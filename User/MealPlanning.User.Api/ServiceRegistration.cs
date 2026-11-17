using MealPlanning.User.Infrastructure;
using MealPlanning.Hosting.Configuration;
using Microsoft.AspNetCore.Cors.Infrastructure;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi.Models;

namespace MealPlanning.User.Api;

internal static class ServiceRegistration
{
    public static WebApplicationBuilder AddUserApiServices(this WebApplicationBuilder builder)
    {
        builder.Services.AddMealPlanningHostOptions(builder.Configuration, "User");
        builder.Services.AddProblemDetails();
        builder.Services.AddHealthChecks();
        builder.Services.AddUserInfrastructure(builder.Configuration);
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
            Title = "Meal Planning User API",
            Version = "v1"
        }));
        builder.Logging.AddJsonConsole();

        if (string.IsNullOrWhiteSpace(builder.Configuration[WebHostDefaults.ServerUrlsKey]))
        {
            builder.WebHost.UseUrls(builder.Configuration["Services:User:ApiUrl"] ?? string.Empty);
        }

        return builder;
    }
}
