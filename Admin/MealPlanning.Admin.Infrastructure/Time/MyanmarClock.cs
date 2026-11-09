using MealPlanning.Admin.Application.Time;

namespace MealPlanning.Admin.Infrastructure.Time;

internal sealed class MyanmarClock(TimeProvider timeProvider) : IMyanmarClock
{
    private static readonly TimeZoneInfo MyanmarTimeZone =
        TimeZoneInfo.FindSystemTimeZoneById("Asia/Yangon");

    public DateTimeOffset Now => TimeZoneInfo.ConvertTime(timeProvider.GetUtcNow(), MyanmarTimeZone);
    public string TimeZoneId => "Asia/Yangon";
}
