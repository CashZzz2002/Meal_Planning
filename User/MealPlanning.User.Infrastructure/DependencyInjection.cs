using MealPlanning.User.Application.MealTypes;
using MealPlanning.User.Application.Time;
using MealPlanning.User.Infrastructure.Database;
using MealPlanning.User.Infrastructure.MealTypes;
using MealPlanning.User.Infrastructure.Time;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace MealPlanning.User.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddUserInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<IMyanmarClock, MyanmarClock>();

        if (configuration.GetValue<bool>("Database:Enabled"))
        {
            var connectionString = configuration.GetConnectionString("MealPlanner")
                ?? configuration["DATABASE_URL"]
                ?? throw new InvalidOperationException(
                    "ConnectionStrings:MealPlanner or DATABASE_URL is required when Database:Enabled is true.");

            services.AddSingleton(_ => NpgsqlDataSource.Create(
                PostgresConnectionString.Normalize(connectionString)));
            services.AddScoped<IMealTypeQueries, PostgresMealTypeQueries>();
            services.AddHealthChecks().AddCheck<PostgresDatabaseHealthCheck>("postgres", tags: ["ready"]);
        }

        return services;
    }
}
