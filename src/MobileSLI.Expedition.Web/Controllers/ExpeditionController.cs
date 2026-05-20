using Microsoft.AspNetCore.Hosting;
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
    private readonly VerrouillageService _verrouillageService;
    private readonly IWebHostEnvironment _environment;
    private readonly ILogger<ExpeditionController> _logger;

    public ExpeditionController(
        IExpeditionApiClient apiClient,
        IExpeditionDraftStore draftStore,
        VerrouillageService verrouillageService,
        IWebHostEnvironment environment,
        ILogger<ExpeditionController> logger)
    {
        _apiClient = apiClient;
        _draftStore = draftStore;
        _verrouillageService = verrouillageService;
        _environment = environment;
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

        var result = await SavePreparationDraftAsync(
            codeTournee,
            input,
            "EN_PREPARATION_WEB",
            cancellationToken);

        if (!result.Success)
        {
            var invalidModel = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
            if (invalidModel is null)
            {
                return RedirectToAction(nameof(Tournees));
            }

            ModelState.AddModelError(
                string.Empty,
                result.Message ?? "Erreur inconnue pendant l'enregistrement du brouillon.");
            ReapplyInputValues(invalidModel, input);
            return View(invalidModel);
        }

        TempData["Success"] = "Brouillon enregistré côté application web.";

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
        if (string.IsNullOrWhiteSpace(input.IdLigneSource))
        {
            input.IdLigneSource = idLigneSource;
        }

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
            return RedirectToAction(nameof(DetailLigne), new { codeTournee, idLigneSource = input.IdLigneSource });
        }

        var ligne = tournee.Lignes.FirstOrDefault(l => string.Equals(l.IdLigneSource, input.IdLigneSource, StringComparison.OrdinalIgnoreCase));
        if (ligne is null)
        {
            TempData["Error"] = "La ligne demandée n'existe pas dans la tournée chargée.";
            return RedirectToAction(nameof(Preparer), new { codeTournee });
        }

        var articles = BuildArticlesPrepares(load.ArticlesSuivis);
        var errors = ValidatePreparationInput(
            new PreparationInputModel
            {
                Lignes = [input]
            },
            tournee,
            articles);

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

            ReapplyInputValues(
                invalidModel,
                new PreparationInputModel
                {
                    Lignes = [input]
                });

            ViewData["SelectedLineId"] = input.IdLigneSource;
            return View(invalidModel);
        }

        var allowedArticles = articles.Select(a => a.CodeArticle).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var draft = new SavePreparationLineDraft
        {
            IdLigneSource = input.IdLigneSource,
            CommentaireExceptionnel = input.CommentaireExceptionnel,
            Quantites = input.Quantites
                .Where(q => allowedArticles.Contains(q.CodeArticle))
                .ToDictionary(q => q.CodeArticle, q => q.QuantiteLivreePrevue, StringComparer.OrdinalIgnoreCase)
        };

        try
        {
            await _draftStore.SavePreparationAsync(
                load.DateTournee,
                codeTournee,
                [draft],
                "EN_PREPARATION_WEB",
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);

            TempData["Success"] = "Ligne enregistrée dans le brouillon local.";
            return RedirectToAction(nameof(DetailLigne), new { codeTournee, idLigneSource = input.IdLigneSource });
        }
        catch (InvalidOperationException ex)
        {
            TempData["Error"] = ex.Message;
            return RedirectToAction(nameof(DetailLigne), new { codeTournee, idLigneSource = input.IdLigneSource });
        }
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
    public async Task<IActionResult> MarquerPretPourVerrouillage(
        string codeTournee,
        CancellationToken cancellationToken)
    {
        var model = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);

        if (model is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Tournees));
        }

        if (model.IsReadOnly)
        {
            TempData["Error"] = "Cette tournée est déjà verrouillée en BD.";
            return RedirectToAction(nameof(Recapitulatif), new { codeTournee });
        }

        var input = new PreparationInputModel
        {
            Lignes = model.Lignes.Select(l => new PreparationLigneInputModel
            {
                IdLigneSource = l.IdLigneSource,
                CommentaireExceptionnel = l.CommentaireExceptionnel,
                Quantites = l.Quantites.Select(q => new PreparationQuantiteInputModel
                {
                    CodeArticle = q.Key,
                    QuantiteLivreePrevue = q.Value
                }).ToList()
            }).ToList()
        };

        var result = await SavePreparationDraftAsync(
            codeTournee,
            input,
            "PRETE_VERROUILLAGE",
            cancellationToken);

        if (!result.Success)
        {
            TempData["Error"] = result.Message ?? "Erreur inconnue pendant le marquage prêt pour verrouillage.";
            return RedirectToAction(nameof(Recapitulatif), new { codeTournee });
        }

        TempData["Success"] = "Tournée marquée prête pour le verrouillage automatique.";
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

        if (string.IsNullOrWhiteSpace(codeTournee))
        {
            TempData["Error"] = "Impossible de déclencher le verrouillage manuel : code tournée manquant.";
            return RedirectToAction(nameof(Tournees));
        }

        try
        {
            var requestedAtLocal = DateTimeOffset.Now;
            var lotSequence = $"DEV-{DateTimeOffset.UtcNow:yyyyMMddHHmmss}";

            var executed = await _verrouillageService.TryRunAsync(requestedAtLocal, lotSequence, cancellationToken);

            if (executed)
            {
                TempData["Success"] = "Verrouillage manuel de développement exécuté. Vérifie l'historique et la base SQL Server.";
            }
            else
            {
                TempData["Error"] = "Aucun lot à verrouiller. Vérifie qu'une tournée est prête pour verrouillage et qu'elle n'est pas déjà verrouillée.";
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Erreur pendant le verrouillage manuel de développement.");
            TempData["Error"] = "Erreur technique pendant le verrouillage manuel de développement.";
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
            EtatPreparation = isReadOnly ? "VERROUILLEE_BD" : tourneeState?.Status ?? tournee.EtatPreparation,
            IsReadOnly = isReadOnly,
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
                CommentaireExceptionnel = lineState?.CommentaireExceptionnel ?? ligne.BrouillonInitial.CommentaireExceptionnel,
                DerniereModificationUtc = lineState?.LastModifiedUtc,
                Quantites = new Dictionary<string, int?>(StringComparer.OrdinalIgnoreCase)
            };

            foreach (var article in articlesPrepares)
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

    private static List<ArticleSuiviDto> BuildArticlesPrepares(List<ArticleSuiviDto> articles)
    {
        var defaults = new[]
        {
            new ArticleSuiviDto { CodeArticle = "ROLLS", LibelleArticle = "Rolls pleins", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "TAPIS", LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "SACS", LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
        };

        return defaults
            .Select(defaultArticle =>
            {
                var articleApi = articles.FirstOrDefault(a => string.Equals(a.CodeArticle, defaultArticle.CodeArticle, StringComparison.OrdinalIgnoreCase));
                return articleApi is null || string.IsNullOrWhiteSpace(articleApi.CodeArticle)
                    ? defaultArticle
                    : articleApi;
            })
            .ToList();
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

    private async Task<SavePreparationResult> SavePreparationDraftAsync(
        string codeTournee,
        PreparationInputModel input,
        string status,
        CancellationToken cancellationToken)
    {
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        var tournee = load?.Tournees.FirstOrDefault(t =>
            string.Equals(t.CodeTournee, codeTournee, StringComparison.OrdinalIgnoreCase));

        if (load is null || tournee is null)
        {
            return SavePreparationResult.Fail("La tournée demandée n'existe pas dans les données chargées.");
        }

        var state = await _draftStore.GetTourneeStateAsync(load.DateTournee, codeTournee, cancellationToken);

        if (tournee.EstVerrouilleeBd || state?.IsLocked == true)
        {
            return SavePreparationResult.Fail("Cette tournée est verrouillée en BD. La modification est refusée.");
        }

        var articles = BuildArticlesPrepares(load.ArticlesSuivis);
        var errors = ValidatePreparationInput(input, tournee, articles);

        if (errors.Count > 0)
        {
            return SavePreparationResult.Fail(string.Join(" ", errors));
        }

        var allowedArticles = articles
            .Select(a => a.CodeArticle)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var drafts = input.Lignes.Select(l => new SavePreparationLineDraft
        {
            IdLigneSource = l.IdLigneSource,
            CommentaireExceptionnel = l.CommentaireExceptionnel,
            Quantites = l.Quantites
                .Where(q => allowedArticles.Contains(q.CodeArticle))
                .ToDictionary(
                    q => q.CodeArticle,
                    q => q.QuantiteLivreePrevue,
                    StringComparer.OrdinalIgnoreCase)
        }).ToList();

        await _draftStore.SavePreparationAsync(
            load.DateTournee,
            codeTournee,
            drafts,
            status,
            HttpContext.Connection.RemoteIpAddress?.ToString(),
            cancellationToken);

        return SavePreparationResult.Ok();
    }

    private sealed record SavePreparationResult(bool Success, string? Message)
    {
        public static SavePreparationResult Ok() => new(true, null);

        public static SavePreparationResult Fail(string message) => new(false, message);
    }
}
