    param(        [PSCustomObject]
                  $configuration
    )

#Ensure all the Directories and Resources required to configure the Host are present
Configuration ResourceSetup { 
    param(        [PSCustomObject]
                  $configuration
    )
    Import-DscResource –ModuleName PSDesiredStateConfiguration

    File xHyperV
    {
        Type = "Directory"
        Ensure = "Present"
        Recurse = $true
        Checksum = "modifiedDate"
        SourcePath = "$($configuration.DSCResourceSource)\xHyper-V"
		DestinationPath = "C:\Program Files\WindowsPowerShell\Modules\xHyper-V"
        MatchSource = $true
	}
	File xComputerManagement
	{
		Type = "Directory"
		Ensure = "Present"
		Recurse = $true
		Checksum = "modifiedDate"
		SourcePath = "$($configuration.DSCResourceSource)\xComputerManagement"
		DestinationPath = "C:\Program Files\WindowsPowerShell\Modules\xComputerManagement"
		MatchSource = $true
	}
	File ParentFolder
    {
        Type = 'Directory' 
        Ensure = 'Present'
        DestinationPath =$configuration.ParentFolderPath
        Force = $true
    }
    File ChildFolder
    {
        Type = 'Directory' 
        Ensure = 'Present'
        DestinationPath = $configuration.ChildFolderPath
        Force = $true
        DependsOn = '[File]ParentFolder'
    }
    
    File DomainJoin
    {
        Type = 'Directory' 
        Ensure = 'Present'
        DestinationPath = $configuration.DomainJoinPath 
        Force = $true
        DependsOn = '[File]ParentFolder'
    }
}
ResourceSetup -Configuration $configuration -OutputPath $configuration.ParentFolderPath
Start-DscConfiguration -Wait -Path $configuration.ParentFolderPath -Verbose -Force