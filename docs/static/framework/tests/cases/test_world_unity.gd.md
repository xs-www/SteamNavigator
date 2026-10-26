# `framework/tests/cases/test_world_unity.gd`

> 作用：锁定「海图唯一真相」世界契约的回归测试（2026-10-26）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TestWorldUnity` | L2 |
| `SEED` | L23 |
| `STRATEGY` | L24 |
| `OTHER_SEEDS` | L26 |
| `test_chart_is_the_single_world_topology() -> void` | L29 |
| `test_chart_is_a_complete_graph() -> void` | L106 |
| `test_chart_view_and_voyage_preview_agree_field_by_field() -> void` | L136 |
| `test_chart_world_is_deterministic() -> void` | L183 |

## 契约与约束
- **唯一拓扑**：坐标海图世界（`state.data["world_map"]`）的 `connectivity_graph` 与
  `edges` 就是世界拓扑；`GameState.world()` 的 `ports` / `routes` 由
  `ChartWorldProjection.from_chart` 派生，集合必须与海图边完全相等（无 chart-only /
  world-only 边，`state.world()` 不再自己生成拓扑）。
- **完全图**（2026-10-26「任意两港可通航 + 航线需解锁」）：`generate_chart` 为每对港口
  生成一条航线，5 港 = 10 条边；每对恰有一条边、每条边都有非空绘制路径。
- **唯一距离**：每条海图边 `distance` == 该边绘制路径（`edges[].path`）的折线长度 ==
  `world.routes[].distance`（两位小数同值）；`world.ports[].x/y` == 海图港口坐标；
  `base_risk` 也出自同一条海图边。
- `sea_chart.view` 与 `voyage.preview` 对同一对港口逐项一致：distance / duration /
  coal / water / risk。未解锁航线 `preview` 返回 `route_locked`（见
  `test_route_unlock`）；本套件先显式解锁全部 pair 再比较数值。
- 同 seed 的两次开局得到逐字段相同的海图世界与派生 `world.routes`；不同 seed 不同。
- 测试只用公开查询 / 命令与内容注册表，不改生产代码路径。

模块索引：[framework/tests](../README.md)
