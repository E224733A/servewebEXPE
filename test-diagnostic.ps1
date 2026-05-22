#!/usr/bin/env pwsh
<#
.DESCRIPTION
Manuel pour tester le verrouillage et diagnostiquer l'erreur API
#>

$ErrorActionPreference = "Stop"

# Configuration
$ApiBaseUrl = "http://192.168.1.233:5000"
$LockEndpoint = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$HealthEndpoint = "$ApiBaseUrl/api/health"

# Couleurs pour le terminal
function Write-Success { Write-Host $args[0] -ForegroundColor Green }
function Write-Error { Write-Host $args[0] -ForegroundColor Red }
function Write-Warning { Write-Host $args[0] -ForegroundColor Yellow }
function Write-Info { Write-Host $args[0] -ForegroundColor Cyan }

Write-Info "`n=== Diagnostic Verrouillage Expédition ===" 

# 1. Tester la santé de l'API
Write-Info "`n[1/4] Test de santé de l'API..."
try {
    $health = Invoke-RestMethod -Uri $HealthEndpoint -Method Get -ErrorAction Stop
    Write-Success "✅ API centrale en ligne"
} catch {
    Write-Error "❌ API centrale indisponible : $_"
    exit 1
}

# 2. Charger les données depuis SERVWEB
Write-Info "`n[2/4] Chargement des données depuis SERVWEB..."
$servwebUrl = "http://localhost:5001"  # Ajustez le port si nécessaire
try {
    $loadResult = Invoke-RestMethod -Uri "$servwebUrl/api/expedition/preparations" -Method Get -ErrorAction Stop
    Write-Success "✅ Données chargées depuis SERVWEB"
    Write-Info "Tournées disponibles : $($loadResult.tournees.Count)"
} catch {
    Write-Error "❌ Impossible de charger depuis SERVWEB : $_"
    Write-Warning "Assurez-vous que SERVWEB est en cours d'exécution sur le port 5001"
    exit 1
}

# 3. Marquer une tournée PRET_VERROUILLAGE
Write-Info "`n[3/4] Sélection d'une tournée pour verrouillage..."
$tourneeCodeTournee = $loadResult.tournees[0].codeTournee
Write-Info "Tournée sélectionnée : $tourneeCodeTournee"

# 4. Déclencher le verrouillage et capturer le payload
Write-Info "`n[4/4] Déclenchement du verrouillage..."
try {
    $lockResult = Invoke-RestMethod -Uri "$servwebUrl/verrouillage/executer" `
        -Method Post `
        -Headers @{ "X-SERVEXPE-LOCK-SECRET" = "your-secret-here" } `
        -ErrorAction Stop

    if ($lockResult.success) {
        Write-Success "✅ Verrouillage réussi"
        Write-Success $lockResult.message
    } else {
        Write-Error "❌ Verrouillage échoué"
        Write-Error $lockResult.message
    }
} catch {
    $ex = $_
    Write-Error "❌ Erreur lors du verrouillage"
    Write-Error $ex.Exception.Message

    if ($ex.Response) {
        Write-Warning "HTTP Status: $($ex.Response.StatusCode)"
        $streamReader = [System.IO.StreamReader]::new($ex.Response.GetResponseStream())
        $body = $streamReader.ReadToEnd()
        Write-Warning "Response Body:`n$body"
    }
}

# 5. Chercher le fichier de payload de diagnostic
Write-Info "`n[5/5] Cherche le fichier de diagnostic..."
$projectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$debugPayloadPath = Join-Path $projectRoot "data\debug-last-expedition-lock-payload.json"

if (Test-Path $debugPayloadPath) {
    Write-Success "✅ Fichier de payload trouvé"
    $payload = Get-Content $debugPayloadPath -Raw
    $obj = $payload | ConvertFrom-Json

    Write-Info "`nStructure du payload :"
    Write-Info "  - schemaVersion: $($obj.schemaVersion)"
    Write-Info "  - source: $($obj.source)"
    Write-Info "  - idLotVerrouillage: $($obj.idLotVerrouillage)"
    Write-Info "  - fuseauHoraireMetier: $($obj.fuseauHoraireMetier)"
    Write-Info "  - tournees: $($obj.tournees.Count)"
    Write-Info "  - lignes: $($obj.tournees[0].lignes.Count)"

    # Vérifications
    Write-Info "`nVérifications :"
    $checks = @(
        @{ expr = { $obj.schemaVersion -eq "1.2" }; desc = "schemaVersion = 1.2" },
        @{ expr = { $obj.source -eq "APPLICATION_WEB_EXPEDITION" }; desc = "source = APPLICATION_WEB_EXPEDITION" },
        @{ expr = { $obj.fuseauHoraireMetier -eq "Europe/Paris" }; desc = "fuseauHoraireMetier = Europe/Paris" },
        @{ expr = { $obj.tournees[0].statutPreparationWeb -eq "PRETE_VERROUILLAGE" }; desc = "statutPreparationWeb = PRETE_VERROUILLAGE" }
    )

    foreach ($check in $checks) {
        if (& $check.expr) {
            Write-Success "  ✅ $($check.desc)"
        } else {
            Write-Error "  ❌ $($check.desc)"
        }
    }

    # Affiche le payload complet
    Write-Info "`n📄 Payload JSON complet :"
    Write-Info ($payload | ConvertFrom-Json | ConvertTo-Json -Depth 10)

    # Test manuel avec curl
    Write-Info "`n💻 Commande cURL pour tester manuellement :"
    Write-Info "curl.exe -i -X POST `"$LockEndpoint`" ``"
    Write-Info "  -H `"Content-Type: application/json`" ``"
    Write-Info "  --data-binary `"@$debugPayloadPath`""
} else {
    Write-Warning "⚠️  Fichier de payload non trouvé : $debugPayloadPath"
    Write-Warning "Vérifiez que SERVWEB a bien tenté le verrouillage"
}

Write-Success "`n✅ Diagnostic terminé"
