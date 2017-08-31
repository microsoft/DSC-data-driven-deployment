Configuration DefaultSQLOnPrem2
{
    param(
        [string] $WindowsBitsLocation,
        [string] $SQLServerBitsLocation,
        [string] $SQLInstanceName,
        [string] $Features,
        [string] $SQLAdminAccount,
        [string] $SQLInstallSharedDir,
        [string] $InstallSharedWowDir,
        [string] $InstanceDir,
        [string] $InstallSQLDataDir,
        [string] $SQLUserDBDir,
        [string] $SQLUserDBLogDir,
        [string] $SQLTempDBDir,
        [string] $SQLTempDBLogDir,
        [string] $SQLBackupDir,
        [string] $AzureCred

    )
    Import-DscResource -ModuleName xSQLServer -ModuleVersion 2.0.0.0
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $Admincreds = Get-AutomationPSCredential -Name $AzureCred
    Node SQLServer
    {
        LocalConfigurationManager
        {
            AllowModuleOverwrite = $true
            ConfigurationMode = 'ApplyAndAutoCorrect'
            RebootNodeIfNeeded = $true
        }

        WindowsFeature "NET"
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
            Source = $WindowsBitsLocation
        }

        xSqlServerSetup SQL
        {
            SourcePath = $SQLServerBitsLocation
            SetupCredential = $Admincreds
            InstanceName = $SQLInstanceName
            Features = $Features
            SQLSysAdminAccounts = $SQLAdminAccount
            InstallSharedDir = $SQLInstallSharedDir
            InstallSharedWOWDir = $InstallSharedWowDir
            InstanceDir = $InstanceDir
            InstallSQLDataDir = $InstallSQLDataDir
            SQLUserDBDir = $SQLUserDBDir
            SQLUserDBLogDir = $SQLUserDBLogDir
            SQLTempDBDir = $SQLTempDBDir
            SQLTempDBLogDir = $SQLTempDBLogDir
            SQLBackupDir = $SQLBackupDir
        
            DependsOn = '[WindowsFeature]NET'
        }
        
        xSqlServerFirewall ($Node.NodeName)
        {
            SourcePath = $SQLServerBitsLocation
            InstanceName = $SQLInstanceName
            Features = $Features
        
            DependsOn = "[xSqlServerSetup]SQL"
        }

        xSQLServerPowerPlan ($Node.Nodename)
        {
            Ensure = "Present"
        }

        xSQLServerMemory ($Node.Nodename)
        {
            Ensure = "Present"
            DynamicAlloc = $True
            SQLInstanceName = $SQLInstanceName
            DependsOn = "[xSqlServerSetup]SQL"
        }
        xSQLServerMaxDop($Node.Nodename)
        {
            Ensure = "Present"
            DynamicAlloc = $true
            SQLInstanceName = $SQLInstanceName
            DependsOn = "[xSqlServerSetup]SQL" 
        }
   }     
}