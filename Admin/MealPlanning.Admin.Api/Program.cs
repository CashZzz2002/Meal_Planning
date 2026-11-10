using MealPlanning.Admin.Application.Time;
using MealPlanning.Admin.Infrastructure;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddProblemDetails();
builder.Services.AddHealthChecks();
builder.Services.AddAdminInfrastructure(builder.Configuration);
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
    new { Code = "IAM", Name = "Identity & Access" },
    new { Code = "SETUP", Name = "Setup" },
    new { Code = "CATALOG", Name = "Food Catalog" },
    new { Code = "WAREHOUSE", Name = "Warehouse" },
    new { Code = "ORDER", Name = "Order Operations" }
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
