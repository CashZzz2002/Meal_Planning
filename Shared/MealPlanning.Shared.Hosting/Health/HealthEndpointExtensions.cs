using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace MealPlanning.Hosting.Health;

public static class HealthEndpointExtensions
{
    public static IEndpointRouteBuilder MapMealPlanningHealthChecks(this IEndpointRouteBuilder endpoints)
    {
        ArgumentNullException.ThrowIfNull(endpoints);
        endpoints.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
        endpoints.MapHealthChecks("/health/ready", new HealthCheckOptions { ResponseWriter = WriteHealthResponse });
        return endpoints;
    }

    private static Task WriteHealthResponse(HttpContext context, HealthReport report)
    {
        context.Response.ContentType = "application/json";
        return JsonSerializer.SerializeAsync(context.Response.Body, new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(entry => new
            {
                name = entry.Key,
                status = entry.Value.Status.ToString(),
                entry.Value.Description,
                entry.Value.Data
            })
        }, cancellationToken: context.RequestAborted);
    }
}
