$Cred = Get-Credential
$Session = New-PSSession -VMName FCIDSC -Credential $Cred


Copy-Item -Path D:\xSQLServer-fix-cluster-bugs.zip -Destination c:\ -ToSession $Session