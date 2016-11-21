Param (
    [Parameter(Mandatory)][string]$machineName,
    [Parameter(Mandatory)][string]$domainname,
    [Parameter(Mandatory)][string]$DCMachineName,
    [Parameter(Mandatory)][string]$DSCResourceDest,
    [Parameter(Mandatory)][string]$domainnamespace,
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
            ConfigurationMode = 'ApplyAndAutoCorrect'
            RefreshMode = 'Push'
            RebootNodeIfNeeded = $True    
        }
    }
}
LCM_Push -ComputerName localhost -OutputPath C:\Mofs
Set-DSCLocalConfigurationManager -cimsession localhost -Path C:\Mofs -Verbose

configuration AddToDomain
{
   param
   (
       [string[]]$NodeName,
       [Parameter(Mandatory)][string]$MachineName,    
       [Parameter(Mandatory)][string]$domainname,
       [Parameter(Mandatory)][string]$DCMachineName,
       [Parameter(Mandatory)][string]$DSCResourceDest,
       [Parameter(Mandatory)][string]$domainnamespace,
       [Parameter(Mandatory)][pscredential]$domainCred
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
          RequestFile = "$DSCResourceDest\$MachineName.txt"
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
AddToDomain -ConfigurationData $cd -NodeName localhost -MachineName $machineName -domainname $domainname -DCMachineName $DCMachineName -DSCResourceDest $DSCResourceDest -domainnamespace $domainnamespace -domainCred $domainCred -OutputPath c:\Mofs

Start-DscConfiguration -ComputerName localhost -Path c:\Mofs -Wait -Force -Verbose

