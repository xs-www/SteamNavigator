# `framework/domain/world/region.gd`

> 作用：表示世界地图中的行政区域，区分沿岸区域和远洋区域。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `Region` | L1 |
| `_init(p_id: String = "", p_name_key: String = "", p_tier: Tier = Tier.COASTAL) -> void` | L22 |
| `is_empty() -> bool` | L29 |
| `add_landmass(landmass_id: String) -> void` | L33 |
| `to_dict() -> Dictionary` | L38 |
| `from_dict(value: Dictionary) -> Region` | L47 |

## 契约与约束
- `tier` 影响港口生成策略，沿岸区域优先放置必需设施。
- `landmass_ids` 用于快速查询区域内的陆地。

模块索引：[framework/domain](../README.md)
