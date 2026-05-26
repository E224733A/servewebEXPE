# Correction du verrouillage manuel en développement

## Objectif

Permettre de tester plusieurs verrouillages depuis l’interface en environnement `Development`, sans modifier le comportement de production.

Cette correction concerne uniquement le bouton de développement.

## Route concernée

```text
POST /expedition/developpement/verrouiller-maintenant
```

Cette route retourne `404` hors environnement `Development`.

## Comportement actuel

Le bouton de développement appelle :

```csharp
_verrouillageService.TryRunDetailedAsync(
    DateTimeOffset.UtcNow,
    $"DEV-{DateTimeOffset.UtcNow:yyyyMMddHHmmss}",
    cancellationToken,
    ignorerVerrouillageDejaReussi: true,
    bypassWindow: _verrouillageOptions.AllowDevelopmentManualLockOutsideWindow);
```

Conséquences :

- l’historique local de verrouillage réussi ne bloque pas le test ;
- la séquence de lot commence par `DEV-` ;
- le contournement de la fenêtre horaire dépend de `AllowDevelopmentManualLockOutsideWindow` ;
- les règles de l’API centrale continuent de s’appliquer.

## Ce qui reste protégé

Même en développement, l’API centrale peut refuser :

```text
idLotVerrouillage déjà utilisé
DateTournee expirée
payload invalide
contrat JSON invalide
tournée déjà verrouillée selon ses règles
conflit métier
```

## Différence avec le verrouillage planifié

| Élément | Verrouillage planifié | Bouton développement |
|---|---|---|
| Route interne | `/verrouillage/executer` | `/expedition/developpement/verrouiller-maintenant` |
| Déclencheur | Tâche Windows | Utilisateur développeur |
| Heure | 22h35 | manuelle |
| Fenêtre horaire | obligatoire | contournable si option activée |
| Séquence | `001` | `DEV-yyyyMMddHHmmss` |
| Environnement | production et développement | développement uniquement |
| Ignore l’historique réussi | non | oui |

## Documentation à retenir

Le bouton développement sert uniquement aux tests.

Le comportement à documenter pour l’exploitation réelle reste :

```text
Tâche planifiée Windows quotidienne à 22h35
Endpoint local /verrouillage/executer
Fenêtre 22h35 à 22h55
```
