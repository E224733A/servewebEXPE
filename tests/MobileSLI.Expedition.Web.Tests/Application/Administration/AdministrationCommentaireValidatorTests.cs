using MobileSLI.Expedition.Web.Application.Administration;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using Xunit;

namespace MobileSLI.Expedition.Web.Tests.Application.Administration;

/// <summary>
/// Tests unitaires du validator Administration.
/// Ils vérifient que les commentaires restent rattachés à une ligne connue et respectent la limite de longueur.
/// </summary>
public sealed class AdministrationCommentaireValidatorTests
{
    [Fact]
    public void Validate_ShouldAcceptKnownLineAndShortComment()
    {
        // Cas nominal : ligne connue et commentaire court.
        var input = new AdminCommentaireInputModel
        {
            IdLigneSource = "LINE-1",
            CommentaireExceptionnel = "Passage avant 10h."
        };
        var tournee = BuildTournee("LINE-1");

        var result = AdministrationCommentaireValidator.Validate(input, tournee);

        Assert.True(result.IsValid);
        Assert.Null(result.Message);
    }

    [Fact]
    public void Validate_ShouldAcceptNullComment()
    {
        // Null représente l'absence de commentaire exceptionnel et doit rester accepté.
        var input = new AdminCommentaireInputModel
        {
            IdLigneSource = "LINE-1",
            CommentaireExceptionnel = null
        };
        var tournee = BuildTournee("LINE-1");

        var result = AdministrationCommentaireValidator.Validate(input, tournee);

        Assert.True(result.IsValid);
        Assert.Null(result.Message);
    }

    [Fact]
    public void Validate_ShouldAcceptEmptyComment()
    {
        // Une chaîne vide permet d'effacer ou de ne pas renseigner le commentaire sans erreur de validation.
        var input = new AdminCommentaireInputModel
        {
            IdLigneSource = "LINE-1",
            CommentaireExceptionnel = string.Empty
        };
        var tournee = BuildTournee("LINE-1");

        var result = AdministrationCommentaireValidator.Validate(input, tournee);

        Assert.True(result.IsValid);
        Assert.Null(result.Message);
    }

    [Fact]
    public void Validate_ShouldAcceptCommentWithExactly400Characters()
    {
        // La limite de 400 caractères est inclusive.
        var input = new AdminCommentaireInputModel
        {
            IdLigneSource = "LINE-1",
            CommentaireExceptionnel = new string('A', 400)
        };
        var tournee = BuildTournee("LINE-1");

        var result = AdministrationCommentaireValidator.Validate(input, tournee);

        Assert.True(result.IsValid);
        Assert.Null(result.Message);
    }

    [Fact]
    public void Validate_ShouldRejectCommentWithMoreThan400Characters()
    {
        // À partir de 401 caractères, le commentaire dépasse la limite applicative attendue.
        var input = new AdminCommentaireInputModel
        {
            IdLigneSource = "LINE-1",
            CommentaireExceptionnel = new string('A', 401)
        };
        var tournee = BuildTournee("LINE-1");

        var result = AdministrationCommentaireValidator.Validate(input, tournee);

        Assert.False(result.IsValid);
        Assert.Contains("400 caractères", result.Message);
    }

    [Fact]
    public void Validate_ShouldRejectUnknownLine()
    {
        // Le commentaire ne doit jamais être enregistré sur une ligne absente du dernier chargement API.
        var input = new AdminCommentaireInputModel
        {
            IdLigneSource = "UNKNOWN-LINE",
            CommentaireExceptionnel = "Commentaire test"
        };
        var tournee = BuildTournee("LINE-1");

        var result = AdministrationCommentaireValidator.Validate(input, tournee);

        Assert.False(result.IsValid);
        Assert.Contains("n'existe pas", result.Message);
    }

    [Fact]
    public void Validate_ShouldRejectEmptyLineId()
    {
        // Sans identifiant de ligne, le commentaire ne peut pas être rattaché à une ligne de tournée fiable.
        var input = new AdminCommentaireInputModel
        {
            IdLigneSource = string.Empty,
            CommentaireExceptionnel = "Commentaire test"
        };
        var tournee = BuildTournee("LINE-1");

        var result = AdministrationCommentaireValidator.Validate(input, tournee);

        Assert.False(result.IsValid);
        Assert.Contains("n'existe pas", result.Message);
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
}