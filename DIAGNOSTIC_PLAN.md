# 🔍 Analyse du Problème Erreur 500

## Contexte
- ✅ Erreur 400 initiale : `source`, `statutPreparationWeb` - **CORRIGÉS**
- ❌ Maintenant erreur 500 après correction

## Signification de l'Erreur 500 Après Validation Initiale

Une erreur 500 après que les validations de base passent indique généralement :

### A. Problème d'Enregistrement SQL
- Contrainte de clé primaire/étrangère non respectée
- Violation d'intégrité référentielle
- Champ obligatoire null
- Type de données incompatible

### B. Mapping d'Objet Échoué
- Les champs du JSON n'ont pas les bons noms
- Les types ne correspondent pas (ex: string où int attendu)
- Désérialisation JSON échouée côté API

### C. Conflit de Données
- Le lot est déjà enregistré (même idLotVerrouillage)
- Combinaison de clés en conflit
- Dateé hors limites acceptables

### D. Logique Métier Échouée
- Une tournée n'existe pas en base
- Une ligne d'une tournée n'existe pas
- Statut de la tournée n'est pas autorisé pour le verrouillage

---

## Points à Vérifier dans le Payload SERVWEB

### 1. **Unicité de `idLotVerrouillage`**

Format attendu : `SERVEXPE-{DateTournee}-{HHmm}-{Sequence}`
Exemple : `SERVEXPE-2026-05-25-2235-001`

⚠️ **Problème possible** : Si le lot est renvoyé avec le même ID, l'API peut rejeter avec erreur 500 (contrainte unique)

**Vérification** :
```json
"idLotVerrouillage": "SERVEXPE-2026-05-25-2235-001"
```

### 2. **Dates Valides**

**`dateTournee`** :
- Format : `yyyy-MM-dd`
- Doit être la date **préparable actuelle selon l'API**
- ✅ Code SERVWEB : `load.DateTournee` (vient du GET API)

**`dateVerrouillageDemandee`** :
- Format : ISO 8601 avec offset explicite
- Exemple : `2026-05-24T22:35:00+02:00`
- ⚠️ **Vérifier** : L'offset `+02:00` est correct pour `Europe/Paris` en mai (heure d'été)

### 3. **Lignes Référencées**

Chaque ligne doit avoir :
- `idLigneSource` qui correspond **exactement** à une ligne du GET API
- `client.numClient` obligatoire et non null

⚠️ **Problème possible** :
- `idLigneSource` reconstruit différemment côté SERVWEB ?
- Un `idLigneSource` invalide (n'existe pas en API) ?

**Vérification** : Comparer `idLigneSource` dans le payload avec ceux retournés par GET API

### 4. **Articles Autorisés**

Seulement `ROLLS`, `TAPIS`, `SACS` - pas de `ROLLS_VIDES`

**Vérification du code SERVWEB** :
```csharp
private static bool IsPreparedArticle(string codeArticle) =>
    string.Equals(codeArticle, "ROLLS", StringComparison.OrdinalIgnoreCase)
    || string.Equals(codeArticle, "TAPIS", StringComparison.OrdinalIgnoreCase)
    || string.Equals(codeArticle, "SACS", StringComparison.OrdinalIgnoreCase);
```
✅ **Code correct**

### 5. **Quantités**

Chaque article doit avoir :
- `quantiteLivreePrevue` : null ou >= 0

⚠️ **Problème possible** :
- Une quantité négative envoyée ?
- Un type incorrect ?

**Vérification du code SERVWEB** :
```csharp
QuantiteLivreePrevue = lineState is not null && lineState.Quantites.TryGetValue(...)
    ? stored
    : ligne.BrouillonInitial.Quantites.FirstOrDefault(...)?.QuantiteLivreePrevue
```
✅ **La source est fiable (stockage SQLite)**

---

## Plan de Diagnostic

### Phase 1 : Générer et Examiner le Payload JSON

1. Modifier le code pour **sauvegarder le payload** ✅ FAIT
2. Déclencher le verrouillage
3. Lire le fichier `debug-last-expedition-lock-payload.json`
4. Vérifier manuellement :
   - Champ manquant ?
   - Valeur incorrecte ?
   - Type faux ?

### Phase 2 : Tester le Payload Manuellement

1. Poster le payload **directement** vers l'API avec `curl`
2. Capture le body exact de l'erreur 500
3. Analyser le message d'erreur pour identifier le champ problématique

### Phase 3 : Analyser les Logs API

- Récupérer les logs de l'API centrale au moment de la tentative
- Chercher l'exception SQL ou le message d'erreur exact
- Identifier le champ/contrainte en conflit

### Phase 4 : Corriger SERVWEB

Basé sur le diagnostic :
- Corriger la construction du payload
- Ajouter des validations côté client
- Retester

---

## Commandes de Test Proposées

### 1. Générer le payload et afficher sa structure

```powershell
# Dans SERVWEB
dotnet build
$payload = Get-Content "data/debug-last-expedition-lock-payload.json" -Raw
$obj = $payload | ConvertFrom-Json
$obj | ConvertTo-Json -Depth 10
```

### 2. Tester avec curl

```bash
# Windows PowerShell
$ApiUrl = "http://192.168.1.233:5000/api/expedition/preparations/verrouiller"
Invoke-RestMethod `
  -Method Post `
  -Uri $ApiUrl `
  -ContentType "application/json" `
  -InFile "C:\path\to\debug-last-expedition-lock-payload.json"
```

### 3. Capturer l'erreur exacte

```powershell
try {
    Invoke-RestMethod `
      -Method Post `
      -Uri $ApiUrl `
      -ContentType "application/json" `
      -InFile "data/debug-last-expedition-lock-payload.json"
} catch {
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    Write-Host "Body: $(Read-Stream($_.Exception.Response.GetResponseStream()))" -ForegroundColor Red
}
```

---

## Prochaines Étapes

1. ✅ Compiler SERVWEB avec les modifications
2. ⏳ Déclencher le verrouillage depuis l'interface
3. 📋 Lire le payload sauvegardé et vérifier sa structure
4. 🔍 Examiner les logs pour voir le body exact de l'erreur 500
5. 🛠️ Corriger les problèmes identifiés
6. 🧪 Retester jusqu'à succès
