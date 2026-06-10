namespace MobileSLI.Expedition.Web.Options;

/// <summary>
/// Filtrage applicatif SERVWEB complémentaire à IIS et au pare-feu.
/// </summary>
public sealed class AccessControlOptions
{
    public const string SectionName = "AccessControl";

    public bool Enabled { get; set; } = true;

    public bool RequireHttps { get; set; } = true;

    // L'application mobile doit parler à l'API centrale, pas à SERVWEB.
    public bool BlockMobileUserAgents { get; set; } = true;

    // Désactivé par défaut pour éviter de bloquer une installation sans préfixes IP validés.
    public bool RequireIpAllowListInProduction { get; set; } = false;

    // Filtrage applicatif léger uniquement ; le vrai filtrage réseau doit rester côté pare-feu Windows / IIS.
    public List<string> AllowedIpPrefixes { get; set; } = [];
}