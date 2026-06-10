using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.ViewModels;

namespace MobileSLI.Expedition.Web.Application.Administration;

/// <summary>
/// Validation métier des commentaires saisis dans l'espace Administration.
/// Elle vérifie que la ligne appartient bien à la tournée chargée et limite la taille du commentaire.
/// </summary>
public static class AdministrationCommentaireValidator
{
    // Limite applicative alignée avec l'usage attendu côté interface pour éviter les commentaires trop longs en brouillon.
    public const int CommentaireExceptionnelMaxLength = 400;

    public static AdministrationCommentaireValidationResult Validate(AdminCommentaireInputModel input, TourneePreparationDto tournee)
    {
        // Le commentaire doit toujours être rattaché à une ligne issue du dernier chargement API.
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