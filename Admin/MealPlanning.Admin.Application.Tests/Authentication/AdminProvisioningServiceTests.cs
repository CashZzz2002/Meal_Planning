using MealPlanning.Admin.Application.Authentication;

namespace MealPlanning.Admin.Application.Tests.Authentication;

public sealed class AdminProvisioningServiceTests
{
    [Fact]
    public async Task ApprovalPersistsOnlyTokenHashAndEmailsRawToken()
    {
        var store = new FakeStore();
        var email = new FakeEmailSender();
        var service = new AdminProvisioningService(store, email, new FakeHasher(), new FixedTimeProvider());

        Assert.True(await service.ApproveAsync(Guid.NewGuid(), Guid.NewGuid(), CancellationToken.None));

        Assert.NotNull(store.TokenHash);
        Assert.Equal(64, store.TokenHash.Length);
        Assert.NotNull(email.Token);
        Assert.NotEqual(email.Token, store.TokenHash);
    }

    [Fact]
    public async Task InvalidAdminRequestDoesNotReachStore()
    {
        var store = new FakeStore();
        var service = new AdminProvisioningService(store, new FakeEmailSender(), new FakeHasher(), new FixedTimeProvider());

        var result = await service.RequestAsync("x", "", "not-an-email", CancellationToken.None);

        Assert.Equal(AdminRequestResult.Invalid, result);
        Assert.False(store.RequestCreated);
    }

    private sealed class FakeStore : IAdminProvisioningStore
    {
        public string? TokenHash { get; private set; }
        public bool RequestCreated { get; private set; }
        public Task<bool> CreateRequestAsync(Guid requestId, string username, string displayName, string email, DateTimeOffset requestedAt, CancellationToken cancellationToken)
        { RequestCreated = true; return Task.FromResult(true); }
        public Task<IReadOnlyList<AdminAccountRequest>> ListPendingRequestsAsync(CancellationToken cancellationToken) => Task.FromResult<IReadOnlyList<AdminAccountRequest>>([]);
        public Task<ApprovedAdminInvitation?> ApproveRequestAsync(Guid requestId, Guid reviewerUserId, Guid userId, Guid challengeId, string invitationTokenHash, DateTimeOffset reviewedAt, DateTimeOffset expiresAt, CancellationToken cancellationToken)
        { TokenHash = invitationTokenHash; return Task.FromResult<ApprovedAdminInvitation?>(new(userId, "Admin", "owner@example.com", challengeId, expiresAt)); }
        public Task<bool> CompleteInvitationAsync(string invitationTokenHash, string passwordHash, DateTimeOffset now, CancellationToken cancellationToken) => Task.FromResult(true);
    }

    private sealed class FakeEmailSender : IAdminInvitationEmailSender
    {
        public string? Token { get; private set; }
        public Task SendAsync(string email, string displayName, string invitationToken, Guid challengeId, CancellationToken cancellationToken)
        { Token = invitationToken; return Task.CompletedTask; }
    }

    private sealed class FakeHasher : IPasswordHashService
    {
        public string Hash(string password) => $"hash:{password}";
        public bool Verify(string passwordHash, string password) => passwordHash == $"hash:{password}";
    }

    private sealed class FixedTimeProvider : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(2026, 11, 18, 0, 0, 0, TimeSpan.Zero);
    }
}
