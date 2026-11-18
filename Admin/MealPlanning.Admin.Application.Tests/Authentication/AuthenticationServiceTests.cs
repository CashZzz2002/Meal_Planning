using MealPlanning.Admin.Application.Authentication;

namespace MealPlanning.Admin.Application.Tests.Authentication;

public sealed class AuthenticationServiceTests
{
    [Fact]
    public async Task LoginNormalizesUsernameAndStoresOnlyTokenHash()
    {
        var store = new FakeStore();
        var service = new AuthenticationService(store, new FakeHasher(), new FixedTimeProvider());

        var result = await service.LoginAsync(" ADMIN ", "valid-test-password", CancellationToken.None);

        Assert.NotNull(result);
        Assert.Equal("admin", store.RequestedUsername);
        Assert.Equal("ADMIN", store.RequiredRole);
        Assert.Equal("ADMIN", store.StoredContext);
        Assert.Equal(64, store.StoredTokenHash?.Length);
        Assert.NotEqual(result.Token, store.StoredTokenHash);
    }

    [Fact]
    public async Task LoginWithWrongPasswordDoesNotCreateSession()
    {
        var store = new FakeStore();
        var service = new AuthenticationService(store, new FakeHasher(), new FixedTimeProvider());

        Assert.Null(await service.LoginAsync("admin", "wrong", CancellationToken.None));
        Assert.Null(store.StoredTokenHash);
    }

    private sealed class FakeHasher : IPasswordHashService
    {
        public string Hash(string password) => $"hash:{password}";
        public bool Verify(string passwordHash, string password) => passwordHash == "stored" && password == "valid-test-password";
    }

    private sealed class FixedTimeProvider : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(2026, 11, 17, 0, 0, 0, TimeSpan.Zero);
    }

    private sealed class FakeStore : IAuthenticationStore
    {
        public string? RequestedUsername { get; private set; }
        public string? RequiredRole { get; private set; }
        public string? StoredContext { get; private set; }
        public string? StoredTokenHash { get; private set; }

        public Task<AuthenticationUser?> FindActiveUserAsync(string normalizedUsername, string requiredRole, CancellationToken cancellationToken)
        {
            RequestedUsername = normalizedUsername; RequiredRole = requiredRole;
            return Task.FromResult<AuthenticationUser?>(new(Guid.NewGuid(), "admin", "Admin", "stored"));
        }
        public Task CreateSessionAsync(Guid sessionId, Guid userId, string context, string tokenHash, DateTimeOffset createdAt, DateTimeOffset expiresAt, CancellationToken cancellationToken)
        { StoredContext = context; StoredTokenHash = tokenHash; return Task.CompletedTask; }
        public Task<AuthenticationSession?> FindSessionAsync(string tokenHash, string context, string requiredRole, DateTimeOffset now, CancellationToken cancellationToken) => Task.FromResult<AuthenticationSession?>(null);
        public Task RevokeSessionAsync(string tokenHash, string context, DateTimeOffset revokedAt, CancellationToken cancellationToken) => Task.CompletedTask;
    }
}
