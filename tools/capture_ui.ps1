<#
.SYNOPSIS
    Capture Steam Navigator UI screenshots with real rendering (windowed Godot).

.DESCRIPTION
    Two modes, selected by the parameters:

    Legacy shipyard / overview mode (no -AllScreens / -Screens), unchanged:
      - runs res://tools/ui_snapshot.gd at 1440x900 (never --headless: the
        viewport texture is empty without a real renderer);
      - bootstraps Core exactly like framework/tests/test_case.gd;
      - saves docs/design/screenshots/shipyard_normal.png and (unless
        -SkipRefit) docs/design/screenshots/shipyard_refit.png;
      - -Tabs / -Categories / -Damage / -OverviewStage / -OverviewDetail add the
        same extra captures as before;
      - validation: every expected PNG exists and is newer than the run start;
        exit code 0 on success, 1 otherwise. Log: .godot-ui-snapshot.log.

    Full-page skin acceptance mode (-AllScreens or -Screens):
      - for each resolution (default 1440x900 and 960x540; override with
        -Resolution "1440x900" or "1440x900,960x540"):
          godot --resolution <res> --window=<res> --script res://tools/ui_snapshot.gd
                -- --out-dir=res://docs/design/screenshots/skin/<res> ...
      - -AllScreens captures every page:
          main_menu, new_game, mods, settings,
          overview, overview_2d, overview_detail,
          market, supply, contracts, tavern, base, auto_trade, ruins,
          shipyard_normal, shipyard_refit, shipyard_buy, shipyard_craft,
          shipyard_misc, sea_chart, clue_log,
          at_sea, event, settlement, victory, ui_kit;
      - -Screens "overview,market,victory" captures a subset (comma list);
      - supply is reached through the real navigation path; since 4.5.3 the
        shell redirects it into the market page, so its capture is the market
        page scrolled to the MarketSupply block (documented, not fabricated);
      - validation: the Godot side prints one "[EXPECT] <absolute path>" line
        per planned screenshot before capturing. This script verifies that
        every expected file exists and is newer than that resolution's start
        time. A missing / stale / empty expectation set fails the run.
      - exit code 0 only when every resolution succeeded.

    Godot executable resolution: -GodotBin > $env:GODOT_BIN > the dsh-tools
    default > the Steam install path from AGENTS.md.
    This script is ASCII-only so Windows PowerShell 5.1 can parse it.

.EXAMPLE
    .\tools\capture_ui.ps1

.EXAMPLE
    .\tools\capture_ui.ps1 -GodotBin "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" -Seed 5201

.EXAMPLE
    .\tools\capture_ui.ps1 -Tabs "buy,craft" -OverviewStage -OverviewDetail

.EXAMPLE
    .\tools\capture_ui.ps1 -AllScreens

.EXAMPLE
    .\tools\capture_ui.ps1 -Screens "overview,market,shipyard_refit,victory" -Resolution "1440x900"
#>
[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [int]$Seed = 5201,
    [string]$OutDir = "res://docs/design/screenshots",
    [string]$Categories = "cargo,misc",
    [string]$Tabs = "",
    [string]$Damage = "",
    [switch]$SkipRefit,
    [switch]$OverviewStage,
    [switch]$OverviewDetail,
    [switch]$AllScreens,
    [string]$Screens = "",
    [string]$Resolution = ""
)

$ErrorActionPreference = "Stop"

$defaultGodotCandidates = @(
    "C:\Users\Zhoei\AppData\Local\dsh-tools\godot\Godot_v4.7.2-stable_win64_console.exe",
    "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
)
if ([string]::IsNullOrWhiteSpace($GodotBin)) {
    foreach ($candidate in $defaultGodotCandidates) {
        if (Test-Path -LiteralPath $candidate) { $GodotBin = $candidate; break }
    }
}
if ([string]::IsNullOrWhiteSpace($GodotBin) -or -not (Test-Path -LiteralPath $GodotBin)) {
    throw "Godot executable not found: $GodotBin (pass -GodotBin or set GODOT_BIN)"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $repoRoot ".godot-ui-snapshot.log"
if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath -Force }
[System.IO.File]::WriteAllText($logPath, "", [System.Text.Encoding]::UTF8)

function Resolve-RepoPath {
    param([string]$PathValue)
    if ($PathValue -like "res://*") {
        return (Join-Path $repoRoot $PathValue.Substring("res://".Length))
    }
    return $PathValue
}

function Add-LogSection {
    param([string]$Title, [string]$CommandLine, [string]$StdoutText, [string]$StderrText)
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine("===== $Title =====")
    [void]$builder.AppendLine($CommandLine)
    [void]$builder.AppendLine($StdoutText)
    if (-not [string]::IsNullOrWhiteSpace($StderrText)) {
        [void]$builder.AppendLine("[stderr]")
        [void]$builder.AppendLine($StderrText)
    }
    [void]$builder.AppendLine("")
    [System.IO.File]::AppendAllText($logPath, $builder.ToString(), [System.Text.Encoding]::UTF8)
}

function Invoke-GodotSnapshot {
    param([string[]]$Arguments, [string]$Label)
    $stdoutPath = "$logPath.$Label.out"
    $stderrPath = "$logPath.$Label.err"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $GodotBin -ArgumentList $Arguments -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $stopwatch.Stop()
    $stdoutText = ""
    $stderrText = ""
    if (Test-Path -LiteralPath $stdoutPath) {
        $stdoutText = [System.IO.File]::ReadAllText($stdoutPath, [System.Text.Encoding]::UTF8)
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $stderrText = [System.IO.File]::ReadAllText($stderrPath, [System.Text.Encoding]::UTF8)
    }
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdoutText
        Stderr = $stderrText
        Seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 1)
        CommandLine = ("$GodotBin " + ($Arguments -join " "))
    }
}

function Get-ExpectedPaths {
    param([string]$StdoutText)
    $paths = @()
    foreach ($line in ($StdoutText -split "`r?`n")) {
        if ($line -match '^\[EXPECT\]\s+(.+)$') {
            $paths += $Matches[1].Trim()
        }
    }
    return $paths
}

function Assert-FreshShots {
    param([string[]]$Expected, [datetime]$StartedAt, [string]$Label, [string]$LogHint)
    $missing = @()
    $stale = @()
    foreach ($path in $Expected) {
        if (-not (Test-Path -LiteralPath $path)) {
            $missing += $path
        } elseif ((Get-Item -LiteralPath $path).LastWriteTime -lt $StartedAt) {
            $stale += $path
        }
    }
    if ($Expected.Count -eq 0) {
        Write-Host "$Label : Godot printed no [EXPECT] manifest; capture did not start." -ForegroundColor Red
        return $false
    }
    if ($missing.Count -eq 0 -and $stale.Count -eq 0) {
        Write-Host ""
        Write-Host ("Screenshots ({0}, {1}):" -f $Label, $Expected.Count)
        foreach ($path in $Expected) { Write-Host "  - $path" }
        return $true
    }
    Write-Host "$Label : expected screenshots missing or stale; full log: $LogHint" -ForegroundColor Red
    foreach ($path in $missing) { Write-Host "  missing: $path" -ForegroundColor Red }
    foreach ($path in $stale) { Write-Host "  stale: $path" -ForegroundColor Red }
    return $false
}

# ---------------------------------------------------------------------------
# Full-page skin acceptance mode
# ---------------------------------------------------------------------------
$skinMode = $AllScreens -or -not [string]::IsNullOrWhiteSpace($Screens)
if ($skinMode) {
    $resolutions = @()
    if ([string]::IsNullOrWhiteSpace($Resolution)) {
        $resolutions = @("1440x900", "960x540")
    } else {
        foreach ($entry in ($Resolution -split ",")) {
            $value = $entry.Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) { $resolutions += $value }
        }
    }
    if ($resolutions.Count -eq 0) { throw "no resolution given" }

    if ($OutDir -eq "res://docs/design/screenshots") {
        $skinRoot = "res://docs/design/screenshots/skin"
    } else {
        $skinRoot = $OutDir
    }

    $allOk = $true
    foreach ($res in $resolutions) {
        if ($res -notmatch '^\d+x\d+$') { throw "invalid resolution: $res (expected WIDTHxHEIGHT)" }
        $resOutDir = ("{0}/{1}" -f $skinRoot.TrimEnd('/'), $res)
        $godotArgs = @(
            "--path", $repoRoot,
            "--resolution", $res,
            "--script", "res://tools/ui_snapshot.gd",
            "--",
            "--seed=$Seed",
            "--out-dir=$resOutDir",
            # --window is a snapshot-script argument (after --), not a Godot engine flag.
            "--window=$res"
        )
        if ($AllScreens) {
            $godotArgs += "--all-screens"
        } else {
            $godotArgs += "--screens=$Screens"
        }
        if ($SkipRefit) { $godotArgs += "--skip-refit" }
        if (-not [string]::IsNullOrWhiteSpace($Damage)) { $godotArgs += "--damage=$Damage" }

        $label = "skin-$res"
        Write-Host ""
        Write-Host "===== $label ====="
        $startedAt = Get-Date
        $run = Invoke-GodotSnapshot -Arguments $godotArgs -Label $label
        Add-LogSection -Title $label -CommandLine $run.CommandLine -StdoutText $run.Stdout -StderrText $run.Stderr
        Write-Host $run.Stdout
        if (-not [string]::IsNullOrWhiteSpace($run.Stderr)) {
            Write-Host $run.Stderr -ForegroundColor Yellow
        }
        Write-Host ("Godot exit code: {0} ({1}s)" -f $run.ExitCode, $run.Seconds)
        $expected = Get-ExpectedPaths -StdoutText $run.Stdout
        $fresh = Assert-FreshShots -Expected $expected -StartedAt $startedAt -Label $label -LogHint $logPath
        if ($run.ExitCode -ne 0 -or -not $fresh) {
            $allOk = $false
            Write-Host "Godot exit code: $($run.ExitCode) (capture failed or runtime error)" -ForegroundColor Red
        }
    }
    Write-Host "Full log: $logPath"
    if (-not $allOk) { exit 1 }
    exit 0
}

# ---------------------------------------------------------------------------
# Legacy shipyard / overview mode (unchanged behavior)
# ---------------------------------------------------------------------------
$stdoutPath = "$logPath.out"
$stderrPath = "$logPath.err"

$godotArgs = @(
    "--path", $repoRoot,
    "--resolution", "1440x900",
    "--script", "res://tools/ui_snapshot.gd",
    "--",
    "--seed=$Seed",
    "--out-dir=$OutDir",
    "--category=$Categories"
)
if ($SkipRefit) { $godotArgs += "--skip-refit" }
if (-not [string]::IsNullOrWhiteSpace($Tabs)) { $godotArgs += "--tabs=$Tabs" }
if ($OverviewStage) { $godotArgs += "--overview-stage" }
if ($OverviewDetail) { $godotArgs += "--overview-detail" }
if (-not [string]::IsNullOrWhiteSpace($Damage)) { $godotArgs += "--damage=$Damage" }

$startedAt = Get-Date
Write-Host "$GodotBin $($godotArgs -join ' ')"
$process = Start-Process -FilePath $GodotBin -ArgumentList $godotArgs -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$exitCode = $process.ExitCode

# Godot writes UTF-8; read it back explicitly so the Chinese log lines stay readable.
$stdoutText = ""
$stderrText = ""
if (Test-Path -LiteralPath $stdoutPath) {
    $stdoutText = [System.IO.File]::ReadAllText($stdoutPath, [System.Text.Encoding]::UTF8)
}
if (Test-Path -LiteralPath $stderrPath) {
    $stderrText = [System.IO.File]::ReadAllText($stderrPath, [System.Text.Encoding]::UTF8)
}
Add-LogSection -Title "legacy" -CommandLine ("$GodotBin " + ($godotArgs -join " ")) -StdoutText $stdoutText -StderrText $stderrText
Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
Write-Host $stdoutText
if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
    Write-Host $stderrText -ForegroundColor Yellow
}

if ($OutDir -like "res://*") {
    $screenshotsDir = Join-Path $repoRoot $OutDir.Substring("res://".Length)
} else {
    $screenshotsDir = $OutDir
}
$expected = @("shipyard_normal.png")
if (-not $SkipRefit) {
    $expected += "shipyard_refit.png"
    # Extra operations-dock tab captures (buy / craft) use the tab name.
    foreach ($tab in ($Tabs -split ",")) {
        $tab = $tab.Trim()
        if ([string]::IsNullOrWhiteSpace($tab) -or $tab -eq "install") { continue }
        $expected += "shipyard_refit_$tab.png"
    }
    # Extra per-category captures use the same short names as ui_snapshot.gd.
    foreach ($category in ($Categories -split ",")) {
        $category = $category.Trim()
        if ([string]::IsNullOrWhiteSpace($category) -or $category -eq "hulls") { continue }
        # C1 categories (hulls/boiler/cargo/utility/cabin/misc) already match file short names.
        $short = $category
        $expected += "shipyard_refit_$short.png"
    }
}
# Damaged-state captures are produced only when -Damage is passed.
if (-not [string]::IsNullOrWhiteSpace($Damage)) {
    $expected += "shipyard_normal_damaged.png"
    if (-not $SkipRefit) { $expected += "shipyard_refit_damaged.png" }
    $expected += "supply_damaged.png"
}
# Overview 3D port stage capture (2.5D slice 3) is opt-in.
if ($OverviewStage -or $OverviewDetail) { $expected += "overview_port_stage.png" }
if ($OverviewDetail) { $expected += "overview_detail.png" }

$shots = @()
$stale = @()
foreach ($name in $expected) {
    $path = Join-Path $screenshotsDir $name
    if (Test-Path -LiteralPath $path) {
        if ((Get-Item -LiteralPath $path).LastWriteTime -lt $startedAt) {
            $stale += $path
        } else {
            $shots += $path
        }
    }
}

if ($shots.Count -eq $expected.Count) {
    Write-Host ""
    Write-Host "Screenshots:"
    foreach ($shot in $shots) { Write-Host "  - $shot" }
} else {
    Write-Host "Expected fresh screenshots missing or stale; full log: $logPath" -ForegroundColor Red
    foreach ($path in $stale) { Write-Host "  stale: $path" -ForegroundColor Red }
    $exitCode = 1
}
Write-Host "Full log: $logPath"
if ($exitCode -ne 0) {
    Write-Host "Godot exit code: $exitCode (capture failed or runtime error)" -ForegroundColor Red
}
exit $exitCode
