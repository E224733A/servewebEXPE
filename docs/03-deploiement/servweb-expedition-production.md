# Mise en production SERVWEB Expedition

## Objectif

Ce document décrit la procédure de mise en production du serveur Web Expedition / Administration MobileSLI.

Le serveur concerné est le serveur intranet SERVWEB / SRVINTRAWEB1.

La règle retenue est la suivante :

```text
SERVWEB ne compile pas l'application.
SERVWEB déploie uniquement un artefact Release déjà publié dans Git.
```

## Etat cible

| Élément | Valeur cible |
|---|---|
| Site IIS | `MobileSLI.Expedition.Web` |
| AppPool IIS | `MobileSLI.Expedition.Web` |
| Dossier dépôt Git serveur | `C:\Sources\servewebEXPE` |
| Dossier publish temporaire | `C:\Publish\MobileSLI.Expedition.Web` |
| Dossier application IIS | `C:\Services\MobileSLI.Expedition.Web` |
| Dossier backups | `C:\Backups\MobileSLI.Expedition.Web` |
| DNS Expedition | `http://expedition.sli.local` |
| DNS Administration | `http://admin.sli.local` |
| Endpoint local verrouillage | `http://localhost/verrouillage/executer` |
| API centrale | `http://api.mobilesli.intra:5000/` |
| Port Web exposé | `80` |
| Environnement ASP.NET Core | `Production` |

## Principe de déploiement

Le poste de développement publie l'application en Release dans un artefact Git :

```text
artifacts/servweb/MobileSLI.Expedition.Web.zip
artifacts/servweb/manifest.json
```

Le serveur SERVWEB récupère ensuite le dépôt Git et déploie cet artefact.

Le script serveur de production est :

```text
scriptsdeploy/update-servweb-iis-prod.ps1
```

Ce script :

1. synchronise le dépôt local avec `origin/main` ;
2. supprime les modifications locales du serveur ;
3. extrait l'artefact Git ;
4. sauvegarde la version actuellement déployée ;
5. met l'application temporairement hors ligne avec `app_offline.htm` ;
6. copie les fichiers publiés vers IIS ;
7. conserve les dossiers `data`, `logs` et `scripts` ;
8. configure `web.config` en `Production` ;
9. configure l'URL de l'API centrale ;
10. donne les droits à l'AppPool sur `data`, `logs` et `scripts` ;
11. vérifie les bindings IIS ;
12. supprime les restes du port 5100 ;
13. redémarre IIS ;
14. exécute les tests HTTP finaux.

## Publication d'un artefact depuis le poste de développement

Depuis le poste de développement :

```powershell
cd C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scriptsdeploy\publish-servweb-artifact.ps1 -SourceCommitMessage "Message source"
```

Le script de publication effectue :

```text
git fetch / git pull
dotnet restore
dotnet build -c Release
dotnet publish -c Release
création du ZIP
mise à jour du manifest
commit de l'artefact
push vers GitHub
```

Après publication, le dépôt doit contenir un nouveau commit d'artefact de type :

```text
Publie artefact SERVWEB <commit_source>
```

## Déploiement sur SERVWEB

Sur SERVWEB, dans PowerShell administrateur :

```powershell
cd C:\Sources\servewebEXPE
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scriptsdeploy\update-servweb-iis-prod.ps1
```

Le script doit afficher :

```text
Environnement ASP         : Production
ASPNETCORE_ENVIRONMENT = Production
ExpeditionApi__BaseUrl = http://api.mobilesli.intra:5000/
```

## Vérifications après déploiement

### Vérifier le manifest déployé

```powershell
Get-Content "C:\Services\MobileSLI.Expedition.Web\manifest.json" -Raw
```

Champs attendus :

```text
project = MobileSLI.Expedition.Web
configuration = Release
deployTarget = SERVWEB IIS
serverBuild = false
```

### Vérifier le web.config

```powershell
Select-String `
  -Path "C:\Services\MobileSLI.Expedition.Web\web.config" `
  -Pattern "ASPNETCORE_ENVIRONMENT"
```

Résultat attendu :

```xml
<environmentVariable name="ASPNETCORE_ENVIRONMENT" value="Production" />
```

### Vérifier les endpoints principaux

```powershell
Invoke-WebRequest "http://localhost/preparations/status" -UseBasicParsing
Invoke-WebRequest "http://expedition.sli.local" -UseBasicParsing
Invoke-WebRequest "http://admin.sli.local" -UseBasicParsing
```

Résultat attendu :

```text
StatusCode = 200
```

### Vérifier les redirections croisées

```powershell
Invoke-WebRequest "http://admin.sli.local/expedition" -UseBasicParsing -MaximumRedirection 0
Invoke-WebRequest "http://expedition.sli.local/administration" -UseBasicParsing -MaximumRedirection 0
```

Résultat attendu :

```text
http://admin.sli.local/expedition          -> 302 vers /administration
http://expedition.sli.local/administration -> 302 vers /expedition
```

## Dossiers conservés au déploiement

Le déploiement ne doit pas supprimer :

```text
C:\Services\MobileSLI.Expedition.Web\data
C:\Services\MobileSLI.Expedition.Web\logs
C:\Services\MobileSLI.Expedition.Web\scripts
```

Ces dossiers contiennent respectivement :

| Dossier | Contenu |
|---|---|
| `data` | base SQLite locale `expedition-drafts.sqlite3` |
| `logs` | logs verrouillage, logs maintenance, heartbeat |
| `scripts` | scripts exécutés par les tâches Windows |

## Rétention locale SQLite

La rétention locale est codée dans :

```text
src/MobileSLI.Expedition.Web/Data/SqliteExpeditionDraftStore.cs
```

Valeurs actuellement attendues :

```text
DraftRetentionDays = 10
LockHistoryRetentionDays = 30
```

Interprétation :

| Donnée locale | Conservation |
|---|---:|
| chargements, états, brouillons, lignes locales | 10 jours |
| historique local des verrouillages | 30 jours |

La purge SQLite reste gérée par l'application. Le script de maintenance Windows ne modifie pas directement la base SQLite.

## Tâche planifiée de verrouillage Expédition

La tâche métier de verrouillage doit exister :

```text
MobileSLI SERVEXPE Verrouillage 22h35
```

Elle exécute :

```text
C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1
```

Le script appelle localement :

```text
POST http://localhost/verrouillage/executer
```

Le port `5100` ne doit plus être utilisé.

Contrôle :

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35" |
    Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Logs :

```text
C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log
C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json
```

## Tâche planifiée de maintenance SERVWEB

La tâche de maintenance doit exister :

```text
MobileSLI SERVWEB Maintenance quotidienne
```

Elle est créée ou mise à jour par :

```powershell
cd C:\Sources\servewebEXPE
.\scriptsdeploy\register-servweb-maintenance-task.ps1
```

Le script de création :

1. vérifie que PowerShell est lancé en administrateur ;
2. copie le script source vers le dossier déployé ;
3. crée la tâche avec `schtasks.exe` ;
4. configure l'exécution sous `SYSTEM` ;
5. planifie l'exécution quotidienne à `04:10`.

Script exécuté par la tâche :

```text
C:\Services\MobileSLI.Expedition.Web\scripts\maintenance-servweb-runtime.ps1
```

Le script de maintenance :

1. journalise son exécution ;
2. archive les gros fichiers `.log` ;
3. supprime les anciens logs archivés ;
4. supprime les anciens backups de déploiement ;
5. ne touche pas à SQLite ;
6. ne supprime pas le payload debug versionné ;
7. ne fait pas de test HTTP/TCP applicatif.

Le contrôle réseau a volontairement été retiré de cette tâche. Des tests HTTP/TCP lancés sous le compte `SYSTEM` ont provoqué des erreurs mémoire instables sur SERVWEB. La supervision applicative reste donc séparée de la maintenance fichiers.

Contrôle manuel du script de maintenance :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Services\MobileSLI.Expedition.Web\scripts\maintenance-servweb-runtime.ps1"
```

Résultat attendu dans le log :

```text
Controle applicatif reseau ignore dans cette tache pour fiabilite SYSTEM.
Logs rotations : 0
Logs archives supprimes : 0
Backups supprimes : 0
Fin maintenance SERVWEB
```

Test de la tâche :

```powershell
schtasks /Run /TN "MobileSLI SERVWEB Maintenance quotidienne"
Start-Sleep -Seconds 15
schtasks /Query /TN "MobileSLI SERVWEB Maintenance quotidienne" /V /FO LIST
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\maintenance-servweb.log" -Tail 80
```

Résultat attendu :

```text
Dernier résultat: 0
```

## Contrôle applicatif séparé de la maintenance

Comme la tâche de maintenance ne fait plus de test réseau, le contrôle applicatif doit être fait séparément :

```powershell
Invoke-WebRequest "http://localhost/preparations/status" -UseBasicParsing
Invoke-WebRequest "http://expedition.sli.local" -UseBasicParsing
Invoke-WebRequest "http://admin.sli.local" -UseBasicParsing
```

Ces vérifications sont aussi exécutées par le script de déploiement production `update-servweb-iis-prod.ps1`.

## Rollback applicatif

Les sauvegardes de déploiement sont créées dans :

```text
C:\Backups\MobileSLI.Expedition.Web\yyyyMMdd-HHmmss
```

Procédure de rollback manuel :

1. arrêter le site ou créer `app_offline.htm` ;
2. copier le contenu du backup choisi vers `C:\Services\MobileSLI.Expedition.Web` ;
3. conserver `data`, `logs` et `scripts` si le backup ne doit pas les remplacer ;
4. redémarrer l'AppPool ;
5. vérifier les endpoints.

Commandes indicatives :

```powershell
Import-Module WebAdministration
Stop-WebAppPool -Name "MobileSLI.Expedition.Web"
robocopy "C:\Backups\MobileSLI.Expedition.Web\yyyyMMdd-HHmmss" "C:\Services\MobileSLI.Expedition.Web" /MIR /R:3 /W:5 /XD data logs scripts /XF *.log
Start-WebAppPool -Name "MobileSLI.Expedition.Web"
Invoke-WebRequest "http://localhost/preparations/status" -UseBasicParsing
```

## Erreurs connues et diagnostic

### `git pull` échoue sur SERVWEB avec mémoire insuffisante

Symptôme possible :

```text
fatal: Out of memory, malloc failed
```

Diagnostic :

```powershell
git log -1 --oneline
git status
```

Si `HEAD` est déjà égal à `origin/main`, le serveur possède déjà la dernière version connue localement.

Si le dépôt est bloqué ou incohérent, utiliser le script de déploiement production, qui fait :

```text
git fetch origin
git reset --hard origin/main
git clean -fd
```

### Maintenance : `LastTaskResult = 1`

Vérifier le log :

```powershell
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\maintenance-servweb.log" -Tail 120
```

Vérifier que le script déployé est la version non bloquante :

```powershell
Select-String `
  -Path "C:\Services\MobileSLI.Expedition.Web\scripts\maintenance-servweb-runtime.ps1" `
  -Pattern "Controle applicatif reseau ignore|Invoke-RestMethod|HttpWebRequest|TcpClient"
```

Résultat attendu :

```text
Controle applicatif reseau ignore
```

Résultats non attendus :

```text
Invoke-RestMethod
HttpWebRequest
TcpClient
```

Si le script source Git a été corrigé mais pas le script déployé, relancer :

```powershell
cd C:\Sources\servewebEXPE
.\scriptsdeploy\register-servweb-maintenance-task.ps1
```

## Ce qui est validé

Validé par tests manuels :

```text
ASPNETCORE_ENVIRONMENT = Production
http://localhost/preparations/status = 200
http://expedition.sli.local = 200
http://admin.sli.local = 200
création de la tâche de maintenance = OK
lancement de la tâche de maintenance = OK côté planificateur
Dernier résultat tâche maintenance = 0
script maintenance manuel = OK
script maintenance SYSTEM = OK
```

Dernier comportement validé :

```text
Controle applicatif reseau ignore dans cette tache pour fiabilite SYSTEM.
Logs rotations : 0
Logs archives supprimes : 0
Backups supprimes : 0
Fin maintenance SERVWEB
```

## Limites connues

Cette mise en production reste une mise en production intranet pragmatique :

1. pas de supervision externe ;
2. pas d'alerte mail automatique en cas d'échec ;
3. pas de haute disponibilité ;
4. dépendance forte aux tâches Windows ;
5. sécurité intranet non durcie au niveau d'une plateforme publique ;
6. rollback manuel ;
7. surveillance RAM/disque à faire côté serveur Windows ;
8. la maintenance quotidienne nettoie les fichiers, mais ne supervise pas l'application.

## Conclusion

Le serveur est maintenable si les règles suivantes sont respectées :

1. publier depuis le poste de développement ;
2. ne pas compiler sur SERVWEB ;
3. déployer avec `update-servweb-iis-prod.ps1` ;
4. conserver `data`, `logs` et `scripts` ;
5. vérifier `Production` après chaque déploiement ;
6. vérifier les tâches Windows ;
7. contrôler l'application séparément de la maintenance fichiers ;
8. documenter chaque changement d'exploitation.
