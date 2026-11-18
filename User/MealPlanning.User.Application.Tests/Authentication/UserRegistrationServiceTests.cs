using MealPlanning.User.Application.Authentication;

namespace MealPlanning.User.Application.Tests.Authentication;

public sealed class UserRegistrationServiceTests
{
    [Fact]
    public async Task RegistrationStoresHashedCodeAndEmailsSixDigits()
    {
        var store = new FakeStore();
        var email = new FakeEmailSender();
        var service = new UserRegistrationService(store, email, new FakeHasher(), new FixedTimeProvider());

        var result = await service.RegisterAsync(
            "new-user", "New User", "owner@example.com", "long-test-password", CancellationToken.None);

        Assert.Equal(RegistrationResult.Accepted, result);
        Assert.NotNull(email.Code);
        Assert.Matches("^[0-9]{6}$", email.Code);
        Assert.Equal($"hash:{email.Code}", store.CodeHash);
    }

    [Fact]
    public async Task ValidCodeActivatesPendingUser()
    {
        var store = new FakeStore { Challenge = new(Guid.NewGuid(), Guid.NewGuid(), "hash:123456", 0) };
        var service = new UserRegistrationService(store, new FakeEmailSender(), new FakeHasher(), new FixedTimeProvider());

        Assert.True(await service.VerifyAsync("owner@example.com", "123456", CancellationToken.None));
        Assert.True(store.Activated);
    }

    private sealed class FakeStore : IUserRegistrationStore
    {
        public string? CodeHash { get; private set; }
        public EmailVerificationChallenge? Challenge { get; init; }
        public bool Activated { get; private set; }
        public Task<PendingRegistrationResult> CreatePendingUserAsync(Guid userId, string username, string displayName, string email, string passwordHash, Guid challengeId, string codeHash, DateTimeOffset createdAt, DateTimeOffset expiresAt, CancellationToken cancellationToken)
        { CodeHash = codeHash; return Task.FromResult(PendingRegistrationResult.Created); }
        public Task<EmailVerificationChallenge?> FindVerificationChallengeAsync(string email, DateTimeOffset now, CancellationToken cancellationToken) => Task.FromResult(Challenge);
        public Task RecordFailedAttemptAsync(Guid challengeId, CancellationToken cancellationToken) => Task.CompletedTask;
        public Task<bool> ActivateUserAsync(Guid challengeId, Guid userId, DateTimeOffset verifiedAt, CancellationToken cancellationToken)
        { Activated = true; return Task.FromResult(true); }
        public Task<PendingUserForEmail?> ReplaceVerificationChallengeAsync(string email, Guid challengeId, string codeHash, DateTimeOffset createdAt, DateTimeOffset expiresAt, CancellationToken cancellationToken) => Task.FromResult<PendingUserForEmail?>(null);
    }

    private sealed class FakeEmailSender : IUserVerificationEmailSender
    {
        public string? Code { get; private set; }
        public Task SendAsync(string email, string displayName, string code, Guid challengeId, CancellationToken cancellationToken)
        { Code = code; return Task.CompletedTask; }
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
