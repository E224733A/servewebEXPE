# Architecture du module Expédition

## Principe

Le navigateur Expédition ne dialogue jamais directement avec SQL Server.

```text
Navigateur Expédition
  -> Application web Expédition ASP.NET Core MVC
  -> API centrale ASP.NET Core
  -> SQL Server
```

## Responsabilités

| Composant | Responsabilité |
|---|---|
| Navigateur Expédition | Affichage des écrans et saisies utilisateur |
| Application web Expédition | Ergonomie, brouillons SQLite, chargement global, verrouillage automatique |
| API centrale | Calcul de la date préparable, lecture ABSSolute, validation finale, sauvegarde SQL Server, verrouillage |
| SQL Server | Données ABSSolute et tables dédiées du projet après verrouillage |

## Stockage brouillon

Les saisies avant verrouillage sont stockées dans une base SQLite locale au serveur web :

```text
data/expedition-drafts.sqlite3
```

Ce stockage conserve :

- le dernier chargement global reçu de l'API centrale ;
- les états de tournées côté web ;
- les commentaires exceptionnels par `idLigneSource` ;
- les quantités livrées prévues par `idLigneSource` et `codeArticle` ;
- la dernière modification ;
- l'historique minimal des tentatives de verrouillage.

## Deux routes API centrales seulement

```text
GET  /api/expedition/preparations/a-preparer
POST /api/expedition/preparations/verrouiller
```

Les modifications intermédiaires restent côté application web et ne déclenchent aucun appel API central.

## Verrouillage automatique

Un service hébergé ASP.NET Core vérifie l'heure locale métier `Europe/Paris` et déclenche le verrouillage dans la fenêtre prévue autour de `00:05`.

Le service construit le lot à partir des brouillons SQLite, l'envoie à l'API centrale et marque les données en lecture seule uniquement après succès ou réponse équivalente `ALREADY_PROCESSED` / `ALREADY_LOCKED`.
