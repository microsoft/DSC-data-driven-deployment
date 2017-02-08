Param (
    [Parameter(Mandatory)][string]$machineName,
    [PSCustomObject] $configuration,
    [Parameter(Mandatory)][pscredential]$domainCred
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
            RefreshMode = 'Push'
            RebootNodeIfNeeded = $True    
        }
    }
}
LCM_Push -ComputerName localhost -OutputPath C:\Mofs
Set-DSCLocalConfigurationManager -cimsession localhost -Path C:\Mofs -Verbose

configuration PostDomainConfig
{
    Param (
        [Parameter(Mandatory)][string]$nodeName,
        [Parameter(Mandatory)][string]$machineName,
        [PSCustomObject] $configuration,
        [Parameter(Mandatory)][pscredential]$domainCred
    )
         
    #Import the required DSC Resources
    Import-DscResource -ModuleName xCertificate
 
    Node $NodeName
    {     
        xCertReq MyCert
        {
            CARootName                = "$($Configuration.domainname)-$($Configuration.DCMachineName)-CA"
            CAServerFQDN              = "$($configuration.domainname)$($configuration.domainExtention)"
            Subject                   = "$MachineName.$($configuration.domainname)$($configuration.domainExtention)"
	        KeyLength                 = '1024'
            Exportable                = $true
            ProviderName              = '"Microsoft RSA SChannel Cryptographic Provider"'
            OID                       = '1.3.6.1.5.5.7.3.1'
            KeyUsage                  = '0xa0'
            CertificateTemplate       = "Webserver"
            AutoRenew                 = $true
            Credential                = $domainCred
        }
        Package PowerShell6
        {
            Ensure = "Present"
            Name = "PowerShell_6.0.0.14"
            Path = "c:\PowerShell_6.0.0.14-alpha.14-win10-x64.msi"
            ProductId ="929A9AD1-0D9E-4B40-A727-9FF96FF2DE60"
            Credential = $domainCred
        }
        Environment UpdatePath 
        {
           Ensure = "Present"
           Name = "Path"
           Path = $true
           Value = "$env:ProgramFiles\OpenSSH"
        }

        Script DisableFirewall
        {
            GetScript = {
                 @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result = -not('True' -in(Get-NetFirewallProfile -All).Enabled)         
                  }
            }
            
            SetScript ={
                Write-Verbose "Setting all firewall profiles to off"
                Set-NetFirewallProfile -All -Enabled False -Verbose
            }
            TestScript = {
                $Status = -not('True' -in(Get-NetFirewallProfile -All).Enabled) 
                $Status -eq $true
            }

        
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
PostDomainConfig -ConfigurationData $cd -NodeName localhost -MachineName $machineName -configuration $configuration -domainCred $domainCred -OutputPath c:\Mofs

Start-DscConfiguration -ComputerName localhost -Path c:\Mofs -Wait -Force -Verbose

