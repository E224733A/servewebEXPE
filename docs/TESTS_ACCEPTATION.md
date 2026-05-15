# Tests d'acceptation - Module Expédition

## TA-01 - Ouverture de l'interface

1. Lancer l'application.
2. Ouvrir `/`.
3. Vérifier que la page d'accueil s'affiche sans identifiant, sans mot de passe et sans champ de date.

## TA-02 - Chargement global

1. Cliquer sur `Charger les données à préparer`.
2. Vérifier que les tournées apparaissent.
3. Vérifier dans les logs applicatifs qu'un seul GET API central a été utilisé.

## TA-03 - Absence de choix manuel de date

1. Ouvrir l'accueil.
2. Ouvrir la liste des tournées.
3. Vérifier qu'aucun champ de date modifiable n'existe.

## TA-04 - Ouverture d'une tournée sans rappel API central

1. Charger les données.
2. Ouvrir une tournée.
3. Modifier une quantité.
4. Vérifier que la modification est enregistrée dans SQLite sans POST API central.

## TA-05 - Quantité vide

1. Laisser une quantité vide.
2. Enregistrer le brouillon.
3. Vérifier que le champ reste vide dans l'écran de préparation et dans le récapitulatif.

## TA-06 - Quantité égale à zéro

1. Saisir `0` pour un article.
2. Enregistrer le brouillon.
3. Vérifier que `0` reste affiché et n'est pas transformé en vide.

## TA-07 - Quantité négative

1. Saisir `-1` pour un article.
2. Enregistrer.
3. Vérifier que l'interface refuse l'enregistrement.

## TA-08 - Commentaire exceptionnel séparé

1. Ouvrir une ligne avec instruction existante.
2. Ajouter un commentaire exceptionnel.
3. Vérifier que les deux textes restent affichés séparément.

## TA-09 - Redémarrage application web

1. Saisir un brouillon.
2. Arrêter l'application.
3. Redémarrer l'application.
4. Revenir sur la tournée.
5. Vérifier que le brouillon est toujours présent.

## TA-10 - Verrouillage automatique

1. Préparer une tournée.
2. Passer le mode API réelle ou fake selon le test.
3. Laisser la tâche automatique atteindre la fenêtre configurée autour de `00:05`.
4. Vérifier que le POST de verrouillage contient toutes les préparations.
5. Vérifier que la tournée devient en lecture seule après succès.

## TA-11 - Idempotence

1. Envoyer le même lot deux fois vers l'API centrale avec le même `idLotVerrouillage`.
2. Vérifier que l'API centrale ne crée pas de doublon.
3. Vérifier que l'application web accepte `SUCCESS`, `ALREADY_PROCESSED` ou `ALREADY_LOCKED` comme réponse non bloquante.
