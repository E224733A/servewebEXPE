using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.Data;

public interface IExpeditionDraftStore
{
    Task InitializeAsync(CancellationToken cancellationToken);

    Task CleanupOldDataAsync(CancellationToken cancellationToken);

    Task SaveLoadedDataAsync(ExpeditionLoadResponse response, CancellationToken cancellationToken);

    Task<ExpeditionLoadResponse?> GetLastLoadedDataAsync(CancellationToken cancellationToken);

    Task<TourneeDraftState?> GetTourneeStateAsync(DateOnly dateTournee, string codeTournee, CancellationToken cancellationToken);

    Task<IReadOnlyDictionary<string, TourneeDraftState>> GetTourneeStatesAsync(DateOnly dateTournee, CancellationToken cancellationToken);

    Task<IReadOnlyDictionary<string, LineDraftState>> GetLineStatesAsync(DateOnly dateTournee, string codeTournee, CancellationToken cancellationToken);

    Task SavePreparationAsync(DateOnly dateTournee, string codeTournee, IReadOnlyList<SavePreparationLineDraft> lignes, string status, string? modifiedBy, CancellationToken cancellationToken);

    Task SaveAdminCommentaireAsync(DateOnly dateTournee, string codeTournee, SaveAdminCommentaireDraft commentaire, string? modifiedBy, CancellationToken cancellationToken);

    Task<PreparedLockLot?> BuildLockLotAsync(DateTimeOffset requestedAtLocal, string lotSequence, CancellationToken cancellationToken);

    Task<bool> HasSuccessfulLockAsync(DateOnly dateTournee, IReadOnlyCollection<string> codeTournees, CancellationToken cancellationToken);

    Task MarkLockSuccessAsync(ExpeditionLockResponse response, string payloadHash, IReadOnlyCollection<string> codeTourneesVerrouillees, CancellationToken cancellationToken);

    Task MarkLockFailureAsync(string idLotVerrouillage, DateOnly dateTournee, string status, string message, string payloadHash, CancellationToken cancellationToken);

    Task<IReadOnlyList<LockHistoryItem>> GetRecentLockHistoryAsync(int limit, CancellationToken cancellationToken);

    Task<PreparationStatusSnapshot> GetStatusSnapshotAsync(DateTimeOffset? expectedLockAtLocal, CancellationToken cancellationToken);
}
