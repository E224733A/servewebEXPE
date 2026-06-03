using MobileSLI.Expedition.Web.Application.Common;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using DomainArticleCodes = MobileSLI.Expedition.Web.Domain.Constants.ArticleCodes;

namespace MobileSLI.Expedition.Web.Application.Administration;

public sealed class AdministrationViewModelBuilder
{
    private static readonly IReadOnlyList<ArticleSuiviDto> DefaultArticles =
    [
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Rolls, LibelleArticle = "Rolls pleins", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Tapis, LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Sacs, LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
    ];

    private static readonly PreparationViewModelBuildOptions BuildOptions = new()
    {
        IsAdministrationMode = true,
        DefaultArticles = DefaultArticles,
        ResolveCommentaireExceptionnel = (lineState, ligne) => lineState?.CommentaireExceptionnel ?? ligne.BrouillonInitial.CommentaireExceptionnel,
        ResolveDerniereModificationUtc = lineState => lineState?.LastModifiedCommentaireUtc
    };

    private readonly SharedPreparationViewModelBuilder _sharedBuilder;

    public AdministrationViewModelBuilder(SharedPreparationViewModelBuilder sharedBuilder)
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
}
