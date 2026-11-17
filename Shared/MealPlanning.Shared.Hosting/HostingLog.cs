using Microsoft.Extensions.Logging;

namespace MealPlanning.Hosting;

public static partial class HostingLog
{
    [LoggerMessage(Level = LogLevel.Information,
        Message = "{Service} starting with Stage={Stage}, DatabaseEnabled={DatabaseEnabled}.")]
    public static partial void Startup(ILogger logger, string service, string stage, bool databaseEnabled);
}
