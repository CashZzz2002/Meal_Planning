using MealPlanning.Admin.Application.Time;
using MealPlanning.Admin.Application.Authentication;
using MealPlanning.Admin.Infrastructure.Authentication;
using MealPlanning.Admin.Infrastructure.Database;
using MealPlanning.Admin.Infrastructure.Time;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Resend;

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
                ?? configuration["DATABASE_URL"]
                ?? throw new InvalidOperationException(
                    "ConnectionStrings:MealPlanner or DATABASE_URL is required when Database:Enabled is true.");

            services.AddSingleton(_ => NpgsqlDataSource.Create(
                PostgresConnectionString.Normalize(connectionString)));
            services.AddScoped<IAuthenticationStore, PostgresAuthenticationStore>();
            services.AddScoped<IAdminProvisioningStore, PostgresAdminProvisioningStore>();
            services.AddScoped<IAdminInvitationEmailSender, ResendAdminInvitationEmailSender>();
            services.AddSingleton<IPasswordHashService, Pbkdf2PasswordHashService>();
            services.AddScoped<AuthenticationService>();
            services.AddScoped<AdminProvisioningService>();
            services.AddOptions<AdminEmailSettings>().Configure(options =>
            {
                options.FromName = configuration["Email:FromName"] ?? string.Empty;
                options.FromAddress = configuration["Email:FromAddress"] ?? string.Empty;
                options.DevelopmentRecipient = configuration["Email:DevelopmentRecipient"] ?? string.Empty;
                options.PortalUrl = configuration["Services:Admin:PortalUrl"] ?? string.Empty;
            });
            services.AddResend(options =>
                options.ApiToken = configuration["RESEND_APITOKEN"] ?? string.Empty);
            services.AddHealthChecks().AddCheck<PostgresDatabaseHealthCheck>("postgres", tags: ["ready"]);
        }

        return services;
    }
}
