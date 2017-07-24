configuration DomainConfig
{
    $DCCred = Get-AutomationPSCredential -Name "$($AllNodes.DomainName)_Admin"

    #Import the required DSC Resources
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xActiveDirectory 
    Import-DscResource -ModuleName xNetworking 
    Import-DscResource -ModuleName xADCSDeployment 
    #Import-DscResource -ModuleName xSmbShare 

    Node $AllNodes.Nodename
    {


        xComputer SetName
        {
            Name          = $Node.NodeName
        }
        
        WindowsFeature ADDSInstall{
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }
        
        #User User1
        #{
        #    UserName = $DCCred.UserName
        #    Password = $DCCred
        #    Description = "local account"
        #    Ensure = "Present"
        #    Disabled = $false
        #    PasswordNeverExpires = $true
        #    PasswordChangeRequired = $false
        #}

        xADDomain MyDC{
            DomainName = "$($Node.domainname)$($Node.domainExtention)"
            DomainAdministratorCredential = $DCCred 
            SafemodeAdministratorPassword =  $DCCred 
            DependsOn = '[xComputer]SetName','[WindowsFeature]ADDSInstall','[WindowsFeature]ADDSTools' 
        }  

        WindowsFeature ADDSTools            
        {             
            Ensure = "Present"             
            Name = "RSAT-AD-PowerShell"      
        } 
        
        WindowsFeature ADDSTools2           
        {             
            Ensure = "Present"             
            Name = "RSAT-ADDS"        
        } 
        
              
        WindowsFeature ADCS-Cert-Authority
        {
               Ensure = 'Present'
               Name = 'ADCS-Cert-Authority'
               DependsOn = '[xADDomain]MyDC'
        }      
        
        xADCSCertificationAuthority ADCS
        {
            Ensure = 'Present'
            Credential = $DCCred 
            CAType = 'EnterpriseRootCA'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority','[xADDomain]MyDC'
        }
        
        WindowsFeature ADCS-Web-Enrollment
        {
            Ensure = 'Present'
            Name = 'ADCS-Web-Enrollment'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority','[xADDomain]MyDC'
        }

        xADCSWebEnrollment CertSrv
        {
            Ensure = 'Present'
            IsSingleInstance = 'Yes'
            Credential = $DCCred 
            DependsOn = '[WindowsFeature]ADCS-Web-Enrollment','[xADCSCertificationAuthority]ADCS'
        }
        
        File ISODirectory
        {
            Type = 'Directory' 
            Ensure = 'Present'
            DestinationPath = 'C:\ISO'
            Force = $true
        }                   
    }
}


