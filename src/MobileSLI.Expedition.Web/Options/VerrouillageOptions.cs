namespace MobileSLI.Expedition.Web.Options;

public sealed class VerrouillageOptions
{
    public const string SectionName = "Verrouillage";

    public bool Enabled { get; set; } = true;

    public string TimeZoneId { get; set; } = "Europe/Paris";

    public int Hour { get; set; } = 0;

    public int Minute { get; set; } = 5;

    public int WindowMinutes { get; set; } = 20;

    public int CheckEverySeconds { get; set; } = 60;

    public string LotSequence { get; set; } = "001";
}
