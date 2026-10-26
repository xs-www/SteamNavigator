# `framework/domain/world/world_generator.gd`

> 作用：世界生成总控，协调区域、陆地、港口放置、连通性、出航角与航线预计算。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldGenerator` | L1 |
| `MAX_ATTEMPTS` | L49 |
| `MIN_PORT_SPACING` | L50 |
| `DEFAULT_WORLD_SIZE` | L51 |
| `MIN_PORTS` | L53 |
| `MAX_PORTS` | L54 |
| `FORMAL_LANDMASSES` | L57 |
| `FORMAL_PORT_SLOTS` | L76 |
| `generate(profile: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary` | L90 |
| `generate_chart(profile: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary` | L124 |
| `formal_profile(definition: ContentDefinition) -> Dictionary` | L466 |

## 契约与约束
- 同 seed、profile 与内容注册表必须得到相同世界。
- 整世界生成最多尝试 `MAX_ATTEMPTS`（60）次；单次放置内每港最多 20 次间距重试。
- 可证明不可满足的 profile 不进入重试：`ports` 定义数低于 `min_ports` 时直接返回
  `too few ports`（放置只会减少港口，重试 60 次不可能成功），避免开局/测试白等。
- `required_tags` 来自港口配置，不依赖内容注册表中的硬编码 ID。
- 航线在生成期算好后写入 `WorldMap.edges`（`{from,to,distance,path}`），
  运行期只读；换航线算法只需改这里，查询/UI 不受影响。
- **港口规模**：通用生成器 `generate()` 的验收口径是单局 `MIN_PORTS..MAX_PORTS`
  （15–20，见设计文档 §2.2 与 §12）。`_validate_world` 用 profile 的
  `min_ports`/`max_ports`，缺省即取这两个常量；`port_defs` 少于下限直接判定失败，所以
  「港口数不够」不会靠静默生成一张小图蒙混过关。**战役不走这条路径**：可玩世界由
  `generate_chart()` 生成，港口数来自内容蓝图（默认 5）。

## 重点逻辑
### `generate_chart(...)`（**战役唯一世界生成入口**，2026-10-26 海图唯一真相）
- 生成的就是海图：陆地 + 港口坐标 + **完全图拓扑**（`RouteCalculator.build_complete_connectivity`：
  任意两港之间都有一条物理航线，5 港 = 10 条边），拓扑建好后再按 BFS 距离分配
  港口 archetype（必需设施落在 `required_facility_max_edges` 内）、重算出航角、
  逐边算贝塞尔路径，`distance` 取路径折线长度（两位小数），`base_risk` 从
  `route_templates.risk_range` 用命名流按 pair 派生。**任一对港口算不出路径即判本次
  尝试失败并重试，不做缺边 / 直线兜底**（海图必须每对都能通航）。
  「能不能出航」不在这里决定：几何恒可通航，运行时由航线解锁状态
  （`campaign_world.unlocked_route_keys`，见 `docs/design/ROUTE_UNLOCK_SYSTEM.md`）门禁。
- 返回 `{ok, world_map, attempt, edge_count}`；生成的 `world_map` 同时是玩法地图
  （`ChartWorldProjection.from_chart` 派生 `GameState.world()`）。
- **没有第二套拓扑**：战役不再调用 `MapGenerator`，也不再有 MST / 补边 / `edge_density`。
### `generate(...)`（通用世界生成器，15–20 港验收骨架 / `test_world_generator`）
- 旧路径：读取 profile，依次生成区域和陆地、放置港口、验证必需设施、构建稀疏连通图
  （MST + 2 近邻）、计算出航角，最后调 `_build_route_edges` 预计算航线表。战役不走它。
### `formal_profile(definition)`
- 把内容层世界 profile 转成生成器 profile：五个区域
  （起始沿岸 / 中部沿岸 ×2 / 远洋 / 外洋）、十一块陆地（1 大陆 + 5 大岛 + 3 小岛 +
  2 环礁）、港口槽位按 `port_count_range` 取前 N 个，名称键来自 `port_name_keys`、
  原型按 `archetypes` 轮转。它是 §12 验收项「15-20 港口合理分布在陆地海岸线上」
  的可执行实现。
### `_place_ports_on_coastlines(...)`
- 按 `coast_t` 在目标海岸采样并施加确定性抖动，同时守住港口最小间距。
### `_build_route_edges(...)`
- 每条连通边算一次 `RouteCalculator.calculate_route`；算不出航线的边跳过并告警，
  不让单条边拖垮整个世界生成（仅通用生成器；战役生成不做这种静默跳过）。

模块索引：[framework/domain](../README.md)
