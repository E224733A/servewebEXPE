using Microsoft.AspNetCore.Mvc;
using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Services;
using MobileSLI.Expedition.Web.ViewModels;

namespace MobileSLI.Expedition.Web.Controllers;

public sealed class ExpeditionController : Controller
{
    private readonly IExpeditionApiClient _apiClient;
    private readonly IExpeditionDraftStore _draftStore;
    private readonly ILogger<ExpeditionController> _logger;

    public ExpeditionController(IExpeditionApiClient apiClient, IExpeditionDraftStore draftStore, ILogger<ExpeditionController> logger)
    {
        _apiClient = apiClient;
        _draftStore = draftStore;
        _logger = logger;
    }

    [HttpGet("/")]
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
            var response = await _apiClient.GetPreparationsAsync(cancellationToken);
            TempData["Success"] = string.Equals(response.Statut, "SUCCESS", StringComparison.OrdinalIgnoreCase)
                ? $"Mode test API : API joignable. {response.Tournees.Count} tournée(s) reçue(s) pour le {response.DateTournee:dd/MM/yyyy}. Aucune donnée n'a été enregistrée par ce test."
                : $"Mode test API : réponse reçue, statut {response.Statut}. Aucune donnée n'a été enregistrée par ce test.";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erreur pendant le test API Expédition.");
            TempData["Error"] = "Mode test API : impossible de joindre ou de lire l'API centrale.";
        }

        return RedirectToAction(nameof(Index));
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
            Tournees = load.Tournees
                .OrderBy(t => t.CodeTournee)
                .Select(t =>
                {
                    states.TryGetValue(t.CodeTournee, out var state);
                    var isLocked = t.EstVerrouilleeBd || state?.IsLocked == true;
                    return new TourneeListItemViewModel
                    {
                        CodeTournee = t.CodeTournee,
                        LibelleTournee = t.LibelleTournee,
                        EtatPreparation = isLocked ? "VERROUILLEE_BD" : state?.Status ?? t.EtatPreparation,
                        IsLocked = isLocked,
                        NombreLignes = t.Lignes.Count
                    };
                })
                .ToList()
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
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        var tournee = load?.Tournees.FirstOrDefault(t => string.Equals(t.CodeTournee, codeTournee, StringComparison.OrdinalIgnoreCase));
        if (load is null || tournee is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Tournees));
        }

        var state = await _draftStore.GetTourneeStateAsync(load.DateTournee, codeTournee, cancellationToken);
        if (tournee.EstVerrouilleeBd || state?.IsLocked == true)
        {
            TempData["Error"] = "Cette tournée est verrouillée en BD. La modification est refusée.";
            return RedirectToAction(nameof(Preparer), new { codeTournee });
        }

        if (!ModelState.IsValid)
        {
            var invalidModel = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
            if (invalidModel is null)
            {
                return RedirectToAction(nameof(Tournees));
            }

            ReapplyInputValues(invalidModel, input);
            return View(invalidModel);
        }

        var errors = ValidatePreparationInput(input, tournee, load.ArticlesSuivis);
        if (errors.Count > 0)
        {
            foreach (var error in errors)
            {
                ModelState.AddModelError(string.Empty, error);
            }

            var invalidModel = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
            if (invalidModel is null)
            {
                return RedirectToAction(nameof(Tournees));
            }

            ReapplyInputValues(invalidModel, input);
            return View(invalidModel);
        }

        var status = string.Equals(input.ActionType, "ready", StringComparison.OrdinalIgnoreCase)
            ? "PRETE_VERROUILLAGE"
            : "EN_PREPARATION_WEB";

        var drafts = input.Lignes.Select(l => new SavePreparationLineDraft
        {
            IdLigneSource = l.IdLigneSource,
            CommentaireExceptionnel = l.CommentaireExceptionnel,
            Quantites = l.Quantites.ToDictionary(q => q.CodeArticle, q => q.QuantiteLivreePrevue, StringComparer.OrdinalIgnoreCase)
        }).ToList();

        try
        {
            await _draftStore.SavePreparationAsync(load.DateTournee, codeTournee, drafts, status, HttpContext.Connection.RemoteIpAddress?.ToString(), cancellationToken);
            TempData["Success"] = status == "PRETE_VERROUILLAGE"
                ? "Brouillon enregistré et tournée marquée prête pour le verrouillage automatique."
                : "Brouillon enregistré côté application web.";

            return string.Equals(input.ActionType, "recap", StringComparison.OrdinalIgnoreCase) || status == "PRETE_VERROUILLAGE"
                ? RedirectToAction(nameof(Recapitulatif), new { codeTournee })
                : RedirectToAction(nameof(Preparer), new { codeTournee });
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(Preparer), new { codeTournee });
        }
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

        var model = new PreparationTourneeViewModel
        {
            DateTournee = load.DateTournee,
            CodeTournee = tournee.CodeTournee,
            LibelleTournee = tournee.LibelleTournee,
            EtatPreparation = isReadOnly ? "VERROUILLEE_BD" : tourneeState?.Status ?? tournee.EtatPreparation,
            IsReadOnly = isReadOnly,
            Articles = load.ArticlesSuivis,
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
                CommentaireExceptionnel = lineState?.CommentaireExceptionnel ?? ligne.BrouillonInitial.CommentaireExceptionnel,
                DerniereModificationUtc = lineState?.LastModifiedUtc,
                Quantites = new Dictionary<string, int?>(StringComparer.OrdinalIgnoreCase)
            };

            foreach (var article in load.ArticlesSuivis)
            {
                var value = lineState is not null && lineState.Quantites.TryGetValue(article.CodeArticle, out var stored)
                    ? stored
                    : ligne.BrouillonInitial.Quantites.FirstOrDefault(q => string.Equals(q.CodeArticle, article.CodeArticle, StringComparison.OrdinalIgnoreCase))?.QuantiteLivreePrevue;

                vm.Quantites[article.CodeArticle] = value;
            }

            model.Lignes.Add(vm);
        }

        return model;
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

            ligne.CommentaireExceptionnel = inputLine.CommentaireExceptionnel;

            foreach (var quantite in inputLine.Quantites)
            {
                if (!string.IsNullOrWhiteSpace(quantite.CodeArticle))
                {
                    ligne.Quantites[quantite.CodeArticle] = quantite.QuantiteLivreePrevue;
                }
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
        var parts = new[]
        {
            point.AdresseLigne1,
            point.AdresseLigne2,
            point.AdresseLigne3,
            string.Join(' ', new[] { point.CodePostal, point.Ville }.Where(v => !string.IsNullOrWhiteSpace(v)))
        };

        return string.Join(" - ", parts.Where(p => !string.IsNullOrWhiteSpace(p)));
    }
}
