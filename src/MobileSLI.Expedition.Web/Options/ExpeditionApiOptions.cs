namespace MobileSLI.Expedition.Web.Options;

/// <summary>
/// Options de communication entre SERVWEB et l'API centrale MobileSLI.
/// </summary>
public sealed class ExpeditionApiOptions
{
    public const string SectionName = "ExpeditionApi";

    // Conservé pour empêcher le retour accidentel à une configuration de test historique.
    public bool UseFakeApi { get; set; } = false;

    public string BaseUrl { get; set; } = string.Empty;

    public int TimeoutSeconds { get; set; } = 30;

    // Garde-fou de configuration pour éviter de pointer SERVWEB vers une API non sécurisée en cible HTTPS.
    public bool RequireHttps { get; set; } = true;

    // Ne pas stocker de vraie clé dans appsettings.json ni dans Git.
    public string? ApiKeyHeaderName { get; set; } = "X-Expedition-Api-Key";

    public string? ApiKey { get; set; }
}