[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Admin', 'User')]
    [string]$Portal,
    [switch]$Detached,
    [switch]$SkipApiWait,
    [switch]$TrackVisualStudio
)

$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$owner = $null
$child = $null
$visualStudio = $null
$exitCode = 1
$logDirectory = Join-Path $repoPath '.run\logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$lifecycleLog = Join-Path $logDirectory "portal-$Portal-owner.log"

function Write-LifecycleEvent {
    param([string]$Message)
    try {
        # Append directly: Windows PowerShell's Add-Content can fail while probing
        # an existing stream's encoding. Diagnostic I/O must not stop the owner.
        [System.IO.File]::AppendAllText($lifecycleLog,
            "$([DateTime]::UtcNow.ToString('O')) PID=$PID $Message$([Environment]::NewLine)",
            [System.Text.UTF8Encoding]::new($false))
    } catch [System.IO.IOException] {
        Write-Verbose 'Portal lifecycle log is temporarily unavailable.'
    } catch [System.UnauthorizedAccessException] {
        Write-Verbose 'Portal lifecycle log is not writable.'
    }
}

try {
    Write-LifecycleEvent "Starting; Detached=$Detached; SkipApiWait=$SkipApiWait; TrackVisualStudio=$TrackVisualStudio."
    if (-not $Detached) {
        # Retain the exact caller, including for direct command-line use.
        $current = Get-CimInstance Win32_Process -Filter "ProcessId = $PID"
        $owner = Get-Process -Id $current.ParentProcessId -ErrorAction Stop
        $null = $owner.Handle
        Write-LifecycleEvent "Caller PID=$($owner.Id)."

        if ($TrackVisualStudio) {
            $ancestor = $current
            while ($ancestor.ParentProcessId) {
                $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($ancestor.ParentProcessId)"
                if (-not $parent -or $parent.CreationDate -gt $ancestor.CreationDate) { break }
                if ($parent.Name -eq 'devenv.exe') {
                    Add-Type -Path (Join-Path $PSScriptRoot 'VisualStudioSession.cs')
                    $visualStudio = [MealPlanning.LocalDevelopment.VisualStudioSession]::Connect(
                        $parent.ProcessId, (Join-Path $repoPath 'MealPlanning.sln'))
                    Write-Output "[$Portal portal] Tracking Visual Studio debug session (PID=$($parent.ProcessId))."
                    Write-LifecycleEvent "Connected to Visual Studio PID=$($parent.ProcessId)."
                    break
                }
                $ancestor = $parent
            }
        }
    }

    Add-Type -Path (Join-Path $PSScriptRoot 'OwnedProcess.cs')
    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    $localNode = Join-Path $repoPath '.run\tools\node\node.exe'
    $node = if ($nodeCommand) {
        $nodeCommand.Source
    } elseif (Test-Path $localNode) {
        $localNode
    } else {
        throw 'Node.js was not found. Install Node.js 24 system-wide or provide .run\tools\node\node.exe.'
    }
    if ($owner -and $owner.HasExited) { exit 0 }

    $arguments = @((Join-Path $PSScriptRoot 'portal.mjs'), $Portal, 'dev')
    if (-not $SkipApiWait) { $arguments += '--wait-for-api' }
    $child = [MealPlanning.LocalDevelopment.OwnedProcess]::Start(
        $node,
        [string[]]$arguments,
        $repoPath)
    Write-LifecycleEvent "Owned Node PID=$($child.ProcessId)."

    $lastState = $null
    while (-not $child.HasExited) {
        $callerEnded = $owner -and $owner.HasExited
        $sessionEnded = $visualStudio -and $visualStudio.HasEnded
        if ($visualStudio -and $visualStudio.State -ne $lastState) {
            $lastState = $visualStudio.State
            Write-LifecycleEvent $lastState
        }
        if ($callerEnded -or $sessionEnded) {
            Write-LifecycleEvent "Stopping; CallerEnded=$callerEnded; SessionEnded=$sessionEnded."
            $exitCode = 0
            break
        }
        Start-Sleep -Milliseconds 500
    }
    if ($child.HasExited) {
        $exitCode = $child.ExitCode
        Write-LifecycleEvent "Node exited with code $exitCode."
    }
} catch {
    Write-LifecycleEvent "Launcher failed: $($_.Exception.GetBaseException().Message)"
    throw
} finally {
    # Ctrl+C / a normal exit closes the job here. A forced kill closes the same
    # handle in the kernel, terminating every descendant without a cleanup race.
    if ($child) { $child.Dispose() }
    if ($visualStudio) { $visualStudio.Dispose() }
    if ($owner) { $owner.Dispose() }
    Write-LifecycleEvent 'Owner cleanup completed.'
}

exit $exitCode
