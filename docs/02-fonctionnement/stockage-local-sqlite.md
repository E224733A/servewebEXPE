# Stockage local SQLite SERVWEB

## Objectif

SERVWEB utilise une base SQLite locale pour conserver temporairement les données de préparation entre le chargement API et le verrouillage.

Cette base permet de travailler sans rappeler l’API centrale à chaque ouverture de tournée.

## Emplacement

Configuration :

```text
src/MobileSLI.Expedition.Web/appsettings.json
ExpeditionDb:DatabasePath = data/expedition-drafts.sqlite3
```

En production, le fichier se trouve dans :

```text
C:\Services\MobileSLI.Expedition.Web\data\expedition-drafts.sqlite3
```

## Service responsable

Interface :

```text
Data/IExpeditionDraftStore.cs
```

Implémentation :

```text
Data/SqliteExpeditionDraftStore.cs
```

## Responsabilités du stockage

Le stockage local gère :

1. l’initialisation de la base ;
2. la sauvegarde du dernier chargement API ;
3. les états des tournées ;
4. les brouillons de quantités Expedition ;
5. les commentaires Administration ;
6. la construction du lot de verrouillage ;
7. l’historique local des verrouillages ;
8. le snapshot de statut exposé par `/preparations/status` ;
9. la purge des anciennes données locales.

## Tables locales connues

Les tables utilisées par le stockage local sont notamment :

```text
Expedition_LoadedData
Expedition_TourneeState
Expedition_LineDraft
Expedition_LineQuantity
Admin_CommentaireDraft
Expedition_LockHistory
```

## Rétention

Valeurs codées dans `SqliteExpeditionDraftStore` :

```text
DraftRetentionDays = 10
LockHistoryRetentionDays = 30
```

Interprétation :

| Donnée | Conservation |
|---|---:|
| chargements API, états de tournées, brouillons, quantités, commentaires | 10 jours |
| historique local des verrouillages | 30 jours |

## Déclenchement de la purge

La purge SQLite est gérée par l’application.

Elle ne doit pas être faite directement par les scripts Windows de maintenance.

Le script `maintenance-servweb-runtime.ps1` ne nettoie que les fichiers et les backups, pas la base SQLite.

## Dossiers conservés au déploiement

Le dossier suivant est volontairement conservé au déploiement :

```text
C:\Services\MobileSLI.Expedition.Web\data
```

Le script de déploiement ne doit pas supprimer ce dossier, sinon les brouillons locaux et l’état de préparation seraient perdus.

## Règles de modification

Une tournée devient non modifiable si :

```text
- elle est déjà verrouillée côté API centrale ;
- ou elle est marquée verrouillée dans l’état local SQLite.
```

Les contrôleurs refusent alors les modifications Expedition et Administration.

## Rôle dans le verrouillage

Au verrouillage, SQLite sert à reconstruire le lot à envoyer à l’API centrale.

Le lot contient :

```text
- les tournées prêtes ;
- les lignes ;
- les quantités prévues ;
- les commentaires exceptionnels ;
- les informations de dernière modification.
```

Après succès API, SQLite marque localement les tournées comme verrouillées.

## Ce qu’il ne faut pas faire

Ne pas supprimer manuellement :

```text
C:\Services\MobileSLI.Expedition.Web\data\expedition-drafts.sqlite3
```

sauf si l’objectif est explicitement de réinitialiser tout l’état local SERVWEB.

Ne pas modifier directement la base SQLite en production sans sauvegarde.

Ne pas ajouter de purge fichier sur `data` dans les scripts de maintenance.
