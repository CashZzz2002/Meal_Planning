using System.Security.Claims;
using System.Text.Encodings.Web;
using MealPlanning.Admin.Application.Authentication;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;
using AppAuthenticationService = MealPlanning.Admin.Application.Authentication.AuthenticationService;

namespace MealPlanning.Admin.Api.Authentication;

internal sealed class AdminCookieAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    AppAuthenticationService authenticationService)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "AdminDatabaseSession";
    public const string CookieName = "mealplanning.admin.session";

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Cookies.TryGetValue(CookieName, out var token) || string.IsNullOrWhiteSpace(token))
        {
            return AuthenticateResult.NoResult();
        }

        var session = await authenticationService.AuthenticateAsync(token, Context.RequestAborted);
        if (session is null)
        {
            return AuthenticateResult.Fail("The session is invalid or expired.");
        }

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, session.UserId.ToString()),
            new Claim(ClaimTypes.Name, session.Username),
            new Claim("display_name", session.DisplayName)
        };
        claims.AddRange(session.Roles.Select(role => new Claim(ClaimTypes.Role, role)));
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, SchemeName));
        return AuthenticateResult.Success(new AuthenticationTicket(principal, SchemeName));
    }
}
