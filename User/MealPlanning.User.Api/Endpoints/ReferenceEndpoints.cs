using MealPlanning.User.Application.MealTypes;

namespace MealPlanning.User.Api.Endpoints;

internal static class ReferenceEndpoints
{
    public static IEndpointRouteBuilder MapUserReferenceEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var reference = endpoints.MapGroup("/api/reference").WithTags("Reference Data");
        reference.MapGet("/meal-types", async (
            IMealTypeQueries queries,
            CancellationToken cancellationToken) =>
                TypedResults.Ok(await queries.GetActiveAsync(cancellationToken)))
            .WithName("UserActiveMealTypes")
            .WithSummary("Active meal types from Neon Postgres");

        return endpoints;
    }
}
