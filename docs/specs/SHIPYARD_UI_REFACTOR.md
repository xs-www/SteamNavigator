# 船厂界面重构（图 2 / 图 3 布局）

> 状态：已完成（本轮文档归档时的验收：船厂/UI 套件 105/105 全绿）。
> 相关代码：`framework/ui/screens/port/shipyard_screen.gd`、`framework/ui/components/sn_ship_view.gd`、`framework/ui/shell/main.gd`、`framework/application/queries/shipyard_view.gd`。
> 相关测试：`framework/tests/cases/test_shipyard_refit.gd`（8 例）、`framework/tests/cases/test_ui_shell.gd`。

## 背景与需求

上一版船厂页是「中央改装台 + 右侧部件 HUD + 下方一长串面板（通关清单 / 打造订单 / 港口仓库 / 配方 / 可购买模块）」。用户给出两张参考图，要求：

1. 主界面只显示到改装台 / 组件 HUD；下方旧的打造订单、港口仓库、配方、可购买模块、通关清单面板全部删除。
2. 常规布局：左「已有船舶」贴图船卡，中心 `SNShipView` 实机渲染占位，右「组件」分类入口（点击进入改装）。
3. 改装展开布局：左船体纵剖图（授权贴图 `assets/ui/shipyard/ship_section.png`，不再是运行时多边形拼接），中间所选分类的槽位信息 / 装配 / 购买 / 打造操作卡，右侧竖排分类页签（船体 / 锅炉 / 货舱 / 导航 / 安全 / 客舱 / 杂项）。
4. 旧功能全部保留入口：分类面板内购买 / 打造 / 卸下 / 拖拽装配；杂项页签承载打造订单、在港等待、仓库材料与仓库模块；通关条件只在总览页。

## 布局对照

### 正常态（`_refit == false`）

| 列 | 内容 | 构建函数 |
| --- | --- | --- |
| 左（258 px 起） | 「已有船舶」标题 + 船卡（`ship_thumb_ironclad.png` 210×118 cover，缺失回退占位面板）+ 重量 / 耐久 / 货舱 / 客舱 + 单船提示 | `_ship_list_panel()` / `_ship_card()` |
| 中（拉伸） | 「当前船只 · 实机渲染」+ `SNShipView(EXTERIOR)` 程序化侧视 + 2.5D 接入提示 | `_render_panel()` |
| 右（300 px 起） | 「组件」六类入口（船体 / 锅炉 / 货舱 / 导航 / 安全 / 客舱），每行带槽位计数；底部「改装流程」三步提示与槽位摘要 | `_components_panel()` / `_category_row()` |

### 改装态（`_refit == true`，由分类点击或「改装」按钮进入）

| 列 | 内容 | 构建函数 |
| --- | --- | --- |
| 左（拉伸） | 「纵剖图」+ `SNShipView(CUTAWAY)`：授权贴图背景 + 每槽位一枚 `SNSlotTarget` 贴片 + 舱室引线 | `_section_panel()` |
| 中（404 px 起，纵向滚动） | 当前分类标题与槽位数徽标；槽位卡（已装模块、效果、重量/tier、卸下按钮、限制原因）→ 仓库/随船可拖行 → 购买并安装卡 → 按配方打造卡 | `_operations_panel()` / `_build_category_body()` |
| 右（164 px 起） | 「部件分类」竖排页签，七个分类；当前分类高亮 | `_category_tabs_panel()` |

- 三列由 `_body: HBoxContainer` 承载，页面其余部分只有标题与摘要行；`_rebuild_layout()` 只重建 `_body`，所以两态切换不会重建整页。
- 操作列是**唯一滚动区域**（`ScrollContainer`，横向滚动禁用），槽位 / 购买 / 打造内容再多也不会把整页撑长。

## 删除的面板与命令迁移

旧函数已从 `shipyard_screen.gd` 删除：`_stage_row`、`_parts_hud`、`_victory_plan`、`_orders_panel`、`_warehouse_panel`、`_craft_panel`、`_build_purchase_panels`。

| 旧面板 / 旧入口 | 旧命令 | 新位置 |
| --- | --- | --- |
| `_victory_plan` 通关条件清单 | —（只读） | 只保留在**总览页**（`port.view.victory.conditions`）；船厂页不再渲染。测试用 `LEGACY_SECTION_KEYS` 扫描保证不回流 |
| `_orders_panel` 打造订单 + 在港等待 | `port.wait` | 改装态「杂项」页签上半部（订单剩余工时 + 不在本港时港口名；6/12/24 h 按钮来自 `wait_options`） |
| `_warehouse_panel` 仓库模块 / 材料 | `ship.install_module(source=warehouse)`、`warehouse.take_module`、`warehouse.store_materials`、`warehouse.take_materials` | 改装态「杂项」页签下半部（材料固定 5 件批量存/取；仓库模块免费安装 / 取出） |
| `_craft_panel` 配方与打造 | `ship.craft_module` | 各模块类型分类内的「按配方打造」区块（材料持有/需求、费用、工时、限制原因） |
| `_build_purchase_panels` 可购买模块 | `ship.install_module` | 各模块类型分类内的「购买并安装」区块（效果、价格、重量、限制原因） |
| `_parts_hud` 已装 / 仓库 / 随船 / 购买行 | 拖拽 + 点击购买 | 改装态中间操作列（`SNPartRow` 可拖行 + 购买卡） |
| `_stage_row` 中央改装台 + HUD | — | 拆分：正常态 `_render_panel()`、改装态 `_section_panel()` + `_operations_panel()` |

- 「已装模块」在分类内以**槽位卡**表达：显示模块名、效果行（`ship.modules[].effect`）、重量 / tier、卸下按钮与 `uninstall_blockers` 原因。
- 拖拽装配协议不变：`_on_slot_drop` 只接受同类型且 `source ∈ {warehouse, transit}`，发 `ship.install_module{module_id, source}`；槽位已有不同件时补 `replace_module_id`。
- 拖放载荷形状（2026-10-26 修复）：`SNPartRow._get_drag_data()` 产出 `{kind:"ship_parts", part:{...}}`；`SNSlotTarget._drop_data` 必须把**整个载荷**从 `part_dropped` 转发，页面 `_on_slot_drop` 按 `payload.part` 解析（同时兼容裸 part 字典）。只转发内层 `part` 会让真实鼠标拖放静默失效（空槽安装 / 已装替换都不发命令），而直接调用页面函数的测试看不出问题——回归用 `test_drag_drop_installs_into_empty_slot_and_replaces_filled_slot` 走 `SNSlotTarget._drop_data` 的真实链路。
- 所有命令仍经 `command_requested` 交回 Shell，由 `CommandBus` 执行、存档与反馈错误；页面不写 `GameState`。

### 武器分类（2026-10-27 玩家反馈）

玩家反馈「装配后不知道装在哪、右侧显示后端 ID、左侧框没有变化、武器不能拖动安装」，武器分类按以下契约实现：

- **玩家文案**：socket 标准名（`SN_Socket_Weapon_Port_1` / `Starboard_1` / `Bow` / `Stern` / `_2`）与 `socket_class`（Light/Medium/Heavy/Side/Tower）在 UI 层映射为「左舷 1 号炮位 · 轻型」类文案（本地化键 `ui.weapon_socket.*` / `ui.weapon_class.*`）；安装页、购买页、仓库武器按钮与蓝图贴片**不得出现 `SN_Socket_Weapon_*` 后端 ID**。未知 name 兜底为「武器槽位 N」。
- **右侧操作坞**：安装页每个炮位一张 `SNWeaponSocketCard`（友好炮位名 + `已装` 徽标 + 已装武器本地化名 / `空槽位` + 重量·伤害 + 卸下按钮）；仓库武器与购买候选用 `SNWeaponRow` 可拖行条目（`{kind:"ship_weapon", weapon_id, weapon_class, source:"warehouse"|"purchase", name}`），行内保留「装到 左舷1 / 购买并安装」显式按钮。
- **左侧蓝图**：`SNShipView` 的炮位贴片（`SNWeaponSocketTarget`，2026-10-27 层）按本地化 `slot_label` / `display_name` / `occupied` 绘制——空槽暗色、已装黄铜填充 + 武器名、武器分类高亮只加青色描边不掩盖已装状态；锚点重叠的炮位（Port/Starboard 同一 blueprint 坐标）垂直扇出，保证每枚贴片与文字可分辨。`blueprint_socket_rects()` 的既有语义不变，新增 `weapon_socket_display_rects()`。
- **拖放**：炮位贴片与右侧槽位卡都是 `ship_weapon` 载荷的落点（等级匹配才接受；已装同型同 id 拒绝）；页面在「武器分类 + 装配页签 + 改装态」调用 `stage.set_weapon_drop_enabled(true)`，落点统一走 `_on_weapon_drop(payload, socket)` → `ship.install_weapon{socket, weapon_id, source}`。失败原因由命令层状态栏提示。
- **数据注入**：`_stage_ship_model()` 把 `shipyard.view.ship.weapon_sockets` 补上 `slot_label` / `slot_title` / `display_name` / `empty_text` / `installed_tag` / `occupied` 后交给 `SNShipView`；后端键不变。
- **回归**：`test_weapon_sockets_show_player_mount_names_and_drag_install`（友好文案、无后端 ID、仓库武器 `_can_drop_data`/`_drop_data` 真链路安装、重建后卡片/蓝图数据变为已装、class 不匹配拒绝）+ `test_weapon_sockets_project_blueprint_positions_into_stage_frames`（蓝图锚点/高亮契约）。

## 状态与信号

- `refit_mode_changed(active: bool)`：进入 / 退出改装态。Shell 写入 `_shipyard_refit`。
- `refit_category_changed(category: String)`：所选分类。Shell 写入 `_shipyard_category`（默认 `hulls`）。
- `set_category(category)`：测试与 Shell 可调用；非法值直接 return。若当前不在改装态，先置 `_refit = true` 并补发 `refit_mode_changed(true)`，再发 `refit_category_changed` 并重建。
- `bind()` 每次从 `vm.refit` / `vm.category` 恢复；`main.gd._shipyard_model()` 把两者与 `ship.hull_name` 一并注入。整页重建、切页、命令刷新后都保持「改装态 + 分类」。
- 页面内部常量：`MODULE_TYPES`（六类模块）与 `CATEGORY_ORDER`（六类 + `misc`）；`TYPE_LABELS` / `_category_label()` 负责中文分类名。

## 贴图资产契约

| 路径 | 尺寸 | 用途 | 生成 |
| --- | --- | --- | --- |
| `assets/ui/shipyard/ship_section.png` | 1792×1008（16:9） | 改装态纵剖图整幅背景 | `python tools/art/gen_shipyard_textures.py` |
| `assets/ui/shipyard/ship_thumb_ironclad.png` | 640×360 | 正常态船卡缩略图 | 同上（`--thumb-only` 只重导缩略图） |

- 生成器 `tools/art/gen_shipyard_textures.py` 用 Pillow + numpy 确定性绘制，配色对齐 `assets/ui/tokens.json` 与 `SNShipView` 常量；构图锚点在文件顶部 `ANCHORS` / `DECK_Y` / `KEEL_Y` / `WATER_Y`。
- `SNShipView.SECTION_TEXTURE_PATH` 指向纵剖图；`_ready()` 时 `ResourceLoader.exists` 才加载，`_draw_section_texture()` 做 cover 裁切 + 0.18 暗青蒙版。**贴图缺失时自动回退 `_draw_cutaway_placeholder()` 程序化剖面**，船卡缺失时回退「船舶缩略图」占位面板，不会白屏。
- 槽位布局固定在 `h*0.60`（非货舱行）与 `h*0.82`（货舱行）；`_chip_anchor()` 的舱室比例要与生成器 `ANCHORS` 保持一致（明轮 / 锅炉 / 货舱 / 安全 / 导航 / 客舱）。
- 正常态中央的 `EXTERIOR` 侧视**仍是程序化 2D 占位**（水面 / 烟 / 明轮动画），本轮没有换成贴图或 3D。

## 测试与截图证据

- `test_shipyard_refit.gd` 8 例：正常态三列与组件入口、改装态 + 模式/分类记忆、纵剖图贴图契约、船卡缩略图、2.5D 渲染器替换、仓库模块拖拽安装、分类导航 + 杂项承载旧操作、旧面板消失（`_body` 恰好 3 列）。
- `test_ui_shell.gd`：通关清单只在总览（船厂不再重复）、锻造入口在模块分类内、下单后重建仍保持改装态与分类、在港等待在杂项页签、密集字段横向排版（新增港口记忆页）。
- 本轮验证：全量套件 **109 / 109 通过**（`godot --headless --script res://framework/tests/test_runner.gd`，exit code 仅受已知 headless ObjectDB/resource-leak stderr 警告影响）；船厂 / UI 相关用例全部 PASS。
- 截图（1440×900 窗口实拍，`pwsh ./tools/capture_ui.ps1`）：
  - `docs/design/screenshots/shipyard_normal.png`
  - `docs/design/screenshots/shipyard_refit.png`
  - `docs/design/screenshots/shipyard_refit_cargo.png`
  - `docs/design/screenshots/shipyard_refit_misc.png`
- 截图工具：`tools/ui_snapshot.gd`（真实渲染 + 模式/分类断言 + 120 s watchdog）+ `tools/capture_ui.ps1`（`-GodotBin` / `GODOT_BIN`，校验产物新鲜度）。旧图 `shipyard_refit_exterior.png` / `shipyard_refit_cutaway.png` 已不再被 README 引用（文件仍在磁盘上，属历史产物）。

## 已知缺口

- 正常态中央「实机渲染」仍是 `SNShipView(EXTERIOR)` 的程序化 2D 占位；2.5D 舞台只预留了 `set_renderer()` 协议，未接入真实 3D 场景。
- 改装态纵剖图是**一张授权 2D 贴图**，不是 3D 场景，也不随船体实体变化；换船体 / 槽位数量变化时靠槽位贴片布局适配。
- 贴图与当前可玩船型视觉不完全一致：纵剖图与船卡画的是铁甲舰风格（60 m 级），而目前可玩船体是小型船体等 4 种 Core 船体。
- 操作列内容多时依赖纵向滚动；购买 / 打造 / 仓库材料目前都是卡内按钮，没有批量选择或数量步进。
- 左列「已有船舶」仍是单船展示（1 / 1），多坞位 / 多船选择未实现。

## 2026-10-28 玩家反馈轮（P1 分类对齐 / P2a 武器分离 / P2b 侧视蓝图）

玩家四条反馈：① 交互限制有问题，框与按钮不在一个地方（P0，属教程引导遮罩，见 [STORY_TUTORIAL.md](../design/STORY_TUTORIAL.md) §8）；② 改装界面还需优化，部件按钮分类没有对齐；③ 安装武器与常规改装需要分离；④ 常规改装也要在船体槽位处画点，并用折线连到旁边的模块方框；可暂时移除俯视图只保留侧视图。

### 操作坞：6 类对齐 + 武器独立模式（P1 / P2a）

- 右侧操作坞坞头新增 `RefitModeSwitch`（`部件改装` / `武器装配` 两块等宽模式板）；模式状态仍复用 `_category`（`weapons` = 武器模式），`set_category("weapons")` / `set_weapon_mode()` / `set_module_mode()` 仍可供 Shell、测试与截图工具驱动。
- 常规模式 `CategoryPicker` 只列 6 个常规分类（船体/锅炉/货舱/通用/客舱/杂项），`GridContainer.columns = 3`，每个按钮 `SIZE_EXPAND_FILL`，即 3×2 等宽对齐；舰载武器不再是分类按钮。
- 武器模式隐藏分类网格，改显示一行说明（`ui.hint.weapon_refit_mode`），页签只保留装配 / 购买（`WEAPON_TAB_ORDER`），`set_tab("craft")` 在武器模式下被拒绝；`_build_tab_body()` 另有一层守卫，避免旧 `_tab` 渲染出模块配方。
- 蓝图侧隔离：常规模式只显示模块槽位圆点/方框（`set_module_chips_visible(true)` + `set_weapon_patches_visible(false)`）；武器模式相反。旧无 `blueprint_views` 的船体忽略两个开关，保持底部 dock。
- 新增本地化键 `ui.label.refit_mode_modules` / `ui.label.refit_mode_weapons` / `ui.hint.weapon_refit_mode`（zh_CN + en 同步，slot 数一致）。

### 侧视蓝图：圆点 + 点线 + 底部标注带（P2b，含第二版调整）

- `SNShipView` 在 `CUTAWAY` 且内容绑定了 `blueprint_views` 时**只绘制侧视图**（`_blueprint_drawn_view()` 优先 side）；`blueprint_view_rect("top")` / `blueprint_socket_rects("top")` 保留旧公式仅作兼容与数据校验，`_weapon_views()` 只返回 `["side"]`（只绑定 top 的内容回退 top）。
- **方框移出侧视图（第二版，玩家要求「把这些槽位从侧视图上移走，用点线连过去」）**：舞台底部保留一条标注带 `chip_band_rect()`（深色凹槽 + 顶部分隔线），普通模块方框与武器贴片全部排进带内、不再压在线稿上；每个槽位在船体锚点处保留圆点，用**点线（dashed leader）**连到方框顶边。`slot_dock_height()` 返回标注带高度（旧 API 名保留）；线稿在「舞台 − 标注带」区域内等比适配。
- 标注带行数/容量确定：`floor((可用宽 + gap) / (最宽方框 + gap))` 个/行，行高取该行最高方框；带高 = 边距 + 行高 + 行距，最多占舞台高度 55%。带内每行按锚点 x 排序、方框尽量居中在自己的圆点下方（右侧过挤时该行退化为左对齐平铺），保证互不重叠、始终在带内、始终在侧视图之外；行内方框也会被 clamp 回带内。
- 槽位锚点来自内容：`shipyard.view.data.ship.slot_anchors`，由 Core hull `data.module_slots[]` / `data.compartments[]` 的 `blueprint_position.side`（0..1、左上原点、相对 `space:"trimmed"` 侧视线稿）投影而成；键为 `hull` / `boiler` / `navigation_module` / `safety_module` / `passenger_cabin` / `cargo_modules[]`（按 x 排序，序号对应 UI 货舱槽）。内容没给锚点时返回 `{}`，UI 用面板内通用锚点兜底，旧内容 / SDK 模板不崩。
- Core 4 艘船已补 `module_slots` / `compartments` 侧视坐标（`hulls.json`），`hull` 槽位未单独声明时用其它锚点质心兜底。
- `SNShipView` 新公开 API：`slot_anchor_rects()`（圆点）/ `slot_chip_rects()`（模块方框）/ `chip_band_rect()`（标注带）/ `slot_leader_lines()`（点线两端）/ `set_module_chips_visible()` / `set_weapon_patches_visible()` / `module_chips_visible()` / `weapon_patches_visible()`；隐藏组的圆点、方框、贴片不绘制且关闭拖放接收，`weapon_targets()` 数量仍等于 socket 数。
- `SNSlotTarget` 新公开 API：`set_compact(bool)`（两行、字号 10/12、隐藏 hint）、`set_drop_enabled(bool)` / `is_drop_enabled()` / `is_hovering()`；载荷契约（完整 `ship_parts` payload）与信号不变。槽位贴片水平内容边距 20 px，避开 `panel_recess` 九宫格 19 px 角饰（此前 8 px 时分类标题首字压在角饰上，即玩家所说「分类没有对齐」的一部分）。
- 回归：`framework/tests/cases/test_shipyard_blueprint.gd`（8 例：单侧视、四艘船的锚点圆点、方框/贴片全部落在标注带且不与侧视图相交、点线从圆点连到方框、无锚点回退、单视图武器贴片、模式隔离、高亮联动）；`test_shipyard_refit.gd` 的 top 双视图旧断言改为「top 仅兼容可计算、不再绘制贴片」，并新增 `test_refit_dock_splits_weapon_install_from_regular_refit`。
- 截图（1440×900，窗口模式）：`docs/design/screenshots/_check5/shipyard_refit.png`（圆点 + 点线 + 底部标注带）、`shipyard_refit_weapons.png`（武器模式同带排布）、`shipyard_refit_cargo.png`（分类高亮）。

### 已知缺口（本轮新增）

- 俯视图暂时移除：等每船 `blueprint_views.top` 与槽位锚点的作者流程补齐后再考虑恢复双视图；top 系列 API 仍在。
- 4 艘 Core 船的锚点坐标为人工按侧视线稿标定（0.1/0.02 网格 + 截图复核），后续可接入 `apply_hull_blueprints.mjs` 的编辑器拾取流程。
- 极窄面板（远小于 320×150）时标注带占比会逼近 55% 上限，线稿相应变小；960×540 已走非重叠路径。

