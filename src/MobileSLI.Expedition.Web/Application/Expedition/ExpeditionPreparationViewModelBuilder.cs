using MobileSLI.Expedition.Web.Application.Common;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using DomainArticleCodes = MobileSLI.Expedition.Web.Domain.Constants.ArticleCodes;

namespace MobileSLI.Expedition.Web.Application.Expedition;

/// <summary>
/// Adaptateur Expédition autour du builder partagé.
/// Il fixe les articles et les règles d'affichage propres à la saisie des quantités prévues.
/// </summary>
public sealed class ExpeditionPreparationViewModelBuilder
{
    // Articles suivis par défaut côté Expédition lorsque le chargement API ne fournit pas de référentiel complet.
    private static readonly IReadOnlyList<ArticleSuiviDto> DefaultArticles =
    [
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Rolls, LibelleArticle = "Chariots", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.RollsVides, LibelleArticle = "Chariots vides", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Tapis, LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Sacs, LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
    ];

    private static readonly PreparationViewModelBuildOptions BuildOptions = new()
    {
        // En mode Expédition, l'écran affiche les quantités à préparer et ne porte pas la saisie des commentaires Administration.
        IsAdministrationMode = false,
        DefaultArticles = DefaultArticles,
        ResolveCommentaireExceptionnel = (_, _) => null,
        ResolveDerniereModificationUtc = lineState => lineState?.LastModifiedQuantiteUtc
    };

    private readonly SharedPreparationViewModelBuilder _sharedBuilder;

    public ExpeditionPreparationViewModelBuilder(SharedPreparationViewModelBuilder sharedBuilder)
    {
        _sharedBuilder = sharedBuilder;
    }

    public Task<HomeIndexViewModel> BuildHomeIndexAsync(CancellationToken cancellationToken)
    {
        return _sharedBuilder.BuildHomeIndexAsync(cancellationToken);
    }

    public Task<TourneesIndexViewModel?> BuildTourneesIndexAsync(CancellationToken cancellationToken)
    {
        return _sharedBuilder.BuildTourneesIndexAsync(cancellationToken);
    }

    public Task<PreparationTourneeViewModel?> BuildPreparationAsync(string codeTournee, CancellationToken cancellationToken)
    {
        return _sharedBuilder.BuildPreparationAsync(codeTournee, BuildOptions, cancellationToken);
    }

    public List<ArticleSuiviDto> BuildArticlesPrepares(List<ArticleSuiviDto> articles)
    {
        // Même liste d'articles que celle affichée à l'écran : elle sert aussi à filtrer les quantités sauvegardées.
        return SharedPreparationViewModelBuilder.BuildArticlesPrepares(articles, DefaultArticles);
    }

    public void ReapplyInputValues(PreparationTourneeViewModel model, PreparationInputModel input)
    {
        // Réapplique la saisie utilisateur après erreur de validation pour éviter de perdre les quantités tapées.
        SharedPreparationViewModelBuilder.ReapplyInputValues(model, input);
    }
}