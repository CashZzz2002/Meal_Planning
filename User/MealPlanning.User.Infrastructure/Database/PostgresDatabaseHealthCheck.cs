using Microsoft.Extensions.Diagnostics.HealthChecks;
using Npgsql;

namespace MealPlanning.User.Infrastructure.Database;

internal sealed class PostgresDatabaseHealthCheck(NpgsqlDataSource dataSource) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using var command = dataSource.CreateCommand(
                "SELECT CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Yangon'");
            var databaseTime = await command.ExecuteScalarAsync(cancellationToken);

            return HealthCheckResult.Healthy(
                "Neon Postgres is reachable.",
                new Dictionary<string, object>
                {
                    ["myanmarDatabaseTime"] = databaseTime?.ToString() ?? string.Empty
                });
        }
        catch (Exception exception)
        {
            return HealthCheckResult.Unhealthy("Neon Postgres is not reachable.", exception);
        }
    }
}

internal static class PostgresConnectionString
{
    public static string Normalize(string value)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) ||
            (uri.Scheme != "postgres" && uri.Scheme != "postgresql"))
        {
            var existing = new NpgsqlConnectionStringBuilder(value);
            existing.Options = MergeMyanmarTimeOption(existing.Options);
            return existing.ConnectionString;
        }

        var credentials = uri.UserInfo.Split(':', 2);
        if (credentials.Length != 2)
        {
            throw new InvalidOperationException("The Neon DATABASE_URL does not contain a username and password.");
        }

        var builder = new NpgsqlConnectionStringBuilder
        {
            Host = uri.Host,
            Port = uri.IsDefaultPort ? 5432 : uri.Port,
            Database = Uri.UnescapeDataString(uri.AbsolutePath.TrimStart('/')),
            Username = Uri.UnescapeDataString(credentials[0]),
            Password = Uri.UnescapeDataString(credentials[1]),
            SslMode = SslMode.Require,
            Options = "-c TimeZone=Asia/Yangon"
        };

        foreach (var pair in uri.Query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var parts = pair.Split('=', 2);
            var key = Uri.UnescapeDataString(parts[0]);
            var queryValue = parts.Length == 2 ? Uri.UnescapeDataString(parts[1]) : string.Empty;
            if (key.Equals("channel_binding", StringComparison.OrdinalIgnoreCase))
            {
                builder["Channel Binding"] = queryValue;
            }
        }

        return builder.ConnectionString;
    }

    private static string MergeMyanmarTimeOption(string? options) =>
        string.IsNullOrWhiteSpace(options)
            ? "-c TimeZone=Asia/Yangon"
            : $"{options} -c TimeZone=Asia/Yangon";
}
