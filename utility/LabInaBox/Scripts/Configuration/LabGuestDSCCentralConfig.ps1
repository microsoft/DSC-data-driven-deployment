Param (
    [PSCustomObject] $configuration,
    [PSCredential] $DomCred
)

$NodetoConfigure = $env:computername
$SQLPayLoad = [PSCustomObject]@{AdminAccount         =         $configuration.SQLAdminAccount; 
                                     InstanceName         =         $configuration.SQLInstanceName;                                                                                                                                                                                                           
                                     InstallSharedDir     =         $configuration.SQLInstallShareDir;                                                                                                                                                                                 
                                     SQLUserDBDir         =         $configuration.SQLUserDBDir;                                                    
                                     SQLTempDBLogDir      =         $configuration.SQLTempDBLogDir;                                                                                                             
                                     SQLTempDBDir         =         $configuration.SQLTempDBDir;                                                                                                                                                                                                         
                                     InstallSQLDataDir    =         $configuration.InstallSQLDataDir;                                                                                                                                                
                                     SQLUserDBLogDir      =         $configuration.SQLUserDBLogDir;                                                                                                                                                                                                         
                                     InstallSharedWOWDir  =         $configuration.InstallSharedWOWDir;                                                                                                                                                                           
                                     Features             =         $configuration.Features;                                                                                                                                                                                            
                                     SQLBackupDir         =         $configuration.SQLBackupDir;                                                                                                                                                                                                       
                                     InstanceDir          =         $configuration.InstanceDir;                                                                                                                                                                                 
                                     DMaxDop              =         $configuration.DMaxDop;                                                                                                                                                                                                                  
                                     MaxDopVal            =         $configuration.MaxDopVal;                                                                                                                                                                                                                             DMemory              =         $DMemory
                                     MinMemory            =         $configuration.MinMemory;                                                                                                                                                                                                          
                                     MaxMemory            =         $configuration.MaxMemory}

$StandAloneParentPayload = [PSCustomObject]@{SourcePath =  $configuration.SQLServerBitsLocation;
                                    NETPath    =  $configuration.WindowsBitsLocation;
                                    PSDscAllowDomainUser = $configuration.PSDscAllowDomainUser;
                                    PSDscAllowPlainTextPassword = $configuration.PSDscAllowPlainTextPassword;
                                   }
Configuration SQLBuild
{
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xSQLServer
    Import-DscResource -ModuleName xDatabase
    Import-DscResource -ModuleName xComputerManagement
 
   
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
             SQLInstanceName = $Node.InstanceName
             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)     
         }
         xDatabase DeployDac
         {
             Ensure = "Present"
             SqlServer = "."
             SqlServerVersion = "2016"
             DatabaseName = $node.DacPacAppName
             DacPacPath =  "C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\build\DSCCentral.dacpac"
             DacPacApplicationName = $node.DacPacAppName

             DependsOn = ("[xSqlServerSetup]" + $Node.NodeName)
         }

        Script LoadPSCredential {
        GetScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                     $CredTest = Get-CredentialFromDB -CredentialName "SQLInstallerAccount" -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                     Return @{Result = $ParentTest}
        }
        
        SetScript = {
                        Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop                  
                        Add-PSCredential -CredentialName "SQLInstallerAccount" -Credential $using:DomCred -SQLServer $using:configuration.DSCDataDrivenSQLServer
                    }
        
        TestScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                      $CredTest = Get-CredentialFromDB -CredentialName "SQLInstallerAccount" -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                      If ($CredTest){$true}
                      else {$False}
        }
            DependsOn = (DependsOn = ("[xDatabase]DeployDac"))
            Credential = $DomCred
        }

        Script LoadParentConfig {
        GetScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                     $ParentTest = Get-ParentConfigurationfromDB -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                     Return @{Result = $ParentTest}
                    }
        
        SetScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                     Add-NewParentConfiguration -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -Payload $using:StandAloneParentPayload -ScriptName "DSCSQLMetaBuild.ps1" -ScriptPath "C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\scripts\" -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                    }
        
        TestScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                      $ParentTest = Get-ParentConfigurationfromDB -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                      If ($ParentTest){$true}
                      else {$False}
                     }
            DependsOn = (DependsOn = ("[xDatabase]DeployDac"))
            Credential = $DomCred
        }
        
        Script LoadDefaultNodeConfig {
        GetScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                     $NodeTest = Get-NodeConfigurationDefaultfromDB -NodeConfigurationName $using:configuration.DefaultSQLConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                     Return @{Result = $NodeTest}
        }
        
        SetScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                     Add-NewNodeConfigurationDefault -NodeConfigurationName $using:configuration.DefaultSQLConfigurationName -Payload $using:SQLPayLoad -SQLServer $using:configuration.DSCDataDrivenSQLServer
                    }
        
        TestScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                      $NodeTest = Get-NodeConfigurationDefaultfromDB -NodeConfigurationName $using:configuration.DefaultSQLConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                      If ($NodeTest){$true}
                      else {$False}
        }
            DependsOn = (DependsOn = ("[xDatabase]DeployDac"))
            Credential = $DomCred
        }
        
        Script LoadDefaultParentCred {
        GetScript = {
                        Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                        $ParentTest = Get-CredentialsforParentConfiguration -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer 


            Return @{Result = $ParentTest}
        }
        
        SetScript = {
                        Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                        Add-NewParentConfigurationCredential -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -CredentialName "SQLInstallerAccount" -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                    }
        
        TestScript = {Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
                      $ParentTest = Get-CredentialsforParentConfiguration -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer 
                      If ($ParentTest){$true}
                      else {$False}
        }
            DependsOn = (DependsOn = ("[xDatabase]DeployDac"))
            Credential = $DomCred
        }


       }
       xScheduledTask DSCDDQueueChecker
       {
            TaskName = "DSCDDQueueChecker"
            ActionExecutable = "C:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
            ActionArguments = "-File `"C:\Program Files\WindowsPowershell\Modules\DSC-data-driven-deployment\scripts\DSCExecutionTask.ps1`""
            ScheduleType = "Minutes"
            RepeatInterval = 5
            StartTime = (Get-Date).AddMinutes(10)
            ExecuteAsCredential = $DomCred
            DependsOn = (DependsOn = ("[xDatabase]DeployDac"))
       }
    } 
}
$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = "*"
            PSDscAllowPlainTextPassword = $configuration.PSDscAllowPlainTextPassword
            PSDscAllowDomainUser =$configuration.PSDscAllowDomainUser
            NETPath = $configuration.WindowsBitsLocation
            SourcePath = $configuration.SQLServerBitsLocation
            InstallerServiceAccount = $DomCred
        }
        @{
            NodeName = $NodetoConfigure
            StandAloneParentPayload =$StandAloneParentPayload
            SQLPayLoad =$SQLPayLoad
            InstanceName    = $configuration.SQLInstanceName
            Features        = $configuration.Features
            SQLSysAdminAccounts = $configuration.SQLAdminAccount
            InstallSharedDir = $configuration.SQLInstallShareDir
            InstallSharedWOWDir = $configuration.InstallSharedWOWDir
            InstanceDir = $configuration.SQLInstallShareDir
            InstallSQLDataDir = $configuration.InstallSQLDataDir
            SQLUserDBDir = $configuration.SQLUserDBDir
            SQLUserDBLogDir = $configuration.SQLUserDBLogDir 
            SQLTempDBDir = $configuration.SQLTempDBDir
            SQLTempDBLogDir = $configuration.SQLTempDBLogDir
            SQLBackupDir = $configuration.SQLBackupDir
            DacPacAppName = "DSCCentral"
        }
    )
}

SQLBuild -ConfigurationData $ConfigurationData -OutputPath $($configuration.OutputPath)

Start-DscConfiguration -ComputerName $NodetoConfigure -Path $($configuration.OutputPath) -Verbose -Wait -Force
