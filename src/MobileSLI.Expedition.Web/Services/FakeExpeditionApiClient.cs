using MobileSLI.Expedition.Web.Models;

namespace MobileSLI.Expedition.Web.Services;

public sealed class FakeExpeditionApiClient : IExpeditionApiClient
{
    private readonly ILogger<FakeExpeditionApiClient> _logger;

    public FakeExpeditionApiClient(ILogger<FakeExpeditionApiClient> logger)
    {
        _logger = logger;
    }

    public Task<ExpeditionLoadResponse> GetPreparationsAsync(CancellationToken cancellationToken)
    {
        var paris = GetParisTimeZone();
        var nowParis = TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, paris);
        var dateTournee = DateOnly.FromDateTime(nowParis.Date.AddDays(1));

        var response = new ExpeditionLoadResponse
        {
            Statut = "SUCCESS",
            SchemaVersion = "1.0",
            DateTournee = dateTournee,
            DatePreparable = dateTournee,
            DateModifiable = false,
            FuseauHoraireMetier = "Europe/Paris",
            DateGenerationApi = nowParis,
            ArticlesSuivis =
            [
                new ArticleSuiviDto { CodeArticle = "ROLLS", LibelleArticle = "Rolls", TypeQuantite = "LIVREE_PREVUE" },
                new ArticleSuiviDto { CodeArticle = "TAPIS", LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
                new ArticleSuiviDto { CodeArticle = "SACS", LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
            ],
            Tournees =
            [
                BuildTournee(dateTournee, "4006", "Tournée 4006", "CLIENT TEST", "12345", "PDL01", 10),
                BuildTournee(dateTournee, "4007", "Tournée 4007", "CLINIQUE EXEMPLE", "67890", "PDL02", 20)
            ],
            Regles = new ReglesPreparationDto
            {
                QuantiteMin = 0,
                QuantiteNullable = true,
                ModificationApiPendantPreparation = false,
                VerrouillagePrevuVers = "00:05"
            }
        };

        _logger.LogInformation("Mode fake : chargement Expédition généré pour la date {DateTournee}", dateTournee);
        return Task.FromResult(response);
    }

    public Task<ExpeditionLockResponse> VerrouillerAsync(ExpeditionLockRequest request, CancellationToken cancellationToken)
    {
        var lignes = request.Tournees.Sum(t => t.Lignes.Count);
        var response = new ExpeditionLockResponse
        {
            Statut = "SUCCESS",
            Message = "Mode fake : préparations Expédition sauvegardées et verrouillées avec succès.",
            IdLotVerrouillage = request.IdLotVerrouillage,
            DateTournee = request.DateTournee,
            StatutVerrouillage = "VERROUILLEE_BD",
            DateReceptionApi = DateTimeOffset.UtcNow,
            DateSauvegardeSql = DateTimeOffset.UtcNow,
            NombreTourneesVerrouillees = request.Tournees.Count,
            NombreLignesVerrouillees = lignes
        };

        _logger.LogInformation("Mode fake : verrouillage accepté pour le lot {IdLot}", request.IdLotVerrouillage);
        return Task.FromResult(response);
    }

    private static TourneePreparationDto BuildTournee(DateOnly dateTournee, string codeTournee, string libelleTournee, string nomClient, string numClient, string codePdl, int ordre)
    {
        return new TourneePreparationDto
        {
            CodeTournee = codeTournee,
            LibelleTournee = libelleTournee,
            EtatPreparation = "NON_PREPAREE",
            EstVerrouilleeBd = false,
            Lignes =
            [
                new LignePreparationDto
                {
                    IdLigneSource = $"{dateTournee:yyyy-MM-dd}|{codeTournee}|{numClient}|{codePdl}|{ordre}",
                    OrdreArret = ordre,
                    Client = new ClientDto
                    {
                        NumClient = numClient,
                        NomClient = nomClient,
                        NomAffiche = nomClient
                    },
                    PointLivraison = new PointLivraisonDto
                    {
                        CodePDL = codePdl,
                        DescriptionPDL = "Accueil principal",
                        AdresseLigne1 = "1 rue Exemple",
                        CodePostal = "44000",
                        Ville = "Nantes"
                    },
                    InfosLecture = new InfosLectureDto
                    {
                        Instructions = "Livraison par l'arrière.",
                        FermetureClient = false,
                        ZoneDechargement = "Zone A"
                    },
                    BrouillonInitial = new BrouillonInitialDto
                    {
                        CommentaireExceptionnel = null,
                        Quantites =
                        [
                            new QuantiteInitialeDto { CodeArticle = "ROLLS", QuantiteLivreePrevue = null },
                            new QuantiteInitialeDto { CodeArticle = "TAPIS", QuantiteLivreePrevue = null },
                            new QuantiteInitialeDto { CodeArticle = "SACS", QuantiteLivreePrevue = null }
                        ]
                    }
                },
                new LignePreparationDto
                {
                    IdLigneSource = $"{dateTournee:yyyy-MM-dd}|{codeTournee}|{numClient}|{codePdl}-B|{ordre + 1}",
                    OrdreArret = ordre + 1,
                    Client = new ClientDto
                    {
                        NumClient = numClient,
                        NomClient = nomClient,
                        NomAffiche = nomClient
                    },
                    PointLivraison = new PointLivraisonDto
                    {
                        CodePDL = $"{codePdl}-B",
                        DescriptionPDL = "Service lingerie",
                        AdresseLigne1 = "1 rue Exemple",
                        CodePostal = "44000",
                        Ville = "Nantes"
                    },
                    InfosLecture = new InfosLectureDto
                    {
                        Instructions = "Déposer uniquement au local linge propre.",
                        FermetureClient = false,
                        ZoneDechargement = "Zone B"
                    },
                    BrouillonInitial = new BrouillonInitialDto
                    {
                        CommentaireExceptionnel = null,
                        Quantites =
                        [
                            new QuantiteInitialeDto { CodeArticle = "ROLLS", QuantiteLivreePrevue = null },
                            new QuantiteInitialeDto { CodeArticle = "TAPIS", QuantiteLivreePrevue = null },
                            new QuantiteInitialeDto { CodeArticle = "SACS", QuantiteLivreePrevue = null }
                        ]
                    }
                }
            ]
        };
    }

    private static TimeZoneInfo GetParisTimeZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Europe/Paris");
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Romance Standard Time");
        }
    }
}
