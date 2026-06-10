namespace MobileSLI.Expedition.Web.Options;

/// <summary>
/// Options de stockage SQLite local des brouillons Expédition/Administration.
/// </summary>
public sealed class ExpeditionDbOptions
{
    public const string SectionName = "ExpeditionDb";

    public string DatabasePath { get; set; } = "data/expedition-drafts.sqlite3";
}