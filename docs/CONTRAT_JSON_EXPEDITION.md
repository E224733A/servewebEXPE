# Contrat API Expédition utilisé par SERVEXPE

## Principe

SERVEXPE utilise l’API centrale MobileSLI pour deux opérations métier :

```text
GET  /api/expedition/preparations/a-preparer
POST /api/expedition/preparations/verrouiller
```

Le test de santé utilise aussi :

```text
GET /api/health
```

SERVEXPE ne choisit pas la date métier. La date est calculée par l’API centrale.

## Chargement global

```http
GET /api/expedition/preparations/a-preparer
```

### Règles

- Aucun paramètre de date.
- L’API centrale calcule la date préparable.
- La réponse contient les tournées et les lignes préparables.
- SERVEXPE stocke la réponse en SQLite.
- L’ouverture d’une tournée ne rappelle pas l’API centrale.
- Les brouillons locaux ne sont pas envoyés tant que la tournée n’est pas prête pour verrouillage.

### Structure attendue côté SERVEXPE

```json
{
  "statut": "SUCCESS",
  "schemaVersion": "1.2",
  "dateTournee": "2026-05-25",
  "datePreparable": "2026-05-25",
  "dateModifiable": false,
  "fuseauHoraireMetier": "Europe/Paris",
  "dateGenerationApi": "2026-05-22T08:00:00+02:00",
  "articlesPreparables": [
    {
      "codeArticle": "ROLLS",
      "libelle": "Rolls pleins",
      "typeQuantite": "LIVREE_PREVUE",
      "quantiteNullable": true
    },
    {
      "codeArticle": "TAPIS",
      "libelle": "Tapis",
      "typeQuantite": "LIVREE_PREVUE",
      "quantiteNullable": true
    },
    {
      "codeArticle": "SACS",
      "libelle": "Sacs",
      "typeQuantite": "LIVREE_PREVUE",
      "quantiteNullable": true
    }
  ],
  "tournees": [
    {
      "codeTournee": "4006",
      "libelleTournee": "Tournée 4006",
      "etatPreparation": "NON_PREPAREE",
      "estVerrouilleeBd": false,
      "lignes": [
        {
          "idLigneSource": "2026-05-25|4006|12345|PDL01|10",
          "ordreArret": 10,
          "client": {
            "numClient": "12345",
            "nomClient": "CLIENT TEST",
            "nomAffiche": "CLIENT TEST"
          },
          "pointLivraison": {
            "codePDL": "PDL01",
            "descriptionPDL": "Accueil principal",
            "adresseLigne1": "1 rue Exemple",
            "adresseLigne2": null,
            "adresseLigne3": null,
            "codePostal": "44000",
            "ville": "Nantes"
          },
          "infosLecture": {
            "instructions": "Livraison par l'arrière.",
            "fermetureClient": false,
            "dateFermeture": null,
            "motifFermeture": null,
            "zoneDechargement": "Zone A"
          },
          "preparationInitiale": {
            "commentaireExceptionnel": null,
            "quantitesPrevues": [
              {
                "codeArticle": "ROLLS",
                "libelle": "Rolls pleins",
                "quantiteLivreePrevue": null
              },
              {
                "codeArticle": "TAPIS",
                "libelle": "Tapis",
                "quantiteLivreePrevue": null
              },
              {
                "codeArticle": "SACS",
                "libelle": "Sacs",
                "quantiteLivreePrevue": null
              }
            ]
          }
        }
      ]
    }
  ],
  "regles": {
    "quantiteMin": 0,
    "quantiteNullable": true,
    "modificationApiPendantPreparation": false,
    "verrouillagePrevuVers": "22:35"
  }
}
```

## Verrouillage définitif

```http
POST /api/expedition/preparations/verrouiller
```

### Déclenchement

Le déclenchement normal se fait par la tâche Windows quotidienne à 22h35.

SERVEXPE appelle d’abord son endpoint local :

```http
POST /verrouillage/executer
```

Puis SERVEXPE construit le lot et appelle l’API centrale :

```http
POST /api/expedition/preparations/verrouiller
```

### Règles de construction du lot

SERVEXPE envoie uniquement les tournées :

```text
non verrouillées
et en état PRET_VERROUILLAGE ou PRETE_VERROUILLAGE
```

Si aucune tournée n’est prête, aucun lot n’est envoyé à l’API centrale.

Le lot contient :

- `schemaVersion` ;
- `idLotVerrouillage` ;
- `source` ;
- `dateTournee` ;
- `dateVerrouillageDemandee` ;
- `fuseauHoraireMetier` ;
- les tournées ;
- les lignes ;
- les quantités prévues ;
- les commentaires exceptionnels.

### Format de l’identifiant de lot

Pour le verrouillage planifié :

```text
SERVEXPE-{dateTournee:yyyy-MM-dd}-{heureVerrouillage:HHmm}-{sequence}
```

Exemple :

```text
SERVEXPE-2026-05-25-2235-001
```

Pour le verrouillage manuel de développement :

```text
DEV-{yyyyMMddHHmmss}
```

### Exemple de requête de verrouillage

```json
{
  "schemaVersion": "1.2",
  "idLotVerrouillage": "SERVEXPE-2026-05-25-2235-001",
  "source": "APPLICATION_WEB_EXPEDITION",
  "dateTournee": "2026-05-25",
  "dateVerrouillageDemandee": "2026-05-22T22:35:00+02:00",
  "fuseauHoraireMetier": "Europe/Paris",
  "tournees": [
    {
      "codeTournee": "4006",
      "libelleTournee": "Tournée 4006",
      "statutPreparationWeb": "PRETE_VERROUILLAGE",
      "lignes": [
        {
          "idLigneSource": "2026-05-25|4006|12345|PDL01|10",
          "ordreArret": 10,
          "client": {
            "numClient": "12345",
            "nomClient": "CLIENT TEST",
            "nomAffiche": "CLIENT TEST"
          },
          "pointLivraison": {
            "codePDL": "PDL01",
            "descriptionPDL": "Accueil principal",
            "adresseLigne1": "1 rue Exemple",
            "adresseLigne2": null,
            "adresseLigne3": null,
            "codePostal": "44000",
            "ville": "Nantes"
          },
          "commentaireExceptionnel": "Prévoir passage avant 10h.",
          "quantitesPrevues": [
            {
              "codeArticle": "ROLLS",
              "libelle": "Rolls pleins",
              "quantiteLivreePrevue": 3
            },
            {
              "codeArticle": "TAPIS",
              "libelle": "Tapis",
              "quantiteLivreePrevue": null
            },
            {
              "codeArticle": "SACS",
              "libelle": "Sacs",
              "quantiteLivreePrevue": 0
            }
          ],
          "derniereModification": {
            "date": "2026-05-22T22:35:00+02:00",
            "utilisateur": "APPLICATION_WEB_EXPEDITION"
          }
        }
      ]
    }
  ]
}
```

## Réponse attendue actuellement par le client SERVEXPE

Le client HTTP actuel considère comme réussite opérationnelle réelle :

```text
SUCCESS
```

Exemple :

```json
{
  "statut": "SUCCESS",
  "code": null,
  "message": "Préparations Expédition verrouillées.",
  "idLotVerrouillage": "SERVEXPE-2026-05-25-2235-001",
  "dateTournee": "2026-05-25",
  "statutVerrouillage": "VERROUILLEE_BD",
  "dateReceptionApi": "2026-05-22T22:35:15+02:00",
  "dateSauvegardeSql": "2026-05-22T22:35:15+02:00",
  "nombreTourneesVerrouillees": 2,
  "nombreLignesVerrouillees": 8
}
```

## Point technique à surveiller sur les statuts idempotents

Le service `VerrouillageService` contient une liste de statuts de succès métier :

```text
SUCCESS
ALREADY_PROCESSED
ALREADY_LOCKED
```

Cependant, le client HTTP `ExpeditionApiClient` actuel rejette une réponse 2xx dont `statut` est différent de `SUCCESS`.

Conclusion documentation-code :

```text
Statut réellement accepté aujourd’hui par le client : SUCCESS.
Statuts prévus par le service mais à valider par correction du client si nécessaire : ALREADY_PROCESSED, ALREADY_LOCKED.
```

Si l’API centrale doit réellement renvoyer `ALREADY_PROCESSED` ou `ALREADY_LOCKED` comme succès 2xx, il faudra ajuster `ExpeditionApiClient.VerrouillerAsync` pour ne pas lever d’exception sur ces statuts.

## Erreurs possibles

Les erreurs retournées par l’API centrale peuvent être affichées par SERVEXPE avec le code API et le message.

Exemples de catégories :

```text
VALIDATION_ERROR
CONFLICT
DATE_TOURNEE_EXPIREE
TECHNICAL_ERROR
```

Si l’erreur est un conflit, une erreur de validation ou une date expirée, le retry automatique ne doit pas masquer le problème métier.
