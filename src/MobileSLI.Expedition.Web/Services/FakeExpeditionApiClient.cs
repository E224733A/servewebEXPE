using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.Services;

// Version finale : ce client ne génère plus de données de test.
// L'application web doit utiliser ExpeditionApiClient et les routes réelles de l'API centrale.
// Ce fichier est conservé uniquement pour éviter les références cassées dans d'anciens tests.
public sealed class FakeExpeditionApiClient : IExpeditionApiClient
{
    public Task<ExpeditionLoadResponse> GetPreparationsAsync(CancellationToken cancellationToken)
    {
        throw new InvalidOperationException("FakeExpeditionApiClient est désactivé dans la version finale. Configure ExpeditionApi:BaseUrl et utilise l'API centrale réelle.");
    }

    public Task<ExpeditionLockResponse> VerrouillerAsync(ExpeditionLockRequest request, CancellationToken cancellationToken)
    {
        throw new InvalidOperationException("FakeExpeditionApiClient est désactivé dans la version finale. Configure ExpeditionApi:BaseUrl et utilise l'API centrale réelle.");
    }
}
