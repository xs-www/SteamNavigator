# `framework/domain/world/world_port.gd`

> 作用：表示锚定在陆地海岸线上的世界港口及其设施、连通性信息。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WorldPort` | L1 |
| `_init(p_id: String = "", p_position: Vector2 = Vector2.ZERO) -> void` | L29 |
| `is_empty() -> bool` | L47 |
| `has_facility(facility: String) -> bool` | L51 |
| `has_tag(tag: String) -> bool` | L55 |
| `has_all_tags(required_tags: Array) -> bool` | L59 |
| `distance_to(other: WorldPort) -> float` | L66 |
| `to_dict() -> Dictionary` | L70 |
| `from_dict(value: Dictionary) -> WorldPort` | L90 |

## 契约与约束
- `departure_angle` 由 `RouteCalculator.compute_departure_angles()` 根据邻居质心计算。
- `connectivity` 只存储直接连通的港口。
- `facilities` 和 `tags` 供内容系统过滤与查询。

模块索引：[framework/domain](../README.md)
