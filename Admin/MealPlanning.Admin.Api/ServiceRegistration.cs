using MealPlanning.Admin.Infrastructure;
using MealPlanning.Hosting.Configuration;
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
                    .AllowAnyMethod()));
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
