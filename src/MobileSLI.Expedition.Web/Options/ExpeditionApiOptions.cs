namespace MobileSLI.Expedition.Web.Options;

public sealed class ExpeditionApiOptions
{
    public const string SectionName = "ExpeditionApi";

    public bool UseFakeApi { get; set; } = true;

    public string BaseUrl { get; set; } = "http://localhost:5000/";

    public int TimeoutSeconds { get; set; } = 30;
}
