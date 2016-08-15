# Set Global Module Verbose
$VerbosePreference = 'Continue' 

function Invoke-StoredProcedure{
        [CmdletBinding()]
        param ( 
        [ValidateNotNull()] 
        $storedProcName,  
        [ValidateNotNull()] 
        [hashtable] $parameters=@{},
        [hashtable] $outparams=@{},
        [ValidateNotNull()] 
        $conn,[switch]$help)

        function Put-OutputParameters($cmd, $outparams){
            foreach($outp in $outparams.Keys){
                $cmd.Parameters.Add("@$outp", (Get-Paramtype $outparams[$outp])).Direction=[System.Data.ParameterDirection]::Output
            }
        }
        function Get-OutputParameters($cmd,$outparams){
            foreach($p in $cmd.Parameters){
                if ($p.Direction -eq [System.Data.ParameterDirection]::Output){
                $outparams[$p.ParameterName.Replace("@","")]=$p.Value
                }
            }
        }

        $close=($conn.State -eq [System.Data.ConnectionState]'Closed')
        if ($close) {
           $conn.Open()
        }

        $cmd=New-Object System.Data.SqlClient.SqlCommand($sql,$conn)
        $cmd.CommandType=[System.Data.CommandType]'StoredProcedure'
        $cmd.CommandText=$storedProcName
        foreach($p in $parameters.Keys){
            $cmd.Parameters.AddWithValue("@$p",[string]$parameters[$p]).Direction=
                  [System.Data.ParameterDirection]::Input
        }

        Put-OutputParameters $cmd $outparams
        $ds=New-Object System.Data.DataSet
        $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        [Void]$da.fill($ds)
        $open=($conn.State -eq [System.Data.ConnectionState]'Open')
        if ($open) {
           $conn.Close()
        }
        Get-OutputParameters $cmd $outparams

        return @{data=$ds;outputparams=$outparams}
    }

function Add-PSCredential {
[CmdletBinding()]
        param ( $Credential = (Get-Credential), 
                
                [ValidateNotNull()] 
                [System.String]
                $CredName, 
                
                [ValidateNotNull()] 
                [System.String]
                $SQLServer)
        Try
        {
            # Look at the object type of the $Credential parameter to determine how to handle it
            switch ( $Credential.GetType().Name ) {
                    PSCredential            { continue }
                    String                          { $Credential = Get-Credential -credential $Credential }
                    default                         { Throw "You must specify a credential object to export to disk." }
            }

            $export = "" | Select-Object Username, EncryptedPassword
            $export.PSObject.TypeNames.Insert(0,’ExportedPSCredential’)
            
            $UserName = $Credential.Username
       
            # Encrypt SecureString password using Data Protection API
            # Only the current user account can decrypt this cipher
            $export.EncryptedPassword = $Credential.Password | ConvertFrom-SecureString

            $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
            Write-Verbose -Message "Connecting to $connString"
            Invoke-StoredProcedure -storedProcName "dbo.NewCred" -parameters @{CredName=$CredName;UserName=$UserName ;Password=$export.EncryptedPassword} -conn $connString

            Write-Verbose "Credentials saved to: $SQLServer"
        }
        Catch
        {Write-Error "Error saving Credentials to: $SQLServer"}
}

function Get-PSCredential{
[CmdletBinding()]
        param (
                [ValidateNotNull()] 
                [System.String]
                $UserName, 
                
                [ValidateNotNull()] 
                [System.String]
                $Password)
                Try
                {
                    $SecurePass = $Password | ConvertTo-SecureString
                    $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecurePass 
                    Return $Credential
                }
                Catch
                {Write-Error "Error Converting Password to SecureString"}
}

Function Get-Cert 
{ 
[CmdletBinding()]
    Param 
    ( 
        [System.String]$RemoteMachine, 
        [System.String]$SaveLocation = "F:\publicKeys" 
    ) 
    if (!(Test-Path $SaveLocation))
    {
        New-Item -path $SaveLocation -type Directory
    }
    $CertStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList  "\\$($RemoteMachine)\My", "LocalMachine" 
    $CertStore.Open('ReadOnly') 
    $certificate  = $CertStore.Certificates | Where-Object {$_.EnhancedKeyUsageList.friendlyName -eq "Document Encryption"} 
    If ($certificate)
    {
        [byte[]]$Bytes  = $certificate.Export('Cert') 
        [string]$SaveLiteralPath = "$SaveLocation\$RemoteMachine.$env:UserDNSDomain.cer" 
        Remove-Item -Path $SaveLiteralPath -Force -ErrorAction Ignore 
        Set-Content -Path $SaveLiteralPath -Value $Bytes -Encoding Byte -Force | out-null 
    }
    Else
    {Write-Error "No Certificates exist with Document Encryption Property on $RemoteMachine"}
}


function Convert-HashToJson
{
    [CmdletBinding()]
    Param
    (   
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Hash
    )

    $paramCustomObject = New-Object –TypeName PSObject -Property $Hash
    $paramSerializedAsJson = $paramCustomObject | ConvertTo-Json
    Return $paramSerializedAsJson
}

function Convert-PSObjectToJson
{
    [CmdletBinding()]
    Param
    (   
        [Parameter(Mandatory=$true)]
        [PSCustomObject]
        $InputObject
    )

    $paramSerializedAsJson = $InputObject | ConvertTo-Json
    Return $paramSerializedAsJson
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
 
            Write-Output -NoEnumerate $collection
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

function Convert-JSONtoHash
{
    [CmdletBinding()]
    Param
    (   
        [Parameter(Mandatory=$true)]
        [System.string]
        $InputObject
    )
    $InputObjectRehydratedAsPSCustomObj = $InputObject | ConvertFrom-Json
    $InputObjectRehydratedAsHash = Convert-PSObjectToHashtable $InputObjectRehydratedAsPSCustomObj
    return  $InputObjectRehydratedAsHash
}

function Add-NewConfigurationToQueue
{
    [CmdletBinding()]
    Param
    (
        [ValidateNotNull()] 
        [PSCustomObject]
        $Configuration,
        
        [ValidateNotNull()] 
        [System.String]
        $SQLServer
    )

        $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
        Write-Verbose -Message "Connecting to $connString"
        $JSONConfig =Convert-PSObjectToJson -InputObject $Configuration
        $output = Invoke-StoredProcedure -storedProcName "dbo.EnqueueConfiguration" -parameters @{Configuration=$JSONConfig} -conn $connString
}

Function Add-NewDefaultConfiguration
{ 
[CmdletBinding()]
   param (
           [ValidateNotNull()] 
           [System.String]
           $Name, 
           [ValidateNotNull()] 
           [PSCustomObject]
           $Value, 
           [ValidateNotNull()] 
           [System.String]
           $SQLServer)
        
        $JSONDefault = $Value | ConvertTo-Json
        $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
        Write-Verbose -Message "Connecting to $connString"
        $output = Invoke-StoredProcedure -storedProcName "dbo.NewDefault" -parameters @{Name=$Name;Value=$JSONDefault} -conn $connString
}

Function Get-ConfigurationfromQueue
{ 
[CmdletBinding()]
   param (
           [ValidateNotNull()] 
           [System.String]
           $BatchSize, 
           
           [ValidateNotNull()] 
           [System.String]
           $SQLServer)

        $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
        Write-Verbose -Message "Connecting to $connString"
        $output = Invoke-StoredProcedure -storedProcName "dbo.DequeueConfiguration" -parameters @{BatchSize=$BatchSize;} -conn $connString
        if($output.data.tables.configuration)
        {$JSONConfig =Convert-JsontoHash -InputObject $output.data.tables.configuration
         $JSONConfig.add('ConfigurationQueueID',$output.data.tables.rows.ConfigurationQueueID)
        }
        Else{$JSONConfig = $False}
        return @($JSONConfig)
}

Function Get-ConfigurationToProcess
{ 
   [CmdletBinding()]
   param (     
           [ValidateNotNull()] 
           [System.String]
           $SQLServer)
        
        $BatchSize =1

        $RehydratedConfig=Get-ConfigurationfromQueue -BatchSize $BatchSize -SQLServer $SQLServer
        If (!$RehydratedConfig)
        {
            RETURN @($False)
        }
        $ConfigurationDatafromDB = [Hashtable]@{}
        $ParentConfig = Get-ConfigurationfromDB -ConfigName $RehydratedConfig.Configuration -SQLServer $SQLServer
        $ConfigurationScriptDetails = Get-ConfigurationScriptDetails -ConfigName $RehydratedConfig.Configuration -SQLServer $SQLServer
        $ConfigurationDatafromDB.Add("ScriptName",$ConfigurationScriptDetails.ScriptName)
        $ConfigurationDatafromDB.Add("ScriptPath",$ConfigurationScriptDetails.ScriptPath)
        $ConfigurationDatafromDB.Add("ConfigurationQueueID",$RehydratedConfig.ConfigurationQueueID)
        $ConfigurationDatafromDB.Add("AllNodes",@())
        $ConfigCredOut =Get-CredentialsforConfiguration -SQLServer $SQLServer -ConfigName $RehydratedConfig.Configuration

        Foreach ($Row in $ConfigCredOut)
        {
                $Credential = Get-PSCredential -UserName $Row.Username -Password $Row.Password
                $ParentConfig.Add($Row.CredName,$Credential)
        }
        
        $parentConfig.Add("NodeName","*")
        $ConfigurationDatafromDB.AllNodes += $parentConfig
      
        foreach ($Node in $RehydratedConfig.NodeName)
        {
           
           $NodeConfigfromDB =Get-NodeConfigurationfromDB -NodeName $Node -ConfigName $RehydratedConfig.Configuration -SQLServer $SQLServer
           $NodeConfigfromDB.Add("NodeName",$Node)
           $NodeCredOut = Get-CredentialsforNode -SQLServer $SQLServer -ConfigName $RehydratedConfig.Configuration -NodeName $Node
           Foreach ($Row in $NodeCredOut)
           {
                   $Credential = Get-PSCredential -UserName $Row.Username -Password $Row.Password
                   $NodeConfigfromDB.Add($Row.CredName,$Credential)
           }


           $ConfigurationDatafromDB.AllNodes += $NodeConfigfromDB
        }

        RETURN @($ConfigurationDatafromDB)
}

Function Get-CredentialsforConfiguration
{ 
   [CmdletBinding()]
   param (     
           [ValidateNotNull()] 
           [System.String]
           $SQLServer,
           
           [ValidateNotNull()] 
           [System.String]
           $ConfigName )
        
            $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
            Write-Verbose -Message "Connecting to $connString"
            $output = Invoke-StoredProcedure -storedProcName "[dbo].[GetCredsforConfig]" -parameters @{ConfigurationName=$ConfigName;} -conn $connString
            
            return $output.data.tables.rows
}

Function Get-CredentialsforNode
{ 
   [CmdletBinding()]
   param (     
           [ValidateNotNull()] 
           [System.String]
           $SQLServer,
           
           [ValidateNotNull()] 
           [System.String]
           $NodeName,
           
           [ValidateNotNull()] 
           [System.String]
           $ConfigName )
        
        $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
        Write-Verbose -Message "Connecting to $connString"
        $output = Invoke-StoredProcedure -storedProcName "[dbo].[GetCredsforNode]" -parameters @{NodeName=$NodeName;ConfigurationName=$ConfigName;} -conn $connString
        Return $output.data.tables.rows          
}

Function Get-NodeConfigurationfromDB
{ 
[CmdletBinding()]
   param (
           [ValidateNotNull()] 
           [System.String]
           $NodeName, 

           [ValidateNotNull()] 
           [System.String]
           $ConfigName, 
           
           [ValidateNotNull()] 
           [System.String]
           $SQLServer)

        $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
        Write-Verbose -Message "Connecting to $connString"
        $output = Invoke-StoredProcedure -storedProcName "dbo.GetNodeConfiguration" -parameters @{NodeName=$NodeName;ConfigurationName=$ConfigName;} -conn $connString
        if($output.data.tables.Payload)
        {$JSONConfig =Convert-JsontoHash -InputObject $output.data.tables.Payload}
        Else{$JSONConfig = 0}
        return @($JSONConfig)
}

Function Get-ConfigurationfromDB
{ 
[CmdletBinding()]
   param (
           [ValidateNotNull()] 
           [System.String]
           $ConfigName, 
           
           [ValidateNotNull()] 
           [System.String]
           $SQLServer)

        $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
        Write-Verbose -Message "Connecting to $connString"
        $output = Invoke-StoredProcedure -storedProcName "dbo.GetConfiguration" -parameters @{ConfigName=$ConfigName;} -conn $connString
        if($output.data.tables.Payload)
        {$JSONConfig =Convert-JsontoHash -InputObject $output.data.tables.Payload}
        Else{$JSONConfig = $False}
        return @($JSONConfig)
}

Function Get-ConfigurationScriptDetails
{ 
[CmdletBinding()]
   param (
           [ValidateNotNull()] 
           [System.String]
           $ConfigName, 
           
           [ValidateNotNull()] 
           [System.String]
           $SQLServer)

        $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
        Write-Verbose -Message "Connecting to $connString"
        $output = Invoke-StoredProcedure -storedProcName "dbo.GetConfigurationScript" -parameters @{ConfigName=$ConfigName;} -conn $connString

        return @($output.data.tables.rows)
}

Function Update-ConfigurationStatus 
{ 
[CmdletBinding()]
   param (
           [ValidateNotNull()]
           [ValidateSet($True,$False)] 
           [System.String]
           $Success, 
           [ValidateNotNull()]
           [System.String]
           $ConfigurationQueueID,
           [ValidateNotNull()]
           [System.String]
           $SQLServer)

        $connString = "Data Source=$SQLServer;Initial Catalog=DSCCentral;Integrated Security=True"
        Write-Verbose -Message "Connecting to $connString"
        if ($Success){$output = Invoke-StoredProcedure -storedProcName "dbo.ConfigProcessedWithSuccess" -parameters @{ConfigurationQueueID=$ConfigurationQueueID;} -conn $connString}
        else{$output = Invoke-StoredProcedure -storedProcName "dbo.ConfigProcessedWithFailure" -parameters @{ConfigurationQueueID=$ConfigurationQueueID;} -conn $connString}

        
        return @($output.data.tables.rows)
}


