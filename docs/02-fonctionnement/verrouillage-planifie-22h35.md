# Verrouillage planifié SERVEXPE à 22h35

## Objectif

Garantir qu’un lot Expedition prêt est envoyé automatiquement chaque jour à l’API centrale, sans dépendre uniquement du réveil du processus IIS.

Le déclencheur principal est une tâche planifiée Windows.

Le `BackgroundService` reste un filet de sécurité applicatif, mais il ne doit pas être considéré comme le mécanisme principal en production.

## Heure

```text
22h35
```

Fenêtre acceptée par l’application :

```text
22h35 à 22h55
```

Les versions 23h55 et 00h05 sont obsolètes.

## Etat réseau final

URLs utilisateur :

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
```

## Configuration applicative

Configuration attendue :

```text
Verrouillage:Enabled = true
Verrouillage:TimeZoneId = Europe/Paris
Verrouillage:Hour = 22
Verrouillage:Minute = 35
Verrouillage:WindowMinutes = 20
Verrouillage:CheckEverySeconds = 60
Verrouillage:LotSequence = 001
Verrouillage:LockSecretHeaderName = X-SERVEXPE-LOCK-SECRET
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

## Script PowerShell

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

Le endpoint suivant est réservé à `localhost` :

```text
POST /verrouillage/executer
```

Tout appel distant doit être refusé.

Si un secret est configuré, le script doit transmettre :

```text
X-SERVEXPE-LOCK-SECRET
```

## Règle métier

Le lot contient uniquement les tournées :

```text
non verrouillées
et en état PRET_VERROUILLAGE ou PRETE_VERROUILLAGE
```

Si aucune tournée n’est prête, aucun POST n’est envoyé à l’API centrale.

## Retry automatique

Comportement :

1. première tentative immédiate ;
2. si échec technique et lot construit, attente de 60 secondes ;
3. deuxième tentative uniquement si la fenêtre 22h35-22h55 est encore ouverte ;
4. pas de retry utile sur conflit métier, validation ou date expirée.

## Contrôles quotidiens

```powershell
Get-ScheduledTaskInfo -TaskName "MobileSLI SERVEXPE Verrouillage 22h35" |
    Select-Object LastRunTime, LastTaskResult, NextRunTime
```

Lire le heartbeat :

```powershell
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie-heartbeat.json" -Raw
```

Lire le log :

```powershell
Get-Content "C:\Services\MobileSLI.Expedition.Web\logs\verrouillage-planifie.log" -Tail 80
```

## Contrôle SQL côté API centrale

Requête de synthèse :

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

## Documentation liée

```text
docs/03-deploiement/servweb-expedition-production.md
docs/04-exploitation/diagnostic-et-reprise.md
docs/01-api/contrat-json-expedition.md
```
