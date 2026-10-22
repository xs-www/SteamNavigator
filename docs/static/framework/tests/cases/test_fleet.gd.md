# `framework/tests/cases/test_fleet.gd`

> 作用：Phase D2 舰队运行时的回归测试：`data.fleet` 惰性结构、旗舰与当前单船衔接、

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `STEADY` | L15 |
| `test_commands_and_query_are_registered() -> void` | L75 |
| `test_view_is_lazy_and_links_the_flagship_to_the_current_ship() -> void` | L85 |
| `test_assign_captain_validates_references_and_uniqueness() -> void` | L107 |
| `test_captain_must_command_the_ship_archetype() -> void` | L133 |
| `test_set_formation_assigns_slots_and_rejects_conflicts() -> void` | L145 |
| `test_set_doctrine_validates_and_reports() -> void` | L184 |
| `test_add_remove_ships_and_capacity() -> void` | L205 |
| `test_commands_publish_fleet_events() -> void` | L231 |
| `test_save_round_trip_and_legacy_lazy_state() -> void` | L256 |
| `test_same_seed_and_commands_are_deterministic() -> void` | L294 |

`fleet.view` 形状、captain 指派/可指挥船型/唯一性、formation 与 slot 校验、
doctrine 选择、增删舰与容量、领域事件、存档 round-trip、旧档惰性补齐、确定性。

## 契约与约束
- 内容从 Core 注册表动态选取（ship_archetypes / captains / formations /
  fleet_doctrines），不写死 core:* 内容 id 到断言里。
- 旗舰永远等于当前 `data.ship`（archetype 由 hull_ref 反查），fleet 不复制 ship
  的模块/耐久状态；测试用 `state.ship().hull_id` 对照。
- 所有写操作走 `fleet.*` 命令（CommandBus 事务）；失败命令不得提交状态。

模块索引：[framework/tests](../README.md)
