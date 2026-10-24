# @static-doc
# 作用：UI 皮肤一键生成 / 一致性门禁。先运行 `tools/ui/build_ui_skin.gd` 把 `docs/design/` 的控件图集与图标图集裁成 `assets/ui/skin/<skin>/` 运行纹理 + skin.json，再运行 `tools/ui/build_ui_theme.gd` 从 skin.json 生成纹理化 Theme。
#
# ## 用法
# ```powershell
# pwsh ./tools/build_ui_skin.ps1              # 重新生成 sn_v1 皮肤与 Theme
# pwsh ./tools/build_ui_skin.ps1 -Check       # 逐字节校验已提交的运行纹理/skin.json/Theme 与母版一致
# pwsh ./tools/build_ui_skin.ps1 -Skin sn_v1  # 指定皮肤 id
# ```
#
# ## 契约
# - 换肤文档：`docs/design/UI_SKIN_PIPELINE.md`。只换同名同尺寸运行贴图时不需要本脚本；改母版、九宫格参数或整套皮肤时必须运行并提交产物。
# - `-Check` 不写仓库文件，差异打印到 stderr 并以退出码 1 结束；CI / 提交前必须通过。
# - Godot 可执行文件优先级：`-GodotBin` > `$env:GODOT_BIN` > 本机 Steam 安装路径。
# - 脚本保持 ASCII-only，兼容 Windows PowerShell 5.1。
# @end-static-doc

# UI skin builder wrapper: slices the master atlases into runtime textures + skin.json,
# then regenerates the textured Theme from that manifest.
#
# This script is ASCII-only so Windows PowerShell 5.1 can parse it.
[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [string]$Skin = "sn_v1",
    [switch]$Check
)

$ErrorActionPreference = "Stop"

$defaultGodot = "C:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = $defaultGodot }
if (-not (Test-Path -LiteralPath $GodotBin)) {
    throw "Godot executable not found: $GodotBin (pass -GodotBin or set GODOT_BIN)"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$checkArg = @()
if ($Check) { $checkArg = @("--check") }

function Invoke-SkinStep {
    param(
        [string]$ScriptPath,
        [string]$Label
    )
    $stdoutPath = Join-Path $env:TEMP ("sn-skin-" + $Label + ".out.log")
    $stderrPath = Join-Path $env:TEMP ("sn-skin-" + $Label + ".err.log")
    $arguments = @("--headless", "--path", $repoRoot, "--script", $ScriptPath, "--", "--skin=$Skin") + $checkArg
    $process = Start-Process -FilePath $GodotBin -ArgumentList $arguments -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (Test-Path -LiteralPath $stdoutPath) {
        [System.IO.File]::ReadAllText($stdoutPath, [System.Text.Encoding]::UTF8) | Write-Host
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $stderrText = [System.IO.File]::ReadAllText($stderrPath, [System.Text.Encoding]::UTF8)
        if (-not [string]::IsNullOrWhiteSpace($stderrText)) { Write-Host $stderrText -ForegroundColor Yellow }
    }
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue
    return $process.ExitCode
}

Write-Host "[build_ui_skin] skin=$Skin check=$($Check.IsPresent)"
$skinExit = Invoke-SkinStep -ScriptPath "res://tools/ui/build_ui_skin.gd" -Label "atlas"
if ($skinExit -ne 0) {
    Write-Host "[build_ui_skin] skin generation/check FAILED (exit $skinExit)" -ForegroundColor Red
    exit $skinExit
}

$themeExit = Invoke-SkinStep -ScriptPath "res://tools/ui/build_ui_theme.gd" -Label "theme"
if ($themeExit -ne 0) {
    Write-Host "[build_ui_skin] theme generation/check FAILED (exit $themeExit)" -ForegroundColor Red
    exit $themeExit
}

Write-Host "[build_ui_skin] OK" -ForegroundColor Green
exit 0
