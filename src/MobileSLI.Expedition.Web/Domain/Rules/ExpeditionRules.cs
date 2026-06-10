using System;
using System.Collections.Generic;
using MobileSLI.Expedition.Web.Domain.Constants;

namespace MobileSLI.Expedition.Web.Domain.Rules;

/// <summary>
/// Règles métier simples partagées par plusieurs couches Expédition.
/// Cette classe évite de dupliquer les comparaisons de statuts dans les contrôleurs, builders et services.
/// </summary>
public static class ExpeditionRules
{
    /// <summary>
    /// Détermine si un statut de brouillon rend une tournée éligible au verrouillage automatique.
    /// Les deux variantes PRET_VERROUILLAGE et PRETE_VERROUILLAGE sont acceptées pour compatibilité.
    /// </summary>
    /// <param name="status">Statut à évaluer.</param>
    /// <returns><c>true</c> si le statut indique une tournée prête pour verrouillage ; sinon <c>false</c>.</returns>
    public static bool IsReadyForLockStatus(string? status)
    {
        var normalized = status?.Trim().ToUpperInvariant();
        return normalized == DraftStatuses.PretVerrouillage || normalized == DraftStatuses.PreteVerrouillage;
    }

    /// <summary>
    /// Détermine si un statut correspond à une préparation encore modifiable côté web.
    /// </summary>
    /// <param name="status">Statut à évaluer.</param>
    /// <returns><c>true</c> si le statut correspond à une préparation en cours ; sinon <c>false</c>.</returns>
    public static bool IsInPreparationStatus(string? status)
    {
        var normalized = status?.Trim().ToUpperInvariant();
        return normalized == DraftStatuses.EnPreparationWeb || normalized == DraftStatuses.Brouillon;
    }

    /// <summary>
    /// Statuts de lot considérés comme des succès fonctionnels lors de l'interprétation de la réponse API.
    /// Les rejoues et états déjà traités sont inclus pour supporter l'idempotence du verrouillage.
    /// </summary>
    public static readonly ISet<string> SuccessLotStatuses = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
    {
        LotStatuses.Success,
        LotStatuses.Envoye,
        LotStatuses.AlreadyProcessed,
        LotStatuses.AlreadyLocked,
        LotStatuses.RejoueIdentique
    };
}