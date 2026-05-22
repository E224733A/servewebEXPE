using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using MobileSLI.Expedition.Web.Data;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Options;
using MobileSLI.Expedition.Web.Services;

namespace MobileSLI.Expedition.Web.Controllers;

public sealed class VerrouillageController : Controller
{
    private readonly IExpeditionDraftStore _draftStore;
    private readonly VerrouillageService _verrouillageService;
    private readonly VerrouillageOptions _options;
    private readonly ILogger<VerrouillageController> _logger;

    public VerrouillageController(
        IExpeditionDraftStore draftStore,
        VerrouillageService verrouillageService,
        IOptions<VerrouillageOptions> options,
        ILogger<VerrouillageController> logger)
    {
        _draftStore = draftStore;
        _verrouillageService = verrouillageService;
        _options = options.Value;
        _logger = logger;
    }

    [HttpPost("/verrouillage/executer")]
    public async Task<IActionResult> Executer(CancellationToken cancellationToken)
    {
        var securityCheck = CheckScheduledLockAccess();
        if (securityCheck is not null)
        {
            return securityCheck;
        }

        var result = await _verrouillageService.TryRunWithOneRetryAsync(
            DateTimeOffset.UtcNow,
            _options.LotSequence,
            cancellationToken);

        var payload = new
        {
            success = result.IsSuccess,
            lotBuilt = result.LotBuilt,
            message = result.Message
        };

        return result.IsSuccess ? Ok(payload) : StatusCode(StatusCodes.Status500InternalServerError, payload);
    }

    [HttpPost("/verrouillage/retry")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Retry(CancellationToken cancellationToken)
    {
        // La relance manuelle est volontairement séparée de /verrouillage/executer.
        // Elle reste disponible depuis l'interface SERVEXPE pour corriger une erreur réseau ou API.
        var result = await _verrouillageService.TryRunDetailedAsync(
            DateTimeOffset.UtcNow,
            _options.LotSequence,
            cancellationToken,
            ignorerVerrouillageDejaReussi: false,
            bypassWindow: true);

        TempData[result.IsSuccess ? "Success" : "Error"] = result.Message;
        return RedirectToAction("Index", "Expedition");
    }

    [HttpGet("/preparations/status")]
    public async Task<IActionResult> Status(CancellationToken cancellationToken)
    {
        var expected = _verrouillageService.GetExpectedLockStart(DateTimeOffset.UtcNow);
        var snapshot = await _draftStore.GetStatusSnapshotAsync(expected, cancellationToken);
        ApplyHeartbeat(snapshot);
        return Json(snapshot, JsonDefaults.Options);
    }

    private IActionResult? CheckScheduledLockAccess()
    {
        var remoteIp = HttpContext.Connection.RemoteIpAddress;
        if (remoteIp is null || !IPAddress.IsLoopback(remoteIp))
        {
            _logger.LogWarning("Refus /verrouillage/executer : adresse distante non locale {RemoteIp}.", remoteIp);
            return StatusCode(StatusCodes.Status403Forbidden, new { success = false, message = "Accès refusé : verrouillage planifié réservé à localhost." });
        }

        if (!string.IsNullOrWhiteSpace(_options.LockSecret))
        {
            if (!Request.Headers.TryGetValue(_options.LockSecretHeaderName, out var headerValues)
                || !string.Equals(headerValues.FirstOrDefault(), _options.LockSecret, StringComparison.Ordinal))
            {
                _logger.LogWarning("Refus /verrouillage/executer : secret technique manquant ou invalide.");
                return StatusCode(StatusCodes.Status403Forbidden, new { success = false, message = "Accès refusé : secret technique invalide." });
            }
        }

        return null;
    }

    private static void ApplyHeartbeat(PreparationStatusSnapshot snapshot)
    {
        var heartbeatPath = Path.Combine(AppContext.BaseDirectory, "logs", "verrouillage-planifie-heartbeat.json");
        if (!System.IO.File.Exists(heartbeatPath))
        {
            return;
        }

        try
        {
            var heartbeat = JsonSerializer.Deserialize<LockTaskHeartbeat>(System.IO.File.ReadAllText(heartbeatPath), JsonDefaults.Options);
            if (heartbeat is null)
            {
                return;
            }

            snapshot.TacheWindowsDerniereExecution = heartbeat.Date;
            snapshot.TacheWindowsDernierCodeRetour = heartbeat.CodeRetour;
        }
        catch
        {
            // La supervision doit rester disponible même si le fichier heartbeat est corrompu.
        }
    }
}
