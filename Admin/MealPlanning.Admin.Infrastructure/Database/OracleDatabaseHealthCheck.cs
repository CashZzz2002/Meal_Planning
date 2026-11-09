using Microsoft.Extensions.Diagnostics.HealthChecks;
using Oracle.ManagedDataAccess.Client;

namespace MealPlanning.Admin.Infrastructure.Database;

internal sealed class OracleDatabaseHealthCheck(OracleDatabaseOptions options) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = new OracleConnection(options.ConnectionString);
            await connection.OpenAsync(cancellationToken);
            await using var command = connection.CreateCommand();
            command.CommandText = "SELECT CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Yangon' FROM DUAL";
            var databaseTime = await command.ExecuteScalarAsync(cancellationToken);

            return HealthCheckResult.Healthy(
                "Oracle database is reachable.",
                new Dictionary<string, object> { ["myanmarDatabaseTime"] = databaseTime?.ToString() ?? string.Empty });
        }
        catch (Exception exception)
        {
            return HealthCheckResult.Unhealthy("Oracle database is not reachable.", exception);
        }
    }
}

internal sealed record OracleDatabaseOptions(string ConnectionString);
