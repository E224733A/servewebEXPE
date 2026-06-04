# Documentation SERVWEB Expedition

Ce dossier regroupe la documentation de reprise du serveur Web Expedition / Administration MobileSLI.

L’objectif est qu’un développeur ou un administrateur puisse comprendre, exploiter et maintenir le projet après le stage.

## Organisation du dossier

```text
docs/
  README.md
  01-architecture/
    vue-ensemble-serveweb.md
  01-api/
    contrat-json-expedition.md
  02-fonctionnement/
    flux-expedition-administration.md
    stockage-local-sqlite.md
    verrouillage-planifie-22h35.md
  03-deploiement/
    servweb-expedition-production.md
  04-exploitation/
    diagnostic-et-reprise.md
  05-reprise/
    guide-reprise-developpeur.md
  99-archives/
    correction-verrouillage-developpement-2026-05-21.md
```

## Documents principaux

| Document | Rôle |
|---|---|
| `01-architecture/vue-ensemble-serveweb.md` | Vue d’ensemble technique du dépôt |
| `01-api/contrat-json-expedition.md` | Contrat JSON entre SERVWEB et l’API centrale |
| `02-fonctionnement/flux-expedition-administration.md` | Parcours métier Expedition et Administration |
| `02-fonctionnement/stockage-local-sqlite.md` | Rôle de SQLite, données locales, rétention |
| `02-fonctionnement/verrouillage-planifie-22h35.md` | Fonctionnement du verrouillage automatique |
| `03-deploiement/servweb-expedition-production.md` | Mise en production sur SERVWEB |
| `04-exploitation/diagnostic-et-reprise.md` | Commandes de diagnostic et reprise incident |
| `05-reprise/guide-reprise-developpeur.md` | Guide pour le développeur suivant |
| `99-archives/correction-verrouillage-developpement-2026-05-21.md` | Note historique conservée pour trace |

## Ordre conseillé de lecture

Pour reprendre le projet rapidement :

1. lire `01-architecture/vue-ensemble-serveweb.md` ;
2. lire `02-fonctionnement/flux-expedition-administration.md` ;
3. lire `02-fonctionnement/stockage-local-sqlite.md` ;
4. lire `01-api/contrat-json-expedition.md` ;
5. lire `02-fonctionnement/verrouillage-planifie-22h35.md` ;
6. lire `03-deploiement/servweb-expedition-production.md` ;
7. lire `04-exploitation/diagnostic-et-reprise.md` ;
8. lire `05-reprise/guide-reprise-developpeur.md`.

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
- documentation de reprise ajoutée et rangée.
```

## Règles de maintenance documentaire

1. Ne pas ajouter de document important directement à la racine de `docs`, sauf `README.md`.
2. Ranger les documents métier dans `02-fonctionnement`.
3. Ranger les contrats API dans `01-api`.
4. Ranger les procédures serveur dans `03-deploiement` ou `04-exploitation`.
5. Ranger les notes historiques dans `99-archives`.
6. Mettre à jour cet index quand un document est ajouté, déplacé ou supprimé.

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
