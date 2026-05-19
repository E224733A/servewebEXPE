# Règles de correction — servewebEXPE

## Objectif

Éviter les régressions causées par des corrections trop larges.

Le serveur web Expédition doit être corrigé par périmètre strict. Une correction SQLite ne doit jamais remplacer une page Razor, un fichier CSS, un fichier JavaScript ou un contrôleur complet.

## Règle principale

Avant chaque livraison de correctif, vérifier la liste des fichiers modifiés avec :

```powershell
git diff --name-only
```

La correction est refusée si un fichier hors périmètre apparaît dans cette liste.

## Périmètres autorisés

### 1. Correction SQLite

Objectif : stockage local des brouillons, quantités prévues, commentaires, états de verrouillage.

Fichier autorisé :

```text
src/MobileSLI.Expedition.Web/Data/SqliteExpeditionDraftStore.cs
```

Fichiers interdits :

```text
src/MobileSLI.Expedition.Web/Views/**
src/MobileSLI.Expedition.Web/wwwroot/**
src/MobileSLI.Expedition.Web/Controllers/**
src/MobileSLI.Expedition.Web/Services/ExpeditionApiClient.cs
src/MobileSLI.Expedition.Web/Models/ExpeditionDtos.cs
```

Exception : si l’interface `IExpeditionDraftStore` impose une signature différente, il faut adapter `SqliteExpeditionDraftStore.cs` à l’interface existante. Il ne faut pas modifier le contrôleur pour compenser une mauvaise signature du store.

### 2. Correction UI

Objectif : affichage, design, champs modifiables, page de chargement, overlay.

Fichiers autorisés :

```text
src/MobileSLI.Expedition.Web/Views/**
src/MobileSLI.Expedition.Web/wwwroot/css/**
src/MobileSLI.Expedition.Web/wwwroot/js/**
```

Fichiers interdits :

```text
src/MobileSLI.Expedition.Web/Data/**
src/MobileSLI.Expedition.Web/Services/**
src/MobileSLI.Expedition.Web/Models/**
```

Exception : si une vue a besoin d’une propriété absente dans un ViewModel, la correction doit être séparée et annoncée avant modification.

### 3. Correction contrat JSON

Objectif : aligner les DTO avec le contrat API ↔ serveur web.

Fichiers autorisés :

```text
src/MobileSLI.Expedition.Web/Models/ExpeditionDtos.cs
src/MobileSLI.Expedition.Web/Services/ExpeditionApiClient.cs
src/MobileSLI.Expedition.Web/Services/IExpeditionApiClient.cs
```

Fichiers interdits :

```text
src/MobileSLI.Expedition.Web/Views/**
src/MobileSLI.Expedition.Web/wwwroot/**
src/MobileSLI.Expedition.Web/Data/**
```

Exception : si le contrat JSON modifie une donnée affichée, la correction UI doit être livrée séparément.

### 4. Correction verrouillage automatique

Objectif : déclenchement 00:05, idempotence, lot de verrouillage, statut de verrouillage.

Fichiers autorisés :

```text
src/MobileSLI.Expedition.Web/Services/VerrouillageService.cs
src/MobileSLI.Expedition.Web/Background/VerrouillageBackgroundService.cs
src/MobileSLI.Expedition.Web/Options/VerrouillageOptions.cs
src/MobileSLI.Expedition.Web/appsettings*.json
```

Fichiers interdits :

```text
src/MobileSLI.Expedition.Web/Views/**
src/MobileSLI.Expedition.Web/wwwroot/**
```

## Format obligatoire des prochains correctifs

Chaque correction doit commencer par :

```text
Périmètre : SQLite | UI | Contrat JSON | Verrouillage
Fichiers modifiés :
- ...
Fichiers explicitement non modifiés :
- ...
```

Puis seulement ensuite le zip ou les fichiers complets.

## Contrôle avant livraison

Exemple pour une correction SQLite :

```powershell
git diff --name-only
```

Résultat attendu :

```text
src/MobileSLI.Expedition.Web/Data/SqliteExpeditionDraftStore.cs
```

Si la commande affiche une vue, un CSS, un JS ou un contrôleur, la correction est trop large et doit être recommencée.

## Règle de sécurité

Le serveur web ne doit jamais contourner l’API centrale pour écrire dans SQL Server.

Le stockage SQLite est uniquement un brouillon local côté backend web. Le POST vers l’API centrale reste le seul moment où les données Expédition sont verrouillées et envoyées au backend métier.
