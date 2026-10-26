# `framework/domain/world/route_calculator.gd`

> 作用：计算避开陆地的港口间贝塞尔航路、出航角度和连通关系。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RouteCalculator` | L1 |
| `BEZIER_SEGMENTS` | L36 |
| `COAST_CLEARANCE` | L41 |
| `END_GRAZE_TOLERANCE` | L45 |
| `compute_departure_angles(ports: Array[WorldPort], connectivity: Dictionary, landmasses: Array[Landmass] = []) -> void` | L48 |
| `calculate_route(from_port: WorldPort, to_port: WorldPort, landmasses: Array[Landmass]) -> Dictionary` | L99 |
| `build_complete_connectivity(ports: Array[WorldPort]) -> Dictionary` | L530 |
| `build_connectivity_graph(ports: Array[WorldPort], landmasses: Array[Landmass]) -> Dictionary` | L540 |

## 契约与约束
- 贝塞尔控制点方向由港口出航角度决定；控制臂过长会把曲线拽进岛里，
  因此每条曲线发出前都必须过陆地校验（`_safe_bezier` 逐档收紧控制臂）。
- **可玩世界 = 完全图**（2026-10-26）：任意两港之间都有一条物理航线，
  拓扑不再做 MST / 补边；能否出航由运行时「航线解锁」状态决定
  （`WorldOps.is_route_unlocked`，见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`）。
- 通用生成器（15–20 港验收骨架）仍用旧的稀疏图 `build_connectivity_graph`。
- 路径计算不考虑运行时海洋迷雾（那是运行时状态）。
- 港口正好在海岸线上，端点附近 `END_GRAZE_TOLERANCE` 内的擦岸算靠泊，不算穿陆。

## 重点逻辑
### `calculate_route(...)`
- 直线不穿陆 → 直接造 20 段三次贝塞尔；穿陆 → `_find_path_around_land` 沿岸绕行，
  两者最终都由 `_safe_bezier` 生成并校验。
### `_detour(...)`
- 有界递归：对挡路的岛，取"沿其海岸外扩环走的较短弧"或"外切点"作候选，整条折线
  过 `_path_is_clear` 才采纳；递归深度上限 3，无 A*、无网格。
- 外扩距离按岛屿尺寸自适应（`_detour_clearances`）：三档 = 半长轴 ×1/2/3，下限
  `COAST_CLEARANCE * 0.5`、上限 `COAST_CLEARANCE`，小礁石不再把航线拽出 42 单位。
### `compute_departure_angles(...)`
- 默认取直接邻居质心方向；若该方向指向本岛内陆，回退为"背离本岛质心"的向海方向。
### `build_complete_connectivity(...)`
- **唯一可玩世界**的拓扑：每对港口互相连接（5 港 → 10 条边），只由港口 id 决定，
  确定性、无 RNG。生成器随后为每条边算贝塞尔路径 / 折线距离 / 基础风险；
  任一对算不出路径即判本次世界生成失败重试，不允许缺边。
### `build_connectivity_graph(...)`
- 通用生成器（15–20 港验收骨架、`WorldGenerator.generate()`）用的旧稀疏图：MST +
  每港 2 条最近邻。**战役不再走它**，保留给通用世界生成与测试。

模块索引：[framework/domain](../README.md)
