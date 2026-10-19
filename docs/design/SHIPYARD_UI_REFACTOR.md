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
- 所有命令仍经 `command_requested` 交回 Shell，由 `CommandBus` 执行、存档与反馈错误；页面不写 `GameState`。

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
