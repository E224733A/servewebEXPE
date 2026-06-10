namespace MobileSLI.Expedition.Web.Options;

/// <summary>
/// Options de filtrage applicatif de l'interface SERVWEB.
/// Elles complètent IIS et le pare-feu, mais ne doivent pas être considérées comme l'unique barrière réseau.
/// </summary>
public sealed class AccessControlOptions
{
    public const string SectionName = "AccessControl";

    public bool Enabled { get; set; } = true;

    // Exige HTTPS côté application lorsque l'environnement cible doit être servi en TLS.
    public bool RequireHttps { get; set; } = true;

    // Protection simple contre l'usage direct depuis mobile : l'application mobile doit parler à l'API, pas à SERVWEB.
    public bool BlockMobileUserAgents { get; set; } = true;

    // Désactivé par défaut pour éviter de bloquer une installation si les préfixes IP n'ont pas été renseignés.
    public bool RequireIpAllowListInProduction { get; set; } = false;

    // Filtrage applicatif léger uniquement.
    // Le vrai filtrage réseau doit être fait au pare-feu Windows / IIS.
    // Laisser vide si le filtrage IP n'est pas utilisé.
    public List<string> AllowedIpPrefixes { get; set; } = [];
}