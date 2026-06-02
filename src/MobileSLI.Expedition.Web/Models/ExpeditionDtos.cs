using System.Text.Json.Serialization;
using DomainDraftStatuses = MobileSLI.Expedition.Web.Domain.Constants.DraftStatuses;
using DomainFuseauxHoraires = MobileSLI.Expedition.Web.Domain.Constants.FuseauxHoraires;
using DomainLotStatuses = MobileSLI.Expedition.Web.Domain.Constants.LotStatuses;

namespace MobileSLI.Expedition.Web.Models;

public sealed class ExpeditionLoadResponse
{
    public string Statut { get; set; } = DomainLotStatuses.Success;

    public string SchemaVersion { get; set; } = "1.2";

    public DateOnly DateTournee { get; set; }

    public DateOnly DatePreparable { get; set; }

    public bool DateModifiable { get; set; }

    public string FuseauHoraireMetier { get; set; } = DomainFuseauxHoraires.EuropeParis;

    public DateTimeOffset DateGenerationApi { get; set; }

    [JsonPropertyName("articlesPreparables")]
    public List<ArticleSuiviDto> ArticlesSuivis { get; set; } = [];

    public List<TourneePreparationDto> Tournees { get; set; } = [];

    public ReglesPreparationDto Regles { get; set; } = new();
}

public sealed class ArticleSuiviDto
{
    public string CodeArticle { get; set; } = string.Empty;

    [JsonPropertyName("libelle")]
    public string LibelleArticle { get; set; } = string.Empty;

    public string TypeQuantite { get; set; } = "LIVREE_PREVUE";

    public bool QuantiteNullable { get; set; } = true;
}

public sealed class TourneePreparationDto
{
    public string CodeTournee { get; set; } = string.Empty;

    public string LibelleTournee { get; set; } = string.Empty;

    public string EtatPreparation { get; set; } = "NON_PREPAREE";

    public bool EstVerrouilleeBd { get; set; }

    public List<LignePreparationDto> Lignes { get; set; } = [];
}

public sealed class LignePreparationDto
{
    public string IdLigneSource { get; set; } = string.Empty;

    public int OrdreArret { get; set; }

    public ClientDto Client { get; set; } = new();

    public PointLivraisonDto PointLivraison { get; set; } = new();

    public InfosLectureDto InfosLecture { get; set; } = new();

    [JsonPropertyName("preparationInitiale")]
    public BrouillonInitialDto BrouillonInitial { get; set; } = new();
}

public sealed class ClientDto
{
    public string NumClient { get; set; } = string.Empty;

    public string NomClient { get; set; } = string.Empty;

    public string NomAffiche { get; set; } = string.Empty;
}

public sealed class PointLivraisonDto
{
    public string CodePDL { get; set; } = string.Empty;

    public string? DescriptionPDL { get; set; }

    public string? AdresseLigne1 { get; set; }

    public string? AdresseLigne2 { get; set; }

    public string? AdresseLigne3 { get; set; }

    public string? CodePostal { get; set; }

    public string? Ville { get; set; }
}

public sealed class InfosLectureDto
{
    public string? Instructions { get; set; }

    public bool FermetureClient { get; set; }

    public DateOnly? DateFermeture { get; set; }

    public string? MotifFermeture { get; set; }

    public string? ZoneDechargement { get; set; }
}

public sealed class BrouillonInitialDto
{
    public string? CommentaireExceptionnel { get; set; }

    [JsonPropertyName("quantitesPrevues")]
    public List<QuantiteInitialeDto> Quantites { get; set; } = [];
}

public sealed class QuantiteInitialeDto
{
    public string CodeArticle { get; set; } = string.Empty;

    [JsonPropertyName("libelle")]
    public string? LibelleArticle { get; set; }

    public int? QuantiteLivreePrevue { get; set; }
}

public sealed class ReglesPreparationDto
{
    public int QuantiteMin { get; set; } = 0;

    public bool QuantiteNullable { get; set; } = true;

    public bool ModificationApiPendantPreparation { get; set; } = false;

    public string VerrouillagePrevuVers { get; set; } = "22:35";
}

public sealed class ExpeditionLockRequest
{
    public string SchemaVersion { get; set; } = "1.2";

    public string IdLotVerrouillage { get; set; } = string.Empty;

    public string Source { get; set; } = "APPLICATION_WEB_EXPEDITION";

    public DateOnly DateTournee { get; set; }

    public DateTimeOffset DateVerrouillageDemandee { get; set; }

    public string FuseauHoraireMetier { get; set; } = DomainFuseauxHoraires.EuropeParis;

    public List<TourneeLockDto> Tournees { get; set; } = [];
}

public sealed class TourneeLockDto
{
    public string CodeTournee { get; set; } = string.Empty;

    public string LibelleTournee { get; set; } = string.Empty;

    public string StatutPreparationWeb { get; set; } = DomainDraftStatuses.PreteVerrouillage;

    /// <summary>
    /// Heure du dernier clic humain "Marquer prête pour verrouillage" côté SERVWEB.
    /// Cette date doit être conservée par l'API centrale dans Mobile_ExpeditionPreparation.DateModification.
    /// Elle est volontairement différente de DateVerrouillageDemandee, qui correspond au verrouillage automatique de nuit.
    /// </summary>
    public DateTimeOffset? DateModification { get; set; }

    public List<LigneLockDto> Lignes { get; set; } = [];
}

public sealed class LigneLockDto
{
    public string IdLigneSource { get; set; } = string.Empty;

    public int OrdreArret { get; set; }

    public ClientDto Client { get; set; } = new();

    public PointLivraisonDto PointLivraison { get; set; } = new();

    public string? CommentaireExceptionnel { get; set; }

    [JsonPropertyName("quantitesPrevues")]
    public List<QuantiteLockDto> Quantites { get; set; } = [];

    public DerniereModificationDto DerniereModification { get; set; } = new();
}

public sealed class QuantiteLockDto
{
    public string CodeArticle { get; set; } = string.Empty;

    [JsonPropertyName("libelle")]
    public string? LibelleArticle { get; set; }

    public int? QuantiteLivreePrevue { get; set; }
}

public sealed class DerniereModificationDto
{
    public DateTimeOffset Date { get; set; }

    public string Utilisateur { get; set; } = "APPLICATION_WEB_EXPEDITION";
}

public sealed class ExpeditionLockResponse
{
    public string Statut { get; set; } = DomainLotStatuses.Success;

    public string? Code { get; set; }

    public string? Message { get; set; }

    public string IdLotVerrouillage { get; set; } = string.Empty;

    public DateOnly DateTournee { get; set; }

    public string StatutVerrouillage { get; set; } = "VERROUILLEE_BD";

    public DateTimeOffset? DateReceptionApi { get; set; }

    public DateTimeOffset? DateSauvegardeSql { get; set; }

    public int NombreTourneesVerrouillees { get; set; }

    public int NombreLignesVerrouillees { get; set; }

    [JsonExtensionData]
    public Dictionary<string, object>? Extra { get; set; }
}
