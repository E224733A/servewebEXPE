# Verrouillage planifié SERVEXPE à 22h35

## Objectif

Garantir qu’un lot Expédition prêt est envoyé automatiquement chaque jour à l’API centrale, sans dépendre uniquement du réveil du processus IIS.

Le déclencheur principal est une tâche planifiée Windows.

Le `BackgroundService` reste un filet de sécurité applicatif, mais il ne doit pas être considéré comme le mécanisme principal en production.

## Heure de verrouillage

Heure cible :

```text
22h35
```

Fenêtre acceptée par l’application :

```text
22h35 à 22h55
```

La version 23h55 est supprimée.

La version 00h05 est obsolète.

## Etat réseau final

L’interface Web SERVWEB est exposée en HTTP sur le port 80 avec host headers.

URLs finales :

```text
http://expedition.sli.local
http://admin.sli.local
```

Endpoint technique local :

```text
http://localhost/verrouillage/executer
```

Le port `5100` ne doit plus être utilisé.

Un binding IIS local doit exister :

```text
*:80:localhost
```

## Fichiers concernés

```text
scriptsdeploy/run-verrouillage.ps1
scriptsdeploy/update-servweb-iis-prod.ps1
src/MobileSLI.Expedition.Web/Options/VerrouillageOptions.cs
src/MobileSLI.Expedition.Web/Services/VerrouillageService.cs
src/MobileSLI.Expedition.Web/Controllers/VerrouillageController.cs
src/MobileSLI.Expedition.Web/Background/VerrouillageBackgroundService.cs
src/MobileSLI.Expedition.Web/appsettings.json
src/MobileSLI.Expedition.Web/appsettings.Development.json
```

## Configuration applicative

Configuration attendue dans `appsettings.json` :

```json
{
  "Verrouillage": {
    "Enabled": true,
    "TimeZoneId": "Europe/Paris",
    "Hour": 22,
    "Minute": 35,
    "WindowMinutes": 20,
    "CheckEverySeconds": 60,
    "LotSequence": "001",
    "LockSecretHeaderName": "X-SERVEXPE-LOCK-SECRET",
    "LockSecret": ""
  }
}
```

En production, l’environnement ASP.NET Core doit être :

```text
ASPNETCORE_ENVIRONMENT=Production
```

## Tâche Windows

Nom :

```text
MobileSLI SERVEXPE Verrouillage 22h35
```

Déclenchement :

```text
Tous les jours à 22:35
```

Script exécuté :

```text
C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1
```

Comportement attendu :

```text
StartWhenAvailable
MultipleInstances IgnoreNew
ExecutionTimeLimit 10 minutes
```

## Script PowerShell exécuté

Le script appelle :

```text
POST http://localhost/verrouillage/executer
```

Il écrit :

```text
C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log
C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json
```

Succès :

```text
exit 0
```

Erreur :

```text
exit 1
```

## Sécurité du endpoint

Le endpoint :

```text
POST /verrouillage/executer
```

est réservé aux appels `localhost`.

Tout appel distant doit être refusé.

Si un secret est configuré dans `Verrouillage:LockSecret`, le script doit fournir l’en-tête :

```text
X-SERVEXPE-LOCK-SECRET
```

Le script lit la valeur depuis :

```powershell
$env:SERVEXPE_LOCK_SECRET
```

## Règle métier de construction du lot

Le lot contient uniquement les tournées :

```text
non verrouillées
et en état PRET_VERROUILLAGE ou PRETE_VERROUILLAGE
```

Si aucune tournée n’est prête, le service retourne :

```text
Aucune tournée prête pour verrouillage.
```

Dans ce cas, aucun POST n’est envoyé à l’API centrale.

## Protection contre les doubles exécutions

Le service utilise un verrou en mémoire pour refuser un second verrouillage déjà en cours.

Le stockage SQLite marque les tournées verrouillées après succès.

Lorsqu’une tournée est déjà verrouillée localement, elle ne doit plus être modifiée.

## Retry automatique

Le endpoint planifié utilise une tentative avec retry court.

Comportement :

- première tentative immédiate ;
- si échec technique et lot construit, attente de 60 secondes ;
- deuxième tentative uniquement si la fenêtre de 22h35 à 22h55 est encore ouverte ;
- pas de retry utile sur conflit métier, validation ou date expirée.

## BackgroundService

Le `BackgroundService` est conservé comme filet de sécurité.

Il vérifie périodiquement la fenêtre de verrouillage.

Il ne doit pas être considéré comme le mécanisme principal en production, car IIS peut arrêter ou endormir l’application selon la configuration.

## Contrôle quotidien recommandé

Commande :

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35" |
    Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Résultat attendu :

```text
LastTaskResult = 0
NextRunTime    = prochain jour à 22:35
```

Lire le heartbeat :

```powershell
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json"
```

Résultat attendu :

```json
{
  "date": "2026-06-04T22:35:15.0000000+02:00",
  "codeRetour": 0,
  "message": "SUCCESS",
  "url": "http://localhost/verrouillage/executer"
}
```

## Contrôle SQL côté API centrale

Requête de synthèse attendue :

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
    CodeTournee,
    StatutLot;
```

Résultat attendu pour une date active :

```text
CodeTournee = GLOBAL
StatutLot   = VERROUILLE
NombreLots  = 1
```

Les anciens lots peuvent rester en :

```text
REMPLACE
```

## Commandes de diagnostic rapides

Vérifier que SERVWEB répond :

```powershell
Invoke-WebRequest "http://localhost/preparations/status" -UseBasicParsing
```

Vérifier les logs :

```powershell
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log" -Tail 80
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json" -Raw
```

Vérifier le script déployé :

```powershell
Get-Content "C:\Services\MobileSLI.Expedition.Web\scripts\run-verrouillage.ps1" -Raw
```

## Tests réels validés

Un verrouillage 22h35 a déjà été validé sur le projet avec réception API centrale.

Les tests exacts à relancer après chaque modification d’exploitation sont :

```text
Get-ScheduledTaskInfo
lecture du heartbeat
lecture du log verrouillage
contrôle SQL côté API centrale
```

## Documentation liée

La procédure complète de mise en production SERVWEB est documentée dans :

```text
docs/03-deploiement/servweb-expedition-production.md
```
