# Correction verrouillage développement

## Objectif

Conserver la protection anti-rejeu pour le verrouillage automatique, tout en permettant au bouton de développement de déclencher plusieurs verrouillages dans la même journée.

## Fichiers concernés

```text
src/MobileSLI.Expedition.Web/Services/VerrouillageService.cs
src/MobileSLI.Expedition.Web/Controllers/ExpeditionController.cs
```

## Comportement final

### Verrouillage automatique

Le service automatique conserve la vérification :

```text
HasSuccessfulLockAsync(dateTournee)
```

Si un verrouillage réussi existe déjà pour la date, aucun nouvel appel API n'est envoyé.

### Bouton de développement

Le bouton :

```text
POST /expedition/developpement/verrouiller-maintenant
```

appelle maintenant le service avec :

```csharp
ignorerVerrouillageDejaReussi: true
```

Donc il ne bloque plus sur l'historique local de verrouillage réussi.

## Application

1. Copier `src/MobileSLI.Expedition.Web/Services/VerrouillageService.cs` dans le projet.
2. Lancer le script PowerShell depuis la racine du dépôt :

```powershell
.\scripts\apply-correction-verrouillage-dev.ps1
```

3. Compiler :

```powershell
dotnet build
```

## Attention

Cette correction ne désactive pas les sécurités de l'API centrale.

Même si le serveur web autorise le bouton de développement à envoyer plusieurs demandes, l'API centrale peut encore refuser selon ses propres règles :

```text
idLotVerrouillage déjà utilisé
DateTournee + CodeTournee déjà verrouillé
payload différent après verrouillage
fenêtre de verrouillage refusée
```
