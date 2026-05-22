using System.Text.Json;
using System.Text.Json.Serialization;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Services;

// Test the JSON serialization to ensure the payload structure is correct

var request = new ExpeditionLockRequest
{
    SchemaVersion = "1.2",
    IdLotVerrouillage = "SERVEXPE-2026-05-25-2235-001",
    Source = "APPLICATION_WEB_EXPEDITION",
    DateTournee = new DateOnly(2026, 5, 25),
    DateVerrouillageDemandee = new DateTimeOffset(2026, 5, 24, 22, 35, 0, TimeSpan.FromHours(2)),
    FuseauHoraireMetier = "Europe/Paris",
    Tournees =
    [
        new TourneeLockDto
        {
            CodeTournee = "1001",
            LibelleTournee = "CHATAGNERAIE LES HERBIERS",
            StatutPreparationWeb = "PRETE_VERROUILLAGE",
            Lignes =
            [
                new LigneLockDto
                {
                    IdLigneSource = "identifiant-exact-du-get-api",
                    OrdreArret = 1,
                    Client = new ClientDto
                    {
                        NumClient = "1108",
                        NomClient = "HOTEL LA VERRIAIRE - LA VERRIE",
                        NomAffiche = "HOTEL LA VERRIAIRE - LA VERRIE"
                    },
                    PointLivraison = new PointLivraisonDto
                    {
                        CodePDL = "1664",
                        DescriptionPDL = "HOTEL LA VERRIAIRE - LA VERRIE"
                    },
                    CommentaireExceptionnel = null,
                    Quantites =
                    [
                        new QuantiteLockDto { CodeArticle = "ROLLS", LibelleArticle = "Rolls", QuantiteLivreePrevue = 4 },
                        new QuantiteLockDto { CodeArticle = "TAPIS", LibelleArticle = "Tapis", QuantiteLivreePrevue = null },
                        new QuantiteLockDto { CodeArticle = "SACS", LibelleArticle = "Sacs", QuantiteLivreePrevue = null }
                    ],
                    DerniereModification = new DerniereModificationDto
                    {
                        Date = new DateTimeOffset(2026, 5, 24, 22, 35, 0, TimeSpan.FromHours(2)),
                        Utilisateur = "APPLICATION_WEB_EXPEDITION"
                    }
                }
            ]
        }
    ]
};

var json = JsonSerializer.Serialize(request, JsonDefaults.Options);
Console.WriteLine("=== Payload JSON généré ===");
Console.WriteLine(json);

// Verify the structure
using (var doc = JsonDocument.Parse(json))
{
    var root = doc.RootElement;
    var checks = new (string path, string expected)[]
    {
        ("$.schemaVersion", "1.2"),
        ("$.source", "APPLICATION_WEB_EXPEDITION"),
        ("$.fuseauHoraireMetier", "Europe/Paris"),
        ("$.tournees[0].statutPreparationWeb", "PRETE_VERROUILLAGE"),
    };

    Console.WriteLine("\n=== Vérifications ===");
    foreach (var (path, expected) in checks)
    {
        var parts = path.TrimStart('$', '.').Split('.');
        var element = root;
        foreach (var part in parts)
        {
            if (part.Contains("["))
            {
                var bracketIndex = part.IndexOf('[');
                var propName = part[..bracketIndex];
                var index = int.Parse(part[(bracketIndex + 1)..].TrimEnd(']'));
                element = element.GetProperty(propName)[index];
            }
            else
            {
                element = element.GetProperty(part);
            }
        }
        var value = element.GetString();
        var status = value == expected ? "✅" : "❌";
        Console.WriteLine($"{status} {path}: {value} (attendu: {expected})");
    }
}
