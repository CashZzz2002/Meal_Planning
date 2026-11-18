using System.Security.Cryptography;
using MealPlanning.Admin.Application.Authentication;

namespace MealPlanning.Admin.Infrastructure.Authentication;

internal sealed class Pbkdf2PasswordHashService : IPasswordHashService
{
    public string Hash(string password)
    {
        ArgumentException.ThrowIfNullOrEmpty(password);
        const int iterations = 210_000;
        var salt = RandomNumberGenerator.GetBytes(16);
        var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, iterations, HashAlgorithmName.SHA256, 32);
        return $"PBKDF2-SHA256${iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(hash)}";
    }

    private const string Algorithm = "PBKDF2-SHA256";

    public bool Verify(string passwordHash, string password)
    {
        var parts = passwordHash.Split('$', StringSplitOptions.None);
        if (parts.Length != 4 || !parts[0].Equals(Algorithm, StringComparison.Ordinal) ||
            !int.TryParse(parts[1], out var iterations) || iterations < 100_000)
        {
            return false;
        }

        try
        {
            var salt = Convert.FromBase64String(parts[2]);
            var expected = Convert.FromBase64String(parts[3]);
            var actual = Rfc2898DeriveBytes.Pbkdf2(
                password,
                salt,
                iterations,
                HashAlgorithmName.SHA256,
                expected.Length);
            return CryptographicOperations.FixedTimeEquals(actual, expected);
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
