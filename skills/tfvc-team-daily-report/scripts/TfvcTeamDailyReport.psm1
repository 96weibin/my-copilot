Set-StrictMode -Version Latest

function ConvertTo-NormalizedIdentity {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    return (($Value.Trim().ToLowerInvariant() -replace '[(),]', ' ') -replace '\s+', ' ')
}

function Get-TeamRosterIndex {
    param(
        [Parameter(Mandatory = $true)][string]$RosterPath,
        [Parameter(Mandatory = $true)]$Configuration
    )

    $index = @{}
    $currentTeam = $null

    foreach ($line in (Get-Content -Path $RosterPath)) {
        if ($line -match '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$') {
            $team = $Matches[1].Trim()
            if ($team -notin @('Agile Team', '---')) {
                foreach ($name in @($Matches[3].Trim(), $Matches[4].Trim())) {
                    $normalized = ConvertTo-NormalizedIdentity $name
                    $index[$normalized] = [pscustomobject]@{ Team = $team; CanonicalName = $name; MatchType = "roster-leadership" }
                }
            }
            continue
        }

        if ($line -match '^###\s+(.+?)\s*$') {
            $currentTeam = $Matches[1].Trim()
            continue
        }

        if ($currentTeam -and $line -match '^-\s+(.+?)\s*$') {
            $name = $Matches[1].Trim()
            $normalized = ConvertTo-NormalizedIdentity $name
            $index[$normalized] = [pscustomobject]@{
                Team = $currentTeam
                CanonicalName = $name
                MatchType = "roster-name"
            }
        }
    }

    foreach ($identity in @($Configuration.identityOverrides)) {
        $values = @($identity.canonicalName) + @($identity.aliases) + @($identity.emails) + @($identity.accounts)
        foreach ($value in $values) {
            $normalized = ConvertTo-NormalizedIdentity $value
            if ($normalized) {
                $index[$normalized] = [pscustomobject]@{
                    Team = $identity.team
                    CanonicalName = $identity.canonicalName
                    MatchType = "identity-override"
                }
            }
        }
    }

    return $index
}

function Resolve-TeamIdentity {
    param(
        [AllowNull()][string]$Identity,
        [Parameter(Mandatory = $true)][hashtable]$RosterIndex
    )

    $normalized = ConvertTo-NormalizedIdentity $Identity
    if ($normalized -and $RosterIndex.ContainsKey($normalized)) {
        return $RosterIndex[$normalized]
    }

    $inputTokens = @($normalized -split ' ' | Where-Object { $_ })
    if ($inputTokens.Count -ge 2) {
        $candidates = @($RosterIndex.GetEnumerator() | Where-Object {
            $candidateTokens = @($_.Key -split ' ' | Where-Object { $_ })
            $candidateTokens.Count -ge 2 -and $candidateTokens.Count -le $inputTokens.Count -and
                @($candidateTokens | Where-Object { $inputTokens -notcontains $_ }).Count -eq 0
        } | ForEach-Object { $_.Value } | Sort-Object Team, CanonicalName -Unique)
        if ($candidates.Count -eq 1) {
            return $candidates[0]
        }
    }

    return $null
}

function Test-IsNoiseChangeset {
    param([AllowNull()][string]$Author, [AllowNull()][string]$Comment)

    if ($Author -match '(?i)^atbuild(?:\.|\\|$)') { return $true }
    $meaningfulComment = (($Comment -replace '(?i)\*\*\*NO_CI\*\*\*', '') -replace '\s+', ' ').Trim()
    return $meaningfulComment -match '(?i)^(?:advance|update|bump)\s+(?:the\s+)?(?:build\s+)?version\b'
}

function Get-WorkItemIdsFromText {
    param([AllowNull()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $ids = New-Object System.Collections.Generic.HashSet[int]
    foreach ($match in [regex]::Matches($Text, '(?i)\b(?:bug|user\s+story|task|defect)\s*#?\s*(\d{4,7})(?<tail>(?:\s*,\s*\d{4,7})*)')) {
        [void]$ids.Add([int]$match.Groups[1].Value)
        foreach ($tailMatch in [regex]::Matches($match.Groups['tail'].Value, '\d{4,7}')) {
            [void]$ids.Add([int]$tailMatch.Value)
        }
    }

    return @($ids | Sort-Object)
}

function Get-CodeRoute {
    param([string[]]$ChangedPaths)

    $meaningfulPaths = @($ChangedPaths | Where-Object { $_ -notmatch '(?i)(?:AssemblyInfo|package-lock\.json|versions?\.xml)$' })
    if ($meaningfulPaths.Count -eq 0) {
        return "non-code"
    }

    $uiCount = @($meaningfulPaths | Where-Object { $_ -match '(?i)/(?:AspenUnified\.(?:Aura|Aum)Services/)?UI/' }).Count
    $nonUiCount = $meaningfulPaths.Count - $uiCount
    if ($uiCount -gt 0 -and $nonUiCount -gt 0) { return "mixed" }
    if ($uiCount -gt 0) { return "frontend" }
    return "backend"
}

function ConvertFrom-TfChangesetOutput {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines)

    $values = @{}
    $commentLines = New-Object System.Collections.Generic.List[string]
    $changedPaths = New-Object System.Collections.Generic.List[string]
    $linkedWorkItemIds = New-Object System.Collections.Generic.HashSet[int]
    $section = "header"

    foreach ($line in $Lines) {
        if ($line -match '^Changeset:\s*(\d+)') { $values.ChangesetId = [int]$Matches[1]; continue }
        if ($line -match '^User:\s*(.+)$') { $values.Author = $Matches[1].Trim(); continue }
        if ($line -match '^Checked in by:\s*(.+)$') { $values.CheckedInBy = $Matches[1].Trim(); continue }
        if ($line -match '^Date:\s*(.+)$') { $values.DateText = $Matches[1].Trim(); continue }
        if ($line -match '^Comment:\s*$') { $section = "comment"; continue }
        if ($line -match '^Items:\s*$') { $section = "items"; continue }
        if ($line -match '^Work Items:\s*$') { $section = "work-items"; continue }
        if ($line -match '^[A-Za-z][A-Za-z ]+:\s*$') { $section = "other"; continue }

        switch ($section) {
            "comment" {
                if (-not [string]::IsNullOrWhiteSpace($line)) { $commentLines.Add($line.Trim()) }
            }
            "items" {
                if ($line -match '(\$/[^;]+)(?:;X\d+)?\s*$') { $changedPaths.Add($Matches[1].Trim()) }
            }
            "work-items" {
                foreach ($match in [regex]::Matches($line, '\b\d{4,7}\b')) { [void]$linkedWorkItemIds.Add([int]$match.Value) }
            }
        }
    }

    if (-not $values.ContainsKey('ChangesetId')) {
        throw "TFVC changeset output did not contain a Changeset id."
    }

    return [pscustomobject]@{
        ChangesetId = $values.ChangesetId
        Author = if ($values.ContainsKey('Author')) { $values.Author } else { $null }
        CheckedInBy = if ($values.ContainsKey('CheckedInBy')) { $values.CheckedInBy } else { $null }
        DateText = if ($values.ContainsKey('DateText')) { $values.DateText } else { $null }
        Comment = ($commentLines -join " ")
        ChangedPaths = @($changedPaths)
        LinkedWorkItemIds = @($linkedWorkItemIds | Sort-Object)
    }
}

function Resolve-ChangesetTeam {
    param(
        [AllowNull()]$AuthorMatch,
        [AllowNull()]$CheckedInByMatch,
        [string[]]$WorkItemAreaPaths,
        [Parameter(Mandatory = $true)]$Configuration
    )

    $evidence = New-Object System.Collections.Generic.List[string]
    $teams = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($match in @($AuthorMatch, $CheckedInByMatch)) {
        if ($null -ne $match) {
            [void]$teams.Add($match.Team)
            $evidence.Add("identity:$($match.Team):$($match.CanonicalName)")
        }
    }

    foreach ($property in $Configuration.teamScope.areaPaths.PSObject.Properties) {
        $areaConfig = $property.Value
        if ($areaConfig.verificationStatus -ne 'verified' -or [string]::IsNullOrWhiteSpace($areaConfig.value)) {
            continue
        }

        foreach ($areaPath in @($WorkItemAreaPaths)) {
            if ($areaPath -and ($areaPath -eq $areaConfig.value -or $areaPath.StartsWith("$($areaConfig.value)\", [System.StringComparison]::OrdinalIgnoreCase))) {
                [void]$teams.Add($property.Name)
                $evidence.Add("area:$($property.Name):$areaPath")
            }
        }
    }

    $includedTeams = @($Configuration.teamScope.primaryTeam) + @($Configuration.teamScope.includedCounterpartTeams)
    $includedMatches = @($teams | Where-Object { $includedTeams -contains $_ })
    $category = if ($includedMatches.Count -gt 0) { "team-plum-related" } elseif ($teams.Count -gt 0) { "other-agile-team" } else { "team-unconfirmed" }
    $relationship = if ($teams.Contains('Plum')) { "plum-direct" } elseif ($teams.Contains('Capulin')) { "capulin-backend-counterpart" } else { $null }

    return [pscustomobject]@{
        Category = $category
        Relationship = $relationship
        Teams = @($teams | Sort-Object)
        Evidence = @($evidence)
        HasConflict = $teams.Count -gt 1
    }
}

Export-ModuleMember -Function ConvertTo-NormalizedIdentity, Get-TeamRosterIndex, Resolve-TeamIdentity, Get-WorkItemIdsFromText, Get-CodeRoute, Test-IsNoiseChangeset, ConvertFrom-TfChangesetOutput, Resolve-ChangesetTeam