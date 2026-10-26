# 遗迹远征系统（Ruin Expedition System，Phase D5）

> 状态：Draft 1（2026-10-23，D5 运行时 + 最小 UI 落地）。内容契约以
> [schemas/v2/](../../schemas/v2/) 与 [dev_mods/core/content/](../../dev_mods/core/content/) 为准。

## 1. 范围

D5 交付可玩的遗迹远征纵向切片：

- 在港口选择遗迹原型，按房间标签池生成确定性房间序列；
- 进入房间时按危险表结算耐久/金钱/货物损失，并触发房间事件；
- 事件提供 1–3 个选项，选项效果落地（金钱、耐久、物品）；
- 走完全部房间后按战利品表发钱/物品，并从遗物池抽 1 件永久遗物；
- 玩家可随时撤退，结束远征但不发完成奖励；
- 最小遗迹页（选择遗迹、进入房间、事件选项、撤退、日志、遗物收藏）。

不在本切片：多房间地图可视化、队伍/随从、遗迹内战斗、攻略进度分享。

## 2. 内容类型（5 类 active 2.0，capability `content.ruins.v1`）

| 类型 | 关键字段 | Core 内容 |
| --- | --- | --- |
| `ruin_archetypes` | `room_count` / `difficulty` / `room_tags` / `hazard_table` / `loot_table` / `relic_pool` | 沉没大厅（4 房）、坍塌金库（6 房） |
| `room_templates` | `size` / `exits` / `event_ref` / `hazard_table` / `loot_table` / `weight` | 积水大厅、坍塌回廊、古老神龛、封闭金库 |
| `expedition_events` | `text_key` / `options[]{text_key,effect}` | 倒塌横梁、古老神龛、封闭金库 |
| `hazard_tables` | `entries[]{type,weight,amount_range,text_key}` | 轻微危险、严重危险 |
| `relics` | `rarity` / `value` / `modifiers` | 黄铜罗盘、密封海图、蒸汽之心 |

## 3. 运行态

`data.expedition`：`{active, ruin_id, phase, room_index, rooms[], pending_event,
loot_money, loot_items, log[]}`；`phase` = `room` / `event` / `finished`。

`data.relics`：永久遗物 id 数组；`data.expedition_serial`：远征序号（随机种子的一部分）。

- 房间序列：按 `room_tags` 过滤 `room_templates`，按 `weight` 抽 `room_count` 个；
  种子 = run seed + ruin id + serial，同序号可复现。
- 危险：进入房间时按危险表权重抽 type/amount；durability 扣船耐久、money 扣钱、
  cargo 从船货舱扣除（无货转耐久损失）。
- 完成：`loot_table.money_range` 发钱，entries 的 item 进当前港仓库，其他类型折算金币；
  `relic_pool` 抽 1 件写入 `data.relics`。

## 4. 命令与查询

| 命令 | 说明 |
| --- | --- |
| `expedition.start {ruin_id}` | 在港开始；唯一进行中远征 |
| `expedition.enter` | 结算当前房间危险；有事件则进入 `event`，否则前进 |
| `expedition.choose {option_index}` | 执行事件选项效果并前进 |
| `expedition.retreat` | 结束远征，不发完成奖励 |

查询 `expedition.view`：遗迹、房间进度、当前房间/事件选项、奖励日志、永久遗物。

## 5. UI

最小遗迹页（`framework/ui/screens/port/ruins_screen.tscn`）随船厂解锁：
未开始列出遗迹；进行中显示房间进度、进入/撤退按钮、事件选项与日志；底部遗物收藏。

> 2026-10-26 玩家反馈：遗迹属于**航行探索**玩法（海图 → 探索），不作为港口页入口；
> 在探索侧遗迹玩法发布前，顶部导航入口暂隐藏（`main.gd` 的 `HIDDEN_NAV_SCREENS`）。
> `expedition.*` 命令 / `expedition.view` 与页面保留，截图工具仍可直接路由。

## 6. 验收

- `test_expedition.gd` 9 例：命令/查询、开始校验、完整远征 + 遗物、危险结算、撤退、
  存档往返、损坏数据、确定性。
- `test_world_schema_refs.gd`：遗迹/房间/事件/危险引用与房间池。
- `test_world_completeness.gd`：5 类 Core 最低数量。
- 编辑器/CLI/SDK：`example_ruins` 模组、`content.ruins.v1` capability、发布门禁校验。
