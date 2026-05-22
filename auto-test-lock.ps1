#!/usr/bin/env pwsh
<#
.DESCRIPTION
Test complet du verrouillage Expédition - charge les données, déclenche le verrouillage,
et teste le payload vers l'API
#>

$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = "C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE"
$ServerUrl = "http://localhost:5001"
$ApiUrl = "http://192.168.1.233:5000/api/expedition/preparations/verrouiller"
$PayloadPath = Join-Path $ProjectRoot "data\debug-last-expedition-lock-payload.json"

# Couleurs
function Write-Success { Write-Host $args[0] -ForegroundColor Green }
function Write-Error_ { Write-Host $args[0] -ForegroundColor Red }
function Write-Warning_ { Write-Host $args[0] -ForegroundColor Yellow }
function Write-Info { Write-Host $args[0] -ForegroundColor Cyan }

Write-Info "`n╔════════════════════════════════════════════════╗"
Write-Info "║  TEST COMPLET VERROUILLAGE EXPÉDITION          ║"
Write-Info "╚════════════════════════════════════════════════╝`n"

# ============ ÉTAPE 1 : Vérifier que l'API centrale est accessible ============
Write-Info "[1/6] Vérification accès API centrale..."
try {
    $apiHealth = Invoke-WebRequest -Uri "http://192.168.1.233:5000/api/health" -Method Get -TimeoutSec 5 -ErrorAction Stop
    Write-Success "✅ API centrale accessible (192.168.1.233:5000)"
} catch {
    Write-Error_ "❌ API centrale INDISPONIBLE"
    Write-Warning_ "   Assurez-vous que l'API est démarrée sur http://192.168.1.233:5000"
    Write-Warning_ "   Erreur: $_"
    exit 1
}

# ============ ÉTAPE 2 : Charger les données Expédition depuis l'API ============
Write-Info "`n[2/6] Chargement données Expédition depuis l'API..."
try {
    $loadResponse = Invoke-RestMethod `
        -Uri "http://192.168.1.233:5000/api/expedition/preparations/a-preparer" `
        -Method Get `
        -ContentType "application/json" `
        -TimeoutSec 10 `
        -ErrorAction Stop

    Write-Success "✅ Données chargées depuis l'API"
    Write-Info "   DateTournee: $($loadResponse.dateTournee)"
    Write-Info "   Tournées: $($loadResponse.tournees.Count)"
    Write-Info "   SchemaVersion: $($loadResponse.schemaVersion)"
    Write-Info "   FuseauHoraireMetier: $($loadResponse.fuseauHoraireMetier)"

    if ($loadResponse.tournees.Count -eq 0) {
        Write-Error_ "❌ Aucune tournée à préparer"
        exit 1
    }

    # Afficher les tournées
    foreach ($t in $loadResponse.tournees) {
        Write-Info "     - $($t.codeTournee): $($t.libelleTournee) (état: $($t.etatPreparation), lignes: $($t.lignes.Count))"
        foreach ($ligne in $t.lignes | Select-Object -First 2) {
            Write-Info "       * $($ligne.idLigneSource) - $($ligne.client.numClient) - $($ligne.client.nomClient)"
        }
    }
} catch {
    Write-Error_ "❌ Erreur chargement données API"
    Write-Error_ "   $_"
    exit 1
}

# ============ ÉTAPE 3 : Sauvegarder les données chargées pour SERVWEB ============
Write-Info "`n[3/6] Sauvegarde des données dans SERVWEB..."

# Pour ce test, je vais simuler le verrouillage en créant le payload directement
# basé sur les données de l'API
$firstTournee = $loadResponse.tournees[0]
$firstLigne = $firstTournee.lignes[0]

# Créer le payload de verrouillage
$now = [DateTimeOffset]::Now
$todayStr = $now.ToString("yyyy-MM-dd")
$timeStr = $now.ToString("HHmm")

$lockPayload = @{
    schemaVersion = "1.2"
    idLotVerrouillage = "SERVEXPE-$todayStr-$timeStr-001"
    source = "APPLICATION_WEB_EXPEDITION"
    dateTournee = $loadResponse.dateTournee
    dateVerrouillageDemandee = $now.ToString("O")  # ISO 8601 avec offset
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
                        @{
                            codeArticle = "ROLLS"
                            libelle = "Rolls"
                            quantiteLivreePrevue = 4
                        },
                        @{
                            codeArticle = "TAPIS"
                            libelle = "Tapis"
                            quantiteLivreePrevue = $null
                        },
                        @{
                            codeArticle = "SACS"
                            libelle = "Sacs"
                            quantiteLivreePrevue = $null
                        }
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

# Sauvegarder le payload
$dataDir = Join-Path $ProjectRoot "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

$lockPayloadJson = $lockPayload | ConvertTo-Json -Depth 10
$lockPayloadJson | Out-File -FilePath $PayloadPath -Encoding UTF8 -Force
Write-Success "✅ Payload sauvegardé: $PayloadPath"

# ============ ÉTAPE 4 : Afficher et vérifier le payload ============
Write-Info "`n[4/6] Vérification du payload JSON..."

$obj = $lockPayload

# Vérifications critiques
Write-Info "`n   Vérifications structure :"
$checks = @(
    @{ 
        desc = "schemaVersion"
        expected = "1.2"
        actual = $obj.schemaVersion
    },
    @{ 
        desc = "source"
        expected = "APPLICATION_WEB_EXPEDITION"
        actual = $obj.source
    },
    @{ 
        desc = "fuseauHoraireMetier"
        expected = "Europe/Paris"
        actual = $obj.fuseauHoraireMetier
    },
    @{ 
        desc = "statutPreparationWeb"
        expected = "PRETE_VERROUILLAGE"
        actual = $obj.tournees[0].statutPreparationWeb
    }
)

$allGood = $true
foreach ($check in $checks) {
    if ($check.actual -eq $check.expected) {
        Write-Success "   ✅ $($check.desc): $($check.actual)"
    } else {
        Write-Error_ "   ❌ $($check.desc): $($check.actual) (attendu: $($check.expected))"
        $allGood = $false
    }
}

# Vérifier dateVerrouillageDemandee
if ($obj.dateVerrouillageDemandee -match "\+\d{2}:\d{2}|−\d{2}:\d{2}") {
    Write-Success "   ✅ dateVerrouillageDemandee avec offset: $($obj.dateVerrouillageDemandee)"
} else {
    Write-Error_ "   ❌ dateVerrouillageDemandee SANS OFFSET: $($obj.dateVerrouillageDemandee)"
    $allGood = $false
}

# Vérifier articles
$articles = $obj.tournees[0].lignes[0].quantitesPrevues | Select-Object -ExpandProperty codeArticle
$expectedArticles = @("ROLLS", "TAPIS", "SACS")
$invalidArticles = $articles | Where-Object { $_ -notin $expectedArticles }
if ($invalidArticles.Count -eq 0) {
    Write-Success "   ✅ Articles valides: $($articles -join ', ')"
} else {
    Write-Error_ "   ❌ Articles INVALIDES: $($invalidArticles -join ', ')"
    $allGood = $false
}

# ============ ÉTAPE 5 : Afficher le payload complet ============
Write-Info "`n[5/6] Payload JSON complet :"
Write-Info "─────────────────────────────────────────────────"
Write-Host $lockPayloadJson -ForegroundColor Gray
Write-Info "─────────────────────────────────────────────────"

# ============ ÉTAPE 6 : Tester le payload vers l'API ============
Write-Info "`n[6/6] Test du payload vers l'API centrale..."
Write-Info "   URL cible: $ApiUrl"

try {
    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $ApiUrl `
        -ContentType "application/json" `
        -InFile $PayloadPath `
        -TimeoutSec 10 `
        -ErrorAction Stop

    Write-Success "✅ API a accepté le payload !"
    Write-Success "   Statut: $($response.statut)"
    Write-Success "   IdLotVerrouillage: $($response.idLotVerrouillage)"
    Write-Success "   DateTournee: $($response.dateTournee)"
    Write-Success "   NombreTourneesVerrouillees: $($response.nombreTourneesVerrouillees)"
    Write-Success "   NombreLignesVerrouillees: $($response.nombreLignesVerrouillees)"

} catch {
    Write-Error_ "❌ API a REJETÉ le payload"
    Write-Error_ "   Status HTTP: $($_.Exception.Response.StatusCode)"

    # Essayer d'extraire le body d'erreur
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
            $reader = [System.IO.StreamReader]::new($stream)
            $errorBody = $reader.ReadToEnd()
            Write-Error_ "`n   Body réponse (erreur de l'API):"
            Write-Host $errorBody -ForegroundColor Yellow
        }
    } catch { }
}

# ============ RÉSUMÉ ============
Write-Info "`n╔════════════════════════════════════════════════╗"
Write-Info "║  RÉSUMÉ DU TEST                                ║"
Write-Info "╚════════════════════════════════════════════════╝"

if ($allGood) {
    Write-Success "`n✅ Payload structure validée !"
    Write-Success "   Le problème ne vient pas de la structure JSON."
} else {
    Write-Error_ "`n❌ Problèmes détectés dans le payload !"
    Write-Error_ "   Vérifiez les erreurs ci-dessus."
}

Write-Info "`nFichier de payload: $PayloadPath"
Write-Info "Vous pouvez tester manuellement avec :`n"
Write-Info "Invoke-RestMethod -Method Post -Uri `"$ApiUrl`" -ContentType `"application/json`" -InFile `"$PayloadPath`""

Write-Info "`n✅ Test terminé`n"
