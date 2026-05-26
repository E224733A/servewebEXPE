# Verrouillage planifié SERVEXPE à 22h35

## Objectif

Garantir qu’un lot Expédition prêt est envoyé automatiquement chaque jour à l’API centrale, sans dépendre du réveil du processus IIS.

Le déclencheur principal est une tâche planifiée Windows.

## Heure actuelle

```text
22h35
```

Fenêtre acceptée par l’application :

```text
22h35 à 22h55
```

La version 23h55 n’est plus présente dans le dépôt.

La version 00h05 est obsolète et ne doit plus apparaître dans la documentation actuelle.

## Fichiers concernés

```text
scriptsdeploy/register-verrouillage-task.ps1
scriptsdeploy/run-verrouillage.ps1
src/MobileSLI.Expedition.Web/Options/VerrouillageOptions.cs
src/MobileSLI.Expedition.Web/Services/VerrouillageService.cs
src/MobileSLI.Expedition.Web/Controllers/VerrouillageController.cs
src/MobileSLI.Expedition.Web/Background/VerrouillageBackgroundService.cs
src/MobileSLI.Expedition.Web/appsettings.json
src/MobileSLI.Expedition.Web/appsettings.Development.json
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

Comportement :

```text
StartWhenAvailable
MultipleInstances IgnoreNew
ExecutionTimeLimit 10 minutes
```

## Script PowerShell exécuté

Le script appelle :

```text
POST http://localhost:5100/verrouillage/executer
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

Si un secret est configuré dans `Verrouillage:LockSecret`, le script doit fournir :

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
  "date": "2026-05-22T22:35:15.0000000+02:00",
  "codeRetour": 0,
  "message": "SUCCESS"
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

## Test réel validé

Le verrouillage à 22h35 a été validé avec :

```text
DateTournee = 2026-05-25
CodeTournee = GLOBAL
StatutLot = VERROUILLE
DateCreation = 2026-05-22 22:35:15 +02:00
```

Le mobile a ensuite lu les données Expédition ajoutées sans erreur.

## Conclusion

La solution est adaptée à un fonctionnement quotidien si :

- SERVWEB est allumé ;
- IIS sert correctement l’application ;
- l’API centrale est joignable ;
- les tournées sont prêtes pour verrouillage ;
- la tâche Windows existe encore ;
- le heartbeat est surveillé.
