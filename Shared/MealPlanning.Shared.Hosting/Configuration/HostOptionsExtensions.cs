using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace MealPlanning.Hosting.Configuration;

public static class HostOptionsExtensions
{
    public static IServiceCollection AddMealPlanningHostOptions(
        this IServiceCollection services,
        IConfiguration configuration,
        string serviceName)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentException.ThrowIfNullOrWhiteSpace(serviceName);

        services.AddOptions<StageOptions>()
            .Bind(configuration)
            .Validate(options => options.Stage is "dev" or "sit" or "uat" or "preprod" or "prod",
                "Stage must be one of: dev, sit, uat, preprod, prod.")
            .Validate(options => options.BusinessTimeZone == "Asia/Yangon",
                "BusinessTimeZone must be Asia/Yangon.")
            .ValidateOnStart();

        var serviceSection = $"Services:{serviceName}";
        services.AddOptions<ServiceEndpointsOptions>()
            .Bind(configuration.GetSection(serviceSection))
            .Validate(options => IsHttpOrigin(options.ApiUrl),
                $"{serviceSection}:ApiUrl must be an absolute HTTP(S) origin without credentials, a path, query, or fragment.")
            .Validate(options => IsHttpOrigin(options.PortalUrl),
                $"{serviceSection}:PortalUrl must be an absolute HTTP(S) origin without credentials, a path, query, or fragment.")
            .Validate(options => options.AllowedOrigins.Length > 0 && options.AllowedOrigins.All(IsHttpOrigin),
                $"{serviceSection}:AllowedOrigins must contain explicit HTTP(S) origins without wildcards or trailing slashes.")
            .ValidateOnStart();

        services.AddOptions<DatabaseOptions>()
            .Bind(configuration.GetSection(DatabaseOptions.SectionName))
            .Validate(options => !options.Enabled || HasDatabaseConnection(configuration),
                "A database connection is required when Database:Enabled is true. Supply ConnectionStrings:MealPlanner or DATABASE_URL from a private source.")
            .ValidateOnStart();

        services.AddOptions<SwaggerOptions>()
            .Bind(configuration.GetSection(SwaggerOptions.SectionName))
            .ValidateOnStart();
        services.AddOptions<HttpsRedirectionOptions>()
            .Bind(configuration.GetSection(HttpsRedirectionOptions.SectionName))
            .ValidateOnStart();

        services.AddOptions<EmailOptions>()
            .Bind(configuration.GetSection(EmailOptions.SectionName))
            .Validate(options => !options.Enabled || options.Provider == "Resend",
                "Email:Provider must be Resend when email delivery is enabled.")
            .Validate(options => !options.Enabled ||
                (!string.IsNullOrWhiteSpace(options.FromName) && IsEmailAddress(options.FromAddress)),
                "Email:FromName and a valid Email:FromAddress are required when email delivery is enabled.")
            .Validate(options => string.IsNullOrWhiteSpace(options.DevelopmentRecipient) ||
                (configuration["Stage"] == "dev" && IsEmailAddress(options.DevelopmentRecipient)),
                "Email:DevelopmentRecipient must be a valid email and may only be used in the dev stage.")
            .Validate(options => !options.Enabled || !string.IsNullOrWhiteSpace(configuration["RESEND_APITOKEN"]),
                "RESEND_APITOKEN is required from a private source when email delivery is enabled.")
            .ValidateOnStart();

        return services;
    }

    private static bool IsHttpOrigin(string value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
        uri.Scheme is "http" or "https" &&
        !string.IsNullOrEmpty(uri.Host) &&
        !uri.Host.Contains('*', StringComparison.Ordinal) &&
        uri.UserInfo.Length == 0 &&
        uri.AbsolutePath == "/" &&
        uri.Query.Length == 0 &&
        uri.Fragment.Length == 0 &&
        !value.EndsWith('/');

    private static bool HasDatabaseConnection(IConfiguration configuration) =>
        !string.IsNullOrWhiteSpace(configuration.GetConnectionString("MealPlanner")) ||
        !string.IsNullOrWhiteSpace(configuration["DATABASE_URL"]);

    private static bool IsEmailAddress(string value)
    {
        try
        {
            return new System.Net.Mail.MailAddress(value).Address.Equals(value, StringComparison.OrdinalIgnoreCase);
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
