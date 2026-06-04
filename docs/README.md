# Documentation SERVWEB Expedition

Ce dossier regroupe la documentation de reprise du serveur Web Expedition / Administration MobileSLI.

L’objectif est qu’un développeur ou un administrateur puisse comprendre, exploiter et maintenir le projet après le stage.

## Documents principaux

| Document | Rôle |
|---|---|
| `01-architecture/vue-ensemble-serveweb.md` | Vue d’ensemble technique du dépôt, responsabilités des couches, composants principaux |
| `02-fonctionnement/flux-expedition-administration.md` | Parcours métier Expedition et Administration, routes, règles de modification |
| `02-fonctionnement/stockage-local-sqlite.md` | Rôle de SQLite, données locales, rétention, verrouillage local |
| `03-deploiement/servweb-expedition-production.md` | Procédure de mise en production sur SERVWEB |
| `04-exploitation/diagnostic-et-reprise.md` | Commandes de diagnostic, contrôles quotidiens, erreurs connues, reprise |
| `05-reprise/guide-reprise-developpeur.md` | Guide de reprise pour le développeur suivant |
| `CONTRAT_JSON_EXPEDITION.md` | Contrat JSON utilisé entre SERVWEB et l’API centrale |
| `VERROUILLAGE_PLANIFIE_22H35.md` | Fonctionnement détaillé du verrouillage automatique à 22h35 |

## Ordre conseillé de lecture

Pour reprendre le projet rapidement :

1. lire `01-architecture/vue-ensemble-serveweb.md` ;
2. lire `02-fonctionnement/flux-expedition-administration.md` ;
3. lire `02-fonctionnement/stockage-local-sqlite.md` ;
4. lire `CONTRAT_JSON_EXPEDITION.md` ;
5. lire `03-deploiement/servweb-expedition-production.md` ;
6. lire `04-exploitation/diagnostic-et-reprise.md` ;
7. lire `05-reprise/guide-reprise-developpeur.md`.

## Etat de la documentation

Cette documentation décrit l’état actuel du dépôt `servewebEXPE` après stabilisation de la mise en production SERVWEB.

Points validés :

```text
- déploiement IIS en Production ;
- URLs finales expedition.sli.local et admin.sli.local ;
- port 80 avec host headers ;
- suppression de l’usage public du port 5100 ;
- artefact Release versionné ;
- verrouillage automatique 22h35 ;
- maintenance quotidienne 04h10 ;
- rétention SQLite 10 jours / 30 jours ;
- documentation de reprise ajoutée.
```

## Limite importante

La documentation ne remplace pas les tests.

Après chaque modification de code ou de configuration, il faut au minimum relancer :

```powershell
dotnet build .\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj -c Release
```

Puis, après déploiement serveur :

```powershell
Invoke-WebRequest "http://localhost/preparations/status" -UseBasicParsing
Invoke-WebRequest "http://expedition.sli.local" -UseBasicParsing
Invoke-WebRequest "http://admin.sli.local" -UseBasicParsing
```
