# Dette technique et améliorations SERVWEB

## Objectif

Ce document décrit les limites techniques connues du dépôt `servewebEXPE` et propose une trajectoire d’amélioration progressive.

L’objectif est de faciliter la reprise sans masquer les points perfectibles.

## Etat général

Le serveur Web Expedition est stabilisé et exploitable en intranet.

Points solides :

```text
- déploiement IIS scripté ;
- environnement Production configuré ;
- artefact Release versionné ;
- séparation fonctionnelle Expedition / Administration ;
- contrat API documenté ;
- stockage local SQLite identifié ;
- verrouillage automatique 22h35 validé ;
- maintenance quotidienne validée ;
- documentation de reprise structurée.
```

## Dette technique connue

| Dette | Impact | Risque | Priorité |
|---|---|---|---|
| Contrôleurs encore orchestrateurs | Moins testable | Moyen | Haute |
| `SqliteExpeditionDraftStore` trop large | Difficile à maintenir | Moyen | Haute |
| Peu de tests automatisés | Régressions possibles | Élevé | Haute |
| Rollback manuel | Intervention humaine nécessaire | Moyen | Moyenne |
| Pas de supervision externe | Échec détecté tardivement | Moyen | Moyenne |
| Sécurité intranet pragmatique | Pas adaptée à Internet | Faible en intranet, élevé hors intranet | Moyenne |
| Documentation récente | Doit être maintenue | Moyen | Moyenne |

## Contrôleurs

Les contrôleurs sont fonctionnels, mais ils contiennent encore une partie de l’orchestration applicative.

Amélioration conseillée : créer des services applicatifs dédiés.

Cible :

```text
Application/Expedition/ExpeditionPreparationService.cs
Application/Administration/AdministrationCommentaireService.cs
```

Responsabilités proposées :

```text
ExpeditionPreparationService
- sauvegarder un brouillon de quantités ;
- marquer une tournée prête ;
- empêcher la modification d’une tournée verrouillée ;
- préserver le statut prêt après correction.

AdministrationCommentaireService
- sauvegarder un commentaire exceptionnel ;
- valider la ligne concernée ;
- empêcher la modification d’une tournée verrouillée.
```

Bénéfice :

```text
Contrôleur = HTTP, redirection, TempData.
Service = logique applicative testable.
```

## Stockage SQLite

`SqliteExpeditionDraftStore` centralise beaucoup de responsabilités.

Découpage progressif recommandé :

```text
Data/Local/SqliteLoadedDataRepository.cs
Data/Local/SqliteTourneeStateRepository.cs
Data/Local/SqliteExpeditionDraftRepository.cs
Data/Local/SqliteAdministrationCommentRepository.cs
Data/Local/SqliteLockHistoryRepository.cs
Data/Local/SqliteLockLotBuilder.cs
```

Règle importante :

```text
Ne pas modifier le schéma SQLite pendant le premier découpage.
```

Le premier objectif doit être d’extraire des classes sans changer le comportement.

## Tests automatisés

Les tests automatisés doivent être renforcés.

Priorité immédiate : validators.

Tests recommandés :

```text
ExpeditionPreparationValidator
- ligne inconnue refusée ;
- article inconnu refusé ;
- quantité négative refusée ;
- quantité zéro acceptée ;
- quantité positive acceptée ;
- quantité null acceptée.

AdministrationCommentaireValidator
- ligne inconnue refusée ;
- identifiant de ligne vide refusé ;
- commentaire de 400 caractères accepté ;
- commentaire de 401 caractères refusé ;
- commentaire vide accepté ;
- commentaire null accepté.
```

Ensuite :

```text
- tests sur ExpeditionRules ;
- tests sur builders de ViewModels ;
- tests sur VerrouillageService avec client API simulé ;
- tests d’intégration SQLite avec base temporaire.
```

## Déploiement

Le déploiement est robuste pour le contexte actuel.

Limite : rollback manuel.

Amélioration future : créer un script de rollback explicite.

Nom proposé :

```text
scriptsdeploy/rollback-servweb-iis-prod.ps1
```

Comportement attendu :

```text
- lister les backups disponibles ;
- demander le backup cible ;
- mettre l’application hors ligne ;
- restaurer les fichiers applicatifs ;
- conserver data/logs/scripts ;
- redémarrer IIS ;
- tester les endpoints.
```

## Supervision

La maintenance quotidienne nettoie les fichiers, mais ne supervise pas l’application.

C’est volontaire, car les tests réseau sous `SYSTEM` ont provoqué des erreurs mémoire instables sur SERVWEB.

Amélioration future : ajouter une supervision séparée.

Exemples :

```text
- tâche Windows dédiée exécutée avec un compte de service non SYSTEM ;
- script de contrôle HTTP qui écrit un rapport ;
- alerte mail interne ;
- supervision par outil réseau existant dans l’entreprise.
```

## Sécurité

Le projet est prévu pour un intranet contrôlé.

Il ne doit pas être exposé sur Internet sans durcissement.

Améliorations possibles :

```text
- authentification Windows ;
- restriction IP côté IIS ou pare-feu ;
- HTTPS interne ;
- journalisation plus détaillée des accès ;
- secret technique obligatoire pour les endpoints sensibles.
```

## Plan d’amélioration conseillé

### Court terme

```text
1. Ajouter les tests unitaires des validators.
2. Exécuter une matrice de tests Web complète.
3. Vérifier build Release.
4. Vérifier déploiement + status + tâches.
```

### Moyen terme

```text
1. Extraire ExpeditionPreparationService.
2. Extraire AdministrationCommentaireService.
3. Ajouter tests sur ces services.
4. Découper progressivement SqliteExpeditionDraftStore.
```

### Long terme

```text
1. Ajouter supervision externe.
2. Script de rollback.
3. Tests d’intégration SQLite.
4. Authentification intranet.
5. CI GitHub Actions build/test.
```

## Conclusion

Le projet est maintenable si la dette technique est traitée progressivement.

La priorité n’est pas de tout réécrire, mais de sécuriser les règles métier par des tests, puis de découper les classes trop larges sans changer le comportement validé.
