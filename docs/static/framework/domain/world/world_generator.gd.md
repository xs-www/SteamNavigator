# `framework/domain/world/world_generator.gd`

> 作用：世界生成总控，协调区域、陆地、港口放置、连通性、出航角与航线预计算。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldGenerator` | L1 |
| `MAX_ATTEMPTS` | L24 |
| `MIN_PORT_SPACING` | L25 |
| `DEFAULT_WORLD_SIZE` | L26 |
| `generate(profile: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary` | L29 |

## 契约与约束
- 同 seed、profile 与内容注册表必须得到相同世界。
- 整世界生成最多尝试 `MAX_ATTEMPTS`（60）次；单次放置内每港最多 20 次间距重试。
- `required_tags` 来自港口配置，不依赖内容注册表中的硬编码 ID。
- 航线在生成期算好后写入 `WorldMap.edges`（`{from,to,distance,path}`），
  运行期只读；换航线算法只需改这里，查询/UI 不受影响。

## 重点逻辑
### `generate(...)`
- 读取 profile，依次生成区域和陆地、放置港口、验证必需设施、构建连通图、计算
  出航角，最后调 `_build_route_edges` 预计算航线表。
### `_place_ports_on_coastlines(...)`
- 按 `coast_t` 在目标海岸采样并施加确定性抖动，同时守住港口最小间距。
### `_build_route_edges(...)`
- 每条连通边算一次 `RouteCalculator.calculate_route`；算不出航线的边跳过并告警，
  不让单条边拖垮整个世界生成。

模块索引：[framework/domain](../README.md)
