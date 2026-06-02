#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host ""
Write-Host ""
Write-Host "[3] Test vers API..." -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = "http://api.mobilesli.intra:5000"
}

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
$ApiVerrouillageUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"

if ([string]::IsNullOrWhiteSpace($PayloadPath)) {
    $PayloadPath = ".\data\debug-last-expedition-lock-payload.json"
}

if (-not (Test-Path $PayloadPath)) {
    Write-Host "ERREUR: Payload introuvable : $PayloadPath" -ForegroundColor Red
    exit 1
}

$PayloadItem = Get-Item $PayloadPath
if ($PayloadItem.Length -le 0) {
    Write-Host "ERREUR: Payload vide : $PayloadPath" -ForegroundColor Red
    exit 1
}

try {
    $null = Get-Content $PayloadPath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "ERREUR: Payload JSON invalide : $PayloadPath" -ForegroundColor Red
    Write-Host "  $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host ""
Write-Host "[3] Test vers API..." -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = "http://api.mobilesli.intra:5000"
}

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
$ApiVerrouillageUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"

if ([string]::IsNullOrWhiteSpace($PayloadPath)) {
    $PayloadPath = ".\data\debug-last-expedition-lock-payload.json"
}

if (-not (Test-Path $PayloadPath)) {
    Write-Host "ERREUR: Payload introuvable : $PayloadPath" -ForegroundColor Red
    exit 1
}

$PayloadItem = Get-Item $PayloadPath
if ($PayloadItem.Length -le 0) {
    Write-Host "ERREUR: Payload vide : $PayloadPath" -ForegroundColor Red
    exit 1
}

try {
    $null = Get-Content $PayloadPath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "ERREUR: Payload JSON invalide : $PayloadPath" -ForegroundColor Red
    Write-Host "  $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    exit 1
}

function Read-ApiErrorBody {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $null
    }

    try {
        if ($response -is [System.Net.Http.HttpResponseMessage]) {
            return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    catch {
    }

    try {
        $stream = $response.GetResponseStream()
        if ($null -ne $stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd()
        }
    }
    catch {
    }

    return $null
}

try {
    $response = Invoke-WebRequest `
        -Uri $ApiVerrouillageUrl `
        -Method POST `
        -ContentType "application/json; charset=utf-8" `
        -InFile $PayloadPath `
        -UseBasicParsing `
        -TimeoutSec 90 `
        -ErrorAction Stop

    Write-Host "OK: API a accepte le payload" -ForegroundColor Green
    Write-Host "  HTTP Status: $($response.StatusCode)"

    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        Write-Host "  Reponse API:"
        Write-Host $response.Content
    }
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red

    if (#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response -ne $null) {
        try {
            Write-Host "  HTTP Status: $([int]#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response.StatusCode)"
        }
        catch {
            Write-Host "  HTTP Status: impossible a lire"
        }

        $content = Read-ApiErrorBody -ErrorRecord #!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan


        if (-not [string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  Reponse API:"
            Write-Host $content
        }
        else {
            Write-Host "  Impossible de lire le corps de reponse API."
        }
    }
    else {
        Write-Host "  Aucune reponse HTTP recue."
        Write-Host "  Erreur PowerShell: $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    }

    exit 1
}
.Exception.Message)"
    exit 1
}

function Read-ApiErrorBody {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $null
    }

    try {
        if ($response -is [System.Net.Http.HttpResponseMessage]) {
            return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    catch {
    }

    try {
        $stream = $response.GetResponseStream()
        if ($null -ne $stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd()
        }
    }
    catch {
    }

    return $null
}

try {
    $response = Invoke-WebRequest `
        -Uri $ApiVerrouillageUrl `
        -Method POST `
        -ContentType "application/json; charset=utf-8" `
        -InFile $PayloadPath `
        -UseBasicParsing `
        -TimeoutSec 90 `
        -ErrorAction Stop

    Write-Host "OK: API a accepte le payload" -ForegroundColor Green
    Write-Host "  HTTP Status: $($response.StatusCode)"

    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        Write-Host "  Reponse API:"
        Write-Host $response.Content
    }
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red

    if (#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host ""
Write-Host "[3] Test vers API..." -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = "http://api.mobilesli.intra:5000"
}

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
$ApiVerrouillageUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"

if ([string]::IsNullOrWhiteSpace($PayloadPath)) {
    $PayloadPath = ".\data\debug-last-expedition-lock-payload.json"
}

if (-not (Test-Path $PayloadPath)) {
    Write-Host "ERREUR: Payload introuvable : $PayloadPath" -ForegroundColor Red
    exit 1
}

$PayloadItem = Get-Item $PayloadPath
if ($PayloadItem.Length -le 0) {
    Write-Host "ERREUR: Payload vide : $PayloadPath" -ForegroundColor Red
    exit 1
}

try {
    $null = Get-Content $PayloadPath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "ERREUR: Payload JSON invalide : $PayloadPath" -ForegroundColor Red
    Write-Host "  $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    exit 1
}

function Read-ApiErrorBody {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $null
    }

    try {
        if ($response -is [System.Net.Http.HttpResponseMessage]) {
            return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    catch {
    }

    try {
        $stream = $response.GetResponseStream()
        if ($null -ne $stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd()
        }
    }
    catch {
    }

    return $null
}

try {
    $response = Invoke-WebRequest `
        -Uri $ApiVerrouillageUrl `
        -Method POST `
        -ContentType "application/json; charset=utf-8" `
        -InFile $PayloadPath `
        -UseBasicParsing `
        -TimeoutSec 90 `
        -ErrorAction Stop

    Write-Host "OK: API a accepte le payload" -ForegroundColor Green
    Write-Host "  HTTP Status: $($response.StatusCode)"

    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        Write-Host "  Reponse API:"
        Write-Host $response.Content
    }
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red

    if (#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response -ne $null) {
        try {
            Write-Host "  HTTP Status: $([int]#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response.StatusCode)"
        }
        catch {
            Write-Host "  HTTP Status: impossible a lire"
        }

        $content = Read-ApiErrorBody -ErrorRecord #!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan


        if (-not [string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  Reponse API:"
            Write-Host $content
        }
        else {
            Write-Host "  Impossible de lire le corps de reponse API."
        }
    }
    else {
        Write-Host "  Aucune reponse HTTP recue."
        Write-Host "  Erreur PowerShell: $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    }

    exit 1
}
.Exception.Response -ne $null) {
        try {
            Write-Host "  HTTP Status: $([int]#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host ""
Write-Host "[3] Test vers API..." -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = "http://api.mobilesli.intra:5000"
}

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
$ApiVerrouillageUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"

if ([string]::IsNullOrWhiteSpace($PayloadPath)) {
    $PayloadPath = ".\data\debug-last-expedition-lock-payload.json"
}

if (-not (Test-Path $PayloadPath)) {
    Write-Host "ERREUR: Payload introuvable : $PayloadPath" -ForegroundColor Red
    exit 1
}

$PayloadItem = Get-Item $PayloadPath
if ($PayloadItem.Length -le 0) {
    Write-Host "ERREUR: Payload vide : $PayloadPath" -ForegroundColor Red
    exit 1
}

try {
    $null = Get-Content $PayloadPath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "ERREUR: Payload JSON invalide : $PayloadPath" -ForegroundColor Red
    Write-Host "  $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    exit 1
}

function Read-ApiErrorBody {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $null
    }

    try {
        if ($response -is [System.Net.Http.HttpResponseMessage]) {
            return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    catch {
    }

    try {
        $stream = $response.GetResponseStream()
        if ($null -ne $stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd()
        }
    }
    catch {
    }

    return $null
}

try {
    $response = Invoke-WebRequest `
        -Uri $ApiVerrouillageUrl `
        -Method POST `
        -ContentType "application/json; charset=utf-8" `
        -InFile $PayloadPath `
        -UseBasicParsing `
        -TimeoutSec 90 `
        -ErrorAction Stop

    Write-Host "OK: API a accepte le payload" -ForegroundColor Green
    Write-Host "  HTTP Status: $($response.StatusCode)"

    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        Write-Host "  Reponse API:"
        Write-Host $response.Content
    }
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red

    if (#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response -ne $null) {
        try {
            Write-Host "  HTTP Status: $([int]#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response.StatusCode)"
        }
        catch {
            Write-Host "  HTTP Status: impossible a lire"
        }

        $content = Read-ApiErrorBody -ErrorRecord #!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan


        if (-not [string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  Reponse API:"
            Write-Host $content
        }
        else {
            Write-Host "  Impossible de lire le corps de reponse API."
        }
    }
    else {
        Write-Host "  Aucune reponse HTTP recue."
        Write-Host "  Erreur PowerShell: $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    }

    exit 1
}
.Exception.Response.StatusCode)"
        }
        catch {
            Write-Host "  HTTP Status: impossible a lire"
        }

        $content = Read-ApiErrorBody -ErrorRecord #!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host ""
Write-Host "[3] Test vers API..." -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = "http://api.mobilesli.intra:5000"
}

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
$ApiVerrouillageUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"

if ([string]::IsNullOrWhiteSpace($PayloadPath)) {
    $PayloadPath = ".\data\debug-last-expedition-lock-payload.json"
}

if (-not (Test-Path $PayloadPath)) {
    Write-Host "ERREUR: Payload introuvable : $PayloadPath" -ForegroundColor Red
    exit 1
}

$PayloadItem = Get-Item $PayloadPath
if ($PayloadItem.Length -le 0) {
    Write-Host "ERREUR: Payload vide : $PayloadPath" -ForegroundColor Red
    exit 1
}

try {
    $null = Get-Content $PayloadPath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "ERREUR: Payload JSON invalide : $PayloadPath" -ForegroundColor Red
    Write-Host "  $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    exit 1
}

function Read-ApiErrorBody {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $null
    }

    try {
        if ($response -is [System.Net.Http.HttpResponseMessage]) {
            return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    catch {
    }

    try {
        $stream = $response.GetResponseStream()
        if ($null -ne $stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd()
        }
    }
    catch {
    }

    return $null
}

try {
    $response = Invoke-WebRequest `
        -Uri $ApiVerrouillageUrl `
        -Method POST `
        -ContentType "application/json; charset=utf-8" `
        -InFile $PayloadPath `
        -UseBasicParsing `
        -TimeoutSec 90 `
        -ErrorAction Stop

    Write-Host "OK: API a accepte le payload" -ForegroundColor Green
    Write-Host "  HTTP Status: $($response.StatusCode)"

    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        Write-Host "  Reponse API:"
        Write-Host $response.Content
    }
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red

    if (#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response -ne $null) {
        try {
            Write-Host "  HTTP Status: $([int]#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response.StatusCode)"
        }
        catch {
            Write-Host "  HTTP Status: impossible a lire"
        }

        $content = Read-ApiErrorBody -ErrorRecord #!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan


        if (-not [string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  Reponse API:"
            Write-Host $content
        }
        else {
            Write-Host "  Impossible de lire le corps de reponse API."
        }
    }
    else {
        Write-Host "  Aucune reponse HTTP recue."
        Write-Host "  Erreur PowerShell: $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    }

    exit 1
}


        if (-not [string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  Reponse API:"
            Write-Host $content
        }
        else {
            Write-Host "  Impossible de lire le corps de reponse API."
        }
    }
    else {
        Write-Host "  Aucune reponse HTTP recue."
        Write-Host "  Erreur PowerShell: $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host ""
Write-Host "[3] Test vers API..." -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = "http://api.mobilesli.intra:5000"
}

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")
$ApiVerrouillageUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"

if ([string]::IsNullOrWhiteSpace($PayloadPath)) {
    $PayloadPath = ".\data\debug-last-expedition-lock-payload.json"
}

if (-not (Test-Path $PayloadPath)) {
    Write-Host "ERREUR: Payload introuvable : $PayloadPath" -ForegroundColor Red
    exit 1
}

$PayloadItem = Get-Item $PayloadPath
if ($PayloadItem.Length -le 0) {
    Write-Host "ERREUR: Payload vide : $PayloadPath" -ForegroundColor Red
    exit 1
}

try {
    $null = Get-Content $PayloadPath -Raw | ConvertFrom-Json
}
catch {
    Write-Host "ERREUR: Payload JSON invalide : $PayloadPath" -ForegroundColor Red
    Write-Host "  $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    exit 1
}

function Read-ApiErrorBody {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorRecord
    )

    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) {
        return $null
    }

    try {
        if ($response -is [System.Net.Http.HttpResponseMessage]) {
            return $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    catch {
    }

    try {
        $stream = $response.GetResponseStream()
        if ($null -ne $stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd()
        }
    }
    catch {
    }

    return $null
}

try {
    $response = Invoke-WebRequest `
        -Uri $ApiVerrouillageUrl `
        -Method POST `
        -ContentType "application/json; charset=utf-8" `
        -InFile $PayloadPath `
        -UseBasicParsing `
        -TimeoutSec 90 `
        -ErrorAction Stop

    Write-Host "OK: API a accepte le payload" -ForegroundColor Green
    Write-Host "  HTTP Status: $($response.StatusCode)"

    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        Write-Host "  Reponse API:"
        Write-Host $response.Content
    }
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red

    if (#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response -ne $null) {
        try {
            Write-Host "  HTTP Status: $([int]#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Response.StatusCode)"
        }
        catch {
            Write-Host "  HTTP Status: impossible a lire"
        }

        $content = Read-ApiErrorBody -ErrorRecord #!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan


        if (-not [string]::IsNullOrWhiteSpace($content)) {
            Write-Host "  Reponse API:"
            Write-Host $content
        }
        else {
            Write-Host "  Impossible de lire le corps de reponse API."
        }
    }
    else {
        Write-Host "  Aucune reponse HTTP recue."
        Write-Host "  Erreur PowerShell: $(#!/usr/bin/env pwsh
# Test complet du verrouillage Expedition
# Etat final DNS : l'API centrale est appelee via api.mobilesli.intra.

$ErrorActionPreference = "Stop"
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ApiBaseUrl = "http://api.mobilesli.intra:5000"
$ApiUrl = "$ApiBaseUrl/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

Write-Host "`n=== TEST VERROUILLAGE EXPEDITION ===" -ForegroundColor Cyan

Write-Host "`n[1] Verification API centrale..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri "$ApiBaseUrl/api/health" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
    Write-Host "OK: API centrale accessible via $ApiBaseUrl" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API centrale indisponible via $ApiBaseUrl" -ForegroundColor Red
    Write-Host "Detail: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n[2] Chargement donnees depuis API..." -ForegroundColor Cyan
try {
    $loadResponse = Invoke-RestMethod -Uri "$ApiBaseUrl/api/expedition/preparations/a-preparer" -Method Get -ContentType "application/json" -TimeoutSec 30
    Write-Host "OK: Donnees chargees" -ForegroundColor Green
    Write-Host "  DateTournee: $($loadResponse.dateTournee)" -ForegroundColor Gray
    Write-Host "  Tournees: $($loadResponse.tournees.Count)" -ForegroundColor Gray
    Write-Host "  SchemaVersion: $($loadResponse.schemaVersion)" -ForegroundColor Gray
}
catch {
    Write-Host "ERREUR: $_" -ForegroundColor Red
    exit 1
}

if ($loadResponse.tournees.Count -eq 0) {
    Write-Host "ERREUR: Aucune tournee" -ForegroundColor Red
    exit 1
}

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
    tournees = @(@{
        codeTournee = $firstTournee.codeTournee
        libelleTournee = $firstTournee.libelleTournee
        statutPreparationWeb = "PRETE_VERROUILLAGE"
        lignes = @(@{
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
                @{ codeArticle = "ROLLS_VIDES"; libelle = "Rolls vides"; quantiteLivreePrevue = $null },
                @{ codeArticle = "TAPIS"; libelle = "Tapis"; quantiteLivreePrevue = $null },
                @{ codeArticle = "SACS"; libelle = "Sacs"; quantiteLivreePrevue = $null }
            )
            derniereModification = @{
                date = $now.ToString("O")
                utilisateur = "APPLICATION_WEB_EXPEDITION"
            }
        })
    })
}

$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Host "OK: Payload sauvegarde : $PayloadPath" -ForegroundColor Green

Write-Host "`n[3] Test vers API..." -ForegroundColor Cyan
try {
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -ContentType "application/json" -InFile $PayloadPath -TimeoutSec 30
    Write-Host "SUCCES: API a accepte le payload" -ForegroundColor Green
    Write-Host "  Statut: $($response.statut)" -ForegroundColor Green
    Write-Host "  IdLot: $($response.idLotVerrouillage)" -ForegroundColor Green
}
catch {
    Write-Host "ERREUR: API a rejete le payload" -ForegroundColor Red
    Write-Host "  HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            Write-Host $reader.ReadToEnd() -ForegroundColor Yellow
        }
    }
    catch { }
    exit 1
}

Write-Host "Fin du test`n" -ForegroundColor Cyan
.Exception.Message)"
    }

    exit 1
}
.Exception.Message)"
    }

    exit 1
}
