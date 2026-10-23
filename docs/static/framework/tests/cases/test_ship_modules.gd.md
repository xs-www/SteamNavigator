# `framework/tests/cases/test_ship_modules.gd`

> 作用：模块实例层测试：实例创建/补齐、condition 夹取与失效、安装替换重置状态、货舱对齐、damage_module 操作码、维修报价与存档往返。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_new_run_creates_module_instances() -> void` | L32 |
| `test_legacy_ship_is_backfilled() -> void` | L50 |
| `test_damage_and_repair_conditions() -> void` | L62 |
| `test_cargo_instances_stay_aligned() -> void` | L81 |
| `test_install_slot_resets_condition() -> void` | L95 |
| `test_damage_module_effect_opcode() -> void` | L106 |
| `test_repair_cost_includes_module_damage() -> void` | L129 |
| `test_condition_changes_performance_and_repair_restores_it() -> void` | L144 |
| `test_shipyard_weapon_purchase_uninstall_and_warehouse_reinstall() -> void` | L167 |
| `test_hull_replacement_returns_incompatible_weapons_to_port_storage() -> void` | L207 |
| `test_conditions_survive_save_load() -> void` | L232 |

## 契约与约束

- 新局每个已装模块都有唯一 instance_id 与满 condition；serial 覆盖全部实例。
- 旧版 ship（只有扁平槽位键）调用 ensure 后补齐实例，重复 ensure 不改变 id 与 serial。
- damage 按比例扣减、0 处夹取并只在首次归零报告 newly_disabled；repair_all 恢复满状态并返回修复数；空/非法槽位返回结构化错误。
- 货舱实例与扁平列表逐位对齐：追加补新实例、按位置删除保留幸存实例 id。
- 单槽替换生成满状态新实例；damage_module 效果发布 ship.module_damaged，hull 不是合法槽位。
- 维修报价把模块损耗折算成点数并抬高 cost，不伪造船体缺失；save/load 后 condition 与 instance_id 哈希一致。

模块索引：[framework/tests](../README.md)
