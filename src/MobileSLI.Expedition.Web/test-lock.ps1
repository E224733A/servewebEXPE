#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiUrl = "http://192.168.1.233:5000/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

# Etape 1: Verifier API centrale
Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "http://192.168.1.233:5000/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: API centrale indisponible" -ForegroundColor Red
    exit 1
}

# Etape 2: Charger donnees
Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod `
        -Uri "http://192.168.1.233:5000/api/expedition/preparations/a-preparer" `
        -Method Get `
        -ContentType "application/json" `
        -TimeoutSec 30

    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
} catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

# Etape 3: Creer payload
Write-Host "`n[3] Creation payload..." -ForegroundColor Cyan

$firstTournee = $loadResponse.tournees[0]
$firstLigne = $firstTournee.lignes[0]
$now = [DateTimeOffset]::Now
$todayStr = $now.ToString("yyyy-MM-dd")
$timeStr = $now.ToString("HHmm")

$lockPayload = @{
    schemaVersion = "1.2"
    idLotVerrouillage = "SERVEXPE-$todayStr-$timeStr-001"
    source = "APPLICATION_WEB_EXPEDITION"
    dateTournee = $loadResponse.dateTournee
    dateVerrouillageDemandee = $now.ToString("O")
    fuseauHoraireMetier = $loadResponse.fuseauHoraireMetier
    tournees = @(
        @{
            codeTournee = $firstTournee.codeTournee
            libelleTournee = $firstTournee.libelleTournee
            statutPreparationWeb = "PRETE_VERROUILLAGE"
            lignes = @(
                @{
                    idLigneSource = $firstLigne.idLigneSource
                    ordreArret = $firstLigne.ordreArret
                    client = @{
                        numClient = $firstLigne.client.numClient
                        nomClient = $firstLigne.client.nomClient
                        nomAffiche = $firstLigne.client.nomAffiche
                    }
                    pointLivraison = @{
                        codePDL = $firstLigne.pointLivraison.codePDL
                        descriptionPDL = $firstLigne.pointLivraison.descriptionPDL
                        adresseLigne1 = $firstLigne.pointLivraison.adresseLigne1
                        adresseLigne2 = $firstLigne.pointLivraison.adresseLigne2
                        adresseLigne3 = $firstLigne.pointLivraison.adresseLigne3
                        ville = $firstLigne.pointLivraison.ville
                        codePostal = $firstLigne.pointLivraison.codePostal
                    }
                    commentaireExceptionnel = $firstLigne.preparationInitiale.commentaireExceptionnel
                    quantitesPrevues = @(
                        @{ codeArticle = "ROLLS"; libelle = "Rolls"; quantiteLivreePrevue = 4 },
                        @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                        @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
                    )
                    derniereModification = @{
                        date = $now.ToString("O")
                        utilisateur = "APPLICATION_WEB_EXPEDITION"
                    }
                }
            )
        }
    )
}

# Sauvegarder
$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde" -ForegroundColor Green
Write-Host "  Fichier: $PayloadPath" -ForegroundColor Gray

# Etape 4: Verifications
Write-Host "`n[4] Verifications structure..." -ForegroundColor Cyan

$checks = @(
    @{ name = "schemaVersion"; expected = "1.2"; actual = $lockPayload.schemaVersion }
    @{ name = "source"; expected = "APPLICATION_WEB_EXPEDITION"; actual = $lockPayload.source }
    @{ name = "fuseauHoraireMetier"; expected = "Europe/Paris"; actual = $lockPayload.fuseauHoraireMetier }
    @{ name = "statutPreparationWeb"; expected = "PRETE_VERROUILLAGE"; actual = $lockPayload.tournees[0].statutPreparationWeb }
)

$allOk = $true
foreach ($check in $checks) {
    if ($check.actual -eq $check.expected) {
        Write-Host "  OK: $($check.name) = $($check.actual)" -ForegroundColor Green
    } else {
        Write-Host "  ERREUR: $($check.name) = $($check.actual) (attendu: $($check.expected))" -ForegroundColor Red
        $allOk = $false
    }
}

if ($lockPayload.dateVerrouillageDemandee -match "\+\d{2}:\d{2}") {
    Write-Host "  OK: dateVerrouillageDemandee avec offset: $($lockPayload.dateVerrouillageDemandee)" -ForegroundColor Green
} else {
    Write-Host "  ERREUR: dateVerrouillageDemandee SANS OFFSET: $($lockPayload.dateVerrouillageDemandee)" -ForegroundColor Red
    $allOk = $false
}

# Etape 5: Afficher payload
Write-Host "`n[5] Payload JSON:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────"
Write-Host $lockPayloadJson -ForegroundColor Gray
Write-Host "─────────────────────────────────────────────────"

# Etape 6: Test API
Write-Host "`n[6] Test vers API..." -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $ApiUrl `
        -ContentType "application/json" `
        -InFile $PayloadPath `
        -TimeoutSec 30

    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
    Write-Host "  Tournees verrouilees: $($response.nombreTourneesVerrouillees)" -ForegroundColor Green
    Write-Host "  Lignes verrouilees: $($response.nombreLignesVerrouillees)" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    $statusCode = $_.Exception.Response.StatusCode
    Write-Host "  HTTP Status: $statusCode" -ForegroundColor Yellow

    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            $errorBody = $reader.ReadToEnd()
            Write-Host "`n  REPONSE API:" -ForegroundColor Yellow
            Write-Host $errorBody -ForegroundColor Yellow
        }
    } catch { }
}

# Resume
Write-Host "`n=== RESUME ===" -ForegroundColor Cyan
if ($allOk) {
    Write-Host "Payload structure OK" -ForegroundColor Green
} else {
    Write-Host "Problemes detectes" -ForegroundColor Red
}

Write-Host "`nFichier: $PayloadPath" -ForegroundColor Gray
Write-Host "Fin du test`n" -ForegroundColor Cyan
