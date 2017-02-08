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

function WaitForSQLConn
{
   [CmdletBinding()]
   Param([string]$VMName, $cred)
   Write-Output "[$($VMName)]:: Waiting for SQL Server Connection (using $($cred.username))"
   [Int]$LoopCnt = 0
   Do {
       $LoopCnt++
       while ($( Invoke-Command -VMName $VMName -Credential $cred {$(Get-Process -Name sqlservr -ErrorAction SilentlyContinue ).ProcessName -ne "sqlservr"})) {Start-Sleep -Seconds 1} 
   }
   Until ($LoopCnt -eq 3)  
   while ($(Invoke-Command -VMName $VMName -Credential $cred {Invoke-Sqlcmd -ServerInstance $VMName -Username $($cred.UserName) -Password $($cred.Password) -Query "SELECT @@servername as SQLServer"} -ErrorAction SilentlyContinue).SQLServer -ne $SQLServer) {Start-Sleep -Seconds 3} 
}

function WaitForPSDirect
{
   [CmdletBinding()]
   Param([string]$VMName, $cred)
   Write-Output "[$($VMName)]:: Waiting for PowerShell Direct (using $($cred.username))"
   [Int]$LoopCnt = 0
   Do {
       $LoopCnt++
       while ((Invoke-Command -VMName $VMName -Credential $cred {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 1}
       #Write-Verbose "Checking for PSDirect attempt $LoopCnt of 3."
       Start-Sleep -Seconds 1     
   }
   Until ($LoopCnt -eq 3)  
}

function WaitForDHCPPSDirect
{
    [CmdletBinding()]
   Param([string]$VMName, $cred)
   Write-Output "[$($VMName)]:: Waiting for DHCP (using $($cred.username))"
   #Start-Sleep -seconds 10
   Invoke-Command -VMName $VMName -Credential $cred {while ((Get-NetIPAddress | ? AddressFamily -eq IPv4 | ? IPAddress -ne 127.0.0.1).SuffixOrigin -ne "Dhcp") {Start-Sleep -seconds 10}}
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
    
    Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'PowerShell_6.0.0.14-alpha.14-win10-x64.msi')" -Destination "C:\PowerShell_6.0.0.14-alpha.14-win10-x64.msi"-ToSession $ServerSession
    Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'OpenSSH.zip')" -Destination "C:\Program Files\OpenSSH.zip" -ToSession $ServerSession   
    Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "C:\Program Files\OpenSSH.zip" -DestinationPath "C:\Program Files\" -Force}
    
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
    if (Test-Path "$($configuration.ISOFolderPath)\SSMSInstall.iso")
    {
        Add-VMDvdDrive -VMName $configuration.DCMachineName -Path "$($configuration.ISOFolderPath)\SSMSInstall.iso"
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
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = $configurationJSON | ConvertFrom-Json
    #$configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json
    Stop-VM -Name $configurationData.DCMachineName -Save
    
    $Servers = $configurationData.DomainJoinServer
    $Servers | ForEach-Object -process {
    stop-Vm -name $_ -save
    }

    if ($configurationJSON.Contains("Linux"))
    {$LinuxServers = $configurationData.LinuxServer
     $LinuxServers | ForEach-Object -process {
        stop-Vm -name $_ -save} 
    }
}

function Start-LabinaBox
{
    [CmdletBinding()]
    param(        [string]
                  $configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = $configurationJSON | ConvertFrom-Json
    Start-VM -name $configurationData.DCMachineName
    $Servers =  $configurationData.DomainJoinServer
    $Servers | ForEach-Object -process {
    Start-VM -name $_
    }
    if ($configurationJSON.Contains("Linux"))
    {$LinuxServers = $configurationData.LinuxServer
     $LinuxServers | ForEach-Object -process {
        stop-Vm -name $_ -save} 
    }
}

function Remove-LabinaBox
{
    [CmdletBinding()]
    param(        [string]
                  $configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = $configurationJSON | ConvertFrom-Json
    $Servers = $configurationData.DomainJoinServer + $configurationData.DCMachineName

    $Servers | ForEach-Object -process {
                   Stop-VM -name $_ -turnoff
                   Remove-VM -Name $_ -force
                  }

    if ($configurationJSON.Contains("Linux"))
    {$LinuxServers = $configurationData.LinuxServer
     $LinuxServers | ForEach-Object -process {
          Stop-VM -name $_ -turnoff
          Remove-VM -Name $_ -force} 
    }
    Remove-Item $configurationData.ChildFolderPath -Force -Recurse
}

function CheckPoint-LabinaBox
{
    [CmdletBinding()]
    param(        [string]
                  $configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = $configurationJSON | ConvertFrom-Json
    Get-VM -name $configurationData.DCMachineName | Checkpoint-VM
    $configurationData.DomainJoinServer | ForEach-Object -process {
    Get-VM -name $_ | CheckPoint-VM
    
    if ($configurationJSON.Contains("Linux"))
    {$LinuxServers = $configurationData.LinuxServer
     $LinuxServers | ForEach-Object -process {
         Get-VM -name $_ | CheckPoint-VM } 
    }
   }
}

function Remove-LabinaBoxSnapshot
{
    [CmdletBinding()]
    param(        [PSCustomObject]
                  $configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = $configurationJSON | ConvertFrom-Json
    Get-VM -name $configurationData.DCMachineName | Remove-VMSnapshot
    $configurationData.DomainJoinServer | ForEach-Object -process {
    Get-VM -name $_ | Remove-VMSnapshot

    if ($configurationJSON.Contains("Linux"))
    {$LinuxServers = $configurationData.LinuxServer
     $LinuxServers | ForEach-Object -process {
         Get-VM -name $_ | Remove-VMSnapshot} 
    }

   }
}

function New-LabinaBox
{
    [CmdletBinding()]
    param(        [PSCustomObject]
                  $configuration
    )

    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = $configurationJSON | ConvertFrom-Json
    $start = Get-Date
    Write-Verbose -Message "Lab Creation began at: $start"

    $ExecutionPolicy = Get-ExecutionPolicy
    if ($ExecutionPolicy -eq 'Restricted') {Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force}
    
    #Step 1. Setup lab host. Apply Configuration to the host to ensure we can create Vms
    Complete-HostConfig -configuration $configurationData
    
    #If Linux Servers Exist create
    #Will Add configuration of them at a later time
    if ($configurationJSON.Contains("Linux"))
    {$LinuxServers = $configurationData.LinuxServer
        $LinuxServers | ForEach-Object -Process {New-LabVM -configuration $configurationData -VMName $_ -Verbose -SysPrepImage $configurationData.LinuxParentDrive}
    }

    #Step 2. Create domain controller VM
    New-LabVM -VMName $configurationData.DCMachineName -SysPrepImage $configurationData.DCSysPrepDriveName -configuration $configurationData

    #Step 3. Create each member server VM
    $configurationdata.DomainJoinServer  | ForEach-Object -Process {New-LabVM -configuration $configurationData -VMName $_ -Verbose -SysPrepImage $configurationData.sysPrepDriveName}
    

    #Step 4. Apply domain controller DSC configuration
    New-Domain -configuration $configurationData  -verbose
    
    #Step 5. Apply member server DSC configuration for each server
    $configurationdata.DomainJoinServer | ForEach-Object -Process {Add-LabVMtoDomain -configuration $configurationData -VMName $_ -verbose}

    #Step 6. If Dev machine exists apply dev config
    if ($configurationJSON.Contains("DeveloperMachine"))
    {
        Add-DeveloperConfig -configuration $configurationData -VMName $configurationData.DeveloperMachine -verbose
    }   

    $end = Get-Date
    $diff = $end -$start
    Write-Verbose -Message "Completed lab build @ $($end.ToLongTimeString())"
    Write-Verbose -Message "Time to build lab: $("{0:N2}" -f ($diff.TotalMinutes)) minutes"
}

function Update-LabinaBox
{
    [CmdletBinding()]
    param(        [PSCustomObject]
                  $configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = $configurationJSON | ConvertFrom-Json
    $start = Get-Date
    Write-Verbose -Message "Lab Update began at: $start"
    $NewVm = @()
    $configurationdata.DomainJoinServer  | ForEach-Object -Process {If(!$(Get-VM -Name $_ -ErrorAction Ignore)){$NewVm += $_}}
    $NewVm | ForEach-Object -Process {New-LabVM -configuration $configurationData -VMName $_ -Verbose -SysPrepImage $configurationData.sysPrepDriveName}
    $NewVm | ForEach-Object -Process {Add-LabVMtoDomain -configuration $configurationData -VMName $_ -verbose}

    if ($configurationJSON.Contains("DeveloperMachine"))
    {
        Add-DeveloperConfig -configuration $configurationData -VMName $configurationData.DeveloperMachine -verbose
    }            
}

function Add-DeveloperConfig
{
    [CmdletBinding()]
    param([Parameter(Mandatory)] 
                  [string]$VMName,
                  [PSCustomObject]
                  $configuration
    )
    $DomCred = New-Cred -userPass $configuration.domainAdminPass -UserName "$($configuration.domainname)\Administrator"
    WaitForPSDirect -VMName $VMName -cred $DomCred
    $Session = New-VMsession -MachineName $VMName -Cred $DomCred
    Copy-Item -Path "$(Join-Path -Path $configurationData.ScriptLocation -ChildPath 'Configuration\LabGuestDeveloperConfig.ps1')" -Destination "$(Join-Path -Path $configurationData.DSCResourceDest -ChildPath 'LabGuestDeveloperConfig.ps1')" -ToSession $Session
    Invoke-Command -VMName $VMName -Credential $DomCred -ScriptBlock {."$(Join-Path -Path $args[0] -ChildPath 'LabGuestDeveloperConfig.ps1')" -configuration $args[1] -DomCred $args[2]} -ArgumentList $configurationData.DSCResourceDest,$configuration, $DomCred
}

function New-DSCDataDrivenSQL
{
    [CmdletBinding()]
    param(
        [PSCustomObject] $configuration,
        [PSCustomObject] $SQLconfiguration
    )

    $SQLconfigurationData = Get-Content -Path $SQLconfiguration -Raw| ConvertFrom-Json
    $configurationData = Get-Content -Path $configuration -Raw| ConvertFrom-Json

    $DomCred = New-Cred -userPass $configurationData.domainAdminPass -UserName "$($configurationData.domainname)\Administrator"
    WaitForPSDirect -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -cred $DomCred -Verbose
    $Session = New-VMsession -MachineName $SQLconfigurationData.DSCDataDrivenSQLServer -Cred $DomCred
    Copy-Item -Path "$(Join-Path -Path $configurationData.DSCResourceSource -ChildPath 'DSC-data-driven-deployment.zip')" -Destination "$(Join-Path -Path $configurationData.DSCResourceDest -ChildPath 'DSC-data-driven-deployment.zip')"-ToSession $Session
    Copy-Item -Path "$(Join-Path -Path $configurationData.DSCResourceSource -ChildPath 'SQLResources.zip')" -Destination "$(Join-Path -Path $configurationData.DSCResourceDest -ChildPath 'SQLResources.zip')"-ToSession $Session
    Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'DSC-data-driven-deployment.zip')" -DestinationPath "$args" -Force} -ArgumentList $configurationData.DSCResourceDest
    Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'SQLResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $configurationData.DSCResourceDest
    Copy-Item -Path "$(Join-Path -Path $configurationData.ScriptLocation -ChildPath 'Configuration\LabGuestDSCCentralConfig.ps1')" -Destination "$(Join-Path -Path $configurationData.DSCResourceDest -ChildPath 'LabGuestDSCCentralConfig.ps1')" -ToSession $Session
    Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {."$(Join-Path -Path $args[0] -ChildPath 'LabGuestDSCCentralConfig.ps1')" -configuration $args[1] -DomCred $args[2]} -ArgumentList $configurationData.DSCResourceDest,$SQLconfigurationData, $DomCred
 }

 function Add-ServerConfigtoQueue
 {
    [CmdletBinding()]
    param(
        [PSCustomObject] $configuration,
        [PSCustomObject] $SQLconfiguration
    )
    Try 
    {
        $SQLconfigurationData = Get-Content -Path $SQLconfiguration -Raw| ConvertFrom-Json
        $configurationData = Get-Content -Path $configuration -Raw| ConvertFrom-Json
        Write-Verbose "Create Credential and then wait for connection"
        $DomCred = New-Cred -userPass $configurationData.domainAdminPass -UserName "$($configurationData.domainname)\Administrator"
        WaitForSQLConn -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -cred $DomCred
        Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {
        $Config = [PSCustomObject]@{Configuration =$args[0]
                                    NodeName =$args[1]}
        
        Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
        Add-NewConfigurationToQueue -Configuration $Config -SQLServer $args[2]
        Return $true
        } -ArgumentList $configurationData.ServerConfig,$configurationData.ServertoQueue,$configurationData.DSCDataDrivenSQLServer -ErrorAction SilentlyContinue
    }
    Catch
    {
        Write-Verbose "Waiting for additional 90 sec to allow SQL Server to come online."
        Start-Sleep -Seconds 90
        $SQLconfigurationData = Get-Content -Path $SQLconfiguration -Raw| ConvertFrom-Json
        $configurationData = Get-Content -Path $configuration -Raw| ConvertFrom-Json
        Write-Verbose "Create Credential and then wait for connection"
        $DomCred = New-Cred -userPass $configurationData.domainAdminPass -UserName "$($configurationData.domainname)\Administrator"
        WaitForSQLConn -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -cred $DomCred
        Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {
        $Config = [PSCustomObject]@{Configuration =$args[0]
                                    NodeName =$args[1]}
        
        Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
        Add-NewConfigurationToQueue -Configuration $Config -SQLServer $args[2]
        Return $true
        } -ArgumentList $configurationData.ServerConfig,$configurationData.ServertoQueue,$configurationData.DSCDataDrivenSQLServer -ErrorAction SilentlyContinue
    }
    Finally
    {
        Write-Verbose "Waiting for additional 120 sec to allow SQL Server to come online."
        Start-Sleep -Seconds 120
        $SQLconfigurationData = Get-Content -Path $SQLconfiguration -Raw| ConvertFrom-Json
        $configurationData = Get-Content -Path $configuration -Raw| ConvertFrom-Json
        $DomCred = New-Cred -userPass $configurationData.domainAdminPass -UserName "$($configurationData.domainname)\Administrator"
        WaitForSQLConn -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -cred $DomCred
        Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {
        $Config = [PSCustomObject]@{Configuration =$args[0]
                                    NodeName =$args[1]}
        
        Import-Module -Name $("C:\Program Files\WindowsPowerShell\Modules\DSC-data-driven-deployment\modules\ConfigurationHelper.psm1") -Verbose:$False -ErrorAction Stop
        Add-NewConfigurationToQueue -Configuration $Config -SQLServer $args[2]
        Return $true
        } -ArgumentList $configurationData.ServerConfig,$configurationData.ServertoQueue,$configurationData.DSCDataDrivenSQLServer -ErrorAction SilentlyContinue
    }

 }

Export-ModuleMember -Function 'Stop-LabinaBox','Start-LabinaBox','CheckPoint-LabinaBox','Remove-LabinaBoxSnapshot','Remove-LabinaBox','New-LabinaBox','New-LabVM','Update-LabinaBox','New-DSCDataDrivenSQL','Add-ServerConfigtoQueue'