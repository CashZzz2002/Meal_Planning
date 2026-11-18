using System.Security.Cryptography;

namespace MealPlanning.User.Application.Authentication;

public sealed class AuthenticationService(
    IAuthenticationStore store,
    IPasswordHashService passwordHashService,
    TimeProvider timeProvider)
{
    public const string Context = "USER";
    public const string RequiredRole = "USER";
    private static readonly TimeSpan SessionLifetime = TimeSpan.FromHours(8);

    public async Task<LoginResult?> LoginAsync(string username, string password, CancellationToken cancellationToken)
    {
        var normalizedUsername = NormalizeUsername(username);
        if (normalizedUsername is null || string.IsNullOrEmpty(password)) return null;

        var user = await store.FindActiveUserAsync(normalizedUsername, RequiredRole, cancellationToken);
        if (user is null || !passwordHashService.Verify(user.PasswordHash, password)) return null;

        var now = timeProvider.GetUtcNow();
        var expiresAt = now.Add(SessionLifetime);
        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');
        await store.CreateSessionAsync(
            Guid.NewGuid(), user.Id, Context, HashToken(token), now, expiresAt, cancellationToken);
        return new LoginResult(
            token,
            expiresAt,
            new AuthenticationSession(user.Id, user.Username, user.DisplayName, expiresAt, [RequiredRole]));
    }

    public Task<AuthenticationSession?> AuthenticateAsync(string token, CancellationToken cancellationToken) =>
        store.FindSessionAsync(HashToken(token), Context, RequiredRole, timeProvider.GetUtcNow(), cancellationToken);

    public Task LogoutAsync(string token, CancellationToken cancellationToken) =>
        store.RevokeSessionAsync(HashToken(token), Context, timeProvider.GetUtcNow(), cancellationToken);

    private static string? NormalizeUsername(string username)
    {
        var normalized = username.Trim().ToLowerInvariant();
        return normalized.Length is > 0 and <= 200 ? normalized : null;
    }

    private static string HashToken(string token) =>
        Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token))).ToLowerInvariant();
}
