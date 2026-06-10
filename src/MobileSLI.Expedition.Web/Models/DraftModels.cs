namespace MobileSLI.Expedition.Web.Models;

/// <summary>
/// Anciens statuts locaux de brouillon conservés pour compatibilité avec les parties du code qui utilisent encore ce modèle.
/// Les constantes métier de référence sont maintenant centralisées dans le namespace Domain.Constants.
/// </summary>
public static class DraftStatuses
{
    public const string Brouillon = "BROUILLON";
    public const string PretVerrouillage = "PRET_VERROUILLAGE";
    public const string VerrouillageEnCours = "VERROUILLAGE_EN_COURS";
    public const string Verrouille = "VERROUILLE";
    public const string ErreurEnvoi = "ERREUR_ENVOI";
}

/// <summary>
/// Statuts locaux d'historique de lot utilisés pour suivre les envois de verrouillage vers l'API.
/// </summary>
public static class LotStatuses
{
    public const string Cree = "CREE";
    public const string VerrouillageEnCours = "VERROUILLAGE_EN_COURS";
    public const string Envoye = "ENVOYE";
    public const string RejoueIdentique = "REJOUE_IDENTIQUE";
    public const string ErreurEnvoi = "ERREUR_ENVOI";
    public const string Conflit = "CONFLIT";
}

/// <summary>
/// État local d'une tournée dans SQLite : brouillon, prête, verrouillée ou en erreur.
/// </summary>
public sealed class TourneeDraftState
{
    public DateOnly DateTournee { get; set; }

    public string CodeTournee { get; set; } = string.Empty;

    public string Status { get; set; } = "NON_PREPAREE";

    public bool IsLocked { get; set; }

    public DateTimeOffset LastModifiedUtc { get; set; }
}

/// <summary>
/// État local d'une ligne de tournée, fusionnant quantités Expédition et commentaire Administration.
/// </summary>
public sealed class LineDraftState
{
    public DateOnly DateTournee { get; set; }

    public string CodeTournee { get; set; } = string.Empty;

    public string IdLigneSource { get; set; } = string.Empty;

    public string? CommentaireExceptionnel { get; set; }

    public bool IsLocked { get; set; }

    public DateTimeOffset? LastModifiedUtc { get; set; }

    public DateTimeOffset? LastModifiedCommentaireUtc { get; set; }

    public DateTimeOffset? LastModifiedQuantiteUtc { get; set; }

    public Dictionary<string, int?> Quantites { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}

/// <summary>
/// Lot prêt à être envoyé à l'API avec son empreinte pour gérer l'idempotence et les rejoues.
/// </summary>
public sealed class PreparedLockLot
{
    public ExpeditionLockRequest Request { get; set; } = new();

    public string PayloadHash { get; set; } = string.Empty;
}

/// <summary>
/// Ligne d'historique locale d'une tentative de verrouillage.
/// </summary>
public sealed class LockHistoryItem
{
    public string IdLotVerrouillage { get; set; } = string.Empty;

    public DateOnly DateTournee { get; set; }

    public string Status { get; set; } = string.Empty;

    public string? ApiMessage { get; set; }

    public string PayloadHash { get; set; } = string.Empty;

    public DateTimeOffset CreatedUtc { get; set; }

    public DateTimeOffset? ProcessedUtc { get; set; }
}

/// <summary>
/// Brouillon de quantités à sauvegarder pour une ligne Expédition.
/// </summary>
public sealed class SavePreparationLineDraft
{
    public string IdLigneSource { get; set; } = string.Empty;

    public Dictionary<string, int?> Quantites { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}

/// <summary>
/// Brouillon de commentaire à sauvegarder pour une ligne Administration.
/// </summary>
public sealed class SaveAdminCommentaireDraft
{
    public string IdLigneSource { get; set; } = string.Empty;

    public string? CommentaireExceptionnel { get; set; }
}

/// <summary>
/// Snapshot de supervision affichant l'état du chargement, des brouillons et du verrouillage planifié.
/// </summary>
public sealed class PreparationStatusSnapshot
{
    public DateOnly? DateTournee { get; set; }

    public DateTimeOffset? DernierChargementApi { get; set; }

    public int NombreTourneesChargees { get; set; }

    public int NombreQuantitesModifiees { get; set; }

    public int NombreCommentairesModifies { get; set; }

    public string? StatutDernierVerrouillage { get; set; }

    public string? MessageRetourApi { get; set; }

    public DateTimeOffset? DateDerniereTentative { get; set; }

    public string TacheWindowsNom { get; set; } = "MobileSLI SERVEXPE Verrouillage 22h35";

    public DateTimeOffset? TacheWindowsDerniereExecution { get; set; }

    public int? TacheWindowsDernierCodeRetour { get; set; }

    public DateTimeOffset? VerrouillageAttenduA { get; set; }

    public bool VerrouillageEnRetard { get; set; }
}

/// <summary>
/// Dernier signal écrit par le script ou la tâche Windows de verrouillage.
/// </summary>
public sealed class LockTaskHeartbeat
{
    public DateTimeOffset? Date { get; set; }

    public int? CodeRetour { get; set; }

    public string? Message { get; set; }
}