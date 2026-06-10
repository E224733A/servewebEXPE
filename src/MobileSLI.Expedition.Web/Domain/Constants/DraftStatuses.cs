// Constantes métier partagées avec l'API centrale et le stockage local SQLite.
// Ne pas modifier ces valeurs sans vérifier le contrat JSON, les statuts API et les requêtes associées.

namespace MobileSLI.Expedition.Web.Domain.Constants;

/// <summary>
/// Statuts possibles pour les brouillons de préparation Expédition.
/// </summary>
public static class DraftStatuses
{
    /// <summary>
    /// Brouillon local saisi mais pas encore marqué prêt pour le verrouillage automatique.
    /// </summary>
    public const string Brouillon = "BROUILLON";

    /// <summary>
    /// Préparation web en cours, avant validation finale par l'opérateur.
    /// </summary>
    public const string EnPreparationWeb = "EN_PREPARATION_WEB";

    /// <summary>
    /// Statut historique masculin accepté par le web pour reconnaître une tournée prête au verrouillage.
    /// </summary>
    public const string PretVerrouillage = "PRET_VERROUILLAGE";

    /// <summary>
    /// Statut API attendu pour une tournée prête au verrouillage automatique.
    /// </summary>
    public const string PreteVerrouillage = "PRETE_VERROUILLAGE";

    /// <summary>
    /// Verrouillage temporairement en cours ; les modifications locales doivent être bloquées pendant cet état.
    /// </summary>
    public const string VerrouillageEnCours = "VERROUILLAGE_EN_COURS";

    /// <summary>
    /// Tournée verrouillée après succès API ; elle ne doit plus être modifiable côté web.
    /// </summary>
    public const string Verrouille = "VERROUILLE";

    /// <summary>
    /// État local utilisé lorsqu'un verrouillage n'a pas pu être envoyé ou confirmé.
    /// </summary>
    public const string ErreurEnvoi = "ERREUR_ENVOI";
}