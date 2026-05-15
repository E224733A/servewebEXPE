using Microsoft.Extensions.Options;
using MobileSLI.Expedition.Web.Options;
using MobileSLI.Expedition.Web.Services;

namespace MobileSLI.Expedition.Web.Background;

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
            _logger.LogInformation("Verrouillage automatique Expédition désactivé par configuration.");
            return;
        }

        var interval = TimeSpan.FromSeconds(Math.Max(10, _options.CheckEverySeconds));
        using var timer = new PeriodicTimer(interval);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CheckAndRunAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Erreur dans la boucle de verrouillage automatique Expédition.");
            }

            await timer.WaitForNextTickAsync(stoppingToken);
        }
    }

    private async Task CheckAndRunAsync(CancellationToken cancellationToken)
    {
        var timezone = ResolveTimeZone(_options.TimeZoneId);
        var localNow = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, timezone);

        if (!IsInsideLockWindow(localNow))
        {
            return;
        }

        using var scope = _scopeFactory.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<VerrouillageService>();
        await service.TryRunAsync(localNow, _options.LotSequence, cancellationToken);
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
}
