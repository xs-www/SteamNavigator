# `framework/domain/world/world_generator.gd`

> 作用：世界生成总控，协调区域、陆地、港口放置、连通性、出航角与航线预计算。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldGenerator` | L1 |
| `MAX_ATTEMPTS` | L35 |
| `MIN_PORT_SPACING` | L36 |
| `DEFAULT_WORLD_SIZE` | L37 |
| `MIN_PORTS` | L39 |
| `MAX_PORTS` | L40 |
| `FORMAL_LANDMASSES` | L43 |
| `FORMAL_PORT_SLOTS` | L62 |
| `generate(profile: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary` | L76 |
| `formal_profile(definition: ContentDefinition) -> Dictionary` | L92 |

## 契约与约束
- 同 seed、profile 与内容注册表必须得到相同世界。
- 整世界生成最多尝试 `MAX_ATTEMPTS`（60）次；单次放置内每港最多 20 次间距重试。
- `required_tags` 来自港口配置，不依赖内容注册表中的硬编码 ID。
- 航线在生成期算好后写入 `WorldMap.edges`（`{from,to,distance,path}`），
  运行期只读；换航线算法只需改这里，查询/UI 不受影响。
- **港口规模**：世界验收口径是单局 `MIN_PORTS..MAX_PORTS`（15–20，见设计文档
  §2.2 与 §12）。`_validate_world` 用 profile 的 `min_ports`/`max_ports`，缺省即
  取这两个常量；`port_defs` 少于下限直接判定失败，所以「港口数不够」不会靠
  静默生成一张小图蒙混过关。真实对局（`RunFactory`）按抽象地图港口数显式传
  `min_ports`，那是另一条路径，不受此下限影响。

## 重点逻辑
### `generate(...)`
- 读取 profile，依次生成区域和陆地、放置港口、验证必需设施、构建连通图、计算
  出航角，最后调 `_build_route_edges` 预计算航线表。
### `formal_profile(definition)`
- 把内容层世界 profile（`map_profiles` 定义）转成生成器 profile：五个区域
  （起始沿岸 / 中部沿岸 ×2 / 远洋 / 外洋）、十一块陆地（1 大陆 + 5 大岛 + 3 小岛 +
  2 环礁）、港口槽位按 `port_count_range` 取前 N 个，名称键来自 `port_name_keys`、
  原型按 `archetypes` 轮转。它是 §12 验收项「15-20 港口合理分布在陆地海岸线上」
  的可执行实现。
### `_place_ports_on_coastlines(...)`
- 按 `coast_t` 在目标海岸采样并施加确定性抖动，同时守住港口最小间距。
### `_build_route_edges(...)`
- 每条连通边算一次 `RouteCalculator.calculate_route`；算不出航线的边跳过并告警，
  不让单条边拖垮整个世界生成。

模块索引：[framework/domain](../README.md)
