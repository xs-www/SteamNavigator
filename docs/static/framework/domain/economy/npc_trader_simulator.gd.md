# `framework/domain/economy/npc_trader_simulator.gd`

> 作用：后台 NPC 商船：在港口间运输/采购商品，推动库存与价格。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `NpcTraderSimulator` | L1 |
| `MAX_CATCH_UP_CYCLES` | L8 |
| `create_initial(state: GameState, hub: RegistryHub, rng_service: RngService, config: Dictionary) -> Array` | L11 |
| `advance(state: GameState, hub: RegistryHub, rng_service: RngService, now: float, config: Dictionary) -> Array[Dictionary]` | L38 |

## 契约与约束

- NPC 不显示为海上实体，只保存当前位置、目的地、货类、数量、动作与 ETA。
- 抵达时 deliver 增加库存、buy 减少库存，随后重算价格并重新分配路线。
- NPC 只在 `buyable=true` 的本地商品中选货，不会为仅收购港口创造买侧市场。
- 单次推进每个 NPC 最多追赶 4 个周期，避免长时间跳跃导致无限循环。
- 随机流按 NPC ID 分离；市场事件返回 `{type:"market.changed"}`。

模块索引：[framework/domain](../README.md)
