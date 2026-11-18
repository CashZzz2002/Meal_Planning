using System.Threading.RateLimiting;
using MealPlanning.Admin.Api.Authentication;
using MealPlanning.Admin.Infrastructure;
using MealPlanning.Hosting.Configuration;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Cors.Infrastructure;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi.Models;

namespace MealPlanning.Admin.Api;

internal static class ServiceRegistration
{
    public static WebApplicationBuilder AddAdminApiServices(this WebApplicationBuilder builder)
    {
        builder.Services.AddMealPlanningHostOptions(builder.Configuration, "Admin");
        builder.Services.AddProblemDetails();
        builder.Services.AddHealthChecks();
        builder.Services.AddAdminInfrastructure(builder.Configuration);
        builder.Services.AddCors();
        builder.Services.AddOptions<CorsOptions>()
            .Configure<IOptions<ServiceEndpointsOptions>>((options, endpoints) =>
                options.AddDefaultPolicy(policy => policy
                    .WithOrigins(endpoints.Value.AllowedOrigins)
                    .AllowAnyHeader()
                    .AllowAnyMethod()
                    .AllowCredentials()));
        if (builder.Configuration.GetValue<bool>("Database:Enabled"))
        {
            builder.Services.AddAuthentication(AdminCookieAuthenticationHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, AdminCookieAuthenticationHandler>(
                    AdminCookieAuthenticationHandler.SchemeName,
                    _ => { });
        }
        else
        {
            builder.Services.AddAuthentication();
        }
        builder.Services.AddAuthorization(options => options.AddPolicy(
            "AdminPortal",
            policy => policy.RequireRole("ADMIN")));
        builder.Services.AddAuthorization(options => options.AddPolicy(
            "SuperAdmin",
            policy => policy.RequireRole("SUPER_ADMIN")));
        builder.Services.AddRateLimiter(options => options.AddPolicy("login", context =>
            RateLimitPartition.GetFixedWindowLimiter(
                context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = 5,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0
                })));
        builder.Services.AddEndpointsApiExplorer();
        builder.Services.AddSwaggerGen(options => options.SwaggerDoc("v1", new OpenApiInfo
        {
            Title = "Meal Planning Admin API",
            Version = "v1"
        }));
        builder.Logging.AddJsonConsole();

        // Explicit ASPNETCORE_URLS / --urls / Visual Studio launch settings win.
        if (string.IsNullOrWhiteSpace(builder.Configuration[WebHostDefaults.ServerUrlsKey]))
        {
            builder.WebHost.UseUrls(builder.Configuration["Services:Admin:ApiUrl"] ?? string.Empty);
        }

        return builder;
    }
}
