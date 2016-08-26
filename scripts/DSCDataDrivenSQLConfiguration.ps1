#Set Required Variables
$OutputPath = 'C:\DSC_Mof'     #Location where mof files will be stored
$CentralDataStore = 'OHSQL9035' #Central location where metadata for DSC configurations are/will be stored
$ConfigurationHelperPath = 'C:\DSC-data-driven-deployment\'
$SQLServerBitsLocation = '\\ohdc9000\SQLAutoBuilds'
$DefaultSQLVersion = 'SQL2014'
$NETLocation = '\\ohdc9000\SQLAutoBuilds\SQL2014\WindowsServer2012R2\sources\sxs'
$PSDscAllowDomainUser = $true 
$PSDscAllowPlainTextPassword = $true #Should be $false for production workloads
$SQLAdminAccount = 'CORP\Administrator'
$SQLInstanceName = 'MSSQLSERVER'
$SQLInstallShareDir = 'C:\Program Files\Microsoft SQL Server'
$SQLUserDBDir = 'C:\Program Files\Microsoft SQL Server\Data'
$SQLTempDBLogDir = 'C:\Program Files\Microsoft SQL Server\Data'
$SQLTempDBDir = 'C:\Program Files\Microsoft SQL Server\Data'
$InstallSQLDataDir = 'C:\Program Files\Microsoft SQL ServerL\Data'
$SQLUserDBLogDir = 'C:\Program Files\Microsoft SQL Server\Data'
$InstallSharedWOWDir = 'c:\Program Files (x86)\Microsoft SQL Server'
$Features = 'SQLENGINE,IS,SSMS,ADV_SSMS'
$SQLBackupDir = 'C:\Program Files\Microsoft SQL Server\Backup' 
$InstanceDir = 'C:\Program Files\Microsoft SQL Server'
$DMaxDop = $true
$MaxDopVal = '0'
$DMemory = $true
$MinMemory = '256'
$MaxMemory = '512'
$InstallerAccountName = 'SQLInstallerAccount'
$SQLAgentAccountName = 'SQLAgentAccount'
$SQLServiceAccountName = 'SQLServiceAccount'
$SQLInstallerAccount = 'CORP\SQLAuto'
$SQLServiceAccount ='CORP\SQLSvc'
$SQLAgenttAccount = 'CORP\SQLAgt' 
$NodetoConfigure = $env:computername

Configuration SQLBuild
{
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xSQLServer
 

   Node $AllNodes.NodeName
   {
   
      # Set LCM to reboot if needed
      LocalConfigurationManager
      {
          AllowModuleOverwrite = $true
          RefreshMode = 'Push'
          ConfigurationMode = 'ApplyAndAutoCorrect'
          RebootNodeIfNeeded = $true
          DebugMode = "All"
      }
      
      WindowsFeature "NET"
      {
          Ensure = "Present"
          Name = "NET-Framework-Core"
          Source = $Node.NETPath 
      }
      
      WindowsFeature "ADTools"
      {
          Ensure = "Present"
          Name = "RSAT-AD-PowerShell"
          Source = $Node.NETPath
      }

      if($Node.Features)
      {
         xSqlServerSetup ($Node.NodeName)
         {
             SourcePath = $Node.SourcePath
             SetupCredential = $Node.InstallerServiceAccount
             InstanceName = $Node.InstanceName
             Features = $Node.Features
             SQLSysAdminAccounts = $Node.SQLSysAdminAccounts
             InstallSharedDir = $Node.SQLInstallShareDir
             InstallSharedWOWDir = $Node.InstallSharedWOWDir
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
             SourcePath = $Node.SourcePath
             InstanceName = $Node.InstanceName
             Features = $Node.Features
         
             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
         }
         xSQLServerPowerPlan ($Node.NodeName)
         {
             Ensure = "Present"
         }
         xSQLServerMemory ($Node.NodeName)
         {
             Ensure = "Present"
             SQLInstanceName = $Node.InstanceName
             DynamicAlloc = $True
         
             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
         }
         xSQLServerMaxDop($Node.NodeName)
         {
             Ensure = "Present"
             DynamicAlloc = $true
         
             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)     
         }
       }
    } 
}
$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = "*"
            PSDscAllowPlainTextPassword = $PSDscAllowPlainTextPassword
            PSDscAllowDomainUser = $PSDscAllowDomainUser
            NETPath = $NETLocation
            SourcePath = $("$SQLServerBitsLocation\$DefaultSQLVersion")
            InstallerServiceAccount = Get-Credential -UserName $SQLInstallerAccount -Message "Credentials to Install SQL Server"
        }
        @{
            NodeName = $NodetoConfigure
            InstanceName    = $SQLInstanceName
            Features        = $Features
            SQLSysAdminAccounts = $SQLAdminAccount
            InstallSharedDir = $SQLInstallShareDir
            InstallSharedWOWDir = $InstallSharedWOWDir
            InstanceDir = $SQLInstallShareDir
            InstallSQLDataDir = $SQLd
            SQLUserDBDir = $SQLUserDBDir
            SQLUserDBLogDir = $SQLUserDBLogDir 
            SQLTempDBDir = $SQLTempDBDir
            SQLTempDBLogDir = $SQLTempDBLogDir
            SQLBackupDir = $SQLBackupDir
        }
    )
}

SQLBuild -ConfigurationData $ConfigurationData -OutputPath $OutputPath

Start-DscConfiguration -ComputerName $NodetoConfigure -Path $OutputPath -Verbose -Wait -Force
Set-DscLocalConfigurationManager -Path $OutputPath -Verbose
Start-DscConfiguration -Path $OutputPath -Verbose -Wait -Force
