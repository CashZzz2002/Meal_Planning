using MealPlanning.User.Application.Time;
using MealPlanning.User.Infrastructure;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddProblemDetails();
builder.Services.AddHealthChecks();
builder.Services.AddUserInfrastructure(builder.Configuration);
builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy
    .WithOrigins(builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [])
    .AllowAnyHeader()
    .AllowAnyMethod()));

var app = builder.Build();
app.UseExceptionHandler();
if (builder.Configuration.GetValue<bool>("HttpsRedirection:Enabled"))
{
    app.UseHttpsRedirection();
}
app.UseCors();

app.MapHealthChecks("/health/live", new() { Predicate = _ => false });
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    ResponseWriter = WriteHealthResponse
});
app.MapGet("/api/system/time", (IMyanmarClock clock) => Results.Ok(new
{
    clock.Now,
    clock.TimeZoneId
}));
app.MapGet("/api/system/modules", () => Results.Ok(new[]
{
    new { Code = "HOUSEHOLD", Name = "Household" },
    new { Code = "MEAL_PLAN", Name = "Weekly Meal Plan" },
    new { Code = "SHOPPING", Name = "Shopping List" },
    new { Code = "ORDER", Name = "My Orders" }
}));

app.Run();

static Task WriteHealthResponse(HttpContext context, HealthReport report)
{
    context.Response.ContentType = "application/json";
    return JsonSerializer.SerializeAsync(context.Response.Body, new
    {
        status = report.Status.ToString(),
        checks = report.Entries.Select(entry => new
        {
            name = entry.Key,
            status = entry.Value.Status.ToString(),
            entry.Value.Description,
            entry.Value.Data
        })
    });
}

public partial class Program;
