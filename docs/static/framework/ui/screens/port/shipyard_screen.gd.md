# `framework/ui/screens/port/shipyard_screen.gd`

> 作用：船厂页两种布局共用一页：正常态为「已有船舶卡片 / 实机渲染舞台 / 组件分类入口」，改装态为「贴图纵剖图 / 所选分类的槽位与操作 / 竖排分类页签（含杂项）」。规则仍来自 `shipyard.view`，页面不写 `GameState`。

- 关键依赖：`SNShipView`、`SNPartRow`、`SNBadge`、`SNButton`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardScreen` | L1 |
| `command_requested (signal)` | L18 |
| `refit_mode_changed (signal)` | L19 |
| `refit_category_changed (signal)` | L20 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L48 |
| `set_category(category: String) -> void` | L136 |

## 契约与约束

- `bind(vm, translate)` 接收 Shell 组合后的 shipyard.view（含 refit/category/ship.hull_name/warehouse/candidates/craft/orders/wait_options），不访问 AppContext、QueryBus、CommandBus 或注册表；可重复 bind，每次 `_clear()` 后重建。
- `CATEGORY_ORDER` = 船体/锅炉/货舱/导航/安全/客舱 + `misc`；`MODULE_TYPES` 不含 misc。`set_category` 只接受这七个值，非法值直接 return；切换分类会同时进入改装态并发 `refit_category_changed`。
- `_body` 固定三列：正常态 `_ship_list_panel / _render_panel / _components_panel`；改装态 `_section_panel / _operations_panel / _category_tabs_panel`。`_rebuild_layout()` 只重建 `_body`，标题与摘要行保留。
- 正常态中央舞台由 `_make_stage(EXTERIOR, ...)` 创建；`ship.hull_model_path` 非空（内容模组提供船体 GLB）或本地有旧路径回退时，通过 `set_renderer(SNShipStage3D.new())` 挂载 3D 船体舞台；改装态仍用纵剖图贴图，无模型时保留程序化占位。
- 正常态：船卡用 `SHIP_THUMB_PATH`（存在才加载，210×118 cover；缺失回退占位面板），船名取 Shell 注入的 `ship.hull_name`，缺失回退 `hull_id` 的本地化键；组件列每类一行入口并显示槽位计数，「0 可拖」徽标统计仓库/随船可装行。
- 改装态：纵剖图 `SNShipView(CUTAWAY)` + 槽位贴片；中间操作列按分类渲染槽位卡、仓库/随船行、购买卡与打造卡。操作列自带 ScrollContainer（`horizontal_scroll_mode=DISABLED`），全页只有中列纵向滚动。
- 槽位卡：标题 + 固定槽徽标 + 已装名；效果行与重量/tier/卸下按钮取自 `ship.modules[]` 行的 `effect/can_uninstall/uninstall_blockers`（`shipyard.view._current_modules` 输出 `effect`）。
- 槽位卡按 `ship.modules[]` 行的 `condition` 显示「状态 NN%」徽标（满状态不显示；0 为失效红色），条件值来自模块实例层，页面不自行计算。
- 槽位反推（`_build_slots`）：船体/锅炉/导航/安全各 1，`cabin_slots≥1` 时加客舱 1，`cargo_slots` 个货舱槽（至少覆盖已装货舱数）；槽位 id `<content_type>_<index>`，fixed 仅船体/锅炉。
- 拖放 `_on_slot_drop`：类型一致且 source ∈ {warehouse, transit} 才发 `ship.install_module{module_id, source}`；槽位已有且不同件时补 `replace_module_id`。点击购买行 `_on_part_activated` 发 `ship.install_module{module_id}`；点击贴片只切到同类分类并高亮兼容行。
- 杂项页签 `_build_misc_body`：打造订单 + 在港等待 6/12/24 h + 仓库材料（固定 5 件存/取）+ 仓库模块（免费安装 / 取出）；模块类分类内仍各自保留「按配方打造」与「购买并安装」。
- 旧整页下方面板已删除：`_stage_row/_parts_hud/_victory_plan/_orders_panel/_warehouse_panel/_craft_panel/_build_purchase_panels` 不再存在；通关条件清单只在总览页。
- 所有 can_install/can_uninstall/can_craft、blockers、价格与工时来自 shipyard.view；页面只翻译原因、禁用按钮与组织布局。
- 密集字段（模块行、限制原因、按钮）用 AUTOWRAP_OFF 单行；操作列描述/效果行用 `_wrap_label` 允许换行，避免固定宽度列被撑开。
- 摘要行的「改装 / 完成改装」按钮直接连 `_on_toggle_refit`（按钮在 `_body` 外，可同步重建）；`_body` 内的分类按钮走 `_ui_set_category` → `set_category.call_deferred`，避免按钮在自身信号里被 `free()`。

## 重点逻辑

### `_rebuild_layout()`

- 清空 `_body` 子节点并重建当前布局；同时重置 `_stage/_stage_title/_stage_hint/_hud_rows`，最后 `_sync_refit_ui()` 同步改装按钮文案与 stage mode。
- 正常态与改装态互斥，仅靠 `_refit` 分支决定三列内容，不保留隐藏面板。

### `set_category(category)`

- 测试与 Shell 可直接调用；当前不在改装态时先置 `_refit=true` 并发 `refit_mode_changed(true)`，再记录分类、发 `refit_category_changed`、重建布局。
- 页面从 `vm.category` 恢复同一分类；非法值回退 `hulls`，Shell 只需保存字符串。

### `_build_misc_body(box)`

- 在港等待按钮按 `wait_options`（默认 6/12/24 h）动态生成 `port.wait`；订单行显示剩余工时，不在当前港时追加港口名。
- 仓库材料行按 `min(5, ship_amount/amount)` 生成存/取命令参数；仓库模块行在 can_install 时给免费安装，始终给取出。

模块索引：[framework/ui](../../README.md)
