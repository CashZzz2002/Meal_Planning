using MealPlanning.User.Application.Authentication;

namespace MealPlanning.User.Application.Tests.Authentication;

public sealed class AuthenticationServiceTests
{
    [Fact]
    public async Task LoginUsesUserContextAndRole()
    {
        var store = new FakeStore();
        var service = new AuthenticationService(store, new FakeHasher(), TimeProvider.System);
        var result = await service.LoginAsync("USER", "valid-test-password", CancellationToken.None);
        Assert.NotNull(result);
        Assert.Equal("user", store.RequestedUsername);
        Assert.Equal("USER", store.RequiredRole);
        Assert.Equal("USER", store.StoredContext);
        Assert.Equal(64, store.StoredTokenHash?.Length);
    }

    private sealed class FakeHasher : IPasswordHashService
    {
        public string Hash(string password) => $"hash:{password}";
        public bool Verify(string passwordHash, string password) => passwordHash == "stored" && password == "valid-test-password";
    }

    private sealed class FakeStore : IAuthenticationStore
    {
        public string? RequestedUsername { get; private set; }
        public string? RequiredRole { get; private set; }
        public string? StoredContext { get; private set; }
        public string? StoredTokenHash { get; private set; }
        public Task<AuthenticationUser?> FindActiveUserAsync(string normalizedUsername, string requiredRole, CancellationToken cancellationToken)
        { RequestedUsername = normalizedUsername; RequiredRole = requiredRole; return Task.FromResult<AuthenticationUser?>(new(Guid.NewGuid(), "user", "User", "stored")); }
        public Task CreateSessionAsync(Guid sessionId, Guid userId, string context, string tokenHash, DateTimeOffset createdAt, DateTimeOffset expiresAt, CancellationToken cancellationToken)
        { StoredContext = context; StoredTokenHash = tokenHash; return Task.CompletedTask; }
        public Task<AuthenticationSession?> FindSessionAsync(string tokenHash, string context, string requiredRole, DateTimeOffset now, CancellationToken cancellationToken) => Task.FromResult<AuthenticationSession?>(null);
        public Task RevokeSessionAsync(string tokenHash, string context, DateTimeOffset revokedAt, CancellationToken cancellationToken) => Task.CompletedTask;
    }
}
