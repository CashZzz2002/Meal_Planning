using MealPlanning.Admin.Application.Authentication;
using Npgsql;

namespace MealPlanning.Admin.Infrastructure.Authentication;

internal sealed class PostgresAuthenticationStore(NpgsqlDataSource dataSource) : IAuthenticationStore
{
    public async Task<AuthenticationUser?> FindActiveUserAsync(
        string normalizedUsername,
        string requiredRole,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT u."ID", u."USERNAME", u."DISPLAY_NAME", u."PASSWORD_HASH"
            FROM "USERS" u
            INNER JOIN "USER_ROLES" ur ON ur."USER_ID" = u."ID" AND ur."IS_ACTIVE"
            INNER JOIN "ROLES" r ON r."ID" = ur."ROLE_ID" AND r."IS_ACTIVE"
            WHERE LOWER(u."USERNAME") = @username
              AND u."ACCOUNT_STATUS" = 'ACTIVE'
              AND u."PASSWORD_HASH" IS NOT NULL
              AND r."CODE" = @role
            LIMIT 1;
            """;

        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("username", normalizedUsername);
        command.Parameters.AddWithValue("role", requiredRole);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken)
            ? new AuthenticationUser(
                reader.GetGuid(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetString(3))
            : null;
    }

    public async Task CreateSessionAsync(
        Guid sessionId,
        Guid userId,
        string context,
        string tokenHash,
        DateTimeOffset createdAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken)
    {
        const string sql = """
            INSERT INTO "AUTH_SESSIONS"
              ("ID", "USER_ID", "CONTEXT", "TOKEN_HASH", "CREATED_AT", "EXPIRES_AT")
            VALUES (@id, @userId, @context, @tokenHash, @createdAt, @expiresAt);
            """;
        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("id", sessionId);
        command.Parameters.AddWithValue("userId", userId);
        command.Parameters.AddWithValue("context", context);
        command.Parameters.AddWithValue("tokenHash", tokenHash);
        command.Parameters.AddWithValue("createdAt", createdAt);
        command.Parameters.AddWithValue("expiresAt", expiresAt);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task<AuthenticationSession?> FindSessionAsync(
        string tokenHash,
        string context,
        string requiredRole,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT u."ID", u."USERNAME", u."DISPLAY_NAME", s."EXPIRES_AT",
              ARRAY(
                SELECT role_claim."CODE"
                FROM "USER_ROLES" role_assignment
                INNER JOIN "ROLES" role_claim ON role_claim."ID" = role_assignment."ROLE_ID"
                WHERE role_assignment."USER_ID" = u."ID"
                  AND role_assignment."IS_ACTIVE"
                  AND role_claim."IS_ACTIVE"
                ORDER BY role_claim."CODE")
            FROM "AUTH_SESSIONS" s
            INNER JOIN "USERS" u ON u."ID" = s."USER_ID"
            INNER JOIN "USER_ROLES" ur ON ur."USER_ID" = u."ID" AND ur."IS_ACTIVE"
            INNER JOIN "ROLES" r ON r."ID" = ur."ROLE_ID" AND r."IS_ACTIVE"
            WHERE s."TOKEN_HASH" = @tokenHash
              AND s."CONTEXT" = @context
              AND s."REVOKED_AT" IS NULL
              AND s."EXPIRES_AT" > @now
              AND u."ACCOUNT_STATUS" = 'ACTIVE'
              AND r."CODE" = @role
            LIMIT 1;
            """;
        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("tokenHash", tokenHash);
        command.Parameters.AddWithValue("context", context);
        command.Parameters.AddWithValue("now", now);
        command.Parameters.AddWithValue("role", requiredRole);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        return await reader.ReadAsync(cancellationToken)
            ? new AuthenticationSession(
                reader.GetGuid(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetFieldValue<DateTimeOffset>(3),
                reader.GetFieldValue<string[]>(4))
            : null;
    }

    public async Task RevokeSessionAsync(
        string tokenHash,
        string context,
        DateTimeOffset revokedAt,
        CancellationToken cancellationToken)
    {
        const string sql = """
            UPDATE "AUTH_SESSIONS"
            SET "REVOKED_AT" = @revokedAt
            WHERE "TOKEN_HASH" = @tokenHash
              AND "CONTEXT" = @context
              AND "REVOKED_AT" IS NULL;
            """;
        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("revokedAt", revokedAt);
        command.Parameters.AddWithValue("tokenHash", tokenHash);
        command.Parameters.AddWithValue("context", context);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
