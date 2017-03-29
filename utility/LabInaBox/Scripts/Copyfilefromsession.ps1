$Cred = Get-Credential
$Session = New-PSSession -VMName DD-DSC -Credential $Cred

Copy-Item -Path c:\Schedtask.ps1 -Destination D:\ -FromSession $Session