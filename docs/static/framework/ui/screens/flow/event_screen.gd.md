# `framework/ui/screens/flow/event_screen.gd`

> 作用：航行事件流程场景：展示事件说明、当前资源和本次抽取的处理选项。

- 关键依赖：`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `EventScreen` | L1 |
| `command_requested (signal)` | L5 |
| `TEXT` | L7 |
| `MUTED` | L8 |
| `RED` | L9 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L13 |

## 契约与约束

- bind(vm, translate) 接收 event、ship 与 money，不访问事件注册表或 GameState。
- 每个选项仅发出 event.choose_option command_requested，并使用独立绑定的 option_id。
- 结果应用、失败回滚、抵达结算和转场全部由 Shell/CommandBus 负责。

模块索引：[framework/ui](../../README.md)
