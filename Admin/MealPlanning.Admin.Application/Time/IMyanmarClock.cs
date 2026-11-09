namespace MealPlanning.Admin.Application.Time;

public interface IMyanmarClock
{
    DateTimeOffset Now { get; }
    string TimeZoneId { get; }
}
