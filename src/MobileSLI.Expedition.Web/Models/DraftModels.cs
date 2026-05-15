namespace MobileSLI.Expedition.Web.Models;

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

    public DateTimeOffset LastModifiedUtc { get; set; }

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

    public DateTimeOffset CreatedUtc { get; set; }

    public DateTimeOffset? ProcessedUtc { get; set; }
}

public sealed class SavePreparationLineDraft
{
    public string IdLigneSource { get; set; } = string.Empty;

    public string? CommentaireExceptionnel { get; set; }

    public Dictionary<string, int?> Quantites { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}
