namespace MobileSLI.Expedition.Web.Options;

/// <summary>
/// Options de stockage local des brouillons Expédition/Administration.
/// La base SQLite reste propre à SERVWEB et ne remplace pas SQL Server central.
/// </summary>
public sealed class ExpeditionDbOptions
{
    public const string SectionName = "ExpeditionDb";

    // Chemin relatif par défaut sous le répertoire applicatif publié ; peut être remplacé par configuration.
    public string DatabasePath { get; set; } = "data/expedition-drafts.sqlite3";
}