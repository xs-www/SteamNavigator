# `framework/tests/cases/test_schema_v2_weapons.gd`

> 作用：Content Schema 2.0 运行时武器类型（`weapons`，D1 起 active）与船体安装点镜像

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WEAPON_SCHEMA` | L20 |
| `HULL_SCHEMA` | L21 |
| `CONTENT_TYPES` | L22 |
| `CORE_HULLS` | L23 |
| `test_weapon_v2_schema_accepts_direct_weapon() -> void` | L228 |
| `test_weapon_v2_schema_accepts_broadside_multi_mount_weapon() -> void` | L234 |
| `test_weapon_v2_schema_rejects_missing_required_and_enum_errors() -> void` | L241 |
| `test_weapon_v2_schema_rejects_out_of_range_and_pattern_errors() -> void` | L269 |
| `test_weapon_v2_schema_rejects_wrong_envelope() -> void` | L319 |
| `test_weapon_type_matches_schema() -> void` | L334 |
| `test_weapon_type_is_active_runtime() -> void` | L374 |
| `test_hull_schema_accepts_socket_mirror_fields() -> void` | L385 |
| `test_hull_schema_rejects_invalid_socket_entries() -> void` | L390 |
| `test_hull_schema_accepts_legacy_content_without_sockets() -> void` | L440 |
| `test_core_hull_socket_mirrors_are_schema_valid() -> void` | L448 |

（hull_data 的 `weapon_sockets` / `rig_sockets`）测试：SchemaValidator 合法 / 非法
文件、运行时类型登记（content_types.json / ContentTypes）与 Core 船体镜像回归。

## 契约与约束
- `schemas/v2/weapon.schema.json`：战斗字段对齐 SNBattleSim（direct / artillery /
  broadside），装配字段对齐 WEAPON_SOCKET_CONTRACT；合法 direct 与
  broadside + yaw_pitch_multi 定义零错误，缺必填 / 越界 / 非法枚举 / 非法颜色 /
  非法材料 ID 必须报错。
- `weapons` 自 Phase D1 起是 active 2.0 运行时类型：在 `content_types.json.types`、
  `ContentTypes.all() / registry_types()` 中，`ContentTypes.schema_path()` 指向 v2
  weapon schema；不再登记 `draft_schemas` / `draft_types` / `planned`。
- `schemas/v2/hull.schema.json`（hulls 2.0）的 socket 镜像字段非法（class / kind /
  缺失 name / 越界 clearance / position 长度错误）必须被拒；不含 socket 字段的 hull
  内容保持合法；Core 已回填的 14 个 weapon socket + 22 个 rig socket 必须通过校验。

模块索引：[framework/tests](../README.md)
