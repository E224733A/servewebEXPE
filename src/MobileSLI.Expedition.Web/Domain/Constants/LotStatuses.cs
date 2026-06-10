// Constantes de contrat liées aux lots de verrouillage.
// Ne pas modifier ces valeurs sans vérifier l'API centrale, l'idempotence et l'historique SQLite.

namespace MobileSLI.Expedition.Web.Domain.Constants;

/// <summary>
/// Statuts possibles pour les lots de verrouillage retournés par l'API centrale ou stockés dans l'historique local.
/// </summary>
public static class LotStatuses
{
    /// <summary>
    /// Lot traité avec succès par l'API centrale.
    /// </summary>
    public const string Success = "SUCCESS";

    /// <summary>
    /// Lot déjà traité côté API ; considéré comme un succès fonctionnel pour l'idempotence.
    /// </summary>
    public const string AlreadyProcessed = "ALREADY_PROCESSED";

    /// <summary>
    /// Lot ou tournée déjà verrouillé côté API ; considéré comme un état non bloquant pour une relance identique.
    /// </summary>
    public const string AlreadyLocked = "ALREADY_LOCKED";

    /// <summary>
    /// Erreur locale ou distante lors de l'envoi du lot.
    /// </summary>
    public const string ErreurEnvoi = "ERREUR_ENVOI";

    /// <summary>
    /// Lot envoyé et accepté, utilisé dans l'historique local de verrouillage.
    /// </summary>
    public const string Envoye = "ENVOYE";

    /// <summary>
    /// Le même contenu de lot a été rejoué sans divergence.
    /// </summary>
    public const string RejoueIdentique = "REJOUE_IDENTIQUE";

    /// <summary>
    /// Erreur technique renvoyée par l'API centrale.
    /// </summary>
    public const string TechnicalError = "TECHNICAL_ERROR";

    /// <summary>
    /// Erreur de validation renvoyée par l'API centrale.
    /// </summary>
    public const string ValidationError = "VALIDATION_ERROR";

    /// <summary>
    /// Conflit détecté lors du traitement du lot, valeur anglaise du contrat API.
    /// </summary>
    public const string Conflict = "CONFLICT";

    /// <summary>
    /// Conflit détecté lors du traitement du lot, valeur française utilisée localement.
    /// </summary>
    public const string Conflit = "CONFLIT";
}