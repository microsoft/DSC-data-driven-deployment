param( [Parameter(Mandatory)] 
       [string]$VMName,  
       [Parameter(Mandatory)] 
       [string]$SysPrepImage,    
       [PSCustomObject]
       $configuration
)
[DSCLocalConfigurationManager()]
Configuration LCM_Push
{    
    Param(
        [string[]]$ComputerName
    )
    Node $ComputerName
    {
    Settings
        {
            AllowModuleOverwrite = $True
            ConfigurationMode = 'ApplyOnly'
            RefreshMode = 'Push'
            RebootNodeIfNeeded = $True    
        }
    }
}
LCM_Push -ComputerName localhost -OutputPath C:\Mofs

Set-DSCLocalConfigurationManager -cimsession localhost -Path C:\Mofs -Verbose
Configuration HyperV_CreateVM { 
    param([Parameter(Mandatory)] 
          [string]$VMName, 
          [Parameter(Mandatory)] 
          [string]$SysPrepImage, 
          [PSCustomObject]
          $configuration
    )
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xHyper-V -ModuleVersion 3.5.0.0
    Import-DscResource -ModuleName xComputerManagement -ModuleVersion 1.8.0.0

    xVMSwitch switch {
        Name = $configuration.SwitchName
        Ensure = 'Present'
        Type = 'Private'
    }
    
    xVHD DiffVHD { 
        Ensure = 'Present' 
        Name = $VMName 
        Path = $Configuration.ChildFolderPath
        ParentPath = "$($Configuration.ParentFolderPath)\$SysPrepImage"
        Generation = 'vhdx' 
    } 
 
    xVMHyperV CreateVM { 
        Name = $VMName 
        SwitchName = $Configuration.SwitchName
        VhdPath = Join-Path -Path $Configuration.ChildFolderPath -ChildPath "\$VMName.vhdx" 
        Path = $Configuration.ChildFolderPath
        SecureBoot = $false
        ProcessorCount = 2
        MaximumMemory = 2GB
        MinimumMemory = 2GB
        RestartIfNeeded = $true
        DependsOn = '[xVHD]DiffVHD'
        State = 'Running'
        Generation = 2
    } 
}
HyperV_CreateVM -VMName $VMName -Configuration $configuration -SysPrepImage $SysPrepImage -OutputPath C:\Mof
Start-DscConfiguration -Wait -Path C:\Mof -Verbose -Force