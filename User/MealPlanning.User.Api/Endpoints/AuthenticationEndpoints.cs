using System.Security.Claims;
using MealPlanning.User.Api.Authentication;
using MealPlanning.User.Application.Authentication;
using Microsoft.AspNetCore.Mvc;

namespace MealPlanning.User.Api.Endpoints;

internal static class AuthenticationEndpoints
{
    public static IEndpointRouteBuilder MapUserAuthenticationEndpoints(
        this IEndpointRouteBuilder endpoints,
        bool emailEnabled)
    {
        var auth = endpoints.MapGroup("/api/auth").WithTags("Authentication");
        auth.MapPost("/login", LoginAsync).AllowAnonymous().RequireRateLimiting("login").WithName("UserLogin");
        auth.MapGet("/me", Me).RequireAuthorization("UserPortal").WithName("UserCurrentUser");
        auth.MapPost("/logout", LogoutAsync).AllowAnonymous().WithName("UserLogout");
        if (emailEnabled)
        {
            auth.MapPost("/register", RegisterAsync)
                .AllowAnonymous()
                .RequireRateLimiting("login")
                .WithName("RegisterUser");
            auth.MapPost("/verify-email", VerifyEmailAsync)
                .AllowAnonymous()
                .RequireRateLimiting("login")
                .WithName("VerifyUserEmail");
            auth.MapPost("/resend-verification", ResendVerificationAsync)
                .AllowAnonymous()
                .RequireRateLimiting("login")
                .WithName("ResendUserVerification");
        }
        return endpoints;
    }

    private static async Task<IResult> RegisterAsync(
        [FromBody] RegisterRequest request,
        UserRegistrationService registrationService,
        CancellationToken cancellationToken)
    {
        var result = await registrationService.RegisterAsync(
            request.Username, request.DisplayName, request.Email, request.Password, cancellationToken);
        return result switch
        {
            RegistrationResult.Accepted => Results.Accepted(),
            RegistrationResult.Conflict => Results.Conflict(new { message = "That username or email is already registered." }),
            _ => Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["registration"] = ["Provide a valid username, display name, email, and a password of at least 12 characters."]
            })
        };
    }

    private static async Task<IResult> VerifyEmailAsync(
        [FromBody] VerifyEmailRequest request,
        UserRegistrationService registrationService,
        CancellationToken cancellationToken) =>
        await registrationService.VerifyAsync(request.Email, request.Code, cancellationToken)
            ? Results.NoContent()
            : Results.BadRequest(new { message = "The verification code is invalid, expired, or has too many failed attempts." });

    private static async Task<IResult> ResendVerificationAsync(
        [FromBody] ResendVerificationRequest request,
        UserRegistrationService registrationService,
        CancellationToken cancellationToken)
    {
        await registrationService.ResendAsync(request.Email, cancellationToken);
        return Results.Accepted();
    }

    private static async Task<IResult> LoginAsync([FromBody] LoginRequest request, HttpContext context, AuthenticationService authenticationService, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrEmpty(request.Password))
        {
            return Results.ValidationProblem(new Dictionary<string, string[]> { ["credentials"] = ["Username and password are required."] });
        }
        var result = await authenticationService.LoginAsync(request.Username, request.Password, cancellationToken);
        if (result is null) return Results.Unauthorized();
        context.Response.Cookies.Append(UserCookieAuthenticationHandler.CookieName, result.Token, CookieOptions(context, result.ExpiresAt));
        return Results.Ok(new UserResponse(result.User.UserId, result.User.Username, result.User.DisplayName, result.User.ExpiresAt));
    }

    private static IResult Me(ClaimsPrincipal principal) => Results.Ok(new UserResponse(
        Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!), principal.Identity!.Name!, principal.FindFirstValue("display_name")!, null));

    private static async Task<IResult> LogoutAsync(HttpContext context, AuthenticationService authenticationService, CancellationToken cancellationToken)
    {
        if (context.Request.Cookies.TryGetValue(UserCookieAuthenticationHandler.CookieName, out var token))
        {
            await authenticationService.LogoutAsync(token, cancellationToken);
        }
        context.Response.Cookies.Delete(UserCookieAuthenticationHandler.CookieName, CookieOptions(context, DateTimeOffset.UnixEpoch));
        return Results.NoContent();
    }

    private static CookieOptions CookieOptions(HttpContext context, DateTimeOffset expires) => new()
    {
        HttpOnly = true, Secure = context.Request.IsHttps, SameSite = SameSiteMode.Lax, Path = "/", Expires = expires
    };

    private sealed record LoginRequest(string Username, string Password);
    private sealed record RegisterRequest(string Username, string DisplayName, string Email, string Password);
    private sealed record VerifyEmailRequest(string Email, string Code);
    private sealed record ResendVerificationRequest(string Email);
    private sealed record UserResponse(Guid Id, string Username, string DisplayName, DateTimeOffset? ExpiresAt);
}
