#requires -Version 5
Param([Hashtable]$ConfigurationData,
      [String]$OutputPath)

$computers = $ConfigurationData.AllNodes.Nodename | Where-Object { $_ -ne "*" }
if($computers){$cim = New-CimSession -ComputerName $computers}

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

foreach ($computer in $computers)
{
    $GUID = (New-Guid).Guid
    LCM_Push -ComputerName $Computer -OutputPath $OutputPath 
    Set-DSCLocalConfigurationManager -Path $OutputPath  -CimSession $computer –Verbose
}

Configuration SQLBuild
{
    Import-DscResource –Module PSDesiredStateConfiguration
    Import-DscResource -Module xSQLServer

    Node $AllNodes.NodeName
    {
        # Set LCM to reboot if needed
        LocalConfigurationManager
        {
            AllowModuleOverwrite = $true
            RebootNodeIfNeeded = $true
        }
        
        WindowsFeature "NET"
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
            Source = $Node.NETPath 
        }

      if($Node.Features)
      {
         xSqlServerSetup ($Node.NodeName)
         {
             SourcePath = $Node.SourcePath
             SetupCredential = $Node.SQLInstallerAccount
             SQLSvcAccount = $Node.SQLServiceAccount
             AgtSvcAccount = $Node.SQLAgentAccount
             InstanceName = $Node.InstanceName
             Features = $Node.Features
             SQLSysAdminAccounts = $Node.AdminAccount
             InstallSharedDir = $Node.InstallSharedDir
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
      }
      xSqlServerPowerPlan ($Node.Nodename)
      {
          Ensure = "Present"
      }
      
     xSqlServerMemory ($Node.Nodename)
     {
         MinMemory = $node.MinMemory 
         MaxMemory =$node.MaxMemory
         DynamicAlloc = $node.DMemory -as [bool]
         Ensure = "Present"
     
         DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
     }
     
     xSqlServerMaxDop($Node.Nodename)
     {
         DynamicAlloc = $node.DMaxDop -as [bool]
         MaxDop = $node.MaxDopval
		    Ensure = "Present"
        
         DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
     }
    
    }
}

SQLBuild -ConfigurationData $ConfigurationData -OutputPath $OutputPath

#Copy Code and push configuration to each Computer
Workflow StartConfigs 
{ 
    param([string[]]$computers,
        [System.string] $Path)
 
    foreach –parallel ($Computer in $Computers) 
    {   
         $Destination = "\\"+$computer+"\\c$\Program Files\WindowsPowerShell\Modules"
         if (Test-Path -Path "$Destination\xSqlServer"){Remove-Item -Path "$Destination\xSqlServer"-Recurse -Force}
         Copy-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\xSqlServer' -Destination $Destination -Recurse -Force
         Start-DscConfiguration -ComputerName $Computer -Path $Path -Verbose -Wait -Force
    }
}
try
{
    StartConfigs -Computers $computers -Path $OutputPath
    Update-ConfigurationStatus -Success True -ConfigurationQueueID $ConfigurationData.ConfigurationQueueID -SQLServer $CentralDataStore 
}
catch
{
    Update-ConfigurationStatus -Success False -ConfigurationQueueID $ConfigurationData.ConfigurationQueueID -SQLServer $CentralDataStore
}
