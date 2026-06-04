# Guide de reprise développeur

## Objectif

Ce guide est destiné au développeur qui reprendra le projet `servewebEXPE` après le stage.

Il donne les points importants à comprendre avant de modifier le code.

## Résumé du projet

`servewebEXPE` est une application Web ASP.NET Core MVC utilisée en intranet pour préparer les tournées Expedition.

Elle possède deux interfaces :

```text
Expedition      -> quantités prévues
Administration  -> commentaires exceptionnels
```

Elle dépend de l’API centrale MobileSLI pour :

```text
GET  /api/expedition/preparations/a-preparer
POST /api/expedition/preparations/verrouiller
GET  /api/health
```

## Avant de modifier le code

Lire dans cet ordre :

1. `docs/README.md` ;
2. `docs/01-architecture/vue-ensemble-serveweb.md` ;
3. `docs/02-fonctionnement/flux-expedition-administration.md` ;
4. `docs/02-fonctionnement/stockage-local-sqlite.md` ;
5. `docs/CONTRAT_JSON_EXPEDITION.md` ;
6. `docs/VERROUILLAGE_PLANIFIE_22H35.md` ;
7. `docs/03-deploiement/servweb-expedition-production.md` ;
8. `docs/04-exploitation/diagnostic-et-reprise.md`.

## Points de code à connaître

| Fichier | Rôle |
|---|---|
| `Program.cs` | configuration DI, middleware, routage DNS, sécurité légère |
| `Controllers/ExpeditionController.cs` | parcours Expedition, quantités, marquage prêt |
| `Controllers/AdministrationController.cs` | parcours Administration, commentaires exceptionnels |
| `Controllers/VerrouillageController.cs` | endpoint local verrouillage, retry, status |
| `Services/ExpeditionApiClient.cs` | appels HTTP vers API centrale |
| `Services/VerrouillageService.cs` | orchestration du verrouillage |
| `Data/SqliteExpeditionDraftStore.cs` | stockage local et construction du lot |
| `Application/Expedition/ExpeditionPreparationValidator.cs` | validation des quantités |
| `Application/Administration/AdministrationCommentaireValidator.cs` | validation des commentaires |
| `Application/Common/SharedPreparationViewModelBuilder.cs` | construction commune des vues |

## Règles à ne pas casser

1. Ne pas faire choisir la date métier à SERVWEB.
2. Ne pas rappeler l’API centrale à chaque ouverture de tournée.
3. Ne pas supprimer le dossier `data` au déploiement.
4. Ne pas supprimer le dossier `logs` au déploiement.
5. Ne pas supprimer le dossier `scripts` au déploiement.
6. Ne pas réutiliser le port 5100 comme URL publique.
7. Ne pas activer `UseFakeApi=true` en production.
8. Ne pas rendre modifiable une tournée verrouillée.
9. Ne pas mélanger quantités Expedition et commentaires Administration.
10. Ne pas faire de supervision réseau dans la tâche de maintenance quotidienne.

## Build local

Commande minimale :

```powershell
dotnet build .\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj -c Release
```

Résultat attendu :

```text
Build succeeded
0 Error(s)
```

## Déploiement

Le serveur SERVWEB ne doit pas compiler.

Procédure :

1. publier un artefact depuis le poste de développement ;
2. pousser l’artefact dans Git ;
3. sur SERVWEB, lancer `update-servweb-iis-prod.ps1`.

Voir :

```text
docs/03-deploiement/servweb-expedition-production.md
```

## Tests minimum après modification

Après chaque changement de code :

```powershell
dotnet build .\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj -c Release
```

Après déploiement :

```powershell
Invoke-WebRequest "http://localhost/preparations/status" -UseBasicParsing
Invoke-WebRequest "http://expedition.sli.local" -UseBasicParsing
Invoke-WebRequest "http://admin.sli.local" -UseBasicParsing
```

Contrôler aussi :

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"
schtasks /Query /TN "MobileSLI SERVWEB Maintenance quotidienne" /V /FO LIST
```

## Dette technique connue

Le projet est fonctionnel et maintenable, mais il reste une dette technique :

1. certains contrôleurs contiennent encore de l’orchestration ;
2. `SqliteExpeditionDraftStore` regroupe beaucoup de responsabilités ;
3. les tests automatisés sont limités ;
4. le rollback est manuel ;
5. la supervision externe n’existe pas encore.

## Améliorations futures conseillées

Priorité 1 : tests automatisés sur validators et builders.

Priorité 2 : découper progressivement `SqliteExpeditionDraftStore`.

Priorité 3 : ajouter une supervision externe simple.

Priorité 4 : ajouter une documentation SQL de diagnostic côté API centrale.

Priorité 5 : formaliser une matrice de tests Web Expedition / Administration.

## Phrase de reprise honnête

Le projet n’est pas une architecture parfaite, mais il est stabilisé :

```text
Les contrôleurs ont été allégés progressivement, la logique de construction des vues est isolée dans des builders, les validations principales sont séparées, le stockage local est centralisé dans SQLite, le déploiement SERVWEB est scripté et la mise en production est documentée. Il reste une dette technique identifiée, surtout autour du stockage SQLite et du manque de tests automatisés, mais elle est connue et maîtrisée.
```
