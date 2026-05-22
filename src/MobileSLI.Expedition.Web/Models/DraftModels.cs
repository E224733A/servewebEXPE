namespace MobileSLI.Expedition.Web.Models;

public static class DraftStatuses
{
    public const string Brouillon = "BROUILLON";
    public const string PretVerrouillage = "PRET_VERROUILLAGE";
    public const string VerrouillageEnCours = "VERROUILLAGE_EN_COURS";
    public const string Verrouille = "VERROUILLE";
    public const string ErreurEnvoi = "ERREUR_ENVOI";
}

public static class LotStatuses
{
    public const string Cree = "CREE";
    public const string VerrouillageEnCours = "VERROUILLAGE_EN_COURS";
    public const string Envoye = "ENVOYE";
    public const string RejoueIdentique = "REJOUE_IDENTIQUE";
    public const string ErreurEnvoi = "ERREUR_ENVOI";
    public const string Conflit = "CONFLIT";
}

public sealed class TourneeDraftState
{
    public DateOnly DateTournee { get; set; }

    public string CodeTournee { get; set; } = string.Empty;

    public string Status { get; set; } = "NON_PREPAREE";

    public bool IsLocked { get; set; }

    public DateTimeOffset LastModifiedUtc { get; set; }
}

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

public sealed class PreparedLockLot
{
    public ExpeditionLockRequest Request { get; set; } = new();

    public string PayloadHash { get; set; } = string.Empty;
}

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

public sealed class SavePreparationLineDraft
{
    public string IdLigneSource { get; set; } = string.Empty;

    public Dictionary<string, int?> Quantites { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}

public sealed class SaveAdminCommentaireDraft
{
    public string IdLigneSource { get; set; } = string.Empty;

    public string? CommentaireExceptionnel { get; set; }
}

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

public sealed class LockTaskHeartbeat
{
    public DateTimeOffset? Date { get; set; }

    public int? CodeRetour { get; set; }

    public string? Message { get; set; }
}
