using MobileSLI.Expedition.Web.Data;

namespace MobileSLI.Expedition.Web.Background;

/// <summary>
/// Service de démarrage de l'application Expédition.
/// Il prépare le stockage SQLite local avant que les écrans ne manipulent les brouillons.
/// </summary>
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
        // Initialisation obligatoire au démarrage : création des tables, index et paramètres SQLite.
        await _draftStore.InitializeAsync(cancellationToken);

        // Purge locale de sécurité pour éviter l'accumulation de vieux brouillons sur SERVWEB.
        await _draftStore.CleanupOldDataAsync(cancellationToken);
        _logger.LogInformation("Stockage SQLite Expédition initialisé et purge de démarrage exécutée.");
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}