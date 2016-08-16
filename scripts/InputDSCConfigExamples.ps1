#Set Required Variables
$OutputPath = 'F:\DSCLocal'     #Location where mof files will be stored
$CentralDataStore = 'OHSQL9018' #Central location where metadata for DSC configurations are/will be stored

# Load Common Code
Import-Module "C:\Program Files\WindowsPowerShell\Modules\ConfigurationHelper.psm1" -Verbose:$False -ErrorAction Stop


#Adds Credential CORP\MyCred to the Credential Table with a secure password.  Only this user and machine combo can retrieve.
#ASSUMPTION:  Running from the machine which will call back to retrieve credential and run configuration
#User will be prompted for the Password
Add-PSCredential -Credential "CORP\MyCred" -SQLServer $CentralDataStore

#Exports certificate with DocumentEncryption property from the remote server locally in SaveLocation.
#Utilized for secure configurations
Get-Cert -RemoteMachine "OHSQL9015" -SaveLocation "f:\publicKeys"

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
Add-NewDefaultConfiguration -Name "StandAloneSQL" -Value $SQLPayload -SQLServer $CentralDataStore

#Utilize the below to add (N) number of servers to an existing configuration StandAloneSQL 
#INFO:  This is an async call to add work to queue.  When and how often queue is drained is configured by scheduling next call.
#TODO:  Need to do some validation here to ensure the configuration they are requesting actually exists
$Config = [PSCustomObject]@{Configuration ="StandAloneSQL"
                            NodeName ='ohsql9015','ohsql9016'}
Add-NewConfigurationToQueue -Configuration $Config -SQLServer $CentralDataStore 

#Queue Reader to pull the items from queue and push configurations
#Returns a hashtable of all the meta data for one configuration. 
#Meta data includes Location of the script to execute the name of the script and the link to the item on the queue.
Get-ConfigurationToProcess -SQLServer $CentralDataStore

#Called in the Configuration to update the status on the queue once complete
Update-ConfigurationStatus -Success True -ConfigurationQueueID 4 -SQLServer $CentralDataStore

#Next steps
#Job to clean up failed jobs, set retry, remove finished jobs ect 