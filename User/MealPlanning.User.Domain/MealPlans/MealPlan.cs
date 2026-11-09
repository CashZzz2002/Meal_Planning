using MealPlanning.User.Domain.Common;

namespace MealPlanning.User.Domain.MealPlans;

public sealed class MealPlan : Entity
{
    public MealPlan(Guid householdId, DateOnly weekStart)
    {
        HouseholdId = householdId;
        WeekStart = weekStart;
    }

    public Guid HouseholdId { get; }
    public DateOnly WeekStart { get; }
    public string Status { get; private set; } = "Draft";
}
