<#
.SYNOPSIS
    Capture the shipyard screen (normal / refit) with real rendering at 1440x900.

.DESCRIPTION
    Runs res://tools/ui_snapshot.gd in windowed mode (never --headless: the
    viewport texture is empty without a real renderer) with a 1440x900 window:
      - bootstraps Core exactly like framework/tests/test_case.gd;
      - run.start {build_id=core:starting_build/steady, seed=5201};
      - mounts main.tscn, switches to the shipyard screen, saves
        docs/design/screenshots/shipyard_normal.png;
      - presses the refit button to enter the cutaway, then saves
        docs/design/screenshots/shipyard_refit.png;
      - quits; exit code 0 when both captures were written and fresh, else 1.
    Godot executable resolution: -GodotBin > $env:GODOT_BIN > default local path.
    This script is ASCII-only so Windows PowerShell 5.1 can parse it.

.EXAMPLE
    .\tools\capture_ui.ps1

.EXAMPLE
    .\tools\capture_ui.ps1 -GodotBin "D:\Godot\Godot_v4.7.2-stable_win64_console.exe" -Seed 5201
#>
[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [int]$Seed = 5201,
    [string]$OutDir = "res://docs/design/screenshots",
    [string]$Categories = "cargo_modules,misc",
    [string]$Damage = "",
    [switch]$SkipRefit
)

$ErrorActionPreference = "Stop"

$defaultGodot = "C:\Users\Zhoei\AppData\Local\dsh-tools\godot\Godot_v4.7.2-stable_win64_console.exe"
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = $defaultGodot }
if (-not (Test-Path -LiteralPath $GodotBin)) {
    throw "Godot executable not found: $GodotBin (pass -GodotBin or set GODOT_BIN)"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $repoRoot ".godot-ui-snapshot.log"
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
[System.IO.File]::WriteAllText($logPath, $stdoutText + $stderrText, [System.Text.Encoding]::UTF8)
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
    # Extra per-category captures use the same short names as ui_snapshot.gd.
    foreach ($category in ($Categories -split ",")) {
        $category = $category.Trim()
        if ([string]::IsNullOrWhiteSpace($category) -or $category -eq "hulls") { continue }
        $short = switch ($category) {
            "cargo_modules" { "cargo" }
            "navigation_modules" { "navigation" }
            "safety_modules" { "safety" }
            default { $category }
        }
        $expected += "shipyard_refit_$short.png"
    }
}
# Damaged-state captures are produced only when -Damage is passed.
if (-not [string]::IsNullOrWhiteSpace($Damage)) {
    $expected += "shipyard_normal_damaged.png"
    if (-not $SkipRefit) { $expected += "shipyard_refit_damaged.png" }
    $expected += "supply_damaged.png"
}

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
