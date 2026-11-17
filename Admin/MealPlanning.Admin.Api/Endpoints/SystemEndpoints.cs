using MealPlanning.Admin.Application.Time;

namespace MealPlanning.Admin.Api.Endpoints;

internal static class SystemEndpoints
{
    public static IEndpointRouteBuilder MapAdminSystemEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var system = endpoints.MapGroup("/api/system").WithTags("System");
        system.MapGet("/time", (IMyanmarClock clock) => TypedResults.Ok(new
        {
            clock.Now,
            clock.TimeZoneId
        })).WithName("AdminSystemTime").WithSummary("Current Myanmar business time");

        system.MapGet("/modules", () => TypedResults.Ok(new[]
        {
            new { Code = "IAM", Name = "Identity & Access" },
            new { Code = "SETUP", Name = "Setup" },
            new { Code = "CATALOG", Name = "Food Catalog" },
            new { Code = "WAREHOUSE", Name = "Warehouse" },
            new { Code = "ORDER", Name = "Order Operations" }
        })).WithName("AdminSystemModules").WithSummary("Admin module directory");

        return endpoints;
    }
}
