Param (
    [PSCustomObject] $configuration,
    [PSCredential] $DomCred
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

configuration DevConfig
{
    Param (
        [Parameter(Mandatory)][string]$nodeName,
        [Parameter(Mandatory)][pscredential]$DomainCred
    )
         
    #Import the required DSC Resources
    Import-DscResource -ModuleName xCertificate
 
    Node $NodeName
    {     
        Package SSMS
        {
            Ensure = "Present"
            Name = "SSMS-Setup-ENU"
            Path = "\\$($configuration.DCMachineName)\SSMSISO\SSMS-Setup-ENU.exe"
            Arguments = "/install /passive /norestart"
            ProductId ="31769AA7-DDF3-463E-9E25-752362EAA5B2"
            Credential = $DomCred
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
DevConfig -ConfigurationData $cd -NodeName localhost -domainCred $DomCred -OutputPath c:\Mofs

Start-DscConfiguration -ComputerName localhost -Path c:\Mofs -Wait -Force -Verbose

