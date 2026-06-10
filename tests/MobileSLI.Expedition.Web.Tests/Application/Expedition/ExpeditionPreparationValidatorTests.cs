using MobileSLI.Expedition.Web.Application.Expedition;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using Xunit;

namespace MobileSLI.Expedition.Web.Tests.Application.Expedition;

/// <summary>
/// Tests unitaires du validator Expédition.
/// Ils couvrent les règles minimales avant sauvegarde SQLite : ligne connue, article connu et quantité non négative.
/// </summary>
public sealed class ExpeditionPreparationValidatorTests
{
    [Fact]
    public void Validate_ShouldAcceptPositiveQuantity()
    {
        // Cas nominal : une quantité positive sur une ligne et un article connus doit être acceptée.
        var input = BuildInput("LINE-1", "ROLLS", 3);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Empty(errors);
    }

    [Fact]
    public void Validate_ShouldAcceptZeroQuantity()
    {
        // Zéro est autorisé : cela permet de préparer explicitement une absence de quantité prévue.
        var input = BuildInput("LINE-1", "ROLLS", 0);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Empty(errors);
    }

    [Fact]
    public void Validate_ShouldAcceptNullQuantity()
    {
        // Null reste autorisé pour représenter une quantité non renseignée dans le brouillon.
        var input = BuildInput("LINE-1", "ROLLS", null);
        var tournee = BuildTournee("LINE-1");
        var articles = BuildArticles("ROLLS");

        var errors = ExpeditionPreparationValidator.Validate(input, tournee, articles);

        Assert.Empty(errors);
    }

    [Fact]
    public void Validate_ShouldRejectNegativeQuantity()
    {
        // Une quantité négative n'a pas de sens métier pour la préparation et doit être refusée.
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
        // Protection contre un formulaire modifié ou désynchronisé : la ligne doit venir du chargement API.
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
        // Protection contre un article non prévu par le référentiel affiché à l'opérateur.
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
        // Tournée minimale suffisante pour tester l'appartenance d'une ligne au chargement API.
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
        // Référentiel d'articles minimal équivalent à celui fourni au validator par le builder Expédition.
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