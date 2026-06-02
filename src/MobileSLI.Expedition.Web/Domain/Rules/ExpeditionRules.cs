using System;
using System.Collections.Generic;
using MobileSLI.Expedition.Web.Domain.Constants;

namespace MobileSLI.Expedition.Web.Domain.Rules;

/// <summary>
/// Centralises simple business rules used by the Expedition feature.
/// </summary>
public static class ExpeditionRules
{
    /// <summary>
    /// Determines whether a draft status is considered ready for lock. A status is ready
    /// for lock when it equals <see cref="DraftStatuses.PretVerrouillage"/> or
    /// <see cref="DraftStatuses.PreteVerrouillage"/>, ignoring case and leading/trailing whitespace.
    /// </summary>
    /// <param name="status">The status string to evaluate.</param>
    /// <returns><c>true</c> if the status is ready for lock; otherwise <c>false</c>.</returns>
    public static bool IsReadyForLockStatus(string? status)
    {
        var normalized = status?.Trim().ToUpperInvariant();
        return normalized == DraftStatuses.PretVerrouillage || normalized == DraftStatuses.PreteVerrouillage;
    }

    /// <summary>
    /// Determines whether a draft status is considered in preparation. A status is in preparation
    /// when it equals <see cref="DraftStatuses.EnPreparationWeb"/> or <see cref="DraftStatuses.Brouillon"/>,
    /// ignoring case and leading/trailing whitespace.
    /// </summary>
    /// <param name="status">The status string to evaluate.</param>
    /// <returns><c>true</c> if the status indicates an in‑progress preparation; otherwise <c>false</c>.</returns>
    public static bool IsInPreparationStatus(string? status)
    {
        var normalized = status?.Trim().ToUpperInvariant();
        return normalized == DraftStatuses.EnPreparationWeb || normalized == DraftStatuses.Brouillon;
    }

    /// <summary>
    /// List of lot statuses that represent success outcomes. This set is used when evaluating
    /// responses from the central API. It is case‑insensitive.
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