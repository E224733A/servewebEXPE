using MobileSLI.Expedition.Web.Application.Administration;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;
using Xunit;

namespace MobileSLI.Expedition.Web.Tests.Application.Administration;

/// <summary>
/// Tests unitaires du validator Administration : rattachement à une ligne connue et limite de longueur.
/// </summary>
public sealed class AdministrationCommentaireValidatorTests
{
    [Fact]
    public void Validate_ShouldAcceptKnownLineAndShortComment()
    {
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