using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.Services;

public sealed class VerrouillageService
{
    private static readonly HashSet<string> SuccessStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "SUCCESS",
        "ALREADY_PROCESSED",
        "ALREADY_LOCKED"
    };

    private readonly IExpeditionDraftStore _draftStore;
    private readonly IExpeditionApiClient _apiClient;
    private readonly ILogger<VerrouillageService> _logger;

    public VerrouillageService(IExpeditionDraftStore draftStore, IExpeditionApiClient apiClient, ILogger<VerrouillageService> logger)
    {
        _draftStore = draftStore;
        _apiClient = apiClient;
        _logger = logger;
    }

    public async Task<bool> TryRunAsync(DateTimeOffset requestedAtLocal, string lotSequence, CancellationToken cancellationToken)
    {
        var result = await TryRunDetailedAsync(requestedAtLocal, lotSequence, cancellationToken);
        return result.IsSuccess;
    }

    public async Task<VerrouillageRunResult> TryRunDetailedAsync(DateTimeOffset requestedAtLocal, string lotSequence, CancellationToken cancellationToken)
    {
        var lot = await _draftStore.BuildLockLotAsync(requestedAtLocal, lotSequence, cancellationToken);
        if (lot is null)
        {
            _logger.LogDebug("Aucune tournée PRETE_VERROUILLAGE à verrouiller dans le stockage Expédition.");
            return VerrouillageRunResult.NoLot();
        }

        try
        {
            _logger.LogInformation(
                "Envoi du lot Expédition {IdLot} vers l'API centrale avec {TourneesCount} tournée(s) prête(s).",
                lot.Request.IdLotVerrouillage,
                lot.Request.Tournees.Count);

            var response = await _apiClient.VerrouillerAsync(lot.Request, cancellationToken);

            if (SuccessStatuses.Contains(response.Statut))
            {
                await _draftStore.MarkLockSuccessAsync(response, lot.PayloadHash, cancellationToken);

                return VerrouillageRunResult.Success(
                    $"Verrouillage exécuté pour {lot.Request.Tournees.Count} tournée(s) PRETE_VERROUILLAGE. Vérifie l'historique et la base SQL Server.");
            }

            await _draftStore.MarkLockFailureAsync(
                lot.Request.IdLotVerrouillage,
                lot.Request.DateTournee,
                response.Statut,
                response.Message ?? "Verrouillage refusé par l'API centrale.",
                lot.PayloadHash,
                cancellationToken);

            return VerrouillageRunResult.Failed(
                response.Message ?? "Verrouillage refusé par l'API centrale.");
        }
        catch (ExpeditionApiException ex)
        {
            await _draftStore.MarkLockFailureAsync(
                lot.Request.IdLotVerrouillage,
                lot.Request.DateTournee,
                ex.ApiStatus ?? "API_ERROR",
                ex.Message,
                lot.PayloadHash,
                cancellationToken);

            _logger.LogError(
                ex,
                "Erreur API pendant le verrouillage Expédition du lot {IdLot}. Réponse API : {ResponseBody}",
                lot.Request.IdLotVerrouillage,
                ex.ResponseBody);

            return VerrouillageRunResult.Failed(
                $"API centrale ({ex.StatusCode}) : {ex.Message}");
        }
        catch (Exception ex)
        {
            await _draftStore.MarkLockFailureAsync(
                lot.Request.IdLotVerrouillage,
                lot.Request.DateTournee,
                "TECHNICAL_ERROR",
                ex.Message,
                lot.PayloadHash,
                cancellationToken);

            _logger.LogError(ex, "Erreur technique pendant le verrouillage Expédition du lot {IdLot}.", lot.Request.IdLotVerrouillage);

            return VerrouillageRunResult.Failed(
                $"Erreur technique pendant le verrouillage : {ex.Message}");
        }
    }
}

public sealed record VerrouillageRunResult(
    bool IsSuccess,
    bool LotBuilt,
    string Message)
{
    public static VerrouillageRunResult NoLot() =>
        new(
            false,
            false,
            "Aucune tournée prête pour verrouillage. Vérifie qu’au moins une tournée est en état PRETE_VERROUILLAGE.");

    public static VerrouillageRunResult Success(string message) =>
        new(true, true, message);

    public static VerrouillageRunResult Failed(string message) =>
        new(false, true, message);
}
