using DomainDraftStatuses = MobileSLI.Expedition.Web.Domain.Constants.DraftStatuses;
using DomainLotStatuses = MobileSLI.Expedition.Web.Domain.Constants.LotStatuses;

namespace MobileSLI.Expedition.Web.Helpers;

/// <summary>
/// Utility for computing CSS classes based on status values. Instead of repeating literal
/// strings in multiple places, the status values used here reference the centralized
/// constants defined in the <see cref="DraftStatuses"/> and <see cref="LotStatuses"/> classes.
/// Unknown or unhandled statuses fall back to the neutral badge.
/// </summary>
public static class CssStatus
{
    public static string ClassFor(string? status)
    {
        return status?.Trim().ToUpperInvariant() switch
        {
            // Locked statuses coming from the database or API that do not have a constant remain as literals.
            "VERROUILLEE_BD" => "badge-locked",
            DomainDraftStatuses.Verrouille => "badge-locked",
            "LECTURE_SEULE" => "badge-locked",
            "TRANSMISE_MOBILE" => "badge-success",
            // Ready for lock statuses
            DomainDraftStatuses.PreteVerrouillage => "badge-ready",
            DomainDraftStatuses.PretVerrouillage => "badge-ready",
            DomainDraftStatuses.VerrouillageEnCours => "badge-ready",
            // In preparation statuses
            DomainDraftStatuses.EnPreparationWeb => "badge-info",
            DomainDraftStatuses.Brouillon => "badge-info",
            "NON_PREPAREE" => "badge-neutral",
            "A_CORRIGER" => "badge-warning",
            // Error statuses specific to the administration process
            "ERREUR_CHARGEMENT" => "badge-error",
            "ERREUR_VERROUILLAGE" => "badge-error",
            DomainDraftStatuses.ErreurEnvoi => "badge-error",
            // Lot status successes
            DomainLotStatuses.Success => "badge-success",
            DomainLotStatuses.Envoye => "badge-success",
            DomainLotStatuses.AlreadyProcessed => "badge-success",
            DomainLotStatuses.AlreadyLocked => "badge-success",
            DomainLotStatuses.RejoueIdentique => "badge-success",
            // Lot status errors
            DomainLotStatuses.TechnicalError => "badge-error",
            DomainLotStatuses.ValidationError => "badge-error",
            DomainLotStatuses.Conflict => "badge-error",
            DomainLotStatuses.Conflit => "badge-error",
            // Default neutral badge for any other status
            _ => "badge-neutral"
        };
    }
}