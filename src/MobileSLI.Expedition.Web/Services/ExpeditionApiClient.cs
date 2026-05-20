using System.Net.Http.Headers;
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
        if (string.IsNullOrWhiteSpace(apiOptions.BaseUrl))
        {
            throw new InvalidOperationException("ExpeditionApi:BaseUrl doit pointer vers l'API centrale réelle.");
        }

        _httpClient.BaseAddress = new Uri(apiOptions.BaseUrl, UriKind.Absolute);
        _httpClient.Timeout = TimeSpan.FromSeconds(apiOptions.TimeoutSeconds <= 0 ? 30 : apiOptions.TimeoutSeconds);
        _httpClient.DefaultRequestHeaders.Accept.Clear();
        _httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("MobileSLI.Expedition.Web/1.0");

        if (!string.IsNullOrWhiteSpace(apiOptions.ApiKey) && !string.IsNullOrWhiteSpace(apiOptions.ApiKeyHeaderName))
        {
            _httpClient.DefaultRequestHeaders.Remove(apiOptions.ApiKeyHeaderName);
            _httpClient.DefaultRequestHeaders.Add(apiOptions.ApiKeyHeaderName, apiOptions.ApiKey);
        }
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

        _logger.LogInformation("Chargement Expédition réel reçu : {TourneesCount} tournée(s), date {DateTournee}", result.Tournees.Count, result.DateTournee);
        return result;
    }

    public async Task<ExpeditionLockResponse> VerrouillerAsync(ExpeditionLockRequest request, CancellationToken cancellationToken)
    {
        using var response = await _httpClient.PostAsJsonAsync("api/expedition/preparations/verrouiller", request, JsonDefaults.Options, cancellationToken);
        var content = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var apiError = TryReadApiError(content);
            var message = BuildApiErrorMessage(apiError, "Le verrouillage Expédition a été refusé par l'API.");

            throw new ExpeditionApiException(
                message,
                (int)response.StatusCode,
                content,
                apiError.Code ?? apiError.Statut);
        }

        ExpeditionLockResponse? result;
        try
        {
            result = JsonSerializer.Deserialize<ExpeditionLockResponse>(content, JsonDefaults.Options);
        }
        catch (JsonException ex)
        {
            throw new ExpeditionApiException(
                $"La réponse de verrouillage Expédition est invalide : {ex.Message}",
                (int)response.StatusCode,
                content);
        }

        if (result is null)
        {
            throw new ExpeditionApiException("La réponse de verrouillage Expédition est vide ou invalide.", (int)response.StatusCode, content);
        }

        if (!string.Equals(result.Statut, "SUCCESS", StringComparison.OrdinalIgnoreCase))
        {
            throw new ExpeditionApiException(
                result.Message ?? "Le verrouillage Expédition a été refusé par l'API.",
                (int)response.StatusCode,
                content,
                result.Code ?? result.Statut);
        }

        _logger.LogInformation("Réponse verrouillage Expédition réel : {Statut} lot {IdLot}", result.Statut, result.IdLotVerrouillage);
        return result;
    }

    public async Task<bool> TesterApiAsync(CancellationToken cancellationToken)
    {
        try
        {
            using var response = await _httpClient.GetAsync("api/health", cancellationToken);
            return response.IsSuccessStatusCode;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Erreur pendant le test de santé de l'API centrale.");
            return false;
        }
    }

    private static ExpeditionApiErrorBody TryReadApiError(string content)
    {
        if (string.IsNullOrWhiteSpace(content))
        {
            return new ExpeditionApiErrorBody();
        }

        try
        {
            return JsonSerializer.Deserialize<ExpeditionApiErrorBody>(content, JsonDefaults.Options)
                ?? new ExpeditionApiErrorBody();
        }
        catch (JsonException)
        {
            return new ExpeditionApiErrorBody
            {
                Message = content
            };
        }
    }

    private static string BuildApiErrorMessage(ExpeditionApiErrorBody apiError, string fallback)
    {
        var parts = new List<string>();

        if (!string.IsNullOrWhiteSpace(apiError.Message))
        {
            parts.Add(apiError.Message.Trim());
        }

        if (apiError.Errors is not null && apiError.Errors.Count > 0)
        {
            parts.Add(string.Join(" ", apiError.Errors.Where(error => !string.IsNullOrWhiteSpace(error))));
        }

        if (parts.Count == 0)
        {
            parts.Add(fallback);
        }

        if (!string.IsNullOrWhiteSpace(apiError.Code))
        {
            parts.Add($"Code API : {apiError.Code}.");
        }

        return string.Join(" ", parts);
    }

    private sealed class ExpeditionApiErrorBody
    {
        public string? Statut { get; set; }

        public string? Code { get; set; }

        public string? Message { get; set; }

        public List<string>? Errors { get; set; }
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
