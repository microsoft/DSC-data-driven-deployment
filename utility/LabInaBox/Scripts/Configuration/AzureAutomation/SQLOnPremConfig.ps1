Configuration SQLOnPremConfig
{

    Import-DscResource -ModuleName xSQLServer -ModuleVersion 2.0.0.0
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    $Admincreds = Get-AutomationPSCredential -Name "LocalAdmin"
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
            Source = $Node.WindowsBitsLocation
        }

        xSqlServerSetup SQL
        {
            SourcePath = $Node.SQLServerBitsLocation
            SetupCredential = $Node.Admincreds
            InstanceName = $Node.SQLInstanceName
            Features = $Node.Features
            SQLSysAdminAccounts = $Node.SQLAdminAccount
            InstallSharedDir = $Node.SQLInstallSharedDir
            InstallSharedWOWDir = $Node.InstallSharedWowDir
            InstanceDir = $Node.InstanceDir
            InstallSQLDataDir = $Node.InstallSQLDataDir
            SQLUserDBDir = $Node.SQLUserDBDir
            SQLUserDBLogDir = $Node.SQLUserDBLogDir
            SQLTempDBDir = $Node.SQLTempDBDir
            SQLTempDBLogDir = $Node.SQLTempDBLogDir
            SQLBackupDir = $Node.SQLBackupDir
        
            DependsOn = '[WindowsFeature]NET'
        }
        
        xSqlServerFirewall ($Node.NodeName)
        {
            SourcePath = $Node.SQLServerBitsLocation
            InstanceName = $Node.SQLInstanceName
            Features = $Node.Features
        
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
            SQLInstanceName = $Node.SQLInstanceName
            DependsOn = "[xSqlServerSetup]SQL"
        }
        xSQLServerMaxDop($Node.Nodename)
        {
            Ensure = "Present"
            DynamicAlloc = $true
            SQLInstanceName = $Node.SQLInstanceName
            DependsOn = "[xSqlServerSetup]SQL" 
        }
   }     
}