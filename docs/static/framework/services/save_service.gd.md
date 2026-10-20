# `framework/services/save_service.gd`

> 作用：JSON 存档槽：模组头、状态、临时文件校验后替换、兼容性检查与旧档迁移入口。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SaveService` | L1 |
| `SAVE_SCHEMA` | L8 |
| `SAVE_SCHEMA_MAJOR` | L9 |
| `AUTOSAVE_SLOT` | L11 |
| `PRE_VOYAGE_SLOT` | L12 |
| `_init(logger: AppLogger = null, save_directory: String = "user://saves") -> void` | L19 |
| `ensure_directory() -> bool` | L25 |
| `save_slot(slot: String, state: GameState, meta: Dictionary = {}) -> Dictionary` | L32 |
| `load_slot(slot: String) -> Dictionary` | L64 |
| `autosave(state: GameState, meta: Dictionary = {}) -> Dictionary` | L117 |
| `save_pre_voyage(state: GameState, meta: Dictionary = {}) -> Dictionary` | L121 |
| `load_autosave() -> Dictionary` | L125 |
| `load_pre_voyage() -> Dictionary` | L129 |
| `has_slot(slot: String) -> bool` | L133 |
| `delete_slot(slot: String) -> bool` | L137 |
| `list_slots() -> PackedStringArray` | L143 |
| `read_header(slot: String) -> Dictionary` | L155 |
| `validate_mods(header: Dictionary, current_mods: Array) -> Dictionary` | L162 |

## 契约与约束

- 新存档写 save_schema 2.0、state_schema 2.0 与 content_schema 1.0；写入前克隆状态并补齐 campaign，不修改实时状态。
- 写入快照与加载结果都会调用 `ShipModules.ensure()` 对齐模块实例表；旧档缺表时按满状态补齐，实例 id 与 condition 随存档往返。
- 写入 `.tmp` 并重新解析校验；旧文件先改名为 `.bak`，最终替换失败会回滚。
- 槽位名限制 `^[a-z][a-z0-9_]{1,31}$`；自动存档与出航前快照为独立槽。
- 缺失存档所需模组拒绝加载；版本/哈希漂移只警告。
- 加载时统一交给 `SaveMigrations.migrate()`；1.x 归档迁移为 2.0 并回填 campaign 元数据。

## 重点逻辑

### `load_slot(slot)`

- 解析后先迁移 save payload，再校验 state；不支持的 save_schema 返回结构化错误。
- 返回 GameState、header、meta、migrated 与 migration_warnings；调用方负责模组兼容性校验。

模块索引：[framework/services](./README.md)
