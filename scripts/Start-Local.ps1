[CmdletBinding()]
param(
    [switch]$NoBrowser,
    [switch]$PortalsOnly,
    [int]$StartupTimeoutSeconds = 90
)

$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runPath = Join-Path $repoPath '.run'
$logPath = Join-Path $runPath 'logs'
$statePath = Join-Path $runPath 'local-processes.json'

New-Item -ItemType Directory -Path $logPath -Force | Out-Null

if (Test-Path -LiteralPath $statePath) {
    $existing = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    $running = @($existing | Where-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue })
    if ($running.Count -gt 0) {
        Write-Output 'Meal Planning services are already running.'
        Write-Output 'Admin Portal: http://localhost:3001'
        Write-Output 'User Portal:  http://localhost:3002'
        exit 0
    }
    Remove-Item -LiteralPath $statePath -Force
}

$ports = if ($PortalsOnly) { 3001, 3002 } else { 3001, 3002, 5101, 5201 }
$occupied = @(Get-NetTCPConnection -State Listen -LocalPort $ports -ErrorAction SilentlyContinue)
if ($occupied.Count -gt 0) {
    $usedPorts = ($occupied.LocalPort | Sort-Object -Unique) -join ', '
    throw "Required local ports are already in use: $usedPorts"
}

$portalDefinitions = @(
    [pscustomobject]@{ Name = 'Admin Portal'; File = 'npm.cmd'; WorkingDirectory = (Join-Path $repoPath 'Admin\admin-web'); Arguments = @('run', 'dev', '--', '--hostname', '127.0.0.1', '--port', '3001'); ReadyUrl = 'http://127.0.0.1:3001' },
    [pscustomobject]@{ Name = 'User Portal'; File = 'npm.cmd'; WorkingDirectory = (Join-Path $repoPath 'User\user-web'); Arguments = @('run', 'dev', '--', '--hostname', '127.0.0.1', '--port', '3002'); ReadyUrl = 'http://127.0.0.1:3002' }
)

$definitions = if ($PortalsOnly) {
    $portalDefinitions
} else {
    @(
        [pscustomobject]@{ Name = 'Admin API'; File = 'dotnet'; WorkingDirectory = $repoPath; Arguments = @('run', '--project', '.\Admin\MealPlanning.Admin.Api', '--no-launch-profile', '-e', 'ASPNETCORE_ENVIRONMENT=Development', '--urls', 'http://127.0.0.1:5101'); ReadyUrl = 'http://127.0.0.1:5101/health/live' },
        [pscustomobject]@{ Name = 'User API'; File = 'dotnet'; WorkingDirectory = $repoPath; Arguments = @('run', '--project', '.\User\MealPlanning.User.Api', '--no-launch-profile', '-e', 'ASPNETCORE_ENVIRONMENT=Development', '--urls', 'http://127.0.0.1:5201'); ReadyUrl = 'http://127.0.0.1:5201/health/live' }
    ) + $portalDefinitions
}

$started = @()
try {
    foreach ($definition in $definitions) {
        $safeName = $definition.Name.ToLowerInvariant().Replace(' ', '-')
        $process = Start-Process -FilePath $definition.File `
            -ArgumentList $definition.Arguments `
            -WorkingDirectory $definition.WorkingDirectory `
            -RedirectStandardOutput (Join-Path $logPath "$safeName.out.log") `
            -RedirectStandardError (Join-Path $logPath "$safeName.err.log") `
            -WindowStyle Hidden `
            -PassThru

        $started += [pscustomobject]@{
            Name = $definition.Name
            ProcessId = $process.Id
            ReadyUrl = $definition.ReadyUrl
        }
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
    foreach ($service in $started) {
        $ready = $false
        while ([DateTime]::UtcNow -lt $deadline) {
            try {
                $response = Invoke-WebRequest -UseBasicParsing -Uri $service.ReadyUrl -TimeoutSec 3
                if ($response.StatusCode -eq 200) { $ready = $true; break }
            } catch {
                Start-Sleep -Milliseconds 700
            }
        }
        if (-not $ready) { throw "$($service.Name) did not become ready. Check .run\logs." }
        Write-Output "$($service.Name) ready: $($service.ReadyUrl)"
    }

    $started | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding utf8
    Write-Output ''
    Write-Output 'Admin Portal: http://localhost:3001'
    Write-Output 'User Portal:  http://localhost:3002'

    if (-not $NoBrowser) {
        Start-Process 'http://localhost:3001'
        Start-Process 'http://localhost:3002'
    }
} catch {
    foreach ($service in $started) {
        Stop-Process -Id $service.ProcessId -Force -ErrorAction SilentlyContinue
    }
    throw
}
