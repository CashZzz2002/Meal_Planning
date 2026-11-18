using MealPlanning.User.Application.Time;

namespace MealPlanning.User.Api.Endpoints;

internal static class SystemEndpoints
{
    public static IEndpointRouteBuilder MapUserSystemEndpoints(
        this IEndpointRouteBuilder endpoints,
        bool requireAuthentication = false)
    {
        var system = endpoints.MapGroup("/api/system").WithTags("System");
        if (requireAuthentication) system.RequireAuthorization("UserPortal");
        system.MapGet("/time", (IMyanmarClock clock) => TypedResults.Ok(new
        {
            clock.Now,
            clock.TimeZoneId
        })).WithName("UserSystemTime").WithSummary("Current Myanmar business time");

        system.MapGet("/modules", () => TypedResults.Ok(new[]
        {
            new { Code = "HOUSEHOLD", Name = "Household" },
            new { Code = "MEAL_PLAN", Name = "Weekly Meal Plan" },
            new { Code = "SHOPPING", Name = "Shopping List" },
            new { Code = "ORDER", Name = "My Orders" }
        })).WithName("UserSystemModules").WithSummary("User module directory");

        return endpoints;
    }
}
