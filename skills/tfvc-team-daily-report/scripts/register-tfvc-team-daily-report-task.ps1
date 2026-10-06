[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
$ConfigPath = if ($ConfigPath) { $ConfigPath } else { Join-Path $repoRoot "agile\projects\plum\tfvc-daily-report.json" }
$runnerPath = Join-Path $PSScriptRoot "invoke-tfvc-team-daily-report.ps1"
$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

if (-not (Test-Path $runnerPath)) { throw "Runner not found: $runnerPath" }
if (-not (Get-Command tf.exe -ErrorAction SilentlyContinue)) { throw "tf.exe was not found on PATH." }
$patVariableName = $config.patEnvironmentVariable
$userPat = [Environment]::GetEnvironmentVariable($patVariableName, 'User')
$machinePat = [Environment]::GetEnvironmentVariable($patVariableName, 'Machine')
if ([string]::IsNullOrWhiteSpace($userPat) -and [string]::IsNullOrWhiteSpace($machinePat)) {
    throw "Environment variable '$patVariableName' is not persisted in User or Machine scope. A Process-only variable can serve VS Code/MCP but cannot be relied on by Task Scheduler."
}
$userPat = $null
$machinePat = $null

$taskName = $config.schedule.taskName
$days = @($config.schedule.days) -join ','
$startTime = $config.schedule.startTime
$taskAction = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$runnerPath`" -ConfigPath `"$ConfigPath`""
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $existingTask -and -not $Force) {
    throw "Scheduled task already exists: $taskName. Re-run with -Force to replace it."
}

$arguments = @('/Create', '/TN', $taskName, '/TR', $taskAction, '/SC', 'WEEKLY', '/D', $days, '/ST', $startTime, '/IT', '/F')
& schtasks.exe @arguments
if ($LASTEXITCODE -ne 0) { throw "schtasks /Create failed with exit code $LASTEXITCODE." }

Write-Host "Scheduled task registered: $taskName" -ForegroundColor Green
Write-Host "Schedule: $days at $startTime (only when the current user is logged on)" -ForegroundColor Cyan
& schtasks.exe /Query /TN $taskName /V /FO LIST
if ($LASTEXITCODE -ne 0) { throw "Scheduled task verification failed with exit code $LASTEXITCODE." }