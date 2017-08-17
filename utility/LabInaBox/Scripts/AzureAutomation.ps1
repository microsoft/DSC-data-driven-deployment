Add-AzureRmAccount
$AutoAccount = 'LIABAuto'
$AutoRG = 'LIAB_RG'
$cred = Get-Credential 

# Define the parameters for Get-AzureRmAutomationDscOnboardingMetaconfig using PowerShell Splatting
$Params = @{

    ResourceGroupName = 'LIAB_RG'; # The name of the ARM Resource Group that contains your Azure Automation Account
    AutomationAccountName = 'LIABAuto'; # The name of the Azure Automation Account where you want a node on-boarded to
    ComputerName = @('AAL-SQL2'); # The names of the computers that the meta configuration will be generated for
    OutputFolder = "E:\";
}

# Use PowerShell splatting to pass parameters to the Azure Automation cmdlet being invoked
Get-AzureRmAutomationDscOnboardingMetaconfig @Params -Force
Set-DscLocalConfigurationManager -Path E:\DscMetaConfigs -Credential $cred

#Modifies the node configuration that a DSC node is mapped to.
$MyNode=Get-AzureRMAutomationDscNode -ResourceGroupName $AutoRG -AutomationAccountName $AutoAccount -Name 'AAL-SQL2'
Set-AzureRmAutomationDscNode -NodeConfigurationName 'TestConfig.WebServer' -ResourceGroupName $AutoRG -AutomationAccountName $AutoAccount -Id $MyNode.Id

#Remove Node from Azure Automation Control
Unregister-AzureRmAutomationDscNode -Id $MyNode.Id -ResourceGroupName $AutoRG -AutomationAccountName $AutoAccount -Force

#Registers Azure VM as a DSC Node
Register-AzureRMAutomationDscNode

#Get-AzureRmAutomationAccount -Name $AutoAccount -ResourceGroupName $AutoRG

New-AzureRMAutomationCredential -AutomationAccountName $AutoAccount -ResourceGroupName $AutoRG -Name 'AALAdministrator' -Description 'AAL Domain Administrator Account' -Value $cred


$myCredential = Get-AzureRMAutomationCredential -Name 'AALAdministrator2' -ResourceGroupName $AutoRG -AutomationAccountName $AutoAccount
$userName = $myCredential.UserName
$securePassword = $myCredential.Password
$password = $myCredential.GetNetworkCredential().Password


get-azurermvm | Stop-AzureRmVM

$cred
$myCredential.UserName




$myCredential = Get-AzureRMAutomationCredential -Name 'AALAdministrator2' -ResourceGroupName $AutoRG -AutomationAccountName $AutoAccount
$myCredential | gm
$myCredential