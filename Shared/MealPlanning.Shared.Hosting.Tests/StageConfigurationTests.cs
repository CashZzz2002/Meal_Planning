using MealPlanning.Hosting.Configuration;
using Microsoft.Extensions.Hosting;

namespace MealPlanning.Hosting.Tests;

public sealed class StageConfigurationTests
{
    [Fact]
    public void SharedBaseThenStageOverrideApiDefaults()
    {
        using var fixture = new ConfigurationFixture();
        fixture.Write("Admin/Test.Api/appsettings.json", """{"Probe":"api","ApiOnly":"kept"}""");
        fixture.Write("Config/appsettings.json", """{"Stage":"dev","Probe":"base","BaseOnly":"kept"}""");
        var builder = fixture.CreateBuilder();

        builder.AddStageConfig([], typeof(StageConfigurationTests).Assembly);

        Assert.Equal("dev", builder.Configuration["Stage"]);
        Assert.Equal("dev", builder.Configuration["Probe"]);
        Assert.Equal("kept", builder.Configuration["ApiOnly"]);
        Assert.Equal("kept", builder.Configuration["BaseOnly"]);
    }

    [Fact]
    public void EnvironmentSelectsStageBeforeItsFileIsLoaded()
    {
        using var fixture = new ConfigurationFixture();
        using var environment = new EnvironmentOverride("Stage", " UAT ");
        fixture.Write("Config/custom-setting-uat.json", """{"Probe":"uat-file"}""");
        var builder = fixture.CreateBuilder();

        builder.AddStageConfig([], typeof(StageConfigurationTests).Assembly);

        Assert.Equal("uat", builder.Configuration["Stage"]);
        Assert.Equal("uat-file", builder.Configuration["Probe"]);
    }

    [Fact]
    public void CommandLineStageWinsOverEnvironment()
    {
        using var fixture = new ConfigurationFixture();
        using var environment = new EnvironmentOverride("Stage", "sit");
        fixture.Write("Config/custom-setting-uat.json", """{"Probe":"uat-file"}""");
        string[] args = ["--Stage=uat"];
        var builder = fixture.CreateBuilder(args);

        builder.AddStageConfig(args, typeof(StageConfigurationTests).Assembly);

        Assert.Equal("uat", builder.Configuration["Stage"]);
        Assert.Equal("uat-file", builder.Configuration["Probe"]);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData("staging")]
    [InlineData("../prod")]
    public void InvalidStageIsRejected(string? value)
    {
        var exception = Assert.Throws<InvalidOperationException>(() => StageConfiguration.NormalizeStage(value));
        Assert.Contains("dev, sit, uat, preprod, prod", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void SelectedStageFileIsRequiredEvenWhenAnExampleExists()
    {
        using var fixture = new ConfigurationFixture();
        using var environment = new EnvironmentOverride("Stage", "prod");
        fixture.Write("Config/custom-setting-prod.example.json", "{}");
        var builder = fixture.CreateBuilder();

        var exception = Assert.Throws<FileNotFoundException>(() =>
            builder.AddStageConfig([], typeof(StageConfigurationTests).Assembly));

        Assert.Contains("custom-setting-prod.json", exception.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void StageFileCannotChangeTheSelectedStage()
    {
        using var fixture = new ConfigurationFixture();
        fixture.Write("Config/custom-setting-dev.json", """{"Stage":"prod"}""");
        var builder = fixture.CreateBuilder();

        Assert.Throws<InvalidOperationException>(() => builder.AddStageConfig([], typeof(StageConfigurationTests).Assembly));
    }

    [Theory]
    [InlineData("Development", null, null, "admin-secret")]
    [InlineData("Development", "environment", null, "environment")]
    [InlineData("Development", "environment", "command-line", "command-line")]
    [InlineData("Production", null, null, "stage")]
    public void ExternalOverridesFollowDocumentedPrecedence(
        string hostingEnvironment, string? environmentValue, string? argumentValue, string expected)
    {
        using var fixture = new ConfigurationFixture();
        using var environment = new EnvironmentOverride("MealPlanningTest__Value", environmentValue);
        using var secrets = new TestUserSecrets("""{"MealPlanningTest:Value":"admin-secret"}""");
        fixture.Write("Config/custom-setting-dev.json", """{"MealPlanningTest":{"Value":"stage"}}""");
        string[] args = argumentValue is null ? [] : [$"--MealPlanningTest:Value={argumentValue}"];
        var builder = fixture.CreateBuilder(args, hostingEnvironment);

        builder.AddStageConfig(args, secrets.Assembly);

        Assert.Equal(expected, builder.Configuration["MealPlanningTest:Value"]);
    }

    [Fact]
    public void EachHostReadsOnlyItsOwnDevelopmentSecretsIncludingStageSelection()
    {
        using var fixture = new ConfigurationFixture();
        using var adminSecrets = new TestUserSecrets("""{"Stage":"sit","MealPlanningTest:Value":"admin"}""");
        using var userSecrets = new TestUserSecrets("""{"MealPlanningTest:Value":"user"}""");
        fixture.Write("Config/custom-setting-sit.json", """{"Probe":"sit-file"}""");
        var admin = fixture.CreateBuilder(environment: Environments.Development);
        var user = fixture.CreateBuilder(environment: Environments.Development);

        admin.AddStageConfig([], adminSecrets.Assembly);
        user.AddStageConfig([], userSecrets.Assembly);

        Assert.Equal("admin", admin.Configuration["MealPlanningTest:Value"]);
        Assert.Equal("sit", admin.Configuration["Stage"]);
        Assert.Equal("sit-file", admin.Configuration["Probe"]);
        Assert.Equal("user", user.Configuration["MealPlanningTest:Value"]);
        Assert.Equal("dev", user.Configuration["Stage"]);
    }

    [Fact]
    public void ResolvesNestedSourceOutputAndPublishedLayouts()
    {
        using var fixture = new ConfigurationFixture();
        var output = Path.Combine(fixture.ContentRoot, "bin", "Release", "net8.0");
        fixture.Write("Admin/Test.Api/bin/Release/net8.0/Config/appsettings.json", "{}");
        var outside = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"));

        Assert.Equal(Path.Combine(fixture.Root, "Config"),
            StageConfiguration.ResolveDirectory(fixture.ContentRoot, output));
        Assert.Equal(Path.Combine(output, "Config"), StageConfiguration.ResolveDirectory(output, output));
        Assert.Equal(Path.Combine(output, "Config"), StageConfiguration.ResolveDirectory(outside, output));
    }

    [Fact]
    public void ExplicitDirectoryWinsAndMissingBaseDoesNotSilentlyFallBack()
    {
        using var fixture = new ConfigurationFixture();
        fixture.Write("mounted-config/appsettings.json", "{}");
        Assert.Equal(Path.Combine(fixture.Root, "mounted-config"),
            StageConfiguration.ResolveDirectory(fixture.Root, fixture.Root, "mounted-config"));

        Assert.Throws<FileNotFoundException>(() =>
            StageConfiguration.ResolveDirectory(fixture.Root, fixture.Root, "missing-config"));
    }
}
