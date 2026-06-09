# Vue d’ensemble SERVWEB Expedition

## Rôle

Le dépôt `servewebEXPE` contient l’application Web intranet utilisée par les équipes Expedition et Administration.

L’application permet de charger les données depuis l’API centrale, de préparer les tournées localement, puis d’envoyer un lot de verrouillage à l’API centrale.

SERVWEB ne décide pas de la date métier. La date préparable est calculée par l’API centrale.

## Technologie

| Élément | Valeur |
|---|---|
| Framework | ASP.NET Core MVC |
| Version .NET | `net8.0` |
| Stockage local | SQLite |
| Serveur cible | SERVWEB / SRVINTRAWEB1 |
| Déploiement courant | IIS par artefact Release versionné |
| API centrale par défaut | `https://srvapi1.sli.local/` |
| URLs utilisateur | `http://expedition.sli.local`, `http://admin.sli.local` |
| Port Web exposé | `80` |
| Port historique supprimé | `5100` |

## Organisation du code

```text
src/MobileSLI.Expedition.Web/
  Application/
    Administration/
    Common/
    Expedition/
  Background/
  Controllers/
  Data/
  Domain/
  Models/
  Options/
  Services/
  ViewModels/
  Views/
```

## Couches

| Couche | Rôle |
|---|---|
| Controllers | Requêtes HTTP, vues, redirections, TempData |
| Application | Builders de ViewModels et validators |
| Services | Client API centrale et orchestration du verrouillage |
| Data | Stockage SQLite local |
| Domain | Constantes et règles métier simples |
| Models | DTO API et modèles de formulaires |
| ViewModels | Données préparées pour les vues Razor |
| Views | Pages Razor Expedition et Administration |
| Background | Initialisation SQLite, purge et filet de sécurité du verrouillage |

## Flux général

```text
API centrale
  -> GET /api/expedition/preparations/a-preparer
  -> stockage SQLite local SERVWEB
  -> saisies Expedition et Administration
  -> lot de verrouillage local
  -> POST /api/expedition/preparations/verrouiller
  -> SQL Server via API centrale
  -> lecture par mobile livreur
```

## Séparation Expedition / Administration

| Interface | Données modifiées | Articles affichés |
|---|---|---|
| Expedition | Quantités prévues | `ROLLS`, `ROLLS_VIDES`, `TAPIS`, `SACS` |
| Administration | Commentaires exceptionnels | `ROLLS`, `TAPIS`, `SACS` |

`ROLLS_VIDES` est donc bien préparé côté Expedition dans le code actuel.

`ROLLS_VIDES` n’est pas affiché côté Administration.

## Routage par nom DNS

Le middleware de `Program.cs` route les deux interfaces selon le host header :

```text
http://expedition.sli.local      -> /expedition
http://admin.sli.local           -> /administration
http://admin.sli.local/expedition -> redirection /administration
http://expedition.sli.local/administration -> redirection /expedition
```

Le port `5100` ne doit plus être utilisé comme URL publique ni comme endpoint local de verrouillage.

## Endpoint technique local

La tâche Windows de verrouillage appelle :

```text
POST http://localhost/verrouillage/executer
```

Cet endpoint est réservé aux appels loopback.

Un appel distant doit être refusé avec un `403 Forbidden`.

Si `Verrouillage:LockSecret` est configuré, le script de tâche Windows doit transmettre l’en-tête configuré, par défaut :

```text
X-SERVEXPE-LOCK-SECRET
```

## Stockage SQLite

Chemin par défaut configuré :

```text
data/expedition-drafts.sqlite3
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

Fenêtre de verrouillage applicative :

```text
22h35 inclus à 22h55 exclu
```

Le `BackgroundService` vérifie aussi la fenêtre, mais il reste un filet de sécurité. Il ne doit pas remplacer la tâche Windows en production.

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

Dans `appsettings.json`, le filtrage applicatif est volontairement léger :

```text
AccessControl:Enabled = true
AccessControl:RequireHttps = false
AccessControl:BlockMobileUserAgents = true
AccessControl:RequireIpAllowListInProduction = false
```

La restriction réseau principale doit rester portée par :

```text
Pare-feu Windows
IIS
Règles réseau internes
```

## Lecture mobile

Après verrouillage réussi, l’API centrale écrit les préparations officielles en SQL Server.

Le mobile lit ensuite les quantités Expedition depuis les préparations verrouillées, sans dépendre de SQLite SERVWEB.

## Décisions d’architecture validées

- La tâche Windows est le déclencheur principal du verrouillage.
- Le `BackgroundService` reste un secours.
- La version 23h55 n’est plus présente.
- La fenêtre actuelle est 22h35 inclus à 22h55 exclu.
- Le stockage brouillon reste local à SERVWEB.
- Le mode API réelle est celui de la version finale.
- Le client fake reste dans le dépôt mais n’est plus enregistré par l’application.
- Le port utilisateur exposé est le port 80 avec host headers.
- L’API centrale configurée dans le code est `https://srvapi1.sli.local/`.
