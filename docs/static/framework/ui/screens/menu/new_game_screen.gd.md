# `framework/ui/screens/menu/new_game_screen.gd`

> 作用：新航程配置页面场景：选择初始构筑和随机种子，展示启动内容摘要与警告。

- 关键依赖：`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `NewGameScreen` | L1 |
| `action_requested (signal)` | L5 |
| `TEXT` | L7 |
| `MUTED` | L8 |
| `BRASS` | L9 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L17 |

## 契约与约束

- bind(vm, translate) 接收 builds、selected_build、seed_text、mods、内容计数和 warnings，不访问注册表或命令总线。
- 构筑与种子是页面局部表单状态；只有点击开始时才通过 start_run 意图一并交给 Shell。
- 构筑选择变化只更新本页描述，不触发整页重建。
- 返回只发出 back 意图；run.start 的参数解析与执行仍由 Shell 负责。

模块索引：[framework/ui](../../README.md)
