$skillRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $skillRoot "..\.."))
Import-Module (Join-Path $skillRoot "scripts\TfvcTeamDailyReport.psm1") -Force
$config = Get-Content (Join-Path $repoRoot "agile\projects\plum\tfvc-daily-report.json") -Raw | ConvertFrom-Json
$rosterPath = Join-Path $repoRoot "agile\projects\plum\agile-team-roster.md"
$rosterIndex = Get-TeamRosterIndex -RosterPath $rosterPath -Configuration $config

Describe "TFVC Team Daily Report classification" {
    It "canonicalizes the Alaina roster spelling to Alaia" {
        $match = Resolve-TeamIdentity "Alaina Gan" $rosterIndex
        $match.Team | Should Be "Plum"
        $match.CanonicalName | Should Be "Gan, Alaia"
    }

    It "matches a TFVC long name through its roster nickname" {
        $match = Resolve-TeamIdentity "Xie, Haowen (Howar)" $rosterIndex
        $match.Team | Should Be "Mango"
        $match.CanonicalName | Should Be "Howar Xie"
    }

    It "includes a Capulin identity in Team Plum scope with a counterpart label" {
        $capulin = Resolve-TeamIdentity "Carolina Bolanos" $rosterIndex
        $resolution = Resolve-ChangesetTeam -AuthorMatch $capulin -CheckedInByMatch $null -WorkItemAreaPaths @() -Configuration $config
        $resolution.Category | Should Be "team-plum-related"
        $resolution.Relationship | Should Be "capulin-backend-counterpart"
    }

    It "indexes Capulin ATL and PO from the leadership table" {
        (Resolve-TeamIdentity "Eduardo Beltran" $rosterIndex).Team | Should Be "Capulin"
        (Resolve-TeamIdentity "Alex Joyal" $rosterIndex).Team | Should Be "Capulin"
    }

    It "matches observed Capulin TFVC display names" {
        (Resolve-TeamIdentity "Diaz, Diego" $rosterIndex).CanonicalName | Should Be "Diego Diaz"
        (Resolve-TeamIdentity "Rivera, JulioRoberto" $rosterIndex).CanonicalName | Should Be "Julio Rivera"
        (Resolve-TeamIdentity "Joyal, Alexander" $rosterIndex).CanonicalName | Should Be "Alex Joyal"
    }

    It "does not infer Capulin from backend paths" {
        $route = Get-CodeRoute @('$/UnifiedPIMS/Releases/Main/Psc/Aum/Services/Order.cs')
        $resolution = Resolve-ChangesetTeam -AuthorMatch $null -CheckedInByMatch $null -WorkItemAreaPaths @() -Configuration $config
        $route | Should Be "backend"
        $resolution.Category | Should Be "team-unconfirmed"
    }

    It "recognizes Plum child Area Paths" {
        $resolution = Resolve-ChangesetTeam -AuthorMatch $null -CheckedInByMatch $null -WorkItemAreaPaths @('AspenTech SAFe\Summit Solution Train\Orchard ART\Plum\UI') -Configuration $config
        $resolution.Category | Should Be "team-plum-related"
        $resolution.Relationship | Should Be "plum-direct"
    }

    It "preserves team conflict evidence" {
        $plum = Resolve-TeamIdentity "Anna Xie" $rosterIndex
        $mango = Resolve-TeamIdentity "Howar Xie" $rosterIndex
        $resolution = Resolve-ChangesetTeam -AuthorMatch $plum -CheckedInByMatch $mango -WorkItemAreaPaths @() -Configuration $config
        $resolution.HasConflict | Should Be $true
        $resolution.Teams.Count | Should Be 2
    }
}

Describe "TFVC changeset parsing" {
    It "parses comment, items and linked work items when Checked in by is absent" {
        $parsed = ConvertFrom-TfChangesetOutput @(
            'Changeset: 123456',
            'User: Zhao, Weibin',
            'Date: Wednesday, August 26, 2026 9:00:00 AM',
            '',
            'Comment:',
            '  Bug 12345: sample',
            '',
            'Items:',
            '  edit  $/UnifiedPIMS/Releases/Main/Psc/Aum/UI/a.ts',
            '',
            'Work Items:',
            '  12345 Bug'
        )
        $parsed.ChangesetId | Should Be 123456
        $parsed.CheckedInBy | Should Be $null
        $parsed.ChangedPaths.Count | Should Be 1
        $parsed.LinkedWorkItemIds[0] | Should Be 12345
    }

    It "extracts prefixed and comma-separated Work Item ids" {
        $ids = @(Get-WorkItemIdsFromText 'fix bug 103066, 103082 and Task 102310')
        ($ids -join ',') | Should Be '102310,103066,103082'
    }

    It "filters build version changes but not normal NO_CI changes" {
        (Test-IsNoiseChangeset 'atbuild.psb' 'Advance build version to 11.2.3 ***NO_CI***') | Should Be $true
        (Test-IsNoiseChangeset 'Xie, Anna' 'Bug 12345: fix order ***NO_CI***') | Should Be $false
    }
}