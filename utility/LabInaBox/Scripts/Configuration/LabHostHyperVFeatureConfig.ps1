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
            ActionAfterReboot = 'ContinueConfiguration'  
            RefreshMode = 'Push'
            RebootNodeIfNeeded = $True    
        }
    }
}
LCM_Push -ComputerName localhost -OutputPath C:\Mof 
Set-DSCLocalConfigurationManager -cimsession localhost -Path C:\Mof -Verbose -force

Configuration HyperV_Feature { 
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xHyper-V
    Import-DscResource -ModuleName xComputerManagement
    
    #ProductType is workstation if not win10 this will fail
    if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1)
    {
        Script ClientHyperVConfiguration
        {
            GetScript = { 
                $state = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select-Object -Property State
                @{ Result  = "State: $($state.State)" }
            }          
            TestScript = { 
                $featureState = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select-Object -Property State)
                $state = $false
                if ($featureState.State -eq [Microsoft.Dism.Commands.FeatureState]::Enabled)
                {
                    $state = $true
                }
                return $state
            }
            SetScript = { 
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
            }
        }

        Log AfterHyperVConfiguration
        {
            Message = 'Finished running AfterClientHyperVConfiguration Script resource'          
            DependsOn = '[Script]ClientHyperVConfiguration'
        }
    }

    #Assumption you are running Server edition, If not and its not HyperV platform script will fail
    else
    {
        WindowsFeature 'Hyper-V' 
        {
            Ensure='Present'
            Name='Hyper-V'
        }

        Log AfterHyperVConfiguration
        {
            Message = 'Finished running AfterClientHyperVConfiguration Script resource'          
            DependsOn = '[WindowsFeature]Hyper-V'
        }
    }
}

HyperV_Feature -OutputPath $ParentFolderPath
Start-DscConfiguration -Wait -Path $ParentFolderPath -Verbose -Force 