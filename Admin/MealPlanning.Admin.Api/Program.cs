using MealPlanning.Admin.Api;
using MealPlanning.Admin.Api.Endpoints;
using MealPlanning.Hosting;
using MealPlanning.Hosting.Configuration;
using MealPlanning.Hosting.Health;
using Microsoft.Extensions.Options;

var builder = WebApplication.CreateBuilder(args);
builder.AddStageConfig(args, typeof(Program).Assembly);
builder.AddAdminApiServices();

var app = builder.Build();
app.UseExceptionHandler();
if (app.Services.GetRequiredService<IOptions<HttpsRedirectionOptions>>().Value.Enabled)
{
    app.UseHttpsRedirection();
}
app.UseCors();
if (app.Services.GetRequiredService<IOptions<SwaggerOptions>>().Value.Enabled)
{
    app.UseSwagger();
    app.UseSwaggerUI(options => options.SwaggerEndpoint("v1/swagger.json", "Meal Planning Admin API v1"));
}

app.MapMealPlanningHealthChecks();
app.MapAdminSystemEndpoints();
if (app.Logger.IsEnabled(LogLevel.Information))
{
    var stage = app.Services.GetRequiredService<IOptions<StageOptions>>().Value;
    var database = app.Services.GetRequiredService<IOptions<DatabaseOptions>>().Value;
    HostingLog.Startup(app.Logger, "Admin API", stage.Stage, database.Enabled);
}
app.Run();

public partial class Program;
