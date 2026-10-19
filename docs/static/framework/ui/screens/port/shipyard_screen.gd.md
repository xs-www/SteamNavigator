# `framework/ui/screens/port/shipyard_screen.gd`

> 作用：船厂页面场景：中央 SNShipView 改装台 + 右侧按槽位分组的部件 HUD（已装/仓库/随船/购买），下方保留打造订单、港口仓库、配方、购买与通关清单面板。

- 关键依赖：`SNShipView`、`SNPartRow`、`SNBadge`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardScreen` | L1 |
| `command_requested (signal)` | L14 |
| `refit_mode_changed (signal)` | L15 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L38 |

## 契约与约束

- bind(vm, translate) 接收 Shell 组合后的 shipyard.view、contracts、victory 与 refit，不访问 AppContext、QueryBus、CommandBus 或注册表。
- `_stage_row()` 是中央改装台：SNShipView（520×390 起）+ 改装开关、船况摘要与提示；右侧 372 px 部件 HUD 按 TYPE_ORDER（船体/锅炉/货舱/导航/安全/客舱）分组。
- 槽位由 `_build_slots()` 从 ship.modules 反推：船体/锅炉/导航/安全各 1，cabin_slots≥1 时加 1，cargo_slots 个货舱槽；槽位 id 为 `<content_type>_<index>`，fixed 只对船体/锅炉为真。
- 拖放 `_on_slot_drop(payload, slot)`：类型一致且 source ∈ {warehouse, transit} 时发 `ship.install_module{module_id, source}`；槽位已有且不同于拖入件时补 `replace_module_id`。
- 点击 HUD 行 `_on_part_activated()`：只有 source == purchase 的行发 `ship.install_module{module_id}`（购买安装）；已装/仓库/随船行不触发。点击槽位 `_on_slot_activated()` 只高亮同类部件行，不改状态。
- HUD 行标签：已装/仓库/随船/购买 n 金币；可拖行 = 仓库且 can_install 为真，或随船件；标题徽标显示 `ui.label.draggable_count` 可拖数量。
- `refit_mode_changed(active)` 只通知 Shell 记住改装态；页面从 vm.refit 恢复，整页重建（切页/命令后刷新）仍保持纵剖图。
- 安装、卸下、打造、模块/材料存取和在港等待均发出 command_requested(command, params)，由 Shell 统一执行、存档并反馈错误。
- 所有 can_install/can_uninstall/can_craft 与 blockers 均来自 shipyard.view；页面只翻译原因、禁用按钮和组织布局，不复制领域规则。
- 打造按钮明确显示工时；未完成订单显示剩余时间和所属港口，等待选项直接来自 wait_options。
- 页面按模块类型分组购买候选，显示效果、解锁来源、替换提示、材料持有/需求和金币配方。
- 密集字段（模块行、限制原因、按钮、HUD 行）统一用 AUTOWRAP_OFF 单行排版，不允许智能换行压成竖列。
- 页面可重复 bind，每次 `_clear()` 重建；每个 PanelContainer 只有一个内容容器。

模块索引：[framework/ui](../../README.md)
