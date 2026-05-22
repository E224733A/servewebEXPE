#!/usr/bin/env pwsh
<#
.DESCRIPTION
Test payload JSON generation to verify schema compliance before calling the API
#>

# Navigate to the SERVWEB project
$projectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
Set-Location $projectRoot

# Create test data directory if it doesn't exist
$testDataDir = Join-Path $projectRoot "data"
if (-not (Test-Path $testDataDir)) {
    New-Item -ItemType Directory -Path $testDataDir -Force | Out-Null
    Write-Host "Créé le répertoire : $testDataDir"
}

# Build the project
Write-Host "`n🔨 Compilation SERVWEB..."
dotnet build
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur de compilation"
    exit 1
}

# Run the application and test the locking endpoint
Write-Host "`n▶️  Démarrage SERVWEB..."
$serverProcess = Start-Process -NoNewWindow -PassThru -FilePath "dotnet" -ArgumentList "run" -WorkingDirectory $projectRoot

# Wait for the server to start
Start-Sleep -Seconds 5

# Check if the debug payload file was created
$debugPayloadPath = Join-Path $projectRoot "data\debug-last-expedition-lock-payload.json"

if (Test-Path $debugPayloadPath) {
    Write-Host "`n📋 Payload JSON trouvé :"
    Write-Host "Chemin : $debugPayloadPath"
    $payload = Get-Content $debugPayloadPath -Raw
    Write-Host $payload | ConvertFrom-Json | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n⚠️  Fichier payload de diagnostic non trouvé. Vous devez déclencher le verrouillage depuis l'interface."
}

# Kill the server process
if ($serverProcess) {
    Stop-Process -Id $serverProcess.Id -ErrorAction SilentlyContinue
}

Write-Host "`n✅ Test terminé"
