# MobileSLI - Module Expédition

Application web ASP.NET Core MVC dédiée à la préparation Expédition du projet MobileSLI.

Cette première base correspond au cahier des charges du module Expédition :

- page d'accueil simple, sans identifiant, sans mot de passe et sans choix manuel de date ;
- chargement global des données à préparer par `GET /api/expedition/preparations/a-preparer` ;
- choix de tournée côté application web, sans rappel API central par tournée ;
- saisie des quantités livrées prévues uniquement pour les articles suivis ;
- commentaire exceptionnel séparé des instructions existantes ;
- stockage brouillon local durable en SQLite côté application web ;
- distinction conservée entre champ vide et valeur `0` ;
- verrouillage automatique autour de `00:05` par `POST /api/expedition/preparations/verrouiller` ;
- lecture seule après verrouillage confirmé par l'API centrale ;
- mode fake de développement pour tester l'interface sans API centrale disponible.

## Structure

```text
MobileSLI.Expedition/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── CONTRAT_API_EXPEDITION.md
│   ├── INITIALISATION_GIT.md
│   └── TESTS_ACCEPTATION.md
├── scripts/
│   ├── run-dev.ps1
│   └── test-verrouillage-payload.ps1
├── src/
│   └── MobileSLI.Expedition.Web/
│       ├── Background/
│       ├── Controllers/
│       ├── Data/
│       ├── Models/
│       ├── Options/
│       ├── Services/
│       ├── ViewModels/
│       ├── Views/
│       ├── wwwroot/
│       ├── Program.cs
│       └── MobileSLI.Expedition.Web.csproj
├── .editorconfig
├── .gitignore
├── MobileSLI.Expedition.sln
└── README.md
```

## Prérequis

- .NET SDK 8.
- Windows, Linux ou VM serveur compatible ASP.NET Core.
- API centrale MobileSLI disponible pour le mode réel.

## Démarrage en développement

Par défaut, le projet utilise un client API fake pour tester les écrans sans API centrale.

```powershell
cd MobileSLI.Expedition
cd src\MobileSLI.Expedition.Web
dotnet restore
dotnet run
```

Puis ouvrir l'adresse indiquée par `dotnet run`, par exemple :

```text
http://localhost:5088
```

## Démarrage rapide avec le script PowerShell

```powershell
dotnet clean
dotnet restore
dotnet build
dotnet run --project ".\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj" --urls "http://127.0.0.1:5100"
```

## Passer du mode fake au mode API réelle

Dans `src/MobileSLI.Expedition.Web/appsettings.Development.json`, modifier :

```json
{
  "ExpeditionApi": {
    "UseFakeApi": false,
    "BaseUrl": "http://localhost:5000/"
  }
}
```

La base SQLite brouillon est créée automatiquement dans :

```text
data/expedition-drafts.sqlite3
```

Le dossier `data/` est volontairement ignoré par Git.

## Routes côté application web

| Route web | Rôle |
|---|---|
| `GET /` | Page d'accueil Expédition |
| `POST /expedition/charger` | Charge les données préparables via le GET global API |
| `GET /expedition/tournees` | Liste les tournées chargées côté web |
| `GET /expedition/tournees/{codeTournee}/preparer` | Préparation d'une tournée depuis les données déjà chargées |
| `POST /expedition/tournees/{codeTournee}/preparer` | Enregistre le brouillon SQLite côté web |
| `GET /expedition/tournees/{codeTournee}/recapitulatif` | Récapitulatif avant verrouillage automatique |

## Routes API centrale utilisées

Le module web Expédition utilise uniquement :

```text
GET  /api/expedition/preparations/a-preparer
POST /api/expedition/preparations/verrouiller
```

Aucun appel API central n'est effectué lors d'une modification de quantité, d'un changement de commentaire ou de l'ouverture d'une tournée déjà chargée.

## Initialiser ton git vide

```powershell
cd MobileSLI.Expedition
git init
git add .
git commit -m "Initialisation module Expedition"
```

Plus de détails dans `docs/INITIALISATION_GIT.md`.

## Limites connues de cette première base

- Le projet n'a pas été compilé dans l'environnement de génération du zip, car le SDK .NET n'y est pas installé.
- Le mode API réelle dépend du contrat exact exposé par ton API centrale.
- Le verrouillage automatique est présent côté application web, mais le contrôle définitif reste bien à faire côté API centrale, conformément au cahier des charges.
