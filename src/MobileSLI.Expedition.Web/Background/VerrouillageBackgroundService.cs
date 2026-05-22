using Microsoft.Extensions.Options;
using MobileSLI.Expedition.Web.Options;
using MobileSLI.Expedition.Web.Services;

namespace MobileSLI.Expedition.Web.Background;

/// <summary>
/// Filet de sécurité uniquement. Le déclencheur principal doit rester la tâche planifiée Windows à 22:35.
/// </summary>
public sealed class VerrouillageBackgroundService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly VerrouillageOptions _options;
    private readonly ILogger<VerrouillageBackgroundService> _logger;

    public VerrouillageBackgroundService(IServiceScopeFactory scopeFactory, IOptions<VerrouillageOptions> options, ILogger<VerrouillageBackgroundService> logger)
    {
        _scopeFactory = scopeFactory;
        _options = options.Value;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_options.Enabled)
        {
            _logger.LogInformation("Verrouillage automatique SERVEXPE désactivé par configuration.");
            return;
        }

        _logger.LogInformation("BackgroundService de verrouillage actif en secours. Le déclencheur principal reste la tâche Windows 22:35.");
        var interval = TimeSpan.FromSeconds(Math.Max(10, _options.CheckEverySeconds));
        using var timer = new PeriodicTimer(interval);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CheckAndRunAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Erreur dans la boucle de verrouillage automatique SERVEXPE.");
            }

            await timer.WaitForNextTickAsync(stoppingToken);
        }
    }

    private async Task CheckAndRunAsync(CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<VerrouillageService>();
        await service.TryRunAsync(DateTimeOffset.UtcNow, _options.LotSequence, cancellationToken);
    }
}
