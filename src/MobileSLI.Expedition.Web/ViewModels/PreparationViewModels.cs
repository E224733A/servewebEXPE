using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.ViewModels;

public sealed class PreparationTourneeViewModel
{
    public DateOnly DateTournee { get; set; }

    public string CodeTournee { get; set; } = string.Empty;

    public string LibelleTournee { get; set; } = string.Empty;

    public string EtatPreparation { get; set; } = "NON_PREPAREE";

    public bool IsReadOnly { get; set; }

    public List<ArticleSuiviDto> Articles { get; set; } = [];

    public List<PreparationLigneViewModel> Lignes { get; set; } = [];
}

public sealed class PreparationLigneViewModel
{
    public string IdLigneSource { get; set; } = string.Empty;

    public int OrdreArret { get; set; }

    public string NumClient { get; set; } = string.Empty;

    public string NomClient { get; set; } = string.Empty;

    public string CodePDL { get; set; } = string.Empty;

    public string? DescriptionPDL { get; set; }

    public string Adresse { get; set; } = string.Empty;

    public string? Instructions { get; set; }

    public string? ZoneDechargement { get; set; }

    public bool FermetureClient { get; set; }

    public string? CommentaireExceptionnel { get; set; }

    public DateTimeOffset? DerniereModificationUtc { get; set; }

    public Dictionary<string, int?> Quantites { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}

public sealed class PreparationInputModel
{
    public string ActionType { get; set; } = "save";

    public List<PreparationLigneInputModel> Lignes { get; set; } = [];
}

public sealed class PreparationLigneInputModel
{
    public string IdLigneSource { get; set; } = string.Empty;

    public string? CommentaireExceptionnel { get; set; }

    public List<PreparationQuantiteInputModel> Quantites { get; set; } = [];
}

public sealed class PreparationQuantiteInputModel
{
    public string CodeArticle { get; set; } = string.Empty;

    public int? QuantiteLivreePrevue { get; set; }
}
