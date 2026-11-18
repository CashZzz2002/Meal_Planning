namespace MealPlanning.Admin.Application.Authentication;

public sealed record AuthenticationUser(
    Guid Id,
    string Username,
    string DisplayName,
    string PasswordHash);

public sealed record AuthenticationSession(
    Guid UserId,
    string Username,
    string DisplayName,
    DateTimeOffset ExpiresAt,
    IReadOnlyList<string> Roles);

public sealed record LoginResult(
    string Token,
    DateTimeOffset ExpiresAt,
    AuthenticationSession User);

public interface IAuthenticationStore
{
    Task<AuthenticationUser?> FindActiveUserAsync(
        string normalizedUsername,
        string requiredRole,
        CancellationToken cancellationToken);

    Task CreateSessionAsync(
        Guid sessionId,
        Guid userId,
        string context,
        string tokenHash,
        DateTimeOffset createdAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken);

    Task<AuthenticationSession?> FindSessionAsync(
        string tokenHash,
        string context,
        string requiredRole,
        DateTimeOffset now,
        CancellationToken cancellationToken);

    Task RevokeSessionAsync(
        string tokenHash,
        string context,
        DateTimeOffset revokedAt,
        CancellationToken cancellationToken);
}

public interface IPasswordHashService
{
    string Hash(string password);
    bool Verify(string passwordHash, string password);
}

public sealed record AdminAccountRequest(
    Guid Id,
    string Username,
    string DisplayName,
    string Email,
    DateTimeOffset RequestedAt);

public sealed record ApprovedAdminInvitation(
    Guid UserId,
    string DisplayName,
    string Email,
    Guid ChallengeId,
    DateTimeOffset ExpiresAt);

public interface IAdminProvisioningStore
{
    Task<bool> CreateRequestAsync(
        Guid requestId,
        string username,
        string displayName,
        string email,
        DateTimeOffset requestedAt,
        CancellationToken cancellationToken);

    Task<IReadOnlyList<AdminAccountRequest>> ListPendingRequestsAsync(CancellationToken cancellationToken);

    Task<ApprovedAdminInvitation?> ApproveRequestAsync(
        Guid requestId,
        Guid reviewerUserId,
        Guid userId,
        Guid challengeId,
        string invitationTokenHash,
        DateTimeOffset reviewedAt,
        DateTimeOffset expiresAt,
        CancellationToken cancellationToken);

    Task<bool> CompleteInvitationAsync(
        string invitationTokenHash,
        string passwordHash,
        DateTimeOffset now,
        CancellationToken cancellationToken);
}

public interface IAdminInvitationEmailSender
{
    Task SendAsync(
        string email,
        string displayName,
        string invitationToken,
        Guid challengeId,
        CancellationToken cancellationToken);
}
