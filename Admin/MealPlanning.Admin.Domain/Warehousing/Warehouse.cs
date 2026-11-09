using MealPlanning.Admin.Domain.Common;

namespace MealPlanning.Admin.Domain.Warehousing;

public sealed class Warehouse : Entity
{
    public Warehouse(Guid townshipId, string name)
    {
        TownshipId = townshipId;
        Name = name;
    }

    public Guid TownshipId { get; }
    public string Name { get; }
    public bool IsActive { get; private set; } = true;
}
