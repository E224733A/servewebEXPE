namespace MobileSLI.Expedition.Web.Helpers;

public static class CssStatus
{
    public static string ClassFor(string? status)
    {
        return status?.ToUpperInvariant() switch
        {
            "VERROUILLEE_BD" => "badge-locked",
            "TRANSMISE_MOBILE" => "badge-success",
            "PRETE_VERROUILLAGE" => "badge-ready",
            "VERROUILLAGE_EN_COURS" => "badge-ready",
            "EN_PREPARATION_WEB" => "badge-info",
            "A_CORRIGER" => "badge-warning",
            "ERREUR_CHARGEMENT" => "badge-error",
            "ERREUR_VERROUILLAGE" => "badge-error",
            "SUCCESS" => "badge-success",
            "ALREADY_PROCESSED" => "badge-success",
            "ALREADY_LOCKED" => "badge-success",
            "TECHNICAL_ERROR" => "badge-error",
            "VALIDATION_ERROR" => "badge-error",
            "CONFLICT" => "badge-error",
            _ => "badge-neutral"
        };
    }
}
