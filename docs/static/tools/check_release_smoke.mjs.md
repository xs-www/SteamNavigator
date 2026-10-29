# `tools/check_release_smoke.mjs`

> 作用：解压最终发布 ZIP，在本机原生运行包内 Windows/Linux 可执行文件，验证真实主菜单启动。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAX_OUTPUT_BYTES` | L25 |
| `ENGINE_TEARDOWN_NOISE` | L31 |
| `isFatalStartupError(line)` | L34 |
| `parseArguments(args)` | L38 |
| `isolatedEnvironment(directory, inherited = process.env)` | L59 |
| `runProcess(command, args, { cwd, env, timeoutMs = 60_000 } = {})` | L77 |
| `verifyStartup(result)` | L109 |
| `extractArchive(archive, destination)` | L123 |
| `fileSha256(filePath)` | L138 |
| `verifyInstallMetadata(directory, executablePath, platform)` | L149 |
| `checkReleaseSmoke({ archive, platform, timeoutMs = 60_000 })` | L175 |

## 用法与门禁
- `node tools/check_release_smoke.mjs --archive <zip> --platform windows|linux [--timeout-ms 60000]`。
- 使用独立临时目录解压；APPDATA/LOCALAPPDATA/HOME/XDG_* 指向临时用户目录，避免读取玩家配置/模组/存档。
- 不传 `--path` 或 `--script`：必须使用可执行文件内嵌的 PCK、真实 Autoload/main.tscn 和旁边的 mods/。
- `--release-smoke` 让 Shell 检查启动报告与主菜单树后走真实退出路径；超时、非零退出、
  SCRIPT ERROR / 其他 ERROR（`ERROR: N resources still in use at exit` 这类引擎退出期资源计数除外）、
  缺少 `[release-smoke] main-menu-ready` 中任一条件都失败，避免 Godot 脚本加载失败仍返回 0 的漏报。
- Windows 用 PowerShell Expand-Archive，Linux 用 unzip；只在与包相同的平台运行。临时文件始终清理。
- 同时校验 `config/install.json`（schema=1/tag、engine/core SHA-256 与包内实际文件一致）：游戏内更新器
  以它为本地版本依据，元数据错位会导致重复下载或漏更新。

模块索引：[tools](./README.md)
