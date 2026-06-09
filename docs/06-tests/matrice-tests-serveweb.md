# Matrice de tests Web SERVWEB

## Objectif

Cette matrice liste les tests fonctionnels minimum à exécuter avant un rendu, après une modification importante ou après un déploiement SERVWEB.

Elle couvre uniquement l’application Web Expedition / Administration du dépôt `servewebEXPE`.

## Conventions

| Statut | Signification |
|---|---|
| A TESTER | scénario documenté mais non exécuté dans cette campagne |
| OK | scénario exécuté et conforme |
| KO | scénario exécuté et non conforme |
| NON APPLICABLE | scénario non applicable au contexte de test |

## Préconditions générales

```text
- API centrale disponible sur https://srvapi1.sli.local/.
- SERVWEB démarré en environnement Production pour les tests serveur.
- Une date métier préparable existe côté API centrale.
- Les DNS expedition.sli.local et admin.sli.local répondent.
- Le poste de test a accès au réseau intranet.
- Le port 5100 n’est pas utilisé comme URL de test finale.
```

## Tests Expedition

| ID | Scénario | Précondition | Actions | Résultat attendu | Statut |
|---|---|---|---|---|---|
| WEB-EXP-001 | Accueil Expedition | Application déployée | Ouvrir `http://expedition.sli.local` | Page Expedition affichée | A TESTER |
| WEB-EXP-002 | Chargement données Expedition | API disponible | Cliquer sur charger les données | Données chargées, redirection vers les tournées | A TESTER |
| WEB-EXP-003 | Liste des tournées | Données chargées | Ouvrir `/expedition/tournees` | Liste des tournées affichée | A TESTER |
| WEB-EXP-004 | Ouvrir une tournée | Données chargées | Ouvrir une tournée | Lignes de préparation affichées | A TESTER |
| WEB-EXP-005 | Saisir quantité valide | Tournée non verrouillée | Saisir une quantité positive ou zéro | Sauvegarde acceptée | A TESTER |
| WEB-EXP-006 | Refuser quantité négative | Tournée non verrouillée | Saisir une quantité négative | Erreur affichée, valeur refusée | A TESTER |
| WEB-EXP-007 | Détail ligne | Tournée ouverte | Ouvrir le détail d’une ligne | Détail affiché | A TESTER |
| WEB-EXP-008 | Sauvegarde depuis détail ligne | Tournée non verrouillée | Modifier une quantité depuis le détail | Sauvegarde acceptée | A TESTER |
| WEB-EXP-009 | Récapitulatif tournée | Tournée préparée | Ouvrir le récapitulatif | Quantités saisies visibles | A TESTER |
| WEB-EXP-010 | Marquer prête | Tournée non verrouillée | Cliquer `Marquer prête` | Statut prêt pour verrouillage | A TESTER |
| WEB-EXP-011 | Correction après prêt | Tournée prête | Modifier une quantité | Tournée reste prête | A TESTER |
| WEB-EXP-012 | Tournée verrouillée non modifiable | Tournée verrouillée | Tenter une modification | Modification refusée | A TESTER |
| WEB-EXP-013 | ROLLS_VIDES côté Expedition | Tournée chargée | Vérifier la présence de l’article `ROLLS_VIDES` | L’article est affiché et saisissable côté Expedition | A TESTER |

## Tests Administration

| ID | Scénario | Précondition | Actions | Résultat attendu | Statut |
|---|---|---|---|---|---|
| WEB-ADM-001 | Accueil Administration | Application déployée | Ouvrir `http://admin.sli.local` | Page Administration affichée | A TESTER |
| WEB-ADM-002 | Chargement données Administration | API disponible | Cliquer sur charger les données | Données chargées, redirection vers les tournées | A TESTER |
| WEB-ADM-003 | Liste des tournées | Données chargées | Ouvrir `/administration/tournees` | Liste des tournées affichée | A TESTER |
| WEB-ADM-004 | Ouvrir commentaires | Données chargées | Ouvrir les commentaires d’une tournée | Lignes avec zone commentaire affichées | A TESTER |
| WEB-ADM-005 | Saisir commentaire valide | Tournée non verrouillée | Saisir un commentaire court | Sauvegarde acceptée | A TESTER |
| WEB-ADM-006 | Refuser commentaire trop long | Tournée non verrouillée | Saisir plus de 400 caractères | Erreur affichée, commentaire refusé | A TESTER |
| WEB-ADM-007 | Tournée verrouillée non modifiable | Tournée verrouillée | Tenter de modifier un commentaire | Modification refusée | A TESTER |
| WEB-ADM-008 | ROLLS_VIDES absent côté Administration | Tournée chargée | Vérifier les articles affichés | `ROLLS_VIDES` n’est pas affiché côté Administration | A TESTER |

## Tests routage DNS

| ID | Scénario | Précondition | Actions | Résultat attendu | Statut |
|---|---|---|---|---|---|
| WEB-DNS-001 | Racine Expedition | DNS actif | Ouvrir `http://expedition.sli.local` | Redirection ou affichage Expedition | A TESTER |
| WEB-DNS-002 | Racine Administration | DNS actif | Ouvrir `http://admin.sli.local` | Redirection ou affichage Administration | A TESTER |
| WEB-DNS-003 | Mauvais module depuis admin | DNS actif | Ouvrir `http://admin.sli.local/expedition` | Redirection vers `/administration` | A TESTER |
| WEB-DNS-004 | Mauvais module depuis expedition | DNS actif | Ouvrir `http://expedition.sli.local/administration` | Redirection vers `/expedition` | A TESTER |

## Tests API centrale depuis SERVWEB

| ID | Scénario | Précondition | Actions | Résultat attendu | Statut |
|---|---|---|---|---|---|
| WEB-API-001 | Santé API centrale | SERVWEB connecté au réseau | `Invoke-WebRequest https://srvapi1.sli.local/api/health -UseBasicParsing` | HTTP 200 | A TESTER |
| WEB-API-002 | Test API depuis Expedition | Interface disponible | Cliquer test API Expedition | Message API joignable | A TESTER |
| WEB-API-003 | Test API depuis Administration | Interface disponible | Cliquer test API Administration | Message API joignable | A TESTER |

## Tests verrouillage

| ID | Scénario | Précondition | Actions | Résultat attendu | Statut |
|---|---|---|---|---|---|
| WEB-LOCK-001 | Tâche 22h35 présente | Déploiement fait | `Get-ScheduledTaskInfo` | Tâche trouvée | A TESTER |
| WEB-LOCK-002 | Heartbeat verrouillage | Tâche exécutée | Lire `verrouillage-planifie-heartbeat.json` | `codeRetour = 0` après succès | A TESTER |
| WEB-LOCK-003 | Endpoint local protégé | App active | Appel distant non local | HTTP 403 attendu | A TESTER |
| WEB-LOCK-004 | Status local | App active | `Invoke-WebRequest http://localhost/preparations/status` | HTTP 200 JSON | A TESTER |
| WEB-LOCK-005 | Endpoint local sans port 5100 | Déploiement fait | Vérifier `run-verrouillage.ps1` | URL `http://localhost/verrouillage/executer` | A TESTER |

## Tests maintenance serveur

| ID | Scénario | Précondition | Actions | Résultat attendu | Statut |
|---|---|---|---|---|---|
| WEB-MAINT-001 | Tâche maintenance présente | Script enregistré | `schtasks /Query /TN "MobileSLI SERVWEB Maintenance quotidienne" /V /FO LIST` | Tâche trouvée | A TESTER |
| WEB-MAINT-002 | Exécution maintenance | Tâche présente | `schtasks /Run` puis query | `Dernier résultat: 0` | A TESTER |
| WEB-MAINT-003 | Log maintenance | Maintenance exécutée | Lire `maintenance-servweb.log` | Fin maintenance visible | A TESTER |

## Tests déploiement

| ID | Scénario | Précondition | Actions | Résultat attendu | Statut |
|---|---|---|---|---|---|
| WEB-DEPLOY-001 | Build Release local | Code récupéré | `dotnet build -c Release` | 0 erreur | A TESTER |
| WEB-DEPLOY-002 | Publication artefact | Build OK | `publish-servweb-artifact.ps1` | ZIP et manifest générés | A TESTER |
| WEB-DEPLOY-003 | Déploiement SERVWEB | Artefact publié | `update-servweb-iis-prod.ps1` | Sites HTTP 200 | A TESTER |
| WEB-DEPLOY-004 | Vérifier Production | Déploiement fait | Lire `web.config` | `ASPNETCORE_ENVIRONMENT=Production` | A TESTER |
| WEB-DEPLOY-005 | Vérifier URL API injectée | Déploiement fait | Lire `web.config` | `ExpeditionApi__BaseUrl=https://srvapi1.sli.local/` | A TESTER |
| WEB-DEPLOY-006 | Vérifier absence port 5100 | Déploiement fait | Lire bindings IIS | Aucun binding `*:5100:*` | A TESTER |

## Commandes rapides de campagne

```powershell
dotnet build .\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj -c Release
Invoke-WebRequest "https://srvapi1.sli.local/api/health" -UseBasicParsing
Invoke-WebRequest "http://localhost/preparations/status" -UseBasicParsing
Invoke-WebRequest "http://expedition.sli.local" -UseBasicParsing
Invoke-WebRequest "http://admin.sli.local" -UseBasicParsing
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"
schtasks /Query /TN "MobileSLI SERVWEB Maintenance quotidienne" /V /FO LIST
```

## Règle de validation avant rendu

Avant rendu, les scénarios minimum à passer en `OK` sont :

```text
WEB-EXP-001 à WEB-EXP-013
WEB-ADM-001 à WEB-ADM-008
WEB-DNS-001 à WEB-DNS-004
WEB-API-001 à WEB-API-003
WEB-LOCK-001 à WEB-LOCK-005
WEB-MAINT-001 à WEB-MAINT-003
WEB-DEPLOY-001 à WEB-DEPLOY-006
```
