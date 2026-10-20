# `framework/domain/world/world_generator.gd`

> 作用：世界生成器的主逻辑，协调陆地生成、港口放置、连通性计算。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldGenerator` | L1 |

## 契约与约束

- 生成过程是确定性的（同 seed 产生相同结果）。
- 重试机制用于处理港口放置冲突（最多60次）。
- 验证失败时会返回详细的错误信息。
- 默认配置提供了合理的起点（4区域、11陆地、13港口）。
- `required_tags` 从港口配置中读取，不依赖内容注册表。

## 重点逻辑

### `generate(profile, rng, content_registry)`

- 从 profile 读取配置（世界大小、区域定义等）。
- 为每个区域生成陆地（调用 LandGenerator）。
- 在海岸线上放置港口（按配置顺序）。
- 验证必需设施位置（船厂和情报站在起点2条边内）。
- 构建连通性图（调用 RouteCalculator）。
- 计算出航角度（调用 RouteCalculator）。

### `_place_ports_on_coastlines(world, port_configs, content_registry, rng)`

- 对于每个港口配置，找到对应的陆地。
- 在海岸线上按 `coast_t` 参数采样位置，添加随机抖动（±0.04）。
- 检查最小间距（15单位），如果不满足则重试（最多20次）。
- 从配置中读取 `required_tags` 并添加到港口。
- 从内容注册表查询原型，补充设施和标签。

模块索引：[framework/domain](../README.md)
