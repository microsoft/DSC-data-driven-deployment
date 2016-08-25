#Set Required Variables
$OutputPath = 'G:\DSC_Mof'     #Location where mof files will be stored
$CentralDataStore = 'OHSQL9035' #Central location where metadata for DSC configurations are/will be stored

# Load Common Code
Import-Module "G:\DSC-data-driven-deployment\Modules\ConfigurationHelper.psm1" -Verbose:$False -ErrorAction Stop

#Add Default build for Company.  This maybe SQL2014 on Windows 2012R2. 
#The ability to add your Own is still there but if you drop items on the queue and dont specify the default will be leveraged
$ParentPayload = [PSCustomObject]@{SourcePath =  "\\ohdc9000\SQLAutoBuilds\SQL2014"
                                    NETPath    =  "\\ohdc9000\SQLAutoBuilds\WIN2012R2\Sxs"
                                    PSDscAllowDomainUser = "True"
                                    PSDscAllowPlainTextPassword = "True"
                                   }
Add-NewParentConfiguration -ParentConfigurationName "CompanyDefault" -Payload $ParentPayload -ScriptName "DSCStandAloneJSON_CalledbyDSCExecution.ps1" -ScriptPath "G:\DSC-data-driven-deployment\scripts\" -SQLServer $CentralDataStore 

#Create New Default configuration which Nodes can be assigned to
#Allows to call Add-NewConfigurationToQueue to be utilized to Enqueue new configurations with an existing default
$SQLPayLoad = [PSCustomObject]@{AdminAccount         =         "CORP\Troyault"; 
                                     InstanceName         =         "MSSQLSERVER";                                                                                                                                                                                                           
                                     InstallSharedDir     =         "T:\Program Files\Microsoft SQL Server";                                                                                                                                                                                 
                                     SQLUserDBDir         =         "G:\MSSQL\Data";                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  
                                     SQLTempDBLogDir      =         "T:\MSSQL\Data";                                                                                                                                                                                                                                                                                                                                                                                    
                                     SQLTempDBDir         =         "T:\MSSQL\Data";                                                                                                                                                                                                         
                                     InstallSQLDataDir    =         "G:\MSSQL\Data";                                                                                                                                                                                                                                                                                                                                                                                                                    
                                     SQLUserDBLogDir      =         "L:\MSSQL\Data";                                                                                                                                                                                                         
                                     InstallSharedWOWDir  =         "T:\Program Files (x86)\Microsoft SQL Server";                                                                                                                                                                           
                                     Features             =         "SQLENGINE,IS,SSMS,ADV_SSMS";                                                                                                                                                                                            
                                     SQLBackupDir         =         "G:\MSSQL\Backup";                                                                                                                                                                                                       
                                     InstanceDir          =         "T:\Program Files\Microsoft SQL Server";                                                                                                                                                                                 
                                     DMaxDop              =         "True";                                                                                                                                                                                                                  
                                     MaxDopVal            =         "0";                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
                                     DMemory              =         "True"
                                     MinMemory            =         "256";                                                                                                                                                                                                          
                                     MaxMemory            =         "512"}
Add-NewNodeConfigurationDefault -NodeConfigurationName "DefaultSQL" -Payload $SQLPayLoad -SQLServer $CentralDataStore

#Adds Credential CORP\MyCred to the Credential Table with a secure password.  Only this user and machine combo can retrieve.
#ASSUMPTION:  Running from the machine which will call back to retrieve credential and run configuration
#User will be prompted for the Password
Add-PSCredential -CredentialName "SQLInstallerAccount"  -Credential "CORP\SQLAuto" -SQLServer $CentralDataStore
Add-PSCredential -CredentialName "SQLAgentAccount"  -Credential "CORP\SQLAgt" -SQLServer $CentralDataStore
Add-PSCredential -CredentialName "SQLServiceAccount"  -Credential "CORP\SQLSvc" -SQLServer $CentralDataStore

#Add Reference of Installer Credential to Default Parent Configuration
#Add Reference of Credentials for DefaultSQL Configuration
#Add-NewNodeConfigurationCredential -NodeConfigurationName 
Add-NewParentConfigurationCredential -ParentConfigurationName "CompanyDefault" -CredentialName "SQLInstallerAccount" -Verbose

#Utilize the below to add (N) number of servers to an existing configuration StandAloneSQL 
#INFO:  This is an async call to add work to queue.  When and how often queue is drained is configured by scheduling next call.
#TODO:  Need to do some validation here to ensure the configuration they are requesting actually exists
$Config = [PSCustomObject]@{Configuration ="CompanyDefault"
                            NodeName ='ohsql9030'}
Add-NewConfigurationToQueue -Configuration $Config -SQLServer $CentralDataStore 



##########################################################################################################
#Below are additional commandlets which are available but not needed for Setup
##########################################################################################################

#Queue Reader to pull the items from queue and push configurations
#Returns a hashtable of all the meta data for one configuration. 
#Meta data includes Location of the script to execute the name of the script and the link to the item on the queue.
$MyConfig = Get-ConfigurationToProcess -SQLServer $CentralDataStore

#Called in the Configuration to update the status on the queue once complete
Update-ConfigurationStatus -Success True -ConfigurationQueueID 4 -SQLServer $CentralDataStore

#Exports certificate with DocumentEncryption property from the remote server locally in SaveLocation.
#Utilized for secure configurations
Get-Cert -RemoteMachine "OHSQL9015" -SaveLocation "f:\publicKeys"
