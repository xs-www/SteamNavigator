# `framework/ui/screens/menu/main_menu_screen.gd`

> 作用：启动主菜单页面场景：展示启动状态与主入口，并把用户操作转成 Shell 意图。

- 关键依赖：`SNBadge`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MainMenuScreen` | L1 |
| `action_requested (signal)` | L5 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L13 |

## 契约与约束

- bind(vm, translate) 接收状态、本地化和 autosave_available，不访问 AppContext、存档服务或场景树退出 API。
- 开始、加载、模组、设置、诊断与退出均发出 action_requested(action, params)，由 Shell 执行。
- 加载按钮的禁用状态只由 autosave_available 决定；页面不自行探测文件。
- 页面可重复 bind，每次清理旧节点。

模块索引：[framework/ui](../../README.md)
