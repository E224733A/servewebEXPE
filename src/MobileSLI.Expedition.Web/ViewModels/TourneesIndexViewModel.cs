using DomainFuseauxHoraires = MobileSLI.Expedition.Web.Domain.Constants.FuseauxHoraires;

namespace MobileSLI.Expedition.Web.ViewModels;

/// <summary>
/// ViewModel de la page listant les tournées chargées pour une date métier.
/// Il centralise les informations nécessaires au choix d'une tournée à préparer ou à consulter.
/// </summary>
public sealed class TourneesIndexViewModel
{
    public DateOnly DateTournee { get; set; }

    // Le fuseau métier reste affiché pour diagnostiquer les écarts entre date serveur, date API et date de tournée.
    public string FuseauHoraireMetier { get; set; } = DomainFuseauxHoraires.EuropeParis;

    public List<TourneeListItemViewModel> Tournees { get; set; } = [];
}

/// <summary>
/// Élément résumé d'une tournée dans la liste principale.
/// </summary>
public sealed class TourneeListItemViewModel
{
    public string CodeTournee { get; set; } = string.Empty;

    public string LibelleTournee { get; set; } = string.Empty;

    // État par défaut avant modification locale ou retour de verrouillage.
    public string EtatPreparation { get; set; } = "NON_PREPAREE";

    public bool IsLocked { get; set; }

    public int NombreLignes { get; set; }
}