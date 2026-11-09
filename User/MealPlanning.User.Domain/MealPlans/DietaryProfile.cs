namespace MealPlanning.User.Domain.MealPlans;

public sealed record DietaryProfile(
    int HouseholdSize,
    IReadOnlySet<string> Allergens,
    IReadOnlySet<string> HealthConditions,
    decimal? WeeklyBudget,
    bool Vegetarian);
