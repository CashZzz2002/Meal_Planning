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
    param([int]$ProcessId)

    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        Stop-ProcessTree -ProcessId $child.ProcessId
    }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

$services = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
foreach ($service in $services) {
    Stop-ProcessTree -ProcessId $service.ProcessId
    Write-Output "Stopped: $($service.Name)"
}

Remove-Item -LiteralPath $statePath -Force
