#Function to create our Credentials to be passed in plain text for simplicity.  
#Do not leverage this for production use
import-module AzureRM

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value;
    if($Invocation.PSScriptRoot)
    {
        $Invocation.PSScriptRoot;
    }
    Elseif($Invocation.MyCommand.Path)
    {
        Split-Path $Invocation.MyCommand.Path
    }
    else
    {
        $Invocation.InvocationName.Substring(0,$Invocation.InvocationName.LastIndexOf("\"));
    }
}

function New-Cred
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [string] $userPass,
        [Parameter(Mandatory, Position = 1)]
        [string] $userName
    )

    $password = ConvertTo-SecureString $userPass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($userName,$password)
    return $cred
}

#Code provided by David Wyatt http://stackoverflow.com/questions/3740128/pscustomobject-to-hashtable
function Convert-PSObjectToHashtable
{
   param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    process
    {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) {  Convert-PSObjectToHashtable $object }
            )
 
            Write-Verbose -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject])
        {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] =  Convert-PSObjectToHashtable $property.Value
            }
            $hash
        }
        else
        {
            $InputObject
        }
    }
}

function WaitForSQLConn
{
   [CmdletBinding()]
   Param(
       [Parameter(Mandatory, Position = 0)]
       [string]$VMName, 
       [Parameter(Mandatory, Position = 1)]
       $cred
   )
   Write-Verbose "[$($VMName)]:: Waiting for SQL Server Connection (using $($cred.username))"
   [Int]$LoopCnt = 0
   $backOff = 1.75 # 0 seconds, 1 second, 4 seconds backoff delay
   Do {
       $retryDelay = [Math]::Ceiling(([Math]::pow( $LoopCnt, $backOff )))
       while ($( Invoke-Command -VMName $VMName -Credential $cred {$(Get-Process -Name sqlservr -ErrorAction SilentlyContinue ).ProcessName -ne "sqlservr"})) {Start-Sleep -Seconds $backOff} 
       $LoopCnt++
   }
   Until ($LoopCnt -eq 3)  
   while ($(Invoke-Command -VMName $VMName -Credential $cred {Invoke-Sqlcmd -ServerInstance $VMName -Username $($cred.UserName) -Password $($cred.Password) -Query "SELECT @@servername as SQLServer"} -ErrorAction SilentlyContinue).SQLServer -ne $SQLServer) {Start-Sleep -Seconds 3} 
}

function WaitForPSDirect
{
   [CmdletBinding()]
   Param(
       [Parameter(Mandatory, Position = 0)]
       [string]$VMName, 
       [Parameter(Mandatory, Position = 1)]
       $cred
   )
   Write-Verbose "[$($VMName)]:: Waiting for PowerShell Direct (using $($cred.username))"
   [Int]$LoopCnt = 0
   $backOff = 1.75 # 0 seconds, 1 second, 4 seconds backoff delay
   Do {
       $retryDelay = [Math]::Ceiling(([Math]::pow( $LoopCnt, $backOff )))
       while ((Invoke-Command -VMName $VMName -Credential $cred {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 1}
       Start-Sleep -Seconds $backOff
       $LoopCnt++     
   }
   Until ($LoopCnt -eq 3)  
}

function WaitForDHCPPSDirect
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [string]$VMName, 
        [Parameter(Mandatory, Position = 1)]
        $cred
    )
    Write-Verbose "[$($VMName)]:: Waiting for DHCP (using $($cred.username))"
    Invoke-Command -VMName $VMName -Credential $cred {while ((Get-NetIPAddress | ? AddressFamily -eq IPv4 | ? IPAddress -ne 127.0.0.1).SuffixOrigin -ne "Dhcp") {Start-Sleep -seconds 10}}
}

function New-VMsession
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, Position = 0)]
        [string] $MachineName,
        [Parameter(Mandatory, Position = 1)]
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
    param(
        [Parameter(Mandatory, Position = 0)]
        [PSCustomObject]$configuration
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
          [Parameter(Mandatory)] 
          [PSCustomObject] $configuration
    )
    .$(Join-Path -Path $configuration.ScriptLocation -ChildPath 'Configuration\LabHostCreateVMConfig.ps1') -VMName $VMName -configuration $configuration -SysPrepImage $SysPrepImage
}

function Add-LabVMtoDomain
{
    [CmdletBinding()]
    param([Parameter(Mandatory)] 
          [string]$VMName,
          [Parameter(Mandatory)] 
          [PSCustomObject]$configuration
    )
    $localAdminCred = New-Cred -userPass $configuration.localAdminPass -userName 'administrator'
    $DomCred = New-Cred -userPass $configuration.domainAdminPass -UserName "$($Configuration.domainname)\Administrator"
    
    #Wait for DC to finalize DHCP configuration
    WaitForDHCPPSDirect -VMName $VMName -cred $localAdminCred
    WaitForPSDirect -VMName $configuration.DCMachineName -cred $DomCred
    Invoke-Command -VMName $configuration.DCMachineName -Credential $DomCred  -ScriptBlock {djoin /provision /domain $using:configuration.domainname /machine $using:VMName /savefile c:\$using:VMName.txt}
    
    #Create offline domain join files so we can join Each VM later
    $DCSession= New-VMsession -MachineName $configuration.DCMachineName -Cred $DomCred
    Copy-Item -Path c:\$VMName.txt -Destination $configuration.DomainJoinPath -FromSession $DCSession
    Remove-PSSession $DCSession
    
    #Copy all the DSC resources we will leverage
    $ServerSession = New-VMsession -MachineName $VMName -Cred $localAdminCred
    Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'DCResources.zip')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'DCResources.zip')" -ToSession $ServerSession
    Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $configuration.DSCResourceDest
    
    #Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'PowerShell_6.0.0.14-alpha.14-win10-x64.msi')" -Destination "C:\PowerShell_6.0.0.14-alpha.14-win10-x64.msi" -ToSession $ServerSession
    #Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'OpenSSH.zip')" -Destination "C:\Program Files\OpenSSH.zip" -ToSession $ServerSession   
    #Invoke-Command -VMName $VMName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "C:\Program Files\OpenSSH.zip" -DestinationPath "C:\Program Files\" -Force}
    
    Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'CertResources.zip')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'CertResources.zip') " -ToSession $ServerSession
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
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$configuration
    )
    $localAdminCred = New-Cred -userPass $configuration.localAdminPass -userName 'administrator'
    $DomCred = New-Cred -userPass $configuration.domainAdminPass -UserName "$($configuration.domainname)\Administrator"
    if (($configuration.SQLServerISO -ne $null)-and(Test-Path "$($configuration.ISOFolderPath)\$($configuration.SQLServerISO)"))
    {
        Add-VMDvdDrive -VMName $configuration.DCMachineName -Path "$($configuration.ISOFolderPath)\$($configuration.SQLServerISO)"
    }
    if (($configuration.Windows2016ISO -ne $null) -and (Test-Path "$($configuration.ISOFolderPath)\$($configuration.Windows2016ISO)"))
    {
        Add-VMDvdDrive -VMName $configuration.DCMachineName -Path "$($configuration.ISOFolderPath)\$($configuration.Windows2016ISO)"
    }
    if (($configuration.SSMSISO -ne $null) -and (Test-Path "$($configuration.ISOFolderPath)\$($configuration.SSMSISO)"))
    {
        Add-VMDvdDrive -VMName $configuration.DCMachineName -Path "$($configuration.ISOFolderPath)\$($configuration.SSMSISO)"
    }

    WaitForPSDirect -VMName $configuration.DCMachineName -cred $localAdminCred
    $DCSession = New-VMsession -MachineName $configuration.DCMachineName -Cred $localAdminCred
    Copy-Item -Path "$(Join-Path -Path $configuration.ScriptLocation -ChildPath 'Configuration\LabGuestPreDomainConfig.ps1')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'LabGuestPreDomainConfig.ps1')" -ToSession $DCSession
    Copy-Item -Path "$(Join-Path -Path $configuration.DSCResourceSource -ChildPath 'DCResources.zip')" -Destination "$(Join-Path -Path $configuration.DSCResourceDest -ChildPath 'DCResources.zip') " -ToSession $DCSession
    Invoke-Command -VMName $configuration.DCMachineName -Credential $localAdminCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $configuration.DSCResourceDest
    Invoke-Command -VMName $configuration.DCMachineName -Credential $localAdminCred -ScriptBlock {Remove-Item -Path "$(Join-Path -Path $args -ChildPath 'DCResources.zip')" -Force} -ArgumentList $configuration.DSCResourceDest
    Invoke-Command -VMName $configuration.DCMachineName -Credential $localAdminCred -ScriptBlock {."$(Join-Path -Path $args[0] -ChildPath 'LabGuestPreDomainConfig.ps1')" -MachineName $Args[1] -configuration $Args[2] -domainCred $Args[3] -safemodeCred $Args[3]} -ArgumentList $configuration.DSCResourceDest,$configuration.DCMachineName,$configuration,$DomCred
}

function Stop-LabinaBox
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
    Stop-VM -Name $configurationData.DCMachineName -Save
    
    $Servers = $configurationData.DomainJoinServer.keys
    $Servers | ForEach-Object -process {
    Stop-VM -name $_ -save
    }

    if ($configurationJSON.Contains("Linux"))
    {$LinuxServers = $configurationData.LinuxServer
     $LinuxServers | ForEach-Object -process {
        Stop-VM -name $_ -save} 
    }
}

function Start-LabinaBox
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
    Start-VM -name $configurationData.DCMachineName
    $Servers =  $configurationData.DomainJoinServer.keys
    $Servers | ForEach-Object -process {
    Start-VM -name $_
    }
    if ($configurationJSON.Contains("Linux"))
    {$LinuxServers = $configurationData.LinuxServer
     $LinuxServers | ForEach-Object -process {
        Start-VM -name $_ -save} 
    }
}

function Remove-LabinaBox
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
    $Servers = $configurationData.DomainJoinServer.keys + $configurationData.DCMachineName

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
    param(
        [Parameter(Mandatory)]
        [string]$configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
    Get-VM -name $configurationData.DCMachineName | Checkpoint-VM
    $configurationData.DomainJoinServer.keys | ForEach-Object -process {
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
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
    Get-VM -name $configurationData.DCMachineName | Remove-VMSnapshot
    $configurationData.DomainJoinServer.keys | ForEach-Object -process {
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
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$configuration
    )

    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
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
    $configurationdata.DomainJoinServer.keys  | ForEach-Object -Process {New-LabVM -configuration $configurationData -VMName $_ -Verbose -SysPrepImage $configurationData.sysPrepDriveName}
    

    #Step 4. Apply domain controller DSC configuration
    New-Domain -configuration $configurationData  -verbose
    
    #Step 5. Apply member server DSC configuration for each server
    $configurationdata.DomainJoinServer.keys | ForEach-Object -Process {Add-LabVMtoDomain -configuration $configurationData -VMName $_ -verbose}

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
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$configuration
    )
    $configurationJSON = Get-Content -Path $configuration -Raw
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
    $start = Get-Date
    Write-Verbose -Message "Lab Update began at: $start"
    $NewVm = @()
    $configurationdata.DomainJoinServer.keys  | ForEach-Object -Process {If(!$(Get-VM -Name $_ -ErrorAction Ignore)){$NewVm += $_}}
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
          [Parameter(Mandatory)]
          [PSCustomObject]$configuration
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
        [Parameter(Mandatory)]
        [PSCustomObject] $configuration,
        [Parameter(Mandatory)]
        [PSCustomObject] $SQLconfiguration
    )

    $SQLconfigurationData = Get-Content -Path $SQLconfiguration -Raw| ConvertFrom-Json
    $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable

    $DomCred = New-Cred -userPass $configurationData.domainAdminPass -UserName "$($configurationData.domainname)\Administrator"
    WaitForPSDirect -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -cred $DomCred -Verbose
    $Session = New-VMsession -MachineName $SQLconfigurationData.DSCDataDrivenSQLServer -Cred $DomCred
    Copy-Item -Path "$(Join-Path -Path $configurationData.DSCResourceSource -ChildPath 'DSC-data-driven-deployment.zip')" -Destination "$(Join-Path -Path $configurationData.DSCResourceDest -ChildPath 'DSC-data-driven-deployment.zip') " -ToSession $Session -Force
    Copy-Item -Path "$(Join-Path -Path $configurationData.DSCResourceSource -ChildPath 'SQLResources.zip')" -Destination "$(Join-Path -Path $configurationData.DSCResourceDest -ChildPath 'SQLResources.zip') " -ToSession $Session -Force
    Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'DSC-data-driven-deployment.zip')" -DestinationPath "$args" -Force} -ArgumentList $configurationData.DSCResourceDest
    Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {Expand-Archive -Path "$(Join-Path -Path $args -ChildPath 'SQLResources.zip')" -DestinationPath "$args" -Force} -ArgumentList $configurationData.DSCResourceDest
    Copy-Item -Path "$(Join-Path -Path $configurationData.ScriptLocation -ChildPath 'Configuration\LabGuestDSCCentralConfig.ps1')" -Destination "$(Join-Path -Path $configurationData.DSCResourceDest -ChildPath 'LabGuestDSCCentralConfig.ps1')" -ToSession $Session -Force
    Invoke-Command -VMName $SQLconfigurationData.DSCDataDrivenSQLServer -Credential $DomCred -ScriptBlock {."$(Join-Path -Path $args[0] -ChildPath 'LabGuestDSCCentralConfig.ps1')" -configuration $args[1] -DomCred $args[2]} -ArgumentList $configurationData.DSCResourceDest,$SQLconfigurationData, $DomCred
 }

 function Add-ServerConfigtoQueue
 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $configuration,
        [Parameter(Mandatory)]
        [PSCustomObject] $SQLconfiguration
    )
    Try 
    {
        $SQLconfigurationData = Get-Content -Path $SQLconfiguration -Raw| ConvertFrom-Json
        $configurationData = Get-Content -Path $configuration -Raw | ConvertFrom-Json | Convert-PSObjectToHashtable
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

 Function New-AzureCertAuthentication
{
    Param (
    
     # Use to set scope to resource group. If no value is provided, scope is set to subscription.
     [Parameter(Mandatory=$false)]
     [String] $ResourceGroup,
    
     # Use to set subscription. If no value is provided, default subscription is used. 
     [Parameter(Mandatory=$false)]
     [String] $SubscriptionId,
    
     [Parameter(Mandatory=$true)]
     [String] $ApplicationDisplayName,
    
      [Parameter(Mandatory=$true)]
     [String] $Subject
     )
    
     Login-AzureRmAccount
     Import-Module AzureRM.Resources
    
     if ($SubscriptionId -eq "") 
     {
        $SubscriptionId = (Get-AzureRmContext).Subscription.SubscriptionId
     }
     else
     {
        Set-AzureRmContext -SubscriptionId $SubscriptionId
     }
    
     if ($ResourceGroup -eq "")
     {
        $Scope = "/subscriptions/" + $SubscriptionId
     }
     else
     {
        $Scope = (Get-AzureRmResourceGroup -Name $ResourceGroup -ErrorAction Stop).ResourceId
     }
    
     $cert = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "$Subject" -FriendlyName "$Subject" -KeySpec KeyExchange
     $keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())
    
     # Use Key credentials
     $Application = New-AzureRmADApplication -DisplayName $ApplicationDisplayName -HomePage ("http://" + $ApplicationDisplayName) -IdentifierUris ("http://" + $ApplicationDisplayName) -CertValue $keyValue -EndDate $cert.NotAfter -StartDate $cert.NotBefore   
     $ServicePrincipal = New-AzureRMADServicePrincipal -ApplicationId $Application.ApplicationId 
    
     $NewRole = $null
     $Retries = 0;
     While ($NewRole -eq $null -and $Retries -le 6)
     {
        # Sleep here for a few seconds to allow the service principal application to become active (should only take a couple of seconds normally)
        Start-Sleep -Seconds 15
        New-AzureRMRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId -Scope $Scope | Write-Verbose -ErrorAction SilentlyContinue
        $NewRole = Get-AzureRMRoleAssignment -ServicePrincipalName $Application.ApplicationId -ErrorAction SilentlyContinue
        $Retries++;
     }
     $AppID=(Get-AzureRmADApplication -DisplayNameStartWith $ApplicationDisplayName).ApplicationId
    
     New-AzureRmADAppCredential -ApplicationId $Application.ApplicationId -CertValue $keyValue -EndDate $cert.NotAfter -StartDate $cert.NotBefore
 }

 function Login-AzurebyCert
 {
    
    Param (
    [String] $CertSubject,
    [String] $ApplicationId,
    [String] $TenantId
    )
    
    $Thumbprint = (Get-ChildItem cert:\CurrentUser\My\ | Where-Object {$_.Subject -match $CertSubject }).Thumbprint
    Login-AzureRmAccount -ServicePrincipal -CertificateThumbprint $Thumbprint -ApplicationId $ApplicationId -TenantId $TenantId | Out-Null
}


function New-LIABAzureNetwork {

   [CmdletBinding()]
   Param(
       [Parameter(Mandatory, Position = 0)]
       [string] $LabPrefix, 
       [Parameter(Mandatory, Position = 1)]
       [string] $Location,
       [Parameter(Mandatory, Position = 2)]
       [string] $SubnetAddress,
       [Parameter(Mandatory, Position = 3)]
       [string] $VNetAddress  


   )
    $VMResourceGroup = "$($LabPrefix)_RG"
    $SubnetName = "$($LabPrefix)_$($SubnetAddress)"
    $VNetName ="$($LabPrefix)vNET"

    #Check for existance of RG if not create
    $AzureRMTest = Get-AzureRmResourceGroup -Name $VMResourceGroup -Location $Location -ErrorAction SilentlyContinue
    if(!$AzureRMTest){New-AzureRmResourceGroup -Name $VMResourceGroup -Location $Location}
    
    $subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix "$SubnetAddress/24"
    
    # Create a virtual network
    $VNetTest = Get-AzureRmVirtualNetwork -ResourceGroupName $VMResourceGroup -Name $VNetName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if(!$VNetTest)
    {
        $vnet = New-AzureRmVirtualNetwork -ResourceGroupName $VMResourceGroup -Location $Location -WarningAction SilentlyContinue `
            -Name $VNetName -AddressPrefix "$VNetAddress/16" -Subnet $subnetConfig
        Write-verbose -message "Virtual Network $VNetName created successfully."
    }
    else
    {
        Write-verbose -message "Virtual Network $VNetName already exists skipping creation...."       
    }
}

function New-LIABAzureVM {

   [CmdletBinding()]
   Param(
       [Parameter(Mandatory)]
       [string] $Location,
       [Parameter(Mandatory)]
       [string] $LabPrefix,
       [Parameter(Mandatory)]
       [string] $VMName,
       [Parameter(Mandatory)]
       [string] $VMSize,
       [Parameter(Mandatory = $false)]
       [string] $StorageType = "Standard_GRS",
       [Parameter(Mandatory)]
       [string] $SubnetAddress,
       [Parameter(Mandatory)]
       [string] $VMUserName,
       [Parameter(Mandatory)]
       [string] $VMPassword,
       [Parameter(Mandatory)]
       [string] $AzurePublisher,
       [Parameter(Mandatory)]
       [string] $AzureOffer,
       [Parameter(Mandatory)]
       [string] $AzureSku,
       [Parameter(Mandatory)]
       [string] $OS )
   
    $ResourceGroupName = "$($LabPrefix)_RG"
    $StorageName = "$($VMName.ToLower().Replace('-',''))storage$(get-random)"
    if ($StorageName.Length > 24)
    {$StorageName.Substring(0,24)}

    $SubnetName = "$($LabPrefix)_$($SubnetAddress)"
    $VNetName ="$($LabPrefix)vNET"
    $OSDiskName = $VMName + "OSDisk"


    $VMStorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -ErrorAction SilentlyContinue
    If(!$VMStorageAccount)
    {
        $VMStorageAccount =  New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageName -Type $StorageType -Location $Location
        Write-Verbose "Created Storage Account $StorageName"
    }
    else
    {
        Write-Verbose "Storage Account $StorageName exists...."
    }

    $vnet=Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroupName  -Name $VNetName

    # Network
    $PIp = Get-AzureRmPublicIpAddress -Name "$($VMName)-PIp" -ResourceGroupName $ResourceGroupName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue    
    If(!$PIp)
    {
        $PIp = New-AzureRmPublicIpAddress -Name "$($VMName)-PIp" -ResourceGroupName $ResourceGroupName -Location $Location -AllocationMethod Dynamic -WarningAction SilentlyContinue
        Write-Verbose "Created Public IP Address $($VMName)-PIp"
    }
    else
    {
        Write-Verbose "Public IP Address $($VMName)-PIp exists..."
    }

    $SubnetConfig = Get-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet -ErrorAction SilentlyContinue
    If(!$SubnetConfig){$SubnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddress}
    $Interface = Get-AzureRmNetworkInterface -Name "$($VMName)-Interface" -ResourceGroupName $ResourceGroupName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if(!$Interface)
    {
        $Interface = New-AzureRmNetworkInterface -Name "$($VMName)-Interface" -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $PIp.Id -WarningAction SilentlyContinue
        Write-Verbose "Created NetworkInterface $($VMName)-Interface"
    }
    else
    {
        Write-Verbose "NetworkInterface $($VMName)Interface exists..."
    }
    
    $VMTest = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if (!$VMTest)
    {
        ## Setup local VM object
        $User = $VMUserName 
        $Password = ConvertTo-SecureString $VMPassword -AsPlainText -Force #Domain Admin Password for LIAB Lab
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password #Credential for LIAB Domain Admin
        $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
        If($OS -eq "Windows")
        {
            $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VMName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
        }
        elseif ($OS -eq "Linux")
        {
            $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $VMName -Credential $Credential
        }
        else 
        {
            Write-Error -message "Unsupported OS $OS"
        }

        $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName $AzurePublisher -Offer $AzureOffer -Skus $Azuresku -Version "latest"
        $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface.Id
        $OSDiskUri = $VMStorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
        $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

        ## Create the VM in Azure
        New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine
        Write-Verbose "Created Virtual Machine $VMName"
    }
    else
    {
        Write-Verbose "Virtual Machine $VMName already exists...."
    }
    
}


function New-AzureLab
{
    [CmdletBinding()]
    param ([Parameter(Mandatory)]
           [PSCustomObject] $configuration
           )
    
    $configurationData = Get-Content -Path $configuration -Raw| ConvertFrom-Json | Convert-PSObjectToHashtable
    $ResourceGroup = "$($configurationData.LabPrefix)_RG"
    Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationId -TenantId $configurationData.TenantId 
    New-LIABAzureNetwork -LabPrefix $configurationData.LabPrefix -Location $configurationData.Location -SubnetAddress $configurationData.SubnetAddress -VNetAddress $configurationData.VNetAddress
    foreach ($Server in $configurationData.DomainJoinServer.keys)
    {     
        $VMTest = Get-AzureRmVM -ResourceGroupName $ResourceGroup -Name $Server -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationId -TenantId $configurationData.TenantId 
        If(!$VMTest)
        {
            New-LIABAzureVM -Location $configurationData.Location -LabPrefix $configurationData.LabPrefix -VMName $Server -VMSize $configurationData.Size `
                -SubnetAddress $configurationData.SubnetAddress -VMUserName $configurationData.DomainJoinServer.$($Server).VMUserName `
                -VMPassword $configurationData.DomainJoinServer.$($Server).VMPassword  `
                -AzurePublisher $configurationData.DomainJoinServer.$($Server).AzurePublisher `
                -AzureOffer $configurationData.DomainJoinServer.$($Server).AzureOffer `
                -AzureSku $configurationData.DomainJoinServer.$($Server).AzureSku `
                -OS $configurationData.DomainJoinServer.$($Server).OS
        }    
        else
        {Write-verbose "$Server Exists skipping creation."}
    }
}

function Remove-AzureLab
{  [CmdletBinding()]
    param ([Parameter(Mandatory)]
           [PSCustomObject] $configuration
           )

    $configurationData = Get-Content -Path $configuration -Raw| ConvertFrom-Json
    Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationId -TenantId $configurationData.TenantId 
    Remove-AzureRmResourceGroup -Name "$($configurationData.LabPrefix)_RG" -Force
    Write-Verbose -Message "Removed Azure Lab in resource group $($configurationData.LabPrefix)_RG"
}

function Remove-AzureDSCNodeConfigurations
{
   [CmdletBinding()]
   param ([ValidateNotNull()] 
          [PSCustomObject]$configuration)
    
   $configurationData = Get-Content -Path $configuration -Raw|ConvertFrom-Json | Convert-PSObjectToHashtable

   Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationId -TenantId $configurationData.TenantId 
   $Servers = $configurationData.DomainJoinServer.Keys 
   foreach ($Server in $Servers)
    {
        $MyRegistration = Get-AzureRmAutomationDscNode -Name $server -ResourceGroupName $configurationData.AzureAutomationRG `
             -AutomationAccountName $configurationData.AzureAutomationAccount -ErrorAction SilentlyContinue
        if ($MyRegistration)
        {
            If($configurationData.LabType -eq 'AzureLab' -and $configurationData.DomainJoinServer.$($Server).DSCConfiguration)
            {          
                Unregister-AzureRmAutomationDscNode -ResourceGroupName $configurationData.AzureAutomationRG `
                    -AutomationAccountName $configurationData.AzureAutomationAccount -Id $myRegistration.Id -Force

                Write-Verbose "Removed $server from DSC configuration."
            }
            elseif($configurationData.LabType -eq 'HyperVLab')
            {
                $ConfigExists = Get-AzureRmAutomationDscConfiguration -Name $configurationData.DomainJoinServer.$server `
                    -ResourceGroupName "$($configurationData.LabPrefix)_RG" -AutomationAccountName $configurationData.AzureAutomationAccount -ErrorAction SilentlyContinue
                if ($ConfigExists)
                {
                    $NodeId=Get-AzureRmAutomationDscNode -ResourceGroupName "$($configurationData.LabPrefix)_RG" `
                            -AutomationAccountName $configurationData.AzureAutomationAccount | Where-Object NAME -EQ $Server | Select-Object Id
                    Unregister-AzureRmAutomationDscNode -ResourceGroupName $configurationData.AzureAutomationRG `
                        -AutomationAccountName $configurationData.AzureAutomationAccount -Id $myRegistration.Id -Force
                }
                else
                {
                    Write-Error "Configuration $($configurationData.DomainJoinServer.$server) does not Exist"
                }
            }
        }
        else
        {
            Write-verbose "$Server does not have a DSC Configuration Applied."
        }
    }
} 



function Set-AzureDSCNodeConfigurations
{
   [CmdletBinding()]
   param ([ValidateNotNull()] 
          [PSCustomObject]$configuration)
   
    $configurationData = Get-Content -Path $configuration -Raw|ConvertFrom-Json | Convert-PSObjectToHashtable

    Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationId -TenantId $configurationData.TenantId 
  
    $Servers = $configurationData.DomainJoinServer.Keys 
    
    foreach ($Server in $Servers)
    {
        $MyRegistration = Get-AzureRmAutomationDscNode -Name $server -ResourceGroupName $configurationData.AzureAutomationRG `
             -AutomationAccountName $configurationData.AzureAutomationAccount -ErrorAction SilentlyContinue
        if (!$MyRegistration)
        {
            If($configurationData.LabType -eq 'AzureLab' -and $configurationData.DomainJoinServer.$($Server).DSCConfiguration)
            {          
                Register-AzureRmAutomationDscNode -AutomationAccountName $configurationData.AzureAutomationAccount `
                    -ResourceGroupName $configurationData.AzureAutomationRG `
                    -AzureVMName $server -AzureVMResourceGroup "$($configurationData.LabPrefix)_RG" `
                    -NodeConfigurationName "$($configurationData.DomainJoinServer.$($Server).DSCConfiguration).$($Server)" `
                    -ActionAfterReboot ContinueConfiguration `
                    -AllowModuleOverwrite $true `
                    -ConfigurationMode ApplyAndAutocorrect `
                    -RebootNodeIfNeeded $true
            }
            elseif($configurationData.LabType -eq 'HyperVLab')
            {
                $Params = @{
            
                 ResourceGroupName = "$($configurationData.LabPrefix)_RG"; 
                 AutomationAccountName =$configurationData.AzureAutomationAccount ; 
                 ComputerName = @($Server); 
                 OutputFolder = "C:\";
                }
            
                Get-AzureRmAutomationDscOnboardingMetaconfig @Params -Force
                #$path = "C:\DscMetaConfigs\$Server.meta.mof"
                #Set-DscLocalConfigurationManager -Path "C:\DscMetaConfigs\" -Credential $Credential -Force -ComputerName $Server 
                $ConfigExists = Get-AzureRmAutomationDscConfiguration -Name $configurationData.DomainJoinServer.$server `
                    -ResourceGroupName "$($configurationData.LabPrefix)_RG" -AutomationAccountName $configurationData.AzureAutomationAccount -ErrorAction SilentlyContinue
                if ($ConfigExists)
                {
                    $NodeId=Get-AzureRmAutomationDscNode -ResourceGroupName "$($configurationData.LabPrefix)_RG" `
                            -AutomationAccountName $configurationData.AzureAutomationAccount | Where-Object NAME -EQ $Server | Select-Object Id
                    Set-AzureRmAutomationDscNode -NodeConfigurationName $configurationData.DomainJoinServer.$server `
                        -ResourceGroupName "$($configurationData.LabPrefix)_RG" -AutomationAccountName $configurationData.AzureAutomationAccount -Id $NodeId.Id
                }
                else
                {
                    Write-Error "Configuration $($configurationData.DomainJoinServer.$server) does not Exist"
                }
            }
        }
        else
        {
            Write-verbose "$($MyRegistration.Name) is registered skipping registration."
            if (!$MyRegistration.NodeConfigurationName -and $configurationData.DomainJoinServer.$($Server).DSCConfiguration)
            {
                Write-verbose "Applying $($configurationData.DomainJoinServer.$server) to $($MyRegistration.Name)"
                $NodeId=Get-AzureRmAutomationDscNode -ResourceGroupName "$($configurationData.LabPrefix)_RG" -AutomationAccountName $configurationData.AzureAutomationAccount | Where-Object NAME -EQ $Server| Select-Object Id
                Set-AzureRmAutomationDscNode -NodeConfigurationName $configurationData.DomainJoinServer.$($Server).DSCConfiguration -ResourceGroupName "$($configurationData.LabPrefix)_RG" -AutomationAccountName $configurationData.AzureAutomationAccount -Id $NodeId.Id  -Force
            }
            else
            {
                Write-verbose "$($MyRegistration.Name) has $($configurationData.DomainJoinServer.$($Server).DSCConfiguration) applied skipping."
            }
        }
    }
}

function Compile-AzureDSCConfiguration
{
   [CmdletBinding()]
   param ([ValidateNotNull()] 
          [PSCustomObject]$configuration)
 
    $configurationData = Get-Content -Path $configuration -Raw|ConvertFrom-Json | Convert-PSObjectToHashtable
    $DCName = $configurationData.DomainJoinServer
    
    foreach ($Server in $configurationData.DomainJoinServer.Keys)
    {
      If ($configurationData.DomainJoinServer.$($Server).DSCConfiguration -eq "DomainConfig")
      {
          $MYDCIP = $(Get-AzureRmNetworkInterface -ResourceGroupName "$($configurationData.LabPrefix)_RG" | Where-Object {$_.Name -like "$Server*" }| Get-AzureRmNetworkInterfaceIpConfig | Select PrivateIPAddress).PrivateIPAddress
      }
    
    }

    foreach ($Server in $configurationData.domainJoinServer.Keys)
    {
        if ($configurationData.DomainJoinServer.$($Server).DSCConfiguration -like "*SQL*")
        {
            #Write-Verbose "Its SQL Config"
            $ConfigData =@{
                AllNodes = @(
  		            @{
  			          NodeName = $Server
                      PSDscAllowPlainTextPassword = $true
                      PSDscAllowDomainUser =$true
                      SQLInstanceName = "MSSQLSERVER"
                      WindowsBitsLocation = if ($configurationData.WindowsBitsLocation){$configurationData.WindowsBitsLocation} else{"\\$($configurationdata.LabPrefix)-DC\Sources\sxs"}
                      SQLServerBitsLocation = if ($configurationData.SQLServerBitsLocation){$configurationData.SQLServerBitsLocation} else {"\\$($configurationData.LabPrefix)-DC\"}
                      Features = if ($configurationData.Features) {$configurationData.Features} else {"SQLENGINE,IS"  }
                      SQLAdminAccount = if($configurationData.SQLAdminAccount){$configurationData.SQLAdminAccount} else{"$($configurationData.LabPrefix)\Administrator"}
                      SQLInstallSharedDir = if($configurationData.SQLInstallSharedDir) {$configurationData.SQLInstallSharedDir} else {"C:\Program Files\Microsoft SQL Server"}
                      InstallSharedWowDir = if($configurationData.InstallSharedWowDir) {$configurationData.InstallSharedWowDir} else {"C:\Program Files\Microsoft SQL Server"}
                      InstanceDir = if($configurationData.InstanceDir) {$configurationData.InstanceDir} else {"C:\Program Files\Microsoft SQL Server"}
                      InstallSQLDataDir = if($configurationData.InstallSQLDataDir) {$configurationData.InstallSQLDataDir} else {"C:\Program Files\Microsoft SQL Server"}
                      SQLUserDBDir = if ($configurationData.SQLUserDBDir) {$configurationData.SQLUserDBDir} else {"C:\Program Files\Microsoft SQL Server"}
                      SQLUserDBLogDir = if($configurationData.SQLUserDBLogDir) {$configurationData.SQLUserDBLogDir} else {"C:\Program Files\Microsoft SQL Server"}
                      SQLTempDBDir = if($configurationData.SQLTempDBLogDir) {$configurationData.SQLTempDBLogDir} else {"C:\Program Files\Microsoft SQL Server"}
                      SQLBackupDir = if($configurationData.SQLBackupDir) {$configurationData.SQLBackupDir} else {"C:\Program Files\Microsoft SQL Server\Backup"}
                      AzureCred = $configurationData.AzureCred
                      DomainName = $configurationData.DomainName
                      DomainExtention = $configurationData.DomainExtention
                      DNSIp = $MYDCIP
  		            }
  	            )
            }
        }
        if ($configurationData.DomainJoinServer.$($Server).DSCConfiguration -like "*Domain*")
        {
            #Write-Verbose "Its Domain Config"
              $ConfigData = @{
                AllNodes = @(
                        @{
                            NodeName = $Server
                            PSDscAllowPlainTextPassword = $true
                            PSDscAllowDomainUser =$true
                            DomainName = $configurationData.DomainName
                            DomainExtention = $configurationData.DomainExtention
                            AutomationRG = $configurationData.AzureAutomationRG
                            AutomationAcct = $configurationData.AzureAutomationAccount
                         }
                    )
              }
        }
   
        if ($configurationData.DomainJoinServer.$($Server).DSCConfiguration)
        {        
            Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationID -TenantId $configurationData.TenantID 
            
            $MyDSCConfig = Get-AzureRmAutomationDscConfiguration -ResourceGroupName $configurationData.AzureAutomationRG  -AutomationAccountName $configurationData.AzureAutomationAccount -Name $configurationData.DomainJoinServer.$($Server).DSCConfiguration -ErrorAction SilentlyContinue
      
            if ($MyDSCConfig)
              {
                $MyDSCConfigCompile = Get-AzureRmAutomationDscCompilationJob -ConfigurationName $MyDSCConfig.Name -ResourceGroupName $configurationData.AzureAutomationRG  -AutomationAccountName $configurationData.AzureAutomationAccount |select -Last 1 -ErrorAction SilentlyContinue
              }
            
              if($MyDSCConfigCompile.Status -ne "Completed")
              {
                  Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationID -TenantId $configurationData.TenantID 
            
                  $CompilationJob =  Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $configurationData.AzureAutomationRG  -AutomationAccountName $configurationData.AzureAutomationAccount -ConfigurationName $configurationData.DomainJoinServer.$($Server).DSCConfiguration -ConfigurationData $ConfigData
                  
                  $backOff = 1.75 # 0 seconds, 1 second, 4 seconds backoff delay
                  [Int]$LoopCnt = 1
                  
                  #Check status of DSC Complication and continue looping till done
                  $JobResult = ""
                  DO{
                      $retryDelay = [Math]::Ceiling(([Math]::pow( $LoopCnt, $backOff )))
                      $JobResult = Get-AzureRmAutomationDscCompilationJob -Id $CompilationJob.Id -ResourceGroupName $configurationData.AzureAutomationRG  -AutomationAccountName $configurationData.AzureAutomationAccount -ErrorAction SilentlyContinue
                      Start-Sleep -Seconds $retryDelay 
                      Write-Verbose "Waiting for $($retryDelay)sec for $($configurationData.DomainJoinServer.$($Server).DSCConfiguration) to Finish Compilation "
                      $LoopCnt++
                  }
                  UNTIL (($JobResult.Status -eq "Completed")  -or ($JobResult.Status -eq "Suspended"))
                  if ($JobResult.Status -ne "Completed")
                  {
                      Write-Warning "$($configurationData.DomainJoinServer.$($Server).DSCConfiguration) result was $($JobResult.Status)"
                  }
                  else
                  {
                      Write-verbose "$($configurationData.DomainJoinServer.$($Server).DSCConfiguration) result was $($JobResult.Status)"
                  }
             }
        }
    }
}


function New-AzureDSCConfigurations
{
   [CmdletBinding()]
   param ([ValidateNotNull()] 
          [PSCustomObject]$configuration)

    $configurationData = Get-Content -Path $configuration -Raw|ConvertFrom-Json | Convert-PSObjectToHashtable
    Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationID -TenantId $configurationData.TenantID 
    $DomainCred = Get-AzureRmAutomationCredential -Name "$($configurationData.DomainName)_Admin" -ResourceGroupName $configurationData.AzureAutomationRG `
                    -AutomationAccountName $configurationData.AzureAutomationAccount  -ErrorAction SilentlyContinue

    if (!$DomainCred)
    {
        $AdminCred = New-Cred -userName $configurationData.DomainAdminUser -userPass $configurationData.DomainAdminPass
        New-AzureRmAutomationCredential -Name "$($configurationData.DomainName)_Admin" -ResourceGroupName $configurationData.AzureAutomationRG `
             -AutomationAccountName $configurationData.AzureAutomationAccount -Value $AdminCred 
    }

    $FilePath = Join-Path -Path $configurationData.InstallLocation -ChildPath "Scripts\Configuration\AzureAutomation"
    $files = Get-ChildItem $FilePath 
    foreach ($File in $Files)
    {

        $SoucePath = Join-Path -Path $FilePath -ChildPath $File
        Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationID -TenantId $configurationData.TenantID 
        
        $MyDSCConfig = Get-AzureRmAutomationDscConfiguration -ResourceGroupName $configurationData.AzureAutomationRG  -AutomationAccountName $configurationData.AzureAutomationAccount -Name $File.BaseName -ErrorAction SilentlyContinue
        if (!$MyDSCConfig)
        {
            Write-verbose "Creating new configuration $($File.BaseName)"
            Import-AzureRmAutomationDscConfiguration -AutomationAccountName $configurationData.AzureAutomationAccount -ResourceGroupName $configurationData.AzureAutomationRG  -SourcePath $SoucePath -Published -Force        
        }
        else
        {Write-verbose "$($File.BaseName) exists skipping creation."}
    }
}

function Publish-AzureDSCModules
{
   [CmdletBinding()]
   param ([ValidateNotNull()] 
          [PSCustomObject]$configuration)
    
    $configurationData = Get-Content -Path $configuration -Raw|ConvertFrom-Json | Convert-PSObjectToHashtable

    $modulePath = Join-Path -Path $configurationData.InstallLocation -ChildPath "DSCResources\AzureAutomation"
    Login-AzurebyCert -CertSubject $configurationData.CertSubject -ApplicationId $configurationData.ApplicationID -TenantId $configurationData.TenantID 
    $MyRG = Get-AzureRmResourceGroup -Name $configurationData.AzureAutomationRG -Location $configurationData.Location -ErrorAction SilentlyContinue
    if (!$MyRG)
    {
        Write-verbose "Creating Resource Group $($configurationData.AzureAutomationRG)"
        New-AzureRmResourceGroup -Name $configurationData.AzureAutomationRG -Location $configurationData.Location
    }

    $AzureAutoAcct=Get-AzureRmAutomationAccount -Name $configurationData.AzureAutomationAccount -ResourceGroupName $configurationData.AzureAutomationRG -ErrorAction SilentlyContinue
    if(!$AzureAutoAcct)
    {
        Write-verbose "Creating AzureAutomation Account $($configurationData.AzureAutomationAccount)"
        New-AzureRmAutomationAccount -ResourceGroupName $configurationData.AzureAutomationRG -Name $configurationData.AzureAutomationAccount -Location $configurationData.Location 
    }
    else
    {
        Write-verbose "$($configurationData.AzureAutomationAccount) exists skipping creation."
    }


    #Substring is used here because there is a limit of 24 characaters 
    #ToLower is used because storage account require all lower case
    $MyStorage = Get-AzureRmStorageAccount -ResourceGroupName $configurationData.AzureAutomationRG  -Name "$($configurationData.AzureAutomationAccount.substring(0,17).ToLower())storage" -ErrorAction SilentlyContinue
    if (!$MyStorage) 
    {
        Write-verbose "Creating storage account $($configurationData.LabPrefix.ToLower())"
        $MyStorage = New-AzureRmStorageAccount -ResourceGroupName $configurationData.AzureAutomationRG   -Name "$($configurationData.AzureAutomationAccount.substring(0,17).ToLower())storage" -Location $configurationData.Location -SkuName "Standard_GRS"
    }
    else
    {
        Write-verbose "$($configurationData.AzureAutomationAccount.substring(0,17).ToLower())storage exists skipping creation."
    }
 
    $FilePath = Join-Path -Path $configurationData.InstallLocation -ChildPath "DSCResources\AzureAutomation"
    $files = Get-ChildItem $FilePath 
    foreach ($File in $Files)
    {
        $MyModule = Get-AzureRmAutomationModule -Name $File.BaseName -ResourceGroupName $configurationData.AzureAutomationRG -AutomationAccountName $configurationData.AzureAutomationAccount -ErrorAction SilentlyContinue
        if (!$MyModule)
        {
            $backOff = 1.75 # 0 seconds, 1 second, 4 seconds backoff delay
            [Int]$LoopCnt = 1
            $storagekey = $(Get-AzureRmStorageAccountKey -ResourceGroupName $configurationData.AzureAutomationRG -Name $MyStorage.StorageAccountName).ITEM(0).VALUE
            $storageContext = New-AzureStorageContext -StorageAccountName $MyStorage.StorageAccountName -StorageAccountKey $storagekey
            
            $MyContainer = Get-AzureStorageContainer -Name "$($configurationData.AzureAutomationRG.ToLower())dscmodules" -Context $storageContext -ErrorAction SilentlyContinue
            If (!$MyContainer)
            {
                Write-verbose "Creating container $("$($configurationData.AzureAutomationRG.ToLower())dscmodulesstorage")"
                $MyContainer = New-AzureStorageContainer -Name "$($configurationData.AzureAutomationRG.ToLower())dscmodules" -Context $storageContext -Permission Blob
            }
            else
            {
                Write-verbose "$("$($configurationData.AzureAutomationRG.ToLower())dscmodulesstorage") exists skipping creation."
            }
            $blobcontent = Set-AzureStorageBlobContent -File $file.FullName -Container $MyContainer.Name -Context $storageContext -Force
            $contentLink = "$($blobcontent.Context.BlobEndPoint)$($MyContainer.Name)/$($file.Name)"
            $module = New-AzureRMAutomationModule -AutomationAccountName $configurationData.AzureAutomationAccount -ResourceGroupName $configurationData.AzureAutomationRG  -Name $file.BaseName -ContentLink $contentLink 
            while(($module.ProvisioningState -ne 'Succeeded') -and ($module.ProvisioningState -ne 'Failed'))
            {
                $retryDelay = [Math]::Ceiling(([Math]::pow( $LoopCnt, $backOff )))
                Start-Sleep -Seconds $retryDelay
                $module = $module | Get-AzureRmAutomationModule
                Write-Verbose "Waiting for $($retryDelay)sec for $($File.BaseName) to Finish Compilation "
                $LoopCnt++
            }
            Write-Verbose "$($module.name) provisioning $($module.ProvisioningState)"

        }
        else 
        {Write-Verbose "$($File.BaseName) exists skipping Upload"}
    }
}

Export-ModuleMember -Function 'Stop-LabinaBox', 'Start-LabinaBox', 'CheckPoint-LabinaBox', 'Remove-LabinaBoxSnapshot', 'Remove-LabinaBox', 'New-LabinaBox',`
					'New-LabVM', 'Update-LabinaBox', 'New-DSCDataDrivenSQL', 'Add-ServerConfigtoQueue', 'New-AzureCertAuthentication',`
					'Login-AzurebyCert', 'New-AzureLab', 'Remove-AzureLab', 'Set-AzureDSCNodeConfigurations','Remove-AzureDSCNodeConfigurations', 'New-AzureDSCConfigurations',`
					'Convert-PSObjectToHashtable', 'Publish-AzureDSCModules', 'Get-ScriptDirectory', 'New-LIABAzureNetwork', 'Compile-AzureDSCConfiguration'


