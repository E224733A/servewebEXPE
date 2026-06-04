# Flux Expedition et Administration

## Objectif

Ce document explique le fonctionnement métier des deux interfaces Web :

```text
Expedition      -> saisie des quantités prévues
Administration  -> saisie des commentaires exceptionnels
```

Les deux interfaces utilisent le même chargement API et le même stockage local SQLite.

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

## Interface Expedition

Routes principales :

```text
GET  /expedition
GET  /expedition/tournees
GET  /expedition/tournees/{codeTournee}/preparer
POST /expedition/tournees/{codeTournee}/preparer
GET  /expedition/tournees/{codeTournee}/recapitulatif
POST /expedition/tournees/{codeTournee}/marquer-pret
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
6. le clic `Marquer prête` enregistre la date de modification métier.

## Interface Administration

Routes principales :

```text
GET  /administration
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

Règles :

1. un commentaire est rattaché à une ligne existante ;
2. un commentaire exceptionnel ne doit pas dépasser 400 caractères ;
3. une tournée verrouillée n’est plus modifiable ;
4. les commentaires sont sauvegardés localement jusqu’au verrouillage.

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

Cette route construit un lot avec les tournées prêtes, puis appelle l’API centrale :

```text
POST /api/expedition/preparations/verrouiller
```

Une tournée est envoyée si elle est :

```text
non verrouillée
et en état PRET_VERROUILLAGE ou PRETE_VERROUILLAGE
```

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
- heure attendue du prochain verrouillage.
```
