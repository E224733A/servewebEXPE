# Vue d’ensemble SERVWEB Expedition

## Rôle

Le dépôt `servewebEXPE` contient l’application Web intranet utilisée par les équipes Expedition et Administration.

L’application permet de charger les données depuis l’API centrale, de préparer les tournées localement, puis d’envoyer un lot de verrouillage à l’API centrale.

## Technologie

| Élément | Valeur |
|---|---|
| Framework | ASP.NET Core MVC |
| Version .NET | `net8.0` |
| Stockage local | SQLite |
| Serveur cible | SERVWEB / SRVINTRAWEB1 |
| Déploiement | IIS par artefact Release |

## Organisation

```text
src/MobileSLI.Expedition.Web/
  Application/
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
| Controllers | Requêtes HTTP, vues, redirections |
| Application | Builders de ViewModels et validators |
| Services | Client API centrale et verrouillage |
| Data | Stockage SQLite local |
| Domain | Constantes et règles métier |
| Models | DTO et modèles de formulaires |
| ViewModels | Données préparées pour les vues |
| Views | Pages Razor |

## Flux général

```text
API centrale
  -> chargement des préparations
  -> stockage SQLite local
  -> saisies Expedition et Administration
  -> lot de verrouillage
  -> API centrale
```

## Décisions structurantes

1. SERVWEB ne choisit pas la date métier.
2. L’API centrale fournit la date préparable.
3. Les saisies restent locales jusqu’au verrouillage.
4. Le verrouillage automatique est prévu à 22h35.
5. Le port public utilisé est le port 80 avec noms DNS.
6. Le serveur ne compile pas en production, il déploie un artefact Release.
