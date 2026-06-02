using DomainFuseauxHoraires = MobileSLI.Expedition.Web.Domain.Constants.FuseauxHoraires;

namespace MobileSLI.Expedition.Web.ViewModels;

/// <summary>
/// View model used on the expedition tournées index page. Centralises default values
/// for properties to avoid scattering magic strings across the application.
/// </summary>
public sealed class TourneesIndexViewModel
{
    public DateOnly DateTournee { get; set; }

    // Default business timezone is Europe/Paris. The constant is centralised to avoid
    // repeating the literal string across multiple models and options.
    public string FuseauHoraireMetier { get; set; } = DomainFuseauxHoraires.EuropeParis;

    public List<TourneeListItemViewModel> Tournees { get; set; } = [];
}

public sealed class TourneeListItemViewModel
{
    public string CodeTournee { get; set; } = string.Empty;

    public string LibelleTournee { get; set; } = string.Empty;

    // Non-prepared state uses the literal value, as this status is not part of expedition draft statuses.
    public string EtatPreparation { get; set; } = "NON_PREPAREE";

    public bool IsLocked { get; set; }

    public int NombreLignes { get; set; }
}