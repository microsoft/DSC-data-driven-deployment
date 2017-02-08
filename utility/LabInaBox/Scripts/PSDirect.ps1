$MachineName = "LD-LSQL1"
$cred = Get-Credential

$s = New-PSSession -VMName $MachineName -Credential $Cred

Copy-Item -Path "D:\hv-rhel7.zip" -Destination "C:\" -ToSession $s
Invoke-Command -Session


Enter-PSSession -Session $s