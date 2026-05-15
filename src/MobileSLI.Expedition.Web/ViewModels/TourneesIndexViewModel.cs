namespace MobileSLI.Expedition.Web.ViewModels;

public sealed class TourneesIndexViewModel
{
    public DateOnly DateTournee { get; set; }

    public string FuseauHoraireMetier { get; set; } = "Europe/Paris";

    public List<TourneeListItemViewModel> Tournees { get; set; } = [];
}

public sealed class TourneeListItemViewModel
{
    public string CodeTournee { get; set; } = string.Empty;

    public string LibelleTournee { get; set; } = string.Empty;

    public string EtatPreparation { get; set; } = "NON_PREPAREE";

    public bool IsLocked { get; set; }

    public int NombreLignes { get; set; }
}
