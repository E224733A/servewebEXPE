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
        var lot = await _draftStore.BuildLockLotAsync(requestedAtLocal, lotSequence, cancellationToken);
        if (lot is null)
        {
            _logger.LogDebug("Aucun lot Expédition à verrouiller.");
            return false;
        }

        try
        {
            _logger.LogInformation("Envoi du lot Expédition {IdLot} vers l'API centrale.", lot.Request.IdLotVerrouillage);
            var response = await _apiClient.VerrouillerAsync(lot.Request, cancellationToken);

            if (SuccessStatuses.Contains(response.Statut))
            {
                await _draftStore.MarkLockSuccessAsync(response, lot.PayloadHash, cancellationToken);
                return true;
            }

            await _draftStore.MarkLockFailureAsync(
                lot.Request.IdLotVerrouillage,
                lot.Request.DateTournee,
                response.Statut,
                response.Message ?? "Verrouillage refusé par l'API centrale.",
                lot.PayloadHash,
                cancellationToken);

            return false;
        }
        catch (ExpeditionApiException ex)
        {
            await _draftStore.MarkLockFailureAsync(
                lot.Request.IdLotVerrouillage,
                lot.Request.DateTournee,
                ex.ApiStatus ?? "TECHNICAL_ERROR",
                ex.Message,
                lot.PayloadHash,
                cancellationToken);

            _logger.LogError(ex, "Erreur API pendant le verrouillage Expédition du lot {IdLot}.", lot.Request.IdLotVerrouillage);
            return false;
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
            return false;
        }
    }
}
