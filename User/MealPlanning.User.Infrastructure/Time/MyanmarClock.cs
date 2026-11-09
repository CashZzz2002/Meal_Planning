using MealPlanning.User.Application.Time;

namespace MealPlanning.User.Infrastructure.Time;

internal sealed class MyanmarClock(TimeProvider timeProvider) : IMyanmarClock
{
    private static readonly TimeZoneInfo MyanmarTimeZone =
        TimeZoneInfo.FindSystemTimeZoneById("Asia/Yangon");

    public DateTimeOffset Now => TimeZoneInfo.ConvertTime(timeProvider.GetUtcNow(), MyanmarTimeZone);
    public string TimeZoneId => "Asia/Yangon";
}
