namespace MobileSLI.Expedition.Web.Options;

public sealed class ExpeditionDbOptions
{
    public const string SectionName = "ExpeditionDb";

    public string DatabasePath { get; set; } = "data/expedition-drafts.sqlite3";
}
