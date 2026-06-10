using System.ComponentModel.DataAnnotations;
using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.ViewModels;

/// <summary>
/// ViewModel principal des écrans de préparation d'une tournée.
/// Il est partagé entre Expédition et Administration, avec un mode d'affichage piloté par IsAdministrationMode.
/// </summary>
public sealed class PreparationTourneeViewModel
{
    public DateOnly DateTournee { get; set; }

    public string CodeTournee { get; set; } = string.Empty;

    public string LibelleTournee { get; set; } = string.Empty;

    public string EtatPreparation { get; set; } = "NON_PREPAREE";

    public bool IsReadOnly { get; set; }

    public bool IsAdministrationMode { get; set; }

    public List<ArticleSuiviDto> Articles { get; set; } = [];

    public List<PreparationLigneViewModel> Lignes { get; set; } = [];

    public int NombreLignes => Lignes.Count;

    public int NombreCommentaires => Lignes.Count(l => !string.IsNullOrWhiteSpace(l.CommentaireExceptionnel));

    public int NombreLignesModifiees => Lignes.Count(l => l.EstModifiee);

    public int NombreFermeturesSignalees => Lignes.Count(l => l.FermetureClient);

    public int NombreQuantitesRenseignees => Lignes.Sum(l => l.Quantites.Count(q => q.Value.HasValue));
}

/// <summary>
/// Ligne affichée dans une tournée préparable, avec les informations client, PDL, commentaire et quantités.
/// </summary>
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

    // Indicateur d'affichage : une ligne est considérée modifiée si une quantité ou un commentaire local existe.
    public bool EstModifiee => DerniereModificationUtc.HasValue || !string.IsNullOrWhiteSpace(CommentaireExceptionnel) || Quantites.Any(q => q.Value.HasValue);
}

/// <summary>
/// Modèle de formulaire de préparation complète d'une tournée.
/// ActionType permet de distinguer l'enregistrement simple de la redirection vers le récapitulatif.
/// </summary>
public sealed class PreparationInputModel
{
    public string ActionType { get; set; } = "save";

    public List<PreparationLigneInputModel> Lignes { get; set; } = [];
}

/// <summary>
/// Modèle de formulaire pour une ligne de préparation Expédition.
/// </summary>
public sealed class PreparationLigneInputModel
{
    public string IdLigneSource { get; set; } = string.Empty;

    public List<PreparationQuantiteInputModel> Quantites { get; set; } = [];
}

/// <summary>
/// Quantité saisie côté Expédition pour un article préparé.
/// </summary>
public sealed class PreparationQuantiteInputModel
{
    public string CodeArticle { get; set; } = string.Empty;

    public int? QuantiteLivreePrevue { get; set; }
}

/// <summary>
/// Modèle de formulaire Administration pour le commentaire exceptionnel d'une ligne.
/// </summary>
public sealed class AdminCommentaireInputModel
{
    public string IdLigneSource { get; set; } = string.Empty;

    [StringLength(400, ErrorMessage = "Le commentaire exceptionnel ne doit pas dépasser 400 caractères.")]
    public string? CommentaireExceptionnel { get; set; }
}