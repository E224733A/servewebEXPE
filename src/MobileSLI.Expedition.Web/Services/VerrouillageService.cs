using System.Text.Json;
using Microsoft.Extensions.Options;
using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Options;

namespace MobileSLI.Expedition.Web.Services;

public sealed class VerrouillageService
{
    private static readonly SemaphoreSlim ProcessLock = new(1, 1);

    private static readonly HashSet<string> SuccessStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        "SUCCESS",
        "ALREADY_PROCESSED",
        "ALREADY_LOCKED"
    };

    private readonly IExpeditionDraftStore _draftStore;
    private readonly IExpeditionApiClient _apiClient;
    private readonly VerrouillageOptions _options;
    private readonly ILogger<VerrouillageService> _logger;

    public VerrouillageService(
        IExpeditionDraftStore draftStore,
        IExpeditionApiClient apiClient,
        IOptions<VerrouillageOptions> options,
        ILogger<VerrouillageService> logger)
    {
        _draftStore = draftStore;
        _apiClient = apiClient;
        _options = options.Value;
        _logger = logger;
    }

    public async Task<bool> TryRunAsync(DateTimeOffset requestedAtLocal, string lotSequence, CancellationToken cancellationToken)
    {
        var result = await TryRunDetailedAsync(
            requestedAtLocal,
            lotSequence,
            cancellationToken,
            ignorerVerrouillageDejaReussi: false,
            bypassWindow: false);

        return result.IsSuccess;
    }

    public async Task<VerrouillageRunResult> TryRunDetailedAsync(
        DateTimeOffset requestedAtLocal,
        string lotSequence,
        CancellationToken cancellationToken,
        bool ignorerVerrouillageDejaReussi = false,
        bool bypassWindow = false)
    {
        var timezone = ResolveTimeZone(_options.TimeZoneId);
        var localNow = TimeZoneInfo.ConvertTime(requestedAtLocal, timezone);

        if (!bypassWindow && !IsInsideLockWindow(localNow))
        {
            return VerrouillageRunResult.Failed(
                $"Verrouillage refusé : l'heure {localNow:HH:mm:ss} est hors fenêtre autorisée {_options.Hour:00}:{_options.Minute:00} pendant {_options.WindowMinutes} minutes.");
        }

        if (!await ProcessLock.WaitAsync(0, cancellationToken))
        {
            return VerrouillageRunResult.Failed("Un verrouillage est déjà en cours. Nouvel appel refusé.");
        }

        try
        {
            var lockWindowStart = GetLockWindowStart(localNow);
            return await RunOnceCoreAsync(lockWindowStart, lotSequence, cancellationToken, ignorerVerrouillageDejaReussi);
        }
        finally
        {
            ProcessLock.Release();
        }
    }

    public async Task<VerrouillageRunResult> TryRunWithOneRetryAsync(
        DateTimeOffset requestedAtLocal,
        string lotSequence,
        CancellationToken cancellationToken)
    {
        var first = await TryRunDetailedAsync(requestedAtLocal, lotSequence, cancellationToken);
        if (first.IsSuccess || !first.LotBuilt || first.IsConflictOrValidationError)
        {
            return first;
        }

        await Task.Delay(TimeSpan.FromSeconds(60), cancellationToken);

        var timezone = ResolveTimeZone(_options.TimeZoneId);
        var retryNow = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, timezone);
        if (!IsInsideLockWindow(retryNow))
        {
            return VerrouillageRunResult.Failed("Retry automatique refusé : la fenêtre de verrouillage est dépassée.");
        }

        return await TryRunDetailedAsync(retryNow, lotSequence, cancellationToken);
    }

    private async Task<VerrouillageRunResult> RunOnceCoreAsync(
        DateTimeOffset lockWindowStartLocal,
        string lotSequence,
        CancellationToken cancellationToken,
        bool ignorerVerrouillageDejaReussi)
    {
        var lot = await _draftStore.BuildLockLotAsync(lockWindowStartLocal, lotSequence, cancellationToken);
        if (lot is null)
        {
            _logger.LogDebug("Aucune tournée PRET_VERROUILLAGE à verrouiller dans le stockage SERVEXPE.");
            return VerrouillageRunResult.NoLot();
        }

        var codesTourneesLot = lot.Request.Tournees
            .Select(t => t.CodeTournee)
            .Where(code => !string.IsNullOrWhiteSpace(code))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (!ignorerVerrouillageDejaReussi
            && await _draftStore.HasSuccessfulLockAsync(lot.Request.DateTournee, codesTourneesLot, cancellationToken))
        {
            _logger.LogInformation(
                "Verrouillage SERVEXPE ignoré : toutes les tournées du lot sont déjà verrouillées pour la date {DateTournee}. Tournées : {CodesTournees}.",
                lot.Request.DateTournee,
                string.Join(", ", codesTourneesLot));

            return VerrouillageRunResult.Success(
                $"Verrouillage déjà effectué pour les tournées du lot ({string.Join(", ", codesTourneesLot)}). Aucun nouvel appel API n'a été envoyé.");
        }

        try
        {
            _logger.LogInformation(
                "Envoi du lot SERVEXPE {IdLot} vers l'API centrale avec {TourneesCount} tournée(s).",
                lot.Request.IdLotVerrouillage,
                lot.Request.Tournees.Count);

            await SaveDebugPayloadAsync(lot.Request, cancellationToken);

            var response = await _apiClient.VerrouillerAsync(lot.Request, cancellationToken);

            if (SuccessStatuses.Contains(response.Statut))
            {
                await _draftStore.MarkLockSuccessAsync(response, lot.PayloadHash, codesTourneesLot, cancellationToken);
                return VerrouillageRunResult.Success(
                    $"Verrouillage exécuté pour {lot.Request.Tournees.Count} tournée(s). Lot : {lot.Request.IdLotVerrouillage}.");
            }

            await _draftStore.MarkLockFailureAsync(
                lot.Request.IdLotVerrouillage,
                lot.Request.DateTournee,
                response.Statut,
                response.Message ?? "Verrouillage refusé par l'API centrale.",
                lot.PayloadHash,
                cancellationToken);

            return VerrouillageRunResult.Failed(response.Message ?? "Verrouillage refusé par l'API centrale.");
        }
        catch (ExpeditionApiException ex)
        {
            var status = ex.ApiStatus ?? "API_ERROR";
            await _draftStore.MarkLockFailureAsync(
                lot.Request.IdLotVerrouillage,
                lot.Request.DateTournee,
                status,
                ex.Message,
                lot.PayloadHash,
                cancellationToken);

            _logger.LogError(
                ex,
                "Erreur API pendant le verrouillage SERVEXPE du lot {IdLot}. Réponse API : {ResponseBody}",
                lot.Request.IdLotVerrouillage,
                ex.ResponseBody);

            return VerrouillageRunResult.Failed(
                $"API centrale ({ex.StatusCode}) : {ex.Message}",
                isConflictOrValidationError: status.Contains("CONFLICT", StringComparison.OrdinalIgnoreCase)
                                           || status.Contains("VALIDATION", StringComparison.OrdinalIgnoreCase)
                                           || status.Contains("DATE_TOURNEE_EXPIREE", StringComparison.OrdinalIgnoreCase));
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

            _logger.LogError(ex, "Erreur technique pendant le verrouillage SERVEXPE du lot {IdLot}.", lot.Request.IdLotVerrouillage);
            return VerrouillageRunResult.Failed($"Erreur technique pendant le verrouillage : {ex.Message}");
        }
    }

    public DateTimeOffset GetExpectedLockStart(DateTimeOffset now)
    {
        var timezone = ResolveTimeZone(_options.TimeZoneId);
        var localNow = TimeZoneInfo.ConvertTime(now, timezone);
        return GetLockWindowStart(localNow);
    }

    private DateTimeOffset GetLockWindowStart(DateTimeOffset localNow)
    {
        return new DateTimeOffset(localNow.Year, localNow.Month, localNow.Day, _options.Hour, _options.Minute, 0, localNow.Offset);
    }

    private bool IsInsideLockWindow(DateTimeOffset localNow)
    {
        var start = new TimeOnly(_options.Hour, _options.Minute);
        var current = TimeOnly.FromDateTime(localNow.DateTime);
        var minutes = (current.ToTimeSpan() - start.ToTimeSpan()).TotalMinutes;
        return minutes >= 0 && minutes < Math.Max(1, _options.WindowMinutes);
    }

    private static TimeZoneInfo ResolveTimeZone(string id)
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(id);
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Romance Standard Time");
        }
    }

    private async Task SaveDebugPayloadAsync(ExpeditionLockRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var debugDir = Path.Combine(AppContext.BaseDirectory, "..", "..", "data");
            Directory.CreateDirectory(debugDir);

            var debugFile = Path.Combine(debugDir, "debug-last-expedition-lock-payload.json");
            var json = JsonSerializer.Serialize(request, JsonDefaults.Options);
            await File.WriteAllTextAsync(debugFile, json, cancellationToken);

            _logger.LogInformation("Payload JSON de verrouillage sauvegardé pour diagnostic : {FilePath}", debugFile);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Impossible de sauvegarder le payload de diagnostic.");
        }
    }
}

public sealed record VerrouillageRunResult(
    bool IsSuccess,
    bool LotBuilt,
    string Message,
    bool IsConflictOrValidationError = false)
{
    public static VerrouillageRunResult NoLot() =>
        new(false, false, "Aucune tournée prête pour verrouillage. Vérifie qu’au moins une tournée est en état PRET_VERROUILLAGE.");

    public static VerrouillageRunResult Success(string message) => new(true, true, message);

    public static VerrouillageRunResult Failed(string message, bool isConflictOrValidationError = false) =>
        new(false, true, message, isConflictOrValidationError);
}
