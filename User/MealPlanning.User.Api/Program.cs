using MealPlanning.User.Api;
using MealPlanning.User.Api.Endpoints;
using MealPlanning.Hosting;
using MealPlanning.Hosting.Configuration;
using MealPlanning.Hosting.Health;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);
builder.AddStageConfig(args, typeof(Program).Assembly);
builder.AddUserApiServices();

var app = builder.Build();
app.UseExceptionHandler();
if (app.Services.GetRequiredService<IOptions<HttpsRedirectionOptions>>().Value.Enabled)
{
    app.UseHttpsRedirection();
}
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
if (app.Services.GetRequiredService<IOptions<SwaggerOptions>>().Value.Enabled)
{
    app.UseSwagger();
    app.UseSwaggerUI(options => options.SwaggerEndpoint("v1/swagger.json", "Meal Planning User API v1"));
}

app.MapMealPlanningHealthChecks();
var database = app.Services.GetRequiredService<IOptions<DatabaseOptions>>().Value;
var email = app.Services.GetRequiredService<IOptions<EmailOptions>>().Value;
app.MapUserSystemEndpoints(database.Enabled);
if (database.Enabled)
{
    app.MapUserAuthenticationEndpoints(email.Enabled);
    app.MapUserReferenceEndpoints(requireAuthentication: true);
}
if (app.Logger.IsEnabled(LogLevel.Information))
{
    var stage = app.Services.GetRequiredService<IOptions<StageOptions>>().Value;
    HostingLog.Startup(app.Logger, "User API", stage.Stage, database.Enabled);
}
app.Run();

public partial class Program;
