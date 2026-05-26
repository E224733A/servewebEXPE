using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Options;
using MobileSLI.Expedition.Web.Services;
using MobileSLI.Expedition.Web.ViewModels;

namespace MobileSLI.Expedition.Web.Controllers;

public sealed class ExpeditionController : Controller
{
    private readonly IExpeditionApiClient _apiClient;
    private readonly IExpeditionDraftStore _draftStore;
    private readonly VerrouillageService _verrouillageService;
    private readonly IWebHostEnvironment _environment;
    private readonly VerrouillageOptions _verrouillageOptions;
    private readonly ILogger<ExpeditionController> _logger;

    public ExpeditionController(
        IExpeditionApiClient apiClient,
        IExpeditionDraftStore draftStore,
        VerrouillageService verrouillageService,
        IWebHostEnvironment environment,
        IOptions<VerrouillageOptions> verrouillageOptions,
        ILogger<ExpeditionController> logger)
    {
        _apiClient = apiClient;
        _draftStore = draftStore;
        _verrouillageService = verrouillageService;
        _environment = environment;
        _verrouillageOptions = verrouillageOptions.Value;
        _logger = logger;
    }

    [HttpGet("/")]
    public IActionResult Root()
    {
        return Redirect("/expedition");
    }

    [HttpGet("/expedition")]
    public async Task<IActionResult> Index(CancellationToken cancellationToken)
    {
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        var locks = await _draftStore.GetRecentLockHistoryAsync(5, cancellationToken);
        var model = new HomeIndexViewModel
        {
            HasLoadedData = load is not null,
            DateTournee = load?.DateTournee,
            TourneesCount = load?.Tournees.Count ?? 0,
            RecentLocks = locks
        };
        return View(model);
    }

    [HttpPost("/expedition/charger")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Charger(CancellationToken cancellationToken)
    {
        try
        {
            var response = await _apiClient.GetPreparationsAsync(cancellationToken);
            if (!string.Equals(response.Statut, "SUCCESS", StringComparison.OrdinalIgnoreCase))
            {
                TempData["Error"] = $"Le chargement a été refusé par l'API : {response.Statut}.";
                return RedirectToAction(nameof(Index));
            }

            await _draftStore.SaveLoadedDataAsync(response, cancellationToken);
            TempData["Success"] = $"Données Expédition chargées pour le {response.DateTournee:dd/MM/yyyy}.";
            return RedirectToAction(nameof(Tournees));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erreur lors du chargement des données Expédition.");
            TempData["Error"] = "Les données à préparer n'ont pas pu être récupérées. Vérifie que l'API centrale répond.";
            return RedirectToAction(nameof(Index));
        }
    }

    [HttpPost("/expedition/test-api")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> TesterApi(CancellationToken cancellationToken)
    {
        try
        {
            var ok = await _apiClient.TesterApiAsync(cancellationToken);
            TempData[ok ? "Success" : "Error"] = ok
                ? "Mode test API : API joignable. Aucun chargement métier n'a été effectué."
                : "Mode test API : l'API ne répond pas correctement.";
            return RedirectToAction(nameof(Index));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erreur pendant le test API Expédition.");
            TempData["Error"] = "Mode test API : impossible de joindre l'API centrale.";
            return RedirectToAction(nameof(Index));
        }
    }

    [HttpGet("/expedition/tournees")]
    public async Task<IActionResult> Tournees(CancellationToken cancellationToken)
    {
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        if (load is null)
        {
            TempData["Error"] = "Aucune donnée Expédition n'a encore été chargée.";
            return RedirectToAction(nameof(Index));
        }

        var states = await _draftStore.GetTourneeStatesAsync(load.DateTournee, cancellationToken);
        var model = new TourneesIndexViewModel
        {
            DateTournee = load.DateTournee,
            FuseauHoraireMetier = load.FuseauHoraireMetier,
            Tournees = load.Tournees.OrderBy(t => t.CodeTournee).Select(t =>
            {
                states.TryGetValue(t.CodeTournee, out var state);
                var isLocked = t.EstVerrouilleeBd || state?.IsLocked == true;
                return new TourneeListItemViewModel
                {
                    CodeTournee = t.CodeTournee,
                    LibelleTournee = t.LibelleTournee,
                    EtatPreparation = isLocked ? DraftStatuses.Verrouille : state?.Status ?? t.EtatPreparation,
                    IsLocked = isLocked,
                    NombreLignes = t.Lignes.Count
                };
            }).ToList()
        };
        return View(model);
    }

    [HttpGet("/expedition/tournees/{codeTournee}/preparer")]
    public async Task<IActionResult> Preparer(string codeTournee, CancellationToken cancellationToken)
    {
        var model = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
        if (model is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Tournees));
        }
        return View(model);
    }

    [HttpPost("/expedition/tournees/{codeTournee}/preparer")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Preparer(string codeTournee, PreparationInputModel input, CancellationToken cancellationToken)
    {
        var result = await SavePreparationDraftAsync(codeTournee, input, DraftStatuses.Brouillon, cancellationToken);
        if (!result.Success)
        {
            var invalidModel = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
            if (invalidModel is null)
            {
                return RedirectToAction(nameof(Tournees));
            }

            ModelState.AddModelError(string.Empty, result.Message ?? "Erreur inconnue pendant l'enregistrement du brouillon.");
            ReapplyInputValues(invalidModel, input);
            return View(invalidModel);
        }

        TempData["Success"] = result.StatusConservePretVerrouillage
            ? "Quantités mises à jour. La tournée reste prête pour le verrouillage automatique de 22h35."
            : "Quantités enregistrées côté Expédition.";

        return string.Equals(input.ActionType, "recap", StringComparison.OrdinalIgnoreCase)
            ? RedirectToAction(nameof(Recapitulatif), new { codeTournee })
            : RedirectToAction(nameof(Preparer), new { codeTournee });
    }

    [HttpGet("/expedition/tournees/{codeTournee}/lignes/detail")]
    public async Task<IActionResult> DetailLigne(string codeTournee, string idLigneSource, CancellationToken cancellationToken)
    {
        var model = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
        if (model is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Tournees));
        }

        var ligne = model.Lignes.FirstOrDefault(l => string.Equals(l.IdLigneSource, idLigneSource, StringComparison.OrdinalIgnoreCase));
        if (ligne is null)
        {
            TempData["Error"] = "La ligne demandée n'existe pas dans la tournée chargée.";
            return RedirectToAction(nameof(Preparer), new { codeTournee });
        }

        ViewData["SelectedLineId"] = ligne.IdLigneSource;
        return View(model);
    }

    [HttpPost("/expedition/tournees/{codeTournee}/lignes/detail")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DetailLigne(string codeTournee, string idLigneSource, PreparationLigneInputModel input, CancellationToken cancellationToken)
    {
        input.IdLigneSource = string.IsNullOrWhiteSpace(input.IdLigneSource) ? idLigneSource : input.IdLigneSource;
        var result = await SavePreparationDraftAsync(
            codeTournee,
            new PreparationInputModel { Lignes = [input] },
            DraftStatuses.Brouillon,
            cancellationToken);

        TempData[result.Success ? "Success" : "Error"] = result.Success
            ? (result.StatusConservePretVerrouillage
                ? "Quantités de la ligne mises à jour. La tournée reste prête pour verrouillage."
                : "Quantités de la ligne enregistrées.")
            : result.Message;

        return RedirectToAction(nameof(DetailLigne), new { codeTournee, idLigneSource = input.IdLigneSource });
    }

    [HttpGet("/expedition/tournees/{codeTournee}/recapitulatif")]
    public async Task<IActionResult> Recapitulatif(string codeTournee, CancellationToken cancellationToken)
    {
        var model = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
        if (model is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Tournees));
        }
        return View(model);
    }

    [HttpPost("/expedition/tournees/{codeTournee}/marquer-pret")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> MarquerPretPourVerrouillage(string codeTournee, CancellationToken cancellationToken)
    {
        var model = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
        if (model is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Tournees));
        }

        if (model.IsReadOnly)
        {
            TempData["Error"] = "Cette tournée est déjà verrouillée.";
            return RedirectToAction(nameof(Recapitulatif), new { codeTournee });
        }

        var input = new PreparationInputModel
        {
            Lignes = model.Lignes.Select(l => new PreparationLigneInputModel
            {
                IdLigneSource = l.IdLigneSource,
                Quantites = l.Quantites.Select(q => new PreparationQuantiteInputModel
                {
                    CodeArticle = q.Key,
                    QuantiteLivreePrevue = q.Value
                }).ToList()
            }).ToList()
        };

        var result = await SavePreparationDraftAsync(codeTournee, input, DraftStatuses.PretVerrouillage, cancellationToken);
        TempData[result.Success ? "Success" : "Error"] = result.Success
            ? "Tournée marquée prête pour le verrouillage automatique de 22h35."
            : result.Message;

        return RedirectToAction(nameof(Recapitulatif), new { codeTournee });
    }

    [HttpPost("/expedition/developpement/verrouiller-maintenant")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> VerrouillerManuellementDeveloppement(string codeTournee, CancellationToken cancellationToken)
    {
        if (!string.Equals(_environment.EnvironmentName, "Development", StringComparison.OrdinalIgnoreCase))
        {
            return NotFound();
        }

        try
        {
            var result = await _verrouillageService.TryRunDetailedAsync(
                DateTimeOffset.UtcNow,
                $"DEV-{DateTimeOffset.UtcNow:yyyyMMddHHmmss}",
                cancellationToken,
                ignorerVerrouillageDejaReussi: true,
                bypassWindow: _verrouillageOptions.AllowDevelopmentManualLockOutsideWindow);

            TempData[result.IsSuccess ? "Success" : "Error"] = result.Message;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erreur pendant le verrouillage manuel de développement.");
            TempData["Error"] = $"Erreur technique pendant le verrouillage manuel de développement : {ex.Message}";
        }

        return RedirectToAction(nameof(Recapitulatif), new { codeTournee });
    }

    private async Task<PreparationTourneeViewModel?> BuildPreparationViewModelAsync(string codeTournee, CancellationToken cancellationToken)
    {
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        var tournee = load?.Tournees.FirstOrDefault(t => string.Equals(t.CodeTournee, codeTournee, StringComparison.OrdinalIgnoreCase));
        if (load is null || tournee is null)
        {
            return null;
        }

        var tourneeState = await _draftStore.GetTourneeStateAsync(load.DateTournee, codeTournee, cancellationToken);
        var lineStates = await _draftStore.GetLineStatesAsync(load.DateTournee, codeTournee, cancellationToken);
        var isReadOnly = tournee.EstVerrouilleeBd || tourneeState?.IsLocked == true;
        var articlesPrepares = BuildArticlesPrepares(load.ArticlesSuivis);

        var model = new PreparationTourneeViewModel
        {
            DateTournee = load.DateTournee,
            CodeTournee = tournee.CodeTournee,
            LibelleTournee = tournee.LibelleTournee,
            EtatPreparation = isReadOnly ? DraftStatuses.Verrouille : tourneeState?.Status ?? tournee.EtatPreparation,
            IsReadOnly = isReadOnly,
            IsAdministrationMode = false,
            Articles = articlesPrepares,
            Lignes = []
        };

        foreach (var ligne in tournee.Lignes.OrderBy(l => l.OrdreArret))
        {
            lineStates.TryGetValue(ligne.IdLigneSource, out var lineState);
            var vm = new PreparationLigneViewModel
            {
                IdLigneSource = ligne.IdLigneSource,
                OrdreArret = ligne.OrdreArret,
                NumClient = ligne.Client.NumClient,
                NomClient = string.IsNullOrWhiteSpace(ligne.Client.NomAffiche) ? ligne.Client.NomClient : ligne.Client.NomAffiche,
                CodePDL = ligne.PointLivraison.CodePDL,
                DescriptionPDL = ligne.PointLivraison.DescriptionPDL,
                Adresse = BuildAddress(ligne.PointLivraison),
                Instructions = ligne.InfosLecture.Instructions,
                ZoneDechargement = ligne.InfosLecture.ZoneDechargement,
                FermetureClient = ligne.InfosLecture.FermetureClient,
                CommentaireExceptionnel = null,
                DerniereModificationUtc = lineState?.LastModifiedQuantiteUtc,
                Quantites = new Dictionary<string, int?>(StringComparer.OrdinalIgnoreCase)
            };

            foreach (var article in articlesPrepares)
            {
                vm.Quantites[article.CodeArticle] = lineState is not null && lineState.Quantites.TryGetValue(article.CodeArticle, out var stored)
                    ? stored
                    : ligne.BrouillonInitial.Quantites.FirstOrDefault(q => string.Equals(q.CodeArticle, article.CodeArticle, StringComparison.OrdinalIgnoreCase))?.QuantiteLivreePrevue;
            }
            model.Lignes.Add(vm);
        }

        return model;
    }

    private static List<ArticleSuiviDto> BuildArticlesPrepares(List<ArticleSuiviDto> articles)
    {
        var defaults = new[]
        {
            new ArticleSuiviDto { CodeArticle = "ROLLS", LibelleArticle = "Chariots", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "ROLLS_VIDES", LibelleArticle = "Chariots vides", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "TAPIS", LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "SACS", LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
        };
        return defaults.Select(defaultArticle => articles.FirstOrDefault(a => string.Equals(a.CodeArticle, defaultArticle.CodeArticle, StringComparison.OrdinalIgnoreCase)) ?? defaultArticle).ToList();
    }

    private static void ReapplyInputValues(PreparationTourneeViewModel model, PreparationInputModel input)
    {
        var inputByLine = input.Lignes.ToDictionary(l => l.IdLigneSource, StringComparer.OrdinalIgnoreCase);
        foreach (var ligne in model.Lignes)
        {
            if (!inputByLine.TryGetValue(ligne.IdLigneSource, out var inputLine))
            {
                continue;
            }

            foreach (var quantite in inputLine.Quantites.Where(q => !string.IsNullOrWhiteSpace(q.CodeArticle)))
            {
                ligne.Quantites[quantite.CodeArticle] = quantite.QuantiteLivreePrevue;
            }
        }
    }

    private static List<string> ValidatePreparationInput(PreparationInputModel input, TourneePreparationDto tournee, List<ArticleSuiviDto> articles)
    {
        var errors = new List<string>();
        var knownLines = tournee.Lignes.Select(l => l.IdLigneSource).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var knownArticles = articles.Select(a => a.CodeArticle).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var line in input.Lignes)
        {
            if (string.IsNullOrWhiteSpace(line.IdLigneSource) || !knownLines.Contains(line.IdLigneSource))
            {
                errors.Add("Une ligne envoyée par le formulaire ne correspond à aucune ligne chargée.");
                continue;
            }
            foreach (var quantity in line.Quantites)
            {
                if (string.IsNullOrWhiteSpace(quantity.CodeArticle) || !knownArticles.Contains(quantity.CodeArticle))
                {
                    errors.Add($"Article inconnu pour la ligne {line.IdLigneSource}.");
                    continue;
                }
                if (quantity.QuantiteLivreePrevue < 0)
                {
                    errors.Add($"Quantité négative interdite pour la ligne {line.IdLigneSource}, article {quantity.CodeArticle}.");
                }
            }
        }
        return errors.Distinct().ToList();
    }

    private static string BuildAddress(PointLivraisonDto point)
    {
        var parts = new[] { point.AdresseLigne1, point.AdresseLigne2, point.AdresseLigne3, string.Join(' ', new[] { point.CodePostal, point.Ville }.Where(v => !string.IsNullOrWhiteSpace(v))) };
        return string.Join(" - ", parts.Where(p => !string.IsNullOrWhiteSpace(p)));
    }

    private async Task<SavePreparationResult> SavePreparationDraftAsync(string codeTournee, PreparationInputModel input, string status, CancellationToken cancellationToken)
    {
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        var tournee = load?.Tournees.FirstOrDefault(t => string.Equals(t.CodeTournee, codeTournee, StringComparison.OrdinalIgnoreCase));
        if (load is null || tournee is null)
        {
            return SavePreparationResult.Fail("La tournée demandée n'existe pas dans les données chargées.");
        }

        var state = await _draftStore.GetTourneeStateAsync(load.DateTournee, codeTournee, cancellationToken);
        if (tournee.EstVerrouilleeBd || state?.IsLocked == true)
        {
            return SavePreparationResult.Fail("Cette tournée est verrouillée. La modification est refusée.");
        }

        var articles = BuildArticlesPrepares(load.ArticlesSuivis);
        var errors = ValidatePreparationInput(input, tournee, articles);
        if (errors.Count > 0)
        {
            return SavePreparationResult.Fail(string.Join(" ", errors));
        }

        var allowedArticles = articles.Select(a => a.CodeArticle).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var drafts = input.Lignes.Select(l => new SavePreparationLineDraft
        {
            IdLigneSource = l.IdLigneSource,
            Quantites = l.Quantites
                .Where(q => allowedArticles.Contains(q.CodeArticle))
                .ToDictionary(q => q.CodeArticle, q => q.QuantiteLivreePrevue, StringComparer.OrdinalIgnoreCase)
        }).ToList();

        var effectiveStatus = ResolveStatusAfterExpeditionUpdate(status, state?.Status);
        var statusConservePretVerrouillage = IsReadyForLockStatus(state?.Status)
            && string.Equals(status, DraftStatuses.Brouillon, StringComparison.OrdinalIgnoreCase);

        try
        {
            await _draftStore.SavePreparationAsync(load.DateTournee, codeTournee, drafts, effectiveStatus, HttpContext.Connection.RemoteIpAddress?.ToString(), cancellationToken);
            return SavePreparationResult.Ok(statusConservePretVerrouillage);
        }
        catch (InvalidOperationException ex)
        {
            return SavePreparationResult.Fail(ex.Message);
        }
    }

    private static string ResolveStatusAfterExpeditionUpdate(string requestedStatus, string? currentStatus)
    {
        if (string.Equals(requestedStatus, DraftStatuses.Brouillon, StringComparison.OrdinalIgnoreCase)
            && IsReadyForLockStatus(currentStatus))
        {
            // Règle métier : une tournée prête pour verrouillage reste prête.
            // Une correction de quantité ne doit jamais la refaire passer en brouillon.
            return string.IsNullOrWhiteSpace(currentStatus) ? DraftStatuses.PretVerrouillage : currentStatus;
        }

        return requestedStatus;
    }

    private static bool IsReadyForLockStatus(string? status)
    {
        var normalized = status?.Trim().ToUpperInvariant();
        return normalized is "PRET_VERROUILLAGE" or "PRETE_VERROUILLAGE";
    }

    private sealed record SavePreparationResult(bool Success, string? Message, bool StatusConservePretVerrouillage)
    {
        public static SavePreparationResult Ok(bool statusConservePretVerrouillage = false) => new(true, null, statusConservePretVerrouillage);
        public static SavePreparationResult Fail(string message) => new(false, message, false);
    }
}
