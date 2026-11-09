using MealPlanning.Admin.Domain.Common;

namespace MealPlanning.Admin.Domain.Warehousing;

public sealed class Township : Entity
{
    public Township(string code, string nameEn, string nameMm)
    {
        Code = code;
        NameEn = nameEn;
        NameMm = nameMm;
    }

    public string Code { get; }
    public string NameEn { get; }
    public string NameMm { get; }
}
