# `framework/tests/cases/test_combat.gd`

> 作用：Phase D1-B 战斗自动结算测试。用最小合成 RegistryHub（武器 / 伤害类型 / 能力 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `HULL_SINGLE` | L22 |
| `HULL_DUAL` | L23 |
| `HULL_GUNNER` | L24 |
| `HULL_TOWER` | L25 |
| `WEAPON_LIGHT` | L26 |
| `WEAPON_PIERCER` | L27 |
| `WEAPON_BURNER` | L28 |
| `WEAPON_PLAIN_BURNER` | L29 |
| `WEAPON_MEDIUM` | L30 |
| `WEAPON_CRUSHER` | L31 |
| `WEAPON_HEAVY_BURST` | L32 |
| `ENEMY_WEAK` | L33 |
| `ENEMY_ARMORED` | L34 |
| `ENEMY_FLEEING` | L35 |
| `ENEMY_GUNSHIP` | L36 |
| `ENEMY_CRUSHER` | L37 |
| `ENEMY_TANK` | L38 |
| `ENEMY_LOOTBAG` | L39 |
| `ENEMY_ARMORY` | L40 |
| `ENEMY_BAD_LOOT` | L41 |
| `ENCOUNTER_SCRAP` | L42 |
| `ENCOUNTER_ARMORED` | L43 |
| `ENCOUNTER_FLEEING` | L44 |
| `ENCOUNTER_GUNSHIP` | L45 |
| `ENCOUNTER_CRUSHER` | L46 |
| `ENCOUNTER_TANK` | L47 |
| `LOOT_SCRAP` | L48 |
| `LOOT_MODULE` | L49 |
| `LOOT_WEAPON` | L50 |
| `PORT_ID` | L51 |
| `ITEM_SCRAP` | L52 |
| `MODULE_CRATE` | L53 |
| `test_resolve_victory_applies_loot_and_durability() -> void` | L293 |
| `test_same_seed_is_deterministic() -> void` | L319 |
| `test_armor_and_damage_type_pierce() -> void` | L333 |
| `test_status_effect_adds_damage_over_time() -> void` | L352 |
| `test_player_retreats_below_threshold() -> void` | L371 |
| `test_player_defeat_sets_minimum_durability() -> void` | L385 |
| `test_enemy_retreat_gives_no_loot() -> void` | L397 |
| `test_loot_modules_and_weapon_salvage_apply() -> void` | L409 |
| `test_old_state_queries_are_read_only_and_command_creates_block() -> void` | L434 |
| `test_command_errors_are_structured() -> void` | L454 |
| `test_player_weapon_rows_from_hull_sockets() -> void` | L468 |
| `test_multi_enemy_encounter_targets_sequentially() -> void` | L485 |
| `test_battle_record_is_save_safe() -> void` | L508 |
| `test_core_content_resolves() -> void` | L528 |
| `test_combat_commands_and_queries_are_registered() -> void` | L547 |
| `test_missing_weapon_class_is_reported_for_both_sides() -> void` | L571 |
| `test_missing_loot_table_is_reported_in_battle_diagnostics() -> void` | L601 |

敌人原型 / 遭遇表 / 掉落表 / hull）驱动 `CombatOps`（纯规则）、`CombatService`
（落盘 / 战利品 / 惰性 `data.combat`）、`CombatCommands.resolve` 与
`CombatViewQuery` / `CombatLogQuery`，并补一条真实 core 内容的分辨率冒烟。

## 契约与约束
- **不依赖 core 内容做精确断言**：护甲 / 穿甲 / 状态 / 撤退 / 战利品数值全部用
  `test:*` 合成定义控制；真实 core 只在 `test_core_content_resolves` 里做
  「能加载、能结算、结果形状稳定」的冒烟（不锁具体随机结果）。
- **确定性**：同一 state + 同一显式 seed 两次结算的 `data` 完全相等（含日志与战利品）；
  seed 会写入 battle 记录。
- **不把持久 id/时间写进数值断言**：battle 的 `id / at_time` 由服务写入，测试只比较
  同 seed 下的完整结果（两次都在 game_time 0 / 首场，因此仍然可逐字段比较）。
- **旧档**：没有 `data.combat` 的 state 上查询不创建该块、命令结算后才惰性创建。
- **D1-FIX 诊断**：未知 weapon class 的 socket 跳过时写入 `battle.diagnostics`
  （敌我一致，side/index/socket/socket_class/reason），未知 loot_table / loot entry
  同样记录 reason；battle 仍可结算，内容层缺口由 CrossReferenceValidator 报 error。

模块索引：[framework/tests](../README.md)
