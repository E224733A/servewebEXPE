namespace MobileSLI.Expedition.Web.Options;

public sealed class AccessControlOptions
{
    public const string SectionName = "AccessControl";

    public bool Enabled { get; set; } = true;

    public bool RequireHttps { get; set; } = true;

    public bool BlockMobileUserAgents { get; set; } = true;

    public bool RequireIpAllowListInProduction { get; set; } = false;

    // Filtrage applicatif léger uniquement.
    // Le vrai filtrage réseau doit être fait au pare-feu Windows / IIS.
    // Exemple : ["192.168.1.", "10.0.0.", "127.0.0.1", "::1"]
    public List<string> AllowedIpPrefixes { get; set; } = [];
}
