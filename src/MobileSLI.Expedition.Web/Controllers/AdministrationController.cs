using Microsoft.AspNetCore.Mvc;
using MobileSLI.Expedition.Web.Application.Administration;
using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Services;
using MobileSLI.Expedition.Web.ViewModels;
using DomainLotStatuses = MobileSLI.Expedition.Web.Domain.Constants.LotStatuses;

namespace MobileSLI.Expedition.Web.Controllers;

/// <summary>
/// Contrôleur HTTP de l'espace Administration.
/// Cet espace utilise le même chargement métier que l'Expédition, mais il est limité à la consultation
/// des tournées et à la saisie des commentaires exceptionnels.
/// </summary>
public sealed class AdministrationController : Controller
{
    private readonly IExpeditionApiClient _apiClient;
    private readonly IExpeditionDraftStore _draftStore;
    private readonly AdministrationViewModelBuilder _viewModelBuilder;
    private readonly ILogger<AdministrationController> _logger;

    public AdministrationController(
        IExpeditionApiClient apiClient,
        IExpeditionDraftStore draftStore,
        AdministrationViewModelBuilder viewModelBuilder,
        ILogger<AdministrationController> logger)
    {
        _apiClient = apiClient;
        _draftStore = draftStore;
        _viewModelBuilder = viewModelBuilder;
        _logger = logger;
    }

    [HttpGet("/administration")]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        var model = await _viewModelBuilder.BuildHomeIndexAsync(cancellationToken);
        return View(model);
    }

    [HttpPost("/administration/charger")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Charger(CancellationToken cancellationToken)
    {
        try
        {
            // L'Administration recharge le même lot API que l'Expédition pour travailler sur un référentiel commun.
            var response = await _apiClient.GetPreparationsAsync(cancellationToken);
            if (!string.Equals(response.Statut, DomainLotStatuses.Success, StringComparison.OrdinalIgnoreCase))
            {
                TempData["Error"] = $"Le chargement a été refusé par l'API : {response.Statut}.";
                return RedirectToAction(nameof(Index));
            }

            // La sauvegarde locale remplace le dernier snapshot afin que les commentaires soient saisis sur les données courantes.
            await _draftStore.SaveLoadedDataAsync(response, cancellationToken);
            TempData["Success"] = $"Données Administration chargées pour le {response.DateTournee:dd/MM/yyyy}.";
            return RedirectToAction(nameof(Tournees));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erreur lors du chargement des données Administration.");
            TempData["Error"] = "Les données à préparer n'ont pas pu être récupérées. Vérifie que l'API centrale répond.";
            return RedirectToAction(nameof(Index));
        }
    }

    [HttpPost("/administration/test-api")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> TesterApi(CancellationToken cancellationToken)
    {
        try
        {
            // Test réseau sans effet de bord métier : il ne recharge pas les tournées et n'écrase aucun brouillon.
            var ok = await _apiClient.TesterApiAsync(cancellationToken);
            TempData[ok ? "Success" : "Error"] = ok
                ? "Mode test API : API joignable. Aucun chargement métier n'a été effectué."
                : "Mode test API : l'API ne répond pas correctement.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erreur pendant le test API Administration.");
            TempData["Error"] = "Mode test API : impossible de joindre l'API centrale.";
            return RedirectToAction(nameof(Index));
        }
    }

    [HttpGet("/administration/tournees")]
    public async Task<IActionResult> Tournees(CancellationToken cancellationToken)
    {
        // La liste Administration est construite depuis le dernier chargement SQLite, comme côté Expédition.
        var model = await _viewModelBuilder.BuildTourneesIndexAsync(cancellationToken);
        if (model is null)
        {
            TempData["Error"] = "Aucune donnée Administration n'a encore été chargée.";
            return RedirectToAction(nameof(Index));
        }

        return View(model);
    }

    [HttpGet("/administration/tournees/{codeTournee}/commentaires")]
    public async Task<IActionResult> Commentaires(string codeTournee, CancellationToken cancellationToken)
    {
        var model = await _viewModelBuilder.BuildPreparationAsync(codeTournee, cancellationToken);
        if (model is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Tournees));
        }

        return View(model);
    }

    [HttpPost("/admin/drafts/commentaires")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EnregistrerCommentaire(string codeTournee, AdminCommentaireInputModel input, CancellationToken cancellationToken)
    {
        // Les commentaires Administration sont rattachés au dernier lot chargé localement.
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        var tournee = load?.Tournees.FirstOrDefault(t => string.Equals(t.CodeTournee, codeTournee, StringComparison.OrdinalIgnoreCase));
        if (load is null || tournee is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Index));
        }

        // Même règle que l'Expédition : une tournée verrouillée n'accepte plus de modification locale.
        var state = await _draftStore.GetTourneeStateAsync(load.DateTournee, codeTournee, cancellationToken);
        if (tournee.EstVerrouilleeBd || state?.IsLocked == true)
        {
            TempData["Error"] = "Cette tournée est verrouillée. Modification Administration refusée.";
            return RedirectToAction(nameof(Commentaires), new { codeTournee });
        }

        // Le validator Administration protège le contrat commentaire sans mélanger les règles de quantité Expédition.
        var validation = AdministrationCommentaireValidator.Validate(input, tournee);
        if (!validation.IsValid)
        {
            TempData["Error"] = validation.Message;
            return RedirectToAction(nameof(Commentaires), new { codeTournee });
        }

        try
        {
            // La sauvegarde trace l'adresse IP pour garder une origine de modification côté poste web.
            await _draftStore.SaveAdminCommentaireAsync(
                load.DateTournee,
                codeTournee,
                new SaveAdminCommentaireDraft
                {
                    IdLigneSource = input.IdLigneSource,
                    CommentaireExceptionnel = input.CommentaireExceptionnel
                },
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);

            TempData["Success"] = "Commentaire Administration enregistré.";
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erreur pendant l'enregistrement d'un commentaire Administration.");
            TempData["Error"] = "Erreur technique pendant l'enregistrement du commentaire.";
        }

        return RedirectToAction(nameof(Commentaires), new { codeTournee });
    }
}