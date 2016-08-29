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
    Set-DSCLocalConfigurationManager -Path $OutputPath  -CimSession $computer -Verbose
}

Configuration AlwaysOnCluster
{
    Import-DscResource –Module PSDesiredStateConfiguration
    Import-DscResource -Module xSQLServer
    Import-DscResource -Module xFailoverCluster

   Node $AllNodes.Where{$_.Role -eq "PrimaryClusterNode" }.NodeName
   {
        # Set LCM to reboot if needed
        LocalConfigurationManager
        {
            AllowModuleOverwrite = $true
            RefreshMode = 'Push'
            ConfigurationMode = 'ApplyAndAutoCorrect'
            RebootNodeIfNeeded = $true
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
             SQLSysAdminAccounts = $Node.AdminAccount
             SQLSvcAccount = $Node.InstallerServiceAccount
             InstallSharedDir = $Node.InstallSharedDir
             InstallSharedWOWDir = $Node.InstallSharedWoWDir
             InstanceDir = $Node.InstanceDir
             InstallSQLDataDir = $Node.InstallSQLDataDir
             SQLUserDBDir = $Node.SQLUserDBDir
             SQLUserDBLogDir = $Node.SQLUserDBLogDir
             SQLTempDBDir = $Node.SQLTempDBDir
             SQLTempDBLogDir = $SQLTempDBLogDir
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

         xSQLServerPowerPlan ($Node.Nodename)
         {
             Ensure = "Present"
         }

         xSQLServerMemory ($Node.Nodename)
         {
             Ensure = "Present"
             DynamicAlloc = $node.DMemory -as [bool]
             MinMemory = $node.MinMemory 
             MaxMemory =$node.MaxMemory
             SQLInstanceName = $Node.InstanceName
             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
         }

         xSQLServerMaxDop($Node.Nodename)
         {
             Ensure = "Present"
             DynamicAlloc = $node.DMaxDop -as [bool]
             MaxDop = $node.MaxDopval
         
             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)            
         }
       }

       WindowsFeature FailoverFeature
       {
           Ensure = "Present"
           Name      = "Failover-clustering"

           DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
       }

       WindowsFeature RSATClusteringMgmt
       {
           Ensure = "Present"
           Name = "RSAT-Clustering-Mgmt"

           DependsOn = "[WindowsFeature]FailoverFeature"
       }

       WindowsFeature RSATClusteringPowerShell
       {
           Ensure = "Present"
           Name   = "RSAT-Clustering-PowerShell"   

           DependsOn = "[WindowsFeature]FailoverFeature"
       }

       WindowsFeature RSATClusteringCmdInterface
       {
           Ensure = "Present"
           Name   = "RSAT-Clustering-CmdInterface"

           DependsOn = "[WindowsFeature]RSATClusteringPowerShell"
       }

       xCluster ensureCreated
       {
           Name = $Node.ClusterName
           StaticIPAddress = $Node.ClusterIPAddress
           DomainAdministratorCredential = $Node.InstallerServiceAccount
       
           DependsOn = “[WindowsFeature]RSATClusteringCmdInterface”
       }
       xSQLServerAlwaysOnService($Node.Nodename)
       {
            Ensure = "Present"
       
            DependsOn = ("[xCluster]ensureCreated"),("[xSqlServerSetup]" + $Node.NodeName)
       } 
       
       xSQLServerEndpoint($Node.Nodename)
       {
           Ensure = "Present"
           Port = $Node.EndpointPort
           AuthorizedUser = $Node.AuthorizedUser
           EndPointName = $Node.EndPointName
           DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
       }
       
       xSQLAOGroupEnsure($Node.Nodename)
       {
          Ensure = "Present"
          AvailabilityGroupName = $Node.AvailabilityGroupName
          AvailabilityGroupNameListener = $Node.AvailabilityGroupNameListener
          AvailabilityGroupNameIP = $Node.AvailabilityGroupNameIp
          AvailabilityGroupSubMask =$Node.AvailabilityGroupSubMask
          SetupCredential = $Node.InstallerServiceAccount
          PsDscRunAsCredential = $Node.InstallerServiceAccount
          DependsOn = ("[xSQLServerEndpoint]" + $Node.NodeName),("[xSQLServerAlwaysOnService]" + $Node.NodeName),("[WindowsFeature]ADTools")
       }
    } 
    Node $AllNodes.Where{$_.Role -eq "ReplicaServerNode" }.NodeName
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
       
      if($Node.Features)
      {
         xSqlServerSetup ($Node.NodeName)
         {
             SourcePath = $Node.SourcePath
             SetupCredential = $Node.InstallerServiceAccount
             InstanceName = $Node.InstanceName
             Features = $Node.Features
             SQLSysAdminAccounts = $Node.AdminAccount
             SQLSvcAccount = $Node.InstallerServiceAccount
             InstallSharedDir = $Node.InstallSharedDir
             InstallSharedWOWDir = $Node.InstallSharedWoWDir
             InstanceDir = $Node.InstanceDir
             InstallSQLDataDir = $Node.InstallSQLDataDir
             SQLUserDBDir = $Node.SQLUserDBDir
             SQLUserDBLogDir = $Node.SQLUserDBLogDir
             SQLTempDBDir = $Node.SQLTempDBDir
             SQLTempDBLogDir = $Node.TempDBLogDir
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
         xSQLServerPowerPlan ($Node.Nodename)
         {
             Ensure = "Present"
         }
         xSQLServerMemory ($Node.Nodename)
         {
             Ensure = "Present"
             MinMemory = $node.MinMemory 
             MaxMemory =$node.MaxMemory
             SQLInstanceName = $Node.InstanceName
             DynamicAlloc = $node.DMemory -as [bool]

             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
         }
         xSQLServerMaxDop($Node.Nodename)
         {
             Ensure = "Present"
             DynamicAlloc = $node.DMaxDop -as [bool]
             MaxDop = $node.MaxDopval

             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)           
         }   
       }
    
       WindowsFeature FailoverFeature
       {
           Ensure = "Present"
           Name      = "Failover-clustering"
       
           DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
       }
       
       WindowsFeature RSATClusteringPowerShell
       {
           Ensure = "Present"
           Name   = "RSAT-Clustering-PowerShell"   
       
           DependsOn = "[WindowsFeature]FailoverFeature"
       }
      
       WindowsFeature RSATClusteringMgmt
       {
           Ensure = "Present"
           Name = "RSAT-Clustering-Mgmt"
      
           DependsOn = "[WindowsFeature]FailoverFeature"
       }
       
       WindowsFeature RSATClusteringCmdInterface
       {
           Ensure = "Present"
           Name   = "RSAT-Clustering-CmdInterface"
       
           DependsOn = "[WindowsFeature]RSATClusteringPowerShell"
       }
        
       xWaitForCluster waitForCluster 
       { 
           Name = $Node.ClusterName 
           RetryIntervalSec = 20 
           RetryCount = 10
       
           DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
       } 
       
       xCluster joinCluster 
       { 
           Name = $Node.ClusterName 
           StaticIPAddress = $Node.ClusterIPAddress 
           DomainAdministratorCredential = $Node.InstallerServiceAccount
       
           DependsOn = "[xWaitForCluster]waitForCluster" 
       }
       xSQLServerAlwaysOnService($Node.Nodename)
       {
            Ensure = "Present"
       
            DependsOn = ("[xCluster]joinCluster"),("[xSqlServerSetup]" + $Node.NodeName)
       } 
       xSQLServerEndpoint($Node.Nodename)
       {
           Ensure = "Present"
           Port = $Node.Port
           AuthorizedUser = $Node.AuthorizedUser
           EndPointName = $Node.EndPointName
           DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
       }
       
       xWaitForAvailabilityGroup waitforAG
       { 
           Name = $Node.AvailabilityGroupName
           RetryIntervalSec = 20 
           RetryCount = 10
       
           DependsOn = (“[xSQLServerEndpoint]" +$Node.Nodename),(“[xSQLServerAlwaysOnService]" +$Node.Nodename)
       } 
       
       xSQLAOGroupJoin ($Node.Nodename)
       {
          Ensure = "Present"
          AvailabilityGroupName = $Node.AvailabilityGroupName
          SetupCredential = $Node.InstallerServiceAccount
          PsDscRunAsCredential = $Node.InstallerServiceAccount

          DependsOn = ("[xWaitForAvailabilityGroup]waitforAG")
       }
     
    }
}

ForEach ($computer in $computers) {
   $Destination = "\\"+$computer+"\\c$\Program Files\WindowsPowerShell\Modules"
   if (Test-Path "$Destination\xFailoverCluster"){Remove-Item -Path "$Destination\xFailoverCluster" -Recurse -Force}
   if (Test-Path "$Destination\xSqlServer"){Remove-Item -Path "$Destination\xSqlServer"-Recurse -Force}
   Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\xFailoverCluster' -Destination $Destination -Recurse -Force
   Copy-Item 'C:\Program Files\WindowsPowerShell\Modules\xSqlServer' -Destination $Destination -Recurse -Force
}

AlwaysOnCluster -ConfigurationData $ConfigurationData -OutputPath $OutputPath

#Push################################

Workflow StartConfigs 
{ 
    param([string[]]$computers,
        [System.string] $Path)
 
    foreach –parallel ($Computer in $Computers) 
    {
    
        Start-DscConfiguration -ComputerName $Computer -Path $Path -Verbose -Wait -Force
    }
}

StartConfigs -Computers $computers -Path $OutputPath
