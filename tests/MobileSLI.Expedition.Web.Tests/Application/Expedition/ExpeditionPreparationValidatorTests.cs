using MobileSLI.Expedition.Web.Application.Expedition;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using Xunit;

namespace MobileSLI.Expedition.Web.Tests.Application.Expedition;

/// <summary>
/// Tests unitaires du validator Expédition : ligne connue, article connu et quantité non négative.
/// </summary>
public sealed class ExpeditionPreparationValidatorTests
{
    [Fact]
    public void Validate_ShouldAcceptPositiveQuantity()
    {
        var input = BuildInput("LINE-1", "ROLLS", 3);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Empty(errors);
    }

    [Fact]
    public void Validate_ShouldAcceptZeroQuantity()
    {
        var input = BuildInput("LINE-1", "ROLLS", 0);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Empty(errors);
    }

    [Fact]
    public void Validate_ShouldAcceptNullQuantity()
    {
        var input = BuildInput("LINE-1", "ROLLS", null);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Empty(errors);
    }

    [Fact]
    public void Validate_ShouldRejectNegativeQuantity()
    {
        var input = BuildInput("LINE-1", "ROLLS", -1);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Single(errors);
        Assert.Contains("Quantité négative interdite", errors[0]);
    }

    [Fact]
    public void Validate_ShouldRejectUnknownLine()
    {
        var input = BuildInput("UNKNOWN-LINE", "ROLLS", 1);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Single(errors);
        Assert.Contains("aucune ligne chargée", errors[0]);
    }

    [Fact]
    public void Validate_ShouldRejectUnknownArticle()
    {
        var input = BuildInput("LINE-1", "UNKNOWN-ARTICLE", 1);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Single(errors);
        Assert.Contains("Article inconnu", errors[0]);
    }

    private static PreparationInputModel BuildInput(string idLigneSource, string codeArticle, int? quantite)
    {
        return new PreparationInputModel
        {
            Lignes =
            [
                new PreparationLigneInputModel
                {
                    IdLigneSource = idLigneSource,
                    Quantites =
                    [
                        new PreparationQuantiteInputModel
                        {
                            CodeArticle = codeArticle,
                            QuantiteLivreePrevue = quantite
                        }
                    ]
                }
            ]
        };
    }

    private static TourneePreparationDto BuildTournee(string idLigneSource)
    {
        return new TourneePreparationDto
        {
            CodeTournee = "T001",
            LibelleTournee = "Tournee test",
            Lignes =
            [
                new LignePreparationDto
                {
                    IdLigneSource = idLigneSource,
                    OrdreArret = 1
                }
            ]
        };
    }

    private static List<ArticleSuiviDto> BuildArticles(params string[] codes)
    {
        return codes
            .Select(code => new ArticleSuiviDto
            {
                CodeArticle = code,
                LibelleArticle = code,
                TypeQuantite = "LIVREE_PREVUE"
            })
            .ToList();
    }
}