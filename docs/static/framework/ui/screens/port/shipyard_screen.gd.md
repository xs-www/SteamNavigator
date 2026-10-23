# `framework/ui/screens/port/shipyard_screen.gd`

> 作用：船厂页两种布局共用一页：正常态为「已有船舶卡片 / 面板内 3D 船体舞台 / 组件分类入口」；改装态是画在连续港区 `shipyard` 站位上的船厂工作台——左侧九宫格蓝图底板、中间 3D 窗口、右侧半透明操作坞（舰船数据卡 + 七项分类 + 装配/购买/打造三个独立页签）。规则仍来自 `shipyard.view`，页面不写 `GameState`。

- 关键依赖：`SNShipView`、`SNPartRow`、`SNBadge`、`SNButton`、`SNSectionHeader`、`steam_navigator_theme.tres`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardScreen` | L1 |
| `command_requested (signal)` | L18 |
| `refit_mode_changed (signal)` | L19 |
| `refit_category_changed (signal)` | L20 |
| `TEXT` | L22 |
| `MUTED` | L23 |
| `BRASS` | L24 |
| `TEAL` | L25 |
| `RED` | L26 |
| `GREEN` | L27 |
| `CATEGORY_ORDER` | L28 |
| `MODULE_CATEGORIES` | L29 |
| `TYPE_LABELS` | L30 |
| `SLOT_TITLES` | L31 |
| `SLOT_DEFS` | L33 |
| `CARGO_CATEGORY` | L40 |
| `TAB_ORDER` | L43 |
| `SHIP_THUMB_PATH` | L44 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L60 |
| `set_category(category: String) -> void` | L166 |
| `set_tab(tab: String) -> void` | L184 |

## 契约与约束

- `bind(vm, translate)` 接收 Shell 组合后的 shipyard.view（含 refit/category/ship.hull_name/warehouse/candidates/craft/orders/wait_options），不访问 AppContext、QueryBus、CommandBus 或注册表；`_build_page()` 每次整体重建，可重复 bind。
- `_build_page()` 先把旧根节点 `remove_child` 后 `queue_free`（不是立即 free），所以操作坞里的「完成改装」按钮可以在自己的 `pressed` 信号里重建整页；绑定/切模式/切分类/切页签都走这一个入口。
- `CATEGORY_ORDER` = 船体/锅炉/货舱/通用/客舱/武器/杂项；`TAB_ORDER` = 装配(install)/购买(buy)/打造(craft)。`set_category` 只接受声明值，未在改装态时先置 refit 并发 `refit_mode_changed(true)`，同时把页签重置为装配；`set_tab` 只切页签（相同值 no-op）。
- `_body` 固定三列：正常态 `_ship_list_panel / _render_panel / _components_panel`；改装态 `_blueprint_panel / _stage_window / _refit_dock_panel`（`StageWindow` 空 Control、`RefitDock` 操作坞）。正常态保留章节标题与摘要行，改装态不显示标题/摘要行。
- 改装态画在 3D 港区舞台上：Shell 的 `STAGE_SCREENS` 含 `shipyard→shipyard` 且只在 `_shipyard_refit` 时显示，页面不再自带整页不透明背景；`_stage_window()` 是可让 3D 透出的空 Control（MOUSE_FILTER_IGNORE），蓝图板/操作坞用 `size_flags_stretch_ratio` 1.2 / 0.25 分配宽度。
- 左列蓝图：`SNBlueprintPanel` + `SNShipView(CUTAWAY)`（`set_blueprint_backdrop(true)`），不再有「改装蓝图 / 蓝图线稿 / 贴图剖面」标题与徽标；侧视/俯视等比绘制、武器框按 `weapon_sockets[].blueprint` 映射，槽位贴片停靠蓝图底部 dock。
- 右列操作坞：Theme variation `SNGlassPanel`（半透明）。顶部为当前分类标题 + 槽位计数徽标 + `_refit_button`（正常态在摘要行、改装态在坞头，文案 改装/完成改装）；`_ship_data_card()` 显示船名与重量·耐久·货舱槽·客舱槽·武器·剩余货舱；`_category_picker()` 两行七项分类；`_tab_row()` 三个页签。
- 装配页：当前分类的槽位卡 + 仓库/随船可拖行（`SNPartRow`，登记在 `_hud_rows`）+ 拖放提示；`_highlight_category_slots()` 把可安装槽位贴片高亮成青色（武器分类高亮蓝图武器框），购买/打造页清空高亮。拖放命令仍是 `ship.install_module{module_id, source, slot?, replace_module_id?}`。
- 购买页：`candidates`（武器分类用 `weapon_candidates`）；打造页：`craft` 配方 + `ship.craft_module`。两者与装配列表完全分离；socket/module 长名用 `_clip_title()` 省略号截断，避免撑宽固定宽度操作坞。
- `杂项` 分类不显示页签，直接展示打造订单 / 在港等待（6/12/24 h `port.wait`）/ 仓库材料 / 仓库模块；页面不重复通关条件清单（只在总览页）。
- 武器交互：槽位卡与购买候选卡悬停时 `SNShipView.highlight_slots()` 高亮对应蓝图框，离开恢复当前分类高亮（`_highlight_all_weapon_sockets()` / `_highlight_category_slots()`）。
- 所有 can_install/can_uninstall/can_craft、blockers、价格与工时来自 shipyard.view；页面只翻译原因、禁用按钮与组织布局。密集字段（模块行、限制原因、按钮）用 AUTOWRAP_OFF 单行，操作坞描述/效果行用 `_wrap_label` 允许换行。
- 旧整页下方面板（`_stage_row/_parts_hud/_victory_plan/_orders_panel/_warehouse_panel/_craft_panel/_build_purchase_panels`）不再存在；测试向文案（`ui.label.stage_blueprint` / `ui.tag.blueprint_lineart` / `ui.tag.section_texture` / `ui.hint.live_render` / `ui.hint.ship_list`）不再渲染。
- 窗口适配：改装页在 PageScroll 内，页面根 `SIZE_EXPAND_FILL` 填满可视高度；三列最小宽 560 / 140 / 432，1440 逻辑宽度下不会横向溢出，窄窗口交给外层 PageScroll。

## 重点逻辑

### `_build_page()`

- 清空根节点（detach + queue_free）并重置 `_stage/_stage_title/_body/_refit_button/_hud_rows`，按 `_refit` 选择 `_build_normal_page()` 或 `_build_refit_page()`，最后 `_sync_refit_ui()` 同步按钮文案与 stage mode。
- 正常态与改装态互斥；正常态才添加 `_heading()` 与 `_summary_row()`，改装态的三个子节点固定为蓝图 / 3D 窗口 / 操作坞。

### `set_category(category)`

- 测试与 Shell 可直接调用；非法值直接 return，未在改装态时先置 `_refit=true` 并发 `refit_mode_changed(true)`，再记录分类、重置 `_tab=install`、发 `refit_category_changed`、`_build_page()`。
- 页面从 `vm.category` 恢复同一分类；非法值回退 `hulls`，Shell 只需保存字符串。

### `set_tab(tab)`

- 只接受 `TAB_ORDER` 中的值，相同值 no-op；页签切换重建整页（蓝图纹理走静态缓存，不重复解码）。

### `_build_tab_body(box)`

- `杂项` 直接走 `_build_misc_body`；其它分类按 `_tab` 分派到 `_build_install_body` / `_build_buy_body` / `_build_craft_body`，武器分类分别走 `_build_weapon_install_body` / `_build_weapon_buy_body`。

### `_ship_data_card()`

- 数据全部来自 ship VM（total_weight/max_weight、durability、cargo_used/slots、cabin_used/slots、weapon_sockets、free_cargo_capacity/capacity），缺失字段回退 0；顶栏已有金币/资源，数据卡不重复。

### `_build_misc_body(box)`

- 在港等待按钮按 `wait_options`（默认 6/12/24 h）动态生成 `port.wait`；订单行显示剩余工时，不在当前港时追加港口名。
- 仓库材料行按 `min(5, ship_amount/amount)` 生成存/取命令参数；仓库模块行在 can_install 时给免费安装，始终给取出。

模块索引：[framework/ui](../../README.md)
