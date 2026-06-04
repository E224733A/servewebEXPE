# Archive - Correction du verrouillage manuel en développement

## Statut

Document historique conservé pour trace.

Le comportement utile est maintenant résumé dans :

```text
docs/05-reprise/guide-reprise-developpeur.md
docs/02-fonctionnement/verrouillage-planifie-22h35.md
```

## Objectif de la correction historique

Permettre de tester plusieurs verrouillages depuis l’interface en environnement `Development`, sans modifier le comportement de production.

Cette correction concerne uniquement le bouton de développement :

```text
POST /expedition/developpement/verrouiller-maintenant
```

Cette route retourne `404` hors environnement `Development`.

## Comportement

Le bouton de développement appelle le service de verrouillage avec :

```text
idLotVerrouillage = DEV-{yyyyMMddHHmmss}
ignorerVerrouillageDejaReussi = true
bypassWindow = Verrouillage:AllowDevelopmentManualLockOutsideWindow
```

Conséquences :

1. l’historique local de verrouillage réussi ne bloque pas le test ;
2. la séquence de lot commence par `DEV-` ;
3. le contournement de la fenêtre horaire dépend de la configuration ;
4. les règles de l’API centrale continuent de s’appliquer.

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

## Rappel

Le comportement de production à retenir reste :

```text
Tâche planifiée Windows quotidienne à 22h35
Endpoint local /verrouillage/executer
Fenêtre 22h35 à 22h55
```
