using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.Services;

/// <summary>
/// Ancien client de test volontairement désactivé dans la version finale.
/// SERVWEB doit utiliser <see cref="ExpeditionApiClient"/> pour communiquer avec l'API centrale réelle.
/// </summary>
public sealed class FakeExpeditionApiClient : IExpeditionApiClient
{
    public Task<ExpeditionLoadResponse> GetPreparationsAsync(CancellationToken cancellationToken)
    {
        // Échec explicite : ce client ne doit pas produire de données factices en environnement final.
        throw new InvalidOperationException("FakeExpeditionApiClient est désactivé dans la version finale. Configure ExpeditionApi:BaseUrl et utilise l'API centrale réelle.");
    }

    public Task<ExpeditionLockResponse> VerrouillerAsync(ExpeditionLockRequest request, CancellationToken cancellationToken)
    {
        // Même règle pour le verrouillage : aucun lot ne doit être simulé côté SERVWEB final.
        throw new InvalidOperationException("FakeExpeditionApiClient est désactivé dans la version finale. Configure ExpeditionApi:BaseUrl et utilise l'API centrale réelle.");
    }

    public Task<bool> TesterApiAsync(CancellationToken cancellationToken)
    {
        // Le test API réel doit passer par le client HTTP configuré avec ExpeditionApi:BaseUrl.
        throw new InvalidOperationException("FakeExpeditionApiClient est désactivé dans la version finale. Configure ExpeditionApi:BaseUrl et utilise l'API centrale réelle.");
    }
}