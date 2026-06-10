using MobileSLI.Expedition.Web.Domain.Constants;

namespace MobileSLI.Expedition.Web.Options;

/// <summary>
/// Paramètres du verrouillage automatique SERVWEB.
/// </summary>
public sealed class VerrouillageOptions
{
    public const string SectionName = "Verrouillage";

    public bool Enabled { get; set; } = true;

    // Fuseau métier utilisé pour calculer l'heure attendue du verrouillage, indépendamment de l'UTC technique.
    public string TimeZoneId { get; set; } = FuseauxHoraires.EuropeParis;

    public int Hour { get; set; } = 22;

    public int Minute { get; set; } = 35;

    // Fenêtre pendant laquelle le verrouillage automatique est considéré valide.
    public int WindowMinutes { get; set; } = 20;

    public int CheckEverySeconds { get; set; } = 60;

    public string LotSequence { get; set; } = "001";

    /// <summary>
    /// Secret technique optionnel utilisé par la tâche planifiée Windows pour appeler /verrouillage/executer.
    /// Ne jamais versionner une vraie valeur dans Git. Utiliser une variable d'environnement ou appsettings non versionné.
    /// </summary>
    public string? LockSecret { get; set; }

    public string LockSecretHeaderName { get; set; } = "X-SERVEXPE-LOCK-SECRET";

    /// <summary>
    /// Permet uniquement au bouton de développement de contourner la fenêtre horaire.
    /// Ne doit pas être utilisé pour la tâche planifiée de production.
    /// </summary>
    public bool AllowDevelopmentManualLockOutsideWindow { get; set; } = true;
}