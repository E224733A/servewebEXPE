using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.ViewModels;

/// <summary>
/// ViewModel de l'accueil Expédition et Administration.
/// Il synthétise le dernier chargement local et les dernières tentatives de verrouillage affichées à l'opérateur.
/// </summary>
public sealed class HomeIndexViewModel
{
    public bool HasLoadedData { get; set; }

    public DateOnly? DateTournee { get; set; }

    public int TourneesCount { get; set; }

    public IReadOnlyList<LockHistoryItem> RecentLocks { get; set; } = [];
}