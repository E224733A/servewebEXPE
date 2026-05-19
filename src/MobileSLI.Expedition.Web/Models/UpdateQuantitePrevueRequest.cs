namespace MobileSLI.Expedition.Web.Models;

public sealed class UpdateQuantitePrevueRequest
{
    public string IdLigneSource { get; set; } = string.Empty;

    public string CodeArticle { get; set; } = string.Empty;

    public int? QuantiteLivreePrevue { get; set; }
}
