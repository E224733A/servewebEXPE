using Microsoft.AspNetCore.Mvc;
using MobileSLI.Expedition.Web.Application.Administration;
using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Services;
using MobileSLI.Expedition.Web.ViewModels;
// Import des constantes métier pour éviter les chaînes magiques et clarifier l'origine des statuts.
// Les constantes se trouvent dans le namespace Domain.Constants de la partie Web.
using DomainArticleCodes = MobileSLI.Expedition.Web.Domain.Constants.ArticleCodes;
using DomainDraftStatuses = MobileSLI.Expedition.Web.Domain.Constants.DraftStatuses;
using DomainLotStatuses = MobileSLI.Expedition.Web.Domain.Constants.LotStatuses;

namespace MobileSLI.Expedition.Web.Controllers;

public sealed class AdministrationController : Controller
{
    private readonly IExpeditionApiClient _apiClient;
    private readonly IExpeditionDraftStore _draftStore;
    private readonly ILogger<AdministrationController> _logger;

    public AdministrationController(
        IExpeditionApiClient apiClient,
        IExpeditionDraftStore draftStore,
        ILogger<AdministrationController> logger)
    {
        _apiClient = apiClient;
        _draftStore = draftStore;
        _logger = logger;
    }

    [HttpGet("/administration")]
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

    [HttpPost("/administration/charger")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Charger(CancellationToken cancellationToken)
    {
        try
        {
            var response = await _apiClient.GetPreparationsAsync(cancellationToken);
            // Utilise une constante pour vérifier le statut de succès retourné par l'API afin d'éviter les chaînes magiques.
            if (!string.Equals(response.Statut, DomainLotStatuses.Success, StringComparison.OrdinalIgnoreCase))
            {
                TempData["Error"] = $"Le chargement a été refusé par l'API : {response.Statut}.";
                return RedirectToAction(nameof(Index));
            }

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
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        if (load is null)
        {
            TempData["Error"] = "Aucune donnée Administration n'a encore été chargée.";
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
                        EtatPreparation = isLocked ? DomainDraftStatuses.Verrouille : state?.Status ?? t.EtatPreparation,
                        IsLocked = isLocked,
                        NombreLignes = t.Lignes.Count
                    };
                })
                .ToList()
        };

        return View(model);
    }

    [HttpGet("/administration/tournees/{codeTournee}/commentaires")]
    public async Task<IActionResult> Commentaires(string codeTournee, CancellationToken cancellationToken)
    {
        var model = await BuildPreparationViewModelAsync(codeTournee, cancellationToken);
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
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        var tournee = load?.Tournees.FirstOrDefault(t => string.Equals(t.CodeTournee, codeTournee, StringComparison.OrdinalIgnoreCase));
        if (load is null || tournee is null)
        {
            TempData["Error"] = "La tournée demandée n'existe pas dans les données chargées.";
            return RedirectToAction(nameof(Index));
        }

        var state = await _draftStore.GetTourneeStateAsync(load.DateTournee, codeTournee, cancellationToken);
        if (tournee.EstVerrouilleeBd || state?.IsLocked == true)
        {
            TempData["Error"] = "Cette tournée est verrouillée. Modification Administration refusée.";
            return RedirectToAction(nameof(Commentaires), new { codeTournee });
        }

        var validation = AdministrationCommentaireValidator.Validate(input, tournee);
        if (!validation.IsValid)
        {
            TempData["Error"] = validation.Message;
            return RedirectToAction(nameof(Commentaires), new { codeTournee });
        }

        try
        {
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
            EtatPreparation = isReadOnly ? DomainDraftStatuses.Verrouille : tourneeState?.Status ?? tournee.EtatPreparation,
            IsReadOnly = isReadOnly,
            IsAdministrationMode = true,
            Articles = BuildArticlesPrepares(load.ArticlesSuivis),
            Lignes = []
        };

        foreach (var ligne in tournee.Lignes.OrderBy(l => l.OrdreArret))
        {
            lineStates.TryGetValue(ligne.IdLigneSource, out var lineState);
            var quantites = new Dictionary<string, int?>(StringComparer.OrdinalIgnoreCase);
            foreach (var article in model.Articles)
            {
                quantites[article.CodeArticle] = lineState is not null && lineState.Quantites.TryGetValue(article.CodeArticle, out var stored)
                    ? stored
                    : ligne.BrouillonInitial.Quantites.FirstOrDefault(q => string.Equals(q.CodeArticle, article.CodeArticle, StringComparison.OrdinalIgnoreCase))?.QuantiteLivreePrevue;
            }

            model.Lignes.Add(new PreparationLigneViewModel
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
                DerniereModificationUtc = lineState?.LastModifiedCommentaireUtc,
                Quantites = quantites
            });
        }

        return model;
    }

    private static List<ArticleSuiviDto> BuildArticlesPrepares(List<ArticleSuiviDto> articles)
    {
        // Centralisation des codes articles pour éviter la répétition de chaînes magiques.
        var defaults = new[]
        {
            new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Rolls, LibelleArticle = "Rolls pleins", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Tapis, LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Sacs, LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
        };

        return defaults.Select(defaultArticle =>
            articles.FirstOrDefault(a => string.Equals(a.CodeArticle, defaultArticle.CodeArticle, StringComparison.OrdinalIgnoreCase))
            ?? defaultArticle).ToList();
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
