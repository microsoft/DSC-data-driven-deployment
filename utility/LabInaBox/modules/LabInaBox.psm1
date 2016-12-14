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
    param(        [PSCustomObject]
                  $configuration
    )
    .$(Join-Path -Path $configuration.ScriptLocation -ChildPath 'Configuration\LabHostResourcesConfig.ps1') -configuration $configuration
}

function New-LabVM
{
    [CmdletBinding()]
    param([Parameter(Mandatory)] 
          [string]$VMName,
          [Parameter(Mandatory)] 
          [string]$SysPrepImage,
          [PSCustomObject] $configuration
    )
    .$(Join-Path -Path $configuration.ScriptLocation -ChildPath 'Configuration\LabHostCreateVMConfig.ps1') -VMName $VMName -configuration $configuration -SysPrepImage $SysPrepImage
}

function Add-LabVMtoDomain
{
    [CmdletBinding()]
    param([Parameter(Mandatory)] 
                  [string]$VMName,
                  [PSCustomObject]
                  $configuration
    )
    $localAdminCred = New-Cred -userPass $configuration.localAdminPass -userName 'administrator'
    $DomCred = New-Cred -userPass $configuration.domainAdminPass -UserName "$($Configuration.domainname)\Administrator"
    
    #Wait for DC to finalize DHCP configuration
    WaitForDHCPPSDirect -VMName $VMName -cred $localAdminCred
    WaitForPSDirect -VMName $configuration.DCMachineName -cred $DomCred
    Invoke-Command -VMName $configuration.DCMachineName -Credential $DomCred  -ScriptBlock {djoin /provision /domain $using:configuration.domainname /machine $using:VMName /savefile c:\$using:VMName.txt} -ErrorAction Ignore
    
    #Create offline domain join files so we can join Each VM later
    $DCSession= New-VMsession -MachineName $configuration.DCMachineName -Cred $DomCred
    Copy-Item -Path c:\$VMName.txt -Destination $configuration.DomainJoinPath -FromSession $DCSession
    Remove-PSSession $DCSession -ErrorAction Ignore
    
    #Copy all the DSC resources we will leverage
    $ServerSession = New-VMsession -MachineName $VMName -Cred $localAdminCred
    Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'DCResources.zip')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'DCResources.zip')"-ToSession $ServerSession
    Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $configuration.DSCResourceDest
    Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'CertResources.zip')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'CertResources.zip')"-ToSession $ServerSession
    Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'CertResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $configuration.DSCResourceDest
    Copy-Item -Path "$(Join-Path -Path $configuration.ScriptLocation -ChildPath 'Configuration\LabGuestAddtoDomainDSCConfig.ps1')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'LabGuestAddtoDomainDSCConfig.ps1')" -ToSession $ServerSession
    Copy-Item -Path "$(Join-Path -Path $configuration.ScriptLocation -ChildPath 'Configuration\LabGuestPostDomainConfig.ps1')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'LabGuestPostDomainConfig.ps1')" -ToSession $ServerSession
    Copy-Item -Path "$(Join-Path -Path $configuration.DomainJoinPath -ChildPath "$VMName.txt")" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath "$VMName.txt")" -ToSession $ServerSession
    
    #Kick of configuration to Join the Vm to the domain
    Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {."$(Join-Path -Path $args[0] -ChildPath 'LabGuestAddtoDomainDSCConfig.ps1')" -MachineName $args[1] -configuration $args[2]} -ArgumentList $configuration.DSCResourceDest,$VMName, $configuration
    Start-Sleep -Seconds 5

    #Wait for VM to become available then complete the post configuration tasks
    WaitForPSDirect -VMName $VMName -cred $DomCred
    Invoke-Command -VMName $VMName -Credential $DomCred -ScriptBlock {."$(Join-Path -Path $args[0] -ChildPath 'LabGuestPostDomainConfig.ps1')" -MachineName $args[1] -configuration $args[2] -domainCred $args[3]} -ArgumentList $configuration.DSCResourceDest,$VMName, $configuration,$DomCred
}

function New-Domain
{ 
    [CmdletBinding()]
    param(        [PSCustomObject]
                  $configuration
    )
    $localAdminCred = New-Cred -userPass $configuration.localAdminPass -userName 'administrator'
    $DomCred = New-Cred -userPass $configuration.domainAdminPass -UserName "$($configuration.domainname)\Administrator"
    if (Test-Path "$($configuration.ISOFolderPath)\en_sql_server_2016_enterprise_x64_dvd_8701793.iso")
    {
        Add-VMDvdDrive -VMName $configuration.DCMachineName -Path "$($configuration.ISOFolderPath)\en_sql_server_2016_enterprise_x64_dvd_8701793.iso"
    }
    if (Test-Path "$($configuration.ISOFolderPath)\en_windows_server_2016_x64_dvd_9327751.iso")
    {
        Add-VMDvdDrive -VMName $configuration.DCMachineName -Path "$($configuration.ISOFolderPath)\en_windows_server_2016_x64_dvd_9327751.iso"
    }

    WaitForPSDirect -VMName $configuration.DCMachineName -cred $localAdminCred
    $DCSession = New-VMsession -MachineName $configuration.DCMachineName -Cred $localAdminCred
    Copy-Item -Path "$(Join-Path -Path $configuration.ScriptLocation -ChildPath 'Configuration\LabGuestPreDomainConfig.ps1')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'LabGuestPreDomainConfig.ps1')" -ToSession $DCSession
    Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'DCResources.zip')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'DCResources.zip')"-ToSession $DCSession
    Invoke-Command -VMName $configuration.DCMachineName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $configuration.DSCResourceDest
    Invoke-Command -VMName $configuration.DCMachineName -Credential $localAdminCred -ScriptBlock {Remove-Item -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -Force} -ArgumentList $configuration.DSCResourceDest
    Invoke-Command -VMName $configuration.DCMachineName -Credential $localAdminCred -ScriptBlock {."$(Join-Path -Path $args[0] -ChildPath 'LabGuestPreDomainConfig.ps1')" -MachineName $Args[1] -configuration $Args[2] -domainCred $Args[3] -safemodeCred $Args[3]} -ArgumentList $configuration.DSCResourceDest,$configuration.DCMachineName,$configuration,$DomCred
}

function Stop-LabinaBox
{
    [CmdletBinding()]
    param(        [string]
                  $configuration
    )
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json
    Stop-VM -Name $configurationData.DCMachineName -Save
    $configurationData.DomainJoinServer | ForEach-Object -process {
    stop-Vm -name $_ -save
   }
}

function Start-LabinaBox
{
    [CmdletBinding()]
    param(        [string]
                  $configuration
    )
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json
    Start-VM -name $configurationData.DCMachineName
    $configurationData.DomainJoinServer | ForEach-Object -process {
    Start-VM -name $_
   }
}

function Remove-LabinaBox
{
    [CmdletBinding()]
    param(        [string]
                  $configuration
    )
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json
    $Servers = $configurationData.DomainJoinServer + $configurationData.DCMachineName 

    $Servers | ForEach-Object -process {
                   stop-Vm -name $_ -turnoff
                   Remove-VM -Name $_ -force
                  }
    Remove-Item $configurationData.ChildFolderPath -Force -Recurse
}

function CheckPoint-LabinaBox
{
    [CmdletBinding()]
    param(        [string]
                  $configuration
    )
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json
    Get-VM -name $configurationData.DCMachineName | Checkpoint-VM
    $configurationData.DomainJoinServer | ForEach-Object -process {
    Get-VM -name $_ | CheckPoint-VM
   }
}

function Remove-LabinaBoxSnapshot
{
    [CmdletBinding()]
    param(        [PSCustomObject]
                  $configuration
    )
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json
    Get-VM -name $configurationData.DCMachineName | Remove-VMSnapshot
    $configurationData.DomainJoinServer | ForEach-Object -process {
    Get-VM -name $_ | Remove-VMSnapshot
   }
}

function New-LabinaBox
{
    [CmdletBinding()]
    param(        [PSCustomObject]
                  $configuration
    )
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json
    $start = Get-Date
    Write-Verbose -Message "Lab Creation began at: $start"

    $ExecutionPolicy = Get-ExecutionPolicy
    if ($ExecutionPolicy -eq 'Restricted') {Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force}
    
    #Step 1. Setup lab host. Apply Configuration to the host to ensure we can create Vms
    Complete-HostConfig -configuration $configurationData
    
    #Step 2. Create domain controller VM
    New-LabVM -VMName $configurationData.DCMachineName -SysPrepImage $configurationData.DCSysPrepDriveName -configuration $configurationData
    
    #Step 3. Create each member server VM
    $configurationdata.DomainJoinServer  | ForEach-Object -Process {New-LabVM -configuration $configurationData -VMName $_ -Verbose -SysPrepImage $configurationData.sysPrepDriveName}
    
    #Step 4. Apply domain controller DSC configuration
    New-Domain -configuration $configurationData  -verbose
    
    #Step 5. Apply member server DSC configuration for each server
    $configurationdata.DomainJoinServer | ForEach-Object -Process {Add-LabVMtoDomain -configuration $configurationData -VMName $_ -verbose}

    $end = Get-Date
    $diff = $end -$start
    Write-Verbose -Message "Completed lab build @ $($end.ToLongTimeString())"
    Write-Verbose -Message "Time to build lab: $("{0:N2}" -f ($diff.TotalMinutes)) minutes"
}


Export-ModuleMember -Function 'Stop-LabinaBox','Start-LabinaBox','CheckPoint-LabinaBox','Remove-LabinaBoxSnapshot','Remove-LabinaBox','New-LabinaBox'