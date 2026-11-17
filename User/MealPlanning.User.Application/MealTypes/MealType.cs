namespace MealPlanning.User.Application.MealTypes;

public sealed record MealType(Guid Id, string Code, string NameMm, int SortOrder);
