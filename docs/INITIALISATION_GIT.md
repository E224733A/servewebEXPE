# Initialisation Git

## Cas conseillé : ton dépôt Git est vide

Dézipper le projet, puis exécuter :

```powershell
cd MobileSLI.Expedition
git init
git add .
git commit -m "Initialisation module Expedition"
```

## Ajouter le dépôt distant plus tard

```powershell
git remote add origin https://github.com/TON-COMPTE/TON-DEPOT.git
git branch -M main
git push -u origin main
```

## Vérifier les fichiers suivis

```powershell
git status
git ls-files
```

## Fichiers volontairement exclus

Le dossier `data/` est ignoré car il contient la base SQLite locale de brouillons.

Les fichiers suivants ne doivent pas être poussés :

- base SQLite locale ;
- fichiers de logs ;
- secrets ;
- configuration de production réelle ;
- certificats ;
- chaînes de connexion sensibles.
