$Cred = Get-Credential
$Session = New-PSSession -VMName DD-DC -Credential $Cred

$Session
Copy-Item -Path D:\Users\TroyAult\Downloads\SSMS-Setup-ENU.exe -Destination c:\ -ToSession $Session