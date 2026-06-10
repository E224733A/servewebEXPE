using MobileSLI.Expedition.Web.Application.Common;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using DomainArticleCodes = MobileSLI.Expedition.Web.Domain.Constants.ArticleCodes;

namespace MobileSLI.Expedition.Web.Application.Administration;

/// <summary>
/// Adaptateur Administration autour du builder partagé.
/// Il réutilise les tournées chargées par l'API, mais applique les règles d'affichage propres aux commentaires.
/// </summary>
public sealed class AdministrationViewModelBuilder
{
    // Référentiel Administration par défaut : il reste séparé de celui d'Expédition pour préserver le comportement existant.
    private static readonly IReadOnlyList<ArticleSuiviDto> DefaultArticles =
    [
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Rolls, LibelleArticle = "Rolls pleins", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Tapis, LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
        new ArticleSuiviDto { CodeArticle = DomainArticleCodes.Sacs, LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
    ];

    private static readonly PreparationViewModelBuildOptions BuildOptions = new()
    {
        // En mode Administration, les quantités sont consultées mais la saisie porte sur les commentaires exceptionnels.
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