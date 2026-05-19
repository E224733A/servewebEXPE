// JavaScript de l'application Expédition

document.addEventListener('DOMContentLoaded', function () {
  // Dès que le DOM est prêt, masquer la superposition globale de chargement
  hideGlobalLoading();

  // Validation de base pour les champs numériques : interdit les valeurs négatives
  const numberInputs = document.querySelectorAll('input[type="number"]');
  numberInputs.forEach(function (input) {
    input.addEventListener('input', function () {
      if (input.value === '') {
        input.setCustomValidity('');
        return;
      }
      const value = Number(input.value);
      if (Number.isFinite(value) && value < 0) {
        input.setCustomValidity('La quantité doit être vide, égale à 0 ou positive.');
      } else {
        input.setCustomValidity('');
      }
    });
  });

  // Lors de la soumission d'un formulaire marqué "data-loading-form", afficher la superposition de chargement
  const loadingForms = document.querySelectorAll('form[data-loading-form]');
  loadingForms.forEach(function (form) {
    form.addEventListener('submit', function () {
      showGlobalLoading();
    });
  });
});

// Affiche la superposition globale de chargement
function showGlobalLoading() {
  const overlay = document.getElementById('global-loading');
  if (overlay) {
    overlay.classList.remove('d-none');
  }
}

// Masque la superposition globale de chargement
function hideGlobalLoading() {
  const overlay = document.getElementById('global-loading');
  if (overlay) {
    overlay.classList.add('d-none');
  }
}

// Envoie une requête AJAX pour mettre à jour une quantité livrée prévue
async function updateQuantitePrevue(input) {
  const lineId = input.dataset.lineId;
  const articleCode = input.dataset.articleCode;
  const codeTournee = input.dataset.codeTournee;
  const rawValue = input.value;
  // Convertit en nombre ou null
  const quantite = rawValue === '' ? null : parseInt(rawValue, 10);

  showGlobalLoading();
  try {
    await fetch(`/expedition/tournees/${encodeURIComponent(codeTournee)}/lignes/quantite`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        idLigneSource: lineId,
        codeArticle: articleCode,
        quantiteLivreePrevue: quantite
      })
    });
  } catch (error) {
    // En cas d'erreur réseau, on affiche une trace dans la console.
    console.error('Erreur lors de la mise à jour de la quantité :', error);
  } finally {
    hideGlobalLoading();
  }
}

// Envoie une requête AJAX pour mettre à jour le commentaire exceptionnel d'une ligne
async function updateCommentaire(textarea) {
  const lineId = textarea.dataset.lineId;
  const codeTournee = textarea.dataset.codeTournee;
  const commentaire = textarea.value;

  showGlobalLoading();
  try {
    await fetch(`/expedition/tournees/${encodeURIComponent(codeTournee)}/lignes/commentaire`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        idLigneSource: lineId,
        commentaireExceptionnel: commentaire
      })
    });
  } catch (error) {
    console.error('Erreur lors de la mise à jour du commentaire :', error);
  } finally {
    hideGlobalLoading();
  }
}