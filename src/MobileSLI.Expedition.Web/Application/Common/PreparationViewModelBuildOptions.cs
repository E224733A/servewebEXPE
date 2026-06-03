using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.Application.Common;

public sealed class PreparationViewModelBuildOptions
{
    public bool IsAdministrationMode { get; init; }

    public IReadOnlyList<ArticleSuiviDto> DefaultArticles { get; init; } = [];

    public Func<LineDraftState?, LignePreparationDto, string?> ResolveCommentaireExceptionnel { get; init; } = (_, _) => null;

    public Func<LineDraftState?, DateTimeOffset?> ResolveDerniereModificationUtc { get; init; } = _ => null;
}
