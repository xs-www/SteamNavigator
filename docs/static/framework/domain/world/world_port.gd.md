# `framework/domain/world/world_port.gd`

> 作用：表示世界地图中的港口，包含位置、设施、连通性等信息。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldPort` | L1 |
| `_init(p_id: String = "", p_position: Vector2 = Vector2.ZERO) -> void` | L25 |
| `is_empty() -> bool` | L43 |
| `has_facility(facility: String) -> bool` | L47 |
| `has_tag(tag: String) -> bool` | L51 |
| `has_all_tags(required_tags: Array) -> bool` | L55 |
| `distance_to(other: WorldPort) -> float` | L62 |
| `to_dict() -> Dictionary` | L66 |

## 契约与约束

- `departure_angle` 由 `RouteCalculator.compute_departure_angles()` 计算，基于邻居质心。
- `connectivity` 存储的是直接连通的港口，不包含间接连通。
- `facilities` 和 `tags` 用于内容系统的过滤和查询。

模块索引：[framework/domain](../README.md)
