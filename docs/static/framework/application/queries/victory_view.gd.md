# `framework/application/queries/victory_view.gd`

> 作用：通关页 ViewModel：是否通关、通关时间与完整 run summary。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VictoryViewQuery` | L1 |
| `execute(_params: Dictionary, context) -> Dictionary` | L5 |

## 契约与约束

- 没有 run 时返回 has_run=false / achieved=false，UI 可安全渲染。
- achieved/achieved_at 来自 state.data.victory；summary 直接透传 VictoryService 写入的纯数据。
- achieved_at_label 由 ClockService 格式化，供页面标题使用。

模块索引：[framework/application](../README.md)
