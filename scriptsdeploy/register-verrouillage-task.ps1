$ErrorActionPreference = "Stop"

$ScriptPath = "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
$TaskName = "MobileSLI SERVEXPE Verrouillage 22h35"

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

$Trigger = New-ScheduledTaskTrigger -Daily -At "22:35"

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "Déclenche le verrouillage SERVEXPE à 22:35" `
    -Force

Write-Host "Tâche planifiée créée ou mise à jour : $TaskName"
