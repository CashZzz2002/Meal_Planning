using MealPlanning.User.Application.Authentication;
using Npgsql;

namespace MealPlanning.User.Infrastructure.Authentication;

internal sealed class PostgresUserRegistrationStore(NpgsqlDataSource dataSource) : IUserRegistrationStore
{
    public async Task<PendingRegistrationResult> CreatePendingUserAsync(
        Guid userId,
        string username,
        string displayName,
        string email,
        string passwordHash,
        Guid challengeId,
        string codeHash,
        DateTimeOffset createdAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken)
    {
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            const string userSql = """
                INSERT INTO "USERS"
                  ("ID", "PHONE", "USERNAME", "DISPLAY_NAME", "EMAIL", "PASSWORD_HASH",
                   "ACCOUNT_STATUS", "PHONE_VERIFIED_AT", "CREATED_AT")
                VALUES (@id, NULL, @username, @displayName, @email, @passwordHash,
                        'PENDING_EMAIL_VERIFICATION', NULL, @createdAt);
                """;
            await using (var user = new NpgsqlCommand(userSql, connection, transaction))
            {
                user.Parameters.AddWithValue("id", userId);
                user.Parameters.AddWithValue("username", username);
                user.Parameters.AddWithValue("displayName", displayName);
                user.Parameters.AddWithValue("email", email);
                user.Parameters.AddWithValue("passwordHash", passwordHash);
                user.Parameters.AddWithValue("createdAt", createdAt);
                await user.ExecuteNonQueryAsync(cancellationToken);
            }

            const string roleSql = """
                INSERT INTO "USER_ROLES" ("ID", "USER_ID", "ROLE_ID", "IS_ACTIVE")
                SELECT @id, @userId, "ID", TRUE FROM "ROLES"
                WHERE "CODE" = 'USER' AND "IS_ACTIVE";
                """;
            await using (var role = new NpgsqlCommand(roleSql, connection, transaction))
            {
                role.Parameters.AddWithValue("id", Guid.NewGuid());
                role.Parameters.AddWithValue("userId", userId);
                if (await role.ExecuteNonQueryAsync(cancellationToken) != 1)
                {
                    throw new InvalidOperationException("The active USER role was not found.");
                }
            }

            await InsertChallengeAsync(
                connection, transaction, challengeId, userId, codeHash, createdAt, expiresAt, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return PendingRegistrationResult.Created;
        }
        catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            await transaction.RollbackAsync(cancellationToken);
            return PendingRegistrationResult.Conflict;
        }
    }

    public async Task<EmailVerificationChallenge?> FindVerificationChallengeAsync(
        string email,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT c."ID", c."USER_ID", c."SECRET_HASH", c."FAILED_ATTEMPTS"
            FROM "AUTH_EMAIL_CHALLENGES" c
            INNER JOIN "USERS" u ON u."ID" = c."USER_ID"
            WHERE LOWER(u."EMAIL") = @email
              AND u."ACCOUNT_STATUS" = 'PENDING_EMAIL_VERIFICATION'
              AND c."PURPOSE" = 'USER_EMAIL_VERIFICATION'
              AND c."CONSUMED_AT" IS NULL
              AND c."EXPIRES_AT" > @now
            ORDER BY c."CREATED_AT" DESC
            LIMIT 1;
            """;
        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("email", email);
        command.Parameters.AddWithValue("now", now);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken)
            ? new EmailVerificationChallenge(
                reader.GetGuid(0), reader.GetGuid(1), reader.GetString(2), reader.GetInt32(3))
            : null;
    }

    public async Task RecordFailedAttemptAsync(Guid challengeId, CancellationToken cancellationToken)
    {
        const string sql = """
            UPDATE "AUTH_EMAIL_CHALLENGES"
            SET "FAILED_ATTEMPTS" = "FAILED_ATTEMPTS" + 1
            WHERE "ID" = @id AND "CONSUMED_AT" IS NULL;
            """;
        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("id", challengeId);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<bool> ActivateUserAsync(
        Guid challengeId,
        Guid userId,
        DateTimeOffset verifiedAt,
        CancellationToken cancellationToken)
    {
        const string sql = """
            WITH consumed AS (
              UPDATE "AUTH_EMAIL_CHALLENGES"
              SET "CONSUMED_AT" = @verifiedAt
              WHERE "ID" = @challengeId
                AND "USER_ID" = @userId
                AND "CONSUMED_AT" IS NULL
                AND "EXPIRES_AT" > @verifiedAt
                AND "FAILED_ATTEMPTS" < 5
              RETURNING "USER_ID"
            )
            UPDATE "USERS" u
            SET "ACCOUNT_STATUS" = 'ACTIVE'
            FROM consumed c
            WHERE u."ID" = c."USER_ID"
              AND u."ACCOUNT_STATUS" = 'PENDING_EMAIL_VERIFICATION';
            """;
        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("challengeId", challengeId);
        command.Parameters.AddWithValue("userId", userId);
        command.Parameters.AddWithValue("verifiedAt", verifiedAt);
        return await command.ExecuteNonQueryAsync(cancellationToken) == 1;
    }

    public async Task<PendingUserForEmail?> ReplaceVerificationChallengeAsync(
        string email,
        Guid challengeId,
        string codeHash,
        DateTimeOffset createdAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken)
    {
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        const string userSql = """
            SELECT "ID", "DISPLAY_NAME", "EMAIL"
            FROM "USERS"
            WHERE LOWER("EMAIL") = @email AND "ACCOUNT_STATUS" = 'PENDING_EMAIL_VERIFICATION'
            FOR UPDATE;
            """;
        PendingUserForEmail? pendingUser;
        await using (var user = new NpgsqlCommand(userSql, connection, transaction))
        {
            user.Parameters.AddWithValue("email", email);
            await using var reader = await user.ExecuteReaderAsync(cancellationToken);
            pendingUser = await reader.ReadAsync(cancellationToken)
                ? new PendingUserForEmail(reader.GetGuid(0), reader.GetString(1), reader.GetString(2))
                : null;
        }
        if (pendingUser is null) return null;

        const string consumeSql = """
            UPDATE "AUTH_EMAIL_CHALLENGES"
            SET "CONSUMED_AT" = @createdAt
            WHERE "USER_ID" = @userId
              AND "PURPOSE" = 'USER_EMAIL_VERIFICATION'
              AND "CONSUMED_AT" IS NULL;
            """;
        await using (var consume = new NpgsqlCommand(consumeSql, connection, transaction))
        {
            consume.Parameters.AddWithValue("createdAt", createdAt);
            consume.Parameters.AddWithValue("userId", pendingUser.UserId);
            await consume.ExecuteNonQueryAsync(cancellationToken);
        }

        await InsertChallengeAsync(
            connection, transaction, challengeId, pendingUser.UserId, codeHash, createdAt, expiresAt, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return pendingUser;
    }

    private static async Task InsertChallengeAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        Guid challengeId,
        Guid userId,
        string codeHash,
        DateTimeOffset createdAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken)
    {
        const string sql = """
            INSERT INTO "AUTH_EMAIL_CHALLENGES"
              ("ID", "USER_ID", "PURPOSE", "SECRET_HASH", "CREATED_AT", "EXPIRES_AT", "FAILED_ATTEMPTS")
            VALUES (@id, @userId, 'USER_EMAIL_VERIFICATION', @secretHash, @createdAt, @expiresAt, 0);
            """;
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.AddWithValue("id", challengeId);
        command.Parameters.AddWithValue("userId", userId);
        command.Parameters.AddWithValue("secretHash", codeHash);
        command.Parameters.AddWithValue("createdAt", createdAt);
        command.Parameters.AddWithValue("expiresAt", expiresAt);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
