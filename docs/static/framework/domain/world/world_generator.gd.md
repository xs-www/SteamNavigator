# `framework/domain/world/world_generator.gd`

> 作用：世界生成总控，协调区域、陆地、港口放置、连通性与出航角计算。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldGenerator` | L1 |
| `MAX_ATTEMPTS` | L18 |
| `MIN_PORT_SPACING` | L19 |
| `DEFAULT_WORLD_SIZE` | L20 |
| `generate(profile: Dictionary, hub: RegistryHub, rng_service: RngService, ship: Dictionary) -> Dictionary` | L23 |

## 契约与约束
- 同 seed、profile 与内容注册表必须得到相同世界。
- 港口冲突通过有限重试解决，最多尝试 60 次；失败返回结构化原因。
- `required_tags` 来自港口配置，不依赖内容注册表中的硬编码 ID。

## 重点逻辑
### `generate(...)`
- 读取 profile，依次生成区域和陆地、放置港口、验证必需设施、构建连通图并计算出航角。
### `_place_ports_on_coastlines(...)`
- 按 `coast_t` 在目标海岸采样并施加确定性抖动，同时守住港口最小间距。

模块索引：[framework/domain](../README.md)
