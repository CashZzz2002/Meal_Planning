# Meal Planning Platform

Myanmar-focused weekly meal planning, township warehouse operations, shopping and ordering. The repository uses Next.js/TypeScript for the portals, .NET 8/C# for APIs, and Neon Postgres.

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
│  ├─ PostgreSql/                      # Deployable Neon/PostgreSQL scripts
│  └─ Oracle/                          # Supplied Oracle source retained for traceability
└─ compose.yaml
```

Each side follows `Api -> Infrastructure -> Application -> Domain`. The Next.js projects call their APIs over HTTP and do not reference server-side Domain projects. The `.esproj` files make both Next.js portals visible in the Visual Studio solution.

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
- Neon CLI 9.3 or newer
- Access to the linked Neon project

Authenticate and pull the linked production branch environment without printing secrets:

```powershell
neon login
neon env pull --file .env.local
```

Do not place registry credentials, database passwords or connection strings in the repository.

## Run the complete local stack

Pull the ignored Neon environment file, then pass it to Compose:

```powershell
neon env pull --file .env.local
docker compose --env-file .env.local up --build
```

The applications become available after both Npgsql readiness checks reach Neon:

| Service | URL |
| --- | --- |
| Admin portal | `http://localhost:3001` |
| User portal | `http://localhost:3002` |
| Admin API live/readiness | `http://localhost:5101/health/live`, `http://localhost:5101/health/ready` |
| User API live/readiness | `http://localhost:5201/health/live`, `http://localhost:5201/health/ready` |

Stop the stack without deleting database data:

```powershell
docker compose down
```

Neon database data is not stored in a local Docker volume.

## Run APIs and portals locally

The APIs read the pooled Neon URL from .NET User Secrets. The direct URL is reserved for schema migrations.

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

To preview only the two UIs with temporary static data (no APIs or database required):

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

This mode verifies API/UI behavior. Database acceptance also requires both `/health/ready` endpoints and persisted read-back checks against Neon.

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

The intended next phase is Amplify Hosting or container hosting for Next.js and ECR/ECS Fargate for the APIs, with Neon retained as managed Postgres. Secrets Manager, CloudWatch, ACM/Route 53 and WAF will be added in that phase. AWS resources are not created by the current local-first implementation.
