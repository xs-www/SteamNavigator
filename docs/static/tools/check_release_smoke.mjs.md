# `tools/check_release_smoke.mjs`

> 作用：解压最终发布 ZIP，在本机原生运行包内 Windows/Linux 可执行文件，验证真实主菜单启动。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAX_OUTPUT_BYTES` | L21 |
| `ENGINE_TEARDOWN_NOISE` | L27 |
| `isFatalStartupError(line)` | L30 |
| `parseArguments(args)` | L34 |
| `isolatedEnvironment(directory, inherited = process.env)` | L55 |
| `runProcess(command, args, { cwd, env, timeoutMs = 60_000 } = {})` | L73 |
| `verifyStartup(result)` | L105 |
| `extractArchive(archive, destination)` | L119 |
| `checkReleaseSmoke({ archive, platform, timeoutMs = 60_000 })` | L134 |

## 用法与门禁
- `node tools/check_release_smoke.mjs --archive <zip> --platform windows|linux [--timeout-ms 60000]`。
- 使用独立临时目录解压；APPDATA/LOCALAPPDATA/HOME/XDG_* 指向临时用户目录，避免读取玩家配置/模组/存档。
- 不传 `--path` 或 `--script`：必须使用可执行文件内嵌的 PCK、真实 Autoload/main.tscn 和旁边的 mods/。
- `--release-smoke` 让 Shell 检查启动报告与主菜单树后走真实退出路径；超时、非零退出、
  SCRIPT ERROR / 其他 ERROR（`ERROR: N resources still in use at exit` 这类引擎退出期资源计数除外）、
  缺少 `[release-smoke] main-menu-ready` 中任一条件都失败，避免 Godot 脚本加载失败仍返回 0 的漏报。
- Windows 用 PowerShell Expand-Archive，Linux 用 unzip；只在与包相同的平台运行。临时文件始终清理。

模块索引：[tools](./README.md)
