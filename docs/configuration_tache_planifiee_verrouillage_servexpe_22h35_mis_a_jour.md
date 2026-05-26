# Configuration de la tâche planifiée Windows de verrouillage SERVEXPE à 22h35

## Objectif

Cette procédure permet de configurer, vérifier et superviser la tâche planifiée Windows qui déclenche automatiquement le verrouillage SERVEXPE à **22h35**.

Le verrouillage ne doit pas dépendre uniquement du réveil de l’application ASP.NET Core hébergée par IIS. La tâche planifiée Windows est donc le **déclencheur principal** du verrouillage automatique.

Le service ASP.NET Core conserve un `BackgroundService` de secours, mais ce service ne doit pas être considéré comme le mécanisme principal. En production, le déclenchement fiable doit venir de Windows Task Scheduler.

Configuration actuelle attendue :

```text
Heure unique de verrouillage : 22h35
Ancienne hypothèse 23h55    : supprimée
Fenêtre applicative          : 22h35 à 22h54 inclus environ
Déclencheur principal        : tâche planifiée Windows
Déclencheur secondaire       : BackgroundService ASP.NET Core en filet de sécurité
```

Le script exécuté par la tâche est :

```text
C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1
```

Ce script appelle ensuite l’endpoint local :

```text
http://localhost:5100/verrouillage/executer
```

L’endpoint `/verrouillage/executer` est volontairement réservé à `localhost`. Il ne doit pas être appelé directement depuis un autre poste du réseau.

---

## État validé après test réel

Le verrouillage automatique à **22h35** a été testé avec succès.

Résultat observé :

```text
Date d’exécution serveur : 2026-05-22 22:35:15 +02:00
DateTournee verrouillée  : 2026-05-25
CodeTournee du lot       : GLOBAL
StatutLot actif          : VERROUILLE
Adresse appelante        : 192.168.1.232
```

Le cas important **vendredi soir vers lundi** est donc validé : le verrouillage exécuté le vendredi soir a bien préparé la tournée du lundi.

Les anciens lots de test sont correctement conservés en statut :

```text
REMPLACE
```

Et un seul lot actif reste utilisable :

```text
VERROUILLE
```

Le mobile a également été testé : il lit correctement les données Expédition ajoutées par le verrouillage, sans erreur.

Conclusion :

```text
OK - tâche Windows 22h35 fonctionnelle
OK - appel local SERVWEB fonctionnel
OK - verrouillage API centrale fonctionnel
OK - écriture SQL Server fonctionnelle
OK - remplacement des anciens lots fonctionnel
OK - lecture mobile des données Expédition fonctionnelle
```

---

## Prérequis

À vérifier avant configuration ou après redémarrage serveur :

```powershell
Get-TimeZone
w32tm /query /status
Get-WebAppPoolState -Name "MobileSLI.Expedition.Web"
Get-Website -Name "MobileSLI.Expedition.Web"
```

Résultat attendu :

```text
Fuseau horaire : Romance Standard Time / Europe Paris
Horloge        : synchronisée
AppPool        : Started
Site IIS       : Started
```

Vérifier aussi que SERVWEB peut joindre l’API centrale :

```powershell
curl.exe -i http://192.168.1.233:5000/api/health
```

Résultat attendu :

```text
HTTP/1.1 200 OK
```

---

## 1. Mettre à jour le dépôt SERVWEB

À exécuter sur **SERVWEB** dans PowerShell administrateur :

```powershell
cd C:\Sources\servewebEXPE
git pull
```

Vérifier que le script de déploiement existe :

```powershell
Test-Path "C:\Sources\servewebEXPE\scriptsdeploy\run-verrouillage.ps1"
Test-Path "C:\Sources\servewebEXPE\scriptsdeploy\register-verrouillage-task.ps1"
```

Résultat attendu :

```text
True
True
```

---

## 2. Copier le script de verrouillage dans le dossier IIS

La tâche Windows ne doit pas pointer directement vers le dépôt Git. Elle doit exécuter le script présent dans le dossier de service IIS :

```text
C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1
```

Commandes :

```powershell
cd C:\Sources\servewebEXPE

New-Item -ItemType Directory -Force "C:\Services\MobileSLI.Expedition.Web\scripts" | Out-Null

Copy-Item `
  -Path "C:\Sources\servewebEXPE\scriptsdeploy\run-verrouillage.ps1" `
  -Destination "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1" `
  -Force

Test-Path "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
```

Résultat attendu :

```text
True
```

---

## 3. Créer ou mettre à jour la tâche planifiée Windows

### Option recommandée : script du dépôt

Le dépôt contient un script prévu pour créer ou mettre à jour la tâche :

```powershell
cd C:\Sources\servewebEXPE
.\scriptsdeploy\register-verrouillage-task.ps1
```

Ce script configure :

```text
Nom tâche : MobileSLI SERVEXPE Verrouillage 22h35
Heure     : tous les jours à 22:35
Action    : powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
```

### Option détaillée : création manuelle maîtrisée

Cette version force l’exécution avec le compte `SYSTEM`, ce qui est adapté pour un serveur si le script n’a pas besoin d’un profil utilisateur interactif.

```powershell
$TaskName = "MobileSLI SERVEXPE Verrouillage 22h35"
$ScriptPath = "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

$Trigger = New-ScheduledTaskTrigger -Daily -At "22:35"

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

$Principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Principal $Principal `
    -Description "Déclenche le verrouillage SERVEXPE à 22:35" `
    -Force
```

---

## 4. Vérifier qu’il n’existe pas d’ancienne tâche 23h55

Le Git actuel ne contient plus de configuration 23h55. Il faut quand même vérifier le serveur Windows, car une ancienne tâche peut rester enregistrée localement.

Lister toutes les tâches liées au verrouillage :

```powershell
Get-ScheduledTask |
    Where-Object { $_.TaskName -like "*Verrouillage*" } |
    Select-Object TaskName, State
```

Voir l’heure de chaque déclencheur :

```powershell
Get-ScheduledTask |
    Where-Object { $_.TaskName -like "*Verrouillage*" } |
    ForEach-Object {
        [PSCustomObject]@{
            TaskName = $_.TaskName
            State    = $_.State
            Trigger  = ($_.Triggers | ForEach-Object { $_.StartBoundary }) -join " ; "
        }
    }
```

Résultat attendu :

```text
MobileSLI SERVEXPE Verrouillage 22h35
```

Si une ancienne tâche 23h55 existe encore, la supprimer uniquement après vérification :

```powershell
Unregister-ScheduledTask -TaskName "NOM_DE_L_ANCIENNE_TACHE_23H55" -Confirm:$false
```

Ne pas supprimer la tâche 22h35.

---

## 5. Vérifier la tâche planifiée

```powershell
Get-ScheduledTask -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"

$Task = Get-ScheduledTask -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"
$Task.Triggers
$Task.Actions
$Task.Settings
$Task.Principal
```

Résultat attendu :

```text
TaskName       : MobileSLI SERVEXPE Verrouillage 22h35
State          : Ready
Trigger        : Daily 22:35
Action         : powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
RunLevel       : Highest, si la version avec Principal SYSTEM a été utilisée
```

Pour afficher clairement la prochaine exécution :

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35" |
    Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Résultat attendu :

```text
NextRunTime : prochain jour à 22:35:00
```

---

## 6. Interpréter le premier état de la tâche

Juste après la création, il est normal d’obtenir :

```text
LastRunTime    : 30/11/1999 00:00:00
LastTaskResult : 267011
```

Cela signifie simplement que la tâche n’a pas encore été exécutée.

Les informations importantes à ce stade sont :

```text
State       : Ready
NextRunTime : 22:35:00
```

Après la première exécution réelle, le résultat attendu est :

```text
LastTaskResult : 0
```

---

## 7. Fonctionnement du script exécuté

Le script exécuté est :

```text
C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1
```

Il appelle :

```text
http://localhost:5100/verrouillage/executer
```

Il écrit deux fichiers de suivi :

```text
C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log
C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json
```

En cas de succès, le script écrit un heartbeat de ce type :

```json
{"date":"2026-05-22T22:35:15.0000000+02:00","codeRetour":0,"message":"SUCCESS"}
```

En cas d’erreur, il écrit :

```json
{"date":"...","codeRetour":1,"message":"message d'erreur"}
```

Puis il retourne :

```text
exit 0 : succès
exit 1 : erreur
```

---

## 8. Vérifications après l’exécution automatique

Après 22h35, ou le lendemain matin :

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35" |
    Select-Object LastRunTime, LastTaskResult, NextRunTime

Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log" -Tail 80

Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json" -Raw

curl.exe -i http://localhost:5100/preparations/status
```

Résultat attendu si le verrouillage automatique a fonctionné :

```text
LastTaskResult = 0
heartbeat codeRetour = 0
log contenant "Succès"
statut du verrouillage = ENVOYE, SUCCESS, ALREADY_PROCESSED ou équivalent accepté
```

Si `LastTaskResult` n’est pas égal à `0`, consulter en priorité :

```text
C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log
```

---

## 9. Vérifications SQL côté API centrale

Après un verrouillage réussi, vérifier dans SQL Server que le lot actif est bien en `VERROUILLE`.

```sql
SELECT
    DateTournee,
    CodeTournee,
    StatutLot,
    COUNT(*) AS NombreLots,
    SUM(NombrePreparations) AS TotalPreparationsDeclarees,
    SUM(NombreLignes) AS TotalLignesDeclarees,
    SUM(NombreQuantites) AS TotalQuantitesDeclarees,
    MIN(DateCreation) AS PremiereCreation,
    MAX(DateCreation) AS DerniereCreation
FROM dbo.Mobile_ExpeditionLotVerrouillage
GROUP BY
    DateTournee,
    CodeTournee,
    StatutLot
ORDER BY
    DateTournee DESC,
    CASE StatutLot WHEN N'VERROUILLE' THEN 0 ELSE 1 END,
    StatutLot;
```

Résultat attendu :

```text
Pour une DateTournee donnée :
- un seul lot GLOBAL / VERROUILLE actif
- les anciens lots éventuels en REMPLACE
```

Détail du lot actif :

```sql
DECLARE @DateTournee DATE = '2026-05-25';

SELECT *
FROM dbo.Mobile_ExpeditionLotVerrouillage
WHERE DateTournee = @DateTournee
  AND CodeTournee = N'GLOBAL'
ORDER BY DateCreation DESC;
```

Préparations visibles par le mobile :

```sql
DECLARE @DateTournee DATE = '2026-05-25';

SELECT
    p.DateTournee,
    p.CodeTournee,
    p.StatutPreparation,
    p.EstVerrouille,
    p.DateVerrouillage,
    p.IdLotVerrouillage,
    COUNT(pl.IdPreparationExpeditionLigne) AS NombreLignesPreparation
FROM dbo.Mobile_ExpeditionPreparation p
LEFT JOIN dbo.Mobile_ExpeditionPreparationLigne pl
    ON pl.IdPreparationExpedition = p.IdPreparationExpedition
   AND pl.Actif = 1
WHERE p.DateTournee = @DateTournee
GROUP BY
    p.DateTournee,
    p.CodeTournee,
    p.StatutPreparation,
    p.EstVerrouille,
    p.DateVerrouillage,
    p.IdLotVerrouillage
ORDER BY p.CodeTournee;
```

Résultat attendu :

```text
StatutPreparation = VERROUILLEE
EstVerrouille     = 1
```

---

## 10. Commandes de contrôle rapides

```powershell
Test-Path "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1"
Test-Path "C:\Services\MobileSLI.Expedition.Web\logs"
Test-Path "C:\Services\MobileSLI.Expedition.Web\data"

curl.exe -i http://localhost:5100
curl.exe -i http://localhost:5100/preparations/status
curl.exe -i http://192.168.1.233:5000/api/health

Get-ScheduledTask -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"
```

---

## 11. Conditions pour que cela fonctionne tous les jours

Le système est fonctionnel sur le long terme si les conditions suivantes sont respectées :

```text
1. SERVWEB est allumé à 22h35.
2. Le site IIS MobileSLI.Expedition.Web est démarré.
3. Le port local 5100 répond sur SERVWEB.
4. L’API centrale est joignable depuis SERVWEB.
5. Les données Expédition du jour métier ont été chargées dans SERVWEB.
6. Au moins une tournée est en statut PRET_VERROUILLAGE ou PRETE_VERROUILLAGE.
7. Le dossier logs est accessible en écriture.
8. Si un secret technique est configuré, il est disponible pour le compte qui exécute la tâche.
```

Point important :

```text
Le verrouillage automatique ne crée pas de préparation à partir de rien.
Il verrouille uniquement les tournées déjà prêtes dans SERVWEB.
```

Si aucune tournée n’est prête à 22h35, le verrouillage ne pourra pas envoyer de lot utile.

---

## 12. Gestion du secret technique optionnel

Le script lit le secret depuis la variable d’environnement :

```powershell
$env:SERVEXPE_LOCK_SECRET
```

Le header envoyé à l’application est :

```text
X-SERVEXPE-LOCK-SECRET
```

Si `Verrouillage:LockSecret` est vide dans la configuration applicative, le secret n’est pas obligatoire.

Si un secret est configuré, il faut créer une variable d’environnement machine, surtout si la tâche tourne en `SYSTEM` :

```powershell
[Environment]::SetEnvironmentVariable(
    "SERVEXPE_LOCK_SECRET",
    "VALEUR_DU_SECRET",
    "Machine"
)
```

Puis redémarrer le service IIS ou le serveur pour garantir que l’environnement est rechargé.

Ne jamais écrire le vrai secret dans Git.

---

## 13. Point de vigilance lors des mises à jour

Le script de verrouillage doit rester synchronisé entre le dépôt Git et le dossier IIS.

À chaque mise à jour applicative, vérifier ou recopier :

```powershell
Copy-Item `
  -Path "C:\Sources\servewebEXPE\scriptsdeploy\run-verrouillage.ps1" `
  -Destination "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1" `
  -Force
```

Recommandation : intégrer cette copie directement dans le script de déploiement IIS, afin d’éviter qu’une ancienne version du script reste utilisée en production.

Vérifier également que la tâche existe toujours après mise à jour :

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35" |
    Select-Object LastRunTime, LastTaskResult, NextRunTime
```

---

## 14. À éviter

Ne pas créer une deuxième tâche à 23h55. La version actuelle validée fonctionne avec une seule tâche à 22h35.

Ne pas exposer `/verrouillage/executer` au réseau. Cet endpoint doit rester réservé à `localhost`.

Ne pas lancer manuellement la tâche hors fenêtre 22h35-22h54 si l’objectif est de tester le fonctionnement automatique.

Cette commande :

```powershell
Start-ScheduledTask -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"
```

peut être utile pour diagnostiquer l’exécution du script, mais l’endpoint `/verrouillage/executer` peut refuser l’appel si l’heure est hors fenêtre. Ce refus est normal et peut polluer les logs.

Pour une relance manuelle contrôlée hors fenêtre, utiliser plutôt l’interface SERVEXPE prévue à cet effet, si elle est disponible, car elle passe par le endpoint de retry applicatif.

---

## 15. Diagnostic rapide en cas d’échec

### Cas 1 : la tâche ne s’est pas lancée

Vérifier :

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35"
```

Si `LastRunTime` n’a pas changé, vérifier :

```text
- serveur éteint ou redémarré
- tâche désactivée
- déclencheur absent
- problème Windows Task Scheduler
```

### Cas 2 : la tâche s’est lancée mais `LastTaskResult` n’est pas 0

Lire :

```powershell
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log" -Tail 120
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json" -Raw
```

### Cas 3 : erreur 403 Forbidden

Causes probables :

```text
- l’appel ne vient pas de localhost
- secret technique manquant ou incorrect
```

Rappel : l’appel attendu est :

```text
http://localhost:5100/verrouillage/executer
```

Pas :

```text
http://192.168.1.232:5100/verrouillage/executer
```

### Cas 4 : aucune tournée verrouillée

Vérifier que les tournées sont prêtes côté SERVEXPE :

```text
PRET_VERROUILLAGE
PRETE_VERROUILLAGE
```

Si les tournées sont encore en brouillon ou non préparées, le verrouillage ne peut pas construire de lot utile.

### Cas 5 : API centrale indisponible

Tester depuis SERVWEB :

```powershell
curl.exe -i http://192.168.1.233:5000/api/health
```

---

## Résumé

La tâche planifiée Windows doit être considérée comme le déclencheur principal du verrouillage automatique SERVEXPE.

Configuration attendue :

```text
Nom tâche       : MobileSLI SERVEXPE Verrouillage 22h35
Heure           : tous les jours à 22:35
Compte          : SYSTEM recommandé sur serveur
Script exécuté  : C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1
Endpoint appelé : http://localhost:5100/verrouillage/executer
Logs            : C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log
Heartbeat       : C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json
Version 23h55   : supprimée / non utilisée
```

Conclusion :

```text
Le verrouillage automatique est validé pour une exécution quotidienne à 22h35.
La solution est fiable sur le long terme si SERVWEB, IIS, l’API centrale et les données PRET_VERROUILLAGE sont disponibles au moment du déclenchement.
```
