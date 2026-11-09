using MealPlanning.Admin.Application.Time;
using MealPlanning.Admin.Infrastructure.Database;
using MealPlanning.Admin.Infrastructure.Time;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace MealPlanning.Admin.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddAdminInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<IMyanmarClock, MyanmarClock>();

        if (configuration.GetValue<bool>("Database:Enabled"))
        {
            var connectionString = configuration.GetConnectionString("MealPlanner")
                ?? throw new InvalidOperationException("ConnectionStrings:MealPlanner is required when Database:Enabled is true.");

            services.AddSingleton(new OracleDatabaseOptions(connectionString));
            services.AddHealthChecks().AddCheck<OracleDatabaseHealthCheck>("oracle", tags: ["ready"]);
        }

        return services;
    }
}
