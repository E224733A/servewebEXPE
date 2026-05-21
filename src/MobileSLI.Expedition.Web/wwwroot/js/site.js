// JavaScript de l'application Expédition

// Important : il n'y a volontairement plus de sauvegarde AJAX.
// Les modifications sont enregistrées uniquement par les formulaires existants :
// - POST /expedition/tournees/{codeTournee}/preparer
// - POST /expedition/tournees/{codeTournee}/lignes/detail

document.addEventListener('DOMContentLoaded', function () {
  hideGlobalLoading();

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

  const loadingForms = document.querySelectorAll('form[data-loading-form]');
  loadingForms.forEach(function (form) {
    form.addEventListener('submit', function () {
      showGlobalLoading();
    });
  });
});

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
