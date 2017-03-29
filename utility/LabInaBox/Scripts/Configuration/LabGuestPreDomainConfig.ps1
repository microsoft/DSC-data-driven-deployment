Param (
    [Parameter(Mandatory)][string]$machineName,
    [PSCustomObject] $configuration,
    [Parameter(Mandatory)][pscredential]$domainCred,
    [Parameter(Mandatory)][pscredential]$safemodeCred

)

[DSCLocalConfigurationManager()]
Configuration LCM_Push
{    
    Param(
        [string[]]$ComputerName
    )
    Node $ComputerName
    {
    Settings
        {
            AllowModuleOverwrite = $True
            ConfigurationMode = 'ApplyOnly'
            ActionAfterReboot = 'ContinueConfiguration'  
            RefreshMode = 'Push'
            RebootNodeIfNeeded = $True    
        }
    }
}
LCM_Push -ComputerName localhost -OutputPath C:\Mof 
Set-DSCLocalConfigurationManager -cimsession localhost -Path C:\Mof -Verbose -force

configuration DomainConfig
{
   param
   (
       [string[]]$NodeName,
       [PSCustomObject] $configuration,
       [Parameter(Mandatory)][pscredential]$domaincred,
       [Parameter(Mandatory)][pscredential]$safemodeCred
   ) 
     
    #Import the required DSC Resources
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.8.0.0
    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.14.0.0
    Import-DscResource -ModuleName xNetworking -ModuleVersion 2.12.0.0
    Import-DscResource -ModuleName xDhcpServer -ModuleVersion 1.5.0.0
    Import-DscResource -ModuleName xADCSDeployment -ModuleVersion 1.0.0.0
    Import-DscResource -ModuleName xSmbShare -ModuleVersion 2.0.0.0

    Node $NodeName
    {
        xComputer SetName
        {
            Name          = $Configuration.DCMachineName   
        }

        xIPAddress SetIP{
            IpAddress = $Configuration.DomainIpAddress
            InterfaceAlias = 'Ethernet'
            SubnetMask = '24'
            AddressFamily = 'IPv4'
        }
        xDNSServerAddress SetDNS{
            Address = '127.0.0.1'
            InterfaceAlias = 'Ethernet'
            AddressFamily = 'Ipv4'
        }

        WindowsFeature ADDSInstall{
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }
        xADDomain MyDC{
            DomainName = "$($configuration.domainname)$($configuration.domainExtention)"
            DomainAdministratorCredential = $domainCred
            SafemodeAdministratorPassword =  $safemodeCred
            DependsOn = '[xComputer]SetName','[xIpAddress]SetIP','[WindowsFeature]ADDSInstall','[WindowsFeature]ADDSTools' 
        }  

        if (Test-Path "D:\")
        {
            xSmbShare SQLShare{
                Ensure= 'Present'
                Name = 'Source'
                Path = 'D:\'
                Description = 'SQL Server Installation Media'
            }
        }

        if (Test-Path "E:\")
        {
            xSmbShare WinShare{
                Ensure= 'Present'
                Name = 'Windows2016ISO'
                Path = 'E:\'
                Description = 'Windows Server 2016 Installation Media'
            }
        }
        if (Test-Path "F:\")
        {
            xSmbShare SSMSShare{
                Ensure= 'Present'
                Name = 'SSMSISO'
                Path = 'F:\'
                Description = 'SSMS Installer'
            }
        }

        WindowsFeature ADDSTools            
        {             
            Ensure = "Present"             
            Name = "RSAT-AD-PowerShell"             
        } 
        
        WindowsFeature DHCP
        {
           Name = 'DHCP'
           Ensure = 'Present'
        }
        
        WindowsFeature ADCS-Cert-Authority
        {
               Ensure = 'Present'
               Name = 'ADCS-Cert-Authority'
               DependsOn = '[xADDomain]MyDC','[xDhcpServerScope]Scope'
        }

        xDhcpServerScope Scope 
        { 
            Ensure = 'Present'
            IPStartRange = $Configuration.DHCPScopeIpStart 
            IPEndRange = $Configuration.DHCPScopeIpEnd 
           
            Name = 'MyScope'
            SubnetMask = '255.255.255.0' 
            LeaseDuration = '00:08:00' 
            State = 'Active' 
            AddressFamily = 'IPv4'
           
            DependsOn = '[WindowsFeature]DHCP','[xADDomain]MyDC'
        } 
        
        xDhcpServerOption Option 
        { 
            Ensure = 'Present' 
            ScopeID = $Configuration.DHCPScopeIpStart  
            DnsDomain = "$($configuration.domainname)$($configuration.domainExtention)"
            DnsServerIPAddress = $Configuration.DomainIpAddress           
            AddressFamily = 'IPv4' 
            Router = $Configuration.DomainIpAddress
        
            DependsOn = '[xDhcpServerScope]Scope'
        } 

        
        xDhcpServerAuthorization AuthorizeAD
        {
            Ensure = 'Present'
            DependsOn = '[xDhcpServerScope]Scope','[xDhcpServerOption]Option'
        }
        

        
        xADCSCertificationAuthority ADCS
        {
            Ensure = 'Present'
            Credential = $domaincred
            CAType = 'EnterpriseRootCA'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority','[xADDomain]MyDC'
        }

        WindowsFeature ADCS-Web-Enrollment
        {
            Ensure = 'Present'
            Name = 'ADCS-Web-Enrollment'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority','[xADDomain]MyDC'
        }

        xADCSWebEnrollment CertSrv
        {
            Ensure = 'Present'
            IsSingleInstance = 'Yes'
            Credential = $domaincred
            DependsOn = '[WindowsFeature]ADCS-Web-Enrollment','[xADCSCertificationAuthority]ADCS'
        }
        
        File ISODirectory
        {
            Type = 'Directory' 
            Ensure = 'Present'
            DestinationPath = 'C:\ISO'
            Force = $true
        }                   
    }
}
    $cd = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowDomainUser =$true
            PSDscAllowPlainTextPassword = $true
            RebootNodeIfNeeded = $true
        }
    )
    }
DomainConfig -ConfigurationData $cd -NodeName localhost -configuration $configuration -domaincred $domainCred -safemodeCred $safemodeCred -OutputPath c:\Mof


Start-DscConfiguration -ComputerName localhost -Path c:\Mof -Wait -Force -Verbose

