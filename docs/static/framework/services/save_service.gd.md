# `framework/services/save_service.gd`

> 作用：JSON 存档槽：模组头、状态、临时文件校验后替换、兼容性检查。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SaveService` | L1 |
| `_init(logger: AppLogger = null, save_directory: String = "user://saves") -> void` | L18 |
| `ensure_directory() -> bool` | L24 |
| `save_slot(slot: String, state: GameState, meta: Dictionary = {}) -> Dictionary` | L31 |
| `load_slot(slot: String) -> Dictionary` | L57 |
| `autosave(state: GameState, meta: Dictionary = {}) -> Dictionary` | L102 |
| `save_pre_voyage(state: GameState, meta: Dictionary = {}) -> Dictionary` | L106 |
| `load_autosave() -> Dictionary` | L110 |
| `load_pre_voyage() -> Dictionary` | L114 |
| `has_slot(slot: String) -> bool` | L118 |
| `delete_slot(slot: String) -> bool` | L122 |
| `list_slots() -> PackedStringArray` | L128 |
| `read_header(slot: String) -> Dictionary` | L140 |
| `validate_mods(header: Dictionary, current_mods: Array) -> Dictionary` | L147 |

## 契约与约束

- 存档头记录 save_schema/framework_version/mod_api_version/seed/mods/meta。
- 写入 `.tmp` 并重新解析校验；旧文件先改名为 `.bak`，最终替换失败会回滚。
- 槽位名限制 `^[a-z][a-z0-9_]{1,31}$`；自动存档与出航前快照为独立槽。
- 缺失存档所需模组拒绝加载；版本/哈希漂移只警告。

## 重点逻辑

### `load_slot(slot)`

- 拒绝非 1.x save_schema、非对象根与缺失 state 的文件。
- 返回 GameState、header 与 meta；调用方负责模组兼容性校验。

模块索引：[framework/services](./README.md)
