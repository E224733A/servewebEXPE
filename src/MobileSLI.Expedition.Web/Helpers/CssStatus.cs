namespace MobileSLI.Expedition.Web.Helpers;

public static class CssStatus
{
    public static string ClassFor(string? status)
    {
        return status?.Trim().ToUpperInvariant() switch
        {
            "VERROUILLEE_BD" => "badge-locked",
            "VERROUILLE" => "badge-locked",
            "LECTURE_SEULE" => "badge-locked",
            "TRANSMISE_MOBILE" => "badge-success",
            "PRETE_VERROUILLAGE" => "badge-ready",
            "PRET_VERROUILLAGE" => "badge-ready",
            "VERROUILLAGE_EN_COURS" => "badge-ready",
            "EN_PREPARATION_WEB" => "badge-info",
            "BROUILLON" => "badge-info",
            "NON_PREPAREE" => "badge-neutral",
            "A_CORRIGER" => "badge-warning",
            "ERREUR_CHARGEMENT" => "badge-error",
            "ERREUR_VERROUILLAGE" => "badge-error",
            "ERREUR_ENVOI" => "badge-error",
            "SUCCESS" => "badge-success",
            "ENVOYE" => "badge-success",
            "ALREADY_PROCESSED" => "badge-success",
            "ALREADY_LOCKED" => "badge-success",
            "REJOUE_IDENTIQUE" => "badge-success",
            "TECHNICAL_ERROR" => "badge-error",
            "VALIDATION_ERROR" => "badge-error",
            "CONFLICT" => "badge-error",
            "CONFLIT" => "badge-error",
            _ => "badge-neutral"
        };
    }
}
