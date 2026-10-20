# `framework/domain/world/landmass.gd`

> 作用：表示世界地图中的陆地多边形，支持大陆、大岛、小岛、环礁四种原型。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `Landmass` | L1 |
| `is_empty() -> bool` | L28 |
| `area() -> float` | L32 |
| `centroid() -> Vector2` | L43 |
| `bounding_box() -> Rect2` | L52 |
| `contains_point(point: Vector2) -> bool` | L65 |
| `coastline_length() -> float` | L81 |
| `sample_coastline(t: float) -> Vector2` | L91 |
| `to_dict() -> Dictionary` | L108 |

## 契约与约束

- 多边形顶点顺序必须一致（全顺时针或全逆时针）。
- 海岸线采样假设多边形是闭合的（首尾顶点相连）。
- 面积计算结果始终为正数（使用 absf）。

模块索引：[framework/domain](../README.md)
