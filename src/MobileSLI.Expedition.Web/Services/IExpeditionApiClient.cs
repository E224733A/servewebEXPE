using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.Services;

public interface IExpeditionApiClient
{
    Task<ExpeditionLoadResponse> GetPreparationsAsync(CancellationToken cancellationToken);

    Task<ExpeditionLockResponse> VerrouillerAsync(ExpeditionLockRequest request, CancellationToken cancellationToken);

    Task<bool> TesterApiAsync(CancellationToken cancellationToken);
}
