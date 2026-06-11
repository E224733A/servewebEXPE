# Architecture du module Expédition SERVEXPE

## Statut du document

Ce document racine est conservé pour compatibilité avec les anciennes notes de travail.

La référence principale d’architecture est maintenant :

```text
docs/01-architecture/vue-ensemble-serveweb.md
```

Les informations ci-dessous ont été réalignées avec le code actuel afin de ne plus documenter l’ancien port `5100` ni l’ancienne configuration API HTTP/IP.

## Objectif du module

Le module Web Expédition permet aux équipes internes de préparer les quantités prévues et les commentaires exceptionnels avant le passage des livreurs.

Le module ne décide pas seul de la persistance officielle : il prépare localement les brouillons, puis envoie un lot de verrouillage à l’API centrale. L’API centrale reste responsable de la validation finale et de l’écriture SQL Server.

## Vue d’ensemble

```text
Poste Expédition / Administration
        |
        | HTTP interne port 80 avec host headers
        v
SERVWEB - Application web ASP.NET Core MVC
        |
        | brouillons locaux
        v
SQLite locale côté SERVWEB
        |
        | GET  /api/expedition/preparations/a-preparer
        | POST /api/expedition/preparations/verrouiller
        v
API centrale MobileSLI
        |
        v
SQL Server
        |
        v
Application mobile livreur
```

## Responsabilités par composant

| Composant | Responsabilités |
|---|---|
| Navigateur Expédition | Saisie des quantités prévues, consultation des tournées, préparation du verrouillage |
| Navigateur Administration | Saisie ou modification des commentaires exceptionnels |
| SERVWEB ASP.NET Core MVC | Interface, brouillons SQLite, état des tournées, appel API, verrouillage planifié |
| SQLite SERVWEB | Stockage local durable des brouillons avant verrouillage officiel |
| Tâche planifiée Windows | Déclencheur principal du verrouillage quotidien à 22h35 |
| BackgroundService | Filet de sécurité uniquement, pas déclencheur principal |
| API centrale MobileSLI | Date métier, lecture ABSSolute, validation du contrat, écriture SQL Server, idempotence |
| SQL Server | Données officielles après verrouillage et données lues par le mobile |
| Mobile livreur | Lecture des préparations verrouillées et synchronisation terrain |

## URLs et ports actuels

URLs utilisateur :

```text
http://expedition.sli.local
http://admin.sli.local
```

API centrale configurée par défaut :

```text
https://srvapi1.sli.local/
```

Endpoint technique local de verrouillage :

```text
POST http://localhost/verrouillage/executer
```

Le port `5100` est obsolète et ne doit plus être réintroduit comme URL utilisateur ni comme URL de verrouillage.

## Principe de séparation

Le navigateur ne contacte jamais directement SQL Server.

Le mobile ne contacte jamais directement SQL Server.

SERVWEB ne modifie pas SQL Server lors d’une saisie utilisateur. Les modifications sont stockées en SQLite jusqu’au verrouillage.

SQL Server ne reçoit que les données officiellement verrouillées par l’API centrale.

## Stockage SQLite

Chemin par défaut :

```text
src/MobileSLI.Expedition.Web/data/expedition-drafts.sqlite3
```

Chemin de service recommandé :

```text
C:\Services\MobileSLI.Expedition.Web\data\expedition-drafts.sqlite3
```

Tables SQLite principales créées par l’application :

| Table | Rôle |
|---|---|
| `Expedition_LoadedData` | Chargements reçus de l’API centrale |
| `Expedition_TourneeState` | État local des tournées : brouillon, prête, verrouillée |
| `Expedition_LineDraft` | Présence locale des lignes de préparation |
| `Expedition_LineQuantity` | Quantités prévues saisies par l’Expédition |
| `Admin_CommentaireDraft` | Commentaires exceptionnels saisis par l’Administration |
| `Expedition_LockHistory` | Historique local des tentatives et résultats de verrouillage |

Le stockage SQLite conserve la distinction entre :

```text
NULL = quantité non renseignée
0    = quantité volontairement renseignée à zéro
> 0  = quantité prévue
```

## Chargement des données

Le chargement se fait via :

```text
GET /api/expedition/preparations/a-preparer
```

SERVWEB ne choisit pas la date. La date est calculée par l’API centrale.

Après chargement, l’ouverture d’une tournée n’effectue pas de nouveau GET API central. L’application utilise les données déjà reçues et les brouillons SQLite.

## Saisie Expédition

L’Expédition prépare les articles :

```text
ROLLS
ROLLS_VIDES
TAPIS
SACS
```

Les `ROLLS_VIDES` sont donc bien préparés côté Expédition dans le code actuel.

Les quantités négatives sont interdites.

Une tournée déjà verrouillée devient en lecture seule.

Si une tournée est déjà en état `PRET_VERROUILLAGE` ou `PRETE_VERROUILLAGE`, une correction de quantité conserve l’état prêt pour verrouillage.

## Saisie Administration

L’Administration peut saisir des commentaires exceptionnels séparés des instructions existantes.

Articles affichés côté Administration :

```text
ROLLS
TAPIS
SACS
```

`ROLLS_VIDES` n’est pas affiché côté Administration.

Un commentaire exceptionnel est lié à :

```text
DateTournee
CodeTournee
IdLigneSource
```

Une tournée verrouillée ne peut plus être modifiée côté Administration.

## Verrouillage automatique

Le verrouillage quotidien se fait à 22h35.

Déclencheur principal :

```text
Tâche planifiée Windows : MobileSLI SERVEXPE Verrouillage 22h35
```

Script exécuté :

```text
C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1
```

Endpoint appelé localement :

```text
POST http://localhost/verrouillage/executer
```

Fenêtre de verrouillage :

```text
22h35 inclus à 22h55 exclu
```

Le `BackgroundService` vérifie aussi la fenêtre mais il doit être considéré comme filet de sécurité. Il ne doit pas remplacer la tâche Windows pour une action obligatoire.

## Sécurité applicative

SERVWEB applique des en-têtes de sécurité HTTP :

```text
X-Content-Type-Options
X-Frame-Options
Referrer-Policy
Permissions-Policy
Content-Security-Policy
```

Le contrôle d’accès applicatif peut :

- exiger HTTPS hors développement ;
- bloquer les user-agents mobiles ;
- filtrer des préfixes IP autorisés.

Le filtrage applicatif reste volontairement léger. La restriction réseau principale doit être faite avec :

```text
Pare-feu Windows
IIS
Règles réseau internes
```

## Sécurité du endpoint technique

`POST /verrouillage/executer` est réservé à `localhost`.

Un appel depuis un autre poste doit recevoir :

```text
403 Forbidden
Accès refusé : verrouillage planifié réservé à localhost.
```

Si `Verrouillage:LockSecret` est configuré, le script doit fournir l’en-tête :

```text
X-SERVEXPE-LOCK-SECRET
```

La valeur transmise par le script est lue depuis :

```powershell
$env:SERVEXPE_LOCK_SECRET
```

## Lecture mobile

Après verrouillage réussi, l’API centrale écrit les préparations officielles en SQL Server.

Le mobile lit ensuite les quantités Expédition depuis les préparations verrouillées, sans dépendre de SQLite SERVWEB.

## Décisions d’architecture validées

- La tâche Windows est le déclencheur principal.
- Le `BackgroundService` reste un secours.
- La version 23h55 n’est plus présente.
- La fenêtre actuelle est 22h35 inclus à 22h55 exclu.
- Le stockage brouillon reste local à SERVWEB.
- Le mode API réelle est celui de la version finale.
- Le client fake n’est plus enregistré dans l’application finale.
- L’API centrale par défaut est `https://srvapi1.sli.local/`.
- Le port `5100` est obsolète.
