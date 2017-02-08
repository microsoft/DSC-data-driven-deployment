#Requires -RunAsAdministrator
$start = Get-Date
Write-Output -Message "Lab Creation began at: $start"

$DDConfig = 'D:\LabInaBox\Examples\DD-Config.json'
$LDConfig = 'D:\LabInaBox\Examples\LD-Config.json'
$DDSQLConfig = 'D:\LabInaBox\Examples\DD-SQLConfig.json'

Import-Module -name D:\LabInaBox\modules\LabinaBox.psm1

New-LabinaBox -configuration $DDConfig -Verbose
#CheckPoint-LabinaBox -configuration $DDConfig

New-DSCDataDrivenSQL -configuration $DDConfig -SQLconfiguration $DDSQLConfig -Verbose
Add-ServerConfigtoQueue -configuration $DDConfig -SQLconfiguration $DDSQLConfig -Verbose


#Update-LabinaBox -configuration $DDConfig -Verbose
#Stop-LabinaBox -configuration $DDConfig
#Start-LabinaBox -configuration $DDConfig
#Remove-LabinaBoxSnapshot -configuration $DDConfig
#Remove-LabinaBox -configuration $DDConfig

$end = Get-Date
$diff = $end -$start
Write-Output -Message "Completed lab build @ $($end.ToLongTimeString())"
Write-Output -Message "Time to build lab: $("{0:N2}" -f ($diff.TotalMinutes)) minutes"