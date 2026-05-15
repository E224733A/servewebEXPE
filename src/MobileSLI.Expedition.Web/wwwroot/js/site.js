document.addEventListener('DOMContentLoaded', function () {
  const numberInputs = document.querySelectorAll('input[type="number"]');

  numberInputs.forEach(function (input) {
    input.addEventListener('input', function () {
      if (input.value === '') {
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
});
