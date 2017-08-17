
#################################################################################################################
#Availability Groups
#################################################################################################################
#Import the tools to convert Configuration to HashTable
Import-Module "C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1"


$RG = 'LIAB_RG'
$Auto = 'LIABAuto'
$Config = 'DefaultSQLOnPrem'
$ConfigParms = $(Get-Content 'D:\LabInaBox\LabConfig\AAL\AAL_SQLConfigAO.json')| ConvertFrom-Json| Convert-PSObjectToHashtable

$Params = @{

     ResourceGroupName = $RG; # The name of the ARM Resource Group that contains your Azure Automation Account
     AutomationAccountName = $Auto; # The name of the Azure Automation Account where you want a node on-boarded to
     ComputerName = @('AAL-SQL4'); # The names of the computers that the meta configuration will be generated for
     OutputFolder = "E:\";
}

# Use PowerShell splatting to pass parameters to the Azure Automation cmdlet being invoked
Get-AzureRmAutomationDscOnboardingMetaconfig @Params -Force

$cred =Get-Credential

Set-DscLocalConfigurationManager -Path E:\DscMetaConfigs -Credential $cred -Force 


$ConfigurationData =@{
	AllNodes = @(
		@{
			NodeName = "SQLServer"         
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser =$true
		}
	)
}
#Compile New Configuration
$CompilationJob =  Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $RG -AutomationAccountName $Auto -ConfigurationName 'DefaultAOOnPremPrimary' -Parameters $ConfigParms -ConfigurationData $ConfigurationData 
$CompilationJob2 =  Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $RG -AutomationAccountName $Auto -ConfigurationName 'DefaultAOOnPremSecondary' -Parameters $ConfigParms -ConfigurationData $ConfigurationData 


$NodeIdPrimary = Get-AzureRmAutomationDscNode -ResourceGroupName $RG -AutomationAccountName $Auto | Where-Object NAME -EQ 'AAL-SQL1' | Select-Object Id
$NodeIDSecondary = Get-AzureRmAutomationDscNode -ResourceGroupName $RG -AutomationAccountName $Auto | Where-Object NAME -EQ 'AAL-SQL2' | Select-Object Id
Set-AzureRmAutomationDscNode -NodeConfigurationName 'DefaultAOOnPremPrimary.SQLServer' -ResourceGroupName $RG -AutomationAccountName $Auto -Id $NodeIdPrimary.Id
Set-AzureRmAutomationDscNode -NodeConfigurationName 'DefaultAOOnPremSecondary.SQLServer' -ResourceGroupName $RG -AutomationAccountName $Auto -Id $NodeIDSecondary.Id