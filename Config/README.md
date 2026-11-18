# Stage configuration and local hosting

`Config/` is a physical directory, shown as **.Config** in `MealPlanning.sln`, following the MMS configuration pattern. Configuration/bootstrap code lives in `Shared/MealPlanning.Shared.Hosting`; the C# namespace is `MealPlanning.Hosting`.

## Loading and precedence

Each API calls `AddStageConfig(args, typeof(Program).Assembly)` once before its grouped service registration. From lowest to highest priority:

1. The API's normal ASP.NET Core defaults (`appsettings.json`, `appsettings.{ASPNETCORE_ENVIRONMENT}.json`).
2. Shared `Config/appsettings.json`.
3. Required `Config/custom-setting-{stage}.json`.
4. **That API's** .NET User Secrets, only in `Development`.
5. Environment variables.
6. Command-line arguments.

The selector applies external overrides **before** choosing the stage file. Stage is trimmed, lowercased and restricted to `dev`, `sit`, `uat`, `preprod`, or `prod`. Stage files cannot contain their own `Stage` selector. Missing files and invalid startup options fail explicitly; example files are never used as a fallback.

Shared JSON is loaded as a startup snapshot. Restart the process after changing Stage or shared settings.

| Setting | Responsibility |
| --- | --- |
| `Debug` / `Release` | .NET build configuration |
| `Stage` | Select shared application settings |
| `ASPNETCORE_ENVIRONMENT` | ASP.NET Core environment; controls Development User Secrets |
| `NODE_ENV` | Next.js `development`, `production`, or `test` behavior |

A Release build does **not** select `prod`. The checked-in default is the local `dev` stage.

### Config directory and build output

Resolution order:

1. Explicit `ConfigDirectory` (use an absolute path when sharing it between APIs and tooling).
2. `Config/` in the application's content root.
3. `Config/` beside the nearest parent `MealPlanning.sln` for nested source projects.
4. `Config/` beside the application assembly for a built/published host launched elsewhere.

Both APIs import `Shared/MealPlanning.Shared.Hosting/ConfigAssets.targets`. It links real, non-secret JSON files into the project and copies them to `bin/<configuration>/net8.0/Config` and publish output. `*.example.json` files are excluded. `MealPlanningConfigDirectory` is an optional MSBuild override for packaging from another non-secret config directory.

## Settings contract

- `BusinessTimeZone` must be `Asia/Yangon`.
- `Services:Admin` and `Services:User` each define `ApiUrl`, `PortalUrl`, and explicit `AllowedOrigins` for that API's CORS policy.
- URLs are absolute HTTP(S) **origins** without credentials, paths, query strings, fragments, or trailing slashes.
- `Swagger:Enabled` controls both the Swagger middleware and synchronized API browser launch. It is enabled in `dev` and disabled in the other templates.
- `Database:Enabled` defaults to `false`. Enabling it requires `ConnectionStrings:MealPlanner` or the standard Neon `DATABASE_URL` from a private source. `ConnectionStrings:MealPlanner` takes precedence when both exist.
- `HttpsRedirection:Enabled` controls HTTP-to-HTTPS redirection; it is disabled for the local HTTP profiles.
- `Email:Enabled` controls Resend-backed invitation and verification endpoints. Enabling it requires `Email:Provider=Resend`, a sender name/address, and private `RESEND_APITOKEN` configuration.
- Logging uses the built-in structured JSON console formatter, with UTC audit-log timestamps. Business time still uses the existing `IMyanmarClock` in `Asia/Yangon`.

`StageOptions`, `ServiceEndpointsOptions`, `DatabaseOptions`, `SwaggerOptions`, `HttpsRedirectionOptions`, and `EmailOptions` are bound with the options pattern and validated on startup. Admin and User register only their own service endpoint options and Infrastructure. Shared.Hosting references no business project.

Environment examples (non-secret):

```powershell
$env:Stage = 'dev'
$env:Services__Admin__ApiUrl = 'http://localhost:5101'
$env:Services__Admin__PortalUrl = 'http://localhost:3101'
$env:Services__Admin__AllowedOrigins__0 = 'http://localhost:3101'
```

### Local secrets

Each API has its own existing `UserSecretsId`. Use **Manage User Secrets** on the corresponding API in Visual Studio, or the CLI. Replace the placeholder privately; do not put the actual value in shared JSON or launch settings.

```powershell
dotnet user-secrets set 'ConnectionStrings:MealPlanner' '[REDACTED_SECRET]' --project .\Admin\MealPlanning.Admin.Api
dotnet user-secrets set 'Database:Enabled' 'true' --project .\Admin\MealPlanning.Admin.Api
dotnet user-secrets set 'ConnectionStrings:MealPlanner' '[REDACTED_SECRET]' --project .\User\MealPlanning.User.Api
dotnet user-secrets set 'Database:Enabled' 'true' --project .\User\MealPlanning.User.Api
```

Use the pooled connection for API traffic. Deployed hosts receive `ConnectionStrings__MealPlanner` or `DATABASE_URL` from the approved environment/secret store. Direct `DATABASE_URL_UNPOOLED` connections remain reserved for migrations and verification. The connection normalizer accepts Neon URI values with or without the surrounding quotes emitted by environment-file tooling.

Visual Studio Docker profiles receive the ignored root `.env.local`, not Development User Secrets. Configure the Resend key there through hidden input:

```powershell
.\scripts\Set-ResendSecret.ps1
```

The resulting private values are `RESEND_APITOKEN`, `Email__Enabled=true`, and `Email__DevelopmentRecipient`. The recipient override is accepted only for the `dev` stage and routes test messages to the Resend account inbox. Do not copy the API token into shared JSON, source, launch settings, screenshots, or logs.

For SIT/UAT/preprod/prod, copy the matching example to `custom-setting-<stage>.json`, replace its public placeholders, and supply private settings externally. Real non-dev files are ignored by Git; review their non-secret contents before packaging them.

## Visual Studio and portal configuration

From the application directory:

```powershell
npm run config:sync
npm run config:check
```

The sync command reads the selected shared config and environment overrides, then updates only the managed URL/browser fields in the API `http` profiles and each portal's `.vscode/launch.json`. It preserves the API `Container (Dockerfile)` profiles and other debugger options. Run it after changing local URLs, then reload the solution. Local launch tooling requires four distinct loopback HTTP ports.

Both portals and both APIs have startup action **Start** in **All portals and APIs**. The APIs select `Container (Dockerfile)` and receive the ignored root `.env.local`; the portals run locally. Both `.esproj` projects also have **Build** and **Deploy** selected in Configuration Manager for every solution configuration. JSPS uses local Deploy to execute the startup command; selecting only Start opens a browser without starting its server. Here, Deploy means starting the local development server. Each portal's `.vscode/launch.json` opens its own URL; the API container profiles publish ports 5101 and 5201.

Visual Studio completes local portal Deploy **before** starting API container debugging, so the `.esproj` commands use `-SkipApiWait -TrackVisualStudio` to avoid a startup deadlock. The portal launcher starts Next.js on the configured fixed port and observes the exact ancestor Visual Studio instance's debugger session. Run and break modes keep it alive; Stop ends it. This also closes the native command window, which JSPS otherwise leaves running. Other Visual Studio instances are isolated by process ID and solution path. Verify both API `/health/ready` endpoints after F5 completes.

For a real Visual Studio session, `Prepare-VisualStudioLaunch.ps1` runs before Node starts. It validates Docker and the ignored Neon child-branch environment, removes an exact stale MealPlanning portal/API process or fixed-name API container, checks that Windows can bind the configured ports, and stops with a diagnostic instead of killing an unrelated owner. Local portals use `3101`/`3102`; `3001`/`3002` can fall inside a Windows/Hyper-V excluded TCP range without appearing as a listening process.

The Windows launcher creates a suspended Node process, assigns it to a **kill-on-close Job Object**, and only then resumes it. All descendants inherit that job. It also tracks the exact parent command process; normal exit, parent-only termination, and forced launcher termination release the portal tree. Admin and User have separate owners/jobs. The API processes are independently owned by Visual Studio.

Direct `Start-Portal.ps1` commands also wait for the corresponding API's `/health/ready` by default. Dependencies are installed explicitly with `npm ci`; `.esproj` uses `ShouldRunNpmInstall=false` and `ShouldRunBuildScript=false` for predictable F5 builds. Run each portal's `npm run build` for production verification.

The portal launcher resolves `node.exe` from the process PATH first, then falls back to the ignored `.run/tools/node/node.exe`. This allows Visual Studio to use a local portable Node 24 runtime when its process environment cannot see a machine-wide installation.

`Start-Local.ps1` uses detached portal owners and records process IDs **and creation times** for `Stop-Local.ps1`. State snapshots are replaced atomically with bounded retries for temporary file locks. Retained process handles ensure a failed startup also stops services whose state could not be saved. Its API processes run built DLLs directly. `-PortalsOnly` explicitly skips API readiness for the existing static-demo preview.

### Public values and production builds

`scripts/public-config.mjs` projects an allowlist of public settings; it never loads API User Secrets or exports complete configuration to a browser. Set Stage and service URLs in shared config or the common environment so APIs and portals select the same values.

All portal `dev`, `build`, and `start` npm scripts use `scripts/portal.mjs`. It injects **only `NEXT_PUBLIC_API_URL`** from that portal's `Services:<name>:ApiUrl`; an explicitly supplied `NEXT_PUBLIC_API_URL` has higher priority for a single-portal command. Use the two `Services__<name>__ApiUrl` variables for a combined build with different API URLs.

Next.js freezes public environment values during `next build`. Changing an environment variable at runtime does not change the browser bundle; rebuild for a different public API URL. The portal Dockerfiles require a `NEXT_PUBLIC_API_URL` **build argument**, and Compose now supplies it at build time. Container builds run Next directly within their portal-only build context.

## Verification

```powershell
dotnet test .\Shared\MealPlanning.Shared.Hosting.Tests --configuration Release --no-restore
npm run test:tooling
npm run config:check
# Build Release first, and stop any existing local/Visual Studio services:
.\scripts\Test-LocalLifecycle.ps1 -Configuration Release
```

The xUnit tests cover stage selection, configuration paths, validation, precedence, and isolated synthetic API User Secrets. Node tests cover the public-value boundary and non-destructive launch synchronization. The Windows lifecycle test executes the actual `.esproj` startup commands under command-line owners, checks API/Swagger/CORS/portal responses, terminates command and launcher processes separately, verifies descendant cleanup and restart, and leaves ports free. Real Visual Studio F5/Stop must also be checked after changes to native launch behavior. Runtime lifecycle verification uses `Database__Enabled=false`; database acceptance still needs readiness with the database enabled plus persisted read-back/verification SQL.
