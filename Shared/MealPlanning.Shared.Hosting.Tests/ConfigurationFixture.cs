using System.Reflection;
using System.Reflection.Emit;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.UserSecrets;

// These tests temporarily override process environment variables; they must be serialized.
[assembly: CollectionBehavior(DisableTestParallelization = true)]

namespace MealPlanning.Hosting.Tests;

internal sealed class ConfigurationFixture : IDisposable
{
    private readonly List<IDisposable> configurations = [];
    private readonly EnvironmentOverride stage = new("Stage", null);
    private readonly EnvironmentOverride configDirectory = new("ConfigDirectory", null);

    public ConfigurationFixture()
    {
        Root = Path.Combine(Path.GetTempPath(), "MealPlanning.Hosting.Tests", Guid.NewGuid().ToString("N"));
        ContentRoot = Path.Combine(Root, "Admin", "Test.Api");
        Directory.CreateDirectory(ContentRoot);
        Write("MealPlanning.sln", string.Empty);
        Write("Config/appsettings.json", """{"Stage":"dev","Probe":"base"}""");
        Write("Config/custom-setting-dev.json", """{"Probe":"dev"}""");
    }

    public string Root { get; }
    public string ContentRoot { get; }

    public void Write(string relativePath, string text)
    {
        var path = Path.Combine(Root, relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, text);
    }

    public WebApplicationBuilder CreateBuilder(string[]? args = null, string environment = "Production")
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ApplicationName = typeof(ConfigurationFixture).Assembly.FullName,
            ContentRootPath = ContentRoot,
            EnvironmentName = environment,
            Args = args ?? []
        });
        configurations.Add(builder.Configuration);
        return builder;
    }

    public void Dispose()
    {
        foreach (var configuration in configurations)
        {
            configuration.Dispose();
        }

        stage.Dispose();
        configDirectory.Dispose();
        Directory.Delete(Root, recursive: true);
    }
}

internal sealed class EnvironmentOverride : IDisposable
{
    private readonly string name;
    private readonly string? previous;

    public EnvironmentOverride(string name, string? value)
    {
        this.name = name;
        previous = Environment.GetEnvironmentVariable(name);
        Environment.SetEnvironmentVariable(name, value);
    }

    public void Dispose() => Environment.SetEnvironmentVariable(name, previous);
}

internal sealed class TestUserSecrets : IDisposable
{
    private readonly string directory;

    public TestUserSecrets(string json)
    {
        var id = $"meal-planning-hosting-tests-{Guid.NewGuid():N}";
        var assembly = AssemblyBuilder.DefineDynamicAssembly(new AssemblyName(id), AssemblyBuilderAccess.Run);
        var attribute = new CustomAttributeBuilder(typeof(UserSecretsIdAttribute).GetConstructor([typeof(string)])!, [id]);
        assembly.SetCustomAttribute(attribute);
        Assembly = assembly;

        // Only synthetic, uniquely named test stores are created/read. Never touch API stores.
        var path = PathHelper.GetSecretsPathFromSecretsId(id);
        directory = Path.GetDirectoryName(path)!;
        Directory.CreateDirectory(directory);
        File.WriteAllText(path, json);
    }

    public Assembly Assembly { get; }

    public void Dispose() => Directory.Delete(directory, recursive: true);
}
