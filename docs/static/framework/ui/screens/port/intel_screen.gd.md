# `framework/ui/screens/port/intel_screen.gd`

> 作用：航路情报页面场景：展示情报摘要、商品×港口矩阵与 NPC 商船动向。

- 关键依赖：`SNIntelTable`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `IntelScreen` | L1 |
| `command_requested (signal)` | L5 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L15 |

## 契约与约束

- bind(vm, translate) 只消费 intel.view 数据，不访问 AppContext、QueryBus 或 CommandBus。
- 有报告时展示生成时间、年龄、覆盖统计与快照提示；无报告和空矩阵均有明确空状态。
- 刷新按钮只发出 intel.refresh command_requested；价格矩阵继续委托 SNIntelTable 渲染。
- NPC 预计到达时间只做 ClockService 格式化，不改变游戏时钟或情报快照。

模块索引：[framework/ui](../../README.md)
