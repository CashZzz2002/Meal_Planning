[CmdletBinding()]
param(
    [switch]$NoBrowser,
    [switch]$PortalsOnly,
    [ValidateRange(10, 600)]
    [int]$StartupTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runPath = Join-Path $repoPath '.run'
$logPath = Join-Path $runPath 'logs'
$statePath = Join-Path $runPath 'local-processes.json'

function Save-ProcessState {
    param([object[]]$Services)

    # Readers see either the previous complete snapshot or the next one. Editors
    # and antivirus scanners may briefly deny replacement of the state file.
    $temporaryPath = "$statePath.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllText($temporaryPath,
            (ConvertTo-Json -InputObject @($Services)), [System.Text.UTF8Encoding]::new($false))
        $deadline = [DateTime]::UtcNow.AddSeconds(5)
        while ($true) {
            try {
                if ([System.IO.File]::Exists($statePath)) {
                    # PowerShell 5.1 otherwise converts $null to an empty backup path.
                    [System.IO.File]::Replace($temporaryPath, $statePath, [NullString]::Value)
                } else {
                    [System.IO.File]::Move($temporaryPath, $statePath)
                }
                return
            } catch [System.IO.IOException] {
                if ([DateTime]::UtcNow -ge $deadline) { throw }
                Start-Sleep -Milliseconds 100
            }
        }
    } finally {
        if ([System.IO.File]::Exists($temporaryPath)) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

New-Item -ItemType Directory -Path $logPath -Force | Out-Null

if (Test-Path -LiteralPath $statePath) {
    $existing = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    $running = @($existing | Where-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue })
    if ($running.Count -gt 0) {
        throw 'Local process state already exists. Run scripts\Stop-Local.ps1 before starting another stack.'
    }
    Remove-Item -LiteralPath $statePath -Force
}

$publicJson = & node (Join-Path $PSScriptRoot 'sync-launch-settings.mjs') --print
if ($LASTEXITCODE -ne 0) { throw 'Unable to load the local Stage configuration.' }
$launch = $publicJson | ConvertFrom-Json
$ports = @($launch.services | ForEach-Object {
    $_.web.port
    if (-not $PortalsOnly) { $_.api.port }
})
$occupied = @(Get-NetTCPConnection -State Listen -LocalPort $ports -ErrorAction SilentlyContinue)
if ($occupied.Count -gt 0) {
    $usedPorts = ($occupied.LocalPort | Sort-Object -Unique) -join ', '
    throw "Required local ports are already in use: $usedPorts"
}

$portalDefinitions = @($launch.services | ForEach-Object {
    $portalArguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'Start-Portal.ps1'), '-Portal', $_.name, '-Detached')
    if ($PortalsOnly) { $portalArguments += '-SkipApiWait' }
    [pscustomobject]@{
        Name = "$($_.name) Portal"
        File = 'powershell.exe'
        WorkingDirectory = $repoPath
        Arguments = $portalArguments
        ReadyUrl = $_.web.probeUrl
        BrowserUrl = $_.web.url
    }
})

$definitions = if ($PortalsOnly) {
    $portalDefinitions
} else {
    # Build before starting any process, then run DLLs directly so there is no
    # unowned dotnet-run wrapper or concurrent build of shared output files.
    & dotnet build (Join-Path $repoPath 'MealPlanning.sln') --no-restore | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'The solution build failed.' }
    @($launch.services | ForEach-Object {
        $apiDirectory = Join-Path $repoPath $_.apiDirectory
        [pscustomobject]@{
            Name = "$($_.name) API"
            File = 'dotnet'
            WorkingDirectory = $apiDirectory
            Arguments = @((Join-Path $apiDirectory "bin\Debug\net8.0\MealPlanning.$($_.name).Api.dll"), '--environment', 'Development', '--urls', $_.api.url)
            ReadyUrl = "$($_.api.probeUrl)/health/ready"
            BrowserUrl = "$($_.api.url)/swagger"
        }
    }) + $portalDefinitions
}

$started = @()
$ownedProcesses = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
try {
    foreach ($definition in $definitions) {
        $safeName = $definition.Name.ToLowerInvariant().Replace(' ', '-')
        $process = Start-Process -FilePath $definition.File `
            -ArgumentList (($definition.Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' ') `
            -WorkingDirectory $definition.WorkingDirectory `
            -RedirectStandardOutput (Join-Path $logPath "$safeName.out.log") `
            -RedirectStandardError (Join-Path $logPath "$safeName.err.log") `
            -WindowStyle Hidden `
            -PassThru

        # Retain every exact process before attempting any fallible state I/O.
        # Portal owners close their Windows job when terminated; APIs run directly.
        $ownedProcesses.Add($process)
        $null = $process.Handle
        $started += [pscustomobject]@{
            Name = $definition.Name
            ProcessId = $process.Id
            ProcessStartTimeUtc = $process.StartTime.ToUniversalTime().ToString('O')
            ReadyUrl = $definition.ReadyUrl
            BrowserUrl = $definition.BrowserUrl
        }
        Save-ProcessState -Services $started
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
    foreach ($service in $started) {
        $ready = $false
        while ([DateTime]::UtcNow -lt $deadline) {
            if (-not (Get-Process -Id $service.ProcessId -ErrorAction SilentlyContinue)) {
                throw "$($service.Name) exited during startup. Check .run\logs."
            }
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

    Write-Output "Stage=$($launch.stage). Services remain running until scripts\Stop-Local.ps1 is called."

    if (-not $NoBrowser) {
        foreach ($service in $started) { Start-Process $service.BrowserUrl }
    }
} catch {
    $startupFailure = $_
    foreach ($process in $ownedProcesses) {
        Stop-Process -InputObject $process -Force -ErrorAction SilentlyContinue
    }
    try {
        & (Join-Path $PSScriptRoot 'Stop-Local.ps1')
    } catch {
        Write-Warning 'Startup processes were stopped, but the state file is unavailable. Run scripts\Stop-Local.ps1 after its file lock is released.'
    }
    throw $startupFailure
} finally {
    foreach ($process in $ownedProcesses) { $process.Dispose() }
}
