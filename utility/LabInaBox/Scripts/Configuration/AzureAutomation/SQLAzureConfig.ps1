Configuration SQLAzureConfig
{
    $DCCred = Get-AutomationPSCredential -Name "$($AllNodes.DomainName)_Admin"
    
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory 
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xSQLServer
    Import-DscResource -modulename xPendingReboot

    Node $AllNodes.NodeName
    {

        xWaitForADDomain WaitforDC
        {
           DomainName = "$($Node.domainname)$($Node.domainExtention)"
           DomainUserCredential = $DCCred
           RetryIntervalSec = 30 
           RetryCount = 45
           RebootRetryCount = 5
        }

        xComputer SetName
        {
            Name          = $Node.NodeName
            DomainName = "$($Node.domainname)$($Node.domainExtention)"
            Credential = $DCCred
            dependson = "[xWaitForADDomain]WaitforDC"
        }
       
        xSQLServerMemory SQLMemory
        {
            Ensure = "Present"
            DynamicAlloc = $True
            SQLInstanceName = $Node.SQLInstanceName
        }
        
        xSQLServerMaxDop SQLMaxdop
        {
            Ensure = "Present"
            DynamicAlloc = $true
            SQLInstanceName = $Node.SQLInstanceName
        }
    }     
}