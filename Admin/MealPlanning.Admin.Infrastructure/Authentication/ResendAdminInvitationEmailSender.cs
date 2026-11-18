using System.Net;
using MealPlanning.Admin.Application.Authentication;
using Microsoft.Extensions.Options;
using Resend;

namespace MealPlanning.Admin.Infrastructure.Authentication;

internal sealed class ResendAdminInvitationEmailSender(
    IResend resend,
    IOptions<AdminEmailSettings> settings) : IAdminInvitationEmailSender
{
    public async Task SendAsync(
        string email,
        string displayName,
        string invitationToken,
        Guid challengeId,
        CancellationToken cancellationToken)
    {
        var options = settings.Value;
        var link = $"{options.PortalUrl}/accept-invitation?token={Uri.EscapeDataString(invitationToken)}";
        var encodedName = WebUtility.HtmlEncode(displayName);
        var encodedLink = WebUtility.HtmlEncode(link);
        var recipient = string.IsNullOrWhiteSpace(options.DevelopmentRecipient)
            ? email
            : options.DevelopmentRecipient;
        var deliveryNote = recipient == email
            ? string.Empty
            : $" Development delivery for requested address {email}.";
        var message = new EmailMessage
        {
            From = $"{options.FromName} <{options.FromAddress}>",
            Subject = $"{(recipient == email ? string.Empty : "[DEV] ")}Set up your Meal Planning Admin account",
            TextBody = $"Hello {displayName}, your Admin request was approved. Set your password within 24 hours: {link}{deliveryNote}",
            HtmlBody = $"<p>Hello {encodedName},</p><p>Your Admin request was approved.</p><p><a href=\"{encodedLink}\">Set your password</a> within 24 hours.</p>{(recipient == email ? string.Empty : $"<p><strong>Development delivery:</strong> requested address {WebUtility.HtmlEncode(email)}.</p>")}"
        };
        message.To.Add(recipient);
        await resend.EmailSendAsync($"admin-invitation/{challengeId}", message, cancellationToken);
    }
}

internal sealed class AdminEmailSettings
{
    public string FromName { get; set; } = string.Empty;
    public string FromAddress { get; set; } = string.Empty;
    public string DevelopmentRecipient { get; set; } = string.Empty;
    public string PortalUrl { get; set; } = string.Empty;
}
