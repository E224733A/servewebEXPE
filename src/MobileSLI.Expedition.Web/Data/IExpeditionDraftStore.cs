using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.Data;

/// <summary>
/// Contrat de persistance locale des chargements, brouillons et historiques de verrouillage SERVWEB.
/// L'implémentation actuelle est SQLite, mais les contrôleurs et services ne dépendent que de cette interface.
/// </summary>
public interface IExpeditionDraftStore
{
    /// <summary>
    /// Crée ou met à jour la structure locale nécessaire au stockage des brouillons.
    /// </summary>
    Task InitializeAsync(CancellationToken cancellationToken);

    /// <summary>
    /// Purge les anciennes données locales sans bloquer le fonctionnement métier si la purge échoue.
    /// </summary>
    Task CleanupOldDataAsync(CancellationToken cancellationToken);

    /// <summary>
    /// Sauvegarde le dernier lot API chargé pour servir de référentiel aux écrans Expédition et Administration.
    /// </summary>
    Task SaveLoadedDataAsync(ExpeditionLoadResponse response, CancellationToken cancellationToken);

    /// <summary>
    /// Retourne le dernier lot API chargé localement, ou null si aucun chargement n'a encore été effectué.
    /// </summary>
    Task<ExpeditionLoadResponse?> GetLastLoadedDataAsync(CancellationToken cancellationToken);

    /// <summary>
    /// Retourne l'état local d'une tournée précise pour une date métier.
    /// </summary>
    Task<TourneeDraftState?> GetTourneeStateAsync(DateOnly dateTournee, string codeTournee, CancellationToken cancellationToken);

    /// <summary>
    /// Retourne tous les états locaux de tournées pour une date métier.
    /// </summary>
    Task<IReadOnlyDictionary<string, TourneeDraftState>> GetTourneeStatesAsync(DateOnly dateTournee, CancellationToken cancellationToken);

    /// <summary>
    /// Retourne les brouillons locaux de lignes d'une tournée, en fusionnant quantités Expédition et commentaires Administration.
    /// </summary>
    Task<IReadOnlyDictionary<string, LineDraftState>> GetLineStatesAsync(DateOnly dateTournee, string codeTournee, CancellationToken cancellationToken);

    /// <summary>
    /// Sauvegarde les quantités prévues saisies côté Expédition et met à jour le statut local de la tournée.
    /// </summary>
    Task SavePreparationAsync(
        DateOnly dateTournee,
        string codeTournee,
        IReadOnlyList<SavePreparationLineDraft> lignes,
        string status,
        string? modifiedBy,
        CancellationToken cancellationToken,
        bool enregistrerClicPretVerrouillage = false);

    /// <summary>
    /// Sauvegarde le commentaire exceptionnel saisi côté Administration pour une ligne.
    /// </summary>
    Task SaveAdminCommentaireAsync(DateOnly dateTournee, string codeTournee, SaveAdminCommentaireDraft commentaire, string? modifiedBy, CancellationToken cancellationToken);

    /// <summary>
    /// Construit le lot JSON prêt à être envoyé à l'API centrale lors du verrouillage automatique.
    /// </summary>
    Task<PreparedLockLot?> BuildLockLotAsync(DateTimeOffset requestedAtLocal, string lotSequence, CancellationToken cancellationToken);

    /// <summary>
    /// Vérifie que toutes les tournées demandées sont déjà verrouillées avec succès côté stockage local.
    /// </summary>
    Task<bool> HasSuccessfulLockAsync(DateOnly dateTournee, IReadOnlyCollection<string> codeTournees, CancellationToken cancellationToken);

    /// <summary>
    /// Marque un verrouillage comme réussi et rend les tournées concernées non modifiables.
    /// </summary>
    Task MarkLockSuccessAsync(ExpeditionLockResponse response, string payloadHash, IReadOnlyCollection<string> codeTourneesVerrouillees, CancellationToken cancellationToken);

    /// <summary>
    /// Trace l'échec d'un verrouillage pour diagnostic et relance éventuelle.
    /// </summary>
    Task MarkLockFailureAsync(string idLotVerrouillage, DateOnly dateTournee, string status, string message, string payloadHash, CancellationToken cancellationToken);

    /// <summary>
    /// Retourne les derniers verrouillages affichés sur les écrans de suivi.
    /// </summary>
    Task<IReadOnlyList<LockHistoryItem>> GetRecentLockHistoryAsync(int limit, CancellationToken cancellationToken);

    /// <summary>
    /// Produit un résumé de supervision pour vérifier le chargement, les modifications et la tâche planifiée.
    /// </summary>
    Task<PreparationStatusSnapshot> GetStatusSnapshotAsync(DateTimeOffset? expectedLockAtLocal, CancellationToken cancellationToken);
}