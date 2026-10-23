# `framework/domain/ruins/expedition_service.gd`

> 作用：Phase D5 遗迹远征的领域用例：开始远征、进入房间、选择事件选项、撤退与结算。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ExpeditionService` | L1 |
| `start(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L18 |
| `enter(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary` | L46 |
| `choose(state: GameState, hub: RegistryHub, params: Dictionary) -> Dictionary` | L79 |
| `retreat(state: GameState, hub: RegistryHub, _params: Dictionary) -> Dictionary` | L103 |

状态只落在 `data.expedition`（临时远征）与 `data.relics`（永久遗物）。

## 契约与约束
- `start` 要求人在港口、没有进行中的远征，遗迹原型存在；生成确定性房间序列。
- `enter` 结算当前房间危险；有事件则停下等待 `choose`，否则前进/结算。
- `choose` 只接受当前事件的选项下标；执行操作码后继续前进。
- 完成时按 loot_table 发钱/物品到当前港仓库，并从 relic_pool 抽 1 件遗物加入
  `data.relics`；撤退结束远征但不发完成奖励。
- 领域事件：`expedition.started` / `expedition.room_entered` / `expedition.event_choice` /
  `expedition.completed` / `expedition.retreated`。

模块索引：[framework/domain](../README.md)
