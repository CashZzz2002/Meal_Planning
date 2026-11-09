using MealPlanning.Admin.Application.Time;
using MealPlanning.Admin.Infrastructure;

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
app.MapHealthChecks("/health/ready");
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

public partial class Program;
