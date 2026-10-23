param(
    [string]$Godot = $env:GODOT_BIN,
    [int]$Shards = 0,
    [string]$Suite = "",
    [switch]$Summary,
    [switch]$NoImport
)

# Headless test entry point.
#
# By default every Godot suite runs in parallel shards and the results are merged,
# so wall time approaches the slowest shard instead of the sum of all suites. Shard
# membership is balanced with the timings of the previous run
# (`.godot/test_suite_timings.json`); a fresh clone starts with a declaration-order
# split and self-tunes from there.
#
# Examples:
#   pwsh ./tools/test.ps1                    # parallel full run (auto shard count)
#   pwsh ./tools/test.ps1 -Shards 4          # fixed shard count
#   pwsh ./tools/test.ps1 -Suite ui_shell    # one suite / name fragment, no sharding
#   pwsh ./tools/test.ps1 -Summary           # full run, only failures and suite totals
#   pwsh ./tools/test.ps1 -NoImport          # skip the one-time asset import check

$ErrorActionPreference = "Stop"
if (-not $Godot) {
    $Godot = (Get-Command godot -ErrorAction SilentlyContinue).Source
}
if (-not $Godot) {
    throw "Set GODOT_BIN to the Godot 4.x executable, or add godot to PATH."
}

$project = Split-Path -Parent $PSScriptRoot
$runner = "res://framework/tests/test_runner.gd"
$cacheDir = Join-Path $project ".godot/test_shards"
New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

# GODOT_BIN may point at the Steam launcher, which does not expose captured output
# to `&` reliably on every shell. Always run through Start-Process + files and read
# the files afterwards; this also keeps `-Wait` semantics honest.
function Invoke-GodotCapture {
    param(
        [string[]]$Arguments,
        [string]$Label
    )
    $stdout = Join-Path $cacheDir ("{0}.out.log" -f $Label)
    $stderr = Join-Path $cacheDir ("{0}.err.log" -f $Label)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $Godot -ArgumentList $Arguments -WorkingDirectory $project `
        -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr -Wait
    $watch.Stop()
    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        Stdout = $stdout
        Stderr = $stderr
        Seconds = [Math]::Round($watch.Elapsed.TotalSeconds, 1)
    }
}

function Write-ErrorOutput {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    # The Steam build prints a known codepage diagnostic on this machine; it is
    # engine noise, not test output, so keep it out of the shard summary.
    $lines = @(Get-Content -Path $Path | Where-Object { $_ -match '\S' -and $_ -notmatch 'Unicode parsing error' })
    if ($lines.Count -eq 0) { return }
    Write-Host "[stderr]"
    $lines | ForEach-Object { Write-Host $_ }
}

# A fresh clone or worktree has no .godot cache; import once so asset suites can load.
if (-not $NoImport -and -not (Test-Path (Join-Path $project ".godot/imported"))) {
    Write-Host "Importing project assets (first run only)..."
    $import = Invoke-GodotCapture -Arguments @("--headless", "--path", ".", "--editor", "--quit") -Label "import"
    if ($import.ExitCode -ne 0) {
        Write-ErrorOutput -Path $import.Stderr
        throw "project import failed with exit code $($import.ExitCode)"
    }
    Write-Host ("Project assets imported in {0}s" -f $import.Seconds)
}

# Dev shortcut: one suite (or name fragment), no sharding.
if ($Suite) {
    $run = Invoke-GodotCapture -Arguments @("--headless", "--path", ".", "--script", $runner, "--", "--suite=$Suite") -Label "suite"
    if (Test-Path $run.Stdout) { Get-Content -Path $run.Stdout | ForEach-Object { Write-Host $_ } }
    Write-ErrorOutput -Path $run.Stderr
    exit $run.ExitCode
}

if ($Shards -le 0) {
    $cores = [Environment]::ProcessorCount
    $Shards = [Math]::Min(8, [Math]::Max(2, $cores - 2))
}

# The suite list comes from the runner itself so this script never drifts from SUITE_PATHS.
$listing = Invoke-GodotCapture -Arguments @("--headless", "--path", ".", "--script", $runner, "--", "--list") -Label "list"
if ($listing.ExitCode -ne 0) {
    Write-ErrorOutput -Path $listing.Stderr
    throw "listing suites failed with exit code $($listing.ExitCode)"
}
$allSuites = @(Get-Content -Path $listing.Stdout | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -match '^test_[A-Za-z0-9_]+$' })
if ($allSuites.Count -eq 0) {
    throw "the test runner returned no suites; check $runner"
}

Get-ChildItem -Path $cacheDir -Filter "shard*.log" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $cacheDir -Filter "timings_*.json" -ErrorAction SilentlyContinue | Remove-Item -Force
$timingsCache = Join-Path $project ".godot/test_suite_timings.json"

# Load last run's suite timings so the split is cost-aware instead of count-aware.
$weights = @{}
if (Test-Path $timingsCache) {
    try {
        $cached = Get-Content -Path $timingsCache -Raw | ConvertFrom-Json
        foreach ($property in $cached.PSObject.Properties) {
            $weights[$property.Name] = [double]$property.Value
        }
    } catch {
        Write-Warning "ignoring unreadable timing cache: $_"
    }
}
$defaultWeight = 750.0
if ($weights.Count -gt 0) {
    $defaultWeight = [double]($weights.Values | Measure-Object -Average).Average
}

# Longest-processing-time-first: sort by known cost and always fill the least loaded
# shard. With no cache every suite has the same weight, which degenerates to a
# round-robin split by declaration order.
$plans = @{}
$loads = @{}
for ($index = 0; $index -lt $Shards; $index++) {
    $plans[$index] = @()
    $loads[$index] = 0.0
}
$ordered = @($allSuites | Sort-Object -Descending -Property {
    if ($weights.ContainsKey($_)) { [double]$weights[$_] } else { $defaultWeight }
})
foreach ($name in $ordered) {
    $target = 0
    for ($index = 1; $index -lt $Shards; $index++) {
        if ($loads[$index] -lt $loads[$target]) { $target = $index }
    }
    $plans[$target] = @($plans[$target]) + $name
    $weight = if ($weights.ContainsKey($name)) { [double]$weights[$name] } else { $defaultWeight }
    $loads[$target] = $loads[$target] + $weight
}

$planText = (0..($Shards - 1) | ForEach-Object { "{0}:{1}" -f ($_ + 1), $plans[$_].Count }) -join "  "
if ($weights.Count -gt 0) {
    Write-Host ("Running {0} suites in {1} balanced shards ({2})" -f $allSuites.Count, $Shards, $planText)
} else {
    Write-Host ("Running {0} suites in {1} shards ({2}); no timing cache yet, split by declaration order and self-tunes next run" -f $allSuites.Count, $Shards, $planText)
}

$shardRuns = @()
for ($index = 0; $index -lt $Shards; $index++) {
    $names = @($plans[$index])
    if ($names.Count -eq 0) { continue }
    $stdout = Join-Path $cacheDir ("shard{0}.out.log" -f $index)
    $stderr = Join-Path $cacheDir ("shard{0}.err.log" -f $index)
    $timingsRelative = "res://.godot/test_shards/timings_{0}.json" -f $index
    $arguments = @(
        "--headless",
        "--path", ".",
        "--script", $runner,
        "--",
        "--suites=$($names -join ',')",
        "--timings=$timingsRelative"
    )
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WorkingDirectory $project `
        -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $shardRuns += [pscustomobject]@{
        Index = $index
        Process = $process
        Stdout = $stdout
        Stderr = $stderr
        Timings = (Join-Path $cacheDir ("timings_{0}.json" -f $index))
    }
}

# The Steam build detaches from Start-Process, so ExitCode is not reliable without
# -Wait (which would serialise the shards). Success is decided by the runner's own
# `Tests:` summary, and a shard that dies early is caught as a missing summary.
$wall = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($shard in $shardRuns) {
    $shard.Process.WaitForExit()
}
$wall.Stop()

$passed = 0
$failed = 0
$totalCount = 0
$internalMs = 0
$reported = @{}
foreach ($shard in $shardRuns) {
    Write-Host ""
    Write-Host ("===== shard {0}/{1} =====" -f ($shard.Index + 1), $Shards)
    if (Test-Path $shard.Stdout) {
        $keepFailureDetail = $false
        foreach ($line in (Get-Content -Path $shard.Stdout)) {
            if ($line -match '^\[(FAIL|SUITE|SHARD)\]|^Tests:') {
                Write-Host $line
                $keepFailureDetail = ($line -match '^\[FAIL\]')
                if ($line -match '^Tests: (\d+) passed, (\d+) failed, (\d+) total in (\d+)ms') {
                    $passed += [int]$Matches[1]
                    $failed += [int]$Matches[2]
                    $totalCount += [int]$Matches[3]
                    $internalMs += [int]$Matches[4]
                    $reported[$shard.Index] = $true
                }
                continue
            }
            if ($line -match '^\s') {
                if ($keepFailureDetail) { Write-Host $line }
                continue
            }
            $keepFailureDetail = $false
            if (-not $Summary) { Write-Host $line }
        }
    }
    Write-ErrorOutput -Path $shard.Stderr
}

foreach ($shard in $shardRuns) {
    if (-not $reported.ContainsKey($shard.Index)) {
        Write-Host ""
        Write-Host ("[FAIL] shard {0}/{1} exited without a Tests summary" -f ($shard.Index + 1), $Shards)
        $failed += 1
    }
}

# Refresh the timing cache from every shard that produced timings.
$merged = @{}
foreach ($shard in $shardRuns) {
    if (-not (Test-Path $shard.Timings)) { continue }
    try {
        $payload = Get-Content -Path $shard.Timings -Raw | ConvertFrom-Json
        foreach ($property in $payload.suites.PSObject.Properties) {
            $merged[$property.Name] = [double]$property.Value
        }
    } catch {
        Write-Warning ("ignoring unreadable timings from shard {0}: {1}" -f ($shard.Index + 1), $_)
    }
}
if ($merged.Count -gt 0) {
    $entries = @()
    foreach ($name in ($merged.Keys | Sort-Object)) {
        $entries += ('  "{0}": {1}' -f $name, [Math]::Round($merged[$name], 1))
    }
    Set-Content -Path $timingsCache -Value ("{`n" + ($entries -join ",`n") + "`n}`n") -Encoding UTF8
}

$wallSeconds = [Math]::Round($wall.Elapsed.TotalSeconds, 1)
Write-Host ""
Write-Host ("Tests: {0} passed, {1} failed, {2} total in {3}ms" -f $passed, $failed, $totalCount, $internalMs)
Write-Host ("Wall time: {0}s with {1} shards" -f $wallSeconds, $Shards)

if ($failed -gt 0) { exit 1 }
exit 0
