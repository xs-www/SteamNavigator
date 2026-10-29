# `framework/services/update_applier.gd`

> 作用：安装目录侧的更新落地。启动时（Bootstrap 扫描模组前）清理上一次自替换留下的旧 exe、应用 `user://updates/pending` 里已校验的 core 包，并重写 `config/install.json`；更新器下载完成后的 exe 自替换也复用这里的文件操作。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UpdateApplier` | L1 |
| `PENDING_ROOT` | L22 |
| `APPLY_FILE` | L23 |
| `INSTALL_FILE` | L24 |
| `INSTALL_SCHEMA` | L25 |
| `CORE_SUFFIX` | L26 |
| `BACKUP_SUFFIX` | L27 |
| `EXE_NAME` | L28 |
| `EXE_BACKUP` | L29 |
| `HEX64` | L30 |
| `default_exe_dir() -> String` | L33 |
| `install_path(exe_dir: String) -> String` | L40 |
| `apply_pending(exe_dir: String = "", pending_root: String = "") -> Dictionary` | L45 |
| `validate_pending(payload: Dictionary, pending_root: String = PENDING_ROOT) -> String` | L105 |
| `swap_engine(staged_exe: String, exe_path: String) -> Dictionary` | L128 |
| `stage_content(core_source: String, payload: Dictionary, pending_root: String = PENDING_ROOT) -> Dictionary` | L147 |
| `read_install(path: String) -> Dictionary` | L180 |
| `file_size(path: String) -> int` | L195 |
| `is_hex64(value: String) -> bool` | L204 |
| `is_utc_timestamp(value: String) -> bool` | L213 |
| `timestamp_value(value: String) -> int` | L222 |
| `iso_now() -> String` | L229 |

- 关键依赖：`JsonUtils`、`FileAccess` / `DirAccess`、`OS.get_executable_path()`

## 契约与约束
- 只由发布版启动链（`AppBootstrap`）或 `UpdateService` 调用；编辑器与 `--script` 测试不自动应用。
- 允许写入的安装目录路径只有：`SteamNavigator.exe`（改名/备份）、`mods/core-*.snavmod.zip`、`config/install.json`。
- pending 格式见 `docs/design/AUTO_UPDATE.md` §5：`apply.json` + 已校验的 core zip；core 文件必须位于 pending 根目录内，SHA-256 与大小必须与清单一致，校验失败绝不覆盖旧 core。
- 应用顺序：备份旧 core → 写新 core 并复验 → 写 install.json → 删除 pending。任何一步失败都回滚旧 core。
- `SteamNavigator.exe.old` 是自替换备份：新进程启动后删掉，它不在任何扫描路径里。

## 重点逻辑
### `apply_pending(exe_dir, pending_root)`
- 默认参数在生产使用 exe 目录与 `user://updates/pending`；测试传临时目录。返回 `{ok, applied, error, tag}`，不抛异常。
### `swap_engine(staged_exe, exe_path)`
- Windows 允许重命名正在运行的 exe（已实测）。先备份成 `.old`，再复制新 exe；复制失败时把 `.old` 改回，保证不出现“exe 缺失”状态。

模块索引：[framework/services](./README.md)
