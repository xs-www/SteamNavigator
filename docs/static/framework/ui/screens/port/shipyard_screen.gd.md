# `framework/ui/screens/port/shipyard_screen.gd`

> 作用：船厂页面场景：展示当前/运输模块、打造订单、港口仓库、配方和可购买模块，并发出船只与仓库命令。

- 关键依赖：`SNBadge`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardScreen` | L1 |
| `command_requested (signal)` | L5 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L18 |

## 契约与约束

- bind(vm, translate) 接收 Shell 组合后的 shipyard.view、contracts、victory，以及材料/解锁/替换展示字段，不访问 AppContext、QueryBus、CommandBus 或注册表。
- 安装、卸下、打造、模块/材料存取和在港等待均发出 command_requested(command, params)，由 Shell 统一执行、存档并反馈错误。
- 所有 can_install/can_uninstall/can_craft 与 blockers 均来自 shipyard.view；页面只翻译原因、禁用按钮和组织布局，不复制领域规则。
- 打造按钮明确显示工时；未完成订单显示剩余时间和所属港口，等待选项直接来自 wait_options。
- 页面按模块类型分组购买候选，显示效果、解锁来源、替换提示、材料持有/需求和金币配方。
- 模块行、限制原因与按钮保持横向布局，不允许智能换行把限制文案压成竖列。
- 页面可重复 bind，每次清理旧节点；每个 PanelContainer 只有一个内容容器。

模块索引：[framework/ui](../../README.md)
