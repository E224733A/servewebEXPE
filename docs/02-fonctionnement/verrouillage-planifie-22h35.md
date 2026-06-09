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
22h35 inclus à 22h55 exclu
```

La fenêtre est calculée avec `WindowMinutes = 20`.

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

Si `Verrouillage:LockSecret` est vide, aucun secret n’est exigé pour l’appel local.

Si `Verrouillage:LockSecret` est renseigné, la tâche Windows doit transmettre la même valeur via l’en-tête technique.

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

## Secret technique optionnel

Le script lit le secret depuis :

```powershell
$env:SERVEXPE_LOCK_SECRET
```

Si cette variable est renseignée, le script transmet :

```text
X-SERVEXPE-LOCK-SECRET
```

La valeur doit correspondre à la configuration applicative :

```text
Verrouillage:LockSecret
```

Ne jamais versionner une vraie valeur de secret dans Git.

## Sécurité du endpoint

Le endpoint suivant est réservé à `localhost` :

```text
POST /verrouillage/executer
```

Tout appel distant doit être refusé.

Réponse attendue en cas d’appel distant :

```text
403 Forbidden
Accès refusé : verrouillage planifié réservé à localhost.
```

## Réponse du endpoint local

En cas de succès, le endpoint retourne un JSON de synthèse :

```json
{
  "success": true,
  "lotBuilt": true,
  "message": "Verrouillage exécuté pour 1 tournée(s). Lot : SERVEXPE-2026-06-05-2235-001."
}
```

En cas d’échec, le endpoint retourne un statut HTTP 500 avec le même format général :

```json
{
  "success": false,
  "lotBuilt": true,
  "message": "message d'erreur"
}
```

## Règle métier

Le lot contient uniquement les tournées :

```text
non verrouillées
et en état PRET_VERROUILLAGE ou PRETE_VERROUILLAGE
```

Si aucune tournée n’est prête, aucun POST n’est envoyé à l’API centrale.

## Protection contre les doubles exécutions

Le service utilise un verrou en mémoire pour refuser un second verrouillage déjà en cours.

Le stockage SQLite marque les tournées verrouillées après succès.

Une tournée déjà verrouillée localement ne doit plus être modifiée.

## Retry automatique

Comportement :

1. première tentative immédiate ;
2. si échec technique et lot construit, attente de 60 secondes ;
3. deuxième tentative uniquement si la fenêtre 22h35-22h55 est encore ouverte ;
4. pas de retry utile sur conflit métier, validation ou date expirée.

## Relance manuelle séparée

Une relance manuelle existe :

```text
POST /verrouillage/retry
```

Elle est séparée de `/verrouillage/executer`.

Elle est protégée par antiforgery et prévue pour être appelée depuis l’interface SERVWEB.

Elle contourne la fenêtre horaire afin de permettre une reprise contrôlée après incident.

## BackgroundService

Le `BackgroundService` est conservé comme filet de sécurité.

Il vérifie périodiquement la fenêtre de verrouillage.

Il ne doit pas être considéré comme le mécanisme principal en production, car IIS peut arrêter ou endormir l’application selon la configuration.

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
