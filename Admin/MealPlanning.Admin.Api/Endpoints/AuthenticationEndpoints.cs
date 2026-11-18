using System.Security.Claims;
using MealPlanning.Admin.Api.Authentication;
using MealPlanning.Admin.Application.Authentication;
using Microsoft.AspNetCore.Mvc;

namespace MealPlanning.Admin.Api.Endpoints;

internal static class AuthenticationEndpoints
{
    public static IEndpointRouteBuilder MapAdminAuthenticationEndpoints(
        this IEndpointRouteBuilder endpoints,
        bool emailEnabled)
    {
        var auth = endpoints.MapGroup("/api/auth").WithTags("Authentication");
        auth.MapPost("/login", LoginAsync)
            .AllowAnonymous()
            .RequireRateLimiting("login")
            .WithName("AdminLogin");
        auth.MapGet("/me", Me).RequireAuthorization("AdminPortal").WithName("AdminCurrentUser");
        auth.MapPost("/logout", LogoutAsync).AllowAnonymous().WithName("AdminLogout");
        if (emailEnabled)
        {
            auth.MapPost("/admin-requests", RequestAdminAsync)
                .AllowAnonymous()
                .RequireRateLimiting("login")
                .WithName("RequestAdminAccount");
            auth.MapGet("/admin-requests", ListAdminRequestsAsync)
                .RequireAuthorization("SuperAdmin")
                .WithName("ListPendingAdminRequests");
            auth.MapPost("/admin-requests/{requestId:guid}/approve", ApproveAdminRequestAsync)
                .RequireAuthorization("SuperAdmin")
                .WithName("ApproveAdminRequest");
            auth.MapPost("/admin-invitations/accept", AcceptInvitationAsync)
                .AllowAnonymous()
                .RequireRateLimiting("login")
                .WithName("AcceptAdminInvitation");
        }
        return endpoints;
    }

    private static async Task<IResult> RequestAdminAsync(
        [FromBody] AdminRequest request,
        AdminProvisioningService service,
        CancellationToken cancellationToken)
    {
        var result = await service.RequestAsync(
            request.Username, request.DisplayName, request.Email, cancellationToken);
        return result switch
        {
            AdminRequestResult.Accepted => Results.Accepted(),
            AdminRequestResult.Conflict => Results.Conflict(new { message = "A pending request or account already uses that username or email." }),
            _ => Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["request"] = ["Username, display name, or email is invalid."]
            })
        };
    }

    private static async Task<IResult> ListAdminRequestsAsync(
        AdminProvisioningService service,
        CancellationToken cancellationToken) =>
        Results.Ok(await service.ListPendingAsync(cancellationToken));

    private static async Task<IResult> ApproveAdminRequestAsync(
        Guid requestId,
        ClaimsPrincipal principal,
        AdminProvisioningService service,
        CancellationToken cancellationToken)
    {
        var reviewerId = Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!);
        return await service.ApproveAsync(requestId, reviewerId, cancellationToken)
            ? Results.NoContent()
            : Results.Conflict(new { message = "The request is no longer pending or its identity conflicts with an existing account." });
    }

    private static async Task<IResult> AcceptInvitationAsync(
        [FromBody] AcceptInvitationRequest request,
        AdminProvisioningService service,
        CancellationToken cancellationToken) =>
        await service.CompleteInvitationAsync(request.Token, request.Password, cancellationToken)
            ? Results.NoContent()
            : Results.BadRequest(new { message = "The invitation is invalid, expired, or the password is shorter than 12 characters." });

    private static async Task<IResult> LoginAsync(
        [FromBody] LoginRequest request,
        HttpContext context,
        AuthenticationService authenticationService,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.Username) || string.IsNullOrEmpty(request.Password))
        {
            return Results.ValidationProblem(new Dictionary<string, string[]>
            {
                ["credentials"] = ["Username and password are required."]
            });
        }

        var result = await authenticationService.LoginAsync(request.Username, request.Password, cancellationToken);
        if (result is null) return Results.Unauthorized();
        context.Response.Cookies.Append(AdminCookieAuthenticationHandler.CookieName, result.Token, CookieOptions(context, result.ExpiresAt));
        return Results.Ok(new UserResponse(result.User.UserId, result.User.Username, result.User.DisplayName, result.User.ExpiresAt));
    }

    private static IResult Me(ClaimsPrincipal principal) => Results.Ok(new UserResponse(
        Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!),
        principal.Identity!.Name!,
        principal.FindFirstValue("display_name")!,
        null));

    private static async Task<IResult> LogoutAsync(HttpContext context, AuthenticationService authenticationService, CancellationToken cancellationToken)
    {
        if (context.Request.Cookies.TryGetValue(AdminCookieAuthenticationHandler.CookieName, out var token))
        {
            await authenticationService.LogoutAsync(token, cancellationToken);
        }
        context.Response.Cookies.Delete(AdminCookieAuthenticationHandler.CookieName, CookieOptions(context, DateTimeOffset.UnixEpoch));
        return Results.NoContent();
    }

    private static CookieOptions CookieOptions(HttpContext context, DateTimeOffset expires) => new()
    {
        HttpOnly = true,
        Secure = context.Request.IsHttps,
        SameSite = SameSiteMode.Lax,
        Path = "/",
        Expires = expires
    };

    private sealed record LoginRequest(string Username, string Password);
    private sealed record AdminRequest(string Username, string DisplayName, string Email);
    private sealed record AcceptInvitationRequest(string Token, string Password);
    private sealed record UserResponse(Guid Id, string Username, string DisplayName, DateTimeOffset? ExpiresAt);
}
