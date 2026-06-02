using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;

namespace MobileSLI.Expedition.Web.Application.Administration;

public static class AdministrationCommentaireValidator
{
    public const int CommentaireExceptionnelMaxLength = 400;

    public static AdministrationCommentaireValidationResult Validate(AdminCommentaireInputModel input, TourneePreparationDto tournee)
    {
        if (string.IsNullOrWhiteSpace(input.IdLigneSource)
            || !tournee.Lignes.Any(l => string.Equals(l.IdLigneSource, input.IdLigneSource, StringComparison.OrdinalIgnoreCase)))
        {
            return AdministrationCommentaireValidationResult.Fail("La ligne demandée n'existe pas dans la tournée chargée.");
        }

        if (input.CommentaireExceptionnel?.Length > CommentaireExceptionnelMaxLength)
        {
            return AdministrationCommentaireValidationResult.Fail("Le commentaire exceptionnel ne doit pas dépasser 400 caractères.");
        }

        return AdministrationCommentaireValidationResult.Ok();
    }
}

public sealed record AdministrationCommentaireValidationResult(bool IsValid, string? Message)
{
    public static AdministrationCommentaireValidationResult Ok() => new(true, null);
    public static AdministrationCommentaireValidationResult Fail(string message) => new(false, message);
}
