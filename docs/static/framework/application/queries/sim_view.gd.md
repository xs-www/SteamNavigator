# `framework/application/queries/sim_view.gd`

> 作用：`sim.view` 只读查询：输出模拟时钟的 paused / speed / tick / 步长 /

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SimViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L15 |

游戏时间与已注册系统描述；无 run 或旧档（缺 `data.sim`）时返回默认值，且
不修改状态（QueryBus 的克隆保证）。

## 契约与约束
- 只读：绝不创建 `data.sim` 块；旧档在第一次 sim 命令后才持久化该块。
- 字段稳定：`paused(bool) / speed(float) / tick(int) / step_hours(float) /
  game_time(float) / time_label(String) / systems(Array[{id, priority}])`。

模块索引：[framework/application](../README.md)
