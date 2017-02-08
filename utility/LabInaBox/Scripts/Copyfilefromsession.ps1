$Cred = Get-Credential
$Session = New-PSSession -VMName DD-Dev -Credential $Cred

Copy-Item -Path c:\DSCCentral.dacpac -Destination D:\ -FromSession $Session