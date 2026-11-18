using System.Security.Cryptography;
using System.Text;
using System.Net.Mail;
using Npgsql;

const string safeBranchPattern = "^(?!main$|default$|production$|prod$).+";
var command = args.Length > 0 ? args[0].ToLowerInvariant() : string.Empty;
if (command is not ("migrate" or "seed" or "verify" or "verify-email-auth" or "bootstrap-master-admin" or "promote-master-admin" or "verify-master-admin"))
{
    Console.Error.WriteLine("Usage: dotnet run --project scripts/MealPlanning.AuthSeeder -- <migrate|seed|verify|verify-email-auth|bootstrap-master-admin|verify-master-admin> OR promote-master-admin <username>");
    return 2;
}

var repositoryPath = FindRepositoryPath(AppContext.BaseDirectory);
var environment = ReadEnvironment(Path.Combine(repositoryPath, ".env.local"));
var branch = environment.GetValueOrDefault("NEON_BRANCH") ?? string.Empty;
if (!System.Text.RegularExpressions.Regex.IsMatch(branch, safeBranchPattern, System.Text.RegularExpressions.RegexOptions.IgnoreCase))
{
    Console.Error.WriteLine("Refusing to modify a default or production Neon branch.");
    return 3;
}

var connectionValue = environment.GetValueOrDefault("DATABASE_URL_UNPOOLED")
    ?? throw new InvalidOperationException("DATABASE_URL_UNPOOLED is required in .env.local.");
await using var connection = new NpgsqlConnection(NormalizeConnectionString(connectionValue));
await connection.OpenAsync();

if (command == "migrate")
{
    var migrationDirectory = Path.Combine(repositoryPath, "Database", "PostgreSql");
    foreach (var migrationName in new[]
    {
        "004_authentication.sql",
        "005_master_admin_role.sql",
        "006_email_authentication.sql"
    })
    {
        var sql = await File.ReadAllTextAsync(Path.Combine(migrationDirectory, migrationName));
        await using var migration = new NpgsqlCommand(sql, connection) { CommandTimeout = 120 };
        await migration.ExecuteNonQueryAsync();
    }
    Console.WriteLine($"Authentication, master-admin, and email-authentication migrations applied to child branch '{branch}'.");
    return 0;
}

if (command == "verify-master-admin")
{
    const string verifyMasterSql = """
        SELECT COUNT(*)
        FROM "USERS" u
        WHERE u."ACCOUNT_STATUS" = 'ACTIVE'
          AND u."PASSWORD_HASH" IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM "USER_ROLES" ur
            INNER JOIN "ROLES" r ON r."ID" = ur."ROLE_ID"
            WHERE ur."USER_ID" = u."ID" AND ur."IS_ACTIVE" AND r."IS_ACTIVE" AND r."CODE" = 'ADMIN')
          AND EXISTS (
            SELECT 1
            FROM "USER_ROLES" ur
            INNER JOIN "ROLES" r ON r."ID" = ur."ROLE_ID"
            WHERE ur."USER_ID" = u."ID" AND ur."IS_ACTIVE" AND r."IS_ACTIVE" AND r."CODE" = 'SUPER_ADMIN');
        """;
    await using var verifyMaster = new NpgsqlCommand(verifyMasterSql, connection);
    var count = (long)(await verifyMaster.ExecuteScalarAsync() ?? 0L);
    Console.WriteLine($"Master-admin verification: activeMasterAdminRows={count}.");
    return count > 0 ? 0 : 6;
}

if (command == "verify-email-auth")
{
    const string verifyEmailAuthSql = """
        SELECT
          to_regclass(format('%I.%I', current_schema(), 'ADMIN_ACCOUNT_REQUESTS')) IS NOT NULL,
          to_regclass(format('%I.%I', current_schema(), 'AUTH_EMAIL_CHALLENGES')) IS NOT NULL,
          to_regclass(format('%I.%I', current_schema(), 'UK_USERS_EMAIL_CI')) IS NOT NULL;
        """;
    await using var verifyEmailAuth = new NpgsqlCommand(verifyEmailAuthSql, connection);
    await using var emailReader = await verifyEmailAuth.ExecuteReaderAsync();
    await emailReader.ReadAsync();
    var requestsTable = emailReader.GetBoolean(0);
    var challengesTable = emailReader.GetBoolean(1);
    var emailIndex = emailReader.GetBoolean(2);
    Console.WriteLine($"Email-auth schema verification: adminRequests={requestsTable}, challenges={challengesTable}, uniqueEmailIndex={emailIndex}.");
    return requestsTable && challengesTable && emailIndex ? 0 : 10;
}

if (command == "promote-master-admin")
{
    if (args.Length != 2 || string.IsNullOrWhiteSpace(args[1]))
    {
        Console.Error.WriteLine("Usage: promote-master-admin <username>");
        return 8;
    }

    var username = args[1].Trim().ToLowerInvariant();
    const string promoteSql = """
        INSERT INTO "USER_ROLES" ("ID", "USER_ID", "ROLE_ID", "IS_ACTIVE")
        SELECT @assignmentId, u."ID", superRole."ID", TRUE
        FROM "USERS" u
        CROSS JOIN "ROLES" superRole
        WHERE LOWER(u."USERNAME") = @username
          AND u."ACCOUNT_STATUS" = 'ACTIVE'
          AND u."PASSWORD_HASH" IS NOT NULL
          AND superRole."CODE" = 'SUPER_ADMIN'
          AND superRole."IS_ACTIVE"
          AND EXISTS (
            SELECT 1
            FROM "USER_ROLES" ur
            INNER JOIN "ROLES" adminRole ON adminRole."ID" = ur."ROLE_ID"
            WHERE ur."USER_ID" = u."ID"
              AND ur."IS_ACTIVE"
              AND adminRole."IS_ACTIVE"
              AND adminRole."CODE" = 'ADMIN')
        ON CONFLICT ("USER_ID", "ROLE_ID") DO UPDATE SET "IS_ACTIVE" = TRUE;
        """;
    await using var promote = new NpgsqlCommand(promoteSql, connection);
    promote.Parameters.AddWithValue("assignmentId", Guid.NewGuid());
    promote.Parameters.AddWithValue("username", username);
    if (await promote.ExecuteNonQueryAsync() != 1)
    {
        Console.Error.WriteLine("Promotion failed: an active credentialed ADMIN with that username was not found.");
        return 9;
    }

    Console.WriteLine($"Existing Admin promoted to Master Admin on child branch '{branch}'.");
    return 0;
}

if (command == "verify")
{
    const string verifySql = """
        SELECT
          (SELECT COUNT(*) FROM "USERS" WHERE "USERNAME" IN ('admin', 'user') AND "PASSWORD_HASH" IS NOT NULL),
          (SELECT COUNT(*) FROM "USER_ROLES" ur
             INNER JOIN "ROLES" r ON r."ID" = ur."ROLE_ID"
             INNER JOIN "USERS" u ON u."ID" = ur."USER_ID"
           WHERE u."USERNAME" IN ('admin', 'user') AND r."CODE" IN ('ADMIN', 'USER') AND ur."IS_ACTIVE");
        """;
    await using var verify = new NpgsqlCommand(verifySql, connection);
    await using var reader = await verify.ExecuteReaderAsync();
    await reader.ReadAsync();
    Console.WriteLine($"Authentication verification: credentialRows={reader.GetInt64(0)}, activeRoleRows={reader.GetInt64(1)}.");
    return reader.GetInt64(0) == 2 && reader.GetInt64(1) == 2 ? 0 : 4;
}

if (command == "bootstrap-master-admin")
{
    Console.Write("Master Admin username: ");
    var username = (Console.ReadLine() ?? string.Empty).Trim().ToLowerInvariant();
    Console.Write("Master Admin display name: ");
    var displayName = (Console.ReadLine() ?? string.Empty).Trim();
    Console.Write("Master Admin email: ");
    var email = (Console.ReadLine() ?? string.Empty).Trim().ToLowerInvariant();
    Console.Write("Master Admin password (input hidden): ");
    var masterPassword = ReadPassword();
    Console.WriteLine();

    if (username.Length is < 3 or > 200 || displayName.Length is < 1 or > 1000 || !IsValidEmail(email))
    {
        Console.Error.WriteLine("Username, display name, or email is invalid.");
        return 7;
    }
    if (masterPassword.Length < 12)
    {
        Console.Error.WriteLine("Master Admin password must contain at least 12 characters.");
        return 5;
    }

    var masterPasswordHash = HashPassword(masterPassword);
    masterPassword = string.Empty;
    await using var masterTransaction = await connection.BeginTransactionAsync();
    const string masterUserSql = """
        INSERT INTO "USERS"
          ("ID", "PHONE", "USERNAME", "DISPLAY_NAME", "EMAIL", "PASSWORD_HASH", "ACCOUNT_STATUS", "PHONE_VERIFIED_AT", "CREATED_AT")
        VALUES (@id, NULL, @username, @displayName, @email, @passwordHash, 'ACTIVE', NULL, CURRENT_TIMESTAMP)
        ON CONFLICT ("USERNAME") DO UPDATE SET
          "DISPLAY_NAME" = EXCLUDED."DISPLAY_NAME",
          "EMAIL" = EXCLUDED."EMAIL",
          "PASSWORD_HASH" = EXCLUDED."PASSWORD_HASH",
          "ACCOUNT_STATUS" = 'ACTIVE'
        RETURNING "ID";
        """;
    await using var masterUserCommand = new NpgsqlCommand(masterUserSql, connection, masterTransaction);
    masterUserCommand.Parameters.AddWithValue("id", Guid.NewGuid());
    masterUserCommand.Parameters.AddWithValue("username", username);
    masterUserCommand.Parameters.AddWithValue("displayName", displayName);
    masterUserCommand.Parameters.AddWithValue("email", email);
    masterUserCommand.Parameters.AddWithValue("passwordHash", masterPasswordHash);
    var masterUserId = (Guid)(await masterUserCommand.ExecuteScalarAsync()
        ?? throw new InvalidOperationException("Master Admin insert failed."));

    const string masterRoleSql = """
        INSERT INTO "USER_ROLES" ("ID", "USER_ID", "ROLE_ID", "IS_ACTIVE")
        SELECT @assignmentId, @userId, "ID", TRUE
        FROM "ROLES"
        WHERE "CODE" = @role AND "IS_ACTIVE"
        ON CONFLICT ("USER_ID", "ROLE_ID") DO UPDATE SET "IS_ACTIVE" = TRUE;
        """;
    foreach (var role in new[] { "ADMIN", "SUPER_ADMIN" })
    {
        await using var masterRoleCommand = new NpgsqlCommand(masterRoleSql, connection, masterTransaction);
        masterRoleCommand.Parameters.AddWithValue("assignmentId", Guid.NewGuid());
        masterRoleCommand.Parameters.AddWithValue("userId", masterUserId);
        masterRoleCommand.Parameters.AddWithValue("role", role);
        if (await masterRoleCommand.ExecuteNonQueryAsync() != 1)
        {
            throw new InvalidOperationException($"Required role '{role}' was not found. Run migrate first.");
        }
    }

    await masterTransaction.CommitAsync();
    Console.WriteLine($"Master Admin bootstrapped on child branch '{branch}'.");
    return 0;
}

Console.Write("Bootstrap password (input hidden): ");
var password = ReadPassword();
Console.WriteLine();
if (password.Length < 12)
{
    Console.Error.WriteLine("Bootstrap password must contain at least 12 characters.");
    return 5;
}

var passwordHash = HashPassword(password);
password = string.Empty;
await using var transaction = await connection.BeginTransactionAsync();
const string userSql = """
    INSERT INTO "USERS"
      ("ID", "PHONE", "USERNAME", "DISPLAY_NAME", "EMAIL", "PASSWORD_HASH", "ACCOUNT_STATUS", "PHONE_VERIFIED_AT", "CREATED_AT")
    VALUES (@id, NULL, @username, @displayName, NULL, @passwordHash, 'ACTIVE', NULL, CURRENT_TIMESTAMP)
    ON CONFLICT ("USERNAME") DO UPDATE SET
      "DISPLAY_NAME" = EXCLUDED."DISPLAY_NAME",
      "PASSWORD_HASH" = EXCLUDED."PASSWORD_HASH",
      "ACCOUNT_STATUS" = 'ACTIVE'
    RETURNING "ID";
    """;
const string roleSql = """
    INSERT INTO "USER_ROLES" ("ID", "USER_ID", "ROLE_ID", "IS_ACTIVE")
    SELECT @assignmentId, @userId, "ID", TRUE FROM "ROLES" WHERE "CODE" = @role
    ON CONFLICT ("USER_ID", "ROLE_ID") DO UPDATE SET "IS_ACTIVE" = TRUE;
    """;
var seeds = new[]
{
    new Seed(Guid.Parse("50000000-0000-0000-0000-000000000001"), "admin", "Local Administrator", "ADMIN"),
    new Seed(Guid.Parse("50000000-0000-0000-0000-000000000002"), "user", "Local Meal Planner", "USER")
};
foreach (var seed in seeds)
{
    await using var userCommand = new NpgsqlCommand(userSql, connection, transaction);
    userCommand.Parameters.AddWithValue("id", seed.Id);
    userCommand.Parameters.AddWithValue("username", seed.Username);
    userCommand.Parameters.AddWithValue("displayName", seed.DisplayName);
    userCommand.Parameters.AddWithValue("passwordHash", passwordHash);
    var userId = (Guid)(await userCommand.ExecuteScalarAsync() ?? throw new InvalidOperationException("User seed failed."));

    await using var roleCommand = new NpgsqlCommand(roleSql, connection, transaction);
    roleCommand.Parameters.AddWithValue("assignmentId", Guid.NewGuid());
    roleCommand.Parameters.AddWithValue("userId", userId);
    roleCommand.Parameters.AddWithValue("role", seed.Role);
    if (await roleCommand.ExecuteNonQueryAsync() != 1) throw new InvalidOperationException("Role seed failed.");
}
await transaction.CommitAsync();
Console.WriteLine($"Seeded two local authentication users on child branch '{branch}'.");
return 0;

static string FindRepositoryPath(string start)
{
    var directory = new DirectoryInfo(start);
    while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "MealPlanning.sln"))) directory = directory.Parent;
    return directory?.FullName ?? throw new InvalidOperationException("Repository root was not found.");
}

static Dictionary<string, string> ReadEnvironment(string path)
{
    if (!File.Exists(path)) throw new InvalidOperationException(".env.local is required.");
    return File.ReadLines(path)
        .Where(line => !string.IsNullOrWhiteSpace(line) && !line.TrimStart().StartsWith('#') && line.Contains('='))
        .Select(line => line.Split('=', 2))
        .ToDictionary(parts => parts[0].Trim(), parts => parts[1].Trim().Trim('"', '\''), StringComparer.OrdinalIgnoreCase);
}

static string NormalizeConnectionString(string value)
{
    if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || (uri.Scheme != "postgres" && uri.Scheme != "postgresql")) return value;
    var credentials = uri.UserInfo.Split(':', 2);
    return new NpgsqlConnectionStringBuilder
    {
        Host = uri.Host,
        Port = uri.IsDefaultPort ? 5432 : uri.Port,
        Database = Uri.UnescapeDataString(uri.AbsolutePath.TrimStart('/')),
        Username = Uri.UnescapeDataString(credentials[0]),
        Password = Uri.UnescapeDataString(credentials[1]),
        SslMode = SslMode.Require
    }.ConnectionString;
}

static string ReadPassword()
{
    var value = new StringBuilder();
    while (true)
    {
        var key = Console.ReadKey(intercept: true);
        if (key.Key == ConsoleKey.Enter) return value.ToString();
        if (key.Key == ConsoleKey.Backspace && value.Length > 0) value.Length--;
        else if (!char.IsControl(key.KeyChar)) value.Append(key.KeyChar);
    }
}

static bool IsValidEmail(string value)
{
    if (value.Length > 1000) return false;
    try
    {
        return new MailAddress(value).Address.Equals(value, StringComparison.OrdinalIgnoreCase);
    }
    catch (FormatException)
    {
        return false;
    }
}

static string HashPassword(string password)
{
    const int iterations = 210_000;
    var salt = RandomNumberGenerator.GetBytes(16);
    var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, 32);
    return $"PBKDF2-SHA256${iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
}

internal sealed record Seed(Guid Id, string Username, string DisplayName, string Role);
