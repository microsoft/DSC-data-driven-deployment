#Requires -RunAsAdministrator

$LabConfig = 'D:\LabInaBox\Examples\DemoConfig.json'

Import-Module -name D:\LabInaBox\modules\LabinaBox.psm1
New-LabinaBox -configuration $LabConfig
Stop-LabinaBox -configuration $LabConfig
Start-LabinaBox -configuration $LabConfig
CheckPoint-LabinaBox -configuration $LabConfig
Remove-LabinaBoxSnapshot -configuration $LabConfig
Remove-LabinaBox -configuration $LabConfig