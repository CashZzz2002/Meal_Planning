namespace MealPlanning.User.Application.Authentication;

public sealed record AuthenticationUser(Guid Id, string Username, string DisplayName, string PasswordHash);
public sealed record AuthenticationSession(Guid UserId, string Username, string DisplayName, DateTimeOffset ExpiresAt, IReadOnlyList<string> Roles);
public sealed record LoginResult(string Token, DateTimeOffset ExpiresAt, AuthenticationSession User);

public interface IAuthenticationStore
{
    Task<AuthenticationUser?> FindActiveUserAsync(string normalizedUsername, string requiredRole, CancellationToken cancellationToken);
    Task CreateSessionAsync(Guid sessionId, Guid userId, string context, string tokenHash, DateTimeOffset createdAt, DateTimeOffset expiresAt, CancellationToken cancellationToken);
    Task<AuthenticationSession?> FindSessionAsync(string tokenHash, string context, string requiredRole, DateTimeOffset now, CancellationToken cancellationToken);
    Task RevokeSessionAsync(string tokenHash, string context, DateTimeOffset revokedAt, CancellationToken cancellationToken);
}

public interface IPasswordHashService
{
    string Hash(string password);
    bool Verify(string passwordHash, string password);
}

public enum PendingRegistrationResult
{
    Created,
    Conflict
}

public sealed record EmailVerificationChallenge(
    Guid Id,
    Guid UserId,
    string SecretHash,
    int FailedAttempts);

public sealed record PendingUserForEmail(
    Guid UserId,
    string DisplayName,
    string Email);

public interface IUserRegistrationStore
{
    Task<PendingRegistrationResult> CreatePendingUserAsync(
        Guid userId,
        string username,
        string displayName,
        string email,
        string passwordHash,
        Guid challengeId,
        string codeHash,
        DateTimeOffset createdAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken);

    Task<EmailVerificationChallenge?> FindVerificationChallengeAsync(
        string email,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task RecordFailedAttemptAsync(Guid challengeId, CancellationToken cancellationToken);

    Task<bool> ActivateUserAsync(
        Guid challengeId,
        Guid userId,
        DateTimeOffset verifiedAt,
        CancellationToken cancellationToken);

    Task<PendingUserForEmail?> ReplaceVerificationChallengeAsync(
        string email,
        Guid challengeId,
        string codeHash,
        DateTimeOffset createdAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken);
}

public interface IUserVerificationEmailSender
{
    Task SendAsync(
        string email,
        string displayName,
        string code,
        Guid challengeId,
        CancellationToken cancellationToken);
}
