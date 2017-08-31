#Requires -RunAsAdministrator
$start = Get-Date
Write-Output -Message "Lab Creation began at: $start"

$Config = 'D:\LabInaBox\Examples\DSC-Test.json'
$SQLConfig = 'D:\LabInaBox\Examples\DD-SQLConfig.json'

Import-Module -name D:\LabInaBox\modules\LabinaBox.psm1

New-LabinaBox -configuration $Config -Verbose
#CheckPoint-LabinaBox -configuration $DDConfig

#New-DSCDataDrivenSQL -configuration $DDConfig -SQLconfiguration $DDSQLConfig -Verbose
#Add-ServerConfigtoQueue -configuration $DDConfig -SQLconfiguration $DDSQLConfig -Verbose


Update-LabinaBox -configuration $Config -Verbose
#Stop-LabinaBox -configuration $Config
#Start-LabinaBox -configuration $Config
#Remove-LabinaBoxSnapshot -configuration $Config
#Remove-LabinaBox -configuration $Config

$end = Get-Date
$diff = $end -$start
Write-Output -Message "Completed lab build @ $($end.ToLongTimeString())"
Write-Output -Message "Time to build lab: $("{0:N2}" -f ($diff.TotalMinutes)) minutes"