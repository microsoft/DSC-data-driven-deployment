Param (
    [Parameter(Mandatory)][string]$machineName,
    [Parameter(Mandatory)][string]$DomainNamespace,
    [Parameter(Mandatory)][string]$DomainIpAddress,
    [Parameter(Mandatory)][string]$DHCPScopeIpStart,
    [Parameter(Mandatory)][string]$DHCPScopeIpEnd,
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
            ConfigurationMode = 'ApplyAndAutoCorrect'
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
       [Parameter(Mandatory)][string]$machineName,
       [Parameter(Mandatory)][string]$DomainNamespace,
       [Parameter(Mandatory)][string]$DomainIpAddress,
       [Parameter(Mandatory)][string]$DHCPScopeIpStart,
       [Parameter(Mandatory)][string]$DHCPScopeIpEnd,
       [Parameter(Mandatory)][pscredential]$domaincred,
       [Parameter(Mandatory)][pscredential]$safemodeCred
   ) 
     
    #Import the required DSC Resources
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.8.0.0
    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.14.0.0
    Import-DscResource -ModuleName xNetworking -ModuleVersion 2.12.0.0
    Import-DscResource -ModuleName xDhcpServer -ModuleVersion 1.5.0.0
    Import-DscResource -ModuleName xADCSDeployment -ModuleVersion 1.0.0.0

    Node $NodeName
    {
        xComputer SetName
        {
            Name          = $machineName    
        }

        xIPAddress SetIP{
            IpAddress = $DomainIpAddress
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
            DomainName = $domainnamespace
            DomainAdministratorCredential = $domainCred
            SafemodeAdministratorPassword =  $safemodeCred
            DependsOn = '[xComputer]SetName','[xIpAddress]SetIP','[WindowsFeature]ADDSInstall','[WindowsFeature]ADDSTools' 
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
            IPStartRange = $DHCPScopeIpStart 
            IPEndRange = $DHCPScopeIpEnd 
           
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
            ScopeID = $DHCPScopeIpStart  
            DnsDomain = $DomainNamespace
            DnsServerIPAddress = $DomainIpAddress           
            AddressFamily = 'IPv4' 
            Router = $DomainIpAddress
        
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
DomainConfig -ConfigurationData $cd -NodeName localhost -machineName $machineName -DomainNamespace $DomainNamespace -DomainIpAddress $DomainIpAddress -DHCPScopeIpStart $DHCPScopeIpStart -DHCPScopeIpEnd $DHCPScopeIpEnd -domaincred $domainCred -safemodecred $safemodeCred -OutputPath c:\Mof


Start-DscConfiguration -ComputerName localhost -Path c:\Mof -Wait -Force -Verbose

