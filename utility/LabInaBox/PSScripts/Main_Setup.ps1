# Verify Running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
	Write-Host "----- Must Run as Admin as Administrator -----" -ForegroundColor Red ;     
    Write-Host "----- Please re-open ISE as Administrator-----" -ForegroundColor Yellow;
    Write-Host "------------------ABORTING!-------------------" -ForegroundColor Red;
	BREAK
}

#User will need to rerun the script if HyperV is not configured as a reboot will occur
$start = Get-Date
$start

$ExecutionPolicy = Get-ExecutionPolicy
if ($ExecutionPolicy -eq 'Restricted') {Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force}

######### Required Variables to Configure ########
$ScriptSourceDrive = 'D:\Scripts\LabInaBox'
$ParentDrive = 'C:'
$ChildDrive = 'E:'
$DCMachineName = 'NJDC6000'
$DSCentral = 'NJDSC6000'
[string[]]$DomainJoinServers ='NJSQL6000','NJSQL6001'
$localAdminPass = 'MyFancyP@$$'
$domainAdminPass = 'MyFancyP@$$'
$sysPrepDriveName = 'Win2016Sysprep.vhdx'
$DCSysPrepDriveName = 'Win2016CoreSysPrep.vhdx'
######### Optional Variables to Configure #######################
$SwitchName = 'GuestToGuest'
$DSCResourceSource =  Join-Path -Path $ScriptSourceDrive -ChildPath "DSCResources"
$DSCResourceDest = 'C:\Program Files\WindowsPowerShell\Modules'
$ParentFolderPathSource = Join-Path -Path $ScriptSourceDrive -ChildPath 'ParentDisks'
$ParentFolderPath = Join-Path -Path $ParentDrive -ChildPath 'vms\Parent'
$ChildFolderPath = Join-Path -Path $ChildDrive -ChildPath 'vms'
$DomainJoinPath = Join-Path -Path $ChildDrive -ChildPath 'vms\DomainJoin'
$domainname = 'TestLab'
$domainExtention = '.com'
$DomainIpAddress ='192.168.200.1'
$DHCPScopeIpStart = '192.168.200.20'
$DHCPScopeIpEnd ='192.168.200.254'
$domainnamespace = $domainname + $domainExtention 
$ScriptLocation = Join-Path -Path $ScriptSourceDrive -ChildPath 'PSScripts'
################################################################

# Loading Helper Functions for HyperVConfig
Import-Module -Name $(Join-Path -Path $ScriptSourceDrive -ChildPath 'PSScripts\LabHostConfigHelper.psm1')  -Verbose:$false -ErrorAction Stop
$localAdminCred = New-Cred -userPass $localAdminPass  -userName 'administrator'
$DomCred = New-Cred -userPass $domainAdminPass -UserName "$domainname\Administrator"
$MemberServers = $DomainJoinServers + $DSCentral
$AllServers = $MemberServers + $DCMachineName

$HostConfig = @{
                ScriptLocation = $ScriptLocation
                ParentFolderPathSource = $ParentFolderPathSource
                ParentFolderPath = $ParentFolderPath
                DSCResourceSource =$DSCResourceSource
                DSCResourceDest = $DSCResourceDest
             }

$LabVmConfig = @{
                    ChildfolderPath = $ChildFolderPath
                    ParentFolderPath = $ParentFolderPath
                    sysPrepDriveName = $sysPrepDriveName
                    VmswitchName = $SwitchName
                }

$DCVmConfig = @{
                    ChildfolderPath = $ChildFolderPath
                    ParentFolderPath = $ParentFolderPath
                    sysPrepDriveName = $DCSysPrepDriveName
                    VmswitchName = $SwitchName
                    VMName = $DCMachineName
                }

$DomainConfig = @{
        
                    DCMachineName =$DCMachineName
                    domainname = $domainname
                    Domainnamespace = $Domainnamespace
                    localAdminCred = $localAdminCred
                    DomCred = $DomCred
                    DSCResourceSource = $DSCResourceSource
                    DSCResourceDest = $DSCResourceDest
                    ScriptLocation = $ScriptLocation

                }
$AddtoDomainConfig = @{
                        DCMachineName = $DCMachineName
                        domainname = $domainname
                        Domainnamespace = $domainnamespace
                        localAdminCred = $localAdminCred 
                        DomCred = $DomCred
                        DomainJoinPath =$DomainJoinPath
                        DSCResourceSource =$DSCResourceSource
                        DSCResourceDest = $DSCResourceDest
                        ScriptLocation = $ScriptLocation
                }

#Apply Configuration to the host to ensure we can create Vms
Complete-HostConfig @HostConfig 

#Create Domain Vm requested
New-LabVM @DCVmConfig

#Create Each Member Vm requested
$MemberServers  | ForEach-Object -Process {New-LabVM @LabVmConfig -VMName $_ -Verbose}

#Apply Domain Controller configuration
New-Domain @DomainConfig -verbose

#Add VMs to domain and run post configuration
$MemberServers | ForEach-Object -Process {Add-LabVMtoDomain @AddtoDomainConfig -VMName $_ -verbose}

$end = Get-Date
$diff = $end -$start
$diff

#Remove lab Vms
<#

$AllServers | ForEach-Object -process {
   stop-Vm -name $_ -turnoff
   Remove-VM -Name $_ -force
} 
Remove-Item $ChildFolderPath -Force -Recurse
#>

