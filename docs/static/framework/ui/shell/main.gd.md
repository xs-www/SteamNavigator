# `framework/ui/shell/main.gd`

> 作用：可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并把已迁移页面挂载到场景宿主；主界面采用「全窗 3D 港口舞台 + 紧凑顶部 chrome + 两侧设施招牌 + 底部状态条 + 详细总览抽屉」的 Bounty Train 式分层，2D 总览保留为回退/可访问性开关。自第七切片起总览/市场/补给三页共用同一座连续 3D 港区：页面切换只是平移镜头、把玩家的船开到对应泊位并换上右侧泊位面板，不重挂舞台、不过黑场；市场/补给页改为右侧 640 px 泊位面板，左侧保留舞台。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI_THEME` | L8 |
| `HARBOR_SIGN_SCRIPT` | L10 |
| `MARKET_SCREEN_SCENE` | L11 |
| `CONTRACTS_SCREEN_SCENE` | L12 |
| `SUPPLY_SCREEN_SCENE` | L13 |
| `INTEL_SCREEN_SCENE` | L14 |
| `VOYAGE_SCREEN_SCENE` | L15 |
| `OVERVIEW_SCREEN_SCENE` | L16 |
| `SHIPYARD_SCREEN_SCENE` | L17 |
| `PORT_MEMORY_SCREEN_SCENE` | L18 |
| `SETTLEMENT_SCREEN_SCENE` | L19 |
| `AT_SEA_SCREEN_SCENE` | L20 |
| `EVENT_SCREEN_SCENE` | L21 |
| `VICTORY_SCREEN_SCENE` | L22 |
| `MAIN_MENU_SCREEN_SCENE` | L23 |
| `NEW_GAME_SCREEN_SCENE` | L24 |
| `MODS_SCREEN_SCENE` | L25 |
| `SETTINGS_SCREEN_SCENE` | L26 |
| `COLOR_BG` | L27 |
| `COLOR_PANEL` | L28 |
| `COLOR_PANEL_ALT` | L29 |
| `COLOR_TEXT` | L30 |
| `COLOR_MUTED` | L31 |
| `COLOR_BRASS` | L32 |
| `COLOR_TEAL` | L33 |
| `COLOR_RED` | L34 |
| `COLOR_GREEN` | L35 |
| `DEV_TEAM` | L36 |
| `GAME_VERSION_FALLBACK` | L37 |
| `SCREENS` | L39 |
| `PORT_STAGE_SCENE_PATH` | L42 |
| `PORT_STAGE_FACILITY_SCREENS` | L44 |
| `STAGE_SCREENS` | L56 |
| `DOCK_PANEL_WIDTH` | L63 |
| `TOP_CHROME_MAX_HEIGHT` | L67 |
| `PORT_STATUS_BAR_HEIGHT` | L69 |
| `PORT_STATUS_BAR_GAP` | L70 |
| `PORT_SIGN_WIDTH` | L73 |
| `PORT_SIGN_HEIGHT` | L74 |
| `PORT_SIGN_GAP` | L75 |
| `PORT_SIGN_MARGIN` | L76 |
| `HUD_ICON_KEYS` | L80 |
| `HUD_ICON_SIZE` | L85 |
| `PAGE_BOTTOM_MARGIN` | L88 |
| `PAGE_BOTTOM_MARGIN_WITH_BAR` | L89 |

## 契约与约束

- 所有数据经 QueryBus 获取，所有修改经 CommandBus；UI 不保存规则状态。
- 主界面默认 `_overview_stage_mode=true`：全窗 3D 港口舞台是主视图，2D 详细总览收进 `_overview_detail` 抽屉（默认关闭）；两者都只是 UI 会话状态，不写存档。
- 紧凑顶部 chrome（`_top_chrome`）用两行替代旧 header + stats bar + navigation：第 1 行品牌/状态/版本 + 港口·时间·金钱·声望 + 阶段切换/诊断/刷新，第 2 行剩余载重·货舱·煤·水·耐久·受损 chip + 7 个导航按钮；半透明面板，实测最小高度 ≤130 px（`TOP_CHROME_MAX_HEIGHT`）。
- HUD 图标：`_stat_chip(..., icon_key)` 在标签左侧挂 22 px `TextureRect`；`_hud_icon()` 经 `AssetService.find_key()` 把 `icon.money/coal/water` 解析到任一内容包并缓存 `Texture2D`，缺 key/缺文件时退回纯文字 chip。金币在顶部 chrome，煤炭/淡水同时在顶部与底部状态条。
- 窗口适配：工程为 `canvas_items` 拉伸（1440×900 基准）+ `expand` 宽高比，真实窗口的逻辑宽度恒 ≥1440（960×540 → 1600×900），因此 HUD 与招牌按同一份完整布局整体缩放，不设删信息/缩控件的 compact 分支；960×540 截图验证缩放后不裁切。
- 设施招牌由 `SNHarborSign`（`sn_harbor_sign.gd`）承载：`_port_sign()` 调 `configure(text, primary, facility, arrow)` 写木板/铁框/黄铜铆钉/徽记/箭头/悬停光晕，`Button` 语义与 `text`/tooltip 保留；招牌固定 172×42、边距 20。
- main.tscn 静态声明背景、菜单遮罩、滚动内容根、页脚、音频与 TransitionLayer；main.gd 通过 @onready 绑定，不再在运行时创建固定外壳。
- 已迁移页面由 PackedScene 实例化：Shell 负责查询并调用 bind，页面只发 command_requested/navigation_requested/action_requested 意图，不接触 AppContext。
- 每个功能有独立界面，通过顶部导航切换；面板分别构建完整 ViewModel，不把所有信息挤在同一滚动页。
- 每轮命令后整页重建；选项/目的地/构筑选择保存在 UI 成员。
- 每个 PanelContainer 只允许一个 VBoxContainer 内容容器；面板子节点必须经 `_panel_add()` 添加，避免多子节点互相重叠。
- 海图点击已访问港口：当前港跳转市场，远程港打开只读港口记忆。
- 海图由独立 map_canvas.tscn 组件承载；Shell 只绑定 ports/routes/labels 并处理 port_clicked。
- 总览页由独立 overview_screen.tscn 承载；Shell 解析横幅资产、海图标签、委托摘要与通报文本，页面组合港口/目标/船只/快捷操作/财务面板并发出导航、海图点击或命令意图。
- 启动主菜单使用全屏港口背景；进入游戏后保留顶部导航，并用共享 Theme 的徽标/章节标题/资源条构建信息层级。
- 总览港口横幅通过 Core manifest 的 `banner.port.*` 资产键与 `banner_asset` 字段解析；无横幅港口退回普通面板。
- 市场页由独立 market_screen.tscn 承载；Shell 组合 port.view 市场数据与 intel.view 趋势，页面发出 trade.buy/trade.sell 意图。
- 委托页由独立 contracts_screen.tscn 承载；Shell 补充直达性、解锁名称和已完成名称，页面发出 contract.accept 或 voyage 导航意图。
- 补给页由独立 supply_screen.tscn 承载；Shell 查询 supply.view、注入本地化回调并统一执行页面发出的 supply.* 命令。
- 情报页由独立 intel_screen.tscn 承载；Shell 查询 intel.view，页面组合 SNIntelTable 并发出 intel.refresh 意图。
- 出航页由独立 voyage_screen.tscn 承载；Shell 保存目的港/策略选择并查询 voyage.preview，页面只展示预览并发出 selection_changed 或 voyage.start 意图。
- 主菜单、新航程、模组列表与设置分别由 menu 目录下四个独立场景承载；Shell 组合启动 ViewModel，并统一处理导航、续玩、诊断、退出、新局与设置持久化意图。
- 港口记忆、抵达结算、航行中、航行事件与通关总结均由 flow 目录独立场景承载；Shell 负责查询/名称解析与流程控制，场景只展示并发出导航、命令或流程意图。
- 交易、委托接取和补给购买成功后播放 pickup_gold_00.wav。
- 无存档时进入主菜单：开始游戏进入新航程配置，加载游戏读取 autosave，模组页只读展示本次加载结果，设置可切换语言与自动存档，退出直接关闭。
- 设置写入 `user://config/config.json`，默认值来自 `config/config.json`；首次加载会创建用户配置。
- 右下角固定显示开发团队与游戏版本；版本来自 `application/config/version`。
- 页面切换使用全屏 TransitionLayer：旧页淡出、重建、新页淡入；数据刷新不播放转场。
- 新航程主操作使用 `SNPrimaryButton`，返回使用 ghost；章节标题控件只声明语义标签（SNEyebrowLabel/SNTitleLabel/SNDetailLabel）。
- 加载游戏读取 autosave 并做模组兼容性校验。
- 根控件加载共享 `steam_navigator_theme.tres`；页面可继续局部覆写，但不再在运行时拼装全局 Theme。
- 船厂页由独立 shipyard_screen.tscn 承载；Shell 查询 shipyard.view 并补充 `contracts`/`victory`（历史合并字段，当前船厂页不渲染通关清单）、船上材料数量 `ship_amount`、解锁来源 `unlock_name`、替换件名 `replacement_name` 与 `ship.hull_name`；页面发出的 ship/warehouse/port 命令统一交回 Shell。
- 船厂页正常态三列（已有船舶 / 实机渲染 / 组件分类），点击分类由页面 `set_category()` 进入改装态并渲染所选分类的槽位操作；Shell 只做状态记忆与 ViewModel 组装，不决定布局。
- 船厂改装态与分类由 Shell 保存：`refit_mode_changed` 写入 `_shipyard_refit`，`refit_category_changed` 写入 `_shipyard_category`（默认 `hulls`）；`_shipyard_model()` 把 `refit` 与 `category` 并入 shipyard.view；整页重建/切页后页面据此恢复纵剖图与选中分类。
- 委托页显示普通委托持有上限（active_count/active_limit）、每次抵达刷新提示与主线完成状态。
- 通关页由 victory.view.achieved 触发并优先于普通页面；展示 summary，提供“再来一局”（reset_state → 新航程菜单）与“继续游玩”（仅 UI 会话 dismiss）。
- 反馈5：紧凑 chrome 固定显示当前港口（在航时显示“在航 → 目的港”）、剩余载重 free_weight/max_weight 与剩余货舱 free_cargo_capacity/cargo_capacity；总览底部状态条再显示耐久/货舱/煤/水/受损/最新通告，避免信息只存在于详细抽屉。
- 反馈6：总览“当前目标”显示通关条件清单（主线 n/5 → 大型船体 → 锅炉 → ≥1 货舱 → 造船厂组装），主线完成后给出下一步提示；数据来自 port.view.victory.conditions 与 contracts.main_done/main_total。船厂页不再重复通关清单，只做组件分类入口。
- 反馈3：情报页用 SNIntelTable 渲染 intel.view 的 columns/rows 矩阵（含未知港口列），替代旧的逐港商品表格。
- 反馈4：打造订单与在港等待迁入船厂改装态「杂项」页签：等待按钮按 wait_options 生成 6/12/24 小时 `port.wait`，总览快捷入口同样提供等待按钮；模块类分类内保留「按配方打造」，打造按钮文案带工时。
- 反馈2：补给卡绑定 SNSupplyCard 时传入 _tr 回调，显示“上限损失/剩余可装”本地化文案。
- `_notice_text(notice)` 用 `_format_slots(template)`（`%[sd]` 正则、保序）取槽位：字符串参数先按本地化键解析，再按 push 顺序 `template % args`；槽位数与参数数不符、或 `%d` 槽位对应参数不是 int/float 时原样返回模板而不报格式错误；缺键时返回键名。空模板 / 无参数 / 无槽位直接返回模板本身，「航行记录」由此渲染成句。通知文案本地化由 test_ui_shell 的两个用例守护（真实渲染 + 源码 `push_notice` 键扫描，中英槽位序列保序一致）。
- 总览 3D 港口舞台由 Shell 持有：`PORT_STAGE_SCENE_PATH`（`port_stage.tscn`）懒加载，`PORT_STAGE_FACILITY_SCREENS` 映射设施→页面（exchange→market / contracts / supply / intel / shipyard）；`_overview_stage_mode` 默认 true（3D 是主视图），`_overview_detail` 默认 false。
- 连续港区：`STAGE_SCREENS = {overview→harbor, market→market, supply→supply}` 把页面映射到同一港区的三个相邻站位；`_stage_station` / `_stage_framing` 记录当前镜头站，overview 用 `stage` 构图，market/supply 用 `panel` 构图（右侧 640 px `DOCK_PANEL_WIDTH` 面板）。
- `_focus_stage_station(station, framing, immediate)` 只在舞台已挂载后调 `PortStage.focus_station()`；重设当前站位是 no-op，所以整页重建不会重启动画。`_stage_backed_page()` 判断当前页是否该用泊位面板（舞台场景可用时）。
- 市场/补给页的泊位面板：`_mount_dock_panel(screen)` 建 `DockPanelRow`（左 expanding `StageWindow` + 右 `PanelContainer(DockPanel, SNPanel, ≥640 px)`），页面放进面板；舞台不可用时退回原来的全宽页面。
- 站位间导航不播放全屏淡出：`_on_nav()` 在 `from` 与目标都属于 `STAGE_SCREENS` 且场景可用时 `_refresh(false)`，让镜头平移与船体航行可见；离开到 contracts/intel/shipyard/voyage 等非舞台页仍走 `_refresh(true)` 淡入淡出。
- 舞台宿主 `_port_stage_host` 为全窗 `SNStageHost`，放在 `Background` 之上、所有 UI 之下；两侧招牌层 `_port_hotspot_layer` 放在 `PageMargin` 之后，层本身 `MOUSE_FILTER_IGNORE`，只有招牌按钮吃点击；详细抽屉打开时另有一个 `_overview_detail_backdrop` 盖住舞台。
- `_sync_port_stage(data)` 在 `has_run && !at_sea && 当前页属于 STAGE_SCREENS && （非 overview 或 _overview_stage_mode） && 场景可用` 时显示；overview 额外要求 3D 总览模式，market/supply 不受该开关影响。菜单/无 run/通关/在航/错误/非舞台页分支在 `_rebuild_ui()` 里由 `_hide_port_stage()` 隐藏并清空招牌。
- `_port_stage_payload(data)` 从 `current_port` 组装 `port.{id,size,facilities,banner_path}`，可选透传 `facility_visuals/town_visuals/diorama/palette/landmark_path` 与 `diorama.density`，ship 只传 `hull_model_path/hull_tier`；`_port_banner_path()` 统一解析 `asset://<mod>/<banner_asset>`。
- 两侧招牌用 `facility_screen_anchor()` 的投影 x 分列（<0.5 左、否则右），同列按投影 y 排序；规格 172×42 / margin 20，左列文字「设施 ▶」、右列「◀ 设施」指向场景；右侧底部固定一条「出航 ▶」招牌（`Hotspot_voyage`）。
- 招牌控件是 `SNHarborSign`（自绘木板/铁框/黄铜铆钉/设施徽记/箭头/悬停光晕），`text` 与 `Button` 语义保留；`_port_sign()` 兼容组件缺失时回退普通 Ghost Button。
- 招牌布局避让紧凑 chrome 与底部状态条：`_port_hud_top_safe()` 取 `_top_chrome` 底边、`_port_hud_bottom_safe()` 取状态条顶边；`_refresh_port_hotspots_soon()` 做两次 deferred（等容器重排与 SubViewport 尺寸），视口 size_changed 时重排。
- 底部状态条（`_port_status_bar`，`PORT_STATUS_BAR_HEIGHT=60`）只在 overview 显示：耐久/货舱/煤/水/受损模块 + 最新通告（沿用 `_notice_text` 模板填充）+「详细总览/返回主界面」+ 出航 + 等待 12 小时（`port.wait`）；显示时隐藏 footer 并增大 `PageMargin` 底部预留。
- 详细总览抽屉：`_on_overview_detail_toggle()` 切换 `_overview_detail`，抽屉用原 2D 面板（含 `_victory_plan`）覆盖在舞台上方；舞台宿主不销毁，招牌层隐藏，关闭后回到裸舞台；离开 stage、切到非 overview、重开/继续游戏与加载失败都会复位抽屉。
- 2D 回退：chrome 上的「2D 总览」按钮切换 `_overview_stage_mode`；舞台加载失败 `_on_port_stage_fallback(reason)` 置 `_port_stage_load_failed`（本会话不再重试）、退出 stage 与抽屉、回退 2D、提示 `ui.error.port_stage_unavailable` 并 deferred refresh。

## 重点逻辑

### `_build_top_chrome(app, data, show_nav)`

- 一个半透明 `PanelContainer`（`_chrome_style()`：深青 0.84 + 黄铜底边）内放两行 `HBoxContainer`：第一行品牌/状态徽标/版本 + 港口·时间·金钱·声望 chip（金币带可选图标）+ 阶段切换（overview 且场景可用时才出现，「2D 总览/俯瞰港口」）+ 诊断/刷新；第二行剩余载重/货舱/煤/水/耐久/受损 chip（煤/水带图标）+ 7 个导航按钮。
- `show_nav=false`（在航）时不挂导航；最小高度由 chip 字号与 panel margin 决定，`test_ui_shell` 断言 ≤130 px。每个页面共用同一份 chrome，960×540 窗口由 canvas 拉伸整体缩放。

### `_stat_chip() / _hud_icon()`

- `_stat_chip(label, value, accent, label_size, value_size, icon_key)`：有图标时在文字列左侧加 22 px `TextureRect`（KEEP_ASPECT_CENTERED、不吃鼠标），否则只输出两行 Label。
- `_hud_icon(key)`：`AssetService.find_key(key)` → `has()` 校验 → `load_texture()`，结果（含 null）按 key 缓存；资产冻结后无需失效。

### `_set_port_status_bar_visible(visible, data) / _refresh_port_status_bar(data)`

- 状态条懒创建为全窗底部锚定的 `PanelContainer`（高 60、左右 20 边距、位于 fade 之下），只在 overview 显示；显示时隐藏 footer，并把 `PageMargin` 底部 margin 从 56 提到 84，避免遮住页面最后一行。
- 内容每次刷新重建：耐久/货舱/煤/水/受损 chip + 最新通告（`_latest_notice_text` → `_notice_text`）+「详细总览/返回主界面」（仅 stage 模式）+「出航 ▶」+「等待 12 小时」（`port.wait`）。

### `_layout_port_hotspots() / _layout_sign_column() / _port_sign()`

- 清空旧招牌后按 `facility_screen_anchor()` 把 present 设施分左右两列（x<0.5 / ≥0.5），同列按投影 y 排序，在两列各自的 safe 区内垂直居中均匀排布（172×42、gap 10）。
- safe 区来自真实 HUD 高度：顶部 = `_top_chrome` 底边 + 8，底部 = 状态条顶边（未建时回退 48 px）；右列底部预留「出航」招牌位，`Hotspot_voyage` 固定在右下。
- 点击招牌走 `_on_port_hotspot`：voyage 直接 `_on_nav("voyage")`，其余查 `PORT_STAGE_FACILITY_SCREENS` 后与顶部导航同一路径；抽屉打开或舞台不活跃时整层不生成招牌。

### `_sync_overview_detail_backdrop() / _place_overview_detail_backdrop()`

- 抽屉用不透明 `ColorRect(COLOR_BG)` 盖住舞台（不盖 chrome/状态条），`mouse_filter=IGNORE` 不抢滚动；只通过 sibling index 调整保证它在 `PageMargin` 之下。
- `_sync_overview_detail_backdrop()` 仅在 `_overview_detail && _port_stage_active()` 时显示；隐藏舞台、离开 overview 或加载失败时同步关闭，招牌层同时隐藏。

### `_sync_port_stage(data) / _ensure_port_stage_host()`

- 显示条件 = `has_run && !at_sea && 当前页在 STAGE_SCREENS && （非 overview 或 _overview_stage_mode） && 场景存在`；宿主首次懒创建（全窗锚定、先隐藏），随后 `load_stage(PORT_STAGE_SCENE_PATH)` → `bind_view_model(_port_stage_payload(data))` → `set_stage_visible(true)`，再 `_focus_stage_station(station, framing, just_mounted)`、同步抽屉 backdrop 与招牌层。站位切换只调 `PortStage.focus_station()`，舞台实例与 3D 世界都不重建。
- `_focus_stage_station(station, framing, immediate)`：overview 用 `stage` 构图，market/supply 用 `panel` 构图（右侧 640 px 面板，镜头右移 3 m 让站位设施留在可见左半屏）；`immediate` 只在首次挂载时传 true，其余走 0.6 s 镜头平移 + 船体沿岸航行。
- 宿主/招牌层/抽屉 backdrop 的层级用 `move_child(..., $Background.get_index() + 1)`、`(..., $PageMargin.get_index() + 1)` 与 `_place_overview_detail_backdrop()` 固定：3D 在背景之上、2D UI 之下，抽屉 backdrop 在页面之下。

### `_mount_dock_panel(screen)`

- market / supply 页的布局：`DockPanelRow`（HBox）第一个子节点是 `StageWindow`（expanding、不吃鼠标、露出舞台），第二个是 `DockPanel`（SNPanel、`custom_minimum_size.x = 640`、纵向 expand），页面本体挂在面板下。
- 舞台不可用（场景缺失或本会话加载失败）时 `_stage_backed_page()` 为 false，页面按原样全宽挂到 `_root_box`，功能不受影响。

模块索引：[framework/ui](../README.md)
