#Scheduled task or Enterprise scheduler calls this Script at whatever interval required

#Set Required Variables
$OutputPath = 'G:\DSC_Mof'
$CentralDataStore = 'OHSQL9035'

# Load Common Code
Import-Module "G:\DSC-data-driven-deployment\Modules\ConfigurationHelper.psm1" -Verbose:$False -ErrorAction Stop

#Get a Configuration data to process
#Loop till no work to do
$ConfigurationData = Get-ConfigurationToProcess -SQLServer $CentralDataStore
if (!$ConfigurationData)
{
    Write-Output "Nothing to Process"
    break
}

#Execute Appropritate Script With Configuration retrieved and redirect all out put to Log file
#TODO:  What do we do with $AllStreams.  Drop Errors to table, drop all others to log file.
$AllStreams = $($Output = .$($ConfigurationData.ScriptPath+$ConfigurationData.ScriptName) -ConfigurationData $ConfigurationData -OutputPath $OutputPath) *>&1


