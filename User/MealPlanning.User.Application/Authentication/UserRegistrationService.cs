using System.Net.Mail;
using System.Security.Cryptography;

namespace MealPlanning.User.Application.Authentication;

public enum RegistrationResult
{
    Accepted,
    Conflict,
    Invalid
}

public sealed class UserRegistrationService(
    IUserRegistrationStore store,
    IUserVerificationEmailSender emailSender,
    IPasswordHashService passwordHashService,
    TimeProvider timeProvider)
{
    private static readonly TimeSpan CodeLifetime = TimeSpan.FromMinutes(10);
    private const int MaximumAttempts = 5;

    public async Task<RegistrationResult> RegisterAsync(
        string username,
        string displayName,
        string email,
        string password,
        CancellationToken cancellationToken)
    {
        var normalizedUsername = NormalizeUsername(username);
        var normalizedEmail = NormalizeEmail(email);
        var normalizedDisplayName = displayName.Trim();
        if (normalizedUsername is null || normalizedEmail is null ||
            normalizedDisplayName.Length is < 1 or > 1000 || password.Length < 12)
        {
            return RegistrationResult.Invalid;
        }

        var now = timeProvider.GetUtcNow();
        var code = CreateCode();
        var challengeId = Guid.NewGuid();
        var persistenceResult = await store.CreatePendingUserAsync(
            Guid.NewGuid(),
            normalizedUsername,
            normalizedDisplayName,
            normalizedEmail,
            passwordHashService.Hash(password),
            challengeId,
            passwordHashService.Hash(code),
            now,
            now.Add(CodeLifetime),
            cancellationToken);
        if (persistenceResult == PendingRegistrationResult.Conflict)
        {
            return RegistrationResult.Conflict;
        }

        await emailSender.SendAsync(
            normalizedEmail, normalizedDisplayName, code, challengeId, cancellationToken);
        return RegistrationResult.Accepted;
    }

    public async Task<bool> VerifyAsync(
        string email,
        string code,
        CancellationToken cancellationToken)
    {
        var normalizedEmail = NormalizeEmail(email);
        if (normalizedEmail is null || code.Length != 6 || code.Any(character => !char.IsAsciiDigit(character)))
        {
            return false;
        }

        var now = timeProvider.GetUtcNow();
        var challenge = await store.FindVerificationChallengeAsync(normalizedEmail, now, cancellationToken);
        if (challenge is null || challenge.FailedAttempts >= MaximumAttempts)
        {
            return false;
        }

        if (!passwordHashService.Verify(challenge.SecretHash, code))
        {
            await store.RecordFailedAttemptAsync(challenge.Id, cancellationToken);
            return false;
        }

        return await store.ActivateUserAsync(challenge.Id, challenge.UserId, now, cancellationToken);
    }

    public async Task ResendAsync(string email, CancellationToken cancellationToken)
    {
        var normalizedEmail = NormalizeEmail(email);
        if (normalizedEmail is null) return;

        var now = timeProvider.GetUtcNow();
        var code = CreateCode();
        var challengeId = Guid.NewGuid();
        var user = await store.ReplaceVerificationChallengeAsync(
            normalizedEmail,
            challengeId,
            passwordHashService.Hash(code),
            now,
            now.Add(CodeLifetime),
            cancellationToken);
        if (user is not null)
        {
            await emailSender.SendAsync(user.Email, user.DisplayName, code, challengeId, cancellationToken);
        }
    }

    private static string CreateCode() => RandomNumberGenerator.GetInt32(0, 1_000_000)
        .ToString("D6", System.Globalization.CultureInfo.InvariantCulture);

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
}
