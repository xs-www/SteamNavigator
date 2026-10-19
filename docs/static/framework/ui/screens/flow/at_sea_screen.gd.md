# `framework/ui/screens/flow/at_sea_screen.gd`

> 作用：航行中流程场景：显示起终港、预计抵达时间或等待结算状态。

- 关键依赖：`ClockService`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `AtSeaScreen` | L1 |
| `bind(vm: Dictionary, _translate: Callable) -> void` | L10 |

## 契约与约束

- bind(vm, translate) 只消费 Shell 解析后的 origin_name/destination_name/arrival_time。
- 页面没有命令入口，不修改航程或时间；抵达刷新由 Shell 与命令结果驱动。

模块索引：[framework/ui](../../README.md)
