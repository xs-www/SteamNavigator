# `framework/domain/economy/intel_service.gd`

> 作用：生成不可变的市场/NPC 情报快照，并保留生成时间。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `IntelService` | L1 |
| `build_snapshot(state: GameState, hub: RegistryHub, game_time: float) -> Dictionary` | L8 |
| `store(state: GameState, snapshot: Dictionary) -> void` | L63 |
| `get_snapshot(state: GameState) -> Dictionary` | L67 |
| `snapshot_age(state: GameState) -> float` | L71 |

## 契约与约束

- 只覆盖已发现港口；NPC 只显示大致 ETA 区间，不暴露精确抵达时刻。
- 快照不会自动更新；刷新由 `intel.refresh` 命令显式触发。
- 趋势由库存相对 base_stock 判断：up/down/stable；快照 market 行另给 trend_percent（最近 8 条 price_history 首尾变化率，样本不足或非 buyable 恒 0.0），供对比表显示红降/绿升数字。

模块索引：[framework/domain](../README.md)
