# `framework/services/settings_service.gd`

> 作用：持久化 UI/玩家设置（语言、自动存档、游玩数据上传），负责读取仓库默认 `config/config.json`、写用户配置并在发布版使用 exe 旁的 `config/config.json`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SettingsService` | L1 |
| `DEFAULT_PATH` | L20 |
| `USER_PATH` | L21 |
| `EXE_CONFIG_PATH` | L22 |
| `VALID_LOCALES` | L23 |
| `_init(user_path_override: String = "", default_path_override: String = "") -> void` | L31 |
| `load_settings(user_path_override: String = "", default_path_override: String = "") -> SettingsService` | L36 |
| `load() -> void` | L66 |
| `locale() -> String` | L96 |
| `autosave() -> bool` | L100 |
| `telemetry() -> bool` | L104 |
| `telemetry_endpoint() -> String` | L108 |
| `telemetry_token() -> String` | L112 |
| `set_locale(value: String) -> void` | L116 |
| `set_autosave(value: bool) -> void` | L121 |
| `set_telemetry(value: bool) -> void` | L125 |
| `set_telemetry_endpoint(value: String) -> void` | L129 |
| `set_telemetry_token(value: String) -> void` | L133 |
| `save() -> Dictionary` | L137 |

- 关键依赖：`JsonUtils`（解析/canonical 序列化）、`Result`（结构化失败）、`TelemetryService`（endpoint 规范化）

## 契约与约束
- `docs/design/TELEMETRY.md` §2：`telemetry` 默认 `false`；`telemetry_endpoint` 空/非法时回退 `TelemetryService.DEFAULT_ENDPOINT`；`telemetry_token` 默认空串、非空时随请求发送 `X-SN-Telemetry-Token`。
- 读设置：优先用户配置，其次发布版 exe 旁配置，最后 `res://config/config.json`；写入失败（目录只读）时发布版回退 `user://config/config.json`，设置不丢。
- `load()` 之后所有字段都经过 `_normalize()`，旧配置缺少 telemetry 键时补默认值而不是报错。

## 重点逻辑
### `_normalize()`
- 语言只接受 `zh_CN` / `en`；autosave / telemetry 强制 bool；endpoint 走 `TelemetryService.normalize_endpoint`（空串、非 http(s)、无 host 都回退默认地址）。
### `save()`
- 以 canonical JSON + 缩进写盘；只有发布版且原路径不可写时才切到 user 目录。

模块索引：[framework/services](./README.md)
