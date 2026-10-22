# `framework/tests/cases/test_combat.gd`

> 作用：Phase D1-B 战斗自动结算测试。用最小合成 RegistryHub（武器 / 伤害类型 / 能力 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `HULL_SINGLE` | L19 |
| `HULL_DUAL` | L20 |
| `HULL_GUNNER` | L21 |
| `WEAPON_LIGHT` | L22 |
| `WEAPON_PIERCER` | L23 |
| `WEAPON_BURNER` | L24 |
| `WEAPON_PLAIN_BURNER` | L25 |
| `WEAPON_MEDIUM` | L26 |
| `WEAPON_CRUSHER` | L27 |
| `WEAPON_HEAVY_BURST` | L28 |
| `ENEMY_WEAK` | L29 |
| `ENEMY_ARMORED` | L30 |
| `ENEMY_FLEEING` | L31 |
| `ENEMY_GUNSHIP` | L32 |
| `ENEMY_CRUSHER` | L33 |
| `ENEMY_TANK` | L34 |
| `ENEMY_LOOTBAG` | L35 |
| `ENEMY_ARMORY` | L36 |
| `ENCOUNTER_SCRAP` | L37 |
| `ENCOUNTER_ARMORED` | L38 |
| `ENCOUNTER_FLEEING` | L39 |
| `ENCOUNTER_GUNSHIP` | L40 |
| `ENCOUNTER_CRUSHER` | L41 |
| `ENCOUNTER_TANK` | L42 |
| `LOOT_SCRAP` | L43 |
| `LOOT_MODULE` | L44 |
| `LOOT_WEAPON` | L45 |
| `PORT_ID` | L46 |
| `ITEM_SCRAP` | L47 |
| `MODULE_CRATE` | L48 |
| `test_resolve_victory_applies_loot_and_durability() -> void` | L280 |
| `test_same_seed_is_deterministic() -> void` | L306 |
| `test_armor_and_damage_type_pierce() -> void` | L320 |
| `test_status_effect_adds_damage_over_time() -> void` | L339 |
| `test_player_retreats_below_threshold() -> void` | L358 |
| `test_player_defeat_sets_minimum_durability() -> void` | L372 |
| `test_enemy_retreat_gives_no_loot() -> void` | L384 |
| `test_loot_modules_and_weapon_salvage_apply() -> void` | L396 |
| `test_old_state_queries_are_read_only_and_command_creates_block() -> void` | L421 |
| `test_command_errors_are_structured() -> void` | L441 |
| `test_player_weapon_rows_from_hull_sockets() -> void` | L455 |
| `test_multi_enemy_encounter_targets_sequentially() -> void` | L472 |
| `test_battle_record_is_save_safe() -> void` | L495 |
| `test_core_content_resolves() -> void` | L515 |
| `test_combat_commands_and_queries_are_registered() -> void` | L534 |

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

模块索引：[framework/tests](../README.md)
