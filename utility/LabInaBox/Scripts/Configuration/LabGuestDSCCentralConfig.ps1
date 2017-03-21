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
		
		if ($Node.Features)
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
			
			Script WaitforSQL{
				GetScript = { Return @{ Result = $true } }
				SetScript = {
					[Int]$LoopCnt = 0
					$backOff = 1.75 # 0 seconds, 1 second, 4 seconds backoff delay
					Do
					{
						$retryDelay = [Math]::Ceiling(([Math]::pow($LoopCnt, $backOff)))
						while ($(Invoke-Command -VMName $using:configuration.DSCDataDrivenSQLServer -Credential $using:DomCred { $(Get-Process -Name sqlservr -ErrorAction SilentlyContinue).ProcessName -ne "sqlservr" })) { Start-Sleep -Seconds $backOff }
						$LoopCnt++
					}
					
					Until ($LoopCnt -eq 3)
					while ($(Invoke-Command -VMName $VMName -Credential $cred { Invoke-Sqlcmd -ServerInstance $using:configuration.DSCDataDrivenSQLServer -Query "SELECT @@servername as SQLServer" } -ErrorAction SilentlyContinue).SQLServer -ne $SQLServer) { Start-Sleep -Seconds 3 }
					$true
					
				}
				
				TestScript ={
					[Int]$LoopCnt = 0
					$backOff = 1.75 # 0 seconds, 1 second, 4 seconds backoff delay
					Do
					{
						$retryDelay = [Math]::Ceiling(([Math]::pow($LoopCnt, $backOff)))
						while ($(Invoke-Command -VMName $using:configuration.DSCDataDrivenSQLServer -Credential $using:DomCred { $(Get-Process -Name sqlservr -ErrorAction SilentlyContinue).ProcessName -ne "sqlservr" })) { Start-Sleep -Seconds $backOff }
						$LoopCnt++
					}
					Until ($LoopCnt -eq 3)
					while ($(Invoke-Command -VMName $VMName -Credential $cred { Invoke-Sqlcmd -ServerInstance $using:configuration.DSCDataDrivenSQLServer -Query "SELECT @@servername as SQLServer" } -ErrorAction SilentlyContinue).SQLServer -ne $SQLServer) { Start-Sleep -Seconds 3 }
					$true
				}
				DependsOn = ("[xDatabase]DeployDac")
				Credential = $DomCred
			}
			
			Script LoadPSCredential {
				GetScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					$CredTest = Get-CredentialFromDB -CredentialName "SQLInstallerAccount" -SQLServer $using:configuration.DSCDataDrivenSQLServer
					Return @{ Result = $ParentTest }
				}
				
				SetScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					Add-PSCredential -CredentialName "SQLInstallerAccount" -Credential $using:DomCred -SQLServer $using:configuration.DSCDataDrivenSQLServer
				}
				
				TestScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					$CredTest = Get-CredentialFromDB -CredentialName "SQLInstallerAccount" -SQLServer $using:configuration.DSCDataDrivenSQLServer
					If ($CredTest) { $true }
					else { $False }
				}
				DependsOn = ("[Script]WaitforSQL")
				Credential = $DomCred
			}
			
			Script LoadParentConfig {
				GetScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					$ParentTest = Get-ParentConfigurationfromDB -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer
					Return @{ Result = $ParentTest }
				}
				
				SetScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					Add-NewParentConfiguration -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -Payload $using:StandAloneParentPayload -ScriptName "DSCSQLMetaBuild.ps1" -ScriptPath "C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\scripts\" -SQLServer $using:configuration.DSCDataDrivenSQLServer
				}
				
				TestScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					$ParentTest = Get-ParentConfigurationfromDB -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer
					If ($ParentTest) { $true }
					else { $False }
				}
				DependsOn = ("[Script]WaitforSQL")
				Credential = $DomCred
			}
			
			Script LoadDefaultNodeConfig {
				GetScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					$NodeTest = Get-NodeConfigurationDefaultfromDB -NodeConfigurationName $using:configuration.DefaultSQLConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer
					Return @{ Result = $NodeTest }
				}
				
				SetScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					Add-NewNodeConfigurationDefault -NodeConfigurationName $using:configuration.DefaultSQLConfigurationName -Payload $using:SQLPayLoad -SQLServer $using:configuration.DSCDataDrivenSQLServer
				}
				
				TestScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					$NodeTest = Get-NodeConfigurationDefaultfromDB -NodeConfigurationName $using:configuration.DefaultSQLConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer
					If ($NodeTest) { $true }
					else { $False }
				}
				DependsOn = ("[Script]WaitforSQL")
				Credential = $DomCred
			}
			
			Script LoadDefaultParentCred {
				GetScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					$ParentTest = Get-CredentialsforParentConfiguration -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer
					
					
					Return @{ Result = $ParentTest }
				}
				
				SetScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					Add-NewParentConfigurationCredential -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -CredentialName "SQLInstallerAccount" -SQLServer $using:configuration.DSCDataDrivenSQLServer
				}
				
				TestScript = {
					Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
					$ParentTest = Get-CredentialsforParentConfiguration -ParentConfigurationName $using:configuration.StandaloneParentConfigurationName -SQLServer $using:configuration.DSCDataDrivenSQLServer
					If ($ParentTest) { $true }
					else { $False }
				}
				DependsOn = ("[Script]WaitforSQL")
				Credential = $DomCred
			}
			
			Script CreateScheduledTask {
				GetScript = {
					$STTest = Get-ScheduledTask -TaskName "Recurring DSCCentral Queue Check"
					Return @{ Result = $STTest }
				}
				
				SetScript = {
					$jobname = "Recurring DSCCentral Queue Check"
					$script = ".\DSCExecutionTask.ps1"
					$WorkingDir = "C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\scripts"
					$repeat = (New-TimeSpan -Minutes 5)
					$action = New-ScheduledTaskAction –Execute "powershell.exe" -Argument "$script" -WorkingDirectory $WorkingDir
					$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval $repeat
					#$credential = $using:DomCred
					#$username = $credential.UserName
					#$password = $credential.GetNetworkCredential().Password
					$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd
					Register-ScheduledTask -TaskName $jobname -Action $action -Trigger $trigger -RunLevel Highest -User $using:DomCred.UserName -Password ([PSCredential]$using:DomCred).GetNetworkCredential().Password -Settings $settings
				}
				
				TestScript = {
					$test = Get-ScheduledTask -TaskName "Recurring DSCCentral Queue Check" -ErrorAction Ignore
					
					If ($test) { $true }
					else { $False }
				}
				DependsOn = ("[Script]WaitforSQL")
				Credential = $DomCred
			}
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
