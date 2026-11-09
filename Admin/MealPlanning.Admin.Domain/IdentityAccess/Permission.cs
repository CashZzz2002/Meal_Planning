namespace MealPlanning.Admin.Domain.IdentityAccess;

public sealed record PermissionDefinition(string Menu, string Action)
{
    public string Code => $"{Menu}.{Action}".ToUpperInvariant();
}
