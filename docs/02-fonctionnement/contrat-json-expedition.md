# Contrat JSON Expedition utilisé par SERVWEB

## Objectif

Ce document décrit le contrat utilisé entre SERVWEB Expedition et l’API centrale MobileSLI.

SERVWEB utilise l’API centrale pour :

```text
GET  /api/expedition/preparations/a-preparer
POST /api/expedition/preparations/verrouiller
GET  /api/health
```

SERVWEB ne choisit pas la date métier. La date préparable est calculée par l’API centrale.

## Configuration API côté SERVWEB

Configuration applicative :

```text
ExpeditionApi:BaseUrl = https://srvapi1.sli.local/
ExpeditionApi:RequireHttps = true
ExpeditionApi:TimeoutSeconds = 30
ExpeditionApi:ApiKeyHeaderName = X-Expedition-Api-Key
```

En développement, `RequireHttps` peut être désactivé par configuration, mais la valeur par défaut actuelle pointe déjà vers HTTPS.

Le client HTTP réel est `Services/ExpeditionApiClient.cs`.

`FakeExpeditionApiClient` reste présent dans le dépôt pour historique/tests isolés, mais il n’est plus enregistré par `Program.cs`.

## Test de santé API

Endpoint :

```http
GET /api/health
```

Il est utilisé par :

```text
POST /expedition/test-api
POST /administration/test-api
```

Ces routes ne chargent pas les données métier et ne modifient pas SQLite.

## Chargement des préparations

Endpoint :

```http
GET /api/expedition/preparations/a-preparer
```

Règles :

1. aucun paramètre de date ;
2. l’API centrale calcule la date préparable ;
3. SERVWEB sauvegarde la réponse en SQLite ;
4. l’ouverture d’une tournée ne rappelle pas l’API centrale ;
5. les brouillons locaux ne sont pas envoyés tant que la tournée n’est pas prête pour verrouillage.

Structure attendue côté SERVWEB :

```json
{
  "statut": "SUCCESS",
  "schemaVersion": "1.2",
  "dateTournee": "2026-06-05",
  "datePreparable": "2026-06-05",
  "dateModifiable": false,
  "fuseauHoraireMetier": "Europe/Paris",
  "dateGenerationApi": "2026-06-04T08:00:00+02:00",
  "articlesPreparables": [],
  "tournees": [],
  "regles": {
    "quantiteMin": 0,
    "quantiteNullable": true,
    "modificationApiPendantPreparation": false,
    "verrouillagePrevuVers": "22:35"
  }
}
```

## Articles utilisés par SERVWEB

Côté Expedition, le code affiche et sauvegarde :

```text
ROLLS
ROLLS_VIDES
TAPIS
SACS
```

Côté Administration, le code affiche :

```text
ROLLS
TAPIS
SACS
```

Les commentaires exceptionnels Administration sont séparés des quantités Expedition.

## Verrouillage des préparations

Endpoint API centrale :

```http
POST /api/expedition/preparations/verrouiller
```

Le déclenchement normal se fait par la tâche Windows quotidienne à 22h35.

SERVWEB appelle d’abord son endpoint local :

```http
POST /verrouillage/executer
```

Puis il construit le lot et appelle l’API centrale.

## Tournées envoyées

SERVWEB envoie uniquement les tournées :

```text
non verrouillées
et en état PRET_VERROUILLAGE ou PRETE_VERROUILLAGE
```

Si aucune tournée n’est prête, aucun lot n’est envoyé à l’API centrale.

## Contenu du lot

Le lot contient :

```text
schemaVersion
idLotVerrouillage
source
dateTournee
dateVerrouillageDemandee
fuseauHoraireMetier
tournées
lignes
quantités prévues
commentaires exceptionnels
dernières modifications
```

## Identifiant du lot

Pour le verrouillage planifié :

```text
SERVEXPE-{dateTournee:yyyy-MM-dd}-{heureVerrouillage:HHmm}-{sequence}
```

Exemple :

```text
SERVEXPE-2026-06-05-2235-001
```

Pour le verrouillage manuel de développement :

```text
DEV-{yyyyMMddHHmmss}
```

## Réponse de succès attendue

Le client SERVWEB considère actuellement comme réussite réelle :

```text
SUCCESS
```

Exemple :

```json
{
  "statut": "SUCCESS",
  "code": null,
  "message": "Préparations Expédition sauvegardées et verrouillées avec succès.",
  "idLotVerrouillage": "SERVEXPE-2026-06-05-2235-001",
  "dateTournee": "2026-06-05",
  "statutVerrouillage": "VERROUILLE",
  "dateReceptionApi": "2026-06-04T22:35:15+02:00",
  "dateSauvegardeSql": "2026-06-04T22:35:15+02:00",
  "nombreTourneesVerrouillees": 1,
  "nombreLignesVerrouillees": 10
}
```

## Point de vigilance sur les statuts idempotents

Le service de verrouillage connaît aussi des statuts métier de type :

```text
ALREADY_PROCESSED
ALREADY_LOCKED
```

Mais le client HTTP `ExpeditionApiClient` rejette encore une réponse 2xx dont `statut` est différent de `SUCCESS`.

Conclusion :

```text
Statut réellement accepté aujourd’hui par le client SERVWEB : SUCCESS.
Statuts à valider par évolution future du client : ALREADY_PROCESSED, ALREADY_LOCKED.
```

## Erreurs possibles

Catégories d’erreurs API connues :

```text
VALIDATION_ERROR
CONFLICT
DATE_TOURNEE_EXPIREE
TECHNICAL_ERROR
```

Le retry automatique ne doit pas masquer une erreur métier.

## Clé API optionnelle

Si l’API centrale exige une clé applicative, SERVWEB peut transmettre un en-tête configuré par :

```text
ExpeditionApi:ApiKeyHeaderName
ExpeditionApi:ApiKey
```

Ne jamais stocker une vraie clé dans `appsettings.json` ni dans Git.

## Documentation liée

```text
docs/02-fonctionnement/flux-expedition-administration.md
docs/02-fonctionnement/verrouillage-planifie-22h35.md
docs/02-fonctionnement/stockage-local-sqlite.md
```
