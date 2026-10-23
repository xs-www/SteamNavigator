# `framework/tests/cases/test_combat.gd`

> 作用：Phase D1-B 战斗自动结算测试。用最小合成 RegistryHub（武器 / 伤害类型 / 能力 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `HULL_SINGLE` | L25 |
| `HULL_DUAL` | L26 |
| `HULL_GUNNER` | L27 |
| `HULL_TOWER` | L28 |
| `WEAPON_LIGHT` | L29 |
| `WEAPON_PIERCER` | L30 |
| `WEAPON_BURNER` | L31 |
| `WEAPON_PLAIN_BURNER` | L32 |
| `WEAPON_MEDIUM` | L33 |
| `WEAPON_CRUSHER` | L34 |
| `WEAPON_HEAVY_BURST` | L35 |
| `ENEMY_WEAK` | L36 |
| `ENEMY_ARMORED` | L37 |
| `ENEMY_FLEEING` | L38 |
| `ENEMY_GUNSHIP` | L39 |
| `ENEMY_CRUSHER` | L40 |
| `ENEMY_TANK` | L41 |
| `ENEMY_LOOTBAG` | L42 |
| `ENEMY_ARMORY` | L43 |
| `ENEMY_BAD_LOOT` | L44 |
| `ENCOUNTER_SCRAP` | L45 |
| `ENCOUNTER_ARMORED` | L46 |
| `ENCOUNTER_FLEEING` | L47 |
| `ENCOUNTER_GUNSHIP` | L48 |
| `ENCOUNTER_CRUSHER` | L49 |
| `ENCOUNTER_TANK` | L50 |
| `LOOT_SCRAP` | L51 |
| `LOOT_MODULE` | L52 |
| `LOOT_WEAPON` | L53 |
| `PORT_ID` | L54 |
| `ITEM_SCRAP` | L55 |
| `MODULE_CRATE` | L56 |
| `test_resolve_victory_applies_loot_and_durability() -> void` | L296 |
| `test_same_seed_is_deterministic() -> void` | L322 |
| `test_armor_and_damage_type_pierce() -> void` | L336 |
| `test_status_effect_adds_damage_over_time() -> void` | L355 |
| `test_player_retreats_below_threshold() -> void` | L374 |
| `test_player_defeat_sets_minimum_durability() -> void` | L388 |
| `test_enemy_retreat_gives_no_loot() -> void` | L400 |
| `test_loot_modules_and_weapon_salvage_apply() -> void` | L412 |
| `test_old_state_queries_are_read_only_and_command_creates_block() -> void` | L437 |
| `test_command_errors_are_structured() -> void` | L457 |
| `test_player_weapon_rows_from_hull_sockets() -> void` | L471 |
| `test_multi_enemy_encounter_targets_sequentially() -> void` | L487 |
| `test_battle_record_is_save_safe() -> void` | L510 |
| `test_core_content_resolves() -> void` | L530 |
| `test_combat_commands_and_queries_are_registered() -> void` | L549 |
| `test_missing_weapon_class_is_reported_for_both_sides() -> void` | L588 |
| `test_missing_loot_table_is_reported_in_battle_diagnostics() -> void` | L618 |
| `test_explicit_loadout_enforces_socket_class() -> void` | L636 |
| `test_settlement_key_makes_resolve_idempotent() -> void` | L659 |
| `test_settlement_keys_are_pruned_with_the_battle_log() -> void` | L695 |
| `test_combat_stream_is_registered() -> void` | L709 |

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
- **D1-FIX2**：显式 `weapon_loadout` 受 socket class 门禁（不匹配 `weapon_class_mismatch`
  且不回退默认武器）；`combat.resolve` 的可选 `encounter_id` 是结算幂等键，重复调用
  返回 `already_settled` 且不发奖/不追加/不发事件；`RngService.STREAM_NAMES` 含 combat。

模块索引：[framework/tests](../README.md)
