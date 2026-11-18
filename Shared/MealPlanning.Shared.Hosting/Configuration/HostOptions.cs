namespace MealPlanning.Hosting.Configuration;

public sealed class StageOptions
{
    public string Stage { get; set; } = string.Empty;
    public string BusinessTimeZone { get; set; } = string.Empty;
}

public sealed class ServiceEndpointsOptions
{
    public string ApiUrl { get; set; } = string.Empty;
    public string PortalUrl { get; set; } = string.Empty;
    public string[] AllowedOrigins { get; set; } = [];
}

public sealed class DatabaseOptions
{
    public const string SectionName = "Database";
    public bool Enabled { get; set; }
}

public sealed class SwaggerOptions
{
    public const string SectionName = "Swagger";
    public bool Enabled { get; set; }
}

public sealed class HttpsRedirectionOptions
{
    public const string SectionName = "HttpsRedirection";
    public bool Enabled { get; set; }
}

public sealed class EmailOptions
{
    public const string SectionName = "Email";
    public bool Enabled { get; set; }
    public string Provider { get; set; } = string.Empty;
    public string FromName { get; set; } = string.Empty;
    public string FromAddress { get; set; } = string.Empty;
    public string DevelopmentRecipient { get; set; } = string.Empty;
}
