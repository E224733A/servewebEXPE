$ErrorActionPreference = "Stop"

# Etat réseau final validé :
# - l'interface Web utilisateur est exposée en HTTP sur le port 80 avec host headers.
# - le port 5100 a été supprimé.
# - la tâche planifiée doit donc appeler le endpoint technique en local sur http://localhost.
# - un binding IIS local *:80:localhost doit exister sur le site MobileSLI.Expedition.Web.
$Url = "http://localhost/verrouillage/executer"

$LogDir = "C:\Services\MobileSLI.Expedition.Web\logs"
$LogFile = Join-Path $LogDir "verrouillage-planifie.log"
$HeartbeatFile = Join-Path $LogDir "verrouillage-planifie-heartbeat.json"
$Secret = $env:SERVEXPE_LOCK_SECRET

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

try {
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Date] Début verrouillage planifié SERVEXPE 22h35"
    Add-Content -Path $LogFile -Value "[$Date] URL locale appelée : $Url"

    $Headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($Secret)) {
        $Headers["X-SERVEXPE-LOCK-SECRET"] = $Secret
    }

    $Response = Invoke-RestMethod -Method Post -Uri $Url -Headers $Headers -TimeoutSec 120

    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Date] Succès : $($Response | ConvertTo-Json -Compress -Depth 8)"

    @{
        date = (Get-Date).ToString("o")
        codeRetour = 0
        message = "SUCCESS"
        url = $Url
    } |
        ConvertTo-Json -Compress |
        Set-Content -Path $HeartbeatFile -Encoding UTF8

    exit 0
}
catch {
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Date] Erreur : $($_.Exception.Message)"

    @{
        date = (Get-Date).ToString("o")
        codeRetour = 1
        message = $_.Exception.Message
        url = $Url
    } |
        ConvertTo-Json -Compress |
        Set-Content -Path $HeartbeatFile -Encoding UTF8

    exit 1
}
