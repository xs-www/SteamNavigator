# `framework/services/rng_service.gd`

> 作用：命名随机流：按（种子、流名、上下文）派生独立 RNG。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RngService` | L1 |
| `STREAM_MAP_GENERATION` | L9 |
| `STREAM_GOODS_GENERATION` | L10 |
| `STREAM_NPC_TRADE` | L11 |
| `STREAM_CONTRACT_GENERATION` | L12 |
| `STREAM_VOYAGE_RISK` | L13 |
| `STREAM_VOYAGE_EVENT` | L14 |
| `STREAM_EVENT_OPTIONS` | L15 |
| `STREAM_EXPLORATION` | L18 |
| `STREAM_CAMPAIGN_WORLD` | L21 |
| `STREAM_COMBAT` | L23 |
| `STREAM_NAMES` | L25 |
| `_init(seed_value: int = 1) -> void` | L43 |
| `stream(stream_name: StringName, context_key: String = "") -> RandomNumberGenerator` | L47 |
| `make_stream(stream_name: StringName, context_key: String = "") -> RandomNumberGenerator` | L57 |
| `derive_seed(stream_name: StringName, context_key: String = "") -> int` | L63 |
| `choose_weighted(generator: RandomNumberGenerator, items: Array, weight_key: String = "weight") -> Variant` | L67 |
| `sample_without_replacement(generator: RandomNumberGenerator, items: Array, count: int) -> Array` | L88 |

## 契约与约束

- 流首次访问时创建并缓存；同 key 多次获取共享状态。
- 新增流/上下文不会改变已有流序列（有测试覆盖）。
- 提供加权抽样与不重复抽样辅助。

模块索引：[framework/services](./README.md)
