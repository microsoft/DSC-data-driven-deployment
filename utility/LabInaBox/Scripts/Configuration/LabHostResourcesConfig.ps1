    param(        [PSCustomObject]
                  $configuration
    )

#Ensure all the Directories and Resources required to configure the Host are present
Configuration ResourceSetup { 
    param(        [PSCustomObject]
                  $configuration
    )
    Import-DscResource –ModuleName PSDesiredStateConfiguration

    File DSCResources
    {
        Type = "Directory"
        Ensure = "Present"
        Recurse = $true
        Checksum = "modifiedDate"
        SourcePath = $configuration.DSCResourceSource
        DestinationPath = $configuration.DSCResourceDest
        MatchSource = $true
    }
    File ParentFolder
    {
        Type = 'Directory' 
        Ensure = 'Present'
        Recurse = $true
        Checksum = "modifiedDate"
        SourcePath = $configuration.ParentFolderPathSource
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