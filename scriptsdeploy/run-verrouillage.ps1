$ErrorActionPreference = "Stop"

$Url = "http://localhost:5100/verrouillage/executer"
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

    $Headers = @{}
    if (-not [string]::IsNullOrWhiteSpace($Secret)) {
        $Headers["X-SERVEXPE-LOCK-SECRET"] = $Secret
    }

    $Response = Invoke-RestMethod -Method Post -Uri $Url -Headers $Headers -TimeoutSec 120

    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Date] Succès : $($Response | ConvertTo-Json -Compress -Depth 8)"

    @{ date = (Get-Date).ToString("o"); codeRetour = 0; message = "SUCCESS" } |
        ConvertTo-Json -Compress |
        Set-Content -Path $HeartbeatFile -Encoding UTF8

    exit 0
}
catch {
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Date] Erreur : $($_.Exception.Message)"

    @{ date = (Get-Date).ToString("o"); codeRetour = 1; message = $_.Exception.Message } |
        ConvertTo-Json -Compress |
        Set-Content -Path $HeartbeatFile -Encoding UTF8

    exit 1
}
