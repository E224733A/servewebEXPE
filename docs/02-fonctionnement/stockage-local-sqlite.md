# Stockage local SQLite SERVWEB

## Objectif

SERVWEB utilise une base SQLite locale pour conserver temporairement les données de préparation entre le chargement API et le verrouillage.

Cette base permet de travailler sans rappeler l’API centrale à chaque ouverture de tournée.

SERVWEB ne modifie pas SQL Server directement pendant la saisie utilisateur.

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

Initialisation et purge au démarrage :

```text
Background/ExpeditionStartupService.cs
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

Les tables utilisées par le stockage local sont :

```text
Expedition_LoadedData
Expedition_TourneeState
Expedition_LineDraft
Expedition_LineQuantity
Admin_CommentaireDraft
Expedition_LockHistory
```

## Initialisation technique

À l’initialisation, l’application applique notamment :

```text
PRAGMA busy_timeout = 5000
PRAGMA foreign_keys = ON
PRAGMA journal_mode = WAL
```

Ces réglages visent à rendre le stockage local plus robuste pendant les accès applicatifs.

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

Elle est exécutée :

```text
- au démarrage de l’application via ExpeditionStartupService ;
- après sauvegarde d’un nouveau chargement API.
```

Elle ne doit pas être faite directement par les scripts Windows de maintenance.

Le script `maintenance-servweb-runtime.ps1` ne nettoie que les fichiers et les backups, pas la base SQLite.

## Dossiers conservés au déploiement

Le dossier suivant est volontairement conservé au déploiement :

```text
C:\Services\MobileSLI.Expedition.Web\data
```

Le script de déploiement ne doit pas supprimer ce dossier, sinon les brouillons locaux et l’état de préparation seraient perdus.

Les scripts de production conservent aussi :

```text
C:\Services\MobileSLI.Expedition.Web\logs
C:\Services\MobileSLI.Expedition.Web\scripts
```

## Règles de modification

Une tournée devient non modifiable si :

```text
- elle est déjà verrouillée côté API centrale ;
- ou elle est marquée verrouillée dans l’état local SQLite.
```

Les contrôleurs refusent alors les modifications Expedition et Administration.

## Préservation de l’état local au rechargement

Lorsqu’un nouveau chargement API est sauvegardé, le stockage conserve certains états locaux existants :

```text
BROUILLON
PRET_VERROUILLAGE
PRETE_VERROUILLAGE
VERROUILLAGE_EN_COURS
```

Cela évite qu’un simple rechargement API écrase une tournée déjà préparée localement.

Une tournée verrouillée localement reste verrouillée.

## Rôle dans le verrouillage

Au verrouillage, SQLite sert à reconstruire le lot à envoyer à l’API centrale.

Le lot contient :

```text
- les tournées prêtes ;
- les lignes ;
- les quantités prévues ;
- les commentaires exceptionnels ;
- la date du dernier clic humain "Marquer prête" ;
- les informations de dernière modification.
```

Après succès API, SQLite marque localement les tournées comme verrouillées.

## Articles stockés côté Expedition

Les quantités prévues saisies côté Expedition concernent :

```text
ROLLS
ROLLS_VIDES
TAPIS
SACS
```

Les commentaires exceptionnels Administration sont stockés séparément dans `Admin_CommentaireDraft`.

## Ce qu’il ne faut pas faire

Ne pas supprimer manuellement :

```text
C:\Services\MobileSLI.Expedition.Web\data\expedition-drafts.sqlite3
```

sauf si l’objectif est explicitement de réinitialiser tout l’état local SERVWEB.

Ne pas modifier directement la base SQLite en production sans sauvegarde.

Ne pas ajouter de purge fichier sur `data` dans les scripts de maintenance.

Ne pas déplacer la responsabilité de purge SQLite vers la tâche Windows de maintenance sans nouvelle validation technique.
