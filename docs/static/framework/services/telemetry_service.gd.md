# `framework/services/telemetry_service.gd`

> 作用：游玩数据（telemetry）会话的纯逻辑服务：记录命令/白名单事件/WARN+ 日志、按契约裁剪、生成 `sn.telemetry.session/1` 载荷并读写 `user://telemetry/pending/` 待上传队列；不依赖 SceneTree / HTTP。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TelemetryService` | L1 |
| `SCHEMA` | L35 |
| `DEFAULT_ENDPOINT` | L37 |
| `PENDING_DIR` | L38 |
| `MAX_PENDING_FILES` | L39 |
| `MAX_PENDING_BYTES` | L40 |
| `MAX_COMMANDS` | L41 |
| `MAX_EVENTS` | L42 |
| `MAX_ERRORS` | L43 |
| `MAX_STRING_LENGTH` | L44 |
| `MAX_NAME_LENGTH` | L45 |
| `MAX_COMMAND_PARAMS` | L47 |
| `PARAM_ALLOWLIST` | L50 |
| `SESSION_ID_PATTERN` | L59 |
| `EVENT_PREFIXES` | L61 |
| `_init(pending_dir_override: String = "") -> void` | L86 |
| `is_valid_endpoint(url: String) -> bool` | L90 |
| `normalize_endpoint(raw: String) -> String` | L110 |
| `is_whitelisted_event(event_type: String) -> bool` | L115 |
| `is_enabled() -> bool` | L125 |
| `is_recording() -> bool` | L129 |
| `set_enabled(value: bool) -> void` | L134 |
| `begin_session(meta_override: Dictionary = {}) -> Dictionary` | L141 |
| `record_command(command: String, ok: bool, error_code: String = "", duration_ms: int = 0, game_time: float = 0.0, params: Dictionary = {}) -> void` | L156 |
| `sanitize_command_params(params: Dictionary) -> Dictionary` | L180 |
| `record_event(event: Dictionary) -> void` | L204 |
| `capture_errors(entries: Array) -> void` | L223 |
| `finalize_session(summary: Dictionary = {}, logger: AppLogger = null) -> Dictionary` | L239 |
| `build_payload(summary: Dictionary = {}) -> Dictionary` | L251 |
| `serialize_with_budget(payload: Dictionary) -> Dictionary` | L281 |
| `pending_files() -> PackedStringArray` | L302 |
| `pending_count() -> int` | L321 |
| `discard_pending() -> int` | L326 |

- 关键依赖：`JsonUtils`（canonical JSON）、`AppLogger`（收尾快照 WARN/ERROR/FATAL）、`FrameworkInfo`（版本基线）

## 契约与约束
- 唯一契约是 `docs/design/TELEMETRY.md` §1-§3、§6：schema、文件名、上限、默认值与隐私红线不得在本文件自行变更。
- 默认关闭（opt-in）：`enabled` 为假时 `begin_session` / `record_*` / `finalize_session` 全部 no-op，且不创建任何文件（验收 §6.2）。
- `set_enabled(false)` = 停止记录 + 丢弃当前会话缓冲 + 删除 `pending_dir` 下全部文件（§2）。
- 隐私：只记录白名单事件前缀（`voyage.` / `port.` / `contract.` / `combat.` / `story.` / `quest.` / `market.` / `run.`），字符串字段 ≤300 字符、命令/事件名 ≤80（§1、§3.3）。
- 命令参数只上传 `PARAM_ALLOWLIST` 白名单键的标量值（内容 ID / 数量 / 时长等），嵌套对象、自由文本字段与 `data` 一律丢弃；字符串值 ≤80、最多 8 个键（§3.4）。
- 缓冲上限 commands 300 / events 150 / errors 40，超出丢最旧；单文件 ≤512 KiB，超限先裁剪命令/事件再写；队列 ≤20 个 pending 文件，超出丢最旧（§3.4、§3.6）。
- 时间用 ISO-8601 UTC（`...Z`），序列化只用 `JsonUtils.canonical_stringify`（UTF-8、无 BOM）；`session_id` 必须匹配 `^[A-Za-z0-9_-]{8,64}$`（服务端按它做文件名，防路径穿越）。

## 重点逻辑
### `begin_session(meta)`
- 关闭时直接返回失败；开启时重置缓冲并生成 `${UTC 时间}-${8 位十六进制}` 的 session id，`is_recording()` 从此为真直到 `finalize_session`。
### `record_command(command, ok, error_code, duration_ms, game_time, params)`
- CommandBus 每条命令一条记录；`params` 经 `sanitize_command_params()` 过滤后才写入 `params` 字段（无白名单参数时不写该字段）。
### `sanitize_command_params(params)`
- 纯函数：按 `PARAM_ALLOWLIST` 只保留标量（String/StringName/Bool/Int/Float），嵌套对象/数组与其他类型丢弃；字符串按 `MAX_NAME_LENGTH` 截断，最多 `MAX_COMMAND_PARAMS` 个键。
### `record_event(event)`
- 只接受 §3 白名单前缀的领域事件；payload 递归截断后再入缓冲，UI / 框架内部事件不会上传。
### `finalize_session(summary, logger)`
- 结束计时、快照 `logger` 的 WARN/ERROR/FATAL、生成载荷并写入 pending；`run.commands` / `run.failed_commands` 是本局计数（不受列表裁剪影响）。
### `serialize_with_budget(payload)`
- 纯函数：按单文件 512 KiB 预算序列化载荷，超限时先丢最旧命令、再丢最旧事件/错误；返回 `{ok, error, text, bytes, trimmed}`，finalize 与测试共用。
### `_trim_pending_queue(keep_path)`
- pending 文件名以 UTC 时间戳开头，按文件名升序即先进先出；写入后超过 20 个就删最旧的（§3.6）。

模块索引：[framework/services](./README.md)
