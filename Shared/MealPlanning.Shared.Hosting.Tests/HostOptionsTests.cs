using MealPlanning.Hosting.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace MealPlanning.Hosting.Tests;

public sealed class HostOptionsTests
{
    [Theory]
    [InlineData("Stage", "invalid", "Stage")]
    [InlineData("BusinessTimeZone", "UTC", "BusinessTimeZone")]
    [InlineData("Services:Admin:ApiUrl", "", "ApiUrl")]
    [InlineData("Services:Admin:PortalUrl", "relative-path", "PortalUrl")]
    [InlineData("Services:Admin:ApiUrl", "https://user:do-not-log@example.invalid", "ApiUrl")]
    [InlineData("Services:Admin:AllowedOrigins:0", "*", "AllowedOrigins")]
    [InlineData("Database:Enabled", "true", "DATABASE_URL")]
    public void RequiredOptionsAreValidatedAtStartupWithoutEchoingValues(string key, string value, string expectedKey)
    {
        using var configuration = CreateConfiguration(key, value);
        var services = new ServiceCollection().AddMealPlanningHostOptions(configuration, "Admin");
        using var provider = services.BuildServiceProvider();

        var exception = Assert.Throws<OptionsValidationException>(() =>
            provider.GetRequiredService<IStartupValidator>().Validate());

        Assert.Contains(expectedKey, exception.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("do-not-log", exception.ToString(), StringComparison.Ordinal);
    }

    [Fact]
    public void ValidOptionsBindOnlyTheSelectedServiceAndDatabaseCanBeDisabled()
    {
        using var configuration = CreateConfiguration("Services:User:ApiUrl", "http://localhost:5201");
        using var admin = new ServiceCollection().AddMealPlanningHostOptions(configuration, "Admin").BuildServiceProvider();
        using var user = new ServiceCollection().AddMealPlanningHostOptions(configuration, "User").BuildServiceProvider();

        admin.GetRequiredService<IStartupValidator>().Validate();
        Assert.False(admin.GetRequiredService<IOptions<DatabaseOptions>>().Value.Enabled);
        Assert.Equal("http://localhost:5101", admin.GetRequiredService<IOptions<ServiceEndpointsOptions>>().Value.ApiUrl);
        Assert.Equal("http://localhost:5201", user.GetRequiredService<IOptions<ServiceEndpointsOptions>>().Value.ApiUrl);
    }

    [Fact]
    public void EnabledDatabaseAcceptsNeonDatabaseUrlFallback()
    {
        using var configuration = CreateConfiguration("Database:Enabled", "true");
        configuration["DATABASE_URL"] = "postgresql://test-user:test-password@example.invalid/test-db";
        using var provider = new ServiceCollection()
            .AddMealPlanningHostOptions(configuration, "Admin")
            .BuildServiceProvider();

        provider.GetRequiredService<IStartupValidator>().Validate();
        Assert.True(provider.GetRequiredService<IOptions<DatabaseOptions>>().Value.Enabled);
    }

    private static ConfigurationManager CreateConfiguration(string key, string value)
    {
        var values = new Dictionary<string, string?>
        {
            ["Stage"] = "dev",
            ["BusinessTimeZone"] = "Asia/Yangon",
            ["Services:Admin:ApiUrl"] = "http://localhost:5101",
            ["Services:Admin:PortalUrl"] = "http://localhost:3001",
            ["Services:Admin:AllowedOrigins:0"] = "http://localhost:3001",
            ["Services:User:ApiUrl"] = "http://localhost:5201",
            ["Services:User:PortalUrl"] = "http://localhost:3002",
            ["Services:User:AllowedOrigins:0"] = "http://localhost:3002"
        };
        values[key] = value;
        var configuration = new ConfigurationManager();
        configuration.AddInMemoryCollection(values);
        return configuration;
    }
}
