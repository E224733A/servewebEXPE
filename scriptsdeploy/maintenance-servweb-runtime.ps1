# ============================================================
# Maintenance autonome SERVWEB
# ============================================================
# Objectif :
# - verifier que le port HTTP local de l'application repond ;
# - purger les anciens backups de deploiement ;
# - purger les anciens logs archives ;
# - archiver les gros fichiers .log avant qu'ils ne grossissent trop.
#
# Important :
# - ce script ne modifie pas la base SQLite ;
# - la purge SQLite reste geree par l'application SERVWEB ;
# - ce script ne supprime pas le payload debug versionne ;
# - ce script evite volontairement de lire le JSON /preparations/status
#   pour rester fiable sous le compte SYSTEM et limiter la consommation memoire.
# ============================================================

param(
    [string]$ServiceRoot = "C:\Services\MobileSLI.Expedition.Web",
    [string]$BackupRoot = "C:\Backups\MobileSLI.Expedition.Web",
    [string]$StatusUrl = "http://localhost/preparations/status",
    [int]$BackupRetentionDays = 30,
    [int]$ArchivedLogRetentionDays = 30,
    [int]$MaxActiveLogSizeMb = 10,
    [int]$TcpTimeoutMilliseconds = 5000
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-MaintenanceLog {
    param([Parameter(Mandatory = $true)][string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Add-Content -Path $MaintenanceLogFile -Value $line -Encoding UTF8
    Write-Host $line
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Remove-OldBackupDirectories {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$RetentionDays
    )

    if (-not (Test-Path $Path)) {
        Write-MaintenanceLog "Dossier backups absent, aucune purge : $Path"
        return
    }

    $cutoff = (Get-Date).AddDays(-$RetentionDays)

    $directories = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }

    foreach ($directory in $directories) {
        Write-MaintenanceLog "Suppression backup ancien : $($directory.FullName)"
        Remove-Item -Path $directory.FullName -Recurse -Force
    }

    Write-MaintenanceLog "Backups supprimes : $(@($directories).Count)"
}

function Rotate-LargeLogs {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$MaxSizeMb
    )

    if (-not (Test-Path $Path)) {
        Write-MaintenanceLog "Dossier logs absent, aucune rotation : $Path"
        return
    }

    $maxBytes = $MaxSizeMb * 1MB
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"

    $logs = Get-ChildItem -Path $Path -File -Filter "*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -ge $maxBytes }

    foreach ($log in $logs) {
        $archiveName = "{0}.{1}.archive.log" -f $log.BaseName, $stamp
        $archivePath = Join-Path $log.DirectoryName $archiveName

        Write-MaintenanceLog "Rotation log volumineux : $($log.FullName) -> $archivePath"
        Move-Item -Path $log.FullName -Destination $archivePath -Force
        New-Item -ItemType File -Path $log.FullName -Force | Out-Null
    }

    Write-MaintenanceLog "Logs rotations : $(@($logs).Count)"
}

function Remove-OldArchivedLogs {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$RetentionDays
    )

    if (-not (Test-Path $Path)) {
        Write-MaintenanceLog "Dossier logs absent, aucune purge : $Path"
        return
    }

    $cutoff = (Get-Date).AddDays(-$RetentionDays)

    $archivedLogs = Get-ChildItem -Path $Path -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTime -lt $cutoff -and (
                $_.Name -like "*.archive.log" -or
                $_.Name -like "stdout*.log" -or
                $_.Name -like "*.bak"
            )
        }

    foreach ($log in $archivedLogs) {
        Write-MaintenanceLog "Suppression log archive ancien : $($log.FullName)"
        Remove-Item -Path $log.FullName -Force
    }

    Write-MaintenanceLog "Logs archives supprimes : $(@($archivedLogs).Count)"
}

function Test-LocalStatusEndpoint {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][int]$TimeoutMilliseconds
    )

    $client = $null
    $asyncResult = $null

    try {
        $uri = [System.Uri]::new($Url)
        $hostName = $uri.Host
        $port = $uri.Port

        if ($port -le 0) {
            if ($uri.Scheme -eq "https") {
                $port = 443
            }
            else {
                $port = 80
            }
        }

        $client = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $client.BeginConnect($hostName, $port, $null, $null)
        $connected = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)

        if (-not $connected) {
            Write-MaintenanceLog "Status SERVWEB KO : TCP $hostName`:$port timeout apres $TimeoutMilliseconds ms"
            return $false
        }

        $client.EndConnect($asyncResult)
        Write-MaintenanceLog "Status SERVWEB OK : TCP $hostName`:$port"
        return $true
    }
    catch {
        Write-MaintenanceLog "Status SERVWEB KO : $($_.Exception.GetType().FullName) - $($_.Exception.Message)"
        return $false
    }
    finally {
        if ($null -ne $asyncResult -and $null -ne $asyncResult.AsyncWaitHandle) {
            $asyncResult.AsyncWaitHandle.Close()
        }

        if ($null -ne $client) {
            $client.Close()
        }
    }
}

$LogsPath = Join-Path $ServiceRoot "logs"
Ensure-Directory -Path $LogsPath

$MaintenanceLogFile = Join-Path $LogsPath "maintenance-servweb.log"

Write-MaintenanceLog "Debut maintenance SERVWEB"
Write-MaintenanceLog "ServiceRoot=$ServiceRoot"
Write-MaintenanceLog "BackupRoot=$BackupRoot"
Write-MaintenanceLog "StatusUrl=$StatusUrl"
Write-MaintenanceLog "BackupRetentionDays=$BackupRetentionDays"
Write-MaintenanceLog "ArchivedLogRetentionDays=$ArchivedLogRetentionDays"
Write-MaintenanceLog "MaxActiveLogSizeMb=$MaxActiveLogSizeMb"
Write-MaintenanceLog "TcpTimeoutMilliseconds=$TcpTimeoutMilliseconds"

$statusOk = Test-LocalStatusEndpoint -Url $StatusUrl -TimeoutMilliseconds $TcpTimeoutMilliseconds

Rotate-LargeLogs -Path $LogsPath -MaxSizeMb $MaxActiveLogSizeMb
Remove-OldArchivedLogs -Path $LogsPath -RetentionDays $ArchivedLogRetentionDays
Remove-OldBackupDirectories -Path $BackupRoot -RetentionDays $BackupRetentionDays

Write-MaintenanceLog "Fin maintenance SERVWEB"

if (-not $statusOk) {
    exit 1
}

exit 0
