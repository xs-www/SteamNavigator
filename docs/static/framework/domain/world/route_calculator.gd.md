# `framework/domain/world/route_calculator.gd`

> 作用：计算避开陆地的港口间贝塞尔航路、出航角度和连通关系。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RouteCalculator` | L1 |
| `BEZIER_SEGMENTS` | L18 |
| `COAST_CLEARANCE` | L22 |
| `END_GRAZE_TOLERANCE` | L26 |
| `compute_departure_angles(ports: Array[WorldPort], connectivity: Dictionary, landmasses: Array[Landmass] = []) -> void` | L29 |
| `calculate_route(from_port: WorldPort, to_port: WorldPort, landmasses: Array[Landmass]) -> Dictionary` | L80 |
| `build_connectivity_graph(ports: Array[WorldPort], landmasses: Array[Landmass]) -> Dictionary` | L491 |

## 契约与约束
- 贝塞尔控制点方向由港口出航角度决定。
- 连通图是无向图；路径计算不考虑运行时海洋迷雾。
- A* 绕路使用曼哈顿距离作为启发式。

## 重点逻辑
### `calculate_route(...)`
- 先检查直线是否穿过陆地，必要时 A* 绕行，再生成 20 段三次贝塞尔曲线。
### `compute_departure_angles(...)`
- 收集直接邻居并计算质心，由质心方向确定唯一出航角。

模块索引：[framework/domain](../README.md)
