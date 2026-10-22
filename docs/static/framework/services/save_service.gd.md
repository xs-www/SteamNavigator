# `framework/services/save_service.gd`

> 作用：JSON 存档槽：模组/框架头、状态克隆与内容版本快照、临时文件校验后替换、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SaveService` | L1 |
| `SAVE_SCHEMA` | L22 |
| `SAVE_SCHEMA_MAJOR` | L23 |
| `AUTOSAVE_SLOT` | L25 |
| `PRE_VOYAGE_SLOT` | L26 |
| `_init(logger: AppLogger = null, save_directory: String = "user://saves") -> void` | L33 |
| `ensure_directory() -> bool` | L39 |
| `save_slot(slot: String, state: GameState, meta: Dictionary = {}) -> Dictionary` | L46 |
| `load_slot(slot: String) -> Dictionary` | L79 |
| `autosave(state: GameState, meta: Dictionary = {}) -> Dictionary` | L132 |
| `save_pre_voyage(state: GameState, meta: Dictionary = {}) -> Dictionary` | L136 |
| `load_autosave() -> Dictionary` | L140 |
| `load_pre_voyage() -> Dictionary` | L144 |
| `has_slot(slot: String) -> bool` | L148 |
| `delete_slot(slot: String) -> bool` | L152 |
| `list_slots() -> PackedStringArray` | L158 |
| `read_header(slot: String) -> Dictionary` | L170 |
| `validate_mods(header: Dictionary, current_mods: Array) -> Dictionary` | L177 |

旧档加载迁移入口与存档/模组兼容性检查。

## 契约与约束
- 头字段 `save_schema/state_schema` 2.0、`content_schema` 继续写基线 1.0（D3）；
  类型级版本在 `state.campaign.setup.content_versions`。
- 保存前不修改实时状态：克隆状态并 `ShipModules.ensure()`；B5 起克隆上再调用
  `SaveMigrations.prepare_for_save()` 快照当前 `ContentTypes.SCHEMA_VERSIONS`。
- 加载统一走 `SaveMigrations.migrate()`；迁移/漂移 warnings 通过
  `migration_warnings` 返回，存档仍可读（不重排世界）。
- 写入 `.tmp` 并重新解析校验；旧文件先改名为 `.bak`，最终替换失败会回滚。
- 槽位名限制 `^[a-z][a-z0-9_]{1,31}$`；缺失所需模组拒绝加载，版本/哈希漂移只警告。

模块索引：[framework/services](./README.md)
