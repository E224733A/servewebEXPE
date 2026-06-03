using MobileSLI.Expedition.Web.Application.Common;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using DomainArticleCodes = MobileSLI.Expedition.Web.Domain.Constants.ArticleCodes;

namespace MobileSLI.Expedition.Web.Application.Expedition;

public sealed class ExpeditionPreparationViewModelBuilder
{
    private static readonly IReadOnlyList<ArticleSuiviDto> DefaultArticles =
    [
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Rolls, LibelleArticle = "Chariots", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.RollsVides, LibelleArticle = "Chariots vides", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Tapis, LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Sacs, LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
    ];

    private static readonly PreparationViewModelBuildOptions BuildOptions = new()
    {
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
        return SharedPreparationViewModelBuilder.BuildArticlesPrepares(articles, DefaultArticles);
    }

    public void ReapplyInputValues(PreparationTourneeViewModel model, PreparationInputModel input)
    {
        SharedPreparationViewModelBuilder.ReapplyInputValues(model, input);
    }
}
