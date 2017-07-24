Configuration SQLAzureConfig
{
    $DCCred = Get-AutomationPSCredential -Name "$($AllNodes.DomainName)_Admin"
    
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory 
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xSQLServer

    Node $AllNodes.NodeName
    {
        xWaitForADDomain WaitforDC
        {
           DomainName = "$($Node.domainname)$($Node.domainExtention)"
           DomainUserCredential = $DCCred
           RetryIntervalSec = 30 
           RetryCount = 45
           RebootRetryCount = 5
           dependson = "[xDNSServerAddress]SetDNS"
        }

        xComputer SetName
        {
            Name          = $Node.NodeName
            DomainName = "$($Node.domainname)$($Node.domainExtention)"
            Credential = $DCCred
            dependson = "[xWaitForADDomain]WaitforDC","[xDNSServerAddress]SetDNS"
        }
       
        xDNSServerAddress SetDNS{
            Address = $Node.DNSIp
            InterfaceAlias = 'Ethernet 3'
            AddressFamily = 'Ipv4'
        }
        #xSQLServerMemory SQLMemory
        #{
        #    Ensure = "Present"
        #    DynamicAlloc = $True
        #    SQLInstanceName = $Node.SQLInstanceName
        #}
        #
        #xSQLServerMaxDop SQLMaxdop
        #{
        #    Ensure = "Present"
        #    DynamicAlloc = $true
        #    SQLInstanceName = $Node.SQLInstanceName
        #}
    }     
}