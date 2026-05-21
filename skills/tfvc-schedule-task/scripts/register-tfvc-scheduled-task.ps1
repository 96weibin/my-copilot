param(
    [Parameter(Mandatory = $true)]
    [string]$TaskName,

    [string]$ScriptPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("DAILY", "WEEKLY", "ONCE", "ONLOGON")]
    [string]$ScheduleType,

    [string]$MainRoot,

    [string]$DevToolsScriptPath,

    [string]$TfsBuildScriptPath,

    [string]$StartTime,

    [string]$StartDate,

    [ValidateSet("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")]
    [string]$Day,

    [switch]$InteractiveOnly
)

$ErrorActionPreference = "Stop"

function Get-SharedTfvcDefaults {
    $defaultsPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\tfvc-defaults.json"))
    if (-not (Test-Path $defaultsPath)) {
        return $null
    }

    return Get-Content $defaultsPath -Raw | ConvertFrom-Json
}

function Resolve-RequiredPath {
    param(
        [string]$Label,
        [string]$PreferredPath,
        [string]$PromptMessage
    )

    if ($PreferredPath -and (Test-Path $PreferredPath)) {
        return $PreferredPath
    }

    while ($true) {
        $inputPath = Read-Host "$PromptMessage"
        if ($inputPath -and (Test-Path $inputPath)) {
            return $inputPath
        }

        Write-Host "$Label path not found. Please enter an existing local path." -ForegroundColor Yellow
    }
}

$defaultScriptPath = Join-Path $PSScriptRoot "tfvc-get-latest-and-devtools.ps1"
$resolvedScriptPath = if ($ScriptPath) { $ScriptPath } else { $defaultScriptPath }
$sharedDefaults = Get-SharedTfvcDefaults

if (-not (Test-Path $resolvedScriptPath)) {
    throw "Script path not found: $resolvedScriptPath"
}

$resolvedMainRoot = Resolve-RequiredPath -Label "MainRoot" -PreferredPath $(if ($MainRoot) { $MainRoot } elseif ($sharedDefaults?.MainRoot) { $sharedDefaults.MainRoot } else { $null }) -PromptMessage "MainRoot path not found. Please enter the local TFVC main root"
$resolvedDevToolsScriptPath = Resolve-RequiredPath -Label "DevTools" -PreferredPath $(if ($DevToolsScriptPath) { $DevToolsScriptPath } elseif ($sharedDefaults?.DevTools) { $sharedDefaults.DevTools } else { Join-Path $resolvedMainRoot "Psc\_DevTools.ps1" }) -PromptMessage "DevTools script path not found. Please enter the full path to _DevTools.ps1"
$resolvedTfsBuildScriptPath = Resolve-RequiredPath -Label "TfsBuild" -PreferredPath $(if ($TfsBuildScriptPath) { $TfsBuildScriptPath } elseif ($sharedDefaults?.TfsBuild) { $sharedDefaults.TfsBuild } else { Join-Path $resolvedMainRoot "Psc\TfsBuild.ps1" }) -PromptMessage "TfsBuild script path not found. Please enter the full path to TfsBuild.ps1"

$taskAction = "powershell.exe -ExecutionPolicy Bypass -File `"$resolvedScriptPath`" -MainRoot `"$resolvedMainRoot`""
$arguments = @("/Create", "/TN", $TaskName, "/TR", $taskAction, "/SC", $ScheduleType, "/F")

switch ($ScheduleType) {
    "DAILY" {
        if (-not $StartTime) {
            throw "StartTime is required for DAILY schedules."
        }

        $arguments += @("/ST", $StartTime)
    }
    "WEEKLY" {
        if (-not $StartTime) {
            throw "StartTime is required for WEEKLY schedules."
        }

        if (-not $Day) {
            throw "Day is required for WEEKLY schedules."
        }

        $arguments += @("/ST", $StartTime, "/D", $Day)
    }
    "ONCE" {
        if (-not $StartTime) {
            throw "StartTime is required for ONCE schedules."
        }

        if (-not $StartDate) {
            throw "StartDate is required for ONCE schedules."
        }

        $arguments += @("/ST", $StartTime, "/SD", $StartDate)
    }
    "ONLOGON" {
    }
}

if ($InteractiveOnly) {
    $arguments += "/IT"
}

Write-Host "Creating scheduled task: $TaskName" -ForegroundColor Cyan
Write-Host "Script path: $resolvedScriptPath" -ForegroundColor Cyan
Write-Host "Main root: $resolvedMainRoot" -ForegroundColor Cyan
Write-Host "DevTools script: $resolvedDevToolsScriptPath" -ForegroundColor Cyan
Write-Host "TfsBuild script: $resolvedTfsBuildScriptPath" -ForegroundColor Cyan
Write-Host "Schedule type: $ScheduleType" -ForegroundColor Cyan
if ($StartTime) {
    Write-Host "Start time: $StartTime" -ForegroundColor Cyan
}
if ($StartDate) {
    Write-Host "Start date: $StartDate" -ForegroundColor Cyan
}
if ($Day) {
    Write-Host "Day: $Day" -ForegroundColor Cyan
}

& schtasks @arguments
& schtasks /Query /TN $TaskName /V /FO LIST