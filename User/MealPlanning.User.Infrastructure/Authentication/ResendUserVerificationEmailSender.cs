using System.Net;
using MealPlanning.User.Application.Authentication;
using Microsoft.Extensions.Options;
using Resend;

namespace MealPlanning.User.Infrastructure.Authentication;

internal sealed class ResendUserVerificationEmailSender(
    IResend resend,
    IOptions<UserEmailSettings> settings) : IUserVerificationEmailSender
{
    public async Task SendAsync(
        string email,
        string displayName,
        string code,
        Guid challengeId,
        CancellationToken cancellationToken)
    {
        var options = settings.Value;
        var encodedName = WebUtility.HtmlEncode(displayName);
        var encodedCode = WebUtility.HtmlEncode(code);
        var recipient = string.IsNullOrWhiteSpace(options.DevelopmentRecipient)
            ? email
            : options.DevelopmentRecipient;
        var deliveryNote = recipient == email
            ? string.Empty
            : $" Development delivery for requested address {email}.";
        var message = new EmailMessage
        {
            From = $"{options.FromName} <{options.FromAddress}>",
            Subject = $"{(recipient == email ? string.Empty : "[DEV] ")}Your Meal Planning verification code",
            TextBody = $"Hello {displayName}, your Meal Planning verification code is {code}. It expires in 10 minutes.{deliveryNote}",
            HtmlBody = $"<p>Hello {encodedName},</p><p>Your verification code is:</p><p style=\"font-size:28px;font-weight:700;letter-spacing:6px\">{encodedCode}</p><p>It expires in 10 minutes.</p>{(recipient == email ? string.Empty : $"<p><strong>Development delivery:</strong> requested address {WebUtility.HtmlEncode(email)}.</p>")}"
        };
        message.To.Add(recipient);
        await resend.EmailSendAsync($"user-email-verification/{challengeId}", message, cancellationToken);
    }
}

internal sealed class UserEmailSettings
{
    public string FromName { get; set; } = string.Empty;
    public string FromAddress { get; set; } = string.Empty;
    public string DevelopmentRecipient { get; set; } = string.Empty;
}
