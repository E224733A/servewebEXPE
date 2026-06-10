using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using DomainDraftStatuses = MobileSLI.Expedition.Web.Domain.Constants.DraftStatuses;

namespace MobileSLI.Expedition.Web.Application.Common;

/// <summary>
/// Builder commun aux écrans Expédition et Administration.
/// Il transforme le dernier chargement SQLite et les brouillons locaux en ViewModels Razor,
/// pendant que les adaptateurs métier décident des articles et champs propres à chaque espace.
/// </summary>
public sealed class SharedPreparationViewModelBuilder
{
    private readonly IExpeditionDraftStore _draftStore;

    public SharedPreparationViewModelBuilder(IExpeditionDraftStore draftStore)
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

        // Les états locaux complètent le snapshot API : brouillon, prêt verrouillage ou verrouillé côté web.
        var states = await _draftStore.GetTourneeStatesAsync(load.DateTournee, cancellationToken);

        return new TourneesIndexViewModel
        {
            DateTournee = load.DateTournee,
            FuseauHoraireMetier = load.FuseauHoraireMetier,
            Tournees = load.Tournees
                .OrderBy(t => t.CodeTournee)
                .Select(t => BuildTourneeListItem(t, states))
                .ToList()
        };
    }

    public async Task<PreparationTourneeViewModel?> BuildPreparationAsync(
        string codeTournee,
        PreparationViewModelBuildOptions options,
        CancellationToken cancellationToken)
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
        var articles = BuildArticlesPrepares(load.ArticlesSuivis, options.DefaultArticles);

        return new PreparationTourneeViewModel
        {
            DateTournee = load.DateTournee,
            CodeTournee = tournee.CodeTournee,
            LibelleTournee = tournee.LibelleTournee,
            EtatPreparation = isReadOnly ? DomainDraftStatuses.Verrouille : tourneeState?.Status ?? tournee.EtatPreparation,
            IsReadOnly = isReadOnly,
            IsAdministrationMode = options.IsAdministrationMode,
            Articles = articles,
            Lignes = tournee.Lignes
                .OrderBy(l => l.OrdreArret)
                .Select(ligne =>
                {
                    lineStates.TryGetValue(ligne.IdLigneSource, out var lineState);
                    return BuildPreparationLine(ligne, lineState, articles, options);
                })
                .ToList()
        };
    }

    public static List<ArticleSuiviDto> BuildArticlesPrepares(
        List<ArticleSuiviDto> loadedArticles,
        IReadOnlyList<ArticleSuiviDto> defaultArticles)
    {
        // On respecte le référentiel API quand il contient l'article attendu ; sinon on garde l'article par défaut de l'écran.
        return defaultArticles
            .Select(defaultArticle =>
                loadedArticles.FirstOrDefault(a => string.Equals(a.CodeArticle, defaultArticle.CodeArticle, StringComparison.OrdinalIgnoreCase))
                ?? CloneArticle(defaultArticle))
            .ToList();
    }

    public static void ReapplyInputValues(PreparationTourneeViewModel model, PreparationInputModel input)
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
                // Après une erreur de validation, l'écran doit réafficher les valeurs saisies et non l'ancien brouillon.
                ligne.Quantites[quantite.CodeArticle] = quantite.QuantiteLivreePrevue;
            }
        }
    }

    private static TourneeListItemViewModel BuildTourneeListItem(
        TourneePreparationDto tournee,
        IReadOnlyDictionary<string, TourneeDraftState> states)
    {
        states.TryGetValue(tournee.CodeTournee, out var state);
        var isLocked = tournee.EstVerrouilleeBd || state?.IsLocked == true;

        return new TourneeListItemViewModel
        {
            CodeTournee = tournee.CodeTournee,
            LibelleTournee = tournee.LibelleTournee,
            EtatPreparation = isLocked ? DomainDraftStatuses.Verrouille : state?.Status ?? tournee.EtatPreparation,
            IsLocked = isLocked,
            NombreLignes = tournee.Lignes.Count
        };
    }

    private static PreparationLigneViewModel BuildPreparationLine(
        LignePreparationDto ligne,
        LineDraftState? lineState,
        IReadOnlyList<ArticleSuiviDto> articles,
        PreparationViewModelBuildOptions options)
    {
        return new PreparationLigneViewModel
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
            CommentaireExceptionnel = options.ResolveCommentaireExceptionnel(lineState, ligne),
            DerniereModificationUtc = options.ResolveDerniereModificationUtc(lineState),
            Quantites = BuildQuantites(ligne, lineState, articles)
        };
    }

    private static Dictionary<string, int?> BuildQuantites(
        LignePreparationDto ligne,
        LineDraftState? lineState,
        IReadOnlyList<ArticleSuiviDto> articles)
    {
        var quantites = new Dictionary<string, int?>(StringComparer.OrdinalIgnoreCase);

        foreach (var article in articles)
        {
            // Priorité au brouillon local ; à défaut, on reprend les quantités initiales reçues de l'API.
            quantites[article.CodeArticle] = lineState is not null && lineState.Quantites.TryGetValue(article.CodeArticle, out var stored)
                ? stored
                : ligne.BrouillonInitial.Quantites.FirstOrDefault(q => string.Equals(q.CodeArticle, article.CodeArticle, StringComparison.OrdinalIgnoreCase))?.QuantiteLivreePrevue;
        }

        return quantites;
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

    private static ArticleSuiviDto CloneArticle(ArticleSuiviDto article)
    {
        // Clone défensif pour éviter qu'un article par défaut partagé soit modifié par un ViewModel consommateur.
        return new ArticleSuiviDto
        {
            CodeArticle = article.CodeArticle,
            LibelleArticle = article.LibelleArticle,
            TypeQuantite = article.TypeQuantite,
            QuantiteNullable = article.QuantiteNullable
        };
    }
}