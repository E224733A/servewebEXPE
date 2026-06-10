// Constantes de contrat pour les articles suivis dans la préparation Expédition.
// Ne pas modifier ces codes sans vérifier les écrans, les brouillons SQLite et le lot envoyé à l'API centrale.

namespace MobileSLI.Expedition.Web.Domain.Constants;

/// <summary>
/// Codes articles suivis par l'application Expédition.
/// </summary>
public static class ArticleCodes
{
    public const string Rolls = "ROLLS";

    /// <summary>
    /// Article explicitement conservé dans le contrat Expédition pour les chariots vides.
    /// </summary>
    public const string RollsVides = "ROLLS_VIDES";

    public const string Tapis = "TAPIS";

    public const string Sacs = "SACS";
}