Param (
    [Parameter(Mandatory)][string]$machineName,
    [PSCustomObject] $configuration
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

configuration AddToDomain
{
    Param (
        [Parameter(Mandatory)][string]$nodeName,
        [Parameter(Mandatory)][string]$machineName,
        [PSCustomObject] $configuration
    )
     
    #Import the required DSC Resources
    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.14.0.0
    Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.8.0.0
    Import-DscResource -ModuleName xCertificate -ModuleVersion 2.1.0.0
 
    Node $NodeName
    {
        xComputer NewNameAndWorkgroup
        {
            Name          = $MachineName    
        }

        xOfflineDomainJoin ODJ
        {
          RequestFile = "$($Configuration.DSCResourceDest)\$MachineName.txt"
          IsSingleInstance = 'Yes'
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
AddToDomain -ConfigurationData $cd -NodeName localhost -MachineName $machineName -configuration $configuration -OutputPath c:\Mofs

Start-DscConfiguration -ComputerName localhost -Path c:\Mofs -Wait -Force -Verbose

