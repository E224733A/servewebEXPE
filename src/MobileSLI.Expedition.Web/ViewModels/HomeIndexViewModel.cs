using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.ViewModels;

public sealed class HomeIndexViewModel
{
    public bool HasLoadedData { get; set; }

    public DateOnly? DateTournee { get; set; }

    public int TourneesCount { get; set; }

    public IReadOnlyList<LockHistoryItem> RecentLocks { get; set; } = [];
}
