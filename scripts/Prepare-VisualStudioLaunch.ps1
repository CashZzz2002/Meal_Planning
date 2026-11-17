[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Admin', 'User')]
    [string]$Portal,
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$runPath = Join-Path $repoPath '.run'
$envPath = Join-Path $repoPath '.env.local'
$configPath = Join-Path $repoPath 'Config\custom-setting-dev.json'

function Get-PrivateEnvironmentValue {
    param([string]$Path, [string]$Name)

    $line = Get-Content -LiteralPath $Path | Where-Object {
        $_ -match "^\s*$([regex]::Escape($Name))\s*="
    } | Select-Object -First 1
    if (-not $line) { return $null }

    $value = ($line -split '=', 2)[1].Trim()
    if ($value.Length -ge 2 -and
        (($value[0] -eq '"' -and $value[-1] -eq '"') -or
         ($value[0] -eq "'" -and $value[-1] -eq "'"))) {
        return $value.Substring(1, $value.Length - 2)
    }
    return $value
}

function Wait-PortReleased {
    param([int]$Port)

    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        if (-not (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)) {
            return
        }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "Port $Port did not release after its stale MealPlanning owner stopped."
}

function Assert-PortBindable {
    param([int]$Port, [string]$ServiceLabel)

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    try {
        $listener.Start()
    } catch [System.Net.Sockets.SocketException] {
        throw "$ServiceLabel cannot start: Windows has reserved or otherwise blocked port $Port. Select a different local port in Config\custom-setting-dev.json."
    } finally {
        $listener.Stop()
    }
}

function Get-DescendantProcessIds {
    param([int]$ParentId)

    foreach ($child in @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ParentId")) {
        Get-DescendantProcessIds -ParentId $child.ProcessId
        $child.ProcessId
    }
}

function Stop-VerifiedProcessTree {
    param([int]$ProcessId)

    foreach ($childId in @(Get-DescendantProcessIds -ParentId $ProcessId)) {
        Stop-Process -Id $childId -Force -ErrorAction SilentlyContinue
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Clear-OwnedPort {
    param(
        [int]$Port,
        [string]$ExpectedDirectory,
        [string]$ServiceLabel
    )

    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue |
        Sort-Object OwningProcess -Unique)
    foreach ($listener in $listeners) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId = $($listener.OwningProcess)"
        if (-not $process) { continue }

        $commandLine = ([string]$process.CommandLine).Replace('/', '\')
        $expected = [System.IO.Path]::GetFullPath($ExpectedDirectory).TrimEnd('\')
        if ($commandLine.IndexOf($expected, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "$ServiceLabel cannot start: port $Port is owned by unrelated process $($process.ProcessId) ($($process.Name))."
        }

        Write-Output "[$Portal preflight] Stopping stale $ServiceLabel process $($process.ProcessId) on port $Port."
        Stop-VerifiedProcessTree -ProcessId $process.ProcessId
    }

    if ($listeners.Count -gt 0) { Wait-PortReleased -Port $Port }
    Assert-PortBindable -Port $Port -ServiceLabel $ServiceLabel
}

if (-not (Test-Path -LiteralPath $envPath)) {
    throw 'Visual Studio Docker launch requires the ignored root .env.local file.'
}
if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'Visual Studio preflight could not find Config\custom-setting-dev.json.'
}

$databaseUrl = Get-PrivateEnvironmentValue -Path $envPath -Name 'DATABASE_URL'
$branchName = Get-PrivateEnvironmentValue -Path $envPath -Name 'NEON_BRANCH'
if ([string]::IsNullOrWhiteSpace($databaseUrl)) {
    throw 'Visual Studio Docker launch requires DATABASE_URL in .env.local.'
}
if ([string]::IsNullOrWhiteSpace($branchName)) {
    throw 'Visual Studio Docker launch requires NEON_BRANCH in .env.local.'
}
if ($branchName -in @('main', 'default', 'production', 'prod')) {
    throw 'Visual Studio local development must use a non-production Neon child branch.'
}

docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop is not running. Start Docker Desktop before Visual Studio F5.'
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$service = $config.Services.$Portal
$webPort = ([Uri]$service.PortalUrl).Port
$apiPort = ([Uri]$service.ApiUrl).Port
$portalFolder = if ($Portal -eq 'Admin') { 'admin-web' } else { 'user-web' }
$portalDirectory = Join-Path $repoPath "$Portal\$portalFolder"
$apiDirectory = Join-Path $repoPath "$Portal\MealPlanning.$Portal.Api"
$containerName = "meal-planning-$($Portal.ToLowerInvariant())-api"

$containerId = docker container ls --all --filter "name=^/$containerName$" --format '{{.ID}}'
if (-not [string]::IsNullOrWhiteSpace($containerId)) {
    Write-Output "[$Portal preflight] Removing stale container $containerName."
    docker container rm --force $containerName 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not remove stale container $containerName." }
}

Clear-OwnedPort -Port $webPort -ExpectedDirectory $portalDirectory -ServiceLabel "$Portal portal"
Clear-OwnedPort -Port $apiPort -ExpectedDirectory $apiDirectory -ServiceLabel "$Portal API"

New-Item -ItemType Directory -Path $runPath -Force | Out-Null
Write-Output "[$Portal preflight] Docker, Neon child configuration, and ports $webPort/$apiPort are ready."
