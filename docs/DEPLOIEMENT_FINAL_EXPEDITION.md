# Déploiement final du module web Expédition

## Statut du document

Ce document racine est conservé pour compatibilité avec les anciennes notes de travail.

La procédure de référence actuelle est :

```text
docs/03-deploiement/servweb-expedition-production.md
```

L’ancienne procédure qui publiait directement vers `C:\Services\MobileSLI.Expedition.Web` et utilisait le port `5100` est obsolète.

## Etat actuel validé

```text
Serveur cible              : SERVWEB / SRVINTRAWEB1
Application IIS            : MobileSLI.Expedition.Web
Environnement ASP.NET Core : Production
Déploiement courant        : artefact Release versionné dans Git
Script courant             : scriptsdeploy/update-servweb-iis-prod.ps1
API centrale               : https://srvapi1.sli.local/
URL Expedition             : http://expedition.sli.local
URL Administration         : http://admin.sli.local
Endpoint verrouillage      : http://localhost/verrouillage/executer
Port Web exposé            : 80
Port obsolète              : 5100
```

## Ce qu’il ne faut plus utiliser

Ne plus utiliser comme procédure finale :

```text
http://192.168.1.232:5100/
http://192.168.1.232:5100/expedition
http://localhost:5100/verrouillage/executer
http://192.168.1.233:5000/
ExpeditionApi__RequireHttps = false en production finale
publication directe dans C:\Services\MobileSLI.Expedition.Web pour les mises à jour courantes
```

Ces valeurs ont été remplacées par :

```text
http://expedition.sli.local
http://admin.sli.local
http://localhost/verrouillage/executer
https://srvapi1.sli.local/
```

## Procédure de déploiement courante

Sur SERVWEB, en PowerShell administrateur :

```powershell
cd C:\Sources\servewebEXPE
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scriptsdeploy\update-servweb-iis-prod.ps1
```

Le serveur ne doit pas compiler l’application pour les mises à jour courantes.

Le script déploie l’artefact Git :

```text
artifacts/servweb/MobileSLI.Expedition.Web.zip
artifacts/servweb/manifest.json
```

## Variables importantes

La valeur importante injectée par le script est :

```text
ExpeditionApi__BaseUrl = https://srvapi1.sli.local/
```

L’environnement doit être :

```text
ASPNETCORE_ENVIRONMENT = Production
```

Vérification :

```powershell
Select-String `
  -Path "C:\Services\MobileSLI.Expedition.Web\web.config" `
  -Pattern "ASPNETCORE_ENVIRONMENT|ExpeditionApi__BaseUrl"
```

## Dossiers à conserver

Ne pas supprimer au déploiement :

```text
C:\Services\MobileSLI.Expedition.Web\data
C:\Services\MobileSLI.Expedition.Web\logs
C:\Services\MobileSLI.Expedition.Web\scripts
```

| Dossier | Contenu |
|---|---|
| `data` | SQLite local et payloads de diagnostic |
| `logs` | logs verrouillage, maintenance, heartbeat |
| `scripts` | scripts exécutés par les tâches Windows |

## Tâche planifiée Windows

La tâche doit être :

```text
MobileSLI SERVEXPE Verrouillage 22h35
```

Elle exécute :

```text
C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1
```

Le script appelle :

```text
http://localhost/verrouillage/executer
```

Contrôle :

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

Bindings attendus :

```text
*:80:expedition.sli.local
*:80:admin.sli.local
*:80:localhost
```

Commande :

```powershell
Import-Module WebAdministration
Get-WebBinding -Name "MobileSLI.Expedition.Web" | Select-Object protocol, bindingInformation
```

Aucun binding `*:5100:*` ne doit rester.

## Test fonctionnel de déploiement

1. Ouvrir `http://expedition.sli.local`.
2. Cliquer sur `Mode test API`.
3. Vérifier que l’API centrale répond.
4. Cliquer sur `Charger les données à préparer`.
5. Vérifier que la date affichée correspond à la date métier calculée par l’API centrale.
6. Ouvrir une tournée.
7. Saisir des quantités `ROLLS`, `ROLLS_VIDES`, `TAPIS` et `SACS` côté Expedition.
8. Enregistrer.
9. Vérifier que les valeurs persistent après redémarrage de l’application.
10. Marquer la tournée prête pour verrouillage.
11. Laisser la tâche Windows exécuter le verrouillage à 22h35.
12. Vérifier le heartbeat.
13. Vérifier SQL Server côté API centrale.
14. Vérifier que le mobile lit les données Expedition verrouillées.

## Test manuel du script de verrouillage

Sur SERVWEB, dans une fenêtre PowerShell administrateur :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
```

À utiliser uniquement pour diagnostic. Le fonctionnement normal reste la tâche planifiée.

Hors fenêtre 22h35-22h55, l’application peut refuser le verrouillage planifié.

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
  "date": "2026-06-04T22:35:15.0000000+02:00",
  "codeRetour": 0,
  "message": "SUCCESS",
  "url": "http://localhost/verrouillage/executer"
}
```

## Points de sécurité

- Ne pas versionner de secret.
- Restreindre l’accès à l’interface web aux postes autorisés.
- Ne pas exposer SERVWEB aux téléphones livreurs.
- Réserver `/verrouillage/executer` à `localhost`.
- Préférer un filtrage réseau par pare-feu Windows ou IIS.
- Préparer HTTPS SERVWEB dans un lot futur séparé si nécessaire.
- Ne pas réintroduire le port `5100` comme solution finale.

## Rollback simple

En cas de problème après publication :

1. restaurer le dossier précédent de `C:\Services\MobileSLI.Expedition.Web` depuis sauvegarde ;
2. redémarrer le site IIS ;
3. vérifier `/preparations/status` ;
4. vérifier `http://expedition.sli.local` ;
5. vérifier `http://admin.sli.local` ;
6. vérifier que la tâche Windows pointe toujours vers le bon script ;
7. vérifier le dernier heartbeat.

La base SQLite contient les brouillons. Ne pas supprimer le fichier SQLite sans sauvegarde si des préparations non verrouillées sont encore utiles.
