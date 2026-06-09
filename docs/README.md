# Documentation SERVWEB Expedition

Ce dossier regroupe la documentation de reprise du serveur Web Expedition / Administration MobileSLI.

L’objectif est qu’un développeur ou un administrateur puisse comprendre, exploiter et maintenir le projet après le stage.

## Etat vérifié de la documentation

Cette documentation a été réalignée avec le code du dépôt `servewebEXPE` après validation du code et tag des dépôts.

Faits vérifiés dans le code au moment de cette mise à jour :

```text
- application ASP.NET Core MVC en Production sur IIS ;
- URLs utilisateur finales : http://expedition.sli.local et http://admin.sli.local ;
- routage par host header : expedition.sli.local -> /expedition, admin.sli.local -> /administration ;
- port Web exposé : HTTP 80 ;
- port 5100 supprimé des scripts de production courants ;
- endpoint local de verrouillage : http://localhost/verrouillage/executer ;
- API centrale configurée par défaut : https://srvapi1.sli.local/ ;
- client API réel uniquement, FakeExpeditionApiClient non enregistré dans Program.cs ;
- verrouillage automatique 22h35 avec fenêtre de 20 minutes ;
- maintenance quotidienne 04h10 limitée aux fichiers, sans supervision réseau ;
- SQLite local conservé dans data/expedition-drafts.sqlite3 ;
- rétention SQLite : brouillons 10 jours, historique verrouillage 30 jours ;
- ROLLS_VIDES préparé côté Expédition, non affiché côté Administration.
```

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
  07-limites/
    dette-technique-et-ameliorations.md
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
| `07-limites/dette-technique-et-ameliorations.md` | Dette technique connue et améliorations futures |
| `99-archives/correction-verrouillage-developpement-2026-05-21.md` | Note historique conservée pour trace |

## Documents racine historiques

Certains documents restent à la racine de `docs` pour compatibilité avec les anciennes notes de travail :

```text
docs/ARCHITECTURE.md
docs/DEPLOIEMENT_FINAL_EXPEDITION.md
docs/EXPLOITATION_SUPERVISION.md
docs/VERROUILLAGE_PLANIFIE_22H35.md
docs/VerifVerrouillage.sql
```

Ils ont été corrigés quand ils contenaient des informations dangereusement obsolètes, notamment l’ancien port `5100` ou l’ancienne URL API HTTP/IP.

Pour une reprise propre, les documents de référence restent ceux rangés dans les sous-dossiers numérotés.

## Ordre conseillé de lecture

Pour reprendre le projet rapidement :

1. lire `01-architecture/vue-ensemble-serveweb.md` ;
2. lire `02-fonctionnement/flux-expedition-administration.md` ;
3. lire `02-fonctionnement/stockage-local-sqlite.md` ;
4. lire `01-api/contrat-json-expedition.md` ;
5. lire `02-fonctionnement/verrouillage-planifie-22h35.md` ;
6. lire `03-deploiement/servweb-expedition-production.md` ;
7. lire `04-exploitation/diagnostic-et-reprise.md` ;
8. lire `05-reprise/guide-reprise-developpeur.md` ;
9. lire `07-limites/dette-technique-et-ameliorations.md`.

## Règles de maintenance documentaire

1. Ne pas ajouter de document important directement à la racine de `docs`, sauf `README.md`.
2. Ranger les documents métier dans `02-fonctionnement`.
3. Ranger les contrats API dans `01-api`.
4. Ranger les procédures serveur dans `03-deploiement` ou `04-exploitation`.
5. Ranger les limites et améliorations futures dans `07-limites`.
6. Ranger les notes historiques dans `99-archives`.
7. Mettre à jour cet index quand un document est ajouté, déplacé ou supprimé.

## Limite importante

La documentation ne remplace pas les tests.

Après chaque modification de code ou de configuration, il faut au minimum relancer :

```powershell
dotnet build .\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj -c Release
```

Puis, après déploiement serveur :

```powershell
Invoke-WebRequest "https://srvapi1.sli.local/api/health" -UseBasicParsing
Invoke-WebRequest "http://localhost/preparations/status" -UseBasicParsing
Invoke-WebRequest "http://expedition.sli.local" -UseBasicParsing
Invoke-WebRequest "http://admin.sli.local" -UseBasicParsing
```
