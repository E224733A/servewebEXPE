// JavaScript de l'application Expédition

// Important : il n'y a volontairement plus de sauvegarde AJAX.
// Les modifications sont enregistrées uniquement par les formulaires existants :
// - POST /expedition/tournees/{codeTournee}/preparer
// - POST /expedition/tournees/{codeTournee}/lignes/detail
// - POST /admin/drafts/commentaires

document.addEventListener('DOMContentLoaded', function () {
  hideGlobalLoading();
  initializeNumberInputs();
  initializeLoadingForms();
  initializeAdminCommentCounters();
});

function initializeNumberInputs() {
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
}

function initializeLoadingForms() {
  const loadingForms = document.querySelectorAll('form[data-loading-form]');

  loadingForms.forEach(function (form) {
    form.addEventListener('submit', function () {
      showGlobalLoading();
    });
  });
}

function initializeAdminCommentCounters() {
  const textareas = document.querySelectorAll('[data-commentaire-exceptionnel]');
  const maxLength = 400;

  textareas.forEach(function (textarea) {
    const form = textarea.closest('.admin-comment-form');
    const counter = form ? form.querySelector('[data-commentaire-counter]') : null;

    const updateCounter = function () {
      const length = textarea.value.length;

      if (counter) {
        counter.textContent = length + ' / ' + maxLength + ' caractères';
        counter.classList.toggle('is-limit', length >= maxLength);
      }

      if (length > maxLength) {
        textarea.setCustomValidity('Le commentaire exceptionnel ne doit pas dépasser ' + maxLength + ' caractères.');
      } else {
        textarea.setCustomValidity('');
      }
    };

    textarea.addEventListener('input', updateCounter);
    textarea.addEventListener('change', updateCounter);
    updateCounter();
  });
}

function showGlobalLoading() {
  const overlay = document.getElementById('global-loading');
  if (overlay) {
    overlay.classList.remove('d-none');
  }
}

function hideGlobalLoading() {
  const overlay = document.getElementById('global-loading');
  if (overlay) {
    overlay.classList.add('d-none');
  }
}
