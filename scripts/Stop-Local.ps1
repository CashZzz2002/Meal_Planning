[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$statePath = Join-Path $repoPath '.run\local-processes.json'

if (-not (Test-Path -LiteralPath $statePath)) {
    Write-Output 'No Meal Planning local process state was found.'
    exit 0
}

function Stop-ProcessTree {
    param([System.Diagnostics.Process]$Process)

    $null = $Process.Handle
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $($Process.Id)" -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        $childProcess = Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
        if ($childProcess -and $childProcess.StartTime.ToUniversalTime() -ge $Process.StartTime.ToUniversalTime()) {
            Stop-ProcessTree -Process $childProcess
        }
    }
    Stop-Process -InputObject $Process -Force -ErrorAction SilentlyContinue
}

$services = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
foreach ($service in $services) {
    $process = Get-Process -Id $service.ProcessId -ErrorAction SilentlyContinue
    if (-not $process) { continue }
    if (-not $service.ProcessStartTimeUtc) {
        throw 'Legacy process state has no creation time. Stop its original owning session before removing that state file.'
    }
    if ($process.StartTime.ToUniversalTime().ToString('O') -ne $service.ProcessStartTimeUtc) {
        Write-Output "Skipped stale process identity: $($service.Name)"
        continue
    }
    Stop-ProcessTree -Process $process
    Write-Output "Stopped: $($service.Name)"
}

Remove-Item -LiteralPath $statePath -Force
