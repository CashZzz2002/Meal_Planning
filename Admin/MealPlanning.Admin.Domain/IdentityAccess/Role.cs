using MealPlanning.Admin.Domain.Common;

namespace MealPlanning.Admin.Domain.IdentityAccess;

public sealed class Role : Entity
{
    private readonly HashSet<string> _permissionCodes = new(StringComparer.OrdinalIgnoreCase);

    public Role(string name, bool isTownshipScoped)
    {
        Name = name;
        IsTownshipScoped = isTownshipScoped;
    }

    public string Name { get; }
    public bool IsTownshipScoped { get; }
    public IReadOnlySet<string> PermissionCodes => _permissionCodes;

    public void Grant(PermissionDefinition permission) => _permissionCodes.Add(permission.Code);

    public bool Can(PermissionDefinition permission) => _permissionCodes.Contains(permission.Code);
}
