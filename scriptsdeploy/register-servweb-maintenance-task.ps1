# ============================================================
# Enregistrement tache planifiee de maintenance SERVWEB
# ============================================================
# La tache execute maintenance-servweb-runtime.ps1 tous les jours.
# ============================================================

param(
    [string]$SourceScriptPath = "C:\Sources\servewebEXPE\scriptsdeploy\maintenance-servweb-runtime.ps1",
    [string]$DeployScriptPath = "C:\Services\MobileSLI.Expedition.Web\scripts\maintenance-servweb-runtime.ps1",
    [string]$TaskName = "MobileSLI SERVWEB Maintenance quotidienne",
    [string]$RunAt = "04:10"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

if (-not (Test-Path $SourceScriptPath)) {
    throw "Script source introuvable : $SourceScriptPath"
}

$deployDirectory = Split-Path -Path $DeployScriptPath -Parent
Ensure-Directory -Path $deployDirectory

Copy-Item -Path $SourceScriptPath -Destination $DeployScriptPath -Force

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$DeployScriptPath`""

$trigger = New-ScheduledTaskTrigger -Daily -At $RunAt

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Maintenance autonome SERVWEB : status local, rotation logs, purge backups." `
    -Force

Write-Host "Tache planifiee creee ou mise a jour : $TaskName"
Write-Host "Horaire : $RunAt"
Write-Host "Script deploye : $DeployScriptPath"

Get-ScheduledTask -TaskName $TaskName | Select-Object TaskName, State
Get-ScheduledTaskInfo -TaskName $TaskName | Select-Object LastRunTime, LastTaskResult, NextRunTime
