# `framework/services/update_service.gd`

> 作用：游戏内自动更新：读取网站 `/api/site/update`、比较本地安装哈希、按「只换 core 包 / 换整个 exe」两种粒度下载并校验，最后交给 `UpdateApplier` 完成文件替换。契约见 `docs/design/AUTO_UPDATE.md`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UpdateService` | L1 |
| `state_changed (signal)` | L22 |
| `restart_requested (signal)` | L23 |
| `DEFAULT_ENDPOINT` | L25 |
| `MANIFEST_SCHEMA` | L26 |
| `UPDATE_ROOT` | L27 |
| `CORE_SUFFIX` | L28 |
| `CHECK_TIMEOUT` | L29 |
| `MAX_DOWNLOAD_BYTES` | L30 |
| `RETRY_LIMIT` | L31 |
| `PHASE_IDLE` | L33 |
| `PHASE_CHECKING` | L34 |
| `PHASE_UP_TO_DATE` | L35 |
| `PHASE_AVAILABLE` | L36 |
| `PHASE_DOWNLOADING` | L37 |
| `PHASE_STAGED` | L38 |
| `PHASE_ERROR` | L39 |
| `configure(endpoint_value: String, auto: bool) -> void` | L71 |
| `snapshot() -> Dictionary` | L76 |
| `check(manual: bool = true) -> void` | L81 |
| `download() -> void` | L97 |
| `cancel() -> void` | L123 |
| `restart_game() -> void` | L130 |
| `normalize_endpoint(value: String) -> String` | L392 |
| `resolve_url(endpoint_value: String, value: String, fallback: String) -> String` | L404 |
| `parse_update_payload(payload: Variant) -> Dictionary` | L428 |
| `validate_manifest(manifest: Variant) -> Dictionary` | L462 |
| `local_state(exe_path: String, mods_dir: String, install_path: String) -> Dictionary` | L525 |
| `find_core_pack(mods_dir: String) -> String` | L544 |
| `decide(info: Dictionary, local: Dictionary) -> Dictionary` | L557 |
| `extract_package(package_path: String, staging_dir: String, windows: Dictionary) -> Dictionary` | L600 |

- 关键依赖：`HTTPRequest`、`UpdateApplier`、`JsonUtils`、`FileAccess.get_sha256`、`ZIPReader`

## 契约与约束
- 只在发布版（`OS.has_feature("template")`）真正联网；编辑器与 `--script` 测试永不发请求，静态函数可直接单测。
- 清单必须 `schema = 1`；所有下载先写 `*.part`，校验字节数与 SHA-256 通过后才改名并应用；失败保留旧安装。
- 允许写入：`user://updates/**`、`mods/core-*.snavmod.zip`（经 `UpdateApplier` 暂存）、`SteamNavigator.exe`（自替换）。
- 不做降级：远端 `published_at` 早于本地 `install.json` 时视为已是最新。
- 断网/清单异常不阻塞启动：自动检查静默失败；手动检查显示可读错误。

## 重点逻辑
### `decide(info, local)`
- engine 哈希不同 → `full`（下载平台 ZIP，解压后自替换 exe + core）；只有 core 不同 → `core`（约 40 MB）；都相同 → `none`。
### `download()`
- 优先同源镜像 URL（相对路径按 endpoint 的 origin 解析），为空时回退 GitHub；失败重试一次 fallback；`_process` 每 200 ms 发一次进度。

模块索引：[framework/services](./README.md)
