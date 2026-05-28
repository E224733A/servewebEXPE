DECLARE @DateTournee date = '2026-05-29';

SELECT
    lot.IdLotVerrouillage,
    lot.DateTournee,
    lot.CodeTournee AS CodeTourneeLot,
    lot.StatutLot,

    CONVERT(datetimeoffset(0), lot.DateReceptionApi AT TIME ZONE 'Romance Standard Time') AS HeureReceptionApiParis,
    CONVERT(datetimeoffset(0), lot.DateSauvegardeSql AT TIME ZONE 'Romance Standard Time') AS HeureSauvegardeApiParis,
    CONVERT(datetimeoffset(0), lot.DateModification AT TIME ZONE 'Romance Standard Time') AS DateModificationLotParis,

    p.CodeTournee,
    p.LibelleTournee,
    p.StatutPreparation,

    CONVERT(datetimeoffset(0), p.DateVerrouillage AT TIME ZONE 'Romance Standard Time') AS HeureVerrouillageTechniqueApiParis,
    CONVERT(datetimeoffset(0), p.DateModification AT TIME ZONE 'Romance Standard Time') AS HeureClicPretVerrouillageParis,

    DATEDIFF(SECOND, p.DateModification, lot.DateReceptionApi) AS SecondesEntreClicEtVerrouillage,

    CASE
        WHEN p.DateModification IS NULL
            THEN N'ERREUR - aucune heure de clic prête pour verrouillage enregistrée'
        WHEN p.DateModification > lot.DateReceptionApi
            THEN N'ERREUR - l’heure du clic est après la réception API'
        ELSE N'OK - l’heure de verrouillage sert à identifier la dernière personne qui a verrouillé'
    END AS Diagnostic
FROM dbo.Mobile_ExpeditionLotVerrouillage lot
INNER JOIN dbo.Mobile_ExpeditionPreparation p
    ON p.IdLotVerrouillage = lot.IdLotVerrouillage
WHERE lot.DateTournee = @DateTournee
  AND lot.CodeTournee = N'GLOBAL'
ORDER BY
    lot.DateReceptionApi DESC,
    p.CodeTournee;