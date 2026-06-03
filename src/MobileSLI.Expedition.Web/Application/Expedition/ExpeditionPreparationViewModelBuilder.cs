using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using DomainArticleCodes = MobileSLI.Expedition.Web.Domain.Constants.ArticleCodes;
using DomainDraftStatuses = MobileSLI.Expedition.Web.Domain.Constants.DraftStatuses;

namespace MobileSLI.Expedition.Web.Application.Expedition;

public sealed class ExpeditionPreparationViewModelBuilder
{
    private readonly IExpeditionDraftStore _draftStore;

    public ExpeditionPreparationViewModelBuilder(IExpeditionDraftStore draftStore)
    {
        _draftStore = draftStore;
    }

    public async Task<HomeIndexViewModel> BuildHomeIndexAsync(CancellationToken cancellationToken)
    {
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        var locks = await _draftStore.GetRecentLockHistoryAsync(5, cancellationToken);

        return new HomeIndexViewModel
        {
            HasLoadedData = load is not null,
            DateTournee = load?.DateTournee,
            TourneesCount = load?.Tournees.Count ?? 0,
            RecentLocks = locks
        };
    }

    public async Task<TourneesIndexViewModel?> BuildTourneesIndexAsync(CancellationToken cancellationToken)
    {
        var load = await _draftStore.GetLastLoadedDataAsync(cancellationToken);
        if (load is null)
        {
            return null;
        }

        var states = await _draftStore.GetTourneeStatesAsync(load.DateTournee, cancellationToken);

        return new TourneesIndexViewModel
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
                    EtatPreparation = isLocked ? DomainDraftStatuses.Verrouille : state?.Status ?? t.EtatPreparation,
                    IsLocked = isLocked,
                    NombreLignes = t.Lignes.Count
                };
            }).ToList()
        };
    }

    public async Task<PreparationTourneeViewModel?> BuildPreparationAsync(string codeTournee, CancellationToken cancellationToken)
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
            EtatPreparation = isReadOnly ? DomainDraftStatuses.Verrouille : tourneeState?.Status ?? tournee.EtatPreparation,
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

    public List<ArticleSuiviDto> BuildArticlesPrepares(List<ArticleSuiviDto> articles)
    {
        var defaults = new[]
        {
            new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Rolls, LibelleArticle = "Chariots", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = DomainArticleCodes.RollsVides, LibelleArticle = "Chariots vides", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Tapis, LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Sacs, LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
        };

        return defaults.Select(defaultArticle =>
            articles.FirstOrDefault(a => string.Equals(a.CodeArticle, defaultArticle.CodeArticle, StringComparison.OrdinalIgnoreCase))
            ?? defaultArticle).ToList();
    }

    public void ReapplyInputValues(PreparationTourneeViewModel model, PreparationInputModel input)
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
