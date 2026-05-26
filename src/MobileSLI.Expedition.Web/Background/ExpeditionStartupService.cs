using MobileSLI.Expedition.Web.Data;

namespace MobileSLI.Expedition.Web.Background;

public sealed class ExpeditionStartupService : IHostedService
{
    private readonly IExpeditionDraftStore _draftStore;
    private readonly ILogger<ExpeditionStartupService> _logger;

    public ExpeditionStartupService(IExpeditionDraftStore draftStore, ILogger<ExpeditionStartupService> logger)
    {
        _draftStore = draftStore;
        _logger = logger;
    }

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        await _draftStore.InitializeAsync(cancellationToken);
        await _draftStore.CleanupOldDataAsync(cancellationToken);
        _logger.LogInformation("Stockage SQLite Expédition initialisé et purge de démarrage exécutée.");
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
