namespace MobileSLI.Expedition.Web.Options;

public sealed class VerrouillageOptions
{
    public const string SectionName = "Verrouillage";

    public bool Enabled { get; set; } = true;

    public string TimeZoneId { get; set; } = "Europe/Paris";

    public int Hour { get; set; } = 22;

    public int Minute { get; set; } = 35;

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
