using System.Reflection;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace MealPlanning.Hosting.Configuration;

public static class ConfigurationExtension
{
    public static WebApplicationBuilder AddStageConfig(
        this WebApplicationBuilder builder,
        string[] args,
        Assembly hostAssembly)
    {
        ArgumentNullException.ThrowIfNull(builder);
        ArgumentNullException.ThrowIfNull(args);
        ArgumentNullException.ThrowIfNull(hostAssembly);

        var directory = StageConfiguration.ResolveDirectory(
            builder.Environment.ContentRootPath,
            AppContext.BaseDirectory,
            builder.Configuration["ConfigDirectory"]);
        var baseFile = Path.Combine(directory, "appsettings.json");

        // Resolve external Stage overrides BEFORE choosing the required stage file.
        // Use the API assembly explicitly: Shared.Hosting must never own API secrets.
        using var selector = new ConfigurationManager();
        selector.AddConfiguration(builder.Configuration)
            .AddJsonFile(baseFile, optional: false, reloadOnChange: false)
            .AddExternalOverrides(builder.Environment, hostAssembly, args);
        var stage = StageConfiguration.NormalizeStage(selector["Stage"]);
        var stageFile = Path.Combine(directory, $"custom-setting-{stage}.json");
        if (!File.Exists(stageFile))
        {
            throw new FileNotFoundException(
                $"Required configuration file custom-setting-{stage}.json was not found. Prepare it from its example before selecting this Stage.", stageFile);
        }

        using var stageSettings = new ConfigurationManager();
        stageSettings.AddJsonFile(stageFile, optional: false, reloadOnChange: false);
        if (stageSettings["Stage"] is not null)
        {
            throw new InvalidOperationException(
                "Set Stage in Config/appsettings.json or an external override, not inside custom-setting-{stage}.json.");
        }

        builder.Configuration
            .AddJsonFile(baseFile, optional: false, reloadOnChange: false)
            .AddJsonFile(stageFile, optional: false, reloadOnChange: false)
            .AddExternalOverrides(builder.Environment, hostAssembly, args)
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Stage"] = stage });

        return builder;
    }

    private static IConfigurationBuilder AddExternalOverrides(
        this IConfigurationBuilder configuration,
        IHostEnvironment environment,
        Assembly hostAssembly,
        string[] args)
    {
        if (environment.IsDevelopment())
        {
            configuration.AddUserSecrets(hostAssembly, optional: true, reloadOnChange: false);
        }

        configuration.AddEnvironmentVariables();
        if (args.Length > 0)
        {
            configuration.AddCommandLine(args);
        }

        return configuration;
    }
}
