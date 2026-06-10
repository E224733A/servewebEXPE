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
/// Stockage brouillon SQLite côté SERVEXPE.
/// Séparation stricte :
/// - Expedition_LineQuantity = quantités prévues saisies par l'Expédition ;
/// - Admin_CommentaireDraft = commentaires exceptionnels saisis par l'Administration ;
/// - Expedition_LockHistory = état du lot envoyé à l'API centrale.
///
/// Important : le blocage définitif se fait au niveau tournée, pas au niveau date.
/// Une tournée déjà verrouillée devient non modifiable, mais les autres tournées de la même date restent modifiables.
/// Le blocage global par date est réservé à l'état temporaire VERROUILLAGE_EN_COURS.
///
/// Règle de traçabilité simple :
/// - Expedition_TourneeState.LastModifiedUtc représente l'heure du dernier clic humain
///   "Marquer prête pour verrouillage" quand la tournée est en PRET_VERROUILLAGE / PRETE_VERROUILLAGE ;
/// - cette heure est envoyée dans TourneeLockDto.DateModification au verrouillage de nuit ;
/// - elle ne doit pas être remplacée par DateVerrouillageDemandee, qui correspond au traitement automatique.
/// </summary>
public sealed class SqliteExpeditionDraftStore : IExpeditionDraftStore
{
    private const string StatusReadyForLock = DraftStatuses.PretVerrouillage;
    private const string ApiSource = "APPLICATION_WEB_EXPEDITION";
    private const string ApiStatusReadyForLock = "PRETE_VERROUILLAGE";
    private const string ApiUser = "APPLICATION_WEB_EXPEDITION";
    private const int DraftRetentionDays = 10;
    private const int LockHistoryRetentionDays = 30;

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

        // Paramètres SQLite importants pour un usage web : attente courte, intégrité référentielle et WAL pour limiter les blocages.
        await ExecuteAsync(connection, "PRAGMA busy_timeout = 5000;", cancellationToken);
        await ExecuteAsync(connection, "PRAGMA foreign_keys = ON;", cancellationToken);
        await ExecuteAsync(connection, "PRAGMA journal_mode = WAL;", cancellationToken);

        // Dernier snapshot API brut, conservé en JSON pour reconstruire les écrans sans rappeler l'API à chaque navigation.
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

        // État local par tournée : brouillon, prêt verrouillage, verrouillage en cours ou verrouillé.
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

        // Table pivot par ligne Expédition, utilisée comme parent des quantités préparées.
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

        // Quantités préparées côté Expédition, séparées des commentaires Administration.
        await ExecuteAsync(connection, """
            CREATE TABLE IF NOT EXISTS Expedition_LineQuantity (
                DateTournee TEXT NOT NULL,
                CodeTournee TEXT NOT NULL,
                IdLigneSource TEXT NOT NULL,
                CodeArticle TEXT NOT NULL,
                QuantiteLivreePrevue INTEGER NULL CHECK (QuantiteLivreePrevue IS NULL OR QuantiteLivreePrevue >= 0),
                LastModifiedUtc TEXT NOT NULL,
                LastModifiedByIp TEXT NULL,
                PRIMARY KEY (DateTournee, CodeTournee, IdLigneSource, CodeArticle),
                FOREIGN KEY (DateTournee, CodeTournee, IdLigneSource)
                    REFERENCES Expedition_LineDraft(DateTournee, CodeTournee, IdLigneSource)
                    ON DELETE CASCADE
            );
            """, cancellationToken);

        // Commentaires exceptionnels saisis dans l'espace Administration.
        await ExecuteAsync(connection, """
            CREATE TABLE IF NOT EXISTS Admin_CommentaireDraft (
                DateTournee TEXT NOT NULL,
                CodeTournee TEXT NOT NULL,
                IdLigneSource TEXT NOT NULL,
                CommentaireExceptionnel TEXT NULL,
                StatutBrouillon TEXT NOT NULL DEFAULT 'BROUILLON',
                IsLocked INTEGER NOT NULL DEFAULT 0,
                LastModifiedUtc TEXT NOT NULL,
                LastModifiedByIp TEXT NULL,
                PRIMARY KEY (DateTournee, CodeTournee, IdLigneSource)
            );
            """, cancellationToken);

        // Historique local des lots envoyés à l'API pour diagnostiquer les succès, rejoues, conflits et échecs.
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

        await ExecuteAsync(connection, "CREATE INDEX IF NOT EXISTS IX_Expedition_LineQuantity_Ligne ON Expedition_LineQuantity(DateTournee, CodeTournee, IdLigneSource);", cancellationToken);
        await ExecuteAsync(connection, "CREATE INDEX IF NOT EXISTS IX_Admin_CommentaireDraft_Ligne ON Admin_CommentaireDraft(DateTournee, CodeTournee, IdLigneSource);", cancellationToken);
        await ExecuteAsync(connection, "CREATE INDEX IF NOT EXISTS IX_Expedition_LockHistory_CreatedUtc ON Expedition_LockHistory(CreatedUtc DESC);", cancellationToken);
        await ExecuteAsync(connection, "CREATE INDEX IF NOT EXISTS IX_Expedition_LockHistory_DateTournee_Status ON Expedition_LockHistory(DateTournee, Status);", cancellationToken);

        _logger.LogInformation("Stockage SQLite SERVEXPE initialisé : {DatabasePath}", GetDatabasePath());
    }

    public async Task CleanupOldDataAsync(CancellationToken cancellationToken)
    {
        try
        {
            var today = DateOnly.FromDateTime(DateTime.Now);
            var draftCutoffDate = today.AddDays(-DraftRetentionDays);
            var lockHistoryCutoffUtc = DateTimeOffset.UtcNow.AddDays(-LockHistoryRetentionDays);

            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);
            await ExecuteAsync(connection, "PRAGMA busy_timeout = 5000;", cancellationToken);
            await ExecuteAsync(connection, "PRAGMA foreign_keys = ON;", cancellationToken);

            await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

            // La purge reste strictement locale : elle nettoie les brouillons SERVWEB sans toucher l'API ni SQL Server central.
            await ExecuteAsync(connection, transaction, "DELETE FROM Expedition_LineQuantity WHERE DateTournee < $draftCutoffDate;", cancellationToken, ("$draftCutoffDate", ToDbDate(draftCutoffDate)));
            await ExecuteAsync(connection, transaction, "DELETE FROM Expedition_LineDraft WHERE DateTournee < $draftCutoffDate;", cancellationToken, ("$draftCutoffDate", ToDbDate(draftCutoffDate)));
            await ExecuteAsync(connection, transaction, "DELETE FROM Admin_CommentaireDraft WHERE DateTournee < $draftCutoffDate;", cancellationToken, ("$draftCutoffDate", ToDbDate(draftCutoffDate)));
            await ExecuteAsync(connection, transaction, "DELETE FROM Expedition_TourneeState WHERE DateTournee < $draftCutoffDate;", cancellationToken, ("$draftCutoffDate", ToDbDate(draftCutoffDate)));
            await ExecuteAsync(connection, transaction, "DELETE FROM Expedition_LoadedData WHERE DateTournee < $draftCutoffDate;", cancellationToken, ("$draftCutoffDate", ToDbDate(draftCutoffDate)));
            await ExecuteAsync(connection, transaction, "DELETE FROM Expedition_LockHistory WHERE CreatedUtc < $lockHistoryCutoffUtc;", cancellationToken, ("$lockHistoryCutoffUtc", ToDbDateTime(lockHistoryCutoffUtc)));

            await transaction.CommitAsync(cancellationToken);
            await ExecuteAsync(connection, "PRAGMA optimize;", cancellationToken);

            _logger.LogInformation(
                "Purge SQLite SERVEXPE exécutée. Brouillons conservés depuis {DraftCutoffDate}. Historique verrouillage conservé depuis {LockHistoryCutoffUtc}.",
                draftCutoffDate,
                lockHistoryCutoffUtc);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            // Une purge échouée ne doit pas empêcher les opérateurs de préparer les tournées.
            _logger.LogWarning(ex, "La purge SQLite SERVEXPE a échoué. Le fonctionnement métier continue.");
        }
    }

    public async Task SaveLoadedDataAsync(ExpeditionLoadResponse response, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var payloadJson = JsonSerializer.Serialize(response, JsonDefaults.Options);

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        // Chaque chargement garde le payload complet ; le dernier Id devient le snapshot courant de l'application.
        await ExecuteAsync(connection, transaction, """
            INSERT INTO Expedition_LoadedData(DateTournee, LoadedAtUtc, PayloadJson)
            VALUES ($dateTournee, $loadedAtUtc, $payloadJson);
            """, cancellationToken,
            ("$dateTournee", ToDbDate(response.DateTournee)),
            ("$loadedAtUtc", ToDbDateTime(now)),
            ("$payloadJson", payloadJson));

        foreach (var tournee in response.Tournees)
        {
            var initialStatus = string.IsNullOrWhiteSpace(tournee.EtatPreparation) ? "NON_PREPAREE" : tournee.EtatPreparation;
            await ExecuteAsync(connection, transaction, """
                INSERT INTO Expedition_TourneeState(DateTournee, CodeTournee, Status, IsLocked, LastModifiedUtc, LastModifiedByIp)
                VALUES ($dateTournee, $codeTournee, $status, $isLocked, $lastModifiedUtc, NULL)
                ON CONFLICT(DateTournee, CodeTournee) DO UPDATE SET
                    Status = CASE
                        WHEN Expedition_TourneeState.IsLocked = 1 THEN Expedition_TourneeState.Status
                        WHEN Expedition_TourneeState.Status IN ('BROUILLON', 'PRET_VERROUILLAGE', 'PRETE_VERROUILLAGE', 'VERROUILLAGE_EN_COURS') THEN Expedition_TourneeState.Status
                        ELSE excluded.Status
                    END,
                    IsLocked = CASE WHEN Expedition_TourneeState.IsLocked = 1 THEN 1 ELSE excluded.IsLocked END,
                    LastModifiedUtc = CASE
                        WHEN Expedition_TourneeState.Status IN ('BROUILLON', 'PRET_VERROUILLAGE', 'PRETE_VERROUILLAGE', 'VERROUILLAGE_EN_COURS') THEN Expedition_TourneeState.LastModifiedUtc
                        ELSE excluded.LastModifiedUtc
                    END,
                    LastModifiedByIp = CASE
                        WHEN Expedition_TourneeState.Status IN ('BROUILLON', 'PRET_VERROUILLAGE', 'PRETE_VERROUILLAGE', 'VERROUILLAGE_EN_COURS') THEN Expedition_TourneeState.LastModifiedByIp
                        ELSE excluded.LastModifiedByIp
                    END;
                """, cancellationToken,
                ("$dateTournee", ToDbDate(response.DateTournee)),
                ("$codeTournee", tournee.CodeTournee),
                ("$status", initialStatus),
                ("$isLocked", tournee.EstVerrouilleeBd ? 1 : 0),
                ("$lastModifiedUtc", ToDbDateTime(now)));
        }

        await transaction.CommitAsync(cancellationToken);
        await CleanupOldDataAsync(cancellationToken);
    }

    public async Task<ExpeditionLoadResponse?> GetLastLoadedDataAsync(CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT PayloadJson FROM Expedition_LoadedData ORDER BY Id DESC LIMIT 1;";
        var payload = await command.ExecuteScalarAsync(cancellationToken);
        return payload is null || payload == DBNull.Value
            ? null
            : JsonSerializer.Deserialize<ExpeditionLoadResponse>((string)payload, JsonDefaults.Options);
    }

    public async Task<IReadOnlyDictionary<string, TourneeDraftState>> GetTourneeStatesAsync(DateOnly dateTournee, CancellationToken cancellationToken)
    {
        var result = new Dictionary<string, TourneeDraftState>(StringComparer.OrdinalIgnoreCase);
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT DateTournee, CodeTournee, Status, IsLocked, LastModifiedUtc FROM Expedition_TourneeState WHERE DateTournee = $dateTournee;";
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
            WHERE DateTournee = $dateTournee AND CodeTournee = $codeTournee
            LIMIT 1;
            """;
        command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));
        command.Parameters.AddWithValue("$codeTournee", codeTournee);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken) ? ReadTourneeDraftState(reader) : null;
    }

    public async Task<IReadOnlyDictionary<string, LineDraftState>> GetLineStatesAsync(DateOnly dateTournee, string codeTournee, CancellationToken cancellationToken)
    {
        var result = new Dictionary<string, LineDraftState>(StringComparer.OrdinalIgnoreCase);
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        // Première passe : initialise les lignes qui ont au moins un brouillon Expédition.
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT DISTINCT DateTournee, CodeTournee, IdLigneSource, IsLocked, LastModifiedUtc
                FROM Expedition_LineDraft
                WHERE DateTournee = $dateTournee AND CodeTournee = $codeTournee;
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
                    IsLocked = reader.GetInt32(3) == 1,
                    LastModifiedQuantiteUtc = DateTimeOffset.Parse(reader.GetString(4)),
                    LastModifiedUtc = DateTimeOffset.Parse(reader.GetString(4)),
                    Quantites = new Dictionary<string, int?>(StringComparer.OrdinalIgnoreCase)
                };
                result[line.IdLigneSource] = line;
            }
        }

        // Deuxième passe : ajoute les quantités par article dans les lignes déjà connues ou créées à la volée.
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT IdLigneSource, CodeArticle, QuantiteLivreePrevue, LastModifiedUtc
                FROM Expedition_LineQuantity
                WHERE DateTournee = $dateTournee AND CodeTournee = $codeTournee;
                """;
            command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));
            command.Parameters.AddWithValue("$codeTournee", codeTournee);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                var id = reader.GetString(0);
                if (!result.TryGetValue(id, out var line))
                {
                    line = new LineDraftState { DateTournee = dateTournee, CodeTournee = codeTournee, IdLigneSource = id };
                    result[id] = line;
                }
                line.Quantites[reader.GetString(1)] = reader.IsDBNull(2) ? null : reader.GetInt32(2);
                var modified = DateTimeOffset.Parse(reader.GetString(3));
                line.LastModifiedQuantiteUtc = Max(line.LastModifiedQuantiteUtc, modified);
                line.LastModifiedUtc = Max(line.LastModifiedUtc, modified);
            }
        }

        // Troisième passe : fusionne les commentaires Administration avec les mêmes LineDraftState.
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = """
                SELECT IdLigneSource, CommentaireExceptionnel, IsLocked, LastModifiedUtc
                FROM Admin_CommentaireDraft
                WHERE DateTournee = $dateTournee AND CodeTournee = $codeTournee;
                """;
            command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));
            command.Parameters.AddWithValue("$codeTournee", codeTournee);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                var id = reader.GetString(0);
                if (!result.TryGetValue(id, out var line))
                {
                    line = new LineDraftState { DateTournee = dateTournee, CodeTournee = codeTournee, IdLigneSource = id };
                    result[id] = line;
                }
                line.CommentaireExceptionnel = reader.IsDBNull(1) ? null : reader.GetString(1);
                line.IsLocked = line.IsLocked || reader.GetInt32(2) == 1;
                var modified = DateTimeOffset.Parse(reader.GetString(3));
                line.LastModifiedCommentaireUtc = modified;
                line.LastModifiedUtc = Max(line.LastModifiedUtc, modified);
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
        CancellationToken cancellationToken,
        bool enregistrerClicPretVerrouillage = false)
    {
        var now = DateTimeOffset.UtcNow;
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await EnsureWritableAsync(connection, transaction, dateTournee, codeTournee, cancellationToken);

        // Le statut de tournée est mis à jour avant les lignes pour garder une trace cohérente de la saisie globale.
        await UpsertTourneeStateAsync(
            connection,
            transaction,
            dateTournee,
            codeTournee,
            status,
            now,
            remoteIp,
            enregistrerClicPretVerrouillage,
            cancellationToken);

        foreach (var line in lines)
        {
            await ExecuteAsync(connection, transaction, """
                INSERT INTO Expedition_LineDraft(DateTournee, CodeTournee, IdLigneSource, CommentaireExceptionnel, IsLocked, LastModifiedUtc, LastModifiedByIp)
                VALUES ($dateTournee, $codeTournee, $idLigneSource, NULL, 0, $lastModifiedUtc, $ip)
                ON CONFLICT(DateTournee, CodeTournee, IdLigneSource) DO UPDATE SET
                    LastModifiedUtc = excluded.LastModifiedUtc,
                    LastModifiedByIp = excluded.LastModifiedByIp;
                """, cancellationToken,
                ("$dateTournee", ToDbDate(dateTournee)), ("$codeTournee", codeTournee), ("$idLigneSource", line.IdLigneSource),
                ("$lastModifiedUtc", ToDbDateTime(now)), ("$ip", ToDbNullable(remoteIp)));

            foreach (var quantity in line.Quantites.Where(q => IsPreparedArticle(q.Key)))
            {
                await ExecuteAsync(connection, transaction, """
                    INSERT INTO Expedition_LineQuantity(DateTournee, CodeTournee, IdLigneSource, CodeArticle, QuantiteLivreePrevue, LastModifiedUtc, LastModifiedByIp)
                    VALUES ($dateTournee, $codeTournee, $idLigneSource, $codeArticle, $quantiteLivreePrevue, $lastModifiedUtc, $ip)
                    ON CONFLICT(DateTournee, CodeTournee, IdLigneSource, CodeArticle) DO UPDATE SET
                        QuantiteLivreePrevue = excluded.QuantiteLivreePrevue,
                        LastModifiedUtc = excluded.LastModifiedUtc,
                        LastModifiedByIp = excluded.LastModifiedByIp;
                    """, cancellationToken,
                    ("$dateTournee", ToDbDate(dateTournee)), ("$codeTournee", codeTournee), ("$idLigneSource", line.IdLigneSource),
                    ("$codeArticle", quantity.Key.ToUpperInvariant()), ("$quantiteLivreePrevue", ToDbNullable(quantity.Value)),
                    ("$lastModifiedUtc", ToDbDateTime(now)), ("$ip", ToDbNullable(remoteIp)));
            }
        }

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task SaveAdminCommentaireAsync(DateOnly dateTournee, string codeTournee, SaveAdminCommentaireDraft commentaire, string? remoteIp, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        await EnsureWritableAsync(connection, transaction, dateTournee, codeTournee, cancellationToken);

        // Les commentaires Administration restent dans leur table dédiée afin de ne pas mélanger les rôles des deux interfaces.
        await ExecuteAsync(connection, transaction, """
            INSERT INTO Admin_CommentaireDraft(DateTournee, CodeTournee, IdLigneSource, CommentaireExceptionnel, StatutBrouillon, IsLocked, LastModifiedUtc, LastModifiedByIp)
            VALUES ($dateTournee, $codeTournee, $idLigneSource, $commentaire, 'BROUILLON', 0, $lastModifiedUtc, $ip)
            ON CONFLICT(DateTournee, CodeTournee, IdLigneSource) DO UPDATE SET
                CommentaireExceptionnel = excluded.CommentaireExceptionnel,
                StatutBrouillon = CASE WHEN Admin_CommentaireDraft.IsLocked = 1 THEN Admin_CommentaireDraft.StatutBrouillon ELSE excluded.StatutBrouillon END,
                LastModifiedUtc = excluded.LastModifiedUtc,
                LastModifiedByIp = excluded.LastModifiedByIp;
            """, cancellationToken,
            ("$dateTournee", ToDbDate(dateTournee)), ("$codeTournee", codeTournee), ("$idLigneSource", commentaire.IdLigneSource),
            ("$commentaire", ToDbNullable(commentaire.CommentaireExceptionnel)), ("$lastModifiedUtc", ToDbDateTime(now)), ("$ip", ToDbNullable(remoteIp)));

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task<PreparedLockLot?> BuildLockLotAsync(DateTimeOffset requestedAtLocal, string lotSequence, CancellationToken cancellationToken)
    {
        var load = await GetLastLoadedDataAsync(cancellationToken);
        if (load is null) return null;

        // Id de lot déterministe pour la date, l'heure demandée et la séquence configurée.
        var request = new ExpeditionLockRequest
        {
            SchemaVersion = string.IsNullOrWhiteSpace(load.SchemaVersion) ? "1.2" : load.SchemaVersion,
            IdLotVerrouillage = $"SERVEXPE-{load.DateTournee:yyyy-MM-dd}-{requestedAtLocal:HHmm}-{lotSequence}",
            Source = ApiSource,
            DateTournee = load.DateTournee,
            DateVerrouillageDemandee = requestedAtLocal,
            FuseauHoraireMetier = string.IsNullOrWhiteSpace(load.FuseauHoraireMetier) ? "Europe/Paris" : load.FuseauHoraireMetier,
            Tournees = []
        };

        var tourneeStates = await GetTourneeStatesAsync(load.DateTournee, cancellationToken);

        foreach (var tournee in load.Tournees.OrderBy(t => t.CodeTournee))
        {
            tourneeStates.TryGetValue(tournee.CodeTournee, out var tourneeState);

            if (tournee.EstVerrouilleeBd || tourneeState?.IsLocked == true)
            {
                continue;
            }

            var status = tourneeState?.Status ?? tournee.EtatPreparation;
            if (!IsReadyForLockStatus(status)) continue;

            // Date métier du dernier clic prêt : elle est différente de l'heure technique du verrouillage automatique.
            var dateDernierClicPret = tourneeState?.LastModifiedUtc ?? requestedAtLocal;
            var lineStates = await GetLineStatesAsync(load.DateTournee, tournee.CodeTournee, cancellationToken);
            var lineDtos = new List<LigneLockDto>();

            foreach (var ligne in tournee.Lignes.OrderBy(l => l.OrdreArret))
            {
                lineStates.TryGetValue(ligne.IdLigneSource, out var lineState);
                var quantites = BuildArticlesPrepares(load.ArticlesSuivis)
                    .Select(article => new QuantiteLockDto
                    {
                        CodeArticle = article.CodeArticle,
                        LibelleArticle = string.IsNullOrWhiteSpace(article.LibelleArticle) ? article.CodeArticle : article.LibelleArticle,
                        QuantiteLivreePrevue = lineState is not null && lineState.Quantites.TryGetValue(article.CodeArticle, out var stored)
                            ? stored
                            : ligne.BrouillonInitial.Quantites.FirstOrDefault(q => string.Equals(q.CodeArticle, article.CodeArticle, StringComparison.OrdinalIgnoreCase))?.QuantiteLivreePrevue
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
                        Date = dateDernierClicPret,
                        Utilisateur = ApiUser
                    }
                });
            }

            request.Tournees.Add(new TourneeLockDto
            {
                CodeTournee = tournee.CodeTournee,
                LibelleTournee = tournee.LibelleTournee,
                StatutPreparationWeb = ApiStatusReadyForLock,
                DateModification = dateDernierClicPret,
                Lignes = lineDtos
            });
        }

        if (request.Tournees.Count == 0)
        {
            _logger.LogInformation("Aucune tournée PRET_VERROUILLAGE/PRETE_VERROUILLAGE à transmettre au verrouillage API Expédition.");
            return null;
        }

        var json = JsonSerializer.Serialize(request, JsonDefaults.Options);
        return new PreparedLockLot { Request = request, PayloadHash = ComputeSha256(json) };
    }

    public async Task<bool> HasSuccessfulLockAsync(DateOnly dateTournee, IReadOnlyCollection<string> codeTournees, CancellationToken cancellationToken)
    {
        if (codeTournees.Count == 0)
        {
            return false;
        }

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);

        // Toutes les tournées du lot doivent être verrouillées pour considérer le verrouillage comme déjà réussi.
        foreach (var codeTournee in codeTournees.Where(code => !string.IsNullOrWhiteSpace(code)))
        {
            await using var command = connection.CreateCommand();
            command.CommandText = """
                SELECT IsLocked
                FROM Expedition_TourneeState
                WHERE DateTournee = $dateTournee
                  AND CodeTournee = $codeTournee
                LIMIT 1;
                """;
            command.Parameters.AddWithValue("$dateTournee", ToDbDate(dateTournee));
            command.Parameters.AddWithValue("$codeTournee", codeTournee);

            var value = await command.ExecuteScalarAsync(cancellationToken);
            if (value is null || value == DBNull.Value || Convert.ToInt32(value) != 1)
            {
                return false;
            }
        }

        return true;
    }

    public async Task MarkLockSuccessAsync(ExpeditionLockResponse response, string payloadHash, IReadOnlyCollection<string> codeTourneesVerrouillees, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var lotStatus = string.Equals(response.Statut, "ALREADY_PROCESSED", StringComparison.OrdinalIgnoreCase) ? LotStatuses.RejoueIdentique : LotStatuses.Envoye;
        var codes = codeTourneesVerrouillees
            .Where(code => !string.IsNullOrWhiteSpace(code))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

        // L'historique est écrit avant le verrouillage local des tournées pour conserver la réponse API reçue.
        await ExecuteAsync(connection, transaction, """
            INSERT INTO Expedition_LockHistory(IdLotVerrouillage, DateTournee, Status, ApiMessage, PayloadHash, CreatedUtc, ProcessedUtc)
            VALUES ($idLot, $dateTournee, $status, $message, $payloadHash, $createdUtc, $processedUtc)
            ON CONFLICT(IdLotVerrouillage) DO UPDATE SET Status = excluded.Status, ApiMessage = excluded.ApiMessage, ProcessedUtc = excluded.ProcessedUtc;
            """, cancellationToken,
            ("$idLot", response.IdLotVerrouillage), ("$dateTournee", ToDbDate(response.DateTournee)), ("$status", lotStatus),
            ("$message", ToDbNullable(response.Message)), ("$payloadHash", payloadHash), ("$createdUtc", ToDbDateTime(now)), ("$processedUtc", ToDbDateTime(now)));

        foreach (var codeTournee in codes)
        {
            await ExecuteAsync(connection, transaction, """
                UPDATE Expedition_TourneeState
                SET Status = $status,
                    IsLocked = 1
                WHERE DateTournee = $dateTournee
                  AND CodeTournee = $codeTournee
                  AND IsLocked = 0;
                """, cancellationToken,
                ("$status", DraftStatuses.Verrouille),
                ("$dateTournee", ToDbDate(response.DateTournee)),
                ("$codeTournee", codeTournee));

            await ExecuteAsync(connection, transaction, """
                UPDATE Expedition_LineDraft
                SET IsLocked = 1,
                    LastModifiedUtc = $now
                WHERE DateTournee = $dateTournee
                  AND CodeTournee = $codeTournee;
                """, cancellationToken,
                ("$now", ToDbDateTime(now)),
                ("$dateTournee", ToDbDate(response.DateTournee)),
                ("$codeTournee", codeTournee));

            await ExecuteAsync(connection, transaction, """
                UPDATE Admin_CommentaireDraft
                SET IsLocked = 1,
                    StatutBrouillon = 'VERROUILLE',
                    LastModifiedUtc = $now
                WHERE DateTournee = $dateTournee
                  AND CodeTournee = $codeTournee;
                """, cancellationToken,
                ("$now", ToDbDateTime(now)),
                ("$dateTournee", ToDbDate(response.DateTournee)),
                ("$codeTournee", codeTournee));
        }

        await transaction.CommitAsync(cancellationToken);
    }

    public async Task MarkLockFailureAsync(string idLotVerrouillage, DateOnly dateTournee, string status, string message, string payloadHash, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var localStatus = string.Equals(status, "CONFLICT", StringComparison.OrdinalIgnoreCase) ? LotStatuses.Conflit : LotStatuses.ErreurEnvoi;
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await ExecuteAsync(connection, """
            INSERT INTO Expedition_LockHistory(IdLotVerrouillage, DateTournee, Status, ApiMessage, PayloadHash, CreatedUtc, ProcessedUtc)
            VALUES ($idLot, $dateTournee, $status, $message, $payloadHash, $createdUtc, $processedUtc)
            ON CONFLICT(IdLotVerrouillage) DO UPDATE SET Status = excluded.Status, ApiMessage = excluded.ApiMessage, ProcessedUtc = excluded.ProcessedUtc;
            """, cancellationToken,
            ("$idLot", idLotVerrouillage), ("$dateTournee", ToDbDate(dateTournee)), ("$status", localStatus),
            ("$message", ToDbNullable(message)), ("$payloadHash", payloadHash), ("$createdUtc", ToDbDateTime(now)), ("$processedUtc", ToDbDateTime(now)));
    }

    public async Task<IReadOnlyList<LockHistoryItem>> GetRecentLockHistoryAsync(int count, CancellationToken cancellationToken)
    {
        var result = new List<LockHistoryItem>();
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT IdLotVerrouillage, DateTournee, Status, ApiMessage, PayloadHash, CreatedUtc, ProcessedUtc FROM Expedition_LockHistory ORDER BY CreatedUtc DESC LIMIT $count;";
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
                PayloadHash = reader.GetString(4),
                CreatedUtc = DateTimeOffset.Parse(reader.GetString(5)),
                ProcessedUtc = reader.IsDBNull(6) ? null : DateTimeOffset.Parse(reader.GetString(6))
            });
        }
        return result;
    }

    public async Task<PreparationStatusSnapshot> GetStatusSnapshotAsync(DateTimeOffset? expectedLockAtLocal, CancellationToken cancellationToken)
    {
        var load = await GetLastLoadedDataAsync(cancellationToken);
        var locks = await GetRecentLockHistoryAsync(1, cancellationToken);
        var snapshot = new PreparationStatusSnapshot
        {
            DateTournee = load?.DateTournee,
            NombreTourneesChargees = load?.Tournees.Count ?? 0,
            DernierChargementApi = await GetLastLoadTimeAsync(cancellationToken),
            StatutDernierVerrouillage = locks.FirstOrDefault()?.Status,
            MessageRetourApi = locks.FirstOrDefault()?.ApiMessage,
            DateDerniereTentative = locks.FirstOrDefault()?.ProcessedUtc,
            VerrouillageAttenduA = expectedLockAtLocal
        };

        if (load is not null)
        {
            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);
            snapshot.NombreQuantitesModifiees = Convert.ToInt32(await ScalarAsync(connection, "SELECT COUNT(*) FROM Expedition_LineQuantity WHERE DateTournee = $date", cancellationToken, ("$date", ToDbDate(load.DateTournee))) ?? 0);
            snapshot.NombreCommentairesModifies = Convert.ToInt32(await ScalarAsync(connection, "SELECT COUNT(*) FROM Admin_CommentaireDraft WHERE DateTournee = $date AND CommentaireExceptionnel IS NOT NULL AND TRIM(CommentaireExceptionnel) <> ''", cancellationToken, ("$date", ToDbDate(load.DateTournee))) ?? 0);
        }

        // Retard affiché seulement après une marge de 30 minutes, pour éviter une alerte pendant la fenêtre normale de traitement.
        if (expectedLockAtLocal.HasValue && DateTimeOffset.Now > expectedLockAtLocal.Value.AddMinutes(30))
        {
            snapshot.VerrouillageEnRetard = !string.Equals(snapshot.StatutDernierVerrouillage, LotStatuses.Envoye, StringComparison.OrdinalIgnoreCase)
                && !string.Equals(snapshot.StatutDernierVerrouillage, LotStatuses.RejoueIdentique, StringComparison.OrdinalIgnoreCase);
        }

        return snapshot;
    }

    private async Task<DateTimeOffset?> GetLastLoadTimeAsync(CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        var value = await ScalarAsync(connection, "SELECT LoadedAtUtc FROM Expedition_LoadedData ORDER BY Id DESC LIMIT 1", cancellationToken);
        return value is string s ? DateTimeOffset.Parse(s) : null;
    }

    private static async Task<object?> ScalarAsync(SqliteConnection connection, string sql, CancellationToken cancellationToken, params (string Name, object? Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        foreach (var p in parameters) command.Parameters.AddWithValue(p.Name, p.Value ?? DBNull.Value);
        var value = await command.ExecuteScalarAsync(cancellationToken);
        return value == DBNull.Value ? null : value;
    }

    private static async Task EnsureWritableAsync(SqliteConnection connection, System.Data.Common.DbTransaction transaction, DateOnly dateTournee, string codeTournee, CancellationToken cancellationToken)
    {
        // Blocage global temporaire : pendant un verrouillage en cours, aucune modification n'est acceptée pour éviter un lot incohérent.
        await using (var command = connection.CreateCommand())
        {
            command.Transaction = (SqliteTransaction)transaction;
            command.CommandText = """
                SELECT Status
                FROM Expedition_LockHistory
                WHERE DateTournee = $date
                  AND Status = 'VERROUILLAGE_EN_COURS'
                ORDER BY CreatedUtc DESC
                LIMIT 1;
                """;
            command.Parameters.AddWithValue("$date", ToDbDate(dateTournee));

            var active = await command.ExecuteScalarAsync(cancellationToken);
            if (active is string)
            {
                throw new InvalidOperationException("Verrouillage en cours : modification temporairement bloquée.");
            }
        }

        // Blocage définitif par tournée : une tournée verrouillée ne doit plus accepter de saisie locale.
        await using (var command = connection.CreateCommand())
        {
            command.Transaction = (SqliteTransaction)transaction;
            command.CommandText = """
                SELECT IsLocked
                FROM Expedition_TourneeState
                WHERE DateTournee = $date
                  AND CodeTournee = $codeTournee
                LIMIT 1;
                """;
            command.Parameters.AddWithValue("$date", ToDbDate(dateTournee));
            command.Parameters.AddWithValue("$codeTournee", codeTournee);

            var locked = await command.ExecuteScalarAsync(cancellationToken);
            if (locked is not null && locked != DBNull.Value && Convert.ToInt32(locked) == 1)
            {
                throw new InvalidOperationException("Cette tournée est déjà verrouillée côté API. Modification refusée.");
            }
        }
    }

    private static async Task UpsertTourneeStateAsync(
        SqliteConnection connection,
        System.Data.Common.DbTransaction transaction,
        DateOnly dateTournee,
        string codeTournee,
        string status,
        DateTimeOffset now,
        string? remoteIp,
        bool enregistrerClicPretVerrouillage,
        CancellationToken cancellationToken)
    {
        // Si la tournée était déjà prête et qu'on modifie seulement une quantité, on conserve l'heure du clic prêt initial.
        var conserverDernierClicPret = IsReadyForLockStatus(status) && !enregistrerClicPretVerrouillage;

        await ExecuteAsync(connection, transaction, """
            INSERT INTO Expedition_TourneeState(DateTournee, CodeTournee, Status, IsLocked, LastModifiedUtc, LastModifiedByIp)
            VALUES ($dateTournee, $codeTournee, $status, 0, $lastModifiedUtc, $ip)
            ON CONFLICT(DateTournee, CodeTournee) DO UPDATE SET
                Status = excluded.Status,
                LastModifiedUtc = CASE
                    WHEN $conserverDernierClicPret = 1 THEN Expedition_TourneeState.LastModifiedUtc
                    ELSE excluded.LastModifiedUtc
                END,
                LastModifiedByIp = CASE
                    WHEN $conserverDernierClicPret = 1 THEN Expedition_TourneeState.LastModifiedByIp
                    ELSE excluded.LastModifiedByIp
                END;
            """, cancellationToken,
            ("$dateTournee", ToDbDate(dateTournee)),
            ("$codeTournee", codeTournee),
            ("$status", status),
            ("$lastModifiedUtc", ToDbDateTime(now)),
            ("$ip", ToDbNullable(remoteIp)),
            ("$conserverDernierClicPret", conserverDernierClicPret ? 1 : 0));
    }

    private SqliteConnection CreateConnection() => new($"Data Source={GetDatabasePath()};Cache=Shared");

    private string GetDatabasePath() => Path.IsPathRooted(_options.DatabasePath) ? _options.DatabasePath : Path.Combine(AppContext.BaseDirectory, _options.DatabasePath);

    private void EnsureDatabaseDirectoryExists()
    {
        var directory = Path.GetDirectoryName(GetDatabasePath());
        if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
    }

    private static async Task ExecuteAsync(SqliteConnection connection, string sql, CancellationToken cancellationToken, params (string Name, object? Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static async Task ExecuteAsync(SqliteConnection connection, System.Data.Common.DbTransaction transaction, string sql, CancellationToken cancellationToken, params (string Name, object? Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.Transaction = (SqliteTransaction)transaction;
        command.CommandText = sql;
        foreach (var parameter in parameters) command.Parameters.AddWithValue(parameter.Name, parameter.Value ?? DBNull.Value);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static TourneeDraftState ReadTourneeDraftState(SqliteDataReader reader) => new()
    {
        DateTournee = DateOnly.Parse(reader.GetString(0)),
        CodeTournee = reader.GetString(1),
        Status = reader.GetString(2),
        IsLocked = reader.GetInt32(3) == 1,
        LastModifiedUtc = DateTimeOffset.Parse(reader.GetString(4))
    };

    private static List<ArticleSuiviDto> BuildArticlesPrepares(List<ArticleSuiviDto> articles)
    {
        // Référentiel minimal attendu par le lot de verrouillage, avec priorité aux libellés reçus de l'API.
        var defaults = new[]
        {
            new ArticleSuiviDto { CodeArticle = "ROLLS", LibelleArticle = "Rolls pleins", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "ROLLS_VIDES", LibelleArticle = "Chariots vides", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "TAPIS", LibelleArticle = "Tapis", TypeQuantite = "LIVREE_PREVUE" },
            new ArticleSuiviDto { CodeArticle = "SACS", LibelleArticle = "Sacs", TypeQuantite = "LIVREE_PREVUE" }
        };
        return defaults.Select(d => articles.FirstOrDefault(a => string.Equals(a.CodeArticle, d.CodeArticle, StringComparison.OrdinalIgnoreCase)) ?? d).ToList();
    }

    private static bool IsReadyForLockStatus(string? status)
    {
        var normalized = status?.Trim().TrimEnd('.');
        return string.Equals(normalized, StatusReadyForLock, StringComparison.OrdinalIgnoreCase)
            || string.Equals(normalized, "PRETE_VERROUILLAGE", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsPreparedArticle(string codeArticle) =>
        string.Equals(codeArticle, "ROLLS", StringComparison.OrdinalIgnoreCase)
        || string.Equals(codeArticle, "ROLLS_VIDES", StringComparison.OrdinalIgnoreCase)
        || string.Equals(codeArticle, "TAPIS", StringComparison.OrdinalIgnoreCase)
        || string.Equals(codeArticle, "SACS", StringComparison.OrdinalIgnoreCase);

    private static DateTimeOffset? Max(DateTimeOffset? a, DateTimeOffset b) => !a.HasValue || b > a.Value ? b : a.Value;

    private static string ToDbDate(DateOnly date) => date.ToString("yyyy-MM-dd");

    private static string ToDbDateTime(DateTimeOffset date) => date.ToUniversalTime().ToString("O");

    private static object? ToDbNullable(string? value) => string.IsNullOrWhiteSpace(value) ? DBNull.Value : value;

    private static object? ToDbNullable(int? value) => value.HasValue ? value.Value : DBNull.Value;

    private static string ComputeSha256(string text)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(text));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}