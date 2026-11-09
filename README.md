# Meal Planning Platform

Myanmar-focused weekly meal planning, township warehouse operations, shopping and ordering. The repository uses Next.js/TypeScript for the portals, .NET 8/C# for APIs, and Oracle Database 19c.

## Repository structure

```text
MealPlanning.sln
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
│  ├─ Oracle/                          # Versioned Oracle schema scripts
│  └─ ContainerSetup/                  # First-container bootstrap
└─ compose.yaml
```

Each side follows `Api -> Infrastructure -> Application -> Domain`. The Next.js projects call their APIs over HTTP and do not reference server-side Domain projects. The `.esproj` files make both Next.js portals visible in the Visual Studio solution.

## Myanmar-time policy

Business time uses `Asia/Yangon` (`+06:30`) in the database, APIs, portals and containers.

- Oracle sessions set `TIME_ZONE = 'Asia/Yangon'`.
- Business timestamp columns are converted to `TIMESTAMP(6) WITH TIME ZONE` during first setup.
- The C# applications expose time through a centralized `IMyanmarClock`.
- External timestamps must retain their original provider value for audit, with a separate Myanmar business timestamp where required.

## Database scripts

Scripts run in numeric order during the first Oracle container initialization:

1. `001_schema.sql` — supplied 69-table Oracle 19c baseline.
2. `002_primary_keys.sql` — adds an `ID` primary key required for reliable EF/ORM tracking.
3. `003_foreign_key_indexes.sql` — adds foreign-key indexes, skipping duplicate column lists.
4. `004_myanmar_time_and_sessions.sql` — applies offset-aware Myanmar timestamps and adds refresh-token sessions.
5. `005_seed_reference_data.sql` — idempotently seeds menus, units, meal types and payment methods.
6. `verify_schema.sql` — reports table, key and timezone evidence.

The original schema creates 69 tables. `USER_SESSIONS` brings the normalized local schema to 70 tables.

## Local prerequisites

- .NET 8 SDK or a newer SDK capable of targeting .NET 8
- Node.js 24 and npm
- Docker Desktop using Linux containers
- Oracle Container Registry access

Oracle 19c is commercial software. Before the first pull, sign in at Oracle Container Registry, accept the Oracle Database Enterprise image terms, then authenticate locally:

```powershell
docker login container-registry.oracle.com
```

Do not place registry credentials, database passwords or connection strings in the repository.

## Run the complete local stack

Create the ignored local environment file and replace both placeholder passwords:

```powershell
Copy-Item .env.example .env
docker compose up --build
```

First-time Oracle initialization can take 15 minutes or longer. The applications become available after the database health check succeeds:

| Service | URL |
| --- | --- |
| Admin portal | `http://localhost:3001` |
| User portal | `http://localhost:3002` |
| Admin API live/readiness | `http://localhost:5101/health/live`, `http://localhost:5101/health/ready` |
| User API live/readiness | `http://localhost:5201/health/live`, `http://localhost:5201/health/ready` |
| Oracle listener | `localhost:1521` |

Stop the stack without deleting database data:

```powershell
docker compose down
```

Deleting the `oracle-data` volume destroys the local database and is intentionally not part of the normal commands.

## Run APIs and portals without Oracle

Database health registration is disabled by default outside Compose, which allows UI/API development before Oracle is available:

### Recommended: one command

Run this from PowerShell in the repository folder:

```powershell
.\scripts\Start-Local.ps1
```

This starts both APIs and both Next.js portals in the background, waits until all four are ready, stores logs under the ignored `.run\logs` folder, and opens both portals. Run it again safely if the services are already running.

To stop only the Meal Planning processes started by that script:

```powershell
.\scripts\Stop-Local.ps1
```

To preview only the two UIs with temporary static data (no APIs or Oracle required):

```powershell
.\scripts\Start-Local.ps1 -PortalsOnly
```

Stop the script-managed services before using Visual Studio Build/Rebuild. Running the APIs from `Start-Local.ps1` and rebuilding the same APIs in Visual Studio at the same time causes Windows DLL file-lock errors.

Portal URLs:

- Admin Portal: `http://localhost:3001`
- User Portal: `http://localhost:3002`

API URLs:

- Admin API: `http://localhost:5101/health/live`
- User API: `http://localhost:5201/health/live`

`/weatherforecast` is not part of this application and should not be used.

### Visual Studio

Open `MealPlanning.sln`, select the `Portals only (static demo)` solution launch profile, then press Start. For API integration work, select `All portals and APIs` instead. API projects no longer open browser tabs automatically; `/health/live` returning `Healthy` is an API health check, not a portal UI.

Use either the Visual Studio launch profile or `Start-Local.ps1`, not both at the same time.

### DLL file-lock troubleshooting

If a build reports that `MealPlanning.Admin.Api` or `MealPlanning.User.Api` is locking an Application/Infrastructure DLL, stop the local script-managed processes and rebuild:

```powershell
.\scripts\Stop-Local.ps1
dotnet clean .\MealPlanning.sln
dotnet build .\MealPlanning.sln --no-restore
```

If Visual Studio itself started the APIs, press the red **Stop** button before rebuilding instead of using `Stop-Local.ps1`.

### Manual commands

```powershell
dotnet run --project .\Admin\MealPlanning.Admin.Api --urls http://localhost:5101
dotnet run --project .\User\MealPlanning.User.Api --urls http://localhost:5201
npm --prefix .\Admin\admin-web run dev -- --port 3001
npm --prefix .\User\user-web run dev -- --port 3002
```

This mode verifies API/UI behavior but does not prove database persistence. Complete-stack acceptance requires Oracle readiness and persisted read-back checks.

## Validation commands

```powershell
dotnet restore .\MealPlanning.sln
dotnet build .\MealPlanning.sln --no-restore
dotnet test .\MealPlanning.sln --no-build
npm --prefix .\Admin\admin-web run build
npm --prefix .\User\user-web run build
```

Production dependency audit:

```powershell
npm --prefix .\Admin\admin-web audit --omit=dev
npm --prefix .\User\user-web audit --omit=dev
```

## AWS phase (after local database acceptance)

The intended next phase is Amplify Hosting or container hosting for Next.js, ECR/ECS Fargate for the APIs, and Amazon RDS for Oracle 19c in private subnets. Secrets Manager, CloudWatch, ACM/Route 53 and WAF will be added in that phase. AWS resources are not created by the current local-first implementation.
