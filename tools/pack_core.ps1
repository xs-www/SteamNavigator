param(
    [string]$Godot = $env:GODOT_BIN,
    [string]$Source = "dev_mods/core",
    [string]$Out = "dist/mods"
)

$ErrorActionPreference = "Stop"
if (-not $Godot) {
    $Godot = (Get-Command godot -ErrorAction SilentlyContinue).Source
}
if (-not $Godot) {
    throw "Set GODOT_BIN to the Godot 4.x executable, or add godot to PATH."
}

$project = Split-Path -Parent $PSScriptRoot
& $Godot --headless --path $project --script res://sdk/pack_mod.gd -- "--source=$Source" "--out=$Out"
exit $LASTEXITCODE
