namespace MobileSLI.Expedition.Web.Options;

/// <summary>
/// Options de communication entre SERVWEB et l'API centrale MobileSLI.
/// Elles définissent l'URL, les délais réseau et l'éventuelle clé applicative.
/// </summary>
public sealed class ExpeditionApiOptions
{
    public const string SectionName = "ExpeditionApi";

    // Conservé uniquement pour empêcher une mauvaise configuration historique.
    // La version finale n'enregistre plus FakeExpeditionApiClient dans Program.cs.
    public bool UseFakeApi { get; set; } = false;

    // URL de base de l'API centrale utilisée pour charger les préparations et envoyer le verrouillage.
    public string BaseUrl { get; set; } = string.Empty;

    public int TimeoutSeconds { get; set; } = 30;

    // Garde-fou de configuration pour éviter de pointer SERVWEB vers une API non sécurisée en cible HTTPS.
    public bool RequireHttps { get; set; } = true;

    // Optionnel : à renseigner par variable d'environnement si l'API centrale exige une clé applicative.
    // Ne pas stocker de vraie clé dans appsettings.json ni dans Git.
    public string? ApiKeyHeaderName { get; set; } = "X-Expedition-Api-Key";

    public string? ApiKey { get; set; }
}