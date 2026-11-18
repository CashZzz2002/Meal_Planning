using System.Net.Mail;
using System.Security.Cryptography;

namespace MealPlanning.Admin.Application.Authentication;

public enum AdminRequestResult
{
    Accepted,
    Conflict,
    Invalid
}

public sealed class AdminProvisioningService(
    IAdminProvisioningStore store,
    IAdminInvitationEmailSender emailSender,
    IPasswordHashService passwordHashService,
    TimeProvider timeProvider)
{
    private static readonly TimeSpan InvitationLifetime = TimeSpan.FromHours(24);

    public async Task<AdminRequestResult> RequestAsync(
        string username,
        string displayName,
        string email,
        CancellationToken cancellationToken)
    {
        var normalizedUsername = NormalizeUsername(username);
        var normalizedEmail = NormalizeEmail(email);
        var normalizedDisplayName = displayName.Trim();
        if (normalizedUsername is null || normalizedEmail is null || normalizedDisplayName.Length is < 1 or > 1000)
        {
            return AdminRequestResult.Invalid;
        }

        var created = await store.CreateRequestAsync(
            Guid.NewGuid(), normalizedUsername, normalizedDisplayName, normalizedEmail,
            timeProvider.GetUtcNow(), cancellationToken);
        return created ? AdminRequestResult.Accepted : AdminRequestResult.Conflict;
    }

    public Task<IReadOnlyList<AdminAccountRequest>> ListPendingAsync(CancellationToken cancellationToken) =>
        store.ListPendingRequestsAsync(cancellationToken);

    public async Task<bool> ApproveAsync(
        Guid requestId,
        Guid reviewerUserId,
        CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow();
        var token = CreateToken();
        var challengeId = Guid.NewGuid();
        var invitation = await store.ApproveRequestAsync(
            requestId,
            reviewerUserId,
            Guid.NewGuid(),
            challengeId,
            HashToken(token),
            now,
            now.Add(InvitationLifetime),
            cancellationToken);
        if (invitation is null)
        {
            return false;
        }

        await emailSender.SendAsync(
            invitation.Email,
            invitation.DisplayName,
            token,
            invitation.ChallengeId,
            cancellationToken);
        return true;
    }

    public async Task<bool> CompleteInvitationAsync(
        string invitationToken,
        string password,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(invitationToken) || password.Length < 12)
        {
            return false;
        }

        return await store.CompleteInvitationAsync(
            HashToken(invitationToken),
            passwordHashService.Hash(password),
            timeProvider.GetUtcNow(),
            cancellationToken);
    }

    private static string? NormalizeUsername(string value)
    {
        var normalized = value.Trim().ToLowerInvariant();
        return normalized.Length is >= 3 and <= 200 ? normalized : null;
    }

    private static string? NormalizeEmail(string value)
    {
        var normalized = value.Trim().ToLowerInvariant();
        if (normalized.Length is < 3 or > 1000) return null;
        try
        {
            return new MailAddress(normalized).Address.Equals(normalized, StringComparison.OrdinalIgnoreCase)
                ? normalized
                : null;
        }
        catch (FormatException)
        {
            return null;
        }
    }

    private static string CreateToken() => Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
        .TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static string HashToken(string token) =>
        Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(
            System.Text.Encoding.UTF8.GetBytes(token))).ToLowerInvariant();
}
