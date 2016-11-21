    param ( 
        [Parameter(Mandatory)] 
        [string]$ParentFolderPathSource,
        
        [Parameter(Mandatory)] 
        [string]$ParentFolderPath,
 
        [Parameter(Mandatory)] 
        [string]$DSCResourceSource,
        
        [Parameter(Mandatory)] 
        [string]$DSCResourceDest
    ) 
#Ensure all the Directories and Resources required to configure the Host are present
Configuration ResourceSetup { 
    param ( 
        [Parameter(Mandatory)] 
        [string]$ParentFolderPathSource,
        
        [Parameter(Mandatory)] 
        [string]$ParentFolderPath,
 
        [Parameter(Mandatory)] 
        [string]$DSCResourceSource,
 
        [Parameter(Mandatory)] 
        [string]$DSCResourceDest
    ) 
    Import-DscResource –ModuleName PSDesiredStateConfiguration

    File DSCResources
    {
        Type = "Directory"
        Ensure = "Present"
        Recurse = $true
        Checksum = "modifiedDate"
        SourcePath = $DSCResourceSource
        DestinationPath = $DSCResourceDest
        MatchSource = $true
    }
    File ParentFolder
    {
        Type = 'Directory' 
        Ensure = 'Present'
        Recurse = $true
        Checksum = "modifiedDate"
        SourcePath = $ParentFolderPathSource
        DestinationPath = $ParentFolderPath
        Force = $true
    }
    File ChildFolder
    {
        Type = 'Directory' 
        Ensure = 'Present'
        DestinationPath = $ChildFolderPath
        Force = $true
        DependsOn = '[File]ParentFolder'
    }
    
    File DomainJoin
    {
        Type = 'Directory' 
        Ensure = 'Present'
        DestinationPath = $DomainJoinPath 
        Force = $true
        DependsOn = '[File]ParentFolder'
    }
}
ResourceSetup -ParentFolderPathSource $ParentFolderPathSource -ParentFolderPath $ParentFolderPath -DSCResourceSource $DSCResourceSource -DSCResourceDest $DSCResourceDest -OutputPath $ParentFolderPath
Start-DscConfiguration -Wait -Path $ParentFolderPath -Verbose -Force