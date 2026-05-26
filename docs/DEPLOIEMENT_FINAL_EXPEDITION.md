# Déploiement final du module web Expédition

## Objectif

Ce document décrit le déploiement final de SERVEXPE, l’application web Expédition du projet MobileSLI.

La version finale utilise l’API centrale réelle et non le client fake.

Routes métier utilisées :

```text
GET  /api/expedition/preparations/a-preparer
POST /api/expedition/preparations/verrouiller
```

Verrouillage automatique :

```text
Tous les jours à 22h35
```

## Pré-requis serveur

- Windows Server ou poste serveur validé.
- IIS configuré pour héberger l’application ASP.NET Core.
- .NET Hosting Bundle ou runtime compatible avec le projet.
- Accès réseau de SERVEXPE vers l’API centrale.
- Port SERVEXPE ouvert uniquement pour les postes autorisés.
- Accès en écriture au dossier de service.

Dossier de service recommandé :

```text
C:\Services\MobileSLI.Expedition.Web
```

Dossier source recommandé :

```text
C:\Sources\servewebEXPE
```

## Variables d’environnement recommandées

À adapter selon l’environnement.

```powershell
[Environment]::SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "Production", "Machine")
[Environment]::SetEnvironmentVariable("ExpeditionApi__BaseUrl", "http://192.168.1.233:5000/", "Machine")
[Environment]::SetEnvironmentVariable("ExpeditionApi__RequireHttps", "false", "Machine")
[Environment]::SetEnvironmentVariable("ExpeditionDb__DatabasePath", "C:\Services\MobileSLI.Expedition.Web\data\expedition-drafts.sqlite3", "Machine")
```

Si l’API centrale exige une clé :

```powershell
[Environment]::SetEnvironmentVariable("ExpeditionApi__ApiKeyHeaderName", "X-Expedition-Api-Key", "Machine")
[Environment]::SetEnvironmentVariable("ExpeditionApi__ApiKey", "VALEUR_SECRETE_A_NE_PAS_COMMIT", "Machine")
```

Si le endpoint local de verrouillage doit utiliser un secret :

```powershell
[Environment]::SetEnvironmentVariable("Verrouillage__LockSecret", "VALEUR_SECRETE_A_NE_PAS_COMMIT", "Machine")
[Environment]::SetEnvironmentVariable("SERVEXPE_LOCK_SECRET", "VALEUR_SECRETE_A_NE_PAS_COMMIT", "Machine")
```

Les deux valeurs doivent être identiques si `Verrouillage__LockSecret` est renseigné.

## Publication applicative

Depuis le dépôt source :

```powershell
cd C:\Sources\servewebEXPE

git pull

dotnet restore .\MobileSLI.Expedition.sln

dotnet publish .\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj `
    -c Release `
    -o C:\Services\MobileSLI.Expedition.Web
```

Créer les dossiers de données et de logs :

```powershell
New-Item -ItemType Directory -Force "C:\Services\MobileSLI.Expedition.Web\data" | Out-Null
New-Item -ItemType Directory -Force "C:\Services\MobileSLI.Expedition.Web\logs" | Out-Null
New-Item -ItemType Directory -Force "C:\Services\MobileSLI.Expedition.Web\scripts" | Out-Null
```

Copier le script de verrouillage :

```powershell
Copy-Item `
  -Path "C:\Sources\servewebEXPE\scriptsdeploy\run-verrouillage.ps1" `
  -Destination "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1" `
  -Force
```

Vérifier la présence du script :

```powershell
Test-Path "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
```

Résultat attendu :

```text
True
```

## Installation de la tâche planifiée Windows

Depuis le dépôt source, en PowerShell administrateur :

```powershell
cd C:\Sources\servewebEXPE
.\scriptsdeploy\register-verrouillage-task.ps1
```

La tâche créée ou mise à jour doit être :

```text
MobileSLI SERVEXPE Verrouillage 22h35
```

Configuration attendue :

```text
Déclenchement : tous les jours à 22:35
Action        : powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
Comportement  : StartWhenAvailable
Instances     : IgnoreNew
Durée max     : 10 minutes
```

## Contrôle de la tâche planifiée

Lister les tâches de verrouillage :

```powershell
Get-ScheduledTask |
    Where-Object { $_.TaskName -like "*Verrouillage*" } |
    Select-Object TaskName, State
```

Afficher le prochain déclenchement :

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35" |
    Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Résultat attendu après une exécution réussie :

```text
LastTaskResult = 0
NextRunTime    = prochain jour à 22:35
```

Vérifier qu’il ne reste pas d’ancienne tâche 23h55 :

```powershell
Get-ScheduledTask |
    Where-Object { $_.TaskName -like "*23h55*" -or $_.TaskName -like "*23:55*" }
```

Résultat attendu : aucun résultat.

## Configuration IIS et réseau

L’application doit être disponible sur le serveur en interne, par exemple :

```text
http://192.168.1.232:5100/
```

Le endpoint technique suivant doit rester local au serveur :

```text
http://localhost:5100/verrouillage/executer
```

Un appel réseau direct depuis un autre poste vers `/verrouillage/executer` doit être refusé.

Test depuis un autre poste :

```powershell
curl.exe -i -X POST "http://192.168.1.232:5100/verrouillage/executer" -H "Content-Type: application/json" --data-raw "{}"
```

Résultat attendu :

```text
HTTP/1.1 403 Forbidden
Accès refusé : verrouillage planifié réservé à localhost.
```

## Test fonctionnel de déploiement

1. Ouvrir l’interface SERVEXPE.
2. Cliquer sur `Mode test API`.
3. Vérifier que l’API centrale répond.
4. Cliquer sur `Charger les données à préparer`.
5. Vérifier que la date affichée correspond à la date métier calculée par l’API centrale.
6. Ouvrir une tournée.
7. Saisir des quantités ROLLS, TAPIS et SACS.
8. Enregistrer.
9. Vérifier que les valeurs persistent après redémarrage de l’application.
10. Marquer la tournée prête pour verrouillage.
11. Laisser la tâche Windows exécuter le verrouillage à 22h35.
12. Vérifier le heartbeat.
13. Vérifier SQL Server côté API centrale.
14. Vérifier que le mobile lit les données Expédition verrouillées.

## Test manuel du script de verrouillage

Sur SERVWEB, dans une fenêtre PowerShell administrateur :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
```

À utiliser uniquement pour diagnostic. Le fonctionnement normal reste la tâche planifiée.

## Logs attendus

Dossier :

```text
C:\Services\MobileSLI.Expedition.Web\logs
```

Fichier principal :

```text
verrouillage-planifie.log
```

Fichier heartbeat :

```text
verrouillage-planifie-heartbeat.json
```

Succès attendu :

```json
{
  "date": "2026-05-22T22:35:15.0000000+02:00",
  "codeRetour": 0,
  "message": "SUCCESS"
}
```

## Points de sécurité

- Ne pas versionner de secret.
- Restreindre l’accès à l’interface web aux postes autorisés.
- Ne pas exposer SERVEXPE aux téléphones livreurs.
- Bloquer `/verrouillage/executer` hors localhost.
- Préférer un filtrage réseau par pare-feu Windows ou IIS.
- Utiliser HTTPS si le contexte réseau l’exige.

## Rollback simple

En cas de problème après publication :

1. Restaurer le dossier précédent de `C:\Services\MobileSLI.Expedition.Web` depuis sauvegarde.
2. Redémarrer le site IIS.
3. Vérifier `/expedition`.
4. Vérifier que la tâche Windows pointe toujours vers le bon script.
5. Vérifier le dernier heartbeat.

La base SQLite contient les brouillons. Ne pas supprimer le fichier SQLite sans sauvegarde si des préparations non verrouillées sont encore utiles.
