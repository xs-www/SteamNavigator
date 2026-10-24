# `framework/ui/screens/port/shipyard_screen.gd`

> 作用：船厂页两种布局共用一页：正常态为「已有船舶卡片 / 面板内 3D 船体舞台 / 组件分类入口」；改装态是画在连续港区 `shipyard` 站位上的船厂工作台——左侧九宫格蓝图底板、中间 3D 窗口、右侧半透明操作坞（舰船数据卡 + 七项分类 + 装配/购买/打造三个独立页签）。规则仍来自 `shipyard.view`，页面不写 `GameState`。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardScreen` | L1 |
| `command_requested (signal)` | L30 |
| `refit_mode_changed (signal)` | L31 |
| `refit_category_changed (signal)` | L32 |
| `CATEGORY_ORDER` | L34 |
| `MODULE_CATEGORIES` | L35 |
| `TYPE_LABELS` | L36 |
| `SLOT_TITLES` | L37 |
| `SLOT_DEFS` | L39 |
| `CARGO_CATEGORY` | L46 |
| `TAB_ORDER` | L49 |
| `SHIP_THUMB_PATH` | L50 |
| `CATEGORY_ICONS` | L53 |
| `TAB_ICONS` | L63 |
| `SLOT_ICONS` | L71 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L104 |
| `set_category(category: String) -> void` | L210 |
| `set_tab(tab: String) -> void` | L228 |

- 关键依赖：`SNShipView`、`SNPartRow`、`SNBadge`、`SNButton`、`SNSectionHeader`、`SNSkin`、`steam_navigator_theme.tres`

## 外观来源（外部贴图 + SNSkin）
- 面板仍由 Theme variation 绘制：正常态 `SNInsetPanel` / `SNElevatedPanel`，改装态 `SNBlueprintPanel`（左列）+ `SNGlassPanel`（右列操作坞）；页面不内联手搓 stylebox。
- 文字与状态色一律取 `SNSkin.color(token)`，本文件不写十六进制颜色；图标取 `SNSkin.icon(id)`。
- 分类按钮与操作页签用 `Button.icon` + `icon_max_width`（16–18）直接挂皮肤图标，不新增包装容器，按钮 `text` 保持不变（测试与 tooltip 按文字查找）。
- 分类映射：hulls/boiler/cargo/cabin → shipyard_hull/boiler/cargo/cabin，utility → shipyard_navigation，weapons/misc → nav_shipyard；页签 install/buy/craft → action_confirm/resource_coins/action_add。
- 槽位卡图标 id 通过槽位描述里的 `icon` 字段交给 `SNSlotTarget`（是否渲染由该组件决定，页面不改它）。

## 契约与约束
- `bind(vm, translate)` 接收 Shell 组合后的 shipyard.view（含 refit/category/ship.hull_name/warehouse/candidates/craft/orders/wait_options），不访问 AppContext、QueryBus、CommandBus 或注册表；`_build_page()` 每次整体重建，可重复 bind。
- `_build_page()` 先把旧根节点 `remove_child` 后 `queue_free`（不是立即 free），所以操作坞里的「完成改装」按钮可以在自己的 `pressed` 信号里重建整页；绑定/切模式/切分类/切页签都走这一个入口。
- `CATEGORY_ORDER` = 船体/锅炉/货舱/通用/客舱/武器/杂项；`TAB_ORDER` = 装配(install)/购买(buy)/打造(craft)。`set_category` 只接受声明值，未在改装态时先置 refit 并发 `refit_mode_changed(true)`，同时把页签重置为装配；`set_tab` 只切页签（相同值 no-op）。
- `_body` 固定三列：正常态 `_ship_list_panel / _render_panel / _components_panel`；改装态 `_blueprint_panel / _stage_window / _refit_dock_panel`（`StageWindow` 空 Control、`RefitDock` 操作坞）。正常态保留章节标题与摘要行，改装态不显示标题/摘要行。
- 改装态画在 3D 港区舞台上：Shell 的 `STAGE_SCREENS` 含 `shipyard→shipyard` 且只在 `_shipyard_refit` 时显示；`_stage_window()` 是可让 3D 透出的空 Control（MOUSE_FILTER_IGNORE），蓝图板/操作坞用 `size_flags_stretch_ratio` 1.2 / 0.25 分配宽度。
- 左列蓝图：`SNBlueprintPanel` + `SNShipView(CUTAWAY)`（`set_blueprint_backdrop(true)`），侧视/俯视等比绘制、武器框按 `weapon_sockets[].blueprint` 映射，槽位贴片停靠蓝图底部 dock。
- 右列操作坞：顶部为当前分类标题 + 槽位计数徽标 + `_refit_button`（正常态在摘要行、改装态在坞头，文案 改装/完成改装）；`_ship_data_card()` 显示船名与重量·耐久·货舱槽·客舱槽·武器·剩余货舱；`_category_picker()` 两行七项分类；`_tab_row()` 三个页签。
- 装配页：当前分类的槽位卡 + 仓库/随船可拖行（`SNPartRow`，登记在 `_hud_rows`）+ 拖放提示；`_highlight_category_slots()` 把可安装槽位贴片高亮成青色（武器分类高亮蓝图武器框），购买/打造页清空高亮。拖放命令仍是 `ship.install_module{module_id, source, slot?, replace_module_id?}`。
- 购买页：`candidates`（武器分类用 `weapon_candidates`）；打造页：`craft` 配方 + `ship.craft_module`。两者与装配列表完全分离；socket/module 长名用 `_clip_title()` 省略号截断，避免撑宽固定宽度操作坞。
- `杂项` 分类不显示页签，直接展示打造订单 / 在港等待（6/12/24 h `port.wait`）/ 仓库材料 / 仓库模块；页面不重复通关条件清单（只在总览页）。
- 所有 can_install/can_uninstall/can_craft、blockers、价格与工时来自 shipyard.view；页面只翻译原因、禁用按钮与组织布局。
- 固定尺寸保持：正常态 258 / 弹性 / 300；改装态 560 / 140 / 432；船卡缩略图 210×118；分类按钮 116×34 / 30 / 32；页签 32；蓝图板参数由 Theme 提供（841×299、56/54、66/62）不得改。

模块索引：[framework/ui](../../README.md)
