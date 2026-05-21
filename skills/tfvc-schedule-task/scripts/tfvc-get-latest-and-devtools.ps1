param(
    [string]$MainRoot,
    [string]$DevToolsScriptPath,
    [string]$TfsBuildScriptPath
)

$ErrorActionPreference = "Stop"

function Get-SharedTfvcDefaults {
    $defaultsPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\..\tfvc-defaults.json"))
    if (-not (Test-Path $defaultsPath)) {
        return $null
    }

    return Get-Content $defaultsPath -Raw | ConvertFrom-Json
}

$sharedDefaults = Get-SharedTfvcDefaults
$mainRoot = if ($MainRoot) { $MainRoot } elseif ($sharedDefaults?.MainRoot) { $sharedDefaults.MainRoot } else { $null }
$devToolsScript = if ($DevToolsScriptPath) { $DevToolsScriptPath } elseif ($sharedDefaults?.DevTools) { $sharedDefaults.DevTools } elseif ($mainRoot) { Join-Path $mainRoot "Psc\_DevTools.ps1" } else { $null }
$tfsBuildScript = if ($TfsBuildScriptPath) { $TfsBuildScriptPath } elseif ($sharedDefaults?.TfsBuild) { $sharedDefaults.TfsBuild } elseif ($mainRoot) { Join-Path $mainRoot "Psc\TfsBuild.ps1" } else { $null }
$summaryPath = Join-Path $PSScriptRoot "tfvc-get-latest-and-devtools-last-run.txt"
$startTime = Get-Date

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "Gray"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

function Get-MatchCount {
    param(
        [string[]]$Lines,
        [string]$Pattern
    )

    return @($Lines | Where-Object { $_ -match $Pattern }).Count
}

function Get-ErrorSummary {
    param(
        [string[]]$Lines
    )

    $errorLines = @($Lines | Where-Object {
        $line = $_.Trim()
        ($line -match '(?i)^build failed\.?$') -or
        ($line -match '(?i)\b(?:fatal )?error\b') -or
        ($line -match '(?i)\bMSB\d+\b') -or
        ($line -match '(?i)^npm ERR!') -or
        ($line -match '(?i)webpack build failed') -or
        ($line -match '(?i)^at line:') -or
        ($line -match '(?i)^\s*\+\s') -or
        (($line -match '(?i)exception') -and ($line -notmatch '(?i)warning'))
    })

    if ($errorLines.Count -eq 0) {
        return @("None")
    }

    return $errorLines | Select-Object -Last 10
}

function Get-WarningCount {
    param(
        [string[]]$Lines
    )

    return @($Lines | Where-Object { $_ -match '(?i)\bwarning\b' }).Count
}

function Get-LatestSummaryLine {
    param(
        [string[]]$Lines
    )

    $meaningfulLines = @($Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($meaningfulLines.Count -eq 0) {
        return "No output yet"
    }

    $preferredLines = @($meaningfulLines | Where-Object {
        $_ -match '(?i)error|failed|warning|restore|build|webpack|project|complete|completed|success'
    })

    if ($preferredLines.Count -gt 0) {
        return $preferredLines[-1].Trim()
    }

    return $meaningfulLines[-1].Trim()
}

function Invoke-ProcessWithHeartbeat {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$StepName,
        [int]$HeartbeatSeconds = 30
    )

    $stdoutPath = Join-Path $env:TEMP ("{0}-stdout-{1}.log" -f $StepName, [guid]::NewGuid().ToString("N"))
    $stderrPath = Join-Path $env:TEMP ("{0}-stderr-{1}.log" -f $StepName, [guid]::NewGuid().ToString("N"))
    $process = $null

    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -WindowStyle Hidden
        $startedAt = Get-Date

        while (-not $process.WaitForExit($HeartbeatSeconds * 1000)) {
            $stdoutLines = if (Test-Path $stdoutPath) { Get-Content $stdoutPath -ErrorAction SilentlyContinue } else { @() }
            $stderrLines = if (Test-Path $stderrPath) { Get-Content $stderrPath -ErrorAction SilentlyContinue } else { @() }
            $combinedLines = @($stdoutLines + $stderrLines)
            $elapsed = (Get-Date) - $startedAt
            $latestLine = Get-LatestSummaryLine -Lines $combinedLines

            Write-Log ("{0} still running. Elapsed: {1:hh\:mm\:ss}. Output lines: {2}. Latest: {3}" -f $StepName, $elapsed, $combinedLines.Count, $latestLine) "DarkYellow"
        }

        $stdoutLines = if (Test-Path $stdoutPath) { Get-Content $stdoutPath -ErrorAction SilentlyContinue } else { @() }
        $stderrLines = if (Test-Path $stderrPath) { Get-Content $stderrPath -ErrorAction SilentlyContinue } else { @() }

        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            OutputLines = @($stdoutLines + $stderrLines)
            StdOutLines = $stdoutLines
            StdErrLines = $stderrLines
            Duration = (Get-Date) - $startedAt
        }
    }
    finally {
        if (Test-Path $stdoutPath) {
            Remove-Item $stdoutPath -Force -ErrorAction SilentlyContinue
        }

        if (Test-Path $stderrPath) {
            Remove-Item $stderrPath -Force -ErrorAction SilentlyContinue
        }

        if ($process) {
            $process.Dispose()
        }
    }
}

$tfOutput = @()
$tfStatus = "NotStarted"
$devToolsStatus = "NotStarted"
$devToolsNote = ""
$tfsBuildOutput = @()
$tfsBuildStatus = "NotStarted"
$tfsBuildErrorSummary = @("NotStarted")
$tfsBuildDuration = [TimeSpan]::Zero
$tfsBuildWarningCount = 0

try {
    Write-Log "Starting TFVC get latest + DevTools workflow." "Cyan"
    Write-Log "TFVC root: $mainRoot" "Cyan"
    Write-Log "DevTools script: $devToolsScript" "Cyan"
    Write-Log "TfsBuild script: $tfsBuildScript" "Cyan"

    if (-not (Test-Path $mainRoot)) {
        throw "TFVC root path not found: $mainRoot"
    }

    if (-not (Test-Path $devToolsScript)) {
        throw "DevTools script not found: $devToolsScript"
    }

    if (-not (Test-Path $tfsBuildScript)) {
        throw "TfsBuild script not found: $tfsBuildScript"
    }

    Set-Location $mainRoot
    Write-Log "Running: tf get . /recursive /noprompt" "Yellow"

    $tfOutput = & tf get . /recursive /noprompt 2>&1 | ForEach-Object { $_.ToString() }
    $tfStatus = if ($LASTEXITCODE -eq 0) { "Success" } else { "Failed($LASTEXITCODE)" }

    if ($tfOutput.Count -eq 0) {
        Write-Log "tf get completed with no console output." "Green"
    }
    else {
        Write-Log "tf get output:" "Green"
        $tfOutput | ForEach-Object { Write-Host $_ }
    }

    Set-Location (Split-Path -Parent $devToolsScript)
    Write-Log "Resolved mapping: _DevTools.ps1 option 1 => TfsBuild.ps1 Dev" "Yellow"
    Write-Log "Running: powershell -ExecutionPolicy Bypass -File $tfsBuildScript Dev" "Yellow"

    $tfsBuildResult = Invoke-ProcessWithHeartbeat -FilePath "powershell.exe" -ArgumentList @("-ExecutionPolicy", "Bypass", "-File", $tfsBuildScript, "Dev") -StepName "TfsBuild.ps1 Dev"
    $tfsBuildOutput = $tfsBuildResult.OutputLines
    $tfsBuildDuration = $tfsBuildResult.Duration
    $tfsBuildErrorSummary = Get-ErrorSummary -Lines $tfsBuildOutput
    $tfsBuildWarningCount = Get-WarningCount -Lines $tfsBuildOutput

    $hasTfsBuildErrors = ($tfsBuildErrorSummary.Count -gt 0) -and ($tfsBuildErrorSummary[0] -ne "None")
    if ($hasTfsBuildErrors) {
        $tfsBuildStatus = if ($null -ne $tfsBuildResult.ExitCode -and "$($tfsBuildResult.ExitCode)" -ne "") { "Failed($($tfsBuildResult.ExitCode))" } else { "Failed" }
    }
    elseif ($tfsBuildWarningCount -gt 0) {
        $tfsBuildStatus = "SucceededWithWarnings($tfsBuildWarningCount)"
    }
    else {
        $tfsBuildStatus = "Success"
    }

    if ($tfsBuildOutput.Count -eq 0) {
        Write-Log "TfsBuild.ps1 Dev completed with no console output." "Green"
    }
    else {
        Write-Log ("TfsBuild.ps1 Dev completed. Duration: {0:hh\:mm\:ss}. Output lines: {1}. Latest: {2}" -f $tfsBuildDuration, $tfsBuildOutput.Count, (Get-LatestSummaryLine -Lines $tfsBuildOutput)) "Green"
    }

    $devToolsStatus = "MappedToTfsBuildDev"
    $devToolsNote = "This wrapper does not modify _DevTools.ps1. It directly runs TfsBuild.ps1 Dev because _DevTools.ps1 option 1 resolves to that command, which allows this script to capture today's error summary."
    Write-Log "TfsBuild.ps1 Dev completed with status: $tfsBuildStatus" "Green"
}
catch {
    Write-Log $_.Exception.Message "Red"

    if ($tfStatus -eq "NotStarted") {
        $tfStatus = "Failed"
    }

    if ($devToolsStatus -eq "NotStarted") {
        $devToolsStatus = "Skipped"
    }

    if ($tfsBuildStatus -eq "NotStarted") {
        $tfsBuildStatus = "Skipped"
        $tfsBuildErrorSummary = @("Not available because an earlier step failed.")
    }

    $devToolsNote = if ($devToolsNote) { $devToolsNote } else { "DevTools step was not completed because an earlier step failed." }
}
finally {
    $endTime = Get-Date
    $replacingCount = Get-MatchCount -Lines $tfOutput -Pattern '^Replacing '
    $deletingCount = Get-MatchCount -Lines $tfOutput -Pattern '^Deleting '
    $newCount = Get-MatchCount -Lines $tfOutput -Pattern '^Getting '
    $summaryLines = @(
        "TFVC Get Latest + DevTools Summary",
        "Start Time : $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))",
        "End Time   : $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))",
        "TFVC Root  : $mainRoot",
        "TFVC Get   : $tfStatus",
        "Replaced   : $replacingCount",
        "Deleted    : $deletingCount",
        "Got/New    : $newCount",
        "TfsBuild  : $tfsBuildStatus",
        "TfsBuild Duration: $($tfsBuildDuration.ToString('hh\:mm\:ss'))",
        "TfsBuild Warnings: $tfsBuildWarningCount",
        "DevTools   : $devToolsStatus",
        "Note       : $devToolsNote",
        "Summary File: $summaryPath",
        "TfsBuild Error Summary:"
    )

    $summaryLines += $tfsBuildErrorSummary | ForEach-Object { "  $_" }

    $summaryLines | Set-Content -Path $summaryPath -Encoding UTF8

    Write-Host ""
    Write-Log "Run summary:" "Cyan"
    $summaryLines | ForEach-Object { Write-Host $_ }
    Write-Log "Summary written to: $summaryPath" "Cyan"
    Start-Process notepad.exe $summaryPath
}
