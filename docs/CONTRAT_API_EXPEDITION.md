# Contrat API Expédition utilisé par l'application web

## Chargement global

```text
GET /api/expedition/preparations/a-preparer
```

### Règles

- Aucun paramètre de date.
- La date préparable est calculée côté API centrale.
- La réponse contient toutes les tournées préparables et toutes les lignes utiles.
- L'application web ne rappelle pas l'API pour ouvrir une tournée.

### Exemple de réponse

```json
{
  "statut": "SUCCESS",
  "schemaVersion": "1.0",
  "dateTournee": "2026-05-16",
  "datePreparable": "2026-05-16",
  "dateModifiable": false,
  "fuseauHoraireMetier": "Europe/Paris",
  "dateGenerationApi": "2026-05-15T08:00:00+02:00",
  "articlesSuivis": [
    { "codeArticle": "ROLLS", "libelleArticle": "Rolls", "typeQuantite": "LIVREE_PREVUE" },
    { "codeArticle": "TAPIS", "libelleArticle": "Tapis", "typeQuantite": "LIVREE_PREVUE" },
    { "codeArticle": "SACS", "libelleArticle": "Sacs", "typeQuantite": "LIVREE_PREVUE" }
  ],
  "tournees": [
    {
      "codeTournee": "4006",
      "libelleTournee": "Tournée 4006",
      "etatPreparation": "NON_PREPAREE",
      "estVerrouilleeBd": false,
      "lignes": [
        {
          "idLigneSource": "2026-05-16|4006|12345|PDL01|10",
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
            "zoneDechargement": "Zone A"
          },
          "brouillonInitial": {
            "commentaireExceptionnel": null,
            "quantites": [
              { "codeArticle": "ROLLS", "quantiteLivreePrevue": null },
              { "codeArticle": "TAPIS", "quantiteLivreePrevue": null },
              { "codeArticle": "SACS", "quantiteLivreePrevue": null }
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
    "verrouillagePrevuVers": "00:05"
  }
}
```

## Verrouillage définitif

```text
POST /api/expedition/preparations/verrouiller
```

### Règles

- Appelé par la tâche automatique de l'application web.
- Envoie toutes les préparations de la date calculée.
- Le corps contient un `idLotVerrouillage`.
- Les quantités acceptent `null`, `0` ou un entier positif.
- Les commentaires exceptionnels restent séparés des instructions.
- L'API centrale reste responsable du contrôle final.

### Exemple de requête

```json
{
  "schemaVersion": "1.0",
  "idLotVerrouillage": "EXP-2026-05-16-0005-001",
  "source": "APPLICATION_WEB_EXPEDITION",
  "dateTournee": "2026-05-16",
  "dateVerrouillageDemandee": "2026-05-16T00:05:00+02:00",
  "fuseauHoraireMetier": "Europe/Paris",
  "tournees": [
    {
      "codeTournee": "4006",
      "statutPreparationWeb": "PRETE_VERROUILLAGE",
      "lignes": [
        {
          "idLigneSource": "2026-05-16|4006|12345|PDL01|10",
          "commentaireExceptionnel": "Prévoir passage avant 10h.",
          "quantites": [
            { "codeArticle": "ROLLS", "quantiteLivreePrevue": 3 },
            { "codeArticle": "TAPIS", "quantiteLivreePrevue": null },
            { "codeArticle": "SACS", "quantiteLivreePrevue": 0 }
          ],
          "derniereModification": {
            "date": "2026-05-15T17:32:00+02:00"
          }
        }
      ]
    }
  ]
}
```

### Statuts attendus côté API

- `SUCCESS`
- `ALREADY_PROCESSED`
- `ALREADY_LOCKED`
- `VALIDATION_ERROR`
- `LOCK_WINDOW_ERROR`
- `CONFLICT`
- `TECHNICAL_ERROR`
