using MealPlanning.User.Application.MealTypes;
using MealPlanning.User.Application.Authentication;
using MealPlanning.User.Infrastructure.Authentication;
using MealPlanning.User.Application.Time;
using MealPlanning.User.Infrastructure.Database;
using MealPlanning.User.Infrastructure.MealTypes;
using MealPlanning.User.Infrastructure.Time;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Resend;

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
            services.AddScoped<IAuthenticationStore, PostgresAuthenticationStore>();
            services.AddScoped<IUserRegistrationStore, PostgresUserRegistrationStore>();
            services.AddScoped<IUserVerificationEmailSender, ResendUserVerificationEmailSender>();
            services.AddSingleton<IPasswordHashService, Pbkdf2PasswordHashService>();
            services.AddScoped<AuthenticationService>();
            services.AddScoped<UserRegistrationService>();
            services.AddOptions<UserEmailSettings>().Configure(options =>
            {
                options.FromName = configuration["Email:FromName"] ?? string.Empty;
                options.FromAddress = configuration["Email:FromAddress"] ?? string.Empty;
                options.DevelopmentRecipient = configuration["Email:DevelopmentRecipient"] ?? string.Empty;
            });
            services.AddResend(options =>
                options.ApiToken = configuration["RESEND_APITOKEN"] ?? string.Empty);
            services.AddScoped<IMealTypeQueries, PostgresMealTypeQueries>();
            services.AddHealthChecks().AddCheck<PostgresDatabaseHealthCheck>("postgres", tags: ["ready"]);
        }

        return services;
    }
}
