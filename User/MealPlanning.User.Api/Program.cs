using MealPlanning.User.Application.Time;
using MealPlanning.User.Infrastructure;

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
app.MapHealthChecks("/health/ready");
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

public partial class Program;
