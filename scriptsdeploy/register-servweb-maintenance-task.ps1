# ============================================================
# Enregistrement tache planifiee de maintenance SERVWEB
# ============================================================
# La tache execute maintenance-servweb-runtime.ps1 tous les jours.
# Execution sous SYSTEM pour ne pas dependre d'une session utilisateur.
# ============================================================

param(
    [string]$SourceScriptPath = "C:\Sources\servewebEXPE\scriptsdeploy\maintenance-servweb-runtime.ps1",
    [string]$DeployScriptPath = "C:\Services\MobileSLI.Expedition.Web\scripts\maintenance-servweb-runtime.ps1",
    [string]$TaskName = "MobileSLI SERVWEB Maintenance quotidienne",
    [string]$RunAt = "04:10"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Message
    Write-Host "============================================================"
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Assert-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        throw "Ce script doit etre execute dans PowerShell en administrateur."
    }
}

function Invoke-SchtasksChecked {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & schtasks.exe @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "schtasks.exe a echoue. Code=$LASTEXITCODE Arguments=$($Arguments -join ' ')"
    }
}

Write-Step "Verification droits administrateur"
Assert-Admin

Write-Step "Verification script source"
if (-not (Test-Path $SourceScriptPath)) {
    throw "Script source introuvable : $SourceScriptPath"
}

Write-Host "Source : $SourceScriptPath"
Write-Host "Cible  : $DeployScriptPath"

Write-Step "Copie du script de maintenance dans le dossier deploye"
$deployDirectory = Split-Path -Path $DeployScriptPath -Parent
Ensure-Directory -Path $deployDirectory
Copy-Item -Path $SourceScriptPath -Destination $DeployScriptPath -Force

if (-not (Test-Path $DeployScriptPath)) {
    throw "Script deploye introuvable apres copie : $DeployScriptPath"
}

Write-Host "Script deploye : $DeployScriptPath"

Write-Step "Creation ou mise a jour de la tache planifiee"
$taskCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$DeployScriptPath`""

Invoke-SchtasksChecked -Arguments @(
    "/Create",
    "/TN", $TaskName,
    "/TR", $taskCommand,
    "/SC", "DAILY",
    "/ST", $RunAt,
    "/RU", "SYSTEM",
    "/RL", "HIGHEST",
    "/F"
)

Write-Step "Tache planifiee enregistree"
Write-Host "Nom     : $TaskName"
Write-Host "Horaire : $RunAt"
Write-Host "Compte  : SYSTEM"
Write-Host "Action  : $taskCommand"

Write-Step "Verification de la tache"
Invoke-SchtasksChecked -Arguments @(
    "/Query",
    "/TN", $TaskName,
    "/V",
    "/FO", "LIST"
)

Write-Step "Test manuel conseille"
Write-Host "Pour tester maintenant :"
Write-Host "Start-ScheduledTask -TaskName `"$TaskName`""
Write-Host "Start-Sleep -Seconds 10"
Write-Host "Get-ScheduledTaskInfo -TaskName `"$TaskName`""
Write-Host "Get-Content `"C:\Services\MobileSLI.Expedition.Web\logs\maintenance-servweb.log`" -Tail 80"
