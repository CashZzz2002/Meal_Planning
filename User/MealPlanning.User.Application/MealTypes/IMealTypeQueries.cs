namespace MealPlanning.User.Application.MealTypes;

public interface IMealTypeQueries
{
    Task<IReadOnlyList<MealType>> GetActiveAsync(CancellationToken cancellationToken);
}
