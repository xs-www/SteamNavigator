# `framework/tests/cases/test_fleet.gd`

> 作用：Phase D2 舰队运行时的回归测试：`data.fleet` 惰性结构、旗舰与当前单船衔接、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STEADY` | L20 |
| `test_commands_and_query_are_registered() -> void` | L80 |
| `test_view_is_lazy_and_links_the_flagship_to_the_current_ship() -> void` | L90 |
| `test_assign_captain_validates_references_and_uniqueness() -> void` | L112 |
| `test_captain_must_command_the_ship_archetype() -> void` | L138 |
| `test_set_formation_assigns_slots_and_rejects_conflicts() -> void` | L150 |
| `test_set_doctrine_validates_and_reports() -> void` | L195 |
| `test_add_remove_ships_and_capacity() -> void` | L216 |
| `test_commands_publish_fleet_events() -> void` | L242 |
| `test_save_round_trip_and_legacy_lazy_state() -> void` | L267 |
| `test_same_seed_and_commands_are_deterministic() -> void` | L305 |
| `test_every_core_hull_has_an_archetype_and_commandable_captain() -> void` | L334 |
| `test_max_ships_defaults_to_slot_count() -> void` | L369 |
| `test_flagship_slot_rules_and_clear_semantics() -> void` | L400 |
| `test_malformed_fleet_data_is_normalized() -> void` | L446 |
| `test_hull_swap_releases_a_captain_that_cannot_command_the_new_archetype() -> void` | L475 |
| `test_switching_formation_clears_roster_ships_from_flagship_slots() -> void` | L505 |
| `test_flagship_archetype_prefers_the_flagship_tag() -> void` | L543 |
| `test_formation_capacity_view_is_clamped_by_the_framework_cap() -> void` | L568 |

`fleet.view` 形状、captain 指派/可指挥船型/唯一性、formation 与 slot 校验、
doctrine 选择、增删舰与容量、领域事件、存档 round-trip、旧档惰性补齐、确定性。

## 契约与约束
- 内容从 Core 注册表动态选取（ship_archetypes / captains / formations /
  fleet_doctrines），不写死 core:* 内容 id 到断言里。
- 旗舰永远等于当前 `data.ship`（archetype 由 hull_ref 反查），fleet 不复制 ship
  的模块/耐久状态；测试用 `state.ship().hull_id` 对照。
- 所有写操作走 `fleet.*` 命令（CommandBus 事务）；失败命令不得提交状态。
- D2-FIX 覆盖：max_ships 缺省按 slots 数、flagship 槽位独占与自动分配跳过、
  slot/formation 清空、以及损坏 `data.fleet` 的规范化不抛引擎错误。
- D2-FIX2 覆盖：换 hull 后释放无法指挥新旗舰 archetype 的舰长；切换 formation
  清空 role 变成 `flagship` 的槽位上的非旗舰船；旗舰 tag 优先于字典序；容量
  view 与命令层同样受 MAX_SHIPS 封顶；每个 hull 最多一个 flagship tag。

模块索引：[framework/tests](../README.md)
