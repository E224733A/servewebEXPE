# Flux Expedition et Administration

## Objectif

Ce document explique le fonctionnement métier des deux interfaces Web :

```text
Expedition      -> saisie des quantités prévues
Administration  -> saisie des commentaires exceptionnels
```

Les deux interfaces utilisent le même chargement API et le même stockage local SQLite.

SERVWEB ne choisit pas la date métier : elle est calculée par l’API centrale.

## URLs utilisateur

```text
http://expedition.sli.local
http://admin.sli.local
```

Routage par host header :

```text
expedition.sli.local -> /expedition
admin.sli.local      -> /administration
```

Les accès croisés sont redirigés :

```text
http://admin.sli.local/expedition          -> /administration
http://expedition.sli.local/administration -> /expedition
```

## Chargement des données

Routes concernées :

```text
POST /expedition/charger
POST /administration/charger
```

Comportement :

1. l’application appelle l’API centrale ;
2. l’API centrale retourne les tournées préparables ;
3. SERVWEB sauvegarde le chargement en SQLite ;
4. l’utilisateur est redirigé vers la liste des tournées.

Endpoint API centrale appelé :

```text
GET /api/expedition/preparations/a-preparer
```

La date métier est calculée par l’API centrale. SERVWEB ne transmet pas de paramètre de date.

## Test API sans chargement métier

Les deux interfaces disposent d’un test de santé API :

```text
POST /expedition/test-api
POST /administration/test-api
```

Ces routes appellent uniquement :

```text
GET /api/health
```

Elles ne chargent pas les données métier et ne modifient pas SQLite.

## Interface Expedition

Routes principales :

```text
GET  /expedition
POST /expedition/charger
POST /expedition/test-api
GET  /expedition/tournees
GET  /expedition/tournees/{codeTournee}/preparer
POST /expedition/tournees/{codeTournee}/preparer
GET  /expedition/tournees/{codeTournee}/lignes/detail
POST /expedition/tournees/{codeTournee}/lignes/detail
GET  /expedition/tournees/{codeTournee}/recapitulatif
POST /expedition/tournees/{codeTournee}/marquer-pret
```

Route disponible uniquement en environnement `Development` :

```text
POST /expedition/developpement/verrouiller-maintenant
```

Rôle :

```text
saisir ou corriger les quantités prévues avant verrouillage
```

Articles suivis côté Expedition :

```text
ROLLS
ROLLS_VIDES
TAPIS
SACS
```

Règles :

1. les quantités négatives sont refusées ;
2. les articles inconnus sont refusés ;
3. les lignes inconnues sont refusées ;
4. une tournée verrouillée n’est plus modifiable ;
5. une tournée déjà prête reste prête si une quantité est corrigée ;
6. le clic `Marquer prête` enregistre la date de modification métier ;
7. `ROLLS_VIDES` est bien affiché et préparé côté Expedition.

## Interface Administration

Routes principales :

```text
GET  /administration
POST /administration/charger
POST /administration/test-api
GET  /administration/tournees
GET  /administration/tournees/{codeTournee}/commentaires
POST /admin/drafts/commentaires
```

Rôle :

```text
saisir ou corriger les commentaires exceptionnels par client / ligne
```

Articles affichés côté Administration :

```text
ROLLS
TAPIS
SACS
```

`ROLLS_VIDES` n’est pas affiché côté Administration.

Règles :

1. un commentaire est rattaché à une ligne existante ;
2. un commentaire exceptionnel ne doit pas dépasser 400 caractères ;
3. un commentaire vide ou null est accepté ;
4. une tournée verrouillée n’est plus modifiable ;
5. les commentaires sont sauvegardés localement jusqu’au verrouillage.

## Séparation des responsabilités

| Interface | Donnée modifiée |
|---|---|
| Expedition | quantités prévues |
| Administration | commentaires exceptionnels |

Les deux interfaces lisent les mêmes tournées chargées, mais ne modifient pas les mêmes champs métier.

## Verrouillage

Le verrouillage normal est automatique à 22h35.

Route locale appelée par la tâche Windows :

```text
POST /verrouillage/executer
```

Cette route est réservée aux appels `localhost`.

Elle construit un lot avec les tournées prêtes, puis appelle l’API centrale :

```text
POST /api/expedition/preparations/verrouiller
```

Une tournée est envoyée si elle est :

```text
non verrouillée
et en état PRET_VERROUILLAGE ou PRETE_VERROUILLAGE
```

Si aucune tournée n’est prête, aucun POST n’est envoyé à l’API centrale.

## Relance manuelle

Une route de relance existe :

```text
POST /verrouillage/retry
```

Elle est séparée de `/verrouillage/executer`.

Elle est appelée depuis l’interface SERVWEB et contourne la fenêtre horaire pour permettre une reprise après erreur réseau ou API.

## Diagnostic utilisateur

La route suivante donne l’état local de préparation :

```text
GET /preparations/status
```

Elle permet de vérifier :

```text
- date de tournée chargée ;
- nombre de tournées ;
- nombre de quantités modifiées ;
- nombre de commentaires modifiés ;
- dernier statut de verrouillage ;
- heure attendue du prochain verrouillage ;
- dernière exécution de la tâche Windows si le heartbeat existe.
```
