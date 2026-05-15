using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Options;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Options;

namespace MobileSLI.Expedition.Web.Services;

public sealed class ExpeditionApiClient : IExpeditionApiClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<ExpeditionApiClient> _logger;

    public ExpeditionApiClient(HttpClient httpClient, IOptions<ExpeditionApiOptions> options, ILogger<ExpeditionApiClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;

        var apiOptions = options.Value;
        _httpClient.BaseAddress = new Uri(apiOptions.BaseUrl, UriKind.Absolute);
        _httpClient.Timeout = TimeSpan.FromSeconds(apiOptions.TimeoutSeconds <= 0 ? 30 : apiOptions.TimeoutSeconds);
    }

    public async Task<ExpeditionLoadResponse> GetPreparationsAsync(CancellationToken cancellationToken)
    {
        using var response = await _httpClient.GetAsync("api/expedition/preparations/a-preparer", cancellationToken);
        var content = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            throw new ExpeditionApiException("Le chargement des données Expédition a échoué.", (int)response.StatusCode, content);
        }

        var result = JsonSerializer.Deserialize<ExpeditionLoadResponse>(content, JsonDefaults.Options);
        if (result is null)
        {
            throw new ExpeditionApiException("La réponse de chargement Expédition est vide ou invalide.", (int)response.StatusCode, content);
        }

        _logger.LogInformation("Chargement Expédition reçu : {TourneesCount} tournée(s), date {DateTournee}", result.Tournees.Count, result.DateTournee);
        return result;
    }

    public async Task<ExpeditionLockResponse> VerrouillerAsync(ExpeditionLockRequest request, CancellationToken cancellationToken)
    {
        using var response = await _httpClient.PostAsJsonAsync("api/expedition/preparations/verrouiller", request, JsonDefaults.Options, cancellationToken);
        var content = await response.Content.ReadAsStringAsync(cancellationToken);

        var result = JsonSerializer.Deserialize<ExpeditionLockResponse>(content, JsonDefaults.Options);

        if (!response.IsSuccessStatusCode && result is null)
        {
            throw new ExpeditionApiException("Le verrouillage Expédition a échoué.", (int)response.StatusCode, content);
        }

        if (result is null)
        {
            throw new ExpeditionApiException("La réponse de verrouillage Expédition est vide ou invalide.", (int)response.StatusCode, content);
        }

        if (!response.IsSuccessStatusCode)
        {
            throw new ExpeditionApiException(result.Message ?? "Le verrouillage Expédition a été refusé par l'API.", (int)response.StatusCode, content, result.Statut);
        }

        _logger.LogInformation("Réponse verrouillage Expédition : {Statut} lot {IdLot}", result.Statut, result.IdLotVerrouillage);
        return result;
    }
}

public sealed class ExpeditionApiException : Exception
{
    public ExpeditionApiException(string message, int statusCode, string responseBody, string? apiStatus = null)
        : base(message)
    {
        StatusCode = statusCode;
        ResponseBody = responseBody;
        ApiStatus = apiStatus;
    }

    public int StatusCode { get; }

    public string ResponseBody { get; }

    public string? ApiStatus { get; }
}
