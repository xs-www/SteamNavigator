# `framework/domain/world/route_calculator.gd`

> 作用：计算港口间的贝塞尔曲线路径，生成出航角度，构建连通性图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `RouteCalculator` | L1 |

## 契约与约束

- 贝塞尔曲线的控制点方向由出航角度决定。
- 连通性图是无向的（A连接B意味着B也连接A）。
- 路径计算不考虑海洋迷雾（那是运行时状态）。
- A* 绕路时使用曼哈顿距离作为启发式。

## 重点逻辑

### `calculate_route(from, to, landmasses)`

- 计算直线距离和方向，检测是否穿过陆地。
- 如果穿过陆地，使用 A* 绕开。
- 生成三次贝塞尔曲线（20段细分），控制点长度 = 距离 × 0.3。

### `compute_departure_angles(ports, connectivity)`

- 对于每个港口，收集所有直接邻居的位置，计算邻居的质心。
- 出航角度 = atan2(质心.y - 港口.y, 质心.x - 港口.x)。

模块索引：[framework/domain](../README.md)
