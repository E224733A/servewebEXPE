#!/usr/bin/env pwsh
<#
.DESCRIPTION
Analyser les logs SERVWEB pour trouver les erreurs API exactes
#>

$projectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"

# Cherche les fichiers de logs
$logsPath = Join-Path $projectRoot "logs"
if (-not (Test-Path $logsPath)) {
    Write-Host "❌ Répertoire logs non trouvé : $logsPath" -ForegroundColor Red
    exit 1
}

# Lit les fichiers de logs les plus récents
Write-Host "`n📋 Logs SERVWEB (les 100 dernières lignes) :" -ForegroundColor Cyan
$latestLog = Get-ChildItem $logsPath -Filter "*.txt" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestLog) {
    Write-Host "Fichier : $($latestLog.Name)" -ForegroundColor Yellow
    $content = Get-Content $latestLog.FullName -Tail 100

    # Cherche les erreurs API
    $apiErrors = $content | Select-String "Erreur API" -Context 2
    $errors = $content | Select-String "ERROR\|Exception" 

    if ($apiErrors) {
        Write-Host "`n🔴 Erreurs API trouvées :" -ForegroundColor Red
        $apiErrors | ForEach-Object { Write-Host $_.Line }
    }

    if ($errors) {
        Write-Host "`n⚠️  Autres erreurs :" -ForegroundColor Yellow
        $errors | Select-Object -First 20 | ForEach-Object { Write-Host $_.Line }
    }

    Write-Host "`nLast 100 lines:" -ForegroundColor Cyan
    $content | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "❌ Aucun fichier log trouvé" -ForegroundColor Red
}
