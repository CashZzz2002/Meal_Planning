[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$logPath = Join-Path $repoPath '.run\logs'
$created = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$previousDatabaseSetting = $env:Database__Enabled

function Wait-Http {
    param([string]$Url)
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    do {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 3
            if ($response.StatusCode -eq 200) { return $response }
        } catch { Start-Sleep -Milliseconds 400 }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Service did not become ready: $Url. Check .run\logs\lifecycle-* files."
}

function Assert-PortReleased {
    param([int]$Port)
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        if (-not (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)) { return }
        Start-Sleep -Milliseconds 250
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Port $Port is still listening after its owner stopped."
}

function Get-DescendantProcesses {
    param([int]$ParentId)
    foreach ($child in @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ParentId")) {
        $process = Get-Process -Id $child.ProcessId -ErrorAction SilentlyContinue
        if ($process) {
            $null = $process.Handle
            $process
            Get-DescendantProcesses -ParentId $process.Id
        }
    }
}

function Start-TestPortal {
    param($Service, [string]$Suffix)
    $projectPath = Join-Path $repoPath "$($Service.directory)\MealPlanning.$($Service.name).WebPortal.esproj"
    [xml]$project = Get-Content -LiteralPath $projectPath -Raw
    $command = [string]$project.Project.PropertyGroup.StartupCommand
    $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/d /s /c `"$command`"" `
        -WorkingDirectory (Join-Path $repoPath $Service.directory) `
        -RedirectStandardOutput (Join-Path $logPath "lifecycle-$($Service.name)-$Suffix.out.log") `
        -RedirectStandardError (Join-Path $logPath "lifecycle-$($Service.name)-$Suffix.err.log") `
        -WindowStyle Hidden -PassThru
    $created.Add($process)
    return $process
}

try {
    if (Test-Path (Join-Path $repoPath '.run\local-processes.json')) {
        throw 'Stop the script-managed stack before running lifecycle verification.'
    }
    $json = & node (Join-Path $PSScriptRoot 'sync-launch-settings.mjs') --print
    if ($LASTEXITCODE -ne 0) { throw 'Local configuration is invalid.' }
    $launch = $json | ConvertFrom-Json
    $ports = @($launch.services | ForEach-Object { $_.api.port; $_.web.port })
    if (@(Get-NetTCPConnection -State Listen -LocalPort $ports -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'A required port is occupied. Stop its owning session before running this test.'
    }
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    # This test exercises host configuration, HTTP contracts and process ownership.
    # It intentionally requires no database connection or private environment files.
    $env:Database__Enabled = 'false'

    foreach ($service in $launch.services) {
        $outputPath = Join-Path $repoPath "$($service.apiDirectory)\bin\$Configuration\net8.0"
        $dll = Join-Path $outputPath "MealPlanning.$($service.name).Api.dll"
        if (-not (Test-Path $dll)) { throw "Build the $Configuration solution before running this test." }
        $process = Start-Process -FilePath 'dotnet' `
            -ArgumentList "`"$dll`" --environment Development --urls $($service.api.url)" `
            -WorkingDirectory $outputPath `
            -RedirectStandardOutput (Join-Path $logPath "lifecycle-$($service.name)-api.out.log") `
            -RedirectStandardError (Join-Path $logPath "lifecycle-$($service.name)-api.err.log") `
            -WindowStyle Hidden -PassThru
        $created.Add($process)
    }

    # Start the actual .esproj StartupCommands concurrently with the APIs.
    $admin = Start-TestPortal -Service $launch.services[0] -Suffix 'first'
    $user = Start-TestPortal -Service $launch.services[1] -Suffix 'first'
    foreach ($service in $launch.services) {
        $null = Wait-Http "$($service.api.probeUrl)/health/ready"
        $swagger = (Wait-Http "$($service.api.probeUrl)/swagger/v1/swagger.json").Content | ConvertFrom-Json
        if ($swagger.info.title -ne "Meal Planning $($service.name) API") { throw 'Unexpected Swagger document.' }
        if (-not $swagger.paths.'/api/system/time'.get -or -not $swagger.paths.'/api/system/modules'.get) {
            throw 'The system endpoints are missing from Swagger.'
        }
        $null = Wait-Http "$($service.api.probeUrl)/swagger/index.html"
        $time = (Wait-Http "$($service.api.probeUrl)/api/system/time").Content | ConvertFrom-Json
        if ($time.timeZoneId -ne 'Asia/Yangon' -or -not $time.now.EndsWith('+06:30')) { throw 'Myanmar time contract failed.' }
        $response = Invoke-WebRequest -UseBasicParsing "$($service.api.probeUrl)/api/system/time" -Headers @{ Origin = $service.web.url }
        if ($response.Headers['Access-Control-Allow-Origin'] -ne $service.web.url) { throw 'Portal CORS origin was not accepted.' }
        $other = @($launch.services | Where-Object { $_.name -ne $service.name })[0]
        $rejected = Invoke-WebRequest -UseBasicParsing "$($service.api.probeUrl)/api/system/time" -Headers @{ Origin = $other.web.url }
        if ($rejected.Headers['Access-Control-Allow-Origin']) { throw 'The other portal origin was unexpectedly accepted.' }
        $null = Wait-Http $service.web.probeUrl
        Write-Output "$($service.name): output Config, readiness, Swagger UI/JSON, Myanmar time, CORS, and portal HTTP passed."
    }

    $adminChildren = @(Get-DescendantProcesses -ParentId $admin.Id)
    $userChildren = @(Get-DescendantProcesses -ParentId $user.Id)
    if ($adminChildren.Count -lt 3 -or $userChildren.Count -lt 3) { throw 'Expected launcher and Next.js descendants were not found.' }

    Stop-Process -InputObject $admin -Force
    Assert-PortReleased $launch.services[0].web.port
    foreach ($child in $adminChildren) {
        if (-not $child.HasExited) { throw "An Admin portal descendant survived its command owner: $($child.Id)" }
    }
    $null = Wait-Http $launch.services[1].web.probeUrl
    Write-Output 'Parent-command termination: entire Admin portal tree exited; User portal stayed available.'

    $userLauncher = @($userChildren | Where-Object { $_.ProcessName -eq 'powershell' })[0]
    Stop-Process -InputObject $userLauncher -Force
    Assert-PortReleased $launch.services[1].web.port
    foreach ($child in $userChildren) {
        if (-not $child.HasExited) { throw "A User portal descendant survived launcher termination: $($child.Id)" }
    }
    Write-Output 'Forced launcher termination: Windows closed the job and every User portal descendant exited.'

    $null = Start-TestPortal -Service $launch.services[0] -Suffix 'restart'
    $null = Start-TestPortal -Service $launch.services[1] -Suffix 'restart'
    foreach ($service in $launch.services) {
        $null = Wait-Http $service.web.probeUrl
        $null = Wait-Http "$($service.api.probeUrl)/health/live"
    }
    Write-Output 'Both portals restarted on their configured ports; both independent APIs stayed available.'
} finally {
    foreach ($process in $created) {
        Stop-Process -InputObject $process -Force -ErrorAction SilentlyContinue
    }
    $env:Database__Enabled = $previousDatabaseSetting
    if ($created.Count -gt 0) {
        foreach ($port in $ports) { Assert-PortReleased $port }
    }
}

Write-Output 'Lifecycle verification passed; all four service ports are free. Database access was disabled for this test.'
