#Function to create our Credentials to be passed in plain text for simplicity.  
#Do not leverage this for production use
function New-Cred
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $userPass,
        [Parameter(Position = 1)]
        [string] $userName
    )

    $password = ConvertTo-SecureString $userPass -AsPlainText -Force
     $cred = New-Object System.Management.Automation.PSCredential($userName,$password)
    return $cred
}



function WaitForPSDirect
{
   [CmdletBinding()]
   Param([string]$VMName, $cred)
   Write-Output "[$($VMName)]:: Waiting for PowerShell Direct (using $($cred.username))"
   while ((Invoke-Command -VMName $VMName -Credential $cred {"Test"} -ea SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 1}}

function WaitForDHCPPSDirect
{
    [CmdletBinding()]
   Param([string]$VMName, $cred)
   Write-Output "[$($VMName)]:: Waiting for DHCP (using $($cred.username))"
   Invoke-Command -VMName $VMName -Credential $cred {while ((Get-NetIPAddress | ? AddressFamily -eq IPv4 | ? IPAddress -ne 127.0.0.1).SuffixOrigin -ne "Dhcp") {Start-Sleep -seconds 10} }
}


function New-VMsession
{
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory = $true, Position = 0)]
        [string] $MachineName,
        [Parameter(Position = 1)]
        [PScredential] $Cred

    )   
    $SleepTimer = 5
    do {
        $s = New-PSSession -VMName $MachineName -Credential $Cred -ErrorAction Ignore
        If(!$s){Start-Sleep -Seconds $SleepTimer
                Write-Verbose "Waiting to get pssession to $MachineName on $MachineIP sleeping for $SleepTimer sec"}
        $SleepTimer = [math]::floor(($SleepTimer *3)/2)
       }
    until($s)
    
    Return $s
}


function Complete-HostConfig
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptLocation,
        [Parameter(Mandatory = $true)]
        [String] $ParentFolderPathSource,
        [Parameter(Mandatory = $true)]
        [String] $ParentFolderPath,
        [Parameter(Mandatory = $true)]
        [String] $DSCResourceSource,
        [Parameter(Mandatory = $true)]
        [String] $DSCResourceDest

    )
$HostConfig = @{
                ParentFolderPathSource = $ParentFolderPathSource
                ParentFolderPath = $ParentFolderPath
                DSCResourceSource =$DSCResourceSource
                DSCResourceDest = $DSCResourceDest
             }
    .$(Join-Path -Path $ScriptLocation -ChildPath 'Configuration\LabHostResourcesConfig.ps1') @HostConfig
}

function New-LabVM
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $VMName,
        [Parameter(Mandatory = $true)]
        [string] $ChildfolderPath,
        [Parameter(Mandatory = $true)]
        [string] $ParentFolderPath,
        [Parameter(Mandatory = $true)]
        [string] $sysPrepDriveName,
        [Parameter(Mandatory = $true)]
        [string] $VmswitchName
    )
    $LabVmConfig = @{
                     VMName = $VMName
                     ChildfolderPath = $ChildFolderPath
                     ParentFolderPath = $ParentFolderPath
                     sysPrepDriveName = $sysPrepDriveName
                     VmswitchName = $SwitchName
                    }
    .$(Join-Path -Path $ScriptLocation -ChildPath 'Configuration\LabHostCreateVMConfig.ps1') @LabVmConfig
}

function Add-LabVMtoDomain
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $DCMachineName,
        [Parameter(Mandatory = $true)]
        [string] $VMName,
        [Parameter(Mandatory = $true)]
        [String] $domainname,
        [Parameter(Mandatory = $true)]
        [String] $Domainnamespace,
        [Parameter(Mandatory = $true)]
        [pscredential] $localAdminCred,
        [Parameter(Mandatory = $true)]
        [pscredential] $DomCred,
        [Parameter(Mandatory = $true)]
        [String] $DomainJoinPath,
        [Parameter(Mandatory = $true)]
        [String]$DSCResourceSource,
        [Parameter(Mandatory = $true)]
        [String]$DSCResourceDest = 'C:\Program Files\WindowsPowerShell\Modules',
        [Parameter(Mandatory = $true)]
        [String]$ScriptLocation

    )
    $AddtoDomainConfig = @{ MachineName =$VMName
                            domainname = $domainname
                            DCMachineName = $DCMachineName
                            Domainnamespace = $domainnamespace
                            DSCResourceDest = $DSCResourceDest
                            DomCred = $DomCred
                         }

    #Wait for DC to finalize DHCP configuration
    WaitForDHCPPSDirect -VMName $VMName -cred $localAdminCred
    WaitForPSDirect -VMName $DCMachineName -cred $DomCred
    Invoke-Command -VMName $DCMachineName -Credential $DomCred  -ScriptBlock {djoin /provision /domain $using:domainname /machine $using:VMName /savefile c:\$using:VMName.txt} -ErrorAction Ignore
    
    #Create offline domain join files so we can join Each VM later
    $DCSession= New-VMsession -MachineName $DCMachineName -Cred $DomCred
    Copy-Item -Path c:\$VMName.txt -Destination $DomainJoinPath -FromSession $DCSession
    Remove-PSSession $DCSession -ErrorAction Ignore
    
    #Copy all the DSC resources we will leverage
    $ServerSession = New-VMsession -MachineName $VMName -Cred $localAdminCred
    Copy-Item -Path "$(Join-Path -Path $DSCResourceSource -ChildPath 'DCResources.zip')" -Destination "$(Join-Path -Path $DSCResourceDest -ChildPath 'DCResources.zip')"-ToSession $ServerSession
    Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $DSCResourceDest
    Copy-Item -Path "$(Join-Path -Path $DSCResourceSource -ChildPath 'CertResources.zip')" -Destination "$(Join-Path -Path $DSCResourceDest -ChildPath 'CertResources.zip')"-ToSession $ServerSession
    Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'CertResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $DSCResourceDest
    Copy-Item -Path "$(Join-Path -Path $ScriptLocation -ChildPath 'Configuration\LabGuestAddtoDomainDSCConfig.ps1')" -Destination "$(Join-Path -Path $DSCResourceDest -ChildPath 'LabGuestAddtoDomainDSCConfig.ps1')" -ToSession $ServerSession
    Copy-Item -Path "$(Join-Path -Path $ScriptLocation -ChildPath 'Configuration\LabGuestPostDomainConfig.ps1')" -Destination "$(Join-Path -Path $DSCResourceDest -ChildPath 'LabGuestPostDomainConfig.ps1')" -ToSession $ServerSession
    Copy-Item -Path "$(Join-Path -Path $DomainJoinPath -ChildPath "$VMName.txt")" -Destination "$(Join-Path -Path $DSCResourceDest -ChildPath "$VMName.txt")" -ToSession $ServerSession
    
    #Kick of configuration to Join the Vm to the domain
    Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {."$(Join-Path -Path $args[4] -ChildPath 'LabGuestAddtoDomainDSCConfig.ps1')" -MachineName $args[0] -domainname $args[1] -DCMachineName $args[2] -domainnamespace $args[3] -DSCResourceDest $args[4]  -domainCred $args[5]} -ArgumentList $VMName, $domainname, $DCMachineName,$Domainnamespace,$DSCResourceDest,$DomCred

    #Wait for VM to become available then complete the post configuration tasks
    WaitForPSDirect -VMName $VMName -cred $DomCred
    Invoke-Command -VMName $VMName -Credential $DomCred -ScriptBlock {."$(Join-Path -Path $args[4] -ChildPath 'LabGuestPostDomainConfig.ps1')" -MachineName $args[0] -domainname $args[1] -DCMachineName $args[2] -domainnamespace $args[3] -domainCred $args[5]} -ArgumentList $VMName, $domainname, $DCMachineName,$Domainnamespace,$DSCResourceDest,$DomCred
}

function New-Domain
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $DCMachineName,
        [Parameter(Mandatory = $true)]
        [String] $domainname,
        [Parameter(Mandatory = $true)]
        [String] $Domainnamespace,
        [Parameter(Mandatory = $true)]
        [pscredential] $localAdminCred,
        [Parameter(Mandatory = $true)]
        [pscredential] $DomCred,
        [Parameter(Mandatory = $true)]
        [String]$DSCResourceSource,
        [Parameter(Mandatory = $true)]
        [String]$DSCResourceDest,
        [Parameter(Mandatory = $true)]
        [String]$ScriptLocation

    ) 
    WaitForPSDirect -VMName $DCMachineName -cred $localAdminCred
    $DCSession = New-VMsession -MachineName $DCMachineName -Cred $localAdminCred
    Copy-Item -Path "$(Join-Path -Path $ScriptLocation -ChildPath 'Configuration\LabGuestPreDomainConfig.ps1')" -Destination "$(Join-Path -Path $DSCResourceDest -ChildPath 'LabGuestPreDomainConfig.ps1')" -ToSession $DCSession
    Copy-Item -Path "$(Join-Path -Path $DSCResourceSource -ChildPath 'DCResources.zip')" -Destination "$(Join-Path -Path $DSCResourceDest -ChildPath 'DCResources.zip')"-ToSession $DCSession
    Invoke-Command -VMName $DCMachineName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $DSCResourceDest
    Invoke-Command -VMName $DCMachineName -Credential $localAdminCred -ScriptBlock {Remove-Item -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -Force} -ArgumentList $DSCResourceDest
    Invoke-Command -VMName $DCMachineName -Credential $localAdminCred -ScriptBlock {."$(Join-Path -Path $args[0] -ChildPath 'LabGuestPreDomainConfig.ps1')" -MachineName $Args[1] -DomainNamespace $Args[2] -DomainIpAddress $Args[3] -DHCPScopeIpStart $Args[4] -DHCPScopeIpEnd $Args[5] -domainCred $Args[6] -safemodeCred $Args[7]} -ArgumentList $DSCResourceDest,$DCMachineName,$domainnamespace,$DomainIpAddress,$DHCPScopeIpStart,$DHCPScopeIpEnd,$DomCred,$localAdminCred
}

function New-DatadrivenDeployment
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string] $DCMachineName,
        [Parameter(Mandatory = $true)]
        [String] $MachineName,
        [Parameter(Mandatory = $true)]
        [pscredential] $localAdminCred,
        [Parameter(Mandatory = $true)]
        [pscredential] $DomCred,
        [Parameter(Mandatory = $true)]
        [String]$ScriptLocation

    ) 
    
    $DCSession = New-VMsession -MachineName $DCMachineName -Cred $DomCred
    Copy-Item -Path "$ScriptLocation\ISO\*" -Destination "" -ToSession $DCSession
}
