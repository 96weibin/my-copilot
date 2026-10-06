[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$RosterPath,
    [switch]$DryRun,
    [switch]$SkipAdo
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
$ConfigPath = if ($ConfigPath) { $ConfigPath } else { Join-Path $repoRoot "agile\projects\plum\tfvc-daily-report.json" }
$RosterPath = if ($RosterPath) { $RosterPath } else { Join-Path $repoRoot "agile\projects\plum\agile-team-roster.md" }
$modulePath = Join-Path $PSScriptRoot "TfvcTeamDailyReport.psm1"
Import-Module $modulePath -Force

function Resolve-RepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
}

function Write-AtomicUtf8 {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)
    $directory = Split-Path -Parent $Path
    [void](New-Item -ItemType Directory -Path $directory -Force)
    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Content, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -Path $temporaryPath -Destination $Path -Force
    }
    finally {
        if (Test-Path $temporaryPath) { Remove-Item $temporaryPath -Force -ErrorAction SilentlyContinue }
    }
}

function Invoke-TfCommand {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = @(& $script:tfPath @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    if ($LASTEXITCODE -ne 0) {
        throw "tf.exe failed with exit code $LASTEXITCODE. $($output -join ' ')"
    }
    return $output
}

function Get-HistoryIds {
    param([Parameter(Mandatory = $true)][string]$ServerPath, [string]$VersionRange, [int]$StopAfter = 0, [switch]$SortAscending)
    $arguments = @("history", $ServerPath, "/recursive", "/noprompt", "/format:brief", "/collection:$($script:config.collectionUrl)")
    if ($SortAscending) { $arguments += "/sort:ascending" }
    if ($VersionRange) { $arguments += "/version:$VersionRange" }
    if ($StopAfter -gt 0) { $arguments += "/stopafter:$StopAfter" }
    $lines = Invoke-TfCommand $arguments
    return @($lines | ForEach-Object { if ($_ -match '^\s*(\d+)\s+') { [int]$Matches[1] } } | Sort-Object -Unique)
}

function Get-PreviousBusinessDayAtTen {
    param([datetime]$Now)
    $candidate = $Now.Date.AddHours(10).AddDays(-1)
    while ($candidate.DayOfWeek -in @([DayOfWeek]::Saturday, [DayOfWeek]::Sunday)) { $candidate = $candidate.AddDays(-1) }
    return $candidate
}

function Get-AdoPat {
    param([string]$VariableName)
    $pat = [Environment]::GetEnvironmentVariable($VariableName, 'Process')
    if ([string]::IsNullOrWhiteSpace($pat)) {
        $pat = [Environment]::GetEnvironmentVariable($VariableName, 'User')
    }
    if ([string]::IsNullOrWhiteSpace($pat)) {
        $pat = [Environment]::GetEnvironmentVariable($VariableName, 'Machine')
    }
    if ([string]::IsNullOrWhiteSpace($pat)) {
        throw "ADO PAT environment variable '$VariableName' is not available in Process, User, or Machine scope. Configure it before running or scheduling the report."
    }
    return $pat
}

function Get-AdoWorkItems {
    param([int[]]$Ids)
    $result = @{}
    if ($Ids.Count -eq 0) { return $result }
    $pat = Get-AdoPat $script:config.patEnvironmentVariable
    try {
        $basicToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
        $headers = @{ Authorization = "Basic $basicToken" }
        $fields = @("System.Id", "System.Title", "System.WorkItemType", "System.State", "System.AssignedTo", "System.AreaPath", "System.IterationPath")
        for ($offset = 0; $offset -lt $Ids.Count; $offset += 200) {
            $batchIds = @($Ids | Select-Object -Skip $offset -First 200)
            $body = @{ ids = $batchIds; fields = $fields; errorPolicy = "Omit" } | ConvertTo-Json -Depth 4
            $organization = [uri]::EscapeDataString($script:config.organization)
            $project = [uri]::EscapeDataString($script:config.project)
            $uri = "https://dev.azure.com/$organization/$project/_apis/wit/workitemsbatch?api-version=7.1"
            $response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType "application/json" -Body $body
            if ($response -is [string]) {
                if ($response.TrimStart().StartsWith('<')) {
                    throw "ADO returned an HTML sign-in page. Environment variable '$($script:config.patEnvironmentVariable)' contains an invalid/expired PAT or cannot access organization '$($script:config.organization)'."
                }
                $response = $response | ConvertFrom-Json
            }
            foreach ($item in @($response.value)) { $result[[int]$item.id] = $item }
        }
    }
    finally {
        $pat = $null
    }
    return $result
}

function Escape-Markdown {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    return (($Value -replace '\|', '\|') -replace "`r?`n", ' ')
}

function Get-WorkItemField {
    param($WorkItem, [string]$Name)
    if ($null -eq $WorkItem -or $null -eq $WorkItem.fields) { return $null }
    $property = $WorkItem.fields.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    if ($property.Value -is [pscustomobject] -and $property.Value.PSObject.Properties['displayName']) { return $property.Value.displayName }
    return $property.Value
}

function Format-ChangesetSection {
    param([string]$Title, [object[]]$Changesets)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("## $Title")
    $lines.Add("")
    if ($Changesets.Count -eq 0) { $lines.Add("No changesets."); $lines.Add(""); return @($lines) }
    $lines.Add("| Changeset | Author | Product / Route | Work Items | Comment | Evidence |")
    $lines.Add("| --- | --- | --- | --- | --- | --- |")
    foreach ($changeset in $Changesets) {
        $workItems = @($changeset.WorkItems | ForEach-Object { "#$($_.Id) $($_.Type): $($_.Title) [$($_.State)]" }) -join '<br>'
        $evidence = @($changeset.TeamResolution.Evidence) -join '<br>'
        $lines.Add("| $($changeset.ChangesetId) | $(Escape-Markdown $changeset.Author) | $($changeset.Products -join ', ') / $($changeset.Route) | $(Escape-Markdown $workItems) | $(Escape-Markdown $changeset.Comment) | $(Escape-Markdown $evidence) |")
    }
    $lines.Add("")
    return @($lines)
}

$startedAt = Get-Date
$runId = $startedAt.ToString("yyyyMMdd-HHmmss")
$lastRunPath = $null
$logPath = $null
$status = "failed"
$stage = "initializing"

try {
    $script:config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $script:tfPath = (Get-Command tf.exe -ErrorAction Stop).Source
    if (-not (Test-Path $RosterPath)) { throw "Roster not found: $RosterPath" }
    $rosterIndex = Get-TeamRosterIndex -RosterPath $RosterPath -Configuration $config
    $statePath = Resolve-RepoPath $config.output.statePath
    $reportRoot = Resolve-RepoPath $config.output.reportRoot
    $logRoot = Resolve-RepoPath $config.output.logRoot
    $lastRunPath = Join-Path $logRoot "last-run.json"
    $logPath = Join-Path $logRoot "$runId.log"
    [void](New-Item -ItemType Directory -Path $logRoot -Force)

    $state = if (Test-Path $statePath) { Get-Content $statePath -Raw | ConvertFrom-Json } else { $null }
    $stage = "querying-upper-bound"
    $upperBound = 0
    foreach ($scope in $config.scopes) {
        $latest = @(Get-HistoryIds -ServerPath $scope.serverPath -StopAfter 1)
        if ($latest.Count -gt 0) { $upperBound = [Math]::Max($upperBound, [int]$latest[-1]) }
    }

    $stage = "querying-history"
    if ($null -ne $state -and $state.lastSuccessfulChangesetId) {
        $lastSuccessfulChangesetId = [int]$state.lastSuccessfulChangesetId
        $lowerBound = $lastSuccessfulChangesetId + 1
        $versionRange = if ($upperBound -gt $lastSuccessfulChangesetId) { "C$lowerBound~C$upperBound" } else { $null }
        $windowStart = $state.lastSuccessAt
        $hasQueryRange = $upperBound -gt $lastSuccessfulChangesetId
    }
    else {
        $bootstrapStart = Get-PreviousBusinessDayAtTen -Now $startedAt
        $versionRange = "D$($bootstrapStart.ToString('yyyy-MM-ddTHH:mm:ss'))~D$($startedAt.ToString('yyyy-MM-ddTHH:mm:ss'))"
        $windowStart = $bootstrapStart.ToString("o")
        $hasQueryRange = $upperBound -gt 0
    }

    $candidateIds = New-Object System.Collections.Generic.HashSet[int]
    if ($hasQueryRange) {
        foreach ($scope in $config.scopes) {
            foreach ($id in @(Get-HistoryIds -ServerPath $scope.serverPath -VersionRange $versionRange -SortAscending)) { [void]$candidateIds.Add($id) }
        }
    }

    $stage = "expanding-changesets"
    $changesets = New-Object System.Collections.Generic.List[object]
    $allWorkItemIds = New-Object System.Collections.Generic.HashSet[int]
    foreach ($id in @($candidateIds | Sort-Object)) {
        $detail = ConvertFrom-TfChangesetOutput (Invoke-TfCommand @("changeset", "$id", "/noprompt", "/collection:$($config.collectionUrl)"))
        $products = @($config.scopes | Where-Object { $scope = $_; @($detail.ChangedPaths | Where-Object { $_.StartsWith($scope.serverPath, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 } | ForEach-Object { $_.name })
        $workItemIds = New-Object System.Collections.Generic.HashSet[int]
        foreach ($workItemId in @($detail.LinkedWorkItemIds) + @(Get-WorkItemIdsFromText $detail.Comment)) { [void]$workItemIds.Add($workItemId); [void]$allWorkItemIds.Add($workItemId) }
        $changesets.Add([pscustomobject]@{
            ChangesetId = $detail.ChangesetId; Author = $detail.Author; CheckedInBy = $detail.CheckedInBy; DateText = $detail.DateText
            Comment = $detail.Comment; ChangedPaths = $detail.ChangedPaths; Products = $products; Route = Get-CodeRoute $detail.ChangedPaths
            WorkItemIds = @($workItemIds | Sort-Object); WorkItems = @(); TeamResolution = $null; IsNoise = Test-IsNoiseChangeset $detail.Author $detail.Comment
        })
    }

    $stage = "querying-ado"
    $adoItems = if ($SkipAdo) { @{} } else { Get-AdoWorkItems @($allWorkItemIds | Sort-Object) }
    $stage = "classifying"
    foreach ($changeset in $changesets) {
        $workItems = @($changeset.WorkItemIds | ForEach-Object {
            if ($adoItems.ContainsKey([int]$_)) {
                $item = $adoItems[[int]$_]
                [pscustomobject]@{ Id = [int]$_; Title = Get-WorkItemField $item 'System.Title'; Type = Get-WorkItemField $item 'System.WorkItemType'; State = Get-WorkItemField $item 'System.State'; AreaPath = Get-WorkItemField $item 'System.AreaPath'; IterationPath = Get-WorkItemField $item 'System.IterationPath' }
            }
            else { [pscustomobject]@{ Id = [int]$_; Title = "Unavailable"; Type = "Unknown"; State = "Unknown"; AreaPath = $null; IterationPath = $null } }
        })
        $changeset.WorkItems = $workItems
        $authorMatch = Resolve-TeamIdentity $changeset.Author $rosterIndex
        $checkedInByMatch = Resolve-TeamIdentity $changeset.CheckedInBy $rosterIndex
        $areaPaths = @($workItems | ForEach-Object { $_.AreaPath })
        $changeset.TeamResolution = Resolve-ChangesetTeam -AuthorMatch $authorMatch -CheckedInByMatch $checkedInByMatch -WorkItemAreaPaths $areaPaths -Configuration $config
    }

    $stage = "writing-report"
    $reportLines = New-Object System.Collections.Generic.List[string]
    $reportLines.Add("# Team Plum TFVC Daily Report")
    $reportLines.Add("")
    $reportLines.Add("- Generated: $($startedAt.ToString('yyyy-MM-dd HH:mm:ss zzz'))")
    $reportLines.Add("- Window start: $windowStart")
    $reportLines.Add("- Upper-bound changeset: $upperBound")
    $reportLines.Add("- Scopes: $(@($config.scopes.name) -join ', ')")
    $reportLines.Add("- Changesets: $($changesets.Count)")
    $reportLines.Add("- ADO enrichment: $(if ($SkipAdo) { 'skipped' } else { 'enabled' })")
    $reportLines.Add("")
    $reportLines.Add("## Summary")
    $reportLines.Add("")
    if ($changesets.Count -eq 0) {
        $reportLines.Add("No new changesets in this window.")
    }
    else {
        foreach ($group in @($changesets | Group-Object Author | Sort-Object @{ Expression = 'Count'; Descending = $true }, Name)) {
            $reportLines.Add("- $($group.Name): $($group.Count)")
        }
    }
    $reportLines.Add("")
    $reportLines.AddRange([string[]](Format-ChangesetSection "Plum direct" @($changesets | Where-Object { -not $_.IsNoise -and $_.TeamResolution.Relationship -eq 'plum-direct' })))
    $reportLines.AddRange([string[]](Format-ChangesetSection "Capulin backend counterpart" @($changesets | Where-Object { -not $_.IsNoise -and $_.TeamResolution.Relationship -eq 'capulin-backend-counterpart' })))
    $reportLines.AddRange([string[]](Format-ChangesetSection "Other Agile Teams" @($changesets | Where-Object { -not $_.IsNoise -and $_.TeamResolution.Category -eq 'other-agile-team' })))
    $reportLines.AddRange([string[]](Format-ChangesetSection "Team unconfirmed" @($changesets | Where-Object { -not $_.IsNoise -and $_.TeamResolution.Category -eq 'team-unconfirmed' })))
    $reportLines.AddRange([string[]](Format-ChangesetSection "Filtered noise" @($changesets | Where-Object { $_.IsNoise })))
    $reportLines.Add("## Data quality")
    $reportLines.Add("")
    $qualityItems = @($changesets | Where-Object { -not $_.Author -or $_.WorkItemIds.Count -eq 0 -or @($_.WorkItems | Where-Object { $_.Title -eq 'Unavailable' }).Count -gt 0 })
    if ($qualityItems.Count -eq 0) {
        $reportLines.Add("No data quality issues detected.")
    }
    else {
        foreach ($changeset in $qualityItems) {
            $reasons = New-Object System.Collections.Generic.List[string]
            if (-not $changeset.Author) { $reasons.Add("missing Author") }
            if ($changeset.WorkItemIds.Count -eq 0) { $reasons.Add("no Work Item id") }
            if (@($changeset.WorkItems | Where-Object { $_.Title -eq 'Unavailable' }).Count -gt 0) { $reasons.Add("Work Item unavailable") }
            $reportLines.Add("- $($changeset.ChangesetId): $($reasons -join ', ')")
        }
    }
    $reportLines.Add("")
    $reportContent = $reportLines -join [Environment]::NewLine
    $dailyDirectory = Join-Path (Join-Path $reportRoot $startedAt.ToString("yyyy")) $startedAt.ToString("MM")
    $dailyReportPath = Join-Path $dailyDirectory "$($startedAt.ToString('yyyy-MM-dd')).md"
    $archiveDirectory = Join-Path (Join-Path (Join-Path $reportRoot "runs") $startedAt.ToString("yyyy")) $startedAt.ToString("MM")
    $archiveReportPath = Join-Path $archiveDirectory "$($startedAt.ToString('yyyy-MM-dd-HHmmss')).md"

    if (-not $DryRun) {
        if ($changesets.Count -gt 0 -or -not (Test-Path $dailyReportPath)) {
            Write-AtomicUtf8 -Path $archiveReportPath -Content $reportContent
            Write-AtomicUtf8 -Path $dailyReportPath -Content $reportContent
            Write-AtomicUtf8 -Path (Join-Path $reportRoot "latest.md") -Content $reportContent
        }
        $newState = [ordered]@{ schemaVersion = 1; lastAttemptAt = $startedAt.ToString('o'); lastSuccessAt = (Get-Date).ToString('o'); lastSuccessfulChangesetId = $upperBound; status = 'success'; reportPath = $dailyReportPath }
        Write-AtomicUtf8 -Path $statePath -Content ($newState | ConvertTo-Json -Depth 5)
    }
    else {
        Write-Output $reportContent
    }

    $status = "success"
    $stage = "completed"
    $summary = [ordered]@{ runId = $runId; status = $status; stage = $stage; dryRun = [bool]$DryRun; startedAt = $startedAt.ToString('o'); completedAt = (Get-Date).ToString('o'); upperBoundChangesetId = $upperBound; changesetCount = $changesets.Count; reportPath = if ($DryRun) { $null } else { $dailyReportPath }; error = $null }
    Write-AtomicUtf8 -Path $lastRunPath -Content ($summary | ConvertTo-Json -Depth 5)
    Write-AtomicUtf8 -Path $logPath -Content ("Run completed successfully. Changesets: {0}. Upper bound: {1}." -f $changesets.Count, $upperBound)
    exit 0
}
catch {
    $errorMessage = $_.Exception.Message
    if ($lastRunPath) {
        $summary = [ordered]@{ runId = $runId; status = 'failed'; stage = $stage; dryRun = [bool]$DryRun; startedAt = $startedAt.ToString('o'); completedAt = (Get-Date).ToString('o'); error = $errorMessage }
        Write-AtomicUtf8 -Path $lastRunPath -Content ($summary | ConvertTo-Json -Depth 5)
    }
    if ($logPath) { Write-AtomicUtf8 -Path $logPath -Content "Run failed at $stage. $errorMessage" }
    Write-Error "TFVC team daily report failed at $stage. $errorMessage"
    exit 1
}