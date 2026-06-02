using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;

namespace MobileSLI.Expedition.Web.Application.Expedition;

public static class ExpeditionPreparationValidator
{
    public static List<string> Validate(PreparationInputModel input, TourneePreparationDto tournee, List<ArticleSuiviDto> articles)
    {
        var errors = new List<string>();
        var knownLines = tournee.Lignes.Select(l => l.IdLigneSource).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var knownArticles = articles.Select(a => a.CodeArticle).ToHashSet(StringComparer.OrdinalIgnoreCase);

        foreach (var line in input.Lignes)
        {
            if (string.IsNullOrWhiteSpace(line.IdLigneSource) || !knownLines.Contains(line.IdLigneSource))
            {
                errors.Add("Une ligne envoyée par le formulaire ne correspond à aucune ligne chargée.");
                continue;
            }

            foreach (var quantity in line.Quantites)
            {
                if (string.IsNullOrWhiteSpace(quantity.CodeArticle) || !knownArticles.Contains(quantity.CodeArticle))
                {
                    errors.Add($"Article inconnu pour la ligne {line.IdLigneSource}.");
                    continue;
                }

                if (quantity.QuantiteLivreePrevue < 0)
                {
                    errors.Add($"Quantité négative interdite pour la ligne {line.IdLigneSource}, article {quantity.CodeArticle}.");
                }
            }
        }

        return errors.Distinct().ToList();
    }
}
