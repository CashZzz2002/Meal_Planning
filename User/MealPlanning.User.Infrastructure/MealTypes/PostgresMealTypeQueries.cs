using MealPlanning.User.Application.MealTypes;
using Npgsql;

namespace MealPlanning.User.Infrastructure.MealTypes;

internal sealed class PostgresMealTypeQueries(NpgsqlDataSource dataSource) : IMealTypeQueries
{
    public async Task<IReadOnlyList<MealType>> GetActiveAsync(CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT "ID", "CODE", "NAME_MM", "SORT_ORDER"
            FROM "MEAL_TYPES"
            WHERE "IS_ACTIVE" = TRUE
            ORDER BY "SORT_ORDER", "CODE"
            """;

        await using var command = dataSource.CreateCommand(sql);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var mealTypes = new List<MealType>();

        while (await reader.ReadAsync(cancellationToken))
        {
            mealTypes.Add(new MealType(
                reader.GetGuid(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetInt32(3)));
        }

        return mealTypes;
    }
}
