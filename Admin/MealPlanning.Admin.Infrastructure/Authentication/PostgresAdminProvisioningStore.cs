using MealPlanning.Admin.Application.Authentication;
using Npgsql;

namespace MealPlanning.Admin.Infrastructure.Authentication;

internal sealed class PostgresAdminProvisioningStore(NpgsqlDataSource dataSource) : IAdminProvisioningStore
{
    public async Task<bool> CreateRequestAsync(
        Guid requestId,
        string username,
        string displayName,
        string email,
        DateTimeOffset requestedAt,
        CancellationToken cancellationToken)
    {
        const string sql = """
            INSERT INTO "ADMIN_ACCOUNT_REQUESTS"
              ("ID", "USERNAME", "DISPLAY_NAME", "EMAIL", "STATUS", "REQUESTED_AT")
            SELECT @id, @username, @displayName, @email, 'PENDING', @requestedAt
            WHERE NOT EXISTS (
              SELECT 1 FROM "USERS"
              WHERE LOWER("USERNAME") = @username OR LOWER("EMAIL") = @email);
            """;
        try
        {
            await using var command = dataSource.CreateCommand(sql);
            command.Parameters.AddWithValue("id", requestId);
            command.Parameters.AddWithValue("username", username);
            command.Parameters.AddWithValue("displayName", displayName);
            command.Parameters.AddWithValue("email", email);
            command.Parameters.AddWithValue("requestedAt", requestedAt);
            return await command.ExecuteNonQueryAsync(cancellationToken) == 1;
        }
        catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            return false;
        }
    }

    public async Task<IReadOnlyList<AdminAccountRequest>> ListPendingRequestsAsync(CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT "ID", "USERNAME", "DISPLAY_NAME", "EMAIL", "REQUESTED_AT"
            FROM "ADMIN_ACCOUNT_REQUESTS"
            WHERE "STATUS" = 'PENDING'
            ORDER BY "REQUESTED_AT";
            """;
        var requests = new List<AdminAccountRequest>();
        await using var command = dataSource.CreateCommand(sql);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            requests.Add(new AdminAccountRequest(
                reader.GetGuid(0), reader.GetString(1), reader.GetString(2), reader.GetString(3),
                reader.GetFieldValue<DateTimeOffset>(4)));
        }
        return requests;
    }

    public async Task<ApprovedAdminInvitation?> ApproveRequestAsync(
        Guid requestId,
        Guid reviewerUserId,
        Guid userId,
        Guid challengeId,
        string invitationTokenHash,
        DateTimeOffset reviewedAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken)
    {
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
        try
        {
            const string requestSql = """
                SELECT "USERNAME", "DISPLAY_NAME", "EMAIL"
                FROM "ADMIN_ACCOUNT_REQUESTS"
                WHERE "ID" = @id AND "STATUS" = 'PENDING'
                FOR UPDATE;
                """;
            string username;
            string displayName;
            string email;
            await using (var request = new NpgsqlCommand(requestSql, connection, transaction))
            {
                request.Parameters.AddWithValue("id", requestId);
                await using var reader = await request.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken)) return null;
                username = reader.GetString(0);
                displayName = reader.GetString(1);
                email = reader.GetString(2);
            }

            const string userSql = """
                INSERT INTO "USERS"
                  ("ID", "PHONE", "USERNAME", "DISPLAY_NAME", "EMAIL", "PASSWORD_HASH",
                   "ACCOUNT_STATUS", "PHONE_VERIFIED_AT", "CREATED_AT")
                VALUES (@id, NULL, @username, @displayName, @email, NULL, 'INVITED', NULL, @createdAt);
                """;
            await using (var user = new NpgsqlCommand(userSql, connection, transaction))
            {
                user.Parameters.AddWithValue("id", userId);
                user.Parameters.AddWithValue("username", username);
                user.Parameters.AddWithValue("displayName", displayName);
                user.Parameters.AddWithValue("email", email);
                user.Parameters.AddWithValue("createdAt", reviewedAt);
                await user.ExecuteNonQueryAsync(cancellationToken);
            }

            const string roleSql = """
                INSERT INTO "USER_ROLES" ("ID", "USER_ID", "ROLE_ID", "IS_ACTIVE")
                SELECT @id, @userId, "ID", TRUE
                FROM "ROLES" WHERE "CODE" = 'ADMIN' AND "IS_ACTIVE";
                """;
            await using (var role = new NpgsqlCommand(roleSql, connection, transaction))
            {
                role.Parameters.AddWithValue("id", Guid.NewGuid());
                role.Parameters.AddWithValue("userId", userId);
                if (await role.ExecuteNonQueryAsync(cancellationToken) != 1)
                {
                    throw new InvalidOperationException("The active ADMIN role was not found.");
                }
            }

            const string challengeSql = """
                INSERT INTO "AUTH_EMAIL_CHALLENGES"
                  ("ID", "USER_ID", "PURPOSE", "SECRET_HASH", "CREATED_AT", "EXPIRES_AT", "FAILED_ATTEMPTS")
                VALUES (@id, @userId, 'ADMIN_INVITATION', @secretHash, @createdAt, @expiresAt, 0);
                """;
            await using (var challenge = new NpgsqlCommand(challengeSql, connection, transaction))
            {
                challenge.Parameters.AddWithValue("id", challengeId);
                challenge.Parameters.AddWithValue("userId", userId);
                challenge.Parameters.AddWithValue("secretHash", invitationTokenHash);
                challenge.Parameters.AddWithValue("createdAt", reviewedAt);
                challenge.Parameters.AddWithValue("expiresAt", expiresAt);
                await challenge.ExecuteNonQueryAsync(cancellationToken);
            }

            const string approvalSql = """
                UPDATE "ADMIN_ACCOUNT_REQUESTS"
                SET "STATUS" = 'APPROVED', "REVIEWED_BY_USER_ID" = @reviewerId, "REVIEWED_AT" = @reviewedAt
                WHERE "ID" = @id;
                """;
            await using (var approval = new NpgsqlCommand(approvalSql, connection, transaction))
            {
                approval.Parameters.AddWithValue("reviewerId", reviewerUserId);
                approval.Parameters.AddWithValue("reviewedAt", reviewedAt);
                approval.Parameters.AddWithValue("id", requestId);
                await approval.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
            return new ApprovedAdminInvitation(userId, displayName, email, challengeId, expiresAt);
        }
        catch (PostgresException exception) when (exception.SqlState == PostgresErrorCodes.UniqueViolation)
        {
            await transaction.RollbackAsync(cancellationToken);
            return null;
        }
    }

    public async Task<bool> CompleteInvitationAsync(
        string invitationTokenHash,
        string passwordHash,
        DateTimeOffset now,
        CancellationToken cancellationToken)
    {
        const string sql = """
            WITH selected AS (
              SELECT c."ID", c."USER_ID"
              FROM "AUTH_EMAIL_CHALLENGES" c
              INNER JOIN "USERS" u ON u."ID" = c."USER_ID"
              WHERE c."PURPOSE" = 'ADMIN_INVITATION'
                AND c."SECRET_HASH" = @secretHash
                AND c."CONSUMED_AT" IS NULL
                AND c."EXPIRES_AT" > @now
                AND u."ACCOUNT_STATUS" = 'INVITED'
              FOR UPDATE OF c, u
            ), activated AS (
              UPDATE "USERS" u
              SET "PASSWORD_HASH" = @passwordHash, "ACCOUNT_STATUS" = 'ACTIVE'
              FROM selected s
              WHERE u."ID" = s."USER_ID"
              RETURNING s."ID"
            )
            UPDATE "AUTH_EMAIL_CHALLENGES" c
            SET "CONSUMED_AT" = @now
            FROM activated a
            WHERE c."ID" = a."ID";
            """;
        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue("secretHash", invitationTokenHash);
        command.Parameters.AddWithValue("passwordHash", passwordHash);
        command.Parameters.AddWithValue("now", now);
        return await command.ExecuteNonQueryAsync(cancellationToken) == 1;
    }
}
