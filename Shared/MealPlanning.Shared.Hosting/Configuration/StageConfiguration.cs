namespace MealPlanning.Hosting.Configuration;

public static class StageConfiguration
{
    public static string NormalizeStage(string? value)
    {
        var stage = value?.Trim().ToLowerInvariant();
        return stage is "dev" or "sit" or "uat" or "preprod" or "prod"
            ? stage
            : throw new InvalidOperationException(
                "Stage is required and must be one of: dev, sit, uat, preprod, prod.");
    }

    public static string ResolveDirectory(
        string contentRootPath,
        string applicationBaseDirectory,
        string? configuredDirectory = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(contentRootPath);
        ArgumentException.ThrowIfNullOrWhiteSpace(applicationBaseDirectory);

        if (!string.IsNullOrWhiteSpace(configuredDirectory))
        {
            return RequireBaseFile(Path.GetFullPath(configuredDirectory, contentRootPath));
        }

        var localDirectory = Path.Combine(contentRootPath, "Config");
        if (File.Exists(Path.Combine(localDirectory, "appsettings.json")))
        {
            return localDirectory;
        }

        // Visual Studio's content root is Admin/MealPlanning.Admin.Api (or User/...);
        // stop at this solution rather than relying on a fixed number of parents.
        for (var directory = new DirectoryInfo(contentRootPath); directory is not null; directory = directory.Parent)
        {
            if (File.Exists(Path.Combine(directory.FullName, "MealPlanning.sln")))
            {
                return RequireBaseFile(Path.Combine(directory.FullName, "Config"));
            }
        }

        // A built/published API can be launched from an unrelated working directory.
        return RequireBaseFile(Path.Combine(applicationBaseDirectory, "Config"));
    }

    private static string RequireBaseFile(string directory)
    {
        var file = Path.Combine(directory, "appsettings.json");
        if (!File.Exists(file))
        {
            throw new FileNotFoundException(
                "Required Config/appsettings.json was not found. Set ConfigDirectory to the shared Config folder or include Config in the API output.", file);
        }

        return directory;
    }
}
