# Passage en version finale - Module web Expédition

Ce document décrit le passage de l'application web Expédition en mode réel.

## Objectif

La version finale ne doit plus utiliser les données de test du `FakeExpeditionApiClient`.
L'application web doit appeler l'API centrale réelle avec les routes finales :

```text
GET  /api/expedition/preparations/a-preparer
POST /api/expedition/preparations/verrouiller
```

Le bouton `Mode test API` reste disponible pour la première mise en production. Il appelle le GET réel, vérifie que l'API répond, mais n'enregistre aucun brouillon.

## Sécurité

- Ne pas stocker de mot de passe, de clé API ou de chaîne sensible dans Git.
- Configurer l'URL réelle de l'API par variable d'environnement ou fichier de configuration serveur.
- Utiliser HTTPS en production, sauf exception réseau interne validée par le service informatique.
- Restreindre l'accès à l'interface web Expédition par pare-feu, IIS, reverse proxy ou préfixes IP.
- Conserver la base SQLite brouillon dans un dossier serveur maîtrisé, hors dépôt Git.
- Ne jamais exposer l'interface web Expédition aux téléphones livreurs.

## Variables d'environnement recommandées en production

Exemples PowerShell administrateur :

```powershell
[Environment]::SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", "Production", "Machine")
[Environment]::SetEnvironmentVariable("ExpeditionApi__BaseUrl", "https://ADRESSE_API_CENTRALE/", "Machine")
[Environment]::SetEnvironmentVariable("ExpeditionApi__RequireHttps", "true", "Machine")
[Environment]::SetEnvironmentVariable("ExpeditionDb__DatabasePath", "D:\\MobileSLI\\Expedition\\data\\expedition-drafts.sqlite3", "Machine")
[Environment]::SetEnvironmentVariable("AccessControl__AllowedIpPrefixes__0", "192.168.1.", "Machine")
```

Si l'API centrale utilise une clé applicative :

```powershell
[Environment]::SetEnvironmentVariable("ExpeditionApi__ApiKeyHeaderName", "X-Expedition-Api-Key", "Machine")
[Environment]::SetEnvironmentVariable("ExpeditionApi__ApiKey", "VALEUR_SECRETE_A_NE_PAS_COMMIT", "Machine")
```

## Vérification locale avant déploiement

```powershell
cd C:\Users\Logistique\Downloads\Stage\ProjetMobileTournee\web\servewebEXPE

dotnet restore .\MobileSLI.Expedition.sln
dotnet build .\MobileSLI.Expedition.sln
dotnet run --project .\src\MobileSLI.Expedition.Web\MobileSLI.Expedition.Web.csproj
```

Ouvrir ensuite l'URL affichée par `dotnet run`.

## Test fonctionnel attendu

1. Lancer l'API centrale réelle.
2. Vérifier que l'API répond sur `/api/health` si la route existe.
3. Ouvrir l'application web Expédition.
4. Cliquer sur `Mode test API`.
5. Le message doit indiquer que l'API est joignable et retourner un nombre réel de tournées.
6. Cliquer sur `Charger les données à préparer`.
7. Ouvrir une tournée.
8. Saisir ROLLS, TAPIS, SACS et un commentaire exceptionnel.
9. Enregistrer le brouillon.
10. Vérifier que la saisie survit à un redémarrage de l'application web.
11. Marquer la tournée prête pour verrouillage.
12. Laisser la tâche automatique envoyer le lot vers l'API à 00:05.

## Points de contrôle métier

- Aucun choix manuel de date dans l'interface.
- Aucune donnée de test affichée si l'API centrale est arrêtée.
- Aucun appel API central à chaque modification utilisateur.
- Le mobile ne doit lire que les préparations verrouillées en SQL Server.
- `null` et `0` doivent rester distingués pour les quantités.
- Les rolls vides récupérés ne doivent pas apparaître côté Expédition.
