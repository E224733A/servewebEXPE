# Corrections robustesse - 2026-05-21

## Objectif

Ce zip contient uniquement les fichiers complets corrigés à recopier dans le dépôt `servewebEXPE`.

Corrections appliquées :

- suppression de la fausse sauvegarde AJAX ;
- conservation uniquement des routes existantes :
  - `POST /expedition/tournees/{codeTournee}/preparer` ;
  - `POST /expedition/tournees/{codeTournee}/lignes/detail` ;
- anti-rejeu local avant appel API de verrouillage si un verrouillage réussi existe déjà pour la date ;
- contrôle IP plus robuste avec adresses exactes et réseaux CIDR ;
- `AllowedHosts` assoupli pour éviter le blocage lors de l'accès via IP de VM ou nom DNS interne.

## Fichiers modifiés

```text
src/MobileSLI.Expedition.Web/Program.cs
src/MobileSLI.Expedition.Web/Options/AccessControlOptions.cs
src/MobileSLI.Expedition.Web/Services/VerrouillageService.cs
src/MobileSLI.Expedition.Web/Views/Expedition/Preparer.cshtml
src/MobileSLI.Expedition.Web/wwwroot/js/site.js
src/MobileSLI.Expedition.Web/appsettings.json
src/MobileSLI.Expedition.Web/appsettings.Development.json
```

## Configuration IP recommandée ensuite

Quand le pôle informatique donne les adresses exactes, remplacer la configuration vide par exemple :

```json
"AccessControl": {
  "Enabled": true,
  "RequireHttps": true,
  "BlockMobileUserAgents": true,
  "RequireIpAllowListInProduction": true,
  "AllowedIpAddresses": [
    "127.0.0.1",
    "::1"
  ],
  "AllowedNetworks": [
    "192.168.1.0/24"
  ],
  "AllowedIpPrefixes": []
}
```

`AllowedIpPrefixes` reste supporté pour compatibilité, mais il faut préférer `AllowedIpAddresses` ou `AllowedNetworks`.
