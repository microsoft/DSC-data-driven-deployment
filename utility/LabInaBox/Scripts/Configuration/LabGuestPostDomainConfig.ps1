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

