#Set Required Variables
$OutputPath = 'C:\DSC_Mof'     #Location where mof files will be stored
$CentralDataStore = 'OHSQL9038' #Central location where metadata for DSC configurations are/will be stored
$DSCCentralRoot = 'C:\DSC-data-driven-deployment'  #DSCCentralRoot  Call this something new
$SQLServerBitsLocation = '\\ohdc9000\SQLAutoBuilds\SQL2014'  #This folder must contain a folder named Source with the contents of the SQL Server installation media within it
$WindowsBitsLocation = '\\ohdc9000\SQLAutoBuilds\Win2012R2\sources\sxs'
$PSDscAllowDomainUser = $true 
$PSDscAllowPlainTextPassword = $true #Should be $false for production workloads
$StandaloneParentConfigurationName = 'SQLStandAlone'
$AlwaysOnParentConfigurationName = 'SQLAlwaysOn'
$DefaultSQLConfigurationName = 'SQLStandAloneNode'
$SQLAdminAccount = 'CORP\Administrator'
$SQLInstanceName = 'MSSQLSERVER'
$SQLInstallShareDir = 'C:\Program Files\Microsoft SQL Server'
$SQLUserDBDir = 'C:\Program Files\Microsoft SQL Server\Data'
$SQLTempDBLogDir = 'C:\Program Files\Microsoft SQL Server\Data'
$SQLTempDBDir = 'C:\Program Files\Microsoft SQL Server\Data'
$InstallSQLDataDir = 'C:\Program Files\Microsoft SQL Server\Data'
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
$SQLAgentAccount = 'CORP\SQLAgt'
####AlwaysOn Specific Variables
$ClusterName = 'AGCluster01'
$ClusterIPAddress = '10.0.75.199/24'
$AvailabilityGroupName01 = 'MyAG01'
$AvailabilityGroupNameListener01 = 'MyAG01List'
$AvailabilityGroupIP01 = '10.0.75.201'
$AvailabilityGroupSubMask01 = '255.255.255.0'
$EndPointName = 'Hadr_endpoint'
$EndPointPort ='1433'
$AuthorizedUser =$SQLServiceAccount

# Load Common Code
Import-Module -Name $("$DSCCentralRoot\Modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop

#Add Default build for Company.  This maybe SQL2014 on Windows 2012R2. 
#The ability to add your Own is still there but if you drop items on the queue and dont specify the default will be leveraged
$StandAloneParentPayload = [PSCustomObject]@{SourcePath =  $("$SQLServerBitsLocation")
                                    NETPath    =  $("$WindowsBitsLocation")
                                    PSDscAllowDomainUser = $PSDscAllowDomainUser
                                    PSDscAllowPlainTextPassword = $PSDscAllowPlainTextPassword
                                   }

$AlwaysOnParentPayload = [PSCustomObject]@{SourcePath =  $("$SQLServerBitsLocation")
                                    NETPath    =  $("$WindowsBitsLocation")
                                    PSDscAllowDomainUser = $PSDscAllowDomainUser
                                    PSDscAllowPlainTextPassword = $PSDscAllowPlainTextPassword
                                    ClusterName = $ClusterName
                                    ClusterIPAddress = $ClusterIPAddress
                                    AvailabilityGroupName01 = $AvailabilityGroupName01
                                    AvailabilityGroupIP01 = $AvailabilityGroupIP01
                                    AvailabilityGroupSubMask01 = $AvailabilityGroupSubMask01
                                    EndPointName = $EndPointName
                                    EndPointPort = $EndPointPort 
                                    AuthorizedUser = $AuthorizedUser
                                   }

Add-NewParentConfiguration -ParentConfigurationName $StandaloneParentConfigurationName -Payload $StandAloneParentPayload -ScriptName "DSCSQLMetaBuild.ps1" -ScriptPath $("$DSCCentralRoot\scripts\") -SQLServer $CentralDataStore 
Add-NewParentConfiguration -ParentConfigurationName $AlwaysOnParentConfigurationName -Payload $AlwaysOnParentPayload -ScriptName "DSCAlwaysOnMetaBuild.ps1" -ScriptPath $("$DSCCentralRoot\scripts\") -SQLServer $CentralDataStore 


#Create New Default configuration which Nodes can be assigned to
#Allows to call Add-NewConfigurationToQueue to be utilized to Enqueue new configurations with an existing default
$SQLPayLoad = [PSCustomObject]@{AdminAccount         =         $SQLAdminAccount; 
                                     InstanceName         =         $SQLInstanceName;                                                                                                                                                                                                           
                                     InstallSharedDir     =         $SQLInstallShareDir;                                                                                                                                                                                 
                                     SQLUserDBDir         =         $SQLUserDBDir;                                                    
                                     SQLTempDBLogDir      =         $SQLTempDBLogDir;                                                                                                             
                                     SQLTempDBDir         =         $SQLTempDBDir;                                                                                                                                                                                                         
                                     InstallSQLDataDir    =         $InstallSQLDataDir;                                                                                                                                                
                                     SQLUserDBLogDir      =         $SQLUserDBLogDir;                                                                                                                                                                                                         
                                     InstallSharedWOWDir  =         $InstallSharedWOWDir;                                                                                                                                                                           
                                     Features             =         $Features;                                                                                                                                                                                            
                                     SQLBackupDir         =         $SQLBackupDir;                                                                                                                                                                                                       
                                     InstanceDir          =         $InstanceDir;                                                                                                                                                                                 
                                     DMaxDop              =         $DMaxDop;                                                                                                                                                                                                                  
                                     MaxDopVal            =         $MaxDopVal;                                                                                                                                                                                                                             DMemory              =         $DMemory
                                     MinMemory            =         $MinMemory;                                                                                                                                                                                                          
                                     MaxMemory            =         $MaxMemory}
Add-NewNodeConfigurationDefault -NodeConfigurationName $DefaultSQLConfigurationName -Payload $SQLPayLoad -SQLServer $CentralDataStore

#Adds Credential CORP\MyCred to the Credential Table with a secure password.  Only this user and machine combo can retrieve.
#ASSUMPTION:  Running from the machine which will call back to retrieve credential and run configuration
#User will be prompted for the Password
Add-PSCredential -CredentialName $InstallerAccountName -Credential $SQLInstallerAccount -SQLServer $CentralDataStore
Add-PSCredential -CredentialName $SQLAgentAccountName  -Credential $SQLAgentAccount  -SQLServer $CentralDataStore
Add-PSCredential -CredentialName $SQLServiceAccountName -Credential $SQLServiceAccount -SQLServer $CentralDataStore

#Add Reference to Installer Credential to Parent Configurations
Add-NewParentConfigurationCredential -ParentConfigurationName $StandaloneParentConfigurationName -CredentialName $InstallerAccountName -SQLServer $CentralDataStore
Add-NewParentConfigurationCredential -ParentConfigurationName $AlwaysOnParentConfigurationName -CredentialName $InstallerAccountName -SQLServer $CentralDataStore

###############################################################################################
#Utilize the below to add (N) number of servers to an existing configuration StandAloneSQL 
###############################################################################################
#INFO:  This is an async call to add work to queue.  When and how often queue is drained is configured by scheduling next call.
#TODO:  Need to do some validation here to ensure the configuration they are requesting actually exists
#$NodestoConfigure = 'ohsql9050','ohsql9051','ohsql9052'
#$Config = [PSCustomObject]@{Configuration =$StandaloneParentConfigurationName
#                            NodeName =$NodestoConfigure}
#Add-NewConfigurationToQueue -Configuration $Config -SQLServer $CentralDataStore 

############################################################################################
#Utilize the below to add (N) number of servers to an existing configuration SQLAlwaysOn 
############################################################################################
#INFO:  This is an async call to add work to queue.  When and how often queue is drained is configured by scheduling next call.
#TODO:  Need to do some validation here to ensure the configuration they are requesting actually exists
#$NodestoConfigure = 'ohsql9040','ohsql9041','ohsql9042'
#$Config = [PSCustomObject]@{Configuration =$AlwaysOnParentConfigurationName
#                            NodeName =$NodestoConfigure}
#foreach ($Node in $NodestoConfigure){
#    Add-NewNodeConfiguration -ParentConfigurationName $AlwaysOnParentConfigurationName -NodeName $Node -Payload $SQLPayLoad -SQLServer $CentralDataStore
#    Add-NewNodeConfigurationCredential -NodeName $Node -CredentialName $SQLServiceAccountName -SQLServer $CentralDataStore
#    Add-NewNodeConfigurationCredential -NodeName $Node -CredentialName $SQLAgentAccountName -SQLServer $CentralDataStore 
#}
#Add-NewConfigurationToQueue -Configuration $Config -SQLServer $CentralDataStore 


##########################################################################################################
#Below are additional cmdlets which are available but not needed for Setup
##########################################################################################################

#Queue Reader to pull the items from queue and push configurations
#Returns a hashtable of all the meta data for one configuration. 
#Meta data includes Location of the script to execute the name of the script and the link to the item on the queue.
#$MyConfig = Get-ConfigurationToProcess -SQLServer $CentralDataStore

#Called in the Configuration to update the status on the queue once complete
#Update-ConfigurationStatus -Success True -ConfigurationQueueID 4 -SQLServer $CentralDataStore

#Exports certificate with DocumentEncryption property from the remote server locally in SaveLocation.
#Utilized for secure configurations
#Get-Cert -RemoteMachine "OHSQL9015" -SaveLocation "f:\publicKeys"
