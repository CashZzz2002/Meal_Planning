# Meal Planning Platform

Myanmar-focused weekly meal planning, township warehouse operations, shopping and ordering. The repository uses Next.js/TypeScript for the portals, .NET 8/C# for APIs, and Neon Postgres.

## Repository structure

```text
MealPlanning.sln
├─ Config/                            # .Config solution folder; Stage-based non-secret settings
├─ Shared/
│  ├─ MealPlanning.Shared.Hosting/     # Configuration, host options, logging and health helpers
│  └─ MealPlanning.Shared.Hosting.Tests/
├─ Admin/
│  ├─ MealPlanning.Admin.Domain/
│  ├─ MealPlanning.Admin.Application/
│  ├─ MealPlanning.Admin.Infrastructure/
│  ├─ MealPlanning.Admin.Api/
│  ├─ MealPlanning.Admin.Domain.Tests/
│  └─ admin-web/                       # Next.js admin portal
├─ User/
│  ├─ MealPlanning.User.Domain/
│  ├─ MealPlanning.User.Application/
│  ├─ MealPlanning.User.Infrastructure/
│  ├─ MealPlanning.User.Api/
│  ├─ MealPlanning.User.Domain.Tests/
│  └─ user-web/                        # Next.js responsive user portal
├─ Database/
│  ├─ PostgreSql/                      # Deployable Neon/PostgreSQL scripts
│  └─ Oracle/                          # Supplied Oracle source retained for traceability
└─ compose.yaml
```

Each side follows `Api -> Infrastructure -> Application -> Domain`. API hosts also reference `Shared.Hosting`, which has no business-project dependencies. The Next.js projects call their APIs over HTTP. Their `.esproj` files are independent Visual Studio startup projects.

The current APIs expose health, Myanmar time and module-directory endpoints, with Swagger in the `dev` stage. The User API also exposes `GET /api/reference/meal-types` through the Application and Infrastructure layers, and the User portal displays that live Neon reference data separately from its demo dashboard. Other portal meal, order and warehouse data is still presentation/demo data.

## Myanmar-time policy

Business time uses `Asia/Yangon` (`+06:30`) in the database, APIs, portals and containers.

- The Neon database and owner role default to `TimeZone = 'Asia/Yangon'`.
- Business timestamp columns use PostgreSQL `TIMESTAMPTZ(6)`; sessions input and display Myanmar local time.
- The C# applications expose time through a centralized `IMyanmarClock`.
- External timestamps must retain their original provider value for audit, with a separate Myanmar business timestamp where required.

## Database scripts

The supplied 69-table Oracle schema is converted reproducibly by `scripts/Convert-OracleSchemaToPostgres.mjs`. PostgreSQL scripts run in numeric order using the direct `DATABASE_URL_UNPOOLED` connection:

1. `000_database_settings.sql` — sets database and owner-role timezone defaults.
2. `001_schema.sql` — creates 69 tables, native UUID/boolean/JSONB types, 69 primary keys and 128 foreign keys.
3. `002_foreign_key_indexes.sql` — creates 128 foreign-key indexes.
4. `003_seed_reference_data.sql` — idempotently seeds menus, units, meal types and payment methods.
5. `verify_schema.sql` — reports table, key, seed and timezone evidence.

The source SQL hash is embedded in the generated schema so source changes fail conversion until reviewed.

## Local prerequisites

- .NET 8 SDK or a newer SDK capable of targeting .NET 8
- Node.js 24 and npm
- Visual Studio with the ASP.NET/web and JavaScript/TypeScript tooling for the F5 workflow
- Docker Desktop with the Linux container engine running
- For database-enabled mode: Neon CLI 9.3 or newer and access to the linked Neon project

Authenticate, select or create a non-production Neon child branch, and pull its ignored environment file without printing secrets:

```powershell
neon login
neon checkout dev-docker-local --create
neon env pull --file .env.local
```

Do not place registry credentials, database passwords or connection strings in the repository.

Visual Studio must be able to resolve `node.exe`. If a machine-wide Node installation is unavailable, `Start-Portal.ps1` also accepts an ignored portable Node 24 runtime at `.run/tools/node/node.exe`.

## Run the complete local stack

Pull the ignored Neon environment file, then pass it to Compose:

```powershell
neon env pull --file .env.local
docker compose --env-file .env.local up --build
```

The applications become available after both Npgsql readiness checks reach Neon:

| Service | URL |
| --- | --- |
| Admin portal | `http://localhost:3101` |
| User portal | `http://localhost:3102` |
| Admin Swagger | `http://localhost:5101/swagger` |
| User Swagger | `http://localhost:5201/swagger` |
| Admin API live/readiness | `http://localhost:5101/health/live`, `http://localhost:5101/health/ready` |
| User API live/readiness | `http://localhost:5201/health/live`, `http://localhost:5201/health/ready` |

Stop the stack without deleting database data:

```powershell
docker compose down
```

Neon database data is not stored in a local Docker volume. Compose supplies each portal's `NEXT_PUBLIC_API_URL` as a **build argument**. Rebuild the portal image after changing its public API URL; a runtime environment change cannot update a compiled browser bundle.

## Run APIs and portals locally

The default `Stage=dev` configuration runs with `Database:Enabled=false`. The Visual Studio Docker profiles enable the database and pass the ignored `.env.local` file to each API container. Normal API traffic uses its pooled `DATABASE_URL`; direct `DATABASE_URL_UNPOOLED` remains reserved for migrations and verification. See [Config/README.md](Config/README.md) for settings, safe secret commands, path resolution, stage templates and precedence.

### Recommended: Visual Studio (F5 / Stop)

1. If you previously used the PowerShell launcher, run `.\scripts\Stop-Local.ps1` first to release its processes and ports.
2. Install dependencies and synchronize the native launch settings once (commands below).
3. Confirm Docker Desktop is running and `.env.local` belongs to the intended non-production Neon branch.
4. Open `MealPlanning.sln`, select **All portals and APIs**, and press **F5**. Reload the solution after changing shared launch settings if Visual Studio still shows an old profile.
5. Visual Studio starts both local portals during Deploy, then builds and starts both API Docker containers. The four separate pages are:
   - Admin Swagger: `http://localhost:5101/swagger`
   - User Swagger: `http://localhost:5201/swagger`
   - Admin portal: `http://localhost:3101`
   - User portal: `http://localhost:3102`
6. Press the red **Stop** button (**Shift+F5**). Both API containers and the portal process trees stop. Allow a few seconds for process/port cleanup before starting again.

An already-open browser tab can still display its last rendered page after Stop. Refreshing it after shutdown fails to connect because the portal server has stopped. Deleting `.next` or browser caches is unnecessary for stopping the servers.

The shared `MealPlanning.slnLaunch` profile uses these startup actions:

| Project | Action | Debug target |
| --- | --- | --- |
| `MealPlanning.Admin.Api` | Start | `Container (Dockerfile)` |
| `MealPlanning.User.Api` | Start | `Container (Dockerfile)` |
| `MealPlanning.Admin.WebPortal` | Start | `Launch Admin portal` (Edge) |
| `MealPlanning.User.WebPortal` | Start | `Launch User portal` (Edge) |

If the profile is missing, enable **Tools > Options > Environment > Preview Features > Enable Multi-Project Launch Profiles** in Visual Studio 2022 17.11 or later (newer versions place Preview Features under All Settings). You can also right-click the solution, open **Configure Startup Projects**, and set all four projects to **Start**.

In **Build > Configuration Manager**, keep **Build** and **Deploy** checked for both WebPortal projects. These flags are included in the solution. JavaScript projects use the local Deploy phase to start their development servers.

Each `.esproj` starts `Start-Portal.ps1 -SkipApiWait` during local Deploy because Visual Studio completes portal Deploy before starting API debugging. The launcher tracks that exact Visual Studio debugger session and ends on Stop. A Windows kill-on-close Job Object owns all Node descendants and also handles forced launcher termination. After F5 finishes, use both `/health/ready` endpoints to confirm the API containers reached Neon. Install dependencies explicitly before the first F5 run; Visual Studio's normal build uses those installed dependencies:

When connected to a real Visual Studio session, each portal launcher runs `Prepare-VisualStudioLaunch.ps1` first. The preflight validates Docker Desktop, the private Neon child-branch environment, and port bindability; removes only exact stale MealPlanning containers/processes; and refuses to terminate an unrelated port owner. Portal ports use `3101` and `3102` because Windows/Hyper-V may reserve the common `3001`/`3002` range even when no process is listening.

```powershell
dotnet restore .\MealPlanning.sln
npm ci
npm --prefix .\Admin\admin-web ci
npm --prefix .\User\user-web ci
npm run config:sync
```

Portal lifecycle diagnostics are written to `.run/logs/portal-Admin-owner.log` and `.run/logs/portal-User-owner.log`. A temporarily locked or unwritable diagnostic log does not interrupt portal startup or cleanup.

Change shared URLs in `Config/custom-setting-dev.json`, run `npm run config:sync`, and reload the solution. `npm run config:check` verifies that native API/browser launch URLs agree with the selected Stage. Full configuration details are in [Config/README.md](Config/README.md).

### Standalone PowerShell launcher

For a deliberately background-running stack, run these commands from the application folder:

```powershell
.\scripts\Start-Local.ps1
# When finished:
.\scripts\Stop-Local.ps1
```

This launcher builds the .NET solution, starts four background services, stores logs under ignored `.run\logs`, and opens both Swagger pages and portals. It records process IDs and creation times in `.run\local-processes.json`; the processes keep running after the command returns and are controlled by `Stop-Local.ps1`. Stop the script-managed stack before switching to Visual Studio F5 or Build/Rebuild.

Process-state snapshots are replaced atomically, with a bounded retry for temporary file locks. If startup fails, the launcher stops every process it started using retained process handles, including a process whose state could not yet be saved.

An explicit UI-only static-demo preview is available with `.\scripts\Start-Local.ps1 -PortalsOnly`; finish it with `.\scripts\Stop-Local.ps1` as well.

API liveness URLs are `http://localhost:5101/health/live` and `http://localhost:5201/health/live`. `/weatherforecast` is not part of this application.

### DLL file-lock troubleshooting

If a build reports that `MealPlanning.Admin.Api` or `MealPlanning.User.Api` is locking an Application/Infrastructure DLL, stop the local script-managed processes and rebuild:

```powershell
.\scripts\Stop-Local.ps1
dotnet clean .\MealPlanning.sln
dotnet build .\MealPlanning.sln --no-restore
```

If Visual Studio itself started the APIs, press the red **Stop** button before rebuilding instead of using `Stop-Local.ps1`.

### Manual commands

Run each command in its own terminal:

```powershell
dotnet run --project .\Admin\MealPlanning.Admin.Api --launch-profile http
dotnet run --project .\User\MealPlanning.User.Api --launch-profile http
.\scripts\Start-Portal.ps1 -Portal Admin
.\scripts\Start-Portal.ps1 -Portal User
```

Open the URLs above and use **Ctrl+C** in each terminal when finished. For cross-platform portal commands, use `npm --prefix Admin/admin-web run dev` and `npm --prefix User/user-web run dev`; the Windows Visual Studio launcher adds Job Object lifetime management.

Database acceptance requires both `/health/ready` endpoints **with the database enabled** and persisted read-back checks against Neon. An empty readiness-check list in database-disabled mode is not database acceptance.

## Validation commands

```powershell
dotnet restore .\MealPlanning.sln
dotnet build .\MealPlanning.sln --configuration Release --no-restore
dotnet test .\MealPlanning.sln --configuration Release --no-build --no-restore
npm run test:tooling
npm run config:check
npm --prefix .\Admin\admin-web run lint
npm --prefix .\User\user-web run lint
npm --prefix .\Admin\admin-web run build
npm --prefix .\User\user-web run build
.\scripts\Test-LocalLifecycle.ps1 -Configuration Release
git diff --check
```

The lifecycle check needs free local ports. It runs the actual `.esproj` startup commands under command-line owners, validates Swagger/health/time/CORS/portal responses, checks parent-only and forced-launcher shutdown and restart, and leaves services stopped. It disables database access for the test. Changes to native launch behavior also require a real Visual Studio F5/Stop check.

Production dependency audit:

```powershell
npm --prefix .\Admin\admin-web audit --omit=dev
npm --prefix .\User\user-web audit --omit=dev
```

## AWS phase (after local database acceptance)

The intended next phase is Amplify Hosting or container hosting for Next.js and ECR/ECS Fargate for the APIs, with Neon retained as managed Postgres. Secrets Manager, CloudWatch, ACM/Route 53 and WAF will be added in that phase. AWS resources are not created by the current local-first implementation.
