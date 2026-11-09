using MealPlanning.Admin.Domain.IdentityAccess;

namespace MealPlanning.Admin.Domain.Tests.IdentityAccess;

public sealed class RoleTests
{
    [Fact]
    public void GrantAllowsConfiguredMenuActionOnly()
    {
        var role = new Role("Township Warehouse Agent", isTownshipScoped: true);
        role.Grant(new PermissionDefinition("Inventory", "View"));

        Assert.True(role.Can(new PermissionDefinition("inventory", "view")));
        Assert.False(role.Can(new PermissionDefinition("Inventory", "Adjust")));
    }
}
