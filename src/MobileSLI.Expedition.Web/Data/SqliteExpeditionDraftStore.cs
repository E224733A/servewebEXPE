using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.Sqlite;
using Microsoft.Extensions.Options;
using MobileSLI.Expedition.Web.Models;
using MobileSLI.Expedition.Web.Options;
using MobileSLI.Expedition.Web.Services;

namespace MobileSLI.Expedition.Web.Data;

/// <summary>
/// Stockage brouillon SQLite côté backend web Expédition.
///
/// Rôle du store :
/// - conserver le dernier chargement reçu depuis l'API centrale ;
/// - conserver les brouillons locaux de préparation ;
/// - conserver les quantités prévues ROLLS / TAPIS / SACS ;
/// - construire le lot de verrouillage à envoyer à l'API centrale ;
/// - conserver l'historique technique des tentatives de verrouillage.
///
/// Important :
/// Le store ne modifie pas SQL Server directement. Le verrouillage réel reste fait par l'API centrale.
/// </summary>
public sealed class SqliteExpeditionDraftStore : IExpeditionDraftStore
{
    private const string StatusReadyForLock = "PRETE_VERROUILLAGE";
    private const string StatusLockedBd = "VERROUILLEE_BD";

    private readonly ExpeditionDbOptions _options;
    private readonly ILogger<SqliteExpeditionDraftStore> _logger;

    public SqliteExpeditionDraftStore(IOptions<ExpeditionDbOptions> options, ILogger<SqliteExpeditionDraftStore> logger)
    {
        _options = options.Value;
        _logger = logger;
    }

    public async Task InitializeAsync(CancellationToken cancellationToken)
    {
        EnsureDatabaseDirectoryExists();

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await ExecuteAsync(connection, "PRAGMA foreign_keys = ON;", cancellationToken);
        await ExecuteAsync(connection, "PRAGMA journal_mode = WAL;", cancellationToken);

        await ExecuteAsync(connection, """
            CREATE TABLE IF NOT EXISTS Expedition_LoadedData (
                Id INTEGER PRIMARY KEY AUTOINCREMENT,
                DateTournee TEXT NOT NULL,
                LoadedAtUtc TEXT NOT NULL,
                PayloadJson TEXT NOT NULL
            );
            """, cancellationToken);

        await ExecuteAsync(connection, """
            CREATE INDEX IF NOT EXISTS IX_Expedition_LoadedData_DateTournee
            ON Expedition_LoadedData(DateTournee);
            """, cancellationToken);

        await ExecuteAsync(connection, """
            CREATE TABLE IF NOT EXISTS Expedition_TourneeState (
                DateTournee TEXT NOT NULL,
                CodeTournee TEXT NOT NULL,
                Status TEXT NOT NULL,
                IsLocked INTEGER NOT NULL DEFAULT 0,
                LastModifiedUtc TEXT NOT NULL,
                LastModifiedByIp TEXT NULL,
                PRIMARY KEY (DateTournee, CodeTournee)
            );
            """, cancellationToken);

        await ExecuteAsync(connection, """
            CREATE TABLE IF NOT EXISTS Expedition_LineDraft (
                DateTournee TEXT NOT NULL,
                CodeTournee TEXT NOT NULL,
                IdLigneSource TEXT NOT NULL,
                CommentaireExceptionnel TEXT NULL,
                IsLocked INTEGER NOT NULL DEFAULT 0,
                LastModifiedUtc TEXT NOT NULL,
                LastModifiedByIp TEXT NULL,
                PRIMARY KEY (DateTournee, CodeTournee, IdLigneSource)
            );
            """, cancellationToken);

        await ExecuteAsync(connection, """
            CREATE TABLE IF NOT EXISTS Expedition_LineQuantity (
                DateTournee TEXT NOT NULL,
                CodeTournee TEXT NOT NULL,
                IdLigneSource TEXT NOT NULL,
                CodeArticle TEXT NOT NULL,
                QuantiteLivreePrevue INTEGER NULL,
                LastModifiedUtc TEXT NOT NULL,
                LastModifiedByIp TEXT NULL,
                PRIMARY KEY (DateTournee, CodeTournee, IdLigneSource, CodeArticle),
                FOREIGN KEY (DateTournee, CodeTournee, IdLigneSource)
                    REFERENCES Expedition_LineDraft(DateTournee, CodeTournee, IdLigneSource)
                    ON DELETE CASCADE
            );
            """, cancellationToken);

        await ExecuteAsync(connection, """
            CREATE INDEX IF NOT EXISTS IX_Expedition_LineQuantity_Ligne
            ON Expedition_LineQuantity(DateTournee, CodeTournee, IdLigneSource);
            """, cancellationToken);

        await ExecuteAsync(connection, """
            CREATE TABLE IF NOT EXISTS Expedition_LockHistory (
                IdLotVerrouillage TEXT PRIMARY KEY,
                DateTournee TEXT NOT NULL,
                Status TEXT NOT NULL,
                ApiMessage TEXT NULL,
                PayloadHash TEXT NOT NULL,
                CreatedUtc TEXT NOT NULL,
                ProcessedUtc TEXT NULL
            );
            """, cancellationToken);

        await ExecuteAsync(connection, """
            CREATE INDEX IF NOT EXISTS IX_Expedition_LockHistory_CreatedUtc
            ON Expedition_LockHistory(CreatedUtc DESC);
            """, cancellationToken);

        await ExecuteAsync(connection, """
            CREATE INDEX IF NOT EXISTS IX_Expedition_LockHistory_DateTournee_Status
            ON Expedition_LockHistory(DateTournee, Status);
            """, cancellationToken);

        _logger.LogInformation("Stockage SQLite Expédition initialisé : {DatabasePath}", GetDatabasePath());
    }

    public async Task SaveLoadedDataAsync(ExpeditionLoadResponse response, CancellationToken cancellationToken)
    {
        EnsureDatabaseDirectoryExists();

        var now = DateTimeOffset.UtcNow;
        var payloadJson = JsonSerializer.Serialize(response, JsonDefaults.Options);

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await ExecuteAsync(connection, transaction, """
            INSERT INTO Expedition_LoadedData(DateTournee, LoadedAtUtc, PayloadJson)
            VALUES ($dateTournee, $loadedAtUtc, $payloadJson);
            """,
            cancellationToken,
            ("$dateTournee", ToDbDate(response.DateTournee)),
            ("$loadedAtUtc", ToDbDateTime(now)),
            ("$payloadJson", payloadJson));

        foreach (var tournee in response.Tournees)
        {
            var initialStatus = string.IsNullOrWhiteSpace(tournee.EtatPreparation)
                ? "NON_PREPAREE"
                : tournee.EtatPreparation;

            await ExecuteAsync(connection, transaction, """
                INSERT INTO Expedition_TourneeState(DateTournee, CodeTournee, Status, IsLocked, LastModifiedUtc, LastModifiedByIp)
                VALUES ($dateTournee, $codeTournee, $status, $isLocked, $lastModifiedUtc, NULL)
                ON CONFLICT(DateTournee, CodeTournee) DO UPDATE SET
                    Status = CASE
                        WHEN Expedition_TourneeState.IsLocked = 1 THEN Expedition_TourneeState.Status
                        WHEN Expedition_TourneeState.Status IN ('EN_PREPARATION_WEB', 'PRETE_VERROUILLAGE') THEN Expedition_TourneeState.Status
                        ELSE excluded.Status
                    END,
                    IsLocked = CASE
                        WHEN Expedition_TourneeState.IsLocked = 1 THEN 1
                        ELSE excluded.IsLocked
                    END,
                    LastModifiedUtc = CASE
                        WHEN Expedition_TourneeState.Status IN ('EN_PREPARATION_WEB', 'PRETE_VERROUILLAGE') THEN Expedition_TourneeState.LastModifiedUtc
                        ELSE excluded.LastModifiedUtc
                    END;
                """,
                cancellationToken,
                ("$dateTournee", ToDbDate(response.DateTournee)),
                ("$codeTournee", tournee.CodeTournee),
                ("$status", initialStatus),
                ("$isLocked", tournee.EstVerrouilleeBd ? 1 : 0),
                ("$lastModifiedUtc", ToDbDateTime(now)));
        }

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<ExpeditionLoadResponse?> GetLastLoadedDataAsync(CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT PayloadJson
            FROM Expedition_LoadedData
            ORDER BY Id DESC
            LIMIT 1;
            """;

        var payload = await command.ExecuteScalarAsync(cancellationToken);

        if (payload is null || payload == DBNull.Value)
        {
            return null;
        }

        return JsonSerializer.Deserialize<ExpeditionLoadResponse>((string)payload, JsonDefaults.Options);
    }

    public async Task<IReadOnlyDictionary<string, TourneeDraftState>> GetTourneeStatesAsync(DateOnly dateTournee, CancellationToken cancellationToken)
    {
        var result = new Dictionary<string, TourneeDraftState>(StringComparer.OrdinalIgnoreCase);

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT DateTournee, CodeTournee, Status, IsLocked, LastModifiedUtc
            FROM Expedition_TourneeState
            WHERE DateTournee = $dateTournee;
            """;
        command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            var state = ReadTourneeDraftState(reader);
            result[state.CodeTournee] = state;
        }

        return result;
    }

    public async Task<TourneeDraftState?> GetTourneeStateAsync(DateOnly dateTournee, string codeTournee, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT DateTournee, CodeTournee, Status, IsLocked, LastModifiedUtc
            FROM Expedition_TourneeState
            WHERE DateTournee = $dateTournee
              AND CodeTournee = $codeTournee
            LIMIT 1;
            """;
        command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));
        command.Parameters.AddWithValue("$codeTournee", codeTournee);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        return ReadTourneeDraftState(reader);
    }

    public async Task<IReadOnlyDictionary<string, LineDraftState>> GetLineStatesAsync(DateOnly dateTournee, string codeTournee, CancellationToken cancellationToken)
    {
        var result = new Dictionary<string, LineDraftState>(StringComparer.OrdinalIgnoreCase);

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT DateTournee, CodeTournee, IdLigneSource, CommentaireExceptionnel, IsLocked, LastModifiedUtc
                FROM Expedition_LineDraft
                WHERE DateTournee = $dateTournee
                  AND CodeTournee = $codeTournee;
                """;
            command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));
            command.Parameters.AddWithValue("$codeTournee", codeTournee);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            while (await reader.ReadAsync(cancellationToken))
            {
                var line = new LineDraftState
                {
                    DateTournee = DateOnly.Parse(reader.GetString(0)),
                    CodeTournee = reader.GetString(1),
                    IdLigneSource = reader.GetString(2),
                    CommentaireExceptionnel = reader.IsDBNull(3) ? null : reader.GetString(3),
                    IsLocked = reader.GetInt32(4) == 1,
                    LastModifiedUtc = DateTimeOffset.Parse(reader.GetString(5)),
                    Quantites = new Dictionary<string, int?>(StringComparer.OrdinalIgnoreCase)
                };

                result[line.IdLigneSource] = line;
            }
        }

        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT IdLigneSource, CodeArticle, QuantiteLivreePrevue
                FROM Expedition_LineQuantity
                WHERE DateTournee = $dateTournee
                  AND CodeTournee = $codeTournee;
                """;
            command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));
            command.Parameters.AddWithValue("$codeTournee", codeTournee);

            await using var reader = await command.ExecuteReaderAsync(cancellationToken);

            while (await reader.ReadAsync(cancellationToken))
            {
                var idLigneSource = reader.GetString(0);
                var codeArticle = reader.GetString(1);
                int? quantite = reader.IsDBNull(2) ? null : reader.GetInt32(2);

                if (result.TryGetValue(idLigneSource, out var line))
                {
                    line.Quantites[codeArticle] = quantite;
                }
            }
        }

        return result;
    }

    public async Task SavePreparationAsync(
        DateOnly dateTournee,
        string codeTournee,
        IReadOnlyList<SavePreparationLineDraft> lines,
        string status,
        string? remoteIp,
        CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await ExecuteAsync(connection, transaction, """
            INSERT INTO Expedition_TourneeState(DateTournee, CodeTournee, Status, IsLocked, LastModifiedUtc, LastModifiedByIp)
            VALUES ($dateTournee, $codeTournee, $status, 0, $lastModifiedUtc, $ip)
            ON CONFLICT(DateTournee, CodeTournee) DO UPDATE SET
                Status = excluded.Status,
                LastModifiedUtc = excluded.LastModifiedUtc,
                LastModifiedByIp = excluded.LastModifiedByIp;
            """,
            cancellationToken,
            ("$dateTournee", ToDbDate(dateTournee)),
            ("$codeTournee", codeTournee),
            ("$status", status),
            ("$lastModifiedUtc", ToDbDateTime(now)),
            ("$ip", ToDbNullable(remoteIp)));

        foreach (var line in lines)
        {
            await ExecuteAsync(connection, transaction, """
                INSERT INTO Expedition_LineDraft(DateTournee, CodeTournee, IdLigneSource, CommentaireExceptionnel, IsLocked, LastModifiedUtc, LastModifiedByIp)
                VALUES ($dateTournee, $codeTournee, $idLigneSource, $commentaireExceptionnel, 0, $lastModifiedUtc, $ip)
                ON CONFLICT(DateTournee, CodeTournee, IdLigneSource) DO UPDATE SET
                    CommentaireExceptionnel = excluded.CommentaireExceptionnel,
                    LastModifiedUtc = excluded.LastModifiedUtc,
                    LastModifiedByIp = excluded.LastModifiedByIp;
                """,
                cancellationToken,
                ("$dateTournee", ToDbDate(dateTournee)),
                ("$codeTournee", codeTournee),
                ("$idLigneSource", line.IdLigneSource),
                ("$commentaireExceptionnel", ToDbNullable(line.CommentaireExceptionnel)),
                ("$lastModifiedUtc", ToDbDateTime(now)),
                ("$ip", ToDbNullable(remoteIp)));

            foreach (var quantity in line.Quantites.Where(q => IsPreparedArticle(q.Key)))
            {
                await ExecuteAsync(connection, transaction, """
                    INSERT INTO Expedition_LineQuantity(DateTournee, CodeTournee, IdLigneSource, CodeArticle, QuantiteLivreePrevue, LastModifiedUtc, LastModifiedByIp)
                    VALUES ($dateTournee, $codeTournee, $idLigneSource, $codeArticle, $quantiteLivreePrevue, $lastModifiedUtc, $ip)
                    ON CONFLICT(DateTournee, CodeTournee, IdLigneSource, CodeArticle) DO UPDATE SET
                        QuantiteLivreePrevue = excluded.QuantiteLivreePrevue,
                        LastModifiedUtc = excluded.LastModifiedUtc,
                        LastModifiedByIp = excluded.LastModifiedByIp;
                    """,
                    cancellationToken,
                    ("$dateTournee", ToDbDate(dateTournee)),
                    ("$codeTournee", codeTournee),
                    ("$idLigneSource", line.IdLigneSource),
                    ("$codeArticle", quantity.Key.ToUpperInvariant()),
                    ("$quantiteLivreePrevue", ToDbNullable(quantity.Value)),
                    ("$lastModifiedUtc", ToDbDateTime(now)),
                    ("$ip", ToDbNullable(remoteIp)));
            }
        }

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<bool> HasSuccessfulLockAsync(DateOnly dateTournee, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT 1
            FROM Expedition_LockHistory
            WHERE DateTournee = $dateTournee
              AND Status IN ('SUCCESS', 'ALREADY_PROCESSED', 'ALREADY_LOCKED')
            LIMIT 1;
            """;
        command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));

        var value = await command.ExecuteScalarAsync(cancellationToken);

        return value is not null && value != DBNull.Value;
    }

    public async Task<PreparedLockLot?> BuildLockLotAsync(DateTimeOffset requestedAtLocal, string lotSequence, CancellationToken cancellationToken)
    {
        var load = await GetLastLoadedDataAsync(cancellationToken);

        if (load is null)
        {
            return null;
        }

        var fuseauHoraireMetier = string.IsNullOrWhiteSpace(load.FuseauHoraireMetier)
            ? "Europe/Paris"
            : load.FuseauHoraireMetier;

        var request = new ExpeditionLockRequest
        {
            SchemaVersion = string.IsNullOrWhiteSpace(load.SchemaVersion) ? "1.2" : load.SchemaVersion,
            IdLotVerrouillage = $"EXP-{load.DateTournee:yyyy-MM-dd}-{requestedAtLocal:HHmm}-{lotSequence}",
            Source = "APPLICATION_WEB_EXPEDITION",
            DateTournee = load.DateTournee,
            DateVerrouillageDemandee = requestedAtLocal,
            FuseauHoraireMetier = fuseauHoraireMetier,
            Tournees = []
        };

        var tourneeStates = await GetTourneeStatesAsync(load.DateTournee, cancellationToken);
        DateTimeOffset? derniereModificationUtc = null;

        foreach (var tournee in load.Tournees.OrderBy(t => t.CodeTournee))
        {
            tourneeStates.TryGetValue(tournee.CodeTournee, out var tourneeState);

            var status = tourneeState?.Status ?? tournee.EtatPreparation;
            var isReadyForLock = string.Equals(status, StatusReadyForLock, StringComparison.OrdinalIgnoreCase);

            if (!isReadyForLock)
            {
                continue;
            }

            var lineStates = await GetLineStatesAsync(load.DateTournee, tournee.CodeTournee, cancellationToken);
            var lineDtos = new List<LigneLockDto>();

            foreach (var ligne in tournee.Lignes.OrderBy(l => l.OrdreArret))
            {
                lineStates.TryGetValue(ligne.IdLigneSource, out var lineState);

                if (lineState is not null)
                {
                    if (derniereModificationUtc is null || lineState.LastModifiedUtc > derniereModificationUtc.Value)
                    {
                        derniereModificationUtc = lineState.LastModifiedUtc;
                    }
                }

                var quantites = BuildArticlesPrepares(load.ArticlesSuivis)
                    .Select(article =>
                    {
                        int? value = null;

                        if (lineState is not null && lineState.Quantites.TryGetValue(article.CodeArticle, out var stored))
                        {
                            value = stored;
                        }
                        else
                        {
                            value = ligne.BrouillonInitial.Quantites
                                .FirstOrDefault(q => string.Equals(q.CodeArticle, article.CodeArticle, StringComparison.OrdinalIgnoreCase))
                                ?.QuantiteLivreePrevue;
                        }

                        return new QuantiteLockDto
                        {
                            CodeArticle = article.CodeArticle,
                            LibelleArticle = string.IsNullOrWhiteSpace(article.LibelleArticle) ? article.CodeArticle : article.LibelleArticle,
                            QuantiteLivreePrevue = value
                        };
                    })
                    .ToList();

                lineDtos.Add(new LigneLockDto
                {
                    IdLigneSource = ligne.IdLigneSource,
                    OrdreArret = ligne.OrdreArret,
                    Client = ligne.Client,
                    PointLivraison = ligne.PointLivraison,
                    CommentaireExceptionnel = lineState?.CommentaireExceptionnel ?? ligne.BrouillonInitial.CommentaireExceptionnel,
                    Quantites = quantites,
                    DerniereModification = new DerniereModificationDto
                    {
                        Date = lineState?.LastModifiedUtc ?? requestedAtLocal,
                        Utilisateur = "EXPEDITION_WEB"
                    }
                });
            }

            request.Tournees.Add(new TourneeLockDto
            {
                CodeTournee = tournee.CodeTournee,
                LibelleTournee = tournee.LibelleTournee,
                StatutPreparationWeb = StatusReadyForLock,
                Lignes = lineDtos
            });
        }

        if (request.Tournees.Count == 0)
        {
            _logger.LogInformation("Aucune tournée PRETE_VERROUILLAGE à transmettre au verrouillage Expédition.");
            return null;
        }

        request.DateVerrouillageDemandee = derniereModificationUtc.HasValue
            ? ConvertUtcToBusinessOffset(derniereModificationUtc.Value, request.FuseauHoraireMetier)
            : requestedAtLocal;

        var json = JsonSerializer.Serialize(request, JsonDefaults.Options);

        return new PreparedLockLot
        {
            Request = request,
            PayloadHash = ComputeSha256(json)
        };
    }

    public async Task MarkLockSuccessAsync(ExpeditionLockResponse response, string payloadHash, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        await ExecuteAsync(connection, transaction, """
            INSERT INTO Expedition_LockHistory(IdLotVerrouillage, DateTournee, Status, ApiMessage, PayloadHash, CreatedUtc, ProcessedUtc)
            VALUES ($idLot, $dateTournee, $status, $message, $payloadHash, $createdUtc, $processedUtc)
            ON CONFLICT(IdLotVerrouillage) DO UPDATE SET
                Status = excluded.Status,
                ApiMessage = excluded.ApiMessage,
                ProcessedUtc = excluded.ProcessedUtc;
            """,
            cancellationToken,
            ("$idLot", response.IdLotVerrouillage),
            ("$dateTournee", ToDbDate(response.DateTournee)),
            ("$status", response.Statut),
            ("$message", ToDbNullable(response.Message)),
            ("$payloadHash", payloadHash),
            ("$createdUtc", ToDbDateTime(now)),
            ("$processedUtc", ToDbDateTime(now)));

        await ExecuteAsync(connection, transaction, """
            UPDATE Expedition_TourneeState
            SET Status = $statusVerrouillage,
                IsLocked = 1,
                LastModifiedUtc = $lastModifiedUtc
            WHERE DateTournee = $dateTournee
              AND Status = 'PRETE_VERROUILLAGE'
              AND IsLocked = 0;
            """,
            cancellationToken,
            ("$statusVerrouillage", string.IsNullOrWhiteSpace(response.StatutVerrouillage) ? StatusLockedBd : response.StatutVerrouillage),
            ("$lastModifiedUtc", ToDbDateTime(now)),
            ("$dateTournee", ToDbDate(response.DateTournee)));

        await ExecuteAsync(connection, transaction, """
            UPDATE Expedition_LineDraft
            SET IsLocked = 1,
                LastModifiedUtc = $lastModifiedUtc
            WHERE DateTournee = $dateTournee
              AND CodeTournee IN (
                  SELECT CodeTournee
                  FROM Expedition_TourneeState
                  WHERE DateTournee = $dateTournee
                    AND IsLocked = 1
              );
            """,
            cancellationToken,
            ("$lastModifiedUtc", ToDbDateTime(now)),
            ("$dateTournee", ToDbDate(response.DateTournee)));

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task MarkLockFailureAsync(
        string idLotVerrouillage,
        DateOnly dateTournee,
        string status,
        string message,
        string payloadHash,
        CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await ExecuteAsync(connection, """
            INSERT INTO Expedition_LockHistory(IdLotVerrouillage, DateTournee, Status, ApiMessage, PayloadHash, CreatedUtc, ProcessedUtc)
            VALUES ($idLot, $dateTournee, $status, $message, $payloadHash, $createdUtc, $processedUtc)
            ON CONFLICT(IdLotVerrouillage) DO UPDATE SET
                Status = excluded.Status,
                ApiMessage = excluded.ApiMessage,
                ProcessedUtc = excluded.ProcessedUtc;
            """,
            cancellationToken,
            ("$idLot", idLotVerrouillage),
            ("$dateTournee", ToDbDate(dateTournee)),
            ("$status", status),
            ("$message", ToDbNullable(message)),
            ("$payloadHash", payloadHash),
            ("$createdUtc", ToDbDateTime(now)),
            ("$processedUtc", ToDbDateTime(now)));
    }

    public async Task<IReadOnlyList<LockHistoryItem>> GetRecentLockHistoryAsync(int count, CancellationToken cancellationToken)
    {
        var result = new List<LockHistoryItem>();

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT IdLotVerrouillage, DateTournee, Status, ApiMessage, CreatedUtc, ProcessedUtc
            FROM Expedition_LockHistory
            ORDER BY CreatedUtc DESC
            LIMIT $count;
            """;
        command.Parameters.AddWithValue("$count", count);

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(new LockHistoryItem
            {
                IdLotVerrouillage = reader.GetString(0),
                DateTournee = DateOnly.Parse(reader.GetString(1)),
                Status = reader.GetString(2),
                ApiMessage = reader.IsDBNull(3) ? null : reader.GetString(3),
                CreatedUtc = DateTimeOffset.Parse(reader.GetString(4)),
                ProcessedUtc = reader.IsDBNull(5) ? null : DateTimeOffset.Parse(reader.GetString(5))
            });
        }

        return result;
    }

    private SqliteConnection CreateConnection()
    {
        return new SqliteConnection($"Data Source={GetDatabasePath()}");
    }

    private string GetDatabasePath()
    {
        if (Path.IsPathRooted(_options.DatabasePath))
        {
            return _options.DatabasePath;
        }

        return Path.Combine(AppContext.BaseDirectory, _options.DatabasePath);
    }

    private void EnsureDatabaseDirectoryExists()
    {
        var databasePath = GetDatabasePath();
        var directory = Path.GetDirectoryName(databasePath);

        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }
    }

    private static async Task ExecuteAsync(
        SqliteConnection connection,
        string sql,
        CancellationToken cancellationToken,
        params (string Name, object? Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;

        foreach (var parameter in parameters)
        {
            command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        }

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task ExecuteAsync(
        SqliteConnection connection,
        System.Data.Common.DbTransaction transaction,
        string sql,
        CancellationToken cancellationToken,
        params (string Name, object? Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.Transaction = (SqliteTransaction)transaction;
        command.CommandText = sql;

        foreach (var parameter in parameters)
        {
            command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        }

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static TourneeDraftState ReadTourneeDraftState(SqliteDataReader reader)
    {
        return new TourneeDraftState
        {
            DateTournee = DateOnly.Parse(reader.GetString(0)),
            CodeTournee = reader.GetString(1),
            Status = reader.GetString(2),
            IsLocked = reader.GetInt32(3) == 1,
            LastModifiedUtc = DateTimeOffset.Parse(reader.GetString(4))
        };
    }

    private static List<ArticleSuiviDto> BuildArticlesPrepares(List<ArticleSuiviDto> articles)
    {
        var defaults = new[]
        {
            new ArticleSuiviDto { CodeArticle = "ROLLS", LibelleArticle = "Rolls", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "TAPIS", LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "SACS", LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
        };

        return defaults
            .Select(defaultArticle =>
            {
                var articleApi = articles.FirstOrDefault(a => string.Equals(a.CodeArticle, defaultArticle.CodeArticle, StringComparison.OrdinalIgnoreCase));

                return articleApi is null || string.IsNullOrWhiteSpace(articleApi.CodeArticle)
                    ? defaultArticle
                    : articleApi;
            })
            .ToList();
    }

    private static bool IsPreparedArticle(string codeArticle)
    {
        return string.Equals(codeArticle, "ROLLS", StringComparison.OrdinalIgnoreCase)
            || string.Equals(codeArticle, "TAPIS", StringComparison.OrdinalIgnoreCase)
            || string.Equals(codeArticle, "SACS", StringComparison.OrdinalIgnoreCase);
    }

    private static DateTimeOffset ConvertUtcToBusinessOffset(DateTimeOffset utcDate, string? timeZoneId)
    {
        var timeZone = FindBusinessTimeZone(timeZoneId);
        var utc = utcDate.ToUniversalTime().UtcDateTime;
        var localDateTime = TimeZoneInfo.ConvertTimeFromUtc(utc, timeZone);
        var offset = timeZone.GetUtcOffset(utc);

        return new DateTimeOffset(localDateTime, offset);
    }

    private static TimeZoneInfo FindBusinessTimeZone(string? timeZoneId)
    {
        if (!string.IsNullOrWhiteSpace(timeZoneId))
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById(timeZoneId);
            }
            catch (TimeZoneNotFoundException)
            {
            }
            catch (InvalidTimeZoneException)
            {
            }
        }

        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Europe/Paris");
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Romance Standard Time");
        }
        catch (InvalidTimeZoneException)
        {
            return TimeZoneInfo.FindSystemTimeZoneById("Romance Standard Time");
        }
    }

    private static string ToDbDate(DateOnly date)
    {
        return date.ToString("yyyy-MM-dd");
    }

    private static string ToDbDateTime(DateTimeOffset date)
    {
        return date.ToUniversalTime().ToString("O");
    }

    private static object? ToDbNullable(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? DBNull.Value : value;
    }

    private static object? ToDbNullable(int? value)
    {
        return value.HasValue ? value.Value : DBNull.Value;
    }

    private static string ComputeSha256(string text)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(text));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}
