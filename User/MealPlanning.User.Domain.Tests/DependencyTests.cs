namespace MealPlanning.User.Domain.Tests;

public sealed class DependencyTests
{
    [Fact]
    public void DomainHasNoProjectDependencies()
    {
        var references = typeof(MealPlanning.User.Domain.Common.Entity).Assembly
            .GetReferencedAssemblies()
            .Select(x => x.Name)
            .Where(x => x is not null && x.StartsWith("MealPlanning.", StringComparison.Ordinal));

        Assert.Empty(references);
    }
}
