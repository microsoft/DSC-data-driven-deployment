    param ( 
        [Parameter(Mandatory)] 
        [string]$VMName,
        
        [Parameter(Mandatory)] 
        [string]$ChildFolderPath,
 
        [Parameter(Mandatory)] 
        [string]$ParentFolderPath,
        
        [Parameter(Mandatory)] 
        [string]$sysPrepDriveName,
        
        [Parameter(Mandatory)] 
        [string]$VMSwitchName
    ) 

Configuration HyperV_CreateVM { 
 
    param ( 
        [Parameter(Mandatory)] 
        [string]$VMName,
        
        [Parameter(Mandatory)] 
        [string]$ChildFolderPath,
 
        [Parameter(Mandatory)] 
        [string]$ParentDisk,
        
        [Parameter(Mandatory)] 
        [string]$VMSwitchName
    ) 

    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xHyper-V -ModuleVersion 3.5.0.0
    Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.8.0.0

    xVMSwitch switch {
        Name = $VMSwitchName
        Ensure = 'Present'
        Type = 'Private'
    }
    
    xVHD DiffVHD { 
        Ensure = 'Present' 
        Name = $VMName 
        Path = $ChildFolderPath
        ParentPath = $ParentDisk
        Generation = 'vhdx' 
    } 
 
    xVMHyperV CreateVM { 
        Name = $VMName 
        SwitchName = $VMSwitchName
        VhdPath = Join-Path -Path $ChildFolderPath -ChildPath "\$VMName.vhdx" 
        Path = $ChildFolderPath
        ProcessorCount = 2
        MaximumMemory = 4GB
        MinimumMemory =1GB
        RestartIfNeeded = $true
        DependsOn = '[xVHD]DiffVHD'
        State = 'Running'
        Generation = 2
    } 
}
HyperV_CreateVM -VMName $VMName -ChildFolderPath $ChildFolderPath -ParentDisk "$ParentFolderPath\$sysPrepDriveName" -VMSwitchName $SwitchName -OutputPath $ParentFolderPath
Start-DscConfiguration -Wait -Path $ParentFolderPath -Verbose -Force