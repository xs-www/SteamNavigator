extends Control
## @static-doc
## 作用：可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并挂载已场景化的菜单/港口/流程页。主界面是「全窗 3D 港口舞台 + 紧凑顶部 chrome（图标 + 文字导航）+ 两侧设施招牌」的分层外壳；底部状态条与详细总览抽屉已在 2026-10-28 UI 轮移除（功能由顶部 chrome / 2D 总览页承担）。Shell 只保留上下文解析、ViewModel 组合、会话导航状态与命令派发。
##
## ## 皮肤接线（ui-skin-v1）
## - 所有纹理/图标/颜色经 `SNSkin`（`framework/ui/skin/sn_skin.gd`）读取 `assets/ui/skin/sn_v1/skin.json`；
##   本文件不写贴图路径、不写十六进制颜色，也不再手写 StyleBoxFlat。
## - 顶栏 `_chrome_style()` = `SNSkin.panel("chrome")`（半透明钢框、content 16/12）；皮肤缺失时
##   退回 Theme 的 `SNChromePanel` 变体，文字与交互不丢。底部状态条（`SNStatusBarPanel`）已移除。
## - 导航/小按钮走 Theme 变体：当前页 `SNPrimaryButton`，其余 `SNCompactButton`；图标来自
##   `SNSkin.icon()`（`button.icon` + `icon_max_width = 18`）。2026-10-28 UI 轮：导航是
##   「图标 + 本地化页名」按钮，入口身份仍走 `nav_screen` meta（剧情引导与测试按 meta 解析）。
## - HUD chip 图标：皮肤表 `HUD_SKIN_ICONS` 是唯一来源（语义键 → 皮肤 icon id）；内容包仍可
##   经 `HUD_ICON_KEYS` 覆盖（本轮为空表，`AssetService.find_key` 返回空则安全回退到皮肤），
##   两者都没有时只显示数值文字。
## - 边缘设施招牌交给 `SNHarborSign`（纹理化 Button）；Shell 只负责 `facilities → 页面` 的布局与导航。
##
## ## 尺寸预算
## - `TOP_CHROME_MAX_HEIGHT = 130`：两行 chrome（品牌/状态/时间·金钱·声望 + 资源 chip/导航）实测最小高度必须 ≤130；
##   3D 舞台是主视图，HUD 只做画框。图标轮后 chip 是 24 px 图标 + 数值单行，比旧的两行 label 更矮。
## - 招牌 `172×42`、右列固定「海图 ▶」入口；`PageMargin` 底部为页脚预留 56。
##   底部状态条移除后页脚在页面态常驻，3D 总览主视图隐藏页脚（`_sync_footer_visibility()`）。
##
## ## 契约
## - 数据只走 QueryBus，修改只走 CommandBus；UI 会话状态不写存档。
## - `SCREENS` / `STAGE_SCREENS` / `PORT_STAGE_FACILITY_SCREENS` 是导航契约，换皮不得改动键名或命令路径。
## - 顶部导航只渲染 `SCREENS` 中不在 `HIDDEN_NAV_SCREENS` 里的页面：基地（D3 基地建设）、
##   贸易（D4 自动贸易）、遗迹（D5 遗迹远征）三个系统尚未作为玩家功能发布，入口暂隐藏；
##   其中遗迹属于**航行探索**玩法（海图 → 探索），不作为港口页入口。三个页面的场景、
##   `_screen_*` 挂载函数与 `ui.nav.*` 本地化键保留：`tools/ui_snapshot.gd` 仍直接路由
##   这些页面做视觉验收，未来重新发布时只需从 `HIDDEN_NAV_SCREENS` 移除对应键。
## - 每个 PanelContainer 只允许一个 VBox 内容容器（`_panel_add()`）；页面场景只发意图，不持有 AppContext。
## - `-- --release-smoke` 专供成品启动门禁：真实 Autoload 与主场景启动后检查 Core 报告、
##   MainMenuScreen 脚本/ready/按钮树；成功打印 `[release-smoke] main-menu-ready`，再走
##   `_graceful_quit(exit_code)` 的真实退出路径，检查结果只通过退出码表达。
##   未传参数时不执行检查；不创建新局、不修改正常启动流程。
## - 自动更新（`docs/design/AUTO_UPDATE.md`）：`_setup_update_service()` 只在发布版（`OS.has_feature("template")`）
##   创建 `UpdateService`；主菜单的 `UpdateButton` 只显示状态，「游戏更新」对话框由 Shell 持有并只转发意图。
##   `_on_update_restart()` 启动自替换后的新 exe 再走 `_graceful_quit()`。编辑器与无头测试永不联网。
##   `-- --update-selftest` 是发布包专用内部验收钩子：自动 check → available 时 download，staged/up_to_date
##   时打印 `[update-selftest]` 后退出，供 `tools/update_e2e.ps1` 在真实安装目录验证下载/替换/重启。
##
## ## HUD 图标化 / 文字精简（2026-10-28 图标轮）
## - 顶部 chrome 的品牌列删掉 9 px `ui.label.port` 小标题，只留港口名（语义进 tooltip）；
##   时间 / 金币 / 声望 chip 只剩图标 + 数值。
## - `_stat_chip()` 统一为「皮肤图标 + 数值」单行容器：`label_text` 变成 chip 的
##   `tooltip_text`，不再画 label；`chip_key` 与内部 `Value` 子节点名保留（煤 / 水逐帧插值依赖）。
## - `HUD_SKIN_ICONS` 语义键：free_weight→resource_cargo、free_capacity→shipyard_cargo、
##   coal→resource_coal、water→resource_water、durability→resource_durability、cargo→resource_cargo、
##   money→resource_coins、reputation→status_reputation、time→status_time、damaged→status_warning；
##   `HUD_ICON_KEYS` 已清空（早期 `icon.money/coal/water` 内容资产退役），只保留内容包覆盖通道。
## - 导航是「图标 + 本地化页名」：`SCREENS` 每个入口 64×36、`icon` + `text`、
##   `set_meta("nav_screen", screen)`；海图 toggle 同样带 `nav_screen = "sea_chart"`。
##   `_story_nav_button()` 先按 meta 解析、再按旧文字回退，隐藏入口仍返回 null。
## - 2026-10-28 UI 轮：底部状态条与「详细总览」抽屉整条移除（与顶部 chrome 重复）；
##   耐久/货舱/煤/水/受损读数留在顶部 chip，海图入口留在导航，等待 6/12/24 h 与
##   航行记录留在 2D 总览页。「详细总览」= 顶部「2D 总览」开关切到的 2D 页面。
##
## ## 剧情 UI 事件时机与强制引导（v0.2.0-dev.3 #1 / #3）
## - `ui:*` 是**玩家动作**，由 Shell 在动作发生处上报一次：`ui:chart_opened` 在
##   `_on_nav("sea_chart")`、`ui:chart_closed` 在 `_on_sea_chart_closed`、
##   `ui:arrival_settled` 在 `_finish_presentation()` / `_full_stop_after_voyage()`
##   的抵达结算点。页面挂载函数（`_screen_settlement` / `_screen_sea_chart`）只渲染、
##   不再 observe，因此剧情卡继续 / resize / 状态刷新引起的页面重建不会重复推进剧情。
## - `DEPARTURE_VEIL` 归入 `_presentation_on_stage()`：离港云层期间继续挂出发港 3D
##   舞台（origin 视图），不会在演出中途掉回海图页并重复上报 `ui:chart_opened`。
## - 离开结算页清空 `_settlement_summary`，避免旧航次摘要被后续重建再次“结算”。
## - `SNFocusOverlay`（framework/ui/components/sn_focus_overlay.gd）：剧情阶段的
##   `story.view.focus.target` 由 `_resolve_story_focus_target()` 解析成真实控件
##   （`market_supply` / `chart_entry` / `<screen>_nav`）；页面挂好、每次重建与窗口
##   resize 后由 `_sync_story_focus()` 更新，剧情卡 / 演出 / 结算页时清除。
## - **重建后的引导框定位**：`_rebuild_ui_body()` 里的同步 `_sync_story_focus()` 只能
##   读到刚重建的 TopChrome/Nav 还没排版时的旧 `global_rect`。所以重建后紧接
##   `_sync_story_focus_soon()`（两次 deferred，同 `_refresh_port_hotspots_soon` 手法）
##   兜底目标重解析；遮罩本身通过 `focus_target()` 绑定真实控件并逐帧自愈，
##   容器排版 / resize 导致目标移动时框自动追上（不再停在旧位置）。
##
## ## 退出与性能（P0，2026-10-24）
## - **优雅退出**：`_ready()` 设 `get_tree().auto_accept_quit = false`，窗口关闭请求走
##   `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` → `_graceful_quit()`；「退出游戏」按钮同样走它。
##   `_prepare_quit()` 幂等：停演出、`unmount_stage()` 并释放 `_port_stage_host`（它持有
##   SubViewport + 世界 + MSAA framebuffer）、释放页面树/全屏层与热点层，随后
##   `ContentAssetLoader.clear_cache()` + `FrameworkRuntime.shutdown()`（此前只有测试会调用）。
## - **导出构建退出崩溃的引擎兜底**：Godot 4.7.2 GL Compatibility 在「本会话渲染过 3D 舞台」
##   后退出时于 GLES3 storage teardown 崩溃（0xC0000005，dev.3 与 HEAD 导出版均可复现，应用层
##   清理无效）。因此 `_had_3d_stage` 为真且非编辑器构建时，清理完成后用 `OS.kill()` 结束进程，
##   玩家看到的是正常关闭而不是 Windows 崩溃弹窗；纯菜单会话仍走 `get_tree().quit()`。引擎升级后应移除该兜底。
## - **整页重建读作用域**：`_rebuild_ui()` 包在 `QueryBus.begin_read_scope()` /
##   `end_read_scope()` 里，一次重建只克隆一次 GameState（每查询克隆 11.6 ms → 一次）；
##   `CommandBus` 提交成功后 `invalidate_read_snapshot()` 保证后续查询看到已提交状态。
## - **港口名缓存**：`_port_name()` 以 run seed 为键缓存 `port_id → name_key`，一次 `map.view`
##   填满整表；状态消息不再每条触发一次 `map.view` 全状态克隆（13.5 ms/次）。
##
## ## 市场页（图标直接交易，`docs/design/MARKET_UI_REFACTOR.md`）
## - `_screen_market()` 先执行 `market.view`；查询不可用时回退用 `port.view` 的行情 / 船摘要
##   组装同名字段的 ViewModel，页面不崩。
## - 每个行情 / 船舱 / 仓库行的 `icon_key` 由 Shell 经 `AssetService.find_key` →
##   `AssetService.load_texture` 解析成 `Texture2D`（实例内缓存）；缺失时回退
##   `assets/ui/icons/item_fallback.svg`，再缺失回退框架占位贴图。
## - 舞台可用时挂三栏 `DockPanelRow`：`CargoHoldPanel`(360) + 透明 `StageWindow`
##   (expand, `MOUSE_FILTER_IGNORE`, 只露出 3D 港区) + `DockPanel`(640)；舞台不可用时
##   退化成 `CargoHoldPanel` + 市场面板两栏，不出现空白舞台窗口。
## - 角标分工：市场行情格右上角显示**剩余库存**（`SNItemTile` 的 `remaining` 模式，
##   `stock - pending`）；玩家已选数量（`×N`）与**预计消费**（`unit_price × amount`，
##   文案键 `ui.market.estimated_cost`）显示在跟随鼠标的 `SNCarryGhost` 上。行情格
##   `meta` 只保留单价 + 趋势，不和角标重复。`offer` 由 `MarketScreen._offer_for()`
##   组装并携带 `unit_price`。
## - 页面只发命令意图：`trade.buy{destination}` / `trade.sell{source}` /
##   `warehouse.store_materials` / `warehouse.take_materials`。
##
## ## 委托页（反馈 #2 / #3）
## - 可接委托列表直接来自 `port.view`（已在查询层过滤掉目的港未发现的普通委托）；
##   Shell 不再做二次雾判断，也不隐藏主线 offer（生成时已揭示目的地）。
## - 无期限委托（`has_deadline=false`）在总览奖励文案里用「完成 +N」而不是「准时 +N」；
##   委托页卡片的期限显示由 `contracts_screen` 负责。
##
## ## 航线解锁（2026-10-26）
## - 酒馆页「海图（航线解锁）」区块发 `chart.buy {port_id}`；成功由 `_handle_success` 的
##   `"chart.buy"` 分支在状态栏确认已测绘航线，`_refresh()` 重建页面后
##   `tavern.view.chart_offers` 的该港口变为 `unlocked=true`（显示「已测绘」）。
## - 海图页签 `voyage.preview` / `voyage.start` / `clue.travel` 的 `route_locked` 失败按
##   既有错误路径显示 `ui.error.route_locked`；面板在未测绘航线上禁用启航并显示酒馆提示。
##
## ## 游玩数据上传（`docs/design/TELEMETRY.md`，唯一契约）
## - 首次解析到 AppContext 时（`_apply_settings_if_needed`）按设置创建 `TelemetryService`
##   并挂到 `AppContext.telemetry`；`TelemetryUploader` 作为 Shell 子节点，Shell 退出时随
##   场景树一起释放。`_settings_applied` 的重置（retry bootstrap）会重新绑定新 context。
## - 开启时 `begin_session(meta)`；`DomainEventBus.event_published` 只把契约白名单事件
##   （`voyage/port/contract/combat/story/quest/market/run.*`）交给服务，CommandBus 负责命令记录。
## - 设置页 VM 的 `telemetry_enabled` 来自 `SettingsService`；`toggle_telemetry` 先写设置、
##   再切换服务（关闭时服务清空缓冲并删除 pending 队列），最后保存配置。
## - 退出：`_graceful_quit()` 先 `finalize_session` 写 pending，再最多等
##   `EXIT_UPLOAD_WAIT_SECONDS`（3 秒）尝试上传，然后才执行原有 teardown / 3D 退出兜底；
##   `_prepare_quit()` 不做网络（测试直接调用它）。启动时的遗留队列补传在后台进行、不阻塞 UI。
## - 无头进程（测试/工具）不发起真实网络请求：启动补传在 headless 下跳过；`_prepare_quit` 不联网。
## @end-static-doc
##
## Playable shell for the framework slice.
##
## The UI only reads ViewModels through QueryBus and mutates through
## CommandBus. Each major function has its own screen; the shell owns
## navigation, the header, and transient selection state only.
##
## Two mount paths exist: ordinary pages go into `PageMargin/PageScroll/RootBox`,
## while the at-sea chart page goes into the full-window `FullscreenLayer` (no
## page margins, no scrolling) so the sea really fills the window. The voyage
## presentation also feeds that page its route polyline straight from the twin
## world's `WorldMap.edges` (`_presentation_route_path`) instead of the
## fog-filtered `sea_chart.view` routes.
##
## Exploration (phase 4.1) reuses that same presentation: `explore.start` returns
## a `presentation` block (`_presentation_explore`) whose route ends at a search
## zone centre the player cannot name yet. The chart page then draws a dashed
## prediction line to a `?` marker, and the arrival milestone runs `explore.settle`
## before cutting to the harbour (the destination only exists after that command).
##
## Phase 4.2 adds the resource-alert decision: when the exploration's Core rules
## report `alert_needed`, the state machine stops at the alert's `alert_progress`
## and `_rebuild_ui` mounts the alert page (reusing `EventScreen`) instead of the
## chart. `continue` acknowledges it in the domain and resumes the voyage;
## `turn_back` lets `explore.decide` settle a half-voyage return immediately, then
## `VoyagePresentation.force_arrival()` plays the normal harbour cut without ever
## calling `explore.settle` again (that is what `_presentation_explore["returned"]`
## guards in `ARRIVAL_READY`).

const UI_THEME := preload("res://assets/ui/theme/steam_navigator_theme.tres")
## Themed edge signboard (wood/iron/brass custom draw, plain Button semantics).
const HARBOR_SIGN_SCRIPT := preload("res://framework/ui/components/sn_harbor_sign.gd")
const MARKET_SCREEN_SCENE := preload("res://framework/ui/screens/port/market_screen.tscn")
## 市场页左侧「船只背包」面板（图标拖拽来源 / 落点）。
const CARGO_HOLD_PANEL_SCRIPT := preload("res://framework/ui/components/sn_cargo_hold_panel.gd")
## 通用物品回退图标（内容模组没提供 `information.texture` 时使用）。
const ITEM_FALLBACK_ICON := "res://assets/ui/icons/item_fallback.svg"
## 市场「拿起 / 放下」光标幽灵（feedback #1）与交互处浮出提示（dev.3 feedback #4）：
## 场景化组件（P0，UI_SCENE_MIGRATION.md），必须 `.instantiate()`，不能 `SCRIPT.new()`；
## 挂在 Shell 的浮层（HintLayer）里，不依赖页面滚动区。
const CARRY_GHOST_SCENE := preload("res://framework/ui/components/sn_carry_ghost.tscn")
const INTERACTION_HINT_SCENE := preload("res://framework/ui/components/sn_interaction_hint.tscn")
const CONTRACTS_SCREEN_SCENE := preload("res://framework/ui/screens/port/contracts_screen.tscn")
const SUPPLY_SCREEN_SCENE := preload("res://framework/ui/screens/port/supply_screen.tscn")
const INTEL_SCREEN_SCENE := preload("res://framework/ui/screens/port/tavern_screen.tscn")
const OVERVIEW_SCREEN_SCENE := preload("res://framework/ui/screens/port/overview_screen.tscn")
const SHIPYARD_SCREEN_SCENE := preload("res://framework/ui/screens/port/shipyard_screen.tscn")
const BASE_SCREEN_SCENE := preload("res://framework/ui/screens/port/base_screen.tscn")
const AUTO_TRADE_SCREEN_SCENE := preload("res://framework/ui/screens/port/auto_trade_screen.tscn")
const RUINS_SCREEN_SCENE := preload("res://framework/ui/screens/port/ruins_screen.tscn")
const PORT_MEMORY_SCREEN_SCENE := preload("res://framework/ui/screens/flow/port_memory_screen.tscn")
const SETTLEMENT_SCREEN_SCENE := preload("res://framework/ui/screens/flow/settlement_screen.tscn")
const AT_SEA_SCREEN_SCENE := preload("res://framework/ui/screens/flow/at_sea_screen.tscn")
const EVENT_SCREEN_SCENE := preload("res://framework/ui/screens/flow/event_screen.tscn")
const SEA_CHART_SCREEN_SCENE := preload("res://framework/ui/screens/flow/sea_chart_screen.tscn")
const CLUE_LOG_SCREEN_SCENE := preload("res://framework/ui/screens/flow/clue_log_screen.tscn")
const STORY_CARD_SCRIPT := preload("res://framework/ui/components/sn_story_card.gd")
const STORY_OBJECTIVE_SCRIPT := preload("res://framework/ui/components/sn_story_objective.gd")
const STORY_FOCUS_SCRIPT := preload("res://framework/ui/components/sn_focus_overlay.gd")
const TASK_TRACKER_SCRIPT := preload("res://framework/ui/components/sn_task_tracker.gd")
const VICTORY_SCREEN_SCENE := preload("res://framework/ui/screens/flow/victory_screen.tscn")
const MAIN_MENU_SCREEN_SCENE := preload("res://framework/ui/screens/menu/main_menu_screen.tscn")
const UPDATE_DIALOG_SCENE := preload("res://framework/ui/components/sn_update_dialog.tscn")
const NEW_GAME_SCREEN_SCENE := preload("res://framework/ui/screens/menu/new_game_screen.tscn")
const MODS_SCREEN_SCENE := preload("res://framework/ui/screens/menu/mods_screen.tscn")
const SETTINGS_SCREEN_SCENE := preload("res://framework/ui/screens/menu/settings_screen.tscn")
## Navigation icon per screen; the shell only names skin ids, `SNSkin.icon()`
## resolves the texture (missing skin -> text-only button, never a path in code).
const NAV_ICONS := {
	"overview": "status_anchor",
	"market": "nav_market",
	"contracts": "nav_contracts",
	"shipyard": "nav_shipyard",
	"base": "shipyard_hull",
	"trade": "status_route",
	"ruins": "nav_chart",
	"tavern": "nav_intelligence",
	"sea_chart": "nav_chart",
}
## Icon-only navigation: the glyph is the whole button face, so it gets a bit more
## width than the old text+18 px icon layout.
const NAV_ICON_MAX_WIDTH := 22
const DEV_TEAM := "PlayThought Team"
const GAME_VERSION_FALLBACK := "0.2.0"

## 港口页面导航（4.3.4 / U7：出航准备页已删除；4.5.3：补给页并入市场；
## 4.5.4：情报站页面被酒馆页替换）。
const SCREENS := ["overview", "market", "contracts", "shipyard", "base", "trade", "ruins", "tavern"]
## 未发布系统的玩家入口：基地（D3）/ 自动贸易（D4）/ 遗迹远征（D5）都有完整内部页面，
## 但尚未作为玩家功能发布，顶部导航不生成按钮（遗迹归航行探索，不是港口页入口）。
## 只隐藏 **入口**：`SCREENS` 路由、三个页面场景与 `ui.nav.*` 文案都保留，因为
## `tools/ui_snapshot.gd` 仍直接路由这些页面做视觉验收，后续重新发布时从本表移除即可。
const HIDDEN_NAV_SCREENS := ["base", "trade", "ruins"]
## 2.5D port stage presented behind the overview page. Kept as a path (not a
## preload) so a missing scene degrades to the 2D banner instead of a parse error.
const PORT_STAGE_SCENE_PATH := "res://framework/ui/stages/port_stage.tscn"
## Facility id -> page opened by the 2D sign drawn over the stage.
const PORT_STAGE_FACILITY_SCREENS := {
	"exchange": &"market",
	"contracts": &"contracts",
	"tavern": &"tavern",
	# 4.5.4：旧世界快照里仍可能带 `intel` 设施，兼容映射到酒馆页。
	"intel": &"tavern",
	"shipyard": &"shipyard",
}
## Screens that share the one continuous 3D port stage. The pages map to adjacent
## stations of the same harbour district: navigating between them keeps the same
## stage instance mounted and only pans the camera + sails the player's hull to
## the station berth (Bounty Train style), so there is no rebuild and no fade to
## black between the market, the harbour authority and the supply yard.
const STAGE_SCREENS := {
	"overview": "harbor",
	"market": "market",
	# 改装态船厂页也画在 3D 港区舞台上（镜头对准船厂干船坞站位）；正常态船厂页
	# 自带面板内的 3D 船体舞台，所以 `_sync_port_stage()` 会按 `_shipyard_refit` 隐藏它。
	"shipyard": "shipyard",
}
## Width of the dock information panel on the market / supply pages. The stage
## keeps the left part of the window, the panel floats over the right side.
const DOCK_PANEL_WIDTH := 640.0
## Width of the market page's left "ship hold" column (cargo + port warehouse).
const CARGO_HOLD_PANEL_WIDTH := 360.0
## Gap between the market page's three columns (backpack / stage window / dock).
const MARKET_COLUMN_GAP := 14
## Compact top chrome: header + resource stats + navigation in two tight rows.
## The measured minimum height must stay under `TOP_CHROME_MAX_HEIGHT`, because
## the 3D stage is the main view and the HUD only frames it.
const TOP_CHROME_MAX_HEIGHT := 130.0
## Side signboards: fixed columns at the scene edges, one per present facility
## plus the always-present "voyage" sign at the bottom of the right column.
const PORT_SIGN_WIDTH := 172.0
const PORT_SIGN_HEIGHT := 42.0
const PORT_SIGN_GAP := 10.0
const PORT_SIGN_MARGIN := 20.0
## Optional HUD icon overrides. Content packs may declare `icon.*` assets and the
## Shell resolves whichever mounted pack provides them (`AssetService.find_key`),
## then falls back to the skin table below. 2026-10-28 图标轮：退役的早期内容图标
## （`icon.money` / `icon.coal` / `icon.water`）与从未声明的键全部清空，HUD chip 统一
## 走 `HUD_SKIN_ICONS`；覆盖通道保留给未来的内容包（`find_key` 返回空也安全回退）。
const HUD_ICON_KEYS := {}
## Skin icon per logical HUD key (assets/ui/skin/sn_v1/icons). The two cargo crates
## are told apart by their tooltip: free_weight = 剩余载重, free_capacity = 剩余货舱；
## `cargo` 供其它读数复用（底部状态条已在 2026-10-28 UI 轮移除）。
const HUD_SKIN_ICONS := {
	"free_weight": "resource_cargo",
	"free_capacity": "shipyard_cargo",
	"coal": "resource_coal",
	"water": "resource_water",
	"durability": "resource_durability",
	"cargo": "resource_cargo",
	"money": "resource_coins",
	"reputation": "status_reputation",
	"time": "status_time",
	"damaged": "status_warning",
}
const HUD_ICON_SIZE := 24.0
## Page bottom reserve: leaves room for the footer (the old bottom status strip
## was removed in the 2026-10-28 UI round).
const PAGE_BOTTOM_MARGIN := 56
## 退出时等待遗留 pending 上传的总预算（TELEMETRY.md §3.4、§1：绝不阻塞退出超过 3 秒）。
const EXIT_UPLOAD_WAIT_SECONDS := 3.0
var _context: AppContext = null
@onready var _root_box: VBoxContainer = $PageMargin/PageScroll/RootBox
## 全窗演出层：航行页的海图挂在这里（在网页边距/滚动容器之外），海图才能真正
## 铺满整屏（阶段 3 验收反馈 F3）。它位于页面层之下、顶部 chrome 与转场层之上。
@onready var _fullscreen_layer: Control = $FullscreenLayer
var _last_port_view: Dictionary = {}
## Market page icon resolution cache: `icon_key` -> Texture2D (session only).
var _market_icon_cache: Dictionary = {}
## 拿起手势光标幽灵 / 交互处浮出提示：挂在 Shell 的全窗 `HintLayer` 浮层里，位于
## `PageScroll` 之外（页面边距与滚动都裁不到），在转场淡出层之下。
var _hint_layer: Control = null
## 游戏内更新（docs/design/AUTO_UPDATE.md）：发布版才有实例；编辑器/测试不联网。
var _update_service: UpdateService = null
var _update_dialog: Control = null
var _carry_ghost: Control = null
var _interaction_hint: Control = null
## True while a player-triggered command executes: `_set_status` uses it so only
## interaction feedback pops at the cursor (nav /演出 / 载入不弹)。
var _interactive_command := false
var _settings: SettingsService = null
var _settings_applied: bool = false
## 游玩数据上传（docs/design/TELEMETRY.md §3、§5）：首次解析到 context 后创建并绑定
## `_context.telemetry`；上传器是 Shell 子节点，负责串行补传 pending 文件。
var _telemetry: TelemetryService = null
var _telemetry_uploader: TelemetryUploader = null
## 当前记录器绑定的 context；retry bootstrap 换 context 时据此重建。
var _telemetry_context: AppContext = null

var _active_screen: String = "overview"
var _menu_screen: String = "main"
var _memory_port_id: String = ""
var _selected_scenario: String = ""
## 4.5.2：新开局走剧情时隐藏选构筑，使用默认教学船。
var _tutorial_mode := false
## 上一次确认出航时选择的锅炉策略（Shell 记忆；无记忆时按 `strategy.standard`
## tag 解析）。4.3.4 起出航确认弹窗默认用它。
var _selected_strategy: String = ""
var _sea_chart_return: String = "overview"
## 海图出航确认弹窗（4.3.4 / U7）。空字典 = 弹窗关闭；否则
## `{kind: "voyage"|"explore", target_id, strategy_id}`。仅 UI 会话状态，不进存档。
var _chart_departure: Dictionary = {}
## 「规划出航」等入口请求打开海图时预选的港口（消费一次后清空）。
var _pending_chart_port: String = ""
## 4.4.4：线索列表页点击条目后，回海图时要选中的线索 id（消费一次后清空）。
var _pending_chart_clue: String = ""
## 4.5 / U1：当前剧情 ViewModel、剧情卡 / 目标条图层与卡片打开状态（仅 UI 会话）。
var _story_vm: Dictionary = {}
## 4.6 Phase A：任务追踪聚合 ViewModel（`task.view`）。
var _task_vm: Dictionary = {}
var _story_layer: Control = null
var _story_card: Control = null
var _story_objective: Control = null
var _task_tracker: Control = null
## 4.7 / dev.3 #3：强制引导遮罩（剧情阶段声明 `focus` 时由 Shell 挂载并解析目标）。
var _story_focus: Control = null
var _story_focus_warned: Dictionary = {}
var _story_card_open := false
var _seed_text: String = ""
var _status_message: String = ""
var _status_is_error: bool = false
@onready var _footer_team: Label = $Footer/Team
@onready var _footer_version: Label = $Footer/Version
@onready var _menu_background: TextureRect = $MenuBackground
@onready var _menu_overlay: ColorRect = $MenuOverlay
@onready var _pickup_player: AudioStreamPlayer = $PickupPlayer
var _settlement_summary: Dictionary = {}
var _victory_dismissed: bool = false
var _shipyard_refit: bool = false
var _shipyard_category: String = "hulls"
## Overview 3D stage state. `_overview_stage_mode` is UI-session state only.
## The 3D port stage is the default main view; the 2D overview stays reachable
## as a fallback / accessibility toggle.
var _overview_stage_mode: bool = true
var _port_stage_load_failed: bool = false
var _port_stage_host: SNStageHost = null
## Station the stage is currently showing ("harbor" / "market" / "supply") and
## the framing it was asked for ("stage" / "panel"). Kept on the shell so a page
## rebuild does not restart the pan.
var _stage_station: String = ""
var _stage_framing: String = ""
## 2D sign layer over the stage (one sign per present facility + voyage).
var _port_hotspot_layer: Control = null
## Fixed chrome nodes rebuilt every refresh; kept so tests and the layout code
## can measure them without walking the whole tree.
var _top_chrome: PanelContainer = null
## Resolved optional HUD icon textures (key -> Texture2D or null). Assets are
## frozen after bootstrap, so the cache never needs invalidation.
var _hud_icon_cache: Dictionary = {}
## 4.3.5 / U8：演出期间顶栏「煤 / 水」读数 Label。`_tick_presentation` 每帧只改这两
## 个 Label 的文本（出发库存 - 费率 × 已航行小时），不写领域状态、不重建页面；
## `_rebuild_ui` 清空引用，重建后的 chrome 回到真实 state 读数。
var _hud_coal_value: Label = null
var _hud_water_value: Label = null
@onready var _page_margin: MarginContainer = $PageMargin
@onready var _fade_layer: ColorRect = $TransitionLayer
var _transitioning: bool = false
var _pending_transition: bool = false
## Voyage presentation (nautical chart phase 3). `_presentation` is the whole
## at-sea演出 session state: while it is set, the shell renders the chart
## presentation, hides navigation and drives `_process` ticks. It is UI-session
## state only — the voyage itself is already resolved by `voyage.start`.
var _presentation: VoyagePresentation = null
var _presentation_summary: Dictionary = {}
## 探索演出（阶段 4.1）：`explore.start` 命令返回的 `presentation`（origin / zone /
## route_path / total_hours / alert_needed / alert_progress / …）。非空表示这次演出是
## 探索，抵达摘要要由 `explore.settle` 现算，目的地直到结算后才存在。4.2 的告警
## 决策点也记在这里（`alert_*`；`returned = true` 表示已掉头并提前结算）。
var _presentation_explore: Dictionary = {}
## Endpoints of the voyage being presented. Kept on the shell because the domain
## voyage record is already cleared when the arrival settles instantly.
var _presentation_voyage: Dictionary = {}
## `port.view` of the harbour the voyage departed from, captured before the
## command settled the arrival (the departure cut is filmed there).
var _presentation_origin_view: Dictionary = {}
var _at_sea_screen: AtSeaScreen = null
## Procedural cloud veil used by the presentation; created lazily as the topmost
## child so it covers both the 3D stage and the pages.
var _cloud_veil: SNCloudVeil = null
## Shutdown guard: the first close/quit request wins, so a second request (or the
## in-game quit button pressed while the teardown runs) cannot start it twice.
var _quitting := false
## True once this session mounted a 3D stage. The exported GL Compatibility build
## crashes (0xC0000005) inside the engine's GLES3 teardown when a 3D stage has been
## rendered; `_graceful_quit()` therefore releases the game resources and then
## terminates the process instead of letting the engine tear the GL context down.
var _had_3d_stage := false
## `port_id -> localized port name`. Ports are generated from the run seed, so the
## seed is the cache key: a new run / a save from another seed rebuilds the table.
## Status messages ask for port names 1–3 times per interaction and each lookup
## used to run a whole `map.view` query (a full GameState clone).
var _port_name_cache: Dictionary = {}
var _port_name_seed: int = -2147483648


func _ready() -> void:
	theme = UI_THEME
	# Close requests go through `_graceful_quit()` instead of Godot's default
	# immediate quit: the exported build crashed with 0xC0000005 when the window
	# closed while the 3D stage's runtime ImageTextures were still alive.
	get_tree().auto_accept_quit = false
	_settings = SettingsService.load_settings()
	_refresh()
	_setup_update_service()
	if OS.get_cmdline_user_args().has("--update-selftest"):
		_run_update_selftest.call_deferred()
	if OS.get_cmdline_user_args().has("--release-smoke"):
		_report_release_smoke.call_deferred()


func _report_release_smoke() -> void:
	var bootstrap := get_tree().root.get_node_or_null("AppBootstrap")
	var menu := _root_box.get_node_or_null("MainMenuScreen")
	var startup_ok: bool = bootstrap != null and bootstrap.is_ready_for_scene() \
		and _context != null and _context == bootstrap.context \
		and _context.report.status_name() == "ok" and _context.report.content_total() > 0
	var menu_ok: bool = menu is MainMenuScreen and menu.is_node_ready() \
		and menu.has_node("MenuStatusRow") and menu.find_child("MenuBoard", true, false) != null \
		and menu.find_children("*", "Button", true, false).size() >= 6
	if startup_ok and menu_ok:
		print("[release-smoke] main-menu-ready")
	else:
		push_error("Release smoke failed: bootstrap or main menu is not ready")
	# Use the real player quit path (telemetry finalize -> free page tree -> release
	# runtime caches) so the gate also catches teardown errors; only the exit code
	# carries the check result.
	_graceful_quit(0 if startup_ok and menu_ok else 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_graceful_quit()


## Drives the at-sea演出. Only the presentation advances the animation; the
## domain voyage was already resolved when `voyage.start` returned.
func _process(delta: float) -> void:
	if _presentation == null:
		return
	_tick_presentation(delta)


func _apply_settings_if_needed() -> void:
	if _context == null or _settings == null or _settings_applied:
		return
	_context.localization.set_locale(_settings.locale())
	_context.autosave_enabled = _settings.autosave()
	_settings_applied = true
	_init_telemetry()


func _play_pickup() -> void:
	if _pickup_player != null and _pickup_player.stream != null:
		_pickup_player.play()


func _set_menu_visual(enabled: bool) -> void:
	if _menu_background != null:
		_menu_background.visible = enabled
	if _menu_overlay != null:
		_menu_overlay.visible = enabled


func _game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", GAME_VERSION_FALLBACK))


func _refresh_footer() -> void:
	if _footer_team != null:
		_footer_team.text = _tr("ui.menu.team", "开发团队：%s" % DEV_TEAM)
	if _footer_version != null:
		_footer_version.text = "%s v%s" % [_tr("ui.menu.version", "版本"), _game_version()]
	# 底部状态条移除后，页脚在页面态常驻；3D 总览主视图由 `_sync_footer_visibility()`
	# 单独隐藏，保持无遮挡画框。
	_set_footer_visible(true)


## 页脚只在页面态显示：裸露的 3D 港口舞台是主视图，不再叠开发团队 / 版本文字。
func _sync_footer_visibility() -> void:
	_set_footer_visible(not _port_stage_active())


func _set_footer_visible(visible: bool) -> void:
	if _footer_team == null:
		return
	var footer := _footer_team.get_parent() as CanvasItem
	if footer != null:
		footer.visible = visible


func _refresh(animate: bool = false) -> void:
	if _transitioning:
		_pending_transition = true
		return
	if animate and _fade_layer != null:
		_begin_transition()
		return
	_rebuild_ui()


func _begin_transition() -> void:
	_transitioning = true
	_fade_layer.visible = true
	_fade_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_color := SNSkin.color("bg.abyss")
	fade_color.a = 0.0
	_fade_layer.color = fade_color
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade_layer, "color:a", 0.96, 0.16)
	tween.tween_callback(func() -> void:
		_rebuild_ui()
		_fade_layer.color.a = 0.96
	)
	tween.tween_property(_fade_layer, "color:a", 0.0, 0.22)
	tween.tween_callback(func() -> void:
		_fade_layer.visible = false
		_fade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transitioning = false
		if _pending_transition:
			_pending_transition = false
			_refresh(true)
	)


## Public entry for a full page rebuild. Opens a query read scope so the whole
## rebuild pays **one** GameState clone instead of one per query (the HEAD page
## rebuild runs ~7 queries; a clone is 11.6 ms), and always closes it, including
## on the early returns inside the body.
func _rebuild_ui() -> void:
	_context = _resolve_context()
	var scoped := _context != null and _context.queries != null
	if scoped:
		_context.queries.begin_read_scope()
	_rebuild_ui_body()
	if scoped and _context != null and _context.queries != null:
		_context.queries.end_read_scope()


func _rebuild_ui_body() -> void:
	# A page rebuild drops the page-owned pending amounts, so the 拿起光标幽灵 goes
	# with it. The floating interaction hint deliberately survives the rebuild: it
	# reports the command that triggered this rebuild.
	_hide_carry_ghost()
	_context = _resolve_context()
	for child in _root_box.get_children():
		_root_box.remove_child(child)
		child.queue_free()
	# The at-sea chart lives outside the scrolling page stack (it must fill the
	# window), so it has to be cleared here too or the page would linger.
	for child in _fullscreen_layer.get_children():
		_fullscreen_layer.remove_child(child)
		child.queue_free()
	_top_chrome = null
	_at_sea_screen = null
	# 4.3.5 / U8：顶栏读数 Label 随页面重建一起失效，避免演出继续写已释放的节点。
	_hud_coal_value = null
	_hud_water_value = null
	if _context == null:
		_hide_port_stage()
		_story_vm = {}
		_task_vm = {}
		_update_story_layer()
		_root_box.add_child(_label("Loading framework...", 20, SNSkin.color("text.muted")))
		get_tree().create_timer(0.4).timeout.connect(_refresh)
		return
	_apply_settings_if_needed()
	var app_view := _context.queries.execute(&"app.view")
	if not bool(app_view.get("ok", false)):
		_hide_port_stage()
		_root_box.add_child(_label(_error_text(app_view), 18, SNSkin.color("state.danger")))
		return
	var app: Dictionary = app_view["data"]
	_refresh_footer()
	var has_run := bool(app.get("has_run", false))
	_set_menu_visual(not has_run)
	if not has_run:
		_hide_port_stage()
		_story_vm = {}
		_task_vm = {}
		_update_story_layer()
		_build_menu(app)
		return
	var port_result := _context.queries.execute(&"port.view")
	if not bool(port_result.get("ok", false)):
		_hide_port_stage()
		_root_box.add_child(_label(_error_text(port_result), 18, SNSkin.color("state.danger")))
		return
	var data: Dictionary = port_result["data"]
	_last_port_view = data
	# 4.5 / U1：剧情 ViewModel 同时驱动功能门禁、剧情卡与目标条。
	var story_result := _context.queries.execute(&"story.view")
	_story_vm = story_result.get("data", {}) if bool(story_result.get("ok", false)) else {}
	# 4.6 Phase A：任务追踪聚合（剧情目标 / 主线 / 已接委托）。
	var task_result := _context.queries.execute(&"task.view")
	_task_vm = task_result.get("data", {}) if bool(task_result.get("ok", false)) else {}
	_update_story_layer()
	var at_sea := bool(data.get("at_sea", false))
	# While the voyage presentation owns the screen the player is not actually in
	# port: navigation stays hidden and the chart page is mounted instead.
	var presenting := _presentation_on_chart()

	# The victory summary takes priority over the regular screens until the
	# player explicitly dismisses it. The dismissed flag is UI-session state
	# only and never written to the save.
	var victory := _victory_view()
	var victory_active := bool(victory.get("achieved", false)) and not _victory_dismissed
	# One compact chrome serves every port/flow page; navigation is omitted while
	# at sea, exactly like the old separate nav panel. During the演出 the chrome
	# must show the departure harbour and "在航 → 目的港" even though the domain
	# already settled the arrival, otherwise the header would reveal the ending.
	var chrome_data := data
	if _presentation != null:
		chrome_data = data.duplicate(true)
		chrome_data["at_sea"] = true
		chrome_data["current_port_id"] = String(_presentation_voyage.get("origin", data.get("current_port_id", "")))
		chrome_data["voyage"] = _presentation_voyage
	_build_top_chrome(app, chrome_data, not at_sea and _presentation == null)
	# 4.5.3：目标条浮在页面顶部，给它留出高度，避免盖住市场 / 海图等页面的标题。
	# 4.6：剧情目标或任务追踪条都可能占用这一行。
	if ((_story_active() and _story_vm.get("objective", null) is Dictionary \
			and not (_story_vm.get("card", null) is Dictionary)) \
			or _task_tracker != null) \
			and not at_sea and _presentation == null:
		var story_spacer := Control.new()
		story_spacer.name = "StoryObjectiveSpacer"
		story_spacer.custom_minimum_size = Vector2(0, 46)
		_root_box.add_child(story_spacer)
	if victory_active:
		_hide_port_stage()
		_build_status_banner()
		_screen_victory(victory)
		return
	if _presentation_on_stage():
		# Departure / arrival cut: the harbour *is* the screen, no page on top.
		_build_status_banner()
		_screen_voyage_stage(data)
		return
	if _presentation_on_alert():
		# 探索演出 · 资源告急（4.2）：海图已被云层盖住，事件页换成告警页。
		# 必须在 `presenting` / `at_sea` 之前判断，否则会先挂出海图页。
		_hide_port_stage()
		_build_status_banner()
		_screen_explore_alert(data)
		return
	if presenting:
		_hide_port_stage()
		_build_status_banner()
		_screen_at_sea(data, data.get("voyage", null))
		return
	if at_sea:
		_hide_port_stage()
		_build_status_banner()
		var voyage: Variant = data.get("voyage", null)
		if voyage is Dictionary and voyage.get("event", null) is Dictionary:
			_screen_event(data, voyage["event"])
		else:
			_screen_at_sea(data, voyage)
		return

	_build_status_banner()
	# 4.5.3：旧存档 / 旧入口把 supply 视为市场页（补给区块在位）。
	if _active_screen == "supply":
		_active_screen = "market"
	# 4.5.4：旧存档 / 旧入口把 intel 视为酒馆页。
	if _active_screen == "intel":
		_active_screen = "tavern"
	if not SCREENS.has(_active_screen) \
			and not ["port_memory", "settlement", "sea_chart", "clue_log"].has(_active_screen):
		_active_screen = "overview"
	# The overview main view is a full-window 3D stage with edge HUD; the other
	# pages keep their own layout. 2026-10-28: the old bottom status strip was
	# removed (duplicate of the top chrome), so pages no longer toggle it here.
	match _active_screen:
		"market":
			_screen_market(data)
		"contracts":
			_screen_contracts(data)
		"shipyard":
			_screen_shipyard(data)
		"base":
			_screen_base(data)
		"trade":
			_screen_trade(data)
		"ruins":
			_screen_ruins(data)
		"tavern":
			_screen_tavern(data)
		"sea_chart":
			_screen_sea_chart(data)
		"clue_log":
			_screen_clue_log(data)
		"port_memory":
			_screen_port_memory(data)
		"settlement":
			_screen_settlement(data)
		_:
			_screen_overview(data)
	_sync_port_stage(data)
	_sync_footer_visibility()
	# 4.7 / dev.3 #3：页面挂好后再解析引导目标（市场补给区块 / 海图入口 / 导航按钮）。
	_sync_story_focus()
	# 刚重建的 TopChrome / Nav 还没有完成容器排版，上面这次同步读到的是旧矩形；
	# 重建后补两次 deferred 重同步（兜底目标重解析 / 页面挂载顺序），位置则由遮罩
	# 绑定目标控件逐帧自愈。详见 `_sync_story_focus_soon()`。
	_sync_story_focus_soon()


## ---------------------------------------------------------------------------
## Stage 4.5 story layer + feature gating
## ---------------------------------------------------------------------------


func _story_active() -> bool:
	if _story_vm.is_empty():
		return false
	return bool(_story_vm.get("enabled", false)) \
		and bool(_story_vm.get("active", false)) \
		and not bool(_story_vm.get("completed", true))


## True when the feature is usable. No story / finished story / old saves = all open.
func _story_feature_unlocked(feature: String) -> bool:
	if feature.is_empty() or _story_vm.is_empty():
		return true
	if not bool(_story_vm.get("enabled", false)):
		return true
	if not bool(_story_vm.get("active", false)) or bool(_story_vm.get("completed", true)):
		return true
	var unlocked := Array(_story_vm.get("unlocked_features", []))
	if unlocked.has(feature):
		return true
	# 4.5.3：补给页并入市场；旧存活的 mid-tutorial 存档可能只解锁过 supply。
	if feature == StoryService.FEATURE_MARKET and unlocked.has(StoryService.FEATURE_SUPPLY):
		return true
	return false


## Maps a nav screen to the framework feature the story unlocks.
func _story_screen_feature(screen: String) -> String:
	match screen:
		"overview":
			return StoryService.FEATURE_OVERVIEW
		"market":
			return StoryService.FEATURE_MARKET
		"contracts":
			return StoryService.FEATURE_CONTRACTS
		"shipyard":
			return StoryService.FEATURE_SHIPYARD
		"base":
			# D3：基地页随船厂一同解锁，教程开场不暴露额外入口。
			return StoryService.FEATURE_SHIPYARD
		"trade":
			# D4：自动贸易同样在船厂阶段解锁。
			return StoryService.FEATURE_SHIPYARD
		"ruins":
			# D5：遗迹远征随船厂阶段解锁。
			return StoryService.FEATURE_SHIPYARD
		"supply":
			# 4.5.3 补给页已并入市场；旧入口重定向到市场。
			return StoryService.FEATURE_MARKET
		"intel":
			# 4.5.4：旧入口重定向到酒馆页；门禁键统一为 tavern。
			return StoryService.FEATURE_TAVERN
		"tavern":
			return StoryService.FEATURE_TAVERN
		_:
			return ""


func _ensure_story_layer() -> Control:
	if _story_layer != null and is_instance_valid(_story_layer):
		return _story_layer
	_story_layer = Control.new()
	_story_layer.name = "StoryLayer"
	_story_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_story_layer)
	return _story_layer


func _clear_story_layer() -> void:
	_story_card = null
	_story_objective = null
	_task_tracker = null
	_story_focus = null
	_story_card_open = false
	if _story_layer == null or not is_instance_valid(_story_layer):
		return
	for child in _story_layer.get_children():
		_story_layer.remove_child(child)
		child.queue_free()
	_story_layer.visible = false


## ---------------------------------------------------------------------------
## 拿起光标幽灵 + 交互处浮出提示（feedback #1 / dev.3 feedback #4）
## ---------------------------------------------------------------------------
##
## One shared Shell overlay hosts both transient interaction feedback components.
## It is full-rect and mouse-transparent, sits above the pages and below the
## transition fade, and lives outside `PageMargin/PageScroll` so a page can never
## clip the ghost or the hint at 960×540 / 1440×900.

func _ensure_hint_layer() -> Control:
	if _hint_layer != null and is_instance_valid(_hint_layer):
		return _hint_layer
	_hint_layer = Control.new()
	_hint_layer.name = "HintLayer"
	_hint_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_layer)
	if _fade_layer != null and is_instance_valid(_fade_layer):
		# Below the transition fade: a page transition still darkens the feedback.
		move_child(_hint_layer, _fade_layer.get_index())
	return _hint_layer


## Cursor ghost of the 拿起手势; created lazily on the shared hint layer.
func _ensure_carry_ghost() -> Control:
	if _carry_ghost != null and is_instance_valid(_carry_ghost):
		return _carry_ghost
	var ghost: Control = CARRY_GHOST_SCENE.instantiate() as Control
	ghost.name = "CarryGhost"
	_ensure_hint_layer().add_child(ghost)
	_carry_ghost = ghost
	return _carry_ghost


## Shows (or updates) the carried stack from a `MarketScreen.carry_changed` offer.
## The pickup sound plays only when a carry actually starts, not on every +1.
## 市场格角标显示剩余库存，玩家已选数量与预计消费（单价 × 数量）画在幽灵上。
func _show_carry_ghost(offer: Dictionary) -> void:
	if offer.is_empty():
		_hide_carry_ghost()
		return
	var ghost := _ensure_carry_ghost()
	var started := not bool(ghost.call("is_carrying"))
	var amount := int(offer.get("amount", 0))
	var unit_price := int(offer.get("unit_price", 0))
	var cost_text := ""
	if unit_price > 0 and amount > 0:
		cost_text = _tr("ui.market.estimated_cost", "预计消费 %d 金") % (unit_price * amount)
	ghost.call(
		"begin",
		offer.get("icon", null) as Texture2D,
		String(offer.get("name", "")),
		amount,
		_tr("ui.hint.market_pickup", ""),
		cost_text
	)
	if started:
		_play_pickup()


func _hide_carry_ghost() -> void:
	if _carry_ghost == null or not is_instance_valid(_carry_ghost):
		return
	_carry_ghost.call("end")


## Floating command feedback at the cursor; created lazily on the shared hint layer.
func _ensure_interaction_hint() -> Control:
	if _interaction_hint != null and is_instance_valid(_interaction_hint):
		return _interaction_hint
	var hint: Control = INTERACTION_HINT_SCENE.instantiate() as Control
	hint.name = "InteractionHint"
	_ensure_hint_layer().add_child(hint)
	_interaction_hint = hint
	return _interaction_hint


func _show_interaction_hint(message: String, is_error: bool) -> void:
	if message.is_empty():
		return
	var hint := _ensure_interaction_hint()
	var at := get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO
	hint.call("show_at", at, message, is_error)


func _hide_interaction_hint() -> void:
	if _interaction_hint == null or not is_instance_valid(_interaction_hint):
		return
	_interaction_hint.call("hide_hint")


## True only while the player is on a port page of a live run: menus, story cards,
## voyage演出 and page fades never pop the floating hint.
func _in_port_interaction() -> bool:
	if _context == null or not _context.has_run():
		return false
	if _presentation != null or _transitioning or _story_card_open:
		return false
	return SCREENS.has(_active_screen)


## The highest-priority aggregated task (`task.view.active_task`), or `{}`.
func _active_task() -> Dictionary:
	var task: Variant = _task_vm.get("active_task", null)
	return task if task is Dictionary else {}


## Rebuilds the full-window story card and the non-blocking HUD strip. The strip
## shows the story objective while a story objective exists; otherwise it falls back
## to the aggregated task tracker (main / normal contract steps) so the player still
## knows what to do after the tutorial.
func _update_story_layer() -> void:
	var task := _active_task()
	if not _story_active():
		if task.is_empty():
			_clear_story_layer()
			return
		var layer := _ensure_story_layer()
		for child in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
		_story_card = null
		_story_objective = null
		_task_tracker = null
		_story_focus = null
		_story_card_open = false
		_mount_task_tracker(layer, task)
		layer.visible = true
		if layer.get_parent() == self:
			move_child(layer, get_child_count() - 1)
		return
	var layer := _ensure_story_layer()
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()
	_story_card = null
	_story_objective = null
	_task_tracker = null
	_story_focus = null
	_story_card_open = false
	var card: Variant = _story_vm.get("card", null)
	if card is Dictionary:
		var card_control: Control = STORY_CARD_SCRIPT.new()
		card_control.name = "StoryCard"
		layer.add_child(card_control)
		card_control.bind(card as Dictionary, Callable(self, "_tr"))
		card_control.advance_requested.connect(func() -> void:
			_run_command(&"story.advance", {})
		)
		card_control.skip_requested.connect(func() -> void:
			_run_command(&"story.skip", {})
		)
		_story_card = card_control
		_story_card_open = true
	var objective: Variant = _story_vm.get("objective", null)
	if objective is Dictionary and _story_card == null:
		var objective_control: Control = STORY_OBJECTIVE_SCRIPT.new()
		objective_control.name = "StoryObjective"
		layer.add_child(objective_control)
		objective_control.bind(
			String((objective as Dictionary).get("text_key", "")),
			int((objective as Dictionary).get("progress", 0)),
			int((objective as Dictionary).get("target", 0)),
			Callable(self, "_tr")
		)
		_story_objective = objective_control
		call_deferred("_place_story_objective")
	elif _story_card == null and not task.is_empty() and String(task.get("kind", "")) != "story":
		# 剧情没有目标时（转场卡 / 结束）交给统一任务追踪条。
		_mount_task_tracker(layer, task)
	# 4.7 / dev.3 #3：强制引导遮罩最后挂：它必须在目标条 / 任务追踪条之上，否则
	# 提示文案会被目标条压住（2026-10-28 P0：右上「市场」引导的提示首字被压掉）。
	# 卡片打开时 `_story_focus_requested()` 为 false，遮罩不会盖住剧情卡。
	# 目标矩形的解析与布局在所有页面挂好之后由 `_sync_story_focus()` 完成。
	if _story_focus_requested():
		var focus_control: Control = STORY_FOCUS_SCRIPT.new()
		focus_control.name = "StoryFocus"
		layer.add_child(focus_control)
		_story_focus = focus_control
	layer.visible = true
	if layer.get_parent() == self:
		move_child(layer, get_child_count() - 1)


func _mount_task_tracker(layer: Control, task: Dictionary) -> void:
	var tracker: Control = TASK_TRACKER_SCRIPT.new()
	tracker.name = "TaskTracker"
	layer.add_child(tracker)
	tracker.bind(task, int(_task_vm.get("task_count", 1)), Callable(self, "_tr"))
	_task_tracker = tracker
	call_deferred("_place_story_objective")


## Centers the non-blocking story objective / task tracker under the top chrome once
## layout has settled.
func _place_story_objective() -> void:
	var control: Control = _story_objective
	if control == null or not is_instance_valid(control):
		control = _task_tracker
	if control == null or not is_instance_valid(control):
		return
	if _story_layer == null or not is_instance_valid(_story_layer):
		return
	control.reset_size()
	var width := control.size.x
	var x := maxf(8.0, (_story_layer.size.x - width) * 0.5)
	var y := _port_hud_top_safe() + 4.0
	# At sea the page starts straight under the chrome (no StoryObjectiveSpacer),
	# so a status banner ("离港，航向…") sits at the same y as this fixed strip.
	# Push the strip below the banner instead of letting the two overlap.
	var banner := _root_box.get_node_or_null("StatusBanner") as Control
	if banner != null and is_instance_valid(banner) and banner.visible:
		var banner_rect := banner.get_global_rect()
		if banner_rect.size.y > 0.0:
			var layer_top := _story_layer.get_global_rect().position.y
			y = maxf(y, banner_rect.end.y - layer_top + 4.0)
	control.position = Vector2(x, y)


## True when the current story stage declares a guided-focus target and no story card
## is on screen (dev.3 feedback #3: the card always wins over the mask).
func _story_focus_requested() -> bool:
	if not _story_active():
		return false
	if _story_vm.get("card", null) is Dictionary:
		return false
	var focus: Variant = _story_vm.get("focus", null)
	return focus is Dictionary and not String((focus as Dictionary).get("target", "")).is_empty()


## Resolves `story.view.focus.target` (framework semantic id, never a page path) into
## the live control and hands the overlay the target itself, not just a rect: freshly
## mounted containers are sorted deferred, so a one-shot `get_global_rect()` snapshot
## would stay stale (the 2026-10-28 P0: focus ring in the top-left, market button in
## the top-right). Called after the page tree is mounted (immediate + two deferred
## passes), on page switches (rebuild) and on resize. Missing / unmounted targets fail
## open (mask cleared) so a content typo can never trap the player.
func _sync_story_focus() -> void:
	if _story_focus == null or not is_instance_valid(_story_focus):
		return
	if not _story_focus_requested() or _presentation != null or _story_card_open \
			or not (SCREENS.has(_active_screen) or _active_screen == "sea_chart"):
		_story_focus.call("clear_focus")
		return
	var focus: Dictionary = _story_vm.get("focus", {})
	var target := _resolve_story_focus_target(String(focus.get("target", "")))
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		_story_focus.call("clear_focus")
		return
	var rect := target.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		_story_focus.call("clear_focus")
		return
	# 文案键缺失时不要渲染裸键名（content / 本地化缺键只显示遮罩）。
	var text_key := String(focus.get("text_key", ""))
	var hint := "" if text_key.is_empty() else _tr(text_key, "")
	if hint == text_key:
		hint = ""
	# 绑定控件让遮罩在排版完成后自愈；无 `focus_target` 的旧实现退回一次性矩形。
	if _story_focus.has_method("focus_target"):
		_story_focus.call("focus_target", target, hint)
	else:
		_story_focus.call("focus", rect, hint)


## Re-runs `_sync_story_focus()` on the next two idle frames. Rebuilding the chrome
## creates brand-new containers whose layout happens deferred in the same frame, so
## the immediate sync above can only read a pre-layout rect; the second pass catches
## the follow-up stage / SubViewport resize (same shape as `_refresh_port_hotspots_soon`).
func _sync_story_focus_soon() -> void:
	_sync_story_focus.call_deferred()
	_delayed_story_focus_pass.call_deferred()


func _delayed_story_focus_pass() -> void:
	_sync_story_focus.call_deferred()


## Semantic focus target -> real control. Targets name framework surfaces, so Core
## content never references a page / node path:
##   market_supply   market page supply section (or the market nav entry when the
##                   player is still on another port page)
##   chart_entry     the chart entry (status-strip button on overview / nav toggle)
##   chart_close     the chart page close button (falls back to the chart toggle)
##   <screen>_nav    that screen's navigation button (market_nav / contracts_nav …)
func _resolve_story_focus_target(target_id: String) -> Control:
	if target_id.is_empty():
		return null
	match target_id:
		"market_supply":
			if _active_screen == "market":
				var supply := find_child("MarketSupply", true, false) as Control
				if supply != null:
					return supply
			return _story_nav_button("market")
		"chart_entry", "chart_nav":
			return _story_chart_entry_control()
		"chart_close":
			if _active_screen == "sea_chart":
				var close := find_child("CloseButton", true, false) as Control
				if close != null:
					return close
			return _story_chart_entry_control()
	if target_id.ends_with("_nav"):
		return _story_nav_button(target_id.trim_suffix("_nav"))
	if not bool(_story_focus_warned.get(target_id, false)):
		_story_focus_warned[target_id] = true
		push_warning("SNFocusOverlay: unknown story focus target '%s'" % target_id)
	return null


## A navigation button from the compact chrome. 2026-10-28 图标轮：按钮是纯图标，
## 入口身份存放在 `nav_screen` meta 里，所以解析优先按 meta；旧皮肤 / 旧路径仍可能
## 用文字标按钮，保留精确文字匹配作为回退，隐藏入口继续返回 null。
func _story_nav_button(screen: String) -> Control:
	var nav := find_child("Nav", true, false)
	if nav == null:
		return null
	for child in nav.get_children():
		if child is Button and String((child as Button).get_meta("nav_screen", "")) == screen:
			return child
	var wanted := _tr("ui.nav.%s" % screen, screen)
	for child in nav.get_children():
		if child is Button and String((child as Button).text) == wanted:
			return child
	return null


## The chart entry is the nav toggle (`nav_screen = sea_chart`); the same button
## closes the chart while that page is up. 2026-10-28：底部状态条的 `ChartButton`
## 随状态条一起移除，剧情引导的 `chart_entry` 目标改为导航里的海图按钮。
func _story_chart_entry_control() -> Control:
	return _story_nav_button("sea_chart")


## Forwards a successful command / UI event to the story state machine and the quest
## progress tracker. Returns true when either moved (caller should refresh the UI).
func _observe_story(event: String, data: Dictionary = {}) -> bool:
	if _context == null or not _context.has_run():
		return false
	var story_advanced := false
	if _story_active():
		var before_stage := int(_story_vm.get("stage_index", -1))
		var before_completed := bool(_story_vm.get("completed", false))
		var result := _context.commands.execute(
			&"story.observe", {"event": event, "data": data}
		)
		if bool(result.get("ok", false)):
			var after_view: Dictionary = result.get("data", {}).get("view", {})
			story_advanced = int(after_view.get("stage_index", before_stage)) != before_stage \
				or bool(after_view.get("completed", false)) != before_completed
			if story_advanced and not after_view.is_empty():
				# UI 事件（开 / 关海图）在重建中途观察；先同步 VM，调用方再按需 deferred 刷新。
				_story_vm = after_view
	return _observe_quests(event, data) or story_advanced


## C3：Quest 目标复用同一套 `cmd:*` / `ui:*` 事件流，与 story 是否 active 无关。
## `active`（跨 stage / 完成）与 `progressed`（counter 变化）都需要刷新任务条。
func _observe_quests(event: String, data: Dictionary = {}) -> bool:
	if _context == null or not _context.has_run():
		return false
	if not _context.commands.has(&"quest.observe"):
		return false
	if not QuestService.has_active_content(_context.state):
		return false
	var result := _context.commands.execute(
		&"quest.observe", {"event": event, "data": data}
	)
	if not bool(result.get("ok", false)):
		return false
	var payload: Dictionary = result.get("data", {})
	return bool(payload.get("advanced", false)) or bool(payload.get("progressed", false))


## True when the current story stage temporarily locks an action (e.g. supply.buy
## while the chart briefing is pending). The lock is content-driven via
## `story.view.lock_actions`.
func _story_action_locked(command: StringName) -> bool:
	if not _story_active():
		return false
	var command_name := String(command)
	for action in Array(_story_vm.get("lock_actions", [])):
		var action_name := String(action)
		if action_name.is_empty():
			continue
		# 命令命名同时使用 `.` 与 `_`（supply.buy_coal），锁动作按前缀匹配两者。
		if command_name == action_name \
				or command_name.begins_with(action_name + ".") \
				or command_name.begins_with(action_name + "_"):
			return true
	return false


## ---------------------------------------------------------------------------
## Compact top chrome (shared by every in-run page)
## ---------------------------------------------------------------------------
##
## Two dense rows replace the old header + stats bar + navigation stack:
##   row 1  brand / status / version | port · time · money · reputation | stage
##          toggle · diagnostics · refresh
##   row 2  remaining weight / cargo / coal / water / durability / damaged chip |
##          7 navigation buttons
## The panel is semi-transparent so the 3D stage shows through; the measured
## minimum height stays below `TOP_CHROME_MAX_HEIGHT`.
func _build_top_chrome(app: Dictionary, data: Dictionary, show_nav: bool) -> void:
	var panel := PanelContainer.new()
	panel.name = "TopChrome"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chrome_style := _chrome_style()
	if chrome_style != null:
		panel.add_theme_stylebox_override("panel", chrome_style)
	else:
		# No skin (missing manifest/textures): the generated theme variation still
		# gives the chrome a textured frame; the 2D fallback is never layoutless.
		panel.theme_type_variation = &"SNChromePanel"
	_root_box.add_child(panel)
	_top_chrome = panel
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)

	var row := HBoxContainer.new()
	row.name = "Chrome"
	row.add_theme_constant_override("separation", 12)
	rows.add_child(row)
	var brand := VBoxContainer.new()
	brand.name = "PortBrand"
	brand.add_theme_constant_override("separation", 0)
	brand.tooltip_text = _tr("ui.label.port", "Port")
	row.add_child(brand)
	# 2026-10-28 图标轮：删掉 9 px 的「港口」小标题，品牌列只留港口名。
	brand.add_child(_label(_current_port_label(data), 22, SNSkin.color("brass.highlight")))
	row.add_child(_badge(
		_tr(String(app.get("status_key", "ui.status.ok")), ""),
		_status_badge_tone(app)
	))
	row.add_child(_label("v%s" % app.get("framework_version", "?"), 10, SNSkin.color("text.muted")))
	row.add_child(VSeparator.new())
	# 时间 / 金币 / 声望：只留图标 + 数值，标签文案进 tooltip（`_stat_chip` 负责）。
	for stat in [
		[_tr("ui.label.time", "Time"), String(data.get("time_label", "")), SNSkin.color("text.light"), "time"],
		[_tr("ui.label.money", "Money"), str(int(data.get("money", 0))), SNSkin.color("brass.highlight"), "money"],
		[_tr("ui.label.reputation", "Reputation"), str(int(data.get("reputation", 0))), SNSkin.color("state.success"), "reputation"],
	]:
		row.add_child(_stat_chip(stat[0], stat[1], stat[2], 16, String(stat[3])))
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(top_spacer)
	if _active_screen == "overview" and _port_stage_available():
		var stage_button := _small_chrome_button(
			_tr("ui.button.overview_2d", "2D overview")
			if _overview_stage_mode
			else _tr("ui.button.port_stage", "Port view (3D)"),
			_on_overview_stage_toggle
		)
		row.add_child(stage_button)
	row.add_child(_small_chrome_button(_tr("ui.button.log", "Diagnostics"), _show_diagnostics))
	row.add_child(_small_chrome_button(_tr("ui.button.refresh", "Refresh"), _refresh))

	var row2 := HBoxContainer.new()
	row2.name = "ChromeDetail"
	row2.add_theme_constant_override("separation", 14)
	rows.add_child(row2)
	var ship: Dictionary = data.get("ship", {})
	var detail_stats := [
		[_tr("ui.label.free_weight", ""), "%s / %s" % [
			_fmt(float(ship.get("free_weight", 0.0))),
			_fmt(float(ship.get("max_weight", 0.0))),
		], SNSkin.color("text.light"), "free_weight"],
		[_tr("ui.label.free_capacity", ""), "%s / %s" % [
			_fmt(float(ship.get("free_cargo_capacity", 0.0))),
			_fmt(float(ship.get("cargo_capacity", 0.0))),
		], SNSkin.color("state.water"), "free_capacity"],
		[_tr("ui.label.coal", "Coal"), _fmt(float(ship.get("coal", 0.0))), SNSkin.color("brass.highlight"), "coal", "CoalChip"],
		[_tr("ui.label.water", "Water"), _fmt(float(ship.get("water", 0.0))), SNSkin.color("state.water"), "water", "WaterChip"],
		[_tr("ui.label.durability", "Durability"), "%s / %s" % [
			_fmt(float(ship.get("durability", 0.0))),
			_fmt(float(ship.get("max_durability", 0.0))),
		], SNSkin.color("state.success"), "durability"],
	]
	var damaged_modules := int(ship.get("damaged_modules", 0))
	if damaged_modules > 0:
		var worst := clampf(float(ship.get("worst_module_condition", 1.0)), 0.0, 1.0)
		detail_stats.append([
			_tr("ui.label.module_status", "Modules"),
			"%d · %d%%" % [damaged_modules, int(round(worst * 100.0))],
			SNSkin.color("state.danger") if worst <= 0.0 else SNSkin.color("brass.base"),
			"damaged",
		])
	for stat in detail_stats:
		var chip_key := String(stat[4]) if stat.size() > 4 else ""
		var stat_chip := _stat_chip(stat[0], stat[1], stat[2], 16, String(stat[3]), chip_key)
		row2.add_child(stat_chip)
		# 4.3.5 / U8：演出中只有煤 / 水读数需要逐帧插值，保存它们的数值 Label。
		if chip_key == "CoalChip":
			_hud_coal_value = stat_chip.find_child("Value", true, false) as Label
		elif chip_key == "WaterChip":
			_hud_water_value = stat_chip.find_child("Value", true, false) as Label
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(bottom_spacer)
	if show_nav:
		_build_nav_buttons(row2)


## Builds the compact navigation row from `SCREENS`, minus `HIDDEN_NAV_SCREENS`
## (unpublished systems: base / auto trade / ruins) and minus story-locked pages.
## 2026-10-28 图标轮：每个入口是「皮肤图标 + 本地化页名」的 64×36 按钮；入口身份
## 仍由 `nav_screen` meta 承载，剧情强制引导与快照工具按 meta 解析（不依赖按钮文字）。
## Page routing itself is unchanged, so the internal pages stay reachable by the
## snapshot tool and future re-release.
func _build_nav_buttons(parent: HBoxContainer) -> void:
	var visual_active := "overview" if _active_screen in ["port_memory", "settlement", "victory"] else _active_screen
	# Nested container so the compact navigation gap does not override the
	# resource-chip spacing of the chrome row it is mounted in.
	var nav := HBoxContainer.new()
	nav.name = "Nav"
	nav.add_theme_constant_override("separation", 2)
	parent.add_child(nav)
	for screen in SCREENS:
		if HIDDEN_NAV_SCREENS.has(screen):
			# 未发布系统：页面保留但不出现在玩家可见的导航里。
			continue
		if not _story_feature_unlocked(_story_screen_feature(screen)):
			continue
		var nav_label := _tr("ui.nav.%s" % screen, screen)
		var button := _button(nav_label, _on_nav.bind(screen))
		button.set_meta("nav_screen", screen)
		button.custom_minimum_size = Vector2(64, 36)
		button.add_theme_font_size_override("font_size", 13)
		# Current page uses the selected plate texture; every other entry is a
		# compact plate. Both are external-texture Theme variations, so the
		# button text/behaviour stays stock Button.
		button.theme_type_variation = &"SNPrimaryButton" if screen == visual_active else &"SNCompactButton"
		_apply_skin_icon(button, NAV_ICONS.get(screen, ""))
		nav.add_child(button)
	# The nautical chart is a toggle, not a nav page: M opens/closes it and the
	# button highlights only while the chart is up. Gated by the story feature.
	if _story_feature_unlocked(StoryService.FEATURE_CHART):
		var chart_button := _button(_tr("ui.nav.sea_chart", "海图"), _toggle_sea_chart)
		chart_button.set_meta("nav_screen", "sea_chart")
		chart_button.custom_minimum_size = Vector2(64, 36)
		chart_button.add_theme_font_size_override("font_size", 13)
		chart_button.theme_type_variation = &"SNPrimaryButton" if _active_screen == "sea_chart" else &"SNCompactButton"
		_apply_skin_icon(chart_button, NAV_ICONS["sea_chart"])
		nav.add_child(chart_button)


## Attaches a skin icon to a stock Button without wrapping it: id comes from the
## skin manifest, width is bounded by `icon_max_width`, and a missing skin simply
## leaves the button text-only.
func _apply_skin_icon(button: Button, icon_id: String) -> void:
	if icon_id.is_empty():
		return
	var icon_texture := SNSkin.icon(icon_id)
	button.icon = icon_texture
	if icon_texture != null:
		button.add_theme_constant_override("icon_max_width", NAV_ICON_MAX_WIDTH)


func _small_chrome_button(text: String, callback: Callable) -> Button:
	var button := _button(text, callback)
	button.theme_type_variation = &"SNCompactButton"
	button.custom_minimum_size = Vector2(0, 30)
	button.add_theme_font_size_override("font_size", 12)
	return button


## Semi-transparent textured chrome so the 3D stage is visible but the HUD stays
## readable over bright sky, water or a banner. The texture and content margins
## (16/12) come from the skin manifest; null means no skin, and the caller falls
## back to the generated Theme's `SNChromePanel`.
func _chrome_style() -> StyleBox:
	return SNSkin.panel("chrome")


func _status_badge_tone(app: Dictionary) -> int:
	match String(app.get("status", "fatal")):
		"ok":
			return SNBadge.Tone.SUCCESS
		"degraded":
			return SNBadge.Tone.WARNING
		_:
			return SNBadge.Tone.DANGER


func _status_color(app: Dictionary) -> Color:
	match String(app.get("status", "fatal")):
		"ok":
			return SNSkin.color("state.success")
		"degraded":
			return SNSkin.color("state.warning")
		_:
			return SNSkin.color("state.danger")


## Current port (or the destination while at sea) for the always-visible info bar.
func _current_port_label(data: Dictionary) -> String:
	var port: Dictionary = data.get("current_port", {})
	if bool(data.get("at_sea", false)):
		var voyage: Variant = data.get("voyage", null)
		if voyage is Dictionary:
			var destination := String(voyage.get("destination", ""))
			if not destination.is_empty():
				return "%s → %s" % [_tr("ui.label.at_sea", ""), _port_name(destination)]
			# 探索演出：目的港要等 `explore.settle` 才知道，顶栏只能显示"探索中 → ？"。
			if not _presentation_explore.is_empty():
				return "%s → %s" % [
					_tr("ui.label.exploring", "探索中"),
					_tr("ui.label.unknown_destination", "？"),
				]
		return _tr("ui.label.at_sea", "")
	return _tr(String(port.get("name_key", "")), String(port.get("id", "")))


## One compact HUD stat: icon + value on a single line（2026-10-28 图标轮）。
## `label_text` 不再画成 9 px 小标题，改为 chip 的 `tooltip_text`，让纯图标读数仍可解释。
## `chip_key`（4.3.5 / U8）继续给需要逐帧改读数的 chip（煤 / 水）一个稳定名字，并把
## 数值 Label 命名为 `Value`，Shell 据此保存引用。
func _stat_chip(label_text: String, value_text: String, accent: Color, value_size: int = 15, icon_key: String = "", chip_key: String = "") -> Control:
	var chip := HBoxContainer.new()
	if not chip_key.is_empty():
		chip.name = chip_key
	chip.add_theme_constant_override("separation", 6)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not label_text.is_empty():
		chip.tooltip_text = label_text
	var icon := _hud_icon(icon_key)
	if icon != null:
		var texture_rect := TextureRect.new()
		texture_rect.texture = icon
		texture_rect.custom_minimum_size = Vector2(HUD_ICON_SIZE, HUD_ICON_SIZE)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(texture_rect)
	var value_label := _label(value_text, value_size, accent)
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not chip_key.is_empty():
		value_label.name = "Value"
	chip.add_child(value_label)
	return chip


## HUD icon for a logical chip key (`HUD_SKIN_ICONS`). Content packs may still
## override a key through `HUD_ICON_KEYS` (`icon.*` → `AssetService.find_key` /
## `load_texture`, so the framework never hardcodes a mod namespace); a retired or
## missing key makes `find_key` return empty, which just falls through to the skin
## icon. Both missing -> null (text-only chip).
func _hud_icon(icon_key: String) -> Texture2D:
	if icon_key.is_empty():
		return null
	if _hud_icon_cache.has(icon_key):
		return _hud_icon_cache[icon_key] as Texture2D
	var texture: Texture2D = null
	var content_key := String(HUD_ICON_KEYS.get(icon_key, ""))
	if _context != null and not content_key.is_empty():
		var logical_key := _context.assets.find_key(content_key)
		if not logical_key.is_empty() and _context.assets.has(logical_key):
			texture = _context.assets.load_texture(logical_key)
	if texture == null:
		var skin_id := String(HUD_SKIN_ICONS.get(icon_key, ""))
		if not skin_id.is_empty():
			texture = SNSkin.icon(skin_id)
	_hud_icon_cache[icon_key] = texture
	return texture


## Layout note: `project.godot` uses `canvas_items` stretch with a 1440x900 base
## and `expand` aspect, so a real 960x540 window renders a scaled 1600x900
## logical canvas: the two-row HUD keeps every chip and fits without clipping.
## There is therefore no compact/drop-secondary branch; the 960x540 acceptance
## screenshot is the evidence that the full layout stays in frame.
func _build_status_banner() -> void:
	if _status_message.is_empty():
		return
	var panel := _panel()
	panel.name = "StatusBanner"
	panel.theme_type_variation = &"SNInsetPanel"
	_panel_add(panel, _badge(_status_message, SNBadge.Tone.DANGER if _status_is_error else SNBadge.Tone.SUCCESS))
	_root_box.add_child(panel)


## ---------------------------------------------------------------------------
## 用户反馈：底部状态条与顶部 chrome 完全重复（耐久 / 货舱 / 煤 / 水 / 受损、
## 海图入口都在顶部或导航里），因此整条移除。它原先额外提供的「详细总览」抽屉
## 与「等待 12 h」分别由顶部「2D 总览」开关和总览页的快捷入口（6/12/24 h）承担，
## 海图入口由顶部导航承担；通告正文在总览页「航行记录」面板里。
##
## 2026-10-28 图标轮：热门 chip 的图标化改进（受损时不显示警告图标）随状态条一起移除。


func _build_menu(app: Dictionary) -> void:
	if _menu_screen != "main":
		_hide_update_dialog()
	var report: Dictionary = app.get("report", {})
	if not report.get("errors", []).is_empty():
		var error_panel := _panel()
		_panel_add(error_panel, _label(_tr("ui.error.start_failed", "Startup failed"), 18, SNSkin.color("state.danger")))
		for entry in report.get("errors", []):
			_panel_add(error_panel, _label("[%s] %s" % [entry.get("severity", "error"), entry.get("message", "")], 14, SNSkin.color("state.danger")))
		_root_box.add_child(error_panel)
		_root_box.add_child(_button(_tr("ui.button.retry", "Retry"), _retry_bootstrap))
		return

	match _menu_screen:
		"new_game":
			_screen_new_game(app)
		"mods":
			_screen_mods(app)
		"settings":
			_screen_settings(app)
		_:
			_screen_main_menu(app)


func _screen_main_menu(app: Dictionary) -> void:
	var vm := app.duplicate(true)
	vm["status_tone"] = _status_badge_tone(app)
	_mount_menu_screen(MAIN_MENU_SCREEN_SCENE, vm)
	_build_status_banner()


## ---------------------------------------------------------------------------
## Auto update（docs/design/AUTO_UPDATE.md）
## ---------------------------------------------------------------------------


## 发布版才创建更新服务；编辑器与无头测试保持零网络。
func _setup_update_service() -> void:
	if not OS.has_feature("template") or _settings == null or _update_service != null:
		return
	_update_service = UpdateService.new()
	_update_service.name = "UpdateService"
	add_child(_update_service)
	_update_service.configure(_settings.update_endpoint(), _settings.auto_check_updates())
	_update_service.state_changed.connect(_on_update_state_changed)
	_update_service.restart_requested.connect(_on_update_restart)
	var selftest := OS.get_cmdline_user_args().has("--update-selftest")
	if _settings.auto_check_updates() and not selftest:
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if _update_service != null and is_instance_valid(_update_service):
				_update_service.check(false))


## 状态行按钮 / 对话框 / 状态条共用同一份 state。
func _on_update_state_changed(state: Dictionary) -> void:
	if _update_dialog != null and is_instance_valid(_update_dialog) and _update_dialog.visible:
		_update_dialog.call("update", state)
	if _menu_screen == "main":
		var menu := _root_box.get_node_or_null("MainMenuScreen")
		if menu is MainMenuScreen:
			(menu as MainMenuScreen).set_update_state(state)
	match String(state.get("phase", "")):
		"available":
			_set_status(_tr("ui.update.available_status", "发现新版本 %s，可在主菜单更新") % String(state.get("tag", "")), false)
		"staged":
			_set_status(_tr("ui.update.staged_status", "更新已下载完成，重启游戏生效"), false)


func _on_check_update() -> void:
	if _update_service == null:
		_set_status(_tr("ui.update.unsupported", "当前版本不支持自动更新"), true)
		return
	var snapshot := _update_service.snapshot()
	if _menu_screen != "main":
		_on_menu("main")
	_show_update_dialog(_update_service.snapshot())
	if String(snapshot.get("phase", "")) not in ["available", "downloading", "staged"]:
		_update_service.check(true)


func _show_update_dialog(state: Dictionary) -> void:
	if _update_dialog == null or not is_instance_valid(_update_dialog):
		_update_dialog = UPDATE_DIALOG_SCENE.instantiate()
		_update_dialog.name = "UpdateDialog"
		add_child(_update_dialog)
		_update_dialog.download_pressed.connect(_on_update_download)
		_update_dialog.cancel_pressed.connect(_on_update_cancel)
		_update_dialog.restart_pressed.connect(_on_update_restart)
		_update_dialog.close_pressed.connect(_hide_update_dialog)
	move_child(_update_dialog, get_child_count() - 1)
	_update_dialog.call("bind", state, Callable(self, "_tr"))
	_update_dialog.visible = true


func _hide_update_dialog() -> void:
	if _update_dialog != null and is_instance_valid(_update_dialog):
		_update_dialog.visible = false


func _on_update_download() -> void:
	if _update_service == null:
		return
	if String(_update_service.snapshot().get("phase", "")) == "available":
		_update_service.download()
	else:
		_update_service.check(true)


func _on_update_cancel() -> void:
	if _update_service != null:
		_update_service.cancel()


## 新 exe 已就位（或 core 已暂存）：启动新进程后走正常退出清理。
func _on_update_restart() -> void:
	_hide_update_dialog()
	var executable := OS.get_executable_path()
	if executable.is_empty() or not FileAccess.file_exists(executable):
		_set_status(_tr("ui.update.restart_manually", "更新已完成，请手动重新启动游戏"), true)
		return
	OS.create_process(executable, PackedStringArray())
	_graceful_quit()


## 发布包内部验收钩子（`-- --update-selftest`）：真实 HTTP/下载/解压/自替换链路自动跑一遍。
## 只由本地 e2e 驱动脚本使用，正常启动不会触发。
func _run_update_selftest() -> void:
	if _update_service == null:
		push_error("update selftest requires a release build")
		_graceful_quit(1)
		return
	_update_service.state_changed.connect(_on_update_selftest_state)
	get_tree().create_timer(0.5).timeout.connect(_start_update_selftest_check)
	get_tree().create_timer(240.0).timeout.connect(_fail_update_selftest_timeout)


func _start_update_selftest_check() -> void:
	if _update_service != null:
		_update_service.check(true)


func _fail_update_selftest_timeout() -> void:
	push_error("update selftest timed out")
	_graceful_quit(1)


func _on_update_selftest_state(state: Dictionary) -> void:
	var phase := String(state.get("phase", ""))
	print("[update-selftest] phase=", phase, " tag=", state.get("tag", ""), " error=", state.get("error", ""))
	match phase:
		"available":
			_update_service.download()
		"staged":
			print("[update-selftest] staged")
			_graceful_quit(0)
		"up_to_date":
			print("[update-selftest] up_to_date")
			_graceful_quit(0)
		"error":
			_graceful_quit(1)


func _screen_new_game(app: Dictionary) -> void:
	var vm := app.duplicate(true)
	_tutorial_mode = _story_profile_available()
	vm["tutorial_mode"] = _tutorial_mode
	vm["selected_scenario"] = _selected_scenario
	vm["seed_text"] = _seed_text
	vm["warnings"] = app.get("report", {}).get("warnings", [])
	_mount_menu_screen(NEW_GAME_SCREEN_SCENE, vm)
	_build_status_banner()


## 4.5.2：当前内容是否有启用的剧情（决定新开局隐藏场景选择 / 传 tutorial）。
## C4：剧情随 `map_configs.story` 提供；菜单期没有 run state，直接遍历 map configs。
func _story_profile_available() -> bool:
	if _context == null:
		return false
	for profile in _context.registries.get_all(ContentTypes.MAP_CONFIG):
		var raw: Variant = profile.data.get("story", null)
		if raw is Dictionary and bool((raw as Dictionary).get("enabled", false)):
			return true
	return false


func _screen_mods(app: Dictionary) -> void:
	_mount_menu_screen(MODS_SCREEN_SCENE, app)
	_build_status_banner()


func _screen_settings(_app: Dictionary) -> void:
	_mount_menu_screen(SETTINGS_SCREEN_SCENE, {
		"locale": _context.localization.active_locale if _context != null else "zh_CN",
		"autosave_enabled": bool(_context.autosave_enabled) if _context != null else true,
		# TELEMETRY.md §2：设置页状态来自持久化设置（默认关），不读记录器内部状态。
		"telemetry_enabled": _settings != null and _settings.telemetry(),
		"show_settings_path": _settings != null,
	})
	_build_status_banner()


func _mount_menu_screen(scene: PackedScene, view_model: Dictionary) -> void:
	var screen: Variant = scene.instantiate()
	screen.bind(view_model, Callable(self, "_tr"))
	screen.action_requested.connect(_on_menu_action)
	_root_box.add_child(screen)
	if screen is MainMenuScreen and _update_service != null:
		(screen as MainMenuScreen).set_update_state(_update_service.snapshot())


## ---------------------------------------------------------------------------
## Overview
## ---------------------------------------------------------------------------

func _screen_overview(data: Dictionary) -> void:
	var screen: Variant = OVERVIEW_SCREEN_SCENE.instantiate()
	screen.bind(_overview_model(data), Callable(self, "_tr"))
	screen.navigation_requested.connect(_on_screen_navigation)
	screen.command_requested.connect(_run_command)
	screen.stage_toggle_requested.connect(_on_overview_stage_toggle)
	_root_box.add_child(screen)


func _overview_model(data: Dictionary) -> Dictionary:
	var model := data.duplicate(true)
	var port: Dictionary = data.get("current_port", {})
	var facilities: Array = []
	for facility in port.get("facilities", []):
		facilities.append(_facility_name(String(facility)))
	model["facility_labels"] = facilities
	model["banner_path"] = _port_banner_path(data)
	# 2.5D overview stage: availability is decided by the shell (scene present
	# and not previously failed); stage mode and the detail drawer are UI-session
	# state only.
	model["stage_available"] = _port_stage_available()
	model["stage_mode"] = _overview_stage_mode and _port_stage_available()
	# 4.3 / U6：详细总览不再挂旧线稿海图（`map_canvas` 已删除），全屏海图页是唯一
	# 海图入口；`map.view` 仍供港口名等其它查询使用，但不再进入总览模型。
	var contracts: Dictionary = model.get("contracts", {}).duplicate(true)
	for key in ["main", "main_offer"]:
		if contracts.get(key, null) is Dictionary:
			var contract: Dictionary = contracts[key].duplicate(true)
			contract["payload_text"] = _contract_payload_text(contract)
			contract["reward_text"] = _contract_reward_text(contract)
			contracts[key] = contract
	model["contracts"] = contracts
	var notice_texts: Array = []
	var notices: Array = data.get("notices", [])
	for notice in notices.slice(maxi(0, notices.size() - 6), notices.size()):
		notice_texts.append(_notice_text(notice))
	model["notice_texts"] = notice_texts
	return model


## ---------------------------------------------------------------------------
## Overview 3D port stage (2.5D fixed stage + edge signs + detail drawer)
## ---------------------------------------------------------------------------

## Toggles the 3D stage / 2D overview fallback. 2026-10-28：底部状态条与「详细总览」
## 抽屉一并移除（抽屉内容就是 2D 总览页，顶部「2D 总览」开关承担同一入口）。
func _on_overview_stage_toggle() -> void:
	if not _port_stage_available():
		return
	_overview_stage_mode = not _overview_stage_mode
	_status_message = ""
	_refresh()


## The stage scene is loaded lazily; a failed load permanently falls back to the
## 2D overview for this session instead of retrying on every refresh.
func _port_stage_available() -> bool:
	return not _port_stage_load_failed and ResourceLoader.exists(PORT_STAGE_SCENE_PATH)


func _ensure_port_stage_host() -> void:
	if _port_stage_host != null and is_instance_valid(_port_stage_host):
		return
	# Full-window 3D backdrop: directly above the flat Background and below every
	# UI layer, so the chrome / side signs float over the scene.
	_port_stage_host = SNStageHost.new()
	_port_stage_host.name = "PortStageHost"
	_port_stage_host.auto_load = false
	_port_stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_port_stage_host.fallback_requested.connect(_on_port_stage_fallback)
	add_child(_port_stage_host)
	_port_stage_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_port_stage_host, $Background.get_index() + 1)
	_port_stage_host.set_stage_visible(false)

	# Edge sign layer over the stage: fixed left/right columns driven by the
	# PortStage camera projection, never 3D raycasts. The layer itself ignores
	# the mouse so clicks outside the signs fall through to the page.
	_port_hotspot_layer = Control.new()
	_port_hotspot_layer.name = "PortStageHotspots"
	_port_hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_port_hotspot_layer)
	_port_hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_port_hotspot_layer, $PageMargin.get_index() + 1)
	_port_hotspot_layer.visible = false
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


## Shows the shared 3D district. `force_station` is used by the voyage演出: during
## the departure / arrival beat the harbour must be visible even though no page of
## `STAGE_SCREENS` is active, and it always plays the harbour-authority shot.
func _sync_port_stage(data: Dictionary, force_station: String = "") -> void:
	var station := force_station if not force_station.is_empty() else String(STAGE_SCREENS.get(_active_screen, ""))
	# 船厂只有改装态才画在 3D 舞台上：正常态页面自带面板内的 3D 船体舞台，
	# 两个舞台同时可见会重复显示同一艘船。
	if _active_screen == "shipyard" and not _shipyard_refit:
		_hide_port_stage()
		return
	# The 2D-overview toggle only affects the overview page; market / supply are
	# always presented over the district because that is where their station is.
	var stage_page_enabled := _active_screen != "overview" or _overview_stage_mode
	var should_show := (
		bool(data.get("has_run", false))
		and (not force_station.is_empty() or not bool(data.get("at_sea", false)))
		and not station.is_empty()
		and (not force_station.is_empty() or stage_page_enabled)
		and _port_stage_available()
	)
	if not should_show:
		_hide_port_stage()
		return
	_ensure_port_stage_host()
	if _port_stage_host == null:
		_hide_port_stage()
		return
	# The stage scene is loaded once and kept for the whole session: switching
	# between overview / market / supply only retargets the camera and the hull.
	var just_mounted := not _port_stage_host.has_stage()
	if just_mounted:
		if not _port_stage_host.load_stage(PORT_STAGE_SCENE_PATH):
			_on_port_stage_fallback("stage_scene_load_failed")
			return
	# Shipyard refit keeps the station-centred shot: its panels sit on the left and
	# right, so the shipyard yard must stay in the middle window instead of being
	# shifted aside like the single right-hand dock panel of market / supply.
	var framing := "stage" if _active_screen == "overview" or _active_screen == "shipyard" or not force_station.is_empty() else "panel"
	_port_stage_host.bind_view_model(_port_stage_payload(data))
	_port_stage_host.set_stage_visible(true)
	_had_3d_stage = true
	_focus_stage_station(station, framing, just_mounted)
	if _port_hotspot_layer != null:
		# Edge signs belong to the overview main view; the market / supply dock
		# panels carry their own navigation, and the voyage cut shows a clean shot.
		_port_hotspot_layer.visible = _active_screen == "overview" and force_station.is_empty()
	_refresh_port_hotspots_soon()


## Retargets the mounted stage to one of the adjacent stations. The stage API is
## a no-op when the station/framing already match, so this is safe to call on
## every page rebuild and never restarts the pan.
func _focus_stage_station(station: String, framing: String, immediate: bool) -> void:
	_stage_station = station
	_stage_framing = framing
	if _port_stage_host == null or not is_instance_valid(_port_stage_host):
		return
	var stage: Node = _port_stage_host.current_stage()
	if stage == null or not stage.has_method("focus_station"):
		return
	stage.call("focus_station", station, framing, immediate)


## True when the current page is drawn over the shared 3D district. Used by the
## market / supply pages to pick the dock-panel layout instead of a full page.
func _stage_backed_page() -> bool:
	return not String(STAGE_SCREENS.get(_active_screen, "")).is_empty() and _port_stage_available()


## Market / supply layout over the live stage: the scene keeps the left part of
## the window, the page becomes an opaque dock panel pinned to the right side
## (Bounty Train's station screens). Falls back to a plain full-width page when
## the stage is unavailable, so the pages always stay usable.
func _mount_dock_panel(screen: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "DockPanelRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var window := Control.new()
	window.name = "StageWindow"
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(window)
	var panel := PanelContainer.new()
	panel.name = "DockPanel"
	panel.theme_type_variation = &"SNPanel"
	panel.custom_minimum_size = Vector2(DOCK_PANEL_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(screen)
	row.add_child(panel)
	_root_box.add_child(row)


func _hide_port_stage() -> void:
	if _port_stage_host != null and is_instance_valid(_port_stage_host):
		_port_stage_host.set_stage_visible(false)
	if _port_hotspot_layer != null and is_instance_valid(_port_hotspot_layer):
		_port_hotspot_layer.visible = false
		for child in _port_hotspot_layer.get_children():
			_port_hotspot_layer.remove_child(child)
			child.queue_free()


func _port_stage_active() -> bool:
	return (
		_overview_stage_mode
		and _active_screen == "overview"
		and _port_stage_host != null
		and is_instance_valid(_port_stage_host)
		and _port_stage_host.is_stage_visible()
	)


func _port_stage_payload(data: Dictionary) -> Dictionary:
	var port: Dictionary = data.get("current_port", {})
	var ship: Dictionary = data.get("ship", {})
	var port_payload := {
		"id": String(port.get("id", "")),
		"size": String(port.get("size", "medium")),
		"facilities": Array(port.get("facilities", [])).duplicate(),
		"banner_path": _port_banner_path(data),
	}
	# Optional diorama inputs are forwarded only when present, so the stage keeps
	# its defaults until content exposes them.
	if port.get("facility_visuals", null) is Dictionary:
		port_payload["facility_visuals"] = (port["facility_visuals"] as Dictionary).duplicate(true)
	if port.get("town_visuals", null) is Dictionary:
		port_payload["town_visuals"] = (port["town_visuals"] as Dictionary).duplicate(true)
	if port.get("diorama", null) is Dictionary:
		port_payload["diorama"] = (port["diorama"] as Dictionary).duplicate(true)
		var density := String((port["diorama"] as Dictionary).get("density", ""))
		if not density.is_empty():
			port_payload["density"] = density
	if port.get("palette", null) is Dictionary:
		port_payload["palette"] = (port["palette"] as Dictionary).duplicate(true)
	if not String(port.get("landmark_path", "")).is_empty():
		port_payload["landmark_path"] = String(port.get("landmark_path", ""))
	var ship_payload := {
		"hull_model_path": String(ship.get("hull_model_path", "")),
		"hull_tier": int(ship.get("hull_tier", 1)),
	}
	# Stage 5: forward the resolved visual plan (hull + rig kit + weapon slots)
	# so PortStage can assemble the player ship; absent on old saves / VMs.
	var visual: Variant = ship.get("visual", null)
	if visual is Dictionary:
		ship_payload["visual"] = (visual as Dictionary).duplicate(true)
	return {
		"port": port_payload,
		"ship": ship_payload,
	}


## Resolved physical path of the port banner (content-mod raw PNG) or "".
func _port_banner_path(data: Dictionary) -> String:
	var port: Dictionary = data.get("current_port", {})
	var banner_key := String(port.get("banner_asset", ""))
	var source_mod := String(port.get("source_mod", ""))
	if banner_key.is_empty() or source_mod.is_empty() or _context == null:
		return ""
	var logical_key := "asset://%s/%s" % [source_mod, banner_key]
	if _context.assets.has(logical_key):
		return _context.assets.resolve(logical_key)
	return ""


func _on_port_stage_fallback(reason: String) -> void:
	if _port_stage_load_failed:
		return
	_port_stage_load_failed = true
	_overview_stage_mode = false
	_hide_port_stage()
	push_warning("PortStage unavailable (%s), falling back to the 2D overview" % reason)
	_set_status(_tr("ui.error.port_stage_unavailable", "3D port stage unavailable, showing the 2D overview."), true)
	_refresh.call_deferred()


func _on_viewport_size_changed() -> void:
	if _port_stage_active():
		_refresh_port_hotspots_soon()
	# 4.7 / dev.3 #3：窗口尺寸变化后引导遮罩必须重新按目标控件矩形排版。
	# 遮罩绑定了目标控件会逐帧自愈，这里再补两次 deferred 重同步兜底目标重解析。
	if _story_focus != null and is_instance_valid(_story_focus):
		_sync_story_focus_soon()


## Two deferred passes: the first runs after the container re-layout, the second
## catches the SubViewport resize that the stage uses for camera projection.
func _refresh_port_hotspots_soon() -> void:
	_layout_port_hotspots.call_deferred()
	_delayed_port_hotspot_pass.call_deferred()


func _delayed_port_hotspot_pass() -> void:
	_layout_port_hotspots.call_deferred()


## Fixed edge signboards replacing the old floating labels: facilities are split
## by their projected x (< 0.5 -> left column, otherwise right column), sorted by
## projected y and stacked at the screen edges. The right column reserves its
## bottom slot for the permanent "voyage" sign. Layout keeps clear of the compact
## top chrome and the footer area, and is redone on every resize.
func _layout_port_hotspots() -> void:
	if _port_hotspot_layer == null or not is_instance_valid(_port_hotspot_layer):
		return
	for child in _port_hotspot_layer.get_children():
		_port_hotspot_layer.remove_child(child)
		child.queue_free()
	if not _port_stage_active():
		return
	var stage := _port_stage_host.current_stage()
	if stage == null or not stage.has_method("facility_screen_anchor"):
		return
	var anchors: Dictionary = stage.facility_anchors() if stage.has_method("facility_anchors") else {}
	var layer_size := _port_hotspot_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		layer_size = get_viewport_rect().size
	var top_safe := _port_hud_top_safe()
	var bottom_safe := _port_hud_bottom_safe(layer_size)
	var left: Array = []
	var right: Array = []
	for raw_facility in anchors.keys():
		var facility := String(raw_facility)
		if not PORT_STAGE_FACILITY_SCREENS.has(facility):
			continue
		var facility_screen := String(PORT_STAGE_FACILITY_SCREENS[facility])
		if not _story_feature_unlocked(_story_screen_feature(facility_screen)):
			continue
		var normalized: Vector2 = stage.facility_screen_anchor(facility)
		if normalized == Vector2.ZERO:
			continue
		var entry := {"facility": facility, "y": normalized.y}
		if normalized.x < 0.5:
			left.append(entry)
		else:
			right.append(entry)
	left.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	right.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	_layout_sign_column(left, false, top_safe, bottom_safe, layer_size)
	_layout_sign_column(right, true, top_safe, bottom_safe, layer_size)
	# Permanent chart sign pinned to the bottom of the right column (4.3.4 / U7:
	# replaces the old voyage sign; departure is confirmed inside the chart).
	# 4.5: hidden until the story unlocks the chart.
	if _story_feature_unlocked(StoryService.FEATURE_CHART):
		var chart_sign := _port_sign(
			"%s ▶" % _tr("ui.nav.sea_chart", "海图"),
			_on_port_hotspot.bind("sea_chart"),
			true,
			"sea_chart",
			-1
		)
		chart_sign.name = "Hotspot_sea_chart"
		chart_sign.position = Vector2(
			layer_size.x - PORT_SIGN_MARGIN - PORT_SIGN_WIDTH,
			bottom_safe - PORT_SIGN_HEIGHT
		)
		_port_hotspot_layer.add_child(chart_sign)


func _layout_sign_column(entries: Array, right_column: bool, top_safe: float, bottom_safe: float, layer_size: Vector2) -> void:
	var count := entries.size()
	if count == 0:
		return
	var area_top := top_safe + 8.0
	var area_bottom := bottom_safe - 8.0
	if right_column:
		# Keep the pinned voyage sign out of the facility stack.
		area_bottom -= PORT_SIGN_HEIGHT + PORT_SIGN_GAP
	var total := count * PORT_SIGN_HEIGHT + (count - 1) * PORT_SIGN_GAP
	var start := area_top + maxf(0.0, (area_bottom - area_top - total) * 0.5)
	var x := (
		layer_size.x - PORT_SIGN_MARGIN - PORT_SIGN_WIDTH
		if right_column
		else PORT_SIGN_MARGIN
	)
	for index in count:
		var facility := String(entries[index]["facility"])
		var label := (
			"◀ %s" % _facility_sign_name(facility)
			if right_column
			else "%s ▶" % _facility_sign_name(facility)
		)
		var button := _port_sign(label, _on_port_hotspot.bind(facility), false, facility, 1 if right_column else -1)
		button.name = "Hotspot_%s" % facility
		button.position = Vector2(x, start + index * (PORT_SIGN_HEIGHT + PORT_SIGN_GAP))
		_port_hotspot_layer.add_child(button)


## One fixed signboard at the scene edge: themed wood/iron/brass plate with a
## painted facility emblem, a real arrow triangle pointing into the scene and a
## brass hover halo. Falls back to the plain themed button if the component is
## unavailable, so the stage never loses its navigation.
func _port_sign(text: String, callback: Callable, primary: bool, facility: String = "", arrow: int = -1) -> Button:
	var sign_size := Vector2(PORT_SIGN_WIDTH, PORT_SIGN_HEIGHT)
	var button: Button
	if HARBOR_SIGN_SCRIPT != null:
		button = HARBOR_SIGN_SCRIPT.new()
		button.call("configure", text, primary, facility, arrow)
	else:
		button = _button(text, callback)
		button.theme_type_variation = &"SNGhostButton"
	button.custom_minimum_size = sign_size
	button.size = sign_size
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_hover_color", SNSkin.color("brass.highlight"))
	button.tooltip_text = _tr("ui.hint.port_hotspot", "Open this facility")
	if button.get_signal_connection_list("pressed").is_empty():
		button.pressed.connect(callback)
	return button


## Bottom edge of the compact top chrome in window coordinates; fallback keeps
## the first (not yet laid out) pass from drawing signs over the HUD.
func _port_hud_top_safe() -> float:
	if _top_chrome != null and is_instance_valid(_top_chrome):
		var rect := _top_chrome.get_global_rect()
		if rect.size.y > 0.0:
			return rect.end.y + 8.0
	return TOP_CHROME_MAX_HEIGHT + 8.0


## Top edge of the fixed footer area in window coords (the old bottom status strip
## was removed in the 2026-10-28 UI round).
func _port_hud_bottom_safe(layer_size: Vector2) -> float:
	return layer_size.y - 48.0


func _on_port_hotspot(facility: String) -> void:
	if _story_card_open:
		return
	if facility == "sea_chart":
		# 4.3.4 / U7：牌匾入口改为打开海图，出航在海图确认弹窗里完成。
		if _story_feature_unlocked(StoryService.FEATURE_CHART):
			_toggle_sea_chart()
		return
	var screen_id: StringName = PORT_STAGE_FACILITY_SCREENS.get(facility, &"")
	if screen_id == &"":
		return
	if not _story_feature_unlocked(_story_screen_feature(String(screen_id))):
		return
	_on_nav(String(screen_id))


## Renders one notice: its localized template filled with the parameters recorded
## by `GameState.push_notice`. Parameters are positional in the order the notice
## was pushed, which is the order every `ui.notice.*` template is written for;
## string parameters are themselves localization keys (port / module / build
## names) and get translated first. A template whose slots do not line up with its
## parameters (count or type) is shown as-is instead of raising a format error on
## every overview refresh.
func _notice_text(notice: Dictionary) -> String:
	var key := String(notice.get("text_key", ""))
	var template := _tr(key, "")
	if template.is_empty():
		return key
	var params: Variant = notice.get("params", null)
	if not (params is Dictionary) or (params as Dictionary).is_empty():
		return template
	var slots := _format_slots(template)
	if slots.is_empty():
		return template
	var args: Array = []
	for value in (params as Dictionary).values():
		if value is String:
			var text := String(value)
			args.append(_tr(text, text))
		else:
			args.append(value)
	if args.size() != slots.size():
		return template
	for index in slots.size():
		if slots[index] == "%d" and not (args[index] is int or args[index] is float):
			return template
	return template % args


## The `%s` / `%d` slots of a format string, in order.
func _format_slots(template: String) -> PackedStringArray:
	var regex := RegEx.new()
	regex.compile("%[sd]")
	var slots := PackedStringArray()
	for match_result in regex.search_all(template):
		slots.append(match_result.get_string(0))
	return slots


## ---------------------------------------------------------------------------
## Market
## ---------------------------------------------------------------------------

## Market page: left ship hold + transparent stage window + market dock panel.
## The page itself is a scene (`MarketScreen`), the backpack is a script-built
## component; the shell owns the ViewModel, icon resolution and command wiring.
func _screen_market(data: Dictionary) -> void:
	var market_model := _market_model(data)
	_attach_market_supply(market_model)
	_resolve_market_icons(market_model)
	var screen: Variant = MARKET_SCREEN_SCENE.instantiate()
	screen.bind(market_model, Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	var hold: Variant = CARGO_HOLD_PANEL_SCRIPT.new()
	hold.name = "CargoHoldPanel"
	hold.bind(market_model, Callable(self, "_tr"))
	hold.command_requested.connect(_run_command)
	# 拿起手势（feedback #1）：市场格子的 pending 聚合成 offer，一边驱动光标幽灵，
	# 一边转发给船舱 / 仓库落点——玩家点落点即执行 trade.buy。
	screen.carry_changed.connect(func(offer: Dictionary) -> void:
		hold.set_offer(offer)
		if offer.is_empty():
			_hide_carry_ghost()
		else:
			_show_carry_ghost(offer)
	)
	if _stage_backed_page():
		_mount_market_dock(hold, screen)
	else:
		_mount_market_columns(hold, screen)


## `market.view` is the contract source; when the query is not available (older
## build / partially merged branch) fall back to the `port.view` data the shell
## already refreshed, keeping the same field names so the page still renders.
func _market_model(data: Dictionary) -> Dictionary:
	var result := _context.queries.execute(&"market.view")
	if bool(result.get("ok", false)) and result.get("data", null) is Dictionary:
		return (result["data"] as Dictionary).duplicate(true)
	var model: Dictionary = data.duplicate(true)
	model["trends"] = _market_trends()
	if not (model.get("warehouse", null) is Dictionary):
		model["warehouse"] = {
			"port_id": String(model.get("current_port_id", "")),
			"materials": [],
		}
	var ship: Dictionary = model.get("ship", {})
	if not (ship.get("hold", null) is Array):
		ship["hold"] = _market_hold_fallback(ship)
		model["ship"] = ship
	model["at_port"] = not bool(model.get("at_sea", false))
	return model


## Fallback hold rows from `port.view`'s `ship.cargo` stacks (no query available).
## Aggregates per item / contract flag exactly like `market.view` does.
func _market_hold_fallback(ship: Dictionary) -> Array:
	var aggregated := {}
	for stack in ship.get("cargo", []):
		if not (stack is Dictionary):
			continue
		var item_id := String((stack as Dictionary).get("item_id", ""))
		var amount := int((stack as Dictionary).get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			continue
		var contract_id := String((stack as Dictionary).get("contract_id", ""))
		var is_contract := not contract_id.is_empty()
		var key := "%s|%s" % [item_id, "contract" if is_contract else "free"]
		if not aggregated.has(key):
			aggregated[key] = {
				"item_id": item_id,
				"name_key": String((stack as Dictionary).get("name_key", item_id)),
				"amount": 0,
				"total_cost": 0.0,
				"is_contract": is_contract,
				"contract_id": contract_id,
				"avg_cost": float((stack as Dictionary).get("average_cost", 0.0)),
			}
		aggregated[key]["amount"] = int(aggregated[key]["amount"]) + amount
	var keys: Array = aggregated.keys()
	keys.sort()
	var rows: Array = []
	for key in keys:
		var entry: Dictionary = aggregated[key]
		var amount := int(entry["amount"])
		var is_contract := bool(entry["is_contract"])
		rows.append({
			"item_id": String(entry["item_id"]),
			"name_key": String(entry["name_key"]),
			"category": "",
			"crafting_material": false,
			"unit_weight": 0.0,
			"amount": amount,
			"sellable_amount": 0 if is_contract else amount,
			"is_contract": is_contract,
			"contract_id": String(entry["contract_id"]),
			"avg_cost": 0.0 if is_contract else float(entry["avg_cost"]),
			"icon_key": "",
		})
	return rows


## 4.5.3：补给并市 —— 市场 VM 附带 supply.view 的煤 / 水区块（购买仍走
## `supply.buy_*`，不复制价格 / 库存逻辑）。
func _attach_market_supply(market_model: Dictionary) -> void:
	var supply_result := _context.queries.execute(&"supply.view")
	if not bool(supply_result.get("ok", false)):
		return
	var supply_model: Dictionary = supply_result["data"].duplicate(true)
	if _story_action_locked(&"supply.buy_coal"):
		for kind in ["coal", "water"]:
			var kind_view: Dictionary = supply_model.get("%s_view" % kind, {})
			var blockers: Array = Array(kind_view.get("blockers", [])).duplicate()
			if not blockers.has("story_locked"):
				blockers.append("story_locked")
			kind_view["blockers"] = blockers
	market_model["supply"] = supply_model


## Resolves every `icon_key` of the market ViewModel into a `Texture2D` placed on
## the row's `icon` field. Missing content keys fall back to the framework item
## fallback (and finally the framework placeholder), so the grid never breaks.
func _resolve_market_icons(market_model: Dictionary) -> void:
	var fallback := _fallback_item_icon()
	for row in market_model.get("market", []):
		if row is Dictionary:
			(row as Dictionary)["icon"] = _resolve_item_icon(String((row as Dictionary).get("icon_key", "")), fallback)
	var ship: Dictionary = market_model.get("ship", {})
	for row in ship.get("hold", []):
		if row is Dictionary:
			(row as Dictionary)["icon"] = _resolve_item_icon(String((row as Dictionary).get("icon_key", "")), fallback)
	var warehouse: Dictionary = market_model.get("warehouse", {})
	for row in warehouse.get("materials", []):
		if row is Dictionary:
			(row as Dictionary)["icon"] = _resolve_item_icon(String((row as Dictionary).get("icon_key", "")), fallback)


func _resolve_item_icon(icon_key: String, fallback: Texture2D) -> Texture2D:
	if icon_key.is_empty():
		return fallback
	if _market_icon_cache.has(icon_key):
		return _market_icon_cache[icon_key] as Texture2D
	var texture: Texture2D = null
	if _context != null and _context.assets != null:
		var logical := icon_key
		if not logical.begins_with("res://") and not logical.begins_with("asset://"):
			logical = _context.assets.find_key(icon_key)
		if not logical.is_empty() and _context.assets.has(logical):
			texture = _context.assets.load_texture(logical)
	if texture == null:
		texture = fallback
	_market_icon_cache[icon_key] = texture
	return texture


## Framework-wide fallback item icon; the placeholder texture is the last resort
## so a build without `assets/ui/icons/item_fallback.svg` still renders tiles.
func _fallback_item_icon() -> Texture2D:
	const CACHE_KEY := "__item_fallback__"
	if _market_icon_cache.has(CACHE_KEY):
		return _market_icon_cache[CACHE_KEY] as Texture2D
	var texture: Texture2D = null
	if ResourceLoader.exists(ITEM_FALLBACK_ICON):
		texture = load(ITEM_FALLBACK_ICON) as Texture2D
	elif FileAccess.file_exists(ITEM_FALLBACK_ICON):
		texture = ContentAssetLoader.load_texture(ITEM_FALLBACK_ICON)
	if texture == null and _context != null and _context.assets != null:
		var fallback_path := _context.assets.fallback_path()
		if ResourceLoader.exists(fallback_path):
			texture = load(fallback_path) as Texture2D
	_market_icon_cache[CACHE_KEY] = texture
	return texture


## Market layout over the live stage: backpack (left) + transparent stage window
## (middle) + market dock panel (right). `StageWindow` stays mouse-transparent so
## the 3D district keeps receiving its own interactions.
func _mount_market_dock(hold: Control, screen: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "DockPanelRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", MARKET_COLUMN_GAP)
	hold.custom_minimum_size = Vector2(CARGO_HOLD_PANEL_WIDTH, 0.0)
	hold.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(hold)
	var window := Control.new()
	window.name = "StageWindow"
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(window)
	var panel := PanelContainer.new()
	panel.name = "DockPanel"
	panel.theme_type_variation = &"SNPanel"
	panel.custom_minimum_size = Vector2(DOCK_PANEL_WIDTH, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(screen)
	row.add_child(panel)
	_root_box.add_child(row)


## Stage-unavailable fallback: backpack + market panel, no empty stage window.
func _mount_market_columns(hold: Control, screen: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "DockPanelRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", MARKET_COLUMN_GAP)
	hold.custom_minimum_size = Vector2(CARGO_HOLD_PANEL_WIDTH, 0.0)
	hold.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(hold)
	var panel := PanelContainer.new()
	panel.name = "DockPanel"
	panel.theme_type_variation = &"SNPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(screen)
	row.add_child(panel)
	_root_box.add_child(row)


func _market_trends() -> Dictionary:
	var result: Dictionary = {}
	var intel := _context.queries.execute(&"intel.view")
	if not bool(intel.get("ok", false)) or not bool(intel["data"].get("has_report", false)):
		return result
	var current_port := String(_last_port_view.get("current_port_id", ""))
	for port_report in intel["data"].get("ports", []):
		if String(port_report.get("port_id", "")) != current_port:
			continue
		for row in port_report.get("market", []):
			result[String(row.get("item_id", ""))] = String(row.get("trend", ""))
	return result


## ---------------------------------------------------------------------------
## Port memory (clicked on the map)
## ---------------------------------------------------------------------------

func _screen_port_memory(_data: Dictionary) -> void:
	if _memory_port_id.is_empty():
		_memory_port_id = String(_last_port_view.get("current_port_id", ""))
	var result := _context.queries.execute(&"port.memory", {"port_id": _memory_port_id})
	var model: Dictionary
	if not bool(result.get("ok", false)):
		model = {"error_text": _error_text(result)}
	else:
		model = result["data"].duplicate(true)
		var facilities: Array = []
		for facility in model.get("facilities", []): facilities.append(_facility_name(String(facility)))
		model["facility_labels"] = facilities
		model["age_text"] = _age_text(float(model.get("age_hours", 0.0)))
	var screen: Variant = PORT_MEMORY_SCREEN_SCENE.instantiate()
	screen.bind(model, Callable(self, "_tr"))
	screen.navigation_requested.connect(_on_screen_navigation)
	_root_box.add_child(screen)


## ---------------------------------------------------------------------------
## Contracts
## ---------------------------------------------------------------------------

func _screen_contracts(data: Dictionary) -> void:
	var screen: Variant = CONTRACTS_SCREEN_SCENE.instantiate()
	screen.bind(_contracts_screen_model(data), Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	screen.navigation_requested.connect(_on_screen_navigation)
	_root_box.add_child(screen)


func _contracts_screen_model(data: Dictionary) -> Dictionary:
	var contracts: Dictionary = data.get("contracts", {}).duplicate(true)
	for key in ["main", "main_offer"]:
		if contracts.get(key, null) is Dictionary:
			contracts[key] = _enrich_contract_for_screen(contracts[key])
	for key in ["offers", "active"]:
		var enriched: Array = []
		for contract in contracts.get(key, []):
			if contract is Dictionary:
				enriched.append(_enrich_contract_for_screen(contract))
		contracts[key] = enriched
	var completed_names: Array = []
	for contract_id in contracts.get("completed", []):
		completed_names.append(_definition_name(String(contract_id)))
	return {
		"contracts": contracts,
		"completed_names": completed_names,
		"tasks": Array(_task_vm.get("tasks", [])).duplicate(true),
		"active_task_id": String(_task_vm.get("active_task_id", "")),
	}


func _enrich_contract_for_screen(contract: Dictionary) -> Dictionary:
	var enriched := contract.duplicate(true)
	enriched["destination_reachable"] = _is_neighbor(String(contract.get("destination", "")))
	var unlock_names: Array = []
	for unlock_id in contract.get("unlock_ids", []):
		unlock_names.append(_definition_name(String(unlock_id)))
	enriched["unlock_names"] = unlock_names
	return enriched


func _contract_payload_text(contract: Dictionary) -> String:
	var parts := PackedStringArray()
	if float(contract.get("cargo_weight", 0.0)) > 0.0:
		parts.append("货物 %.0f 重量" % float(contract.get("cargo_weight", 0.0)))
	if int(contract.get("passengers", 0)) > 0:
		parts.append("旅客 %d 人" % int(contract.get("passengers", 0)))
	if parts.is_empty():
		return "载荷：—"
	return "载荷：" + " · ".join(parts)


func _contract_reward_text(contract: Dictionary) -> String:
	# 反馈 #3：无期限委托的 on_time_bonus 是「完成奖励」，文案从「准时 +N」改为
	# 「完成 +N」（port.view 已给出 has_deadline；缺省时回退到 instance 判定）。
	var timed := bool(contract.get("has_deadline", not ContractOps.is_untimed(contract)))
	var parts := PackedStringArray()
	parts.append("基础 %d" % int(contract.get("base_money", 0)))
	parts.append((
		_tr("ui.reward.on_time", "准时 +%d")
		if timed
		else _tr("ui.reward.completion", "完成 +%d")
	) % int(contract.get("on_time_bonus", 0)))
	parts.append("声誉 +%d" % int(contract.get("reputation", 0)))
	return "报酬：" + " · ".join(parts)


## ---------------------------------------------------------------------------
## Shipyard
## ---------------------------------------------------------------------------

func _screen_base(data: Dictionary) -> void:
	var result := _context.queries.execute(&"base.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, SNSkin.color("state.danger")))
		_root_box.add_child(error_panel)
		return
	var screen: Variant = BASE_SCREEN_SCENE.instantiate()
	screen.bind(_base_model(result["data"], data), Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


func _base_model(view: Dictionary, data: Dictionary) -> Dictionary:
	var model := view.duplicate(true)
	var sites: Array = []
	for definition in _context.registries.get_all(ContentTypes.BASE_SITE):
		sites.append({
			"id": definition.id,
			"name_key": definition.name_key,
			"claim_cost": int(round(float(definition.data.get("claim_cost_money", 0.0)))),
		})
	model["available_sites"] = sites
	var buildings: Array = []
	for definition in _context.registries.get_all(ContentTypes.BUILDING):
		buildings.append({
			"id": definition.id,
			"name_key": definition.name_key,
			"category": String(definition.data.get("category", "")),
			"cost": int(round(float(definition.data.get("build_cost_money", 0.0)))),
		})
	model["available_buildings"] = buildings
	var upgrades: Array = []
	for definition in _context.registries.get_all(ContentTypes.BUILDING_UPGRADE):
		upgrades.append({
			"id": definition.id,
			"building_ref": String(definition.data.get("building_ref", "")),
			"from_level": int(definition.data.get("from_level", 0)),
			"to_level": int(definition.data.get("to_level", 0)),
		})
	model["available_upgrades"] = upgrades
	var roles: Array = []
	for definition in _context.registries.get_all(ContentTypes.WORKER_ROLE):
		roles.append({
			"id": definition.id,
			"name_key": definition.name_key,
			"hire_cost": int(round(float(definition.data.get("hire_cost_money", 0.0)))),
		})
	model["available_roles"] = roles
	var warehouse := WarehouseOps.warehouse(_context.state, _context.state.current_port_id())
	var materials: Dictionary = warehouse.get("materials", {})
	var item_ids: Array = materials.keys()
	item_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
	var warehouse_items: Array = []
	for raw_item_id in item_ids:
		var amount := int(materials[raw_item_id])
		if amount <= 0:
			continue
		warehouse_items.append({
			"item_id": String(raw_item_id),
			"name_key": _definition_name(String(raw_item_id)),
			"amount": amount,
		})
	model["warehouse_items"] = warehouse_items
	model["current_port"] = data.get("current_port", {})
	return model


func _screen_trade(data: Dictionary) -> void:
	var result := _context.queries.execute(&"auto_trade.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, SNSkin.color("state.danger")))
		_root_box.add_child(error_panel)
		return
	var screen: Variant = AUTO_TRADE_SCREEN_SCENE.instantiate()
	screen.bind(_auto_trade_model(result["data"], data), Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


func _auto_trade_model(view: Dictionary, data: Dictionary) -> Dictionary:
	var model := view.duplicate(true)
	var policies: Array = []
	for definition in _context.registries.get_all(ContentTypes.TRADE_POLICY):
		policies.append({
			"id": definition.id,
			"name_key": definition.name_key,
		})
	model["available_policies"] = policies
	model["current_port"] = data.get("current_port", {})
	return model


func _screen_ruins(data: Dictionary) -> void:
	var result := _context.queries.execute(&"expedition.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, SNSkin.color("state.danger")))
		_root_box.add_child(error_panel)
		return
	var screen: Variant = RUINS_SCREEN_SCENE.instantiate()
	screen.bind(_ruins_model(result["data"], data), Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


func _ruins_model(view: Dictionary, data: Dictionary) -> Dictionary:
	var model := view.duplicate(true)
	var ruins: Array = []
	for definition in _context.registries.get_all(ContentTypes.RUIN_ARCHETYPE):
		ruins.append({"id": definition.id, "name_key": definition.name_key})
	model["available_ruins"] = ruins
	var relic_names: Array = []
	for relic_id in view.get("relics", []):
		var relic := _context.registries.get_by_id(ContentTypes.RELIC, String(relic_id))
		relic_names.append(_tr(relic.name_key, String(relic_id)) if relic != null else String(relic_id))
	model["relic_names"] = relic_names
	model["current_port"] = data.get("current_port", {})
	return model


func _screen_shipyard(data: Dictionary) -> void:
	# The normal shipyard page mounts its own 3D hull stage (`SNShipStage3D`), so the
	# session counts as "3D rendered" for the GL teardown workaround even when the
	# port stage never mounts (2D overview fallback).
	_had_3d_stage = true
	var result := _context.queries.execute(&"shipyard.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, SNSkin.color("state.danger")))
		_root_box.add_child(error_panel)
		return
	var screen: Variant = SHIPYARD_SCREEN_SCENE.instantiate()
	# 改装态切换要立刻把 3D 港区舞台显示/隐藏：页面本身只重建自己的内容，
	# 舞台同步必须由 Shell 完成（不能整页刷新，否则会在按钮信号里重建页面）。
	screen.refit_mode_changed.connect(func(active: bool):
		_shipyard_refit = active
		_sync_port_stage(_last_port_view)
	)
	screen.refit_category_changed.connect(func(category: String): _shipyard_category = category)
	screen.bind(_shipyard_model(result["data"], data), Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


func _shipyard_model(yard: Dictionary, port_data: Dictionary) -> Dictionary:
	var model := yard.duplicate(true)
	model["refit"] = _shipyard_refit
	model["category"] = _shipyard_category
	var ship_model: Dictionary = model.get("ship", {}).duplicate(true)
	ship_model["hull_name"] = _definition_name(String(ship_model.get("hull_id", "")))
	model["ship"] = ship_model
	model["contracts"] = port_data.get("contracts", {}).duplicate(true)
	model["victory"] = port_data.get("victory", {}).duplicate(true)
	var warehouse: Dictionary = model.get("warehouse", {}).duplicate(true)
	var materials: Array = warehouse.get("materials", []).duplicate(true)
	for index in materials.size():
		if materials[index] is Dictionary:
			var material: Dictionary = materials[index].duplicate(true)
			material["ship_amount"] = _cargo_amount_on_ship(String(material.get("item_id", "")))
			materials[index] = material
	warehouse["materials"] = materials
	model["warehouse"] = warehouse
	var candidates: Array = model.get("candidates", []).duplicate(true)
	for index in candidates.size():
		if not (candidates[index] is Dictionary):
			continue
		var candidate: Dictionary = candidates[index].duplicate(true)
		var unlock_id := String(candidate.get("unlock_template_id", ""))
		candidate["unlock_name"] = _definition_name(unlock_id) if not unlock_id.is_empty() else ""
		var replacement: Variant = candidate.get("will_replace", "")
		candidate["replacement_name"] = _module_name(String(replacement)) if replacement is String or replacement is StringName else ""
		candidates[index] = candidate
	model["candidates"] = candidates
	return model




## ---------------------------------------------------------------------------
## Supply dock
## ---------------------------------------------------------------------------

func _screen_supply(_data: Dictionary) -> void:
	var result := _context.queries.execute(&"supply.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, SNSkin.color("state.danger")))
		_root_box.add_child(error_panel)
		return
	var screen: Variant = SUPPLY_SCREEN_SCENE.instantiate()
	var view_model: Dictionary = result["data"]
	# 4.5.2：补给限购时把原因挂到两张补给卡的 blockers 上（命令层同时拦截购买）。
	if _story_action_locked(&"supply.buy_coal"):
		for kind in ["coal", "water"]:
			var supply_view: Dictionary = view_model.get("%s_view" % kind, {})
			var blockers: Array = Array(supply_view.get("blockers", [])).duplicate()
			if not blockers.has("story_locked"):
				blockers.append("story_locked")
			supply_view["blockers"] = blockers
	screen.bind(view_model, Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	if _stage_backed_page():
		_mount_dock_panel(screen)
	else:
		_root_box.add_child(screen)


## ---------------------------------------------------------------------------
## Tavern (4.5.4: replaces the old intelligence page)
## ---------------------------------------------------------------------------

func _screen_tavern(_data: Dictionary) -> void:
	var result := _context.queries.execute(&"tavern.view")
	if not bool(result.get("ok", false)):
		var error_panel := _panel()
		_panel_add(error_panel, _label(_error_text(result), 14, SNSkin.color("state.danger")))
		_root_box.add_child(error_panel)
		return
	var screen: Variant = INTEL_SCREEN_SCENE.instantiate()
	screen.bind(result["data"], Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


## ---------------------------------------------------------------------------
## Nautical chart departures (4.3.4 / U7: the separate voyage page is gone)
## ---------------------------------------------------------------------------

## Full-window nautical chart. The query runs with the remembered boiler strategy
## so the panel estimates match the confirmation dialog; when a departure is
## pending, the Shell adds the `departure` block the screen renders as a centered
## confirmation overlay.
func _screen_sea_chart(data: Dictionary) -> void:
	var strategy := _chart_departure_strategy()
	var params := {} if strategy.is_empty() else {"strategy_id": strategy}
	var result := _context.queries.execute(&"sea_chart.view", params)
	var view_model: Dictionary = result.get("data", {}) if bool(result.get("ok", false)) else {}
	if not _pending_chart_port.is_empty() and not view_model.is_empty():
		view_model["preselect_port_id"] = _pending_chart_port
		_pending_chart_port = ""
	# 4.4.4：从线索列表回到海图时预选线索（即使货物线索在海图上没有几何）。
	if not _pending_chart_clue.is_empty() and not view_model.is_empty():
		view_model["preselect_clue_id"] = _pending_chart_clue
		_pending_chart_clue = ""
	if not _chart_departure.is_empty() and not view_model.is_empty():
		view_model["departure"] = _chart_departure_model(data, view_model)
	var screen: Variant = SEA_CHART_SCREEN_SCENE.instantiate()
	screen.bind(view_model, Callable(self, "_tr"))
	screen.close_requested.connect(_on_sea_chart_closed)
	screen.clue_list_requested.connect(_on_clue_list_requested)
	screen.departure_requested.connect(_on_chart_departure_requested)
	screen.departure_confirmed.connect(_on_chart_departure_confirmed)
	screen.departure_cancelled.connect(_on_chart_departure_cancelled)
	screen.departure_strategy_changed.connect(_on_chart_departure_strategy_changed)
	screen.purchase_clue_requested.connect(_on_purchase_clue_requested)
	screen.investigate_requested.connect(_on_investigate_requested)
	_root_box.add_child(screen)
	# dev.3 #1：`ui:chart_opened` 是**玩家动作**，不再挂在这里——页面每次重建都会
	# 重建海图（改策略 / 开确认弹窗 / 买线索），在这个函数里 observe 会把一次
	# 「打开海图」重复上报。真实打开点在 `_on_nav("sea_chart")`。


## 确认弹窗当前策略：弹窗自己的选择 → Shell 记忆的上一次选择 → 按 `strategy.standard`
## tag 解析（框架不写死 `core:*` ID）；都没有时退回内容里的第一个策略。
func _chart_departure_strategy() -> String:
	var pending := String(_chart_departure.get("strategy_id", ""))
	if not pending.is_empty():
		return pending
	# 4.5.2：剧情阶段可以指定默认锅炉策略（如首航限时 → fast），按 tag 解析，
	# 框架不写死 `core:*` ID。
	var preferred := _story_preferred_strategy_id()
	if not preferred.is_empty():
		return preferred
	if not _selected_strategy.is_empty():
		return _selected_strategy
	var fallback := _standard_strategy_id()
	if fallback.is_empty():
		var strategies: Array = _last_port_view.get("strategies", [])
		if not strategies.is_empty():
			fallback = String((strategies[0] as Dictionary).get("id", ""))
	return fallback


## Maps `story.view.preferred_strategy` (e.g. "fast") to a strategy id via the
## `strategy.<name>` tag; empty when the content has no such strategy.
func _story_preferred_strategy_id() -> String:
	var preferred := String(_story_vm.get("preferred_strategy", ""))
	if preferred.is_empty():
		return ""
	var wanted_tag := "strategy.%s" % preferred
	for strategy in _last_port_view.get("strategies", []):
		if not (strategy is Dictionary):
			continue
		if Array((strategy as Dictionary).get("tags", [])).has(wanted_tag):
			return String((strategy as Dictionary).get("id", ""))
	return ""


## 面板「启航 / 循此线索出航 / 前往该港」→ 打开统一确认弹窗（不立即出航）。
func _on_chart_departure_requested(kind: String, target_id: String) -> void:
	if kind != "voyage" and kind != "explore" and kind != "goods":
		return
	_chart_departure = {
		"kind": kind,
		"target_id": target_id,
		"strategy_id": _chart_departure_strategy(),
	}
	_status_message = ""
	_refresh()


## 弹窗切换锅炉策略：记住这次选择，并用新策略重新查询预估（弹窗保持打开）。
func _on_chart_departure_strategy_changed(strategy_id: String) -> void:
	if _chart_departure.is_empty() or strategy_id.is_empty():
		return
	_chart_departure["strategy_id"] = strategy_id
	_selected_strategy = strategy_id
	_refresh()


func _on_chart_departure_cancelled() -> void:
	if _chart_departure.is_empty():
		return
	_chart_departure = {}
	_refresh()


## 弹窗「启航」：直接执行领域命令（`voyage.start` / `explore.start` / `clue.travel`），
## 演出接管后续。
func _on_chart_departure_confirmed(kind: String, target_id: String, strategy_id: String) -> void:
	var chosen := strategy_id if not strategy_id.is_empty() else _chart_departure_strategy()
	_selected_strategy = chosen
	_chart_departure = {}
	if kind == "explore":
		_run_command(&"explore.start", {"clue_id": target_id, "strategy_id": chosen})
	elif kind == "goods":
		# 4.4.2：货物线索走普通航线；目标港由 `ClueService.travel` 在领域层解析。
		_run_command(&"clue.travel", {"clue_id": target_id, "strategy_id": chosen})
	else:
		_run_command(&"voyage.start", {"destination_id": target_id, "strategy_id": chosen})


## Shell 侧组装弹窗数据（页面只渲染）：目标显示名、策略列表（已翻译）、
## `voyage.preview` / 线索预估的可行性、耗时、煤水、风险与 blockers。
## 名称与文案在这里本地化，弹窗不访问注册表 / 查询总线。
func _chart_departure_model(data: Dictionary, chart_vm: Dictionary) -> Dictionary:
	var kind := String(_chart_departure.get("kind", "voyage"))
	var target_id := String(_chart_departure.get("target_id", ""))
	var strategy_id := _chart_departure_strategy()
	var strategies: Array = []
	for strategy in data.get("strategies", []):
		strategies.append({
			"id": String(strategy.get("id", "")),
			"name": _tr(String(strategy.get("name_key", "")), String(strategy.get("id", ""))),
		})
	var preview: Dictionary = {}
	var target_name := ""
	if kind == "explore" or kind == "goods":
		var clue := _chart_clue_entry(chart_vm, target_id)
		if kind == "goods":
			# 4.4.2：货物线索的目标港是已发现港口，名称来自裁剪后的行情视图
			# （查询不输出 target_port_id）。
			var goods: Variant = clue.get("goods", null)
			target_name = ""
			if goods is Dictionary:
				var name_key := String((goods as Dictionary).get("port_name_key", ""))
				target_name = _tr(name_key, name_key) if not name_key.is_empty() else ""
			if target_name.is_empty():
				target_name = _tr("ui.label.unknown_destination", "？")
		else:
			target_name = _chart_clue_target_name(clue)
		var estimated: Variant = clue.get("estimated", null)
		if estimated is Dictionary:
			preview = _chart_preview_from_estimate(estimated as Dictionary)
		else:
			preview = {"feasible": false, "blockers": [{"message_key": "ui.error.unknown_clue"}]}
	else:
		target_name = _port_name(target_id)
		var result := _context.queries.execute(&"voyage.preview", {
			"destination_id": target_id,
			"strategy_id": strategy_id,
		})
		if bool(result.get("ok", false)):
			var info: Dictionary = result.get("data", {})
			preview = {
				"feasible": bool(info.get("feasible", false)),
				"blockers": info.get("blockers", []),
				"distance": float(info.get("distance", 0.0)),
				"duration_hours": float(info.get("duration_hours", 0.0)),
				"coal_required": float(info.get("coal_required", 0.0)),
				"water_required": float(info.get("water_required", 0.0)),
				"risk_score": float(info.get("risk_score", -1.0)),
				"risk_label": String(info.get("risk_label", "")),
				# `voyage.preview` 的 `on_time` 在非委托航线上是 null；不能直接
				# `bool(null)`（GDScript 只对 bool/数字做了 bool 构造）。
				"on_time": info.get("on_time", true) != false,
			}
		else:
			preview = {"feasible": false, "blockers": [{
				"message_key": String(result.get("message_key", "ui.error.voyage_not_feasible")),
			}]}
	return {
		"kind": kind,
		"target_id": target_id,
		"target_name": target_name,
		"current_port_name": _value_name(data.get("current_port", {}), ""),
		"strategy_id": strategy_id,
		"strategies": strategies,
		"preview": preview,
	}


## 把查询层的 `estimated`（探索 / 货物线索共用形状）转成确认弹窗的 `preview`。
## 弹窗只渲染这里给出的字段，不自行计算可行性。
func _chart_preview_from_estimate(estimate: Dictionary) -> Dictionary:
	return {
		"feasible": bool(estimate.get("feasible", false)),
		"blockers": estimate.get("blockers", []),
		"distance": float(estimate.get("distance", 0.0)),
		"duration_hours": float(estimate.get("duration_hours", 0.0)),
		"coal_required": float(estimate.get("coal_required", 0.0)),
		"water_required": float(estimate.get("water_required", 0.0)),
		"risk_score": float(estimate.get("risk_score", 0.0)),
		"risk_label": String(estimate.get("risk_label", "")),
		"on_time": estimate.get("on_time", true) != false,
		"discovery_chance": float(estimate.get("discovery_chance", 0.0)),
	}


## 线索视图条目（按 id）；没有时返回 `{}`（弹窗会显示不可行）。
func _chart_clue_entry(chart_vm: Dictionary, clue_id: String) -> Dictionary:
	for entry in chart_vm.get("clues", []):
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == clue_id:
			return entry
	return {}


## 线索目标显示名：level 4 展示港口名，否则展示 `？`（弹窗不泄露未披露的名称）。
func _chart_clue_target_name(clue: Dictionary) -> String:
	var name_key := String(clue.get("name_key", ""))
	if not name_key.is_empty():
		return _tr(name_key, name_key)
	return _tr("ui.label.unknown_destination", "？")


## 海图面板「购买线索」：`clue.buy` 成功后 `_run_command` 会重建当前页（仍是海图页），
## 查询重新执行即带出新的 `clues` 列表。
func _on_purchase_clue_requested() -> void:
	_run_command(&"clue.buy", {})


## 海图面板「调查线索」（4.3.2）：`clue.investigate` 把该线索推进一级；成功后的
## 状态栏提示与重建由 `_run_command` / `_handle_success` 负责。
func _on_investigate_requested(clue_id: String) -> void:
	_run_command(&"clue.investigate", {"clue_id": clue_id})


func _toggle_sea_chart() -> void:
	if _story_card_open:
		return
	if _active_screen != "sea_chart" and _active_screen != "clue_log" \
			and not _story_feature_unlocked(StoryService.FEATURE_CHART):
		return
	if _active_screen == "sea_chart":
		_on_sea_chart_closed()
	elif _active_screen == "clue_log":
		# 4.4.4：M 在列表页等于「返回海图」，不改变海图的来源页。
		_on_clue_log_closed()
	else:
		# 新开海图不带上一次的待确认弹窗。
		_chart_departure = {}
		_on_nav("sea_chart")


## 4.4.4 线索列表页：Shell 查询 `clue.list`（只读）并把 ViewModel 塞给独立页面；
## 页面自己不发命令、不查询，只通过信号表达「关闭 / 选中线索」。
func _screen_clue_log(_data: Dictionary) -> void:
	var result := _context.queries.execute(&"clue.list", {})
	var view_model: Dictionary = result.get("data", {}) if bool(result.get("ok", false)) else {}
	var screen: Variant = CLUE_LOG_SCREEN_SCENE.instantiate()
	screen.bind(view_model, Callable(self, "_tr"))
	screen.close_requested.connect(_on_clue_log_closed)
	screen.clue_selected.connect(_on_clue_log_clue_selected)
	_root_box.add_child(screen)


func _on_clue_list_requested() -> void:
	# 4.5.4：线索功能属于 `clues` feature（与酒馆同时解锁）；未解锁时入口不响应。
	if not _story_feature_unlocked(StoryService.FEATURE_CLUES):
		return
	_active_screen = "clue_log"
	_status_message = ""
	_refresh()


func _on_clue_log_closed() -> void:
	# 回到海图（保持原来打开海图的返回页），不经过 `_on_nav` 以免改写来源。
	_active_screen = "sea_chart"
	_refresh()


## 列表页点击线索：回海图并选中该线索（货物线索没有几何也能在面板里打开）。
func _on_clue_log_clue_selected(clue_id: String) -> void:
	if clue_id.is_empty():
		return
	_pending_chart_clue = clue_id
	_active_screen = "sea_chart"
	_status_message = ""
	_refresh()


## M/Esc shortcuts are only meaningful inside an active, in-port run without a
## pending victory summary; every other state keeps the keys untouched.
func _sea_chart_available() -> bool:
	if _context == null or not _context.has_run():
		return false
	if _story_card_open or not _story_feature_unlocked(StoryService.FEATURE_CHART):
		return false
	# No chart, no navigation while the voyage演出 owns the screen.
	if _presentation != null:
		return false
	if bool(_context.state.data.get("at_sea", false)):
		return false
	var victory := _victory_view()
	return not (bool(victory.get("achieved", false)) and not _victory_dismissed)


func _on_sea_chart_closed() -> void:
	_chart_departure = {}
	# 4.5：关闭海图可能是剧情步骤（chart_brief → depart_brief）。
	_observe_story("ui:chart_closed")
	var target := _sea_chart_return
	# 4.3.4 起没有 voyage 页：关闭海图回到打开它的页面，否则回总览。
	if not SCREENS.has(target):
		target = "overview"
	_on_nav(target)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	# 4.5：剧情卡打开时暂停快捷键（卡片自带继续 / 跳过按钮）。
	if _story_card_open:
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode == KEY_M and (_active_screen == "sea_chart" or _sea_chart_available()):
		_toggle_sea_chart()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and _active_screen == "sea_chart":
		# 确认弹窗打开时 Esc 只取消弹窗，不把整张海图关掉。
		if not _chart_departure.is_empty():
			_on_chart_departure_cancelled()
		else:
			_on_sea_chart_closed()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and _active_screen == "clue_log":
		# 4.4.4：列表页 Esc 回到海图。
		_on_clue_log_closed()
		get_viewport().set_input_as_handled()


## ---------------------------------------------------------------------------
## At sea and events
## ---------------------------------------------------------------------------

func _screen_settlement(data: Dictionary) -> void:
	if _settlement_summary.is_empty():
		_screen_overview(data)
		return
	# dev.3 #1：`ui:arrival_settled` 是**抵达事件**，只在演出结束 / 无演出结算时
	# 由 Shell 发一次（`_finish_presentation` / `_full_stop_after_voyage`）。这里
	# 只负责画结算页：页面每次重建（剧情卡继续、窗口 resize、状态刷新）都不能
	# 重复推进剧情，否则「到港剧情」会被提前 / 重复触发。
	var summary := _settlement_summary.duplicate(true)
	var destination := String(summary.get("destination", ""))
	var contracts: Array = summary.get("contracts", []).duplicate(true)
	for index in contracts.size():
		if contracts[index] is Dictionary:
			var contract: Dictionary = contracts[index].duplicate(true)
			var name_key := String(contract.get("name_key", ""))
			contract["display_name"] = _tr(name_key, "") if not name_key.is_empty() else _definition_name(String(contract.get("template_id", "")))
			contracts[index] = contract
	summary["contracts"] = contracts
	var screen: Variant = SETTLEMENT_SCREEN_SCENE.instantiate()
	screen.bind({"summary": summary, "ship": data.get("ship", {}), "money": data.get("money", 0), "destination_name": _port_name(destination) if not destination.is_empty() else "目的港"}, Callable(self, "_tr"))
	screen.navigation_requested.connect(_on_screen_navigation)
	_root_box.add_child(screen)


func _victory_view() -> Dictionary:
	if _context == null or not _context.queries.has(&"victory.view"):
		return {}
	var result := _context.queries.execute(&"victory.view")
	if not bool(result.get("ok", false)):
		return {}
	var view: Variant = result.get("data", {})
	return view if view is Dictionary else {}


func _screen_victory(victory: Dictionary) -> void:
	var screen: Variant = VICTORY_SCREEN_SCENE.instantiate()
	screen.bind(victory, Callable(self, "_tr"))
	screen.action_requested.connect(_on_flow_action)
	_root_box.add_child(screen)


func _on_play_again() -> void:
	if _context == null:
		return
	_context.reset_state()
	_victory_dismissed = false
	_settlement_summary = {}
	_reset_voyage_presentation()
	_status_message = ""
	_menu_screen = "new_game"
	_active_screen = "overview"
	_refresh(true)


func _on_keep_playing() -> void:
	_victory_dismissed = true
	_status_message = ""
	_refresh(true)


func _on_flow_action(action: StringName, _params: Dictionary) -> void:
	match action:
		&"play_again":
			_on_play_again()
		&"keep_playing":
			_on_keep_playing()


## At-sea page. While a voyage presentation is running this is the chart演出 page
## (moving ship + voyage strip); with no presentation (legacy save already at sea)
## it falls back to the same chart page without animation data.
func _screen_at_sea(data: Dictionary, voyage: Variant) -> void:
	var chart_vm: Dictionary = {}
	var result := _context.queries.execute(&"sea_chart.view")
	if bool(result.get("ok", false)):
		chart_vm = result.get("data", {})
	# The query reports the harbour the domain already put the ship in. While the
	#演出 is running the chart should mark the departure harbour instead, so the
	# pulsing "you are here" ring does not sit on the destination before arrival.
	if _presentation != null and not chart_vm.is_empty():
		chart_vm["current_port_id"] = String(_presentation_voyage.get("origin", chart_vm.get("current_port_id", "")))
		chart_vm["at_sea"] = true
	# While presenting, the endpoints come from the presentation session: the
	# domain voyage record is gone the moment an eventless voyage arrives.
	var endpoints: Variant = _presentation_voyage if _presentation != null else voyage
	var endpoint_dict: Dictionary = endpoints if endpoints is Dictionary else {}
	var model := {
		"chart": chart_vm,
		"voyage": endpoint_dict,
		# Domain ids alone render as "port_2" in the voyage strip once the chart VM
		# cannot resolve a fogged destination; resolve both labels against the
		# content registry here so the strip always shows the localized port name.
		"origin_name": _port_name(String(endpoint_dict.get("origin", ""))),
		"destination_name": _port_name(String(endpoint_dict.get("destination", ""))),
		"positions": _presentation_positions(endpoints),
		# 航路点来自坐标世界的完整航线表（`WorldMap.edges`），不是 `sea_chart.view`
		# 的迷雾过滤结果：航线发现与否是玩家视角的规则，演出取用程序内部事实
		# （验收反馈 F4）。
		"route_path": _presentation_route_path(endpoints),
	}
	# 探索演出：航线取自 `explore.start` 的 presentation（终点是搜索区中心，不是
	# 已发现的港口），并把未知终点交给海图画虚线预测线 + `?`。`top_inset` 让 `?`
	# 被顶部 chrome / 状态条挡住时 clamp 到可见区（截图验收发现的遮挡）。
	if not _presentation_explore.is_empty():
		model["route_path"] = _presentation_explore.get("route_path", [])
		var zone: Variant = _presentation_explore.get("zone", null)
		if zone is Dictionary and not (zone as Dictionary).is_empty():
			model["unknown_destination"] = {
				"x": float((zone as Dictionary).get("x", 0.0)),
				"y": float((zone as Dictionary).get("y", 0.0)),
				"label_key": "ui.label.unknown_destination",
				"top_inset": _chart_top_inset(),
			}
		# 正在追的这条线索不画在演出海图上：它的虚线圆和 `?` 终点会重叠，反而看不清
		# 探索目标；其它线索保留（玩家仍能看到别的传闻）。
		_filter_chasing_clue(chart_vm)
	if _presentation != null:
		model["presentation"] = _presentation.snapshot()
	var screen: Variant = AT_SEA_SCREEN_SCENE.instantiate()
	screen.bind(model, Callable(self, "_tr"))
	screen.skip_requested.connect(_on_skip_presentation)
	_at_sea_screen = screen
	# 航行页是全窗海面：挂在滚动容器之外，页面边距也不再裁掉海图（F3）——
	# 只有顶部 chrome 浮在它上面。
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fullscreen_layer.add_child(screen)


## 顶部固定 chrome（顶栏 + 状态提示条）占掉的高度。航行页挂在全窗层、海图从窗口
## 顶边开始画，所以未知终点标记要把它当作不可用区：布局还没排完时用子控件的最小
## 高度估算，第一帧也不会把 `?` 藏在顶栏后面。
func _chart_top_inset() -> float:
	var total := 24.0
	var separation := 8.0
	if _root_box == null:
		return total
	for child in _root_box.get_children():
		if child is Control:
			total += (child as Control).get_combined_minimum_size().y + separation
	return total


## 正在追的线索不画在探索演出的海图上：它的虚线圆和未知终点 `?` 会重叠，反而
## 让玩家看不清自己在往哪走。其它线索保留，演出结束后海图页仍显示完整线索层。
func _filter_chasing_clue(chart_vm: Dictionary) -> void:
	var clue_id := String(_presentation_explore.get("clue_id", ""))
	var clues: Variant = chart_vm.get("clues", null)
	if clue_id.is_empty() or not (clues is Array):
		return
	var kept: Array = []
	for entry in (clues as Array):
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == clue_id:
			continue
		kept.append(entry)
	chart_vm["clues"] = kept


## World positions of the voyage endpoints. The chart only knows discovered
## ports, and the destination of a fresh voyage usually is not discovered yet,
## so the shell reads them from the twin world it already owns.
func _presentation_positions(voyage: Variant) -> Dictionary:
	var positions: Dictionary = {}
	if not (voyage is Dictionary) or _context == null:
		return positions
	var world_map: Variant = _context.state.data.get("world_map", null)
	if not (world_map is Dictionary) or (world_map as Dictionary).is_empty():
		return positions
	var world := WorldMap.from_dict(world_map)
	for key in ["origin", "destination"]:
		var port_id := String((voyage as Dictionary).get(key, ""))
		if port_id.is_empty():
			continue
		var port := world.get_port(port_id)
		if port.is_empty():
			continue
		positions[port_id] = {"x": port.position.x, "y": port.position.y}
	return positions


## 航路点表：从坐标世界的航线表（`WorldMap.edges`，旧世界回退现算）取 origin →
## destination 的完整折线，按「起点在 origin」的方向返回扁平数组 `[x0,y0,…]`。
##
## 它**不经过** `sea_chart.view` 的战争迷雾过滤：迷雾只决定玩家能不能在图上看到
## 这条线，演出（船位、进度、取景）取的是程序内部事实（验收反馈 F4）。
## 世界表里确实没有这条边时返回空数组，航行页再退回两点直线。
func _presentation_route_path(voyage: Variant) -> Array:
	if not (voyage is Dictionary) or _context == null:
		return []
	var world_map: Variant = _context.state.data.get("world_map", null)
	if not (world_map is Dictionary) or (world_map as Dictionary).is_empty():
		return []
	var world := WorldMap.from_dict(world_map)
	var origin_id := String((voyage as Dictionary).get("origin", ""))
	var destination_id := String((voyage as Dictionary).get("destination", ""))
	var from_port := world.get_port(origin_id)
	var to_port := world.get_port(destination_id)
	if from_port.is_empty() or to_port.is_empty():
		return []
	var route := WorldOps.route_between(world, from_port, to_port)
	var raw: Variant = route.get("path", null)
	if raw == null:
		raw = route.get("bezier_path", null)
	var path := _as_path_points(raw)
	if path.size() < 2:
		return []
	# 航线表只存一个方向；按几何位置（而不是 from/to 字段）决定要不要反转，
	# 这样旧世界现算出来的航线也能对齐。
	if path[0].distance_to(from_port.position) > path[path.size() - 1].distance_to(from_port.position):
		var reversed := PackedVector2Array()
		for index in range(path.size() - 1, -1, -1):
			reversed.append(path[index])
		path = reversed
	# 世界表里的路点是按存档精度存的（2 位小数），端点直接对齐港口坐标：演出的
	# 起点必须正好是出发港图标，终点正好是目的港图标（阶段 3 的接缝不变量）。
	path[0] = from_port.position
	path[path.size() - 1] = to_port.position
	# 航路点保持世界表里的原始精度，不做量化。
	var flat: Array = []
	for point in path:
		flat.append(point.x)
		flat.append(point.y)
	return flat


static func _as_path_points(raw: Variant) -> PackedVector2Array:
	if raw is PackedVector2Array:
		return raw
	if raw is Array:
		return VoyagePresentation.unpack_path(raw as Array)
	return PackedVector2Array()


## ---------------------------------------------------------------------------
## Voyage presentation (nautical chart phase 3)
## ---------------------------------------------------------------------------

## True while the chart演出 page should be mounted. `DEPARTURE_VEIL` is excluded
## on purpose: the clouds first cover the 3D harbour shot, then the chart takes over.
func _presentation_on_chart() -> bool:
	if _presentation == null:
		return false
	return _presentation.phase in [
		VoyagePresentation.Phase.AT_SEA,
		VoyagePresentation.Phase.EVENT_APPROACH,
		VoyagePresentation.Phase.EVENT_RESUME,
		VoyagePresentation.Phase.ARRIVAL_APPROACH,
	]


## True while the 3D harbour is the screen: the ship sailing out (departure) and
## the ship entering the destination harbour (arrival).
func _presentation_on_stage() -> bool:
	if _presentation == null:
		return false
	# dev.3 #1：`DEPARTURE_VEIL` 也算「3D 演出页」。它既不在 `_presentation_on_chart()`
	# 里，而 `port.view.at_sea` 在 `voyage.start` 返回时已经是 false（领域先结算抵达），
	# 旧实现会在这个 0.7 s 相位里掉回「上一页」（出航时恒为海图），把海图页重新挂上
	# 并重复上报 `ui:chart_opened`。让离港镜头继续留在 3D 舞台下面，云层照常升起。
	return _presentation.phase in [
		VoyagePresentation.Phase.DEPARTURE_3D,
		VoyagePresentation.Phase.DEPARTURE_VEIL,
		VoyagePresentation.Phase.ARRIVAL_HARBOR,
	]


## True while an exploration is stopped at the 4.2 resource-alert decision.
## `EVENT_WAIT` is the same phase a normal risk event uses; only an exploration
## presentation with a pending alert mounts the alert page instead of the event
## screen / chart page.
func _presentation_on_alert() -> bool:
	if _presentation == null or _presentation_explore.is_empty():
		return false
	return _presentation.phase == VoyagePresentation.Phase.EVENT_WAIT


## 探索演出是否已被「掉头返航」提前结算（`explore.decide(turn_back)` 已经把船送回
## 出发港并写好 summary）。此时 `ARRIVAL_READY` 不能再调 `explore.settle`。
func _explore_returned() -> bool:
	return bool(_presentation_explore.get("returned", false))


## Full-window 3D cut. The stage is forced onto the harbour-authority shot even
## though no `STAGE_SCREENS` page is active, and the beat is kicked off *after*
## the stage has been (re)mounted so the high shot starts from a settled camera.
func _screen_voyage_stage(data: Dictionary) -> void:
	# Departure plays at the harbour the ship is leaving, which `port.view` no
	# longer reports once the command has already settled the arrival; the origin
	# view was captured from the last in-port rebuild. Arrival uses the live view
	# (the ship is now at the destination).
	# dev.3 #1：`DEPARTURE_VEIL` 也继续演出发港（云层盖住离港镜头的阶段不能被
	# 目的港视图顶掉，否则云层下会提前露出抵达地）。
	var departure_phase := _presentation.phase in [
		VoyagePresentation.Phase.DEPARTURE_3D,
		VoyagePresentation.Phase.DEPARTURE_VEIL,
	]
	var stage_data := data
	if departure_phase and not _presentation_origin_view.is_empty():
		stage_data = _presentation_origin_view
	_sync_port_stage(stage_data, PortStage.DEFAULT_STATION)
	if departure_phase:
		_begin_stage_departure()
	else:
		_begin_stage_arrival()


## Starts the演出 for a voyage that `voyage.start` already resolved. `hours` is
## the voyage's own schedule, so the animation lasts as long as the voyage says.
func _start_voyage_presentation(data: Dictionary) -> void:
	# `voyage.start` erases the in-flight `state.data["voyage"]` as soon as the
	# arrival settles, so the presentation reads the endpoints and duration from
	# the command's preview instead of the (possibly already cleared) voyage.
	var preview: Dictionary = data.get("preview", {}) if data.get("preview", null) is Dictionary else {}
	var origin := String(preview.get("origin_id", ""))
	var destination := String(preview.get("destination_id", ""))
	var hours := float(preview.get("duration_hours", 0.0))
	if hours <= 0.0:
		var voyage: Variant = _context.state.data.get("voyage", null)
		if voyage is Dictionary:
			hours = float((voyage as Dictionary).get("arrival_time", 0.0)) \
				- float((voyage as Dictionary).get("departure_time", 0.0))
	if hours <= 0.0:
		hours = VoyagePresentation.FALLBACK_HOURS
	# 4.3.5 / U8：演出中顶栏读数的出发库存与每小时费率。费率与领域 `voyage` 同一口径：
	# 计划消耗 ÷ 计划时长（预览缺失时才退回演出时长）。
	var rate_hours := maxf(0.0, float(preview.get("duration_hours", 0.0)))
	if rate_hours <= 0.0:
		rate_hours = hours
	_presentation_voyage = {
		"origin": origin,
		"destination": destination,
		"departure_time": float(preview.get("departure_time", _context.state.now())),
		"arrival_time": float(preview.get("arrival_time", _context.state.now() + hours)),
		"distance": float(preview.get("distance", 0.0)),
		"strategy_id": String(preview.get("strategy_id", "")),
		"departure_coal": float(preview.get("coal_available", 0.0)),
		"departure_water": float(preview.get("water_available", 0.0)),
		"coal_rate": float(preview.get("coal_required", 0.0)) / rate_hours if rate_hours > 0.0 else 0.0,
		"water_rate": float(preview.get("water_required", 0.0)) / rate_hours if rate_hours > 0.0 else 0.0,
	}
	_presentation_summary = {}
	var summary: Variant = data.get("summary", null)
	if summary is Dictionary:
		_presentation_summary = summary
	var event: Variant = data.get("event", null)
	var event_at := -1.0
	if event is Dictionary:
		event_at = VoyagePresentation.DEFAULT_EVENT_PROGRESS
	_presentation = VoyagePresentation.new()
	_presentation.plan(hours, event_at)
	# Capture the origin harbour view *before* anything rebuilds: the departure cut
	# is filmed at the harbour being left, and `port.view` has already moved on.
	_presentation_origin_view = _last_port_view.duplicate(true)
	_presentation.departure_3d_seconds = PortStage.VOYAGE_BEAT_SECONDS
	_presentation.harbor_seconds = PortStage.VOYAGE_BEAT_SECONDS
	_presentation.begin_departure()
	_sync_cloud_veil(0.0)
	_set_status("出航，航向 %s。" % _port_name(destination), false)


## 探索演出（阶段 4.1/4.2）。`explore.start` 已经在领域层扣完资源并写好
## `explore_voyage`，这里保存它返回的 `presentation`（origin / zone / route_path /
## total_hours / alert_needed / alert_progress）并启动与普通航行相同的状态机：
## 3D 离港 → 云层 → 海图。与普通航行的差别：目的地暂时为空（抵达时才由
## `explore.settle` 决定）、海图航线终点是搜索区中心、以及 4.2 的途中资源告急
## 决策点（`alert_needed` 时事件位由 Core 的 `alert_progress` 决定，命中后停在
## `EVENT_WAIT` 挂告警页）。
func _start_explore_presentation(data: Dictionary) -> void:
	var presentation: Dictionary = {}
	if data.get("presentation", null) is Dictionary:
		presentation = (data["presentation"] as Dictionary).duplicate(true)
	var preview: Dictionary = {}
	if data.get("preview", null) is Dictionary:
		preview = data["preview"] as Dictionary
	var origin := String(presentation.get("origin", ""))
	var hours := float(presentation.get("total_hours", 0.0))
	if hours <= 0.0:
		hours = float(preview.get("duration_hours", 0.0))
	if hours <= 0.0:
		hours = VoyagePresentation.FALLBACK_HOURS
	# 4.2：告警决策点来自 Core JSON（`alert_progress`，默认 0.5）；不需要告急时
	# 传 -1，状态机就按「没有途中事件」跑完整段航程。
	var alert_needed := bool(presentation.get("alert_needed", false))
	var alert_progress := float(presentation.get("alert_progress", VoyagePresentation.DEFAULT_EVENT_PROGRESS))
	_presentation_explore = presentation
	_presentation_explore["alert_needed"] = alert_needed
	_presentation_explore["alert_progress"] = alert_progress
	_presentation_voyage = {
		"kind": "explore",
		"origin": origin,
		# 目的港在 `explore.settle` 之前不存在：追查线索时玩家只知道搜索区。
		"destination": "",
		"clue_id": String(presentation.get("clue_id", "")),
		"departure_time": float(presentation.get("departure_time", _context.state.now())),
		"arrival_time": float(presentation.get("arrival_time", _context.state.now() + hours)),
		"distance": float(preview.get("distance", 0.0)),
		"strategy_id": String(presentation.get("strategy_id", _selected_strategy)),
		# 4.3.5 / U8：探索出航的顶栏连续读数（领域 presentation 已带出发库存与费率）。
		"departure_coal": float(presentation.get("departure_coal", 0.0)),
		"departure_water": float(presentation.get("departure_water", 0.0)),
		"coal_rate": float(presentation.get("coal_rate", 0.0)),
		"water_rate": float(presentation.get("water_rate", 0.0)),
	}
	_presentation_summary = {}
	_presentation = VoyagePresentation.new()
	_presentation.plan(hours, alert_progress if alert_needed else -1.0)
	_presentation_origin_view = _last_port_view.duplicate(true)
	_presentation.departure_3d_seconds = PortStage.VOYAGE_BEAT_SECONDS
	_presentation.harbor_seconds = PortStage.VOYAGE_BEAT_SECONDS
	_presentation.begin_departure()
	_sync_cloud_veil(0.0)
	_set_status("%s…" % _tr("ui.label.exploring", "探索中"), false)


## 抵达海图终点后由 Shell 主动结算探索：目的地（目标港或失败后的漂流港）与
## `summary.explore` 只存在于命令结果里。失败时把错误交给状态栏并返回 false，
## 调用方负责退回出发港的入港镜头。
func _settle_exploration() -> bool:
	var result := _context.commands.execute(&"explore.settle", {})
	if not bool(result.get("ok", false)):
		_set_status(_error_text(result), true)
		return false
	var data: Dictionary = result.get("data", {})
	var destination := String(data.get("destination", ""))
	if not destination.is_empty():
		_presentation_voyage["destination"] = destination
	var summary: Variant = data.get("summary", null)
	if summary is Dictionary:
		_presentation_summary = summary
	return true


func _tick_presentation(delta: float) -> void:
	if _presentation == null:
		return
	var step := _presentation.tick(delta)
	_sync_cloud_veil(delta)
	# The port stage owns the 3D half of the cut; stepping it from the shell keeps
	# it in lockstep with the state machine (and lets headless tests step both).
	_advance_stage_voyage(delta)
	# The chart page stays mounted through the arrival veil (it is covered by the
	# clouds, then swapped for the harbour), so it must keep receiving snapshots:
	# `ARRIVAL_APPROACH` is what pushes the chart framing in before the cut. Feeding
	# only `AT_SEA` used to freeze the framing at 1x for the whole arrival.
	if _at_sea_screen != null and _presentation_on_chart():
		_at_sea_screen.set_presentation(_presentation.snapshot())
	match step:
		VoyagePresentation.Step.DEPARTED:
			if not _presentation_explore.is_empty():
				# 探索出航还没有目的港：只说"探索中"，不能拼出一个空的目的港名。
				_set_status("%s…" % _tr("ui.label.exploring", "探索中"), false)
			else:
				_set_status("离港，航向 %s。" % _port_name(String(_presentation_voyage.get("destination", ""))), false)
		VoyagePresentation.Step.AT_SEA_STARTED:
			_rebuild_ui()
		VoyagePresentation.Step.EVENT_READY:
			# The decision is pushed to the player, then the veil clears over it.
			# Exploration (4.2) mounts the resource-alert page instead of the chart
			# / event page; normal voyages keep the regular event screen.
			_rebuild_ui()
			_presentation.begin_event_reveal()
		VoyagePresentation.Step.ARRIVAL_READY:
			# 探索演出：先把目的地结算出来（目标港 / 失败漂流港），再换成目的港的
			# 3D 入港镜头——普通航行的目的地出发时就已经知道，探索要等这一拍。
			# 掉头返航（4.2）已经在 `explore.decide(turn_back)` 里结算过，这里不能再
			# settle：`explore_voyage` 已被清空，再调只会得到 `not_exploring`。
			if not _presentation_explore.is_empty() \
					and not _explore_returned() \
					and not _settle_exploration():
				# 结算失败（状态被外部改动 / 没有 explore_voyage）：退回出发港，
				# 不把玩家留在"没有目的地的入港镜头"里。错误已由结算函数写进状态栏。
				_presentation_explore = {}
				_presentation_summary = {}
				_presentation_voyage["destination"] = String(
					_presentation_voyage.get("origin", "")
				)
				_rebuild_ui()
				_begin_stage_arrival()
				return
			# Charts are covered: swap in the destination harbour from the high
			# "arriving from sea" shot, then let the camera come down.
			_set_status("抵达 %s。" % _port_name(String(_presentation_voyage.get("destination", ""))), false)
			_rebuild_ui()
			_begin_stage_arrival()
		VoyagePresentation.Step.DONE:
			_finish_presentation()
		_:
			pass
	# 4.3.5 / U8：顶栏煤 / 水读数随已航行小时连续下降。只改 Label 文本，
	# 不写领域状态、不重建页面（`_presentation` 结束时本调用自然变成 no-op）。
	_update_presentation_resources()


## 4.3.5 / U8：演出中的顶栏资源读数 = `出发库存 - 每小时费率 × 已航行小时`，钳位到 0。
## 纯表现：领域状态在整个演出期间不变，实际扣款只在结算时一次性发生；`_rebuild_ui`
## 重建 chrome 后 Label 回到真实 state（事件延误 / 漂流 / 掉头的实际扣款由此生效）。
func _update_presentation_resources() -> void:
	if _presentation == null:
		return
	var elapsed := _presentation.elapsed_hours()
	_update_hud_resource(
		_hud_coal_value,
		float(_presentation_voyage.get("departure_coal", 0.0)),
		float(_presentation_voyage.get("coal_rate", 0.0)),
		elapsed
	)
	_update_hud_resource(
		_hud_water_value,
		float(_presentation_voyage.get("departure_water", 0.0)),
		float(_presentation_voyage.get("water_rate", 0.0)),
		elapsed
	)


func _update_hud_resource(
	label: Label, departure: float, rate: float, elapsed_hours: float
) -> void:
	if label == null or not is_instance_valid(label):
		return
	var remaining := maxf(0.0, departure - maxf(0.0, rate) * maxf(0.0, elapsed_hours))
	label.text = _fmt(remaining)


## Ends the presentation on the settlement screen (or the overview when the
## command produced no summary, e.g. a legacy save).
func _finish_presentation() -> void:
	_settlement_summary = _presentation_summary.duplicate(true)
	_active_screen = "settlement" if not _settlement_summary.is_empty() else "overview"
	_status_message = ""
	_presentation = null
	# 4.2：探索上下文（含 `returned` 掉头标记）随演出一起清掉；下一次探索重新写入。
	_presentation_explore = {}
	_at_sea_screen = null
	_sync_cloud_veil(0.0)
	# dev.3 #1：抵达事件在这里发**一次**——演出收尾 = 真正到港；结算页之后的任何
	# 重建都不再上报 `ui:arrival_settled`。必须先 observe 再重建，让同帧的剧情卡 /
	# 目标条直接是抵达后的阶段。
	_observe_story("ui:arrival_settled")
	_rebuild_ui()


func _on_skip_presentation() -> void:
	if _presentation == null:
		return
	_presentation.skip()


## Steps the port stage's departure/arrival beat, if it is playing one.
func _advance_stage_voyage(delta: float) -> void:
	var stage := _port_stage()
	if stage == null or not stage.is_voyage_transitioning():
		return
	stage.advance_voyage(delta)


func _port_stage() -> PortStage:
	if _port_stage_host == null:
		return null
	return _port_stage_host.current_stage() as PortStage


## Starts the 3D harbour beat for a presentation phase. Called right after the
## stage has been (re)mounted, so the high shot is set up before the first frame.
func _begin_stage_departure() -> void:
	var stage := _port_stage()
	if stage == null:
		# No 3D stage available: skip straight to the veil so the演出 still runs.
		_presentation.finish_departure_beat()
		return
	if stage.voyage_mode() == "depart":
		return
	stage.begin_departure(_presentation.departure_3d_seconds)


func _begin_stage_arrival() -> void:
	var stage := _port_stage()
	if stage == null:
		_presentation.skip_harbor_beat()
		return
	stage.begin_arrival(_presentation.harbor_seconds)


## Drops any in-flight presentation (new run, load, give-up paths). The veil is
## pulled back to clear so a stale overlay never covers the next screen.
func _reset_voyage_presentation() -> void:
	_presentation = null
	_presentation_summary = {}
	# 4.2：探索上下文（含告警决策点与 `returned` 掉头标记）也一起清掉。
	_presentation_explore = {}
	_presentation_voyage = {}
	_presentation_origin_view = {}
	_at_sea_screen = null
	if _cloud_veil != null:
		_cloud_veil.cover = 0.0
	var stage := _port_stage()
	if stage != null:
		stage.reset_voyage()


## Lazily creates the veil as the topmost child so it covers the 3D stage, the
## pages and the fade layer alike.
func _ensure_cloud_veil() -> SNCloudVeil:
	if _cloud_veil != null:
		return _cloud_veil
	_cloud_veil = SNCloudVeil.new()
	_cloud_veil.name = "CloudVeil"
	add_child(_cloud_veil)
	# Keep it anchored to the whole shell even if the window is resized mid-演出.
	_cloud_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _cloud_veil


func _sync_cloud_veil(delta: float) -> void:
	if _presentation == null and _cloud_veil == null:
		return
	var veil := _ensure_cloud_veil()
	if _presentation == null:
		veil.cover = 0.0
		return
	veil.cover = _presentation.veil
	veil.set_meta("veil_direction", _presentation.veil_direction)
	veil.advance(delta)


func _screen_event(data: Dictionary, event: Dictionary) -> void:
	var screen: Variant = EVENT_SCREEN_SCENE.instantiate()
	screen.bind({"event": event, "ship": data.get("ship", {}), "money": data.get("money", 0)}, Callable(self, "_tr"))
	screen.command_requested.connect(_run_command)
	_root_box.add_child(screen)


## 资源告急页（4.2）：复用事件页的版式（标题 / 描述 / 船况 / 两个选项），但选项由
## `_on_explore_alert_choice` 处理——`continue` 只确认告警，`turn_back` 让领域立即
## 结算半程返航，两者都不能走 `event.choose_option`。
##
## `event.hint_text` 覆盖事件页默认的「选择后会立即结算」：对 `continue` 那句话是
## 错的，这里改显示本段剩余航程（全部用已有本地化键拼出，不新增文案）。
func _screen_explore_alert(data: Dictionary) -> void:
	var remaining := 0.0
	if _presentation != null:
		remaining = _presentation.remaining_hours()
	var event := {
		"event_id": "explore_resource_alert",
		"name_key": "ui.explore.alert.title",
		"description_key": "ui.explore.alert.description",
		"hint_text": "%s %s %s" % [
			_tr("ui.explore.alert.remaining", "剩余航程"),
			_fmt(remaining),
			_tr("unit.hours", "小时"),
		],
		"options": [
			{"id": "continue", "name_key": "ui.explore.alert.continue"},
			{"id": "turn_back", "name_key": "ui.explore.alert.turn_back"},
		],
	}
	var ship: Dictionary = data.get("ship", {})
	if ship.is_empty():
		ship = _last_port_view.get("ship", {})
	var screen: Variant = EVENT_SCREEN_SCENE.instantiate()
	screen.bind({
		"event": event,
		"ship": ship,
		"money": data.get("money", 0),
	}, Callable(self, "_tr"))
	screen.command_requested.connect(_on_explore_alert_choice)
	_root_box.add_child(screen)


## 资源告急的选择处理。两个选项都通过 `explore.decide` 在领域层落地；失败时把
## 错误交给状态栏并重新挂告警页（不吞错、也不把玩家留在一张空页上）。
func _on_explore_alert_choice(_command: StringName, params: Dictionary) -> void:
	if _presentation == null or _presentation_explore.is_empty():
		return
	var choice := String(params.get("option_id", ""))
	if choice != "continue" and choice != "turn_back":
		return
	var result := _context.commands.execute(&"explore.decide", {"choice": choice})
	if not bool(result.get("ok", false)):
		_set_status(_error_text(result), true)
		_rebuild_ui()
		return
	if choice == "turn_back":
		var data: Variant = result.get("data", null)
		_handle_explore_turn_back(data if data is Dictionary else {})
		return
	# continue：告警确认，云层重新盖上后回海图继续最后半程（剩余航程仍照常结算）。
	_set_status("%s…" % _tr("ui.label.exploring", "探索中"), false)
	_presentation.resolve_event()
	_rebuild_ui()


## 掉头成功（`explore.decide(turn_back)` 已经在领域层回港并写好 summary）：
## 演出放弃剩余航程，直接进入「云层盖住海图 → 3D 入港」。`returned` 标记让
## `ARRIVAL_READY` 跳过 `explore.settle`——否则会对已经清空的探索航次报
## `not_exploring`，也就是一次 double settle。
func _handle_explore_turn_back(data: Dictionary) -> void:
	var destination := String(data.get("destination", ""))
	if not destination.is_empty():
		_presentation_voyage["destination"] = destination
	var summary: Variant = data.get("summary", null)
	if summary is Dictionary:
		_presentation_summary = summary
	_presentation_explore["returned"] = true
	_set_status(
		_tr("ui.notice.exploration_turned_back", "掉头返航：%s") % _port_name(destination),
		false
	)
	_presentation.force_arrival()
	_sync_cloud_veil(0.0)
	_rebuild_ui()


## ---------------------------------------------------------------------------
## Commands and callbacks
## ---------------------------------------------------------------------------

func _on_menu(screen: String) -> void:
	_menu_screen = screen
	_status_message = ""
	_refresh(true)


func _on_menu_back() -> void:
	_menu_screen = "main"
	_status_message = ""
	_refresh(true)


func _on_menu_action(action: StringName, params: Dictionary) -> void:
	match action:
		&"open":
			_on_menu(String(params.get("screen", "main")))
		&"back":
			_on_menu_back()
		&"continue":
			_on_continue()
		&"diagnostics":
			_show_diagnostics()
		&"check_update":
			_on_check_update()
		&"retry":
			_retry_bootstrap()
		&"quit":
			_on_quit()
		&"set_locale":
			_on_set_locale(String(params.get("locale", "zh_CN")))
		&"toggle_autosave":
			_on_toggle_autosave()
		&"toggle_telemetry":
			_on_toggle_telemetry()
		&"start_run":
			_selected_scenario = String(params.get("starting_scenario", ""))
			_seed_text = String(params.get("seed_text", ""))
			_on_new_run()


func _on_quit() -> void:
	_graceful_quit()


## Orderly shutdown shared by the window close request and the quit button.
##
## Three things happen here:
## 1. Telemetry (docs/design/TELEMETRY.md §3.4): finalize the session into
##    `user://telemetry/pending/` and wait at most 3 s for the serial uploader,
##    then continue regardless of the result.
## 2. Game-resource teardown: stop the presentation, free the page tree and both
##    3D stage hosts, drop the runtime content assets (`ContentAssetLoader` cache)
##    and the framework runtime — all while the renderer is still alive.
## 3. Engine workaround: the exported GL Compatibility build crashes with
##    0xC0000005 inside GLES3 storage teardown once a 3D stage has rendered. The
##    teardown above is not enough to avoid it (verified on Godot 4.7.2), so a
##    session that rendered 3D terminates the process after the cleanup instead
##    of letting the engine destroy the GL context. Menu-only sessions still quit
##    normally. Remove the workaround when the engine is updated.
## `exit_code` is only used by the packaged startup smoke (`--release-smoke`); the
## player paths keep the default 0.
func _graceful_quit(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	print("[quit] graceful teardown: freeing 3D stages and page tree")
	# TELEMETRY.md §3.4：先把本局日志写进 pending，再最多等 3 秒尝试上传；无论结果
	# 如何都继续原有 teardown / 退出流程（含 3D 退出崩溃兜底），绝不卡住退出。
	await _finalize_telemetry()
	_prepare_quit()
	# The frees above are deferred (queue_free); let the tree process them so the
	# stage viewports / meshes / textures reach the renderer before it is destroyed.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	ContentAssetLoader.clear_cache()
	FrameworkRuntime.shutdown()
	# Flush the pending GL commands (buffer/texture deletions) before the engine
	# stops the rendering server; the exported GLES3 build crashed on exit when a
	# 3D stage had been rendered, and an unsynchronised teardown was the suspect.
	if RenderingServer.has_method("force_sync"):
		RenderingServer.force_sync()
	print("[quit] runtime caches released: quitting")
	for _i in 3:
		await get_tree().process_frame
	if _had_3d_stage and not OS.has_feature("editor"):
		# Engine workaround: with GL Compatibility the exported build crashes with
		# 0xC0000005 inside GLES3 storage teardown once a 3D stage has rendered
		# (reproduced on Godot 4.7.2, both dev.3 and HEAD builds; app-level cleanup
		# does not help). Terminating after our own teardown gives the player a
		# normal close instead of a Windows crash dialog. Revisit when the engine
		# is updated (see docs/design/RUNTIME_PERF_REPORT.md §5).
		print("[quit] terminating process to skip the GLES3 teardown crash")
		OS.kill(OS.get_process_id())
		return
	get_tree().quit(exit_code)


## Idempotent node-level half of `_graceful_quit()` (tests call it directly because
## the full shutdown ends the process): stop the presentation, free the page tree
## and unmount + free the 3D stages so their GPU resources are released while the
## renderer is still alive. Deliberately network-free: telemetry finalize/upload is
## owned by `_finalize_telemetry()` so tests can tear down without real requests.
func _prepare_quit() -> void:
	_hide_update_dialog()
	_presentation = null
	_presentation_explore = {}
	_presentation_voyage = {}
	_presentation_origin_view = {}
	_at_sea_screen = null
	if _port_stage_host != null and is_instance_valid(_port_stage_host):
		_port_stage_host.unmount_stage()
		_port_stage_host.set_stage_visible(false)
		# The host owns a `SubViewport` (own World3D + MSAA framebuffer); free it
		# explicitly so its render target is released while the renderer still exists.
		remove_child(_port_stage_host)
		_port_stage_host.queue_free()
		_port_stage_host = null
	if _cloud_veil != null and is_instance_valid(_cloud_veil):
		_cloud_veil.queue_free()
		_cloud_veil = null
	if _port_hotspot_layer != null and is_instance_valid(_port_hotspot_layer):
		_port_hotspot_layer.queue_free()
		_port_hotspot_layer = null
	_free_page_tree()



## Frees the rebuilt page layer and the full-window layer (the at-sea chart). The
## shipyard / overview pages own their own `SNStageHost` sub-viewports, so dropping
## the page tree also releases those 3D stages and their viewport render targets.
func _free_page_tree() -> void:
	for layer in [_root_box, _fullscreen_layer]:
		if layer == null or not is_instance_valid(layer):
			continue
		for child in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	_top_chrome = null
	_at_sea_screen = null
	_hud_coal_value = null
	_hud_water_value = null


func _on_set_locale(locale: String) -> void:
	if _context != null:
		_context.localization.set_locale(locale)
	if _settings != null:
		_settings.set_locale(locale)
	_save_settings()
	_refresh(true)


func _on_toggle_autosave() -> void:
	if _context != null:
		_context.autosave_enabled = not _context.autosave_enabled
	if _settings != null:
		_settings.set_autosave(_context.autosave_enabled if _context != null else true)
	_save_settings()
	_refresh(true)


func _save_settings() -> void:
	if _settings == null:
		return
	var saved := _settings.save()
	if bool(saved.get("ok", false)):
		_set_status(_tr("ui.menu.settings_saved", "设置已保存。"), false)
	else:
		_set_status(_error_text(saved), true)


## ---------------------------------------------------------------------------
## 游玩数据上传（docs/design/TELEMETRY.md §2 / §3 / §5）
## ---------------------------------------------------------------------------


## 首次/重新绑定 AppContext 时创建记录器与串行上传器。关闭状态也创建空记录器：
## 设置页开关可在不重启的情况下即时生效（关闭时服务自身清空缓冲并删除 pending）。
func _init_telemetry() -> void:
	if _context == null:
		return
	if _telemetry_context == _context and _telemetry != null:
		return
	_release_telemetry()
	_telemetry_context = _context
	_telemetry = TelemetryService.new()
	_telemetry.set_enabled(_settings != null and _settings.telemetry())
	_context.telemetry = _telemetry
	_telemetry_uploader = TelemetryUploader.new()
	_telemetry_uploader.name = "TelemetryUploader"
	_telemetry_uploader.bind(_telemetry)
	add_child(_telemetry_uploader)
	if not _context.events.event_published.is_connected(_on_domain_event_published):
		_context.events.event_published.connect(_on_domain_event_published)
	if _telemetry.is_enabled():
		_telemetry.begin_session(_telemetry_meta())
		_start_background_upload()


## retry bootstrap 换 context 时解绑旧记录器：旧队列留给下次启动，不在这里 finalize。
func _release_telemetry() -> void:
	var previous := _telemetry_context
	if previous != null and previous.events != null \
			and previous.events.event_published.is_connected(_on_domain_event_published):
		previous.events.event_published.disconnect(_on_domain_event_published)
	if previous != null and previous.telemetry == _telemetry:
		previous.telemetry = null
	_telemetry = null
	if _telemetry_uploader != null and is_instance_valid(_telemetry_uploader):
		_telemetry_uploader.queue_free()
	_telemetry_uploader = null
	_telemetry_context = null


## 设置页「允许上传数据」开关（§2）：先写设置，再切换记录器，最后持久化。
func _on_toggle_telemetry() -> void:
	if _settings == null:
		return
	var enabled := not _settings.telemetry()
	_settings.set_telemetry(enabled)
	if _telemetry == null:
		_init_telemetry()
	if _telemetry != null:
		_telemetry.set_enabled(enabled)
		if enabled and not _telemetry.is_recording():
			_telemetry.begin_session(_telemetry_meta())
			_start_background_upload()
	_save_settings()
	_refresh(true)


func _telemetry_endpoint() -> String:
	return _settings.telemetry_endpoint() if _settings != null else TelemetryService.DEFAULT_ENDPOINT


func _telemetry_token() -> String:
	return _settings.telemetry_token() if _settings != null else ""


## §3.2：会话元数据（版本/语言/平台/模组）；run 统计在退出时由 `_telemetry_summary` 补充。
func _telemetry_meta() -> Dictionary:
	return {
		"game_version": _game_version(),
		"framework_version": FrameworkInfo.VERSION,
		"content_schema": FrameworkInfo.CONTENT_SCHEMA,
		"locale": _context.localization.active_locale if _context != null else "zh_CN",
		"os": OS.get_name(),
		"mods": _telemetry_mods(),
	}


func _telemetry_mods() -> Array:
	var mods: Array = []
	if _context == null:
		return mods
	for mod in _context.mod_summaries():
		if mod is Dictionary:
			mods.append({"id": String(mod.get("id", "")), "version": String(mod.get("version", ""))})
	return mods


## §3「会话载荷」的 run 块：只放游玩统计，不含账号/路径/硬件信息。
func _telemetry_summary() -> Dictionary:
	var summary := {"run": {"has_run": false}}
	if _context == null:
		return summary
	summary["mods"] = _telemetry_mods()
	var state := _context.state
	var has_run := _context.has_run()
	var run := {"has_run": has_run}
	if has_run:
		run["seed"] = state.seed()
		run["port_id"] = state.current_port_id()
		run["money"] = state.money()
		run["game_hours"] = state.now()
		var victory: Variant = state.data.get("victory", null)
		run["victory"] = bool(victory is Dictionary and bool((victory as Dictionary).get("achieved", false)))
	summary["run"] = run
	return summary


## §3.3：白名单过滤在 TelemetryService 内完成，这里只转发已发布事件。
func _on_domain_event_published(event: Dictionary) -> void:
	if _telemetry != null:
		_telemetry.record_event(event)


## §3.5：启动且开启时后台补传遗留 pending（先进先出），不阻塞 UI。
func _start_background_upload() -> void:
	if _telemetry == null or _telemetry_uploader == null:
		return
	if DisplayServer.get_name() == "headless":
		# 无头测试/工具进程不得发起真实外网请求；正常游戏窗口不是 headless。
		return
	if _telemetry.pending_count() == 0:
		return
	# flush 是协程：动态 call 让它在后台跑完（成功删除、失败留待下次启动）。
	_telemetry_uploader.call("flush", _telemetry_endpoint(), _telemetry_token())


## §3.4：退出收尾。先 finalize 写 pending，再在 3 秒预算内尝试上传；失败保留并继续退出。
func _finalize_telemetry() -> void:
	if _telemetry == null or _telemetry_uploader == null:
		return
	if not _telemetry.is_recording():
		return
	var logger: AppLogger = _context.logger if _context != null else null
	var finalized := _telemetry.finalize_session(_telemetry_summary(), logger)
	if not bool(finalized.get("ok", false)):
		return
	if _telemetry.pending_count() == 0:
		return
	# 到点 abort() 取消在途请求并结束本轮；flush 以 aborted 汇总返回，退出流程照常继续。
	var timer := get_tree().create_timer(EXIT_UPLOAD_WAIT_SECONDS)
	timer.timeout.connect(func() -> void:
		if _telemetry_uploader != null and is_instance_valid(_telemetry_uploader):
			_telemetry_uploader.abort()
	)
	await _telemetry_uploader.flush(_telemetry_endpoint(), _telemetry_token())


func _on_nav(screen: String) -> void:
	# 4.5.3：补给页并入市场，旧导航 / 旧存档里的 supply 入口统一重定向。
	if screen == "supply":
		screen = "market"
	if screen != "sea_chart" and not _story_feature_unlocked(_story_screen_feature(screen)):
		return
	# Navigating away from the victory summary counts as "keep playing".
	_victory_dismissed = true
	var from := _active_screen
	if screen == "sea_chart":
		# Remember where the chart was opened from so closing returns there.
		_sea_chart_return = from if SCREENS.has(from) else "overview"
	elif not _chart_departure.is_empty():
		# Navigating away from the chart abandons a pending departure confirmation.
		_chart_departure = {}
	# dev.3 #1：离开结算页就丢掉那份摘要——否则之后任何一次带着
	# `_active_screen == "settlement"` 的重建都会把旧航次再“结算”一遍。
	if from == "settlement" and screen != "settlement":
		_settlement_summary = {}
	_active_screen = screen
	_status_message = ""
	# dev.3 #1：`ui:chart_opened` 只在真正打开海图时发一次（关闭仍由
	# `_on_sea_chart_closed` 发 `ui:chart_closed`）；页面重建不再重复上报。
	var chart_opened := screen == "sea_chart" and from != "sea_chart"
	# Adjacent station pages share one 3D district: a fade to black would hide the
	# camera pan and the sailing hull that are the point of the switch, so those
	# navigations rebuild instantly and let the stage carry the transition. Every
	# other navigation keeps the fade.
	var continuous := (
		STAGE_SCREENS.has(from)
		and STAGE_SCREENS.has(screen)
		and _port_stage_available()
	)
	# Observe before the rebuild so the refreshed card / objective / focus mask
	# already reflect the stage the chart entry just advanced.
	if chart_opened:
		_observe_story("ui:chart_opened")
	_refresh(not continuous)


func _on_screen_navigation(screen_id: StringName, params: Dictionary) -> void:
	if _story_card_open:
		return
	if screen_id == &"sea_chart":
		if not _story_feature_unlocked(StoryService.FEATURE_CHART):
			return
		# 委托「规划出航」等入口：打开海图时预选目的港（不直接出航）。
		_pending_chart_port = String(params.get("destination", ""))
	_on_nav(String(screen_id))


func _on_new_run() -> void:
	var seed := 0
	if not _seed_text.strip_edges().is_empty() and _seed_text.strip_edges().is_valid_int():
		seed = int(_seed_text.strip_edges())
	_selected_strategy = ""
	_chart_departure = {}
	_pending_chart_clue = ""
	_sea_chart_return = "overview"
	_status_message = ""
	# 教学局使用默认起始场景（新航程页已隐藏场景选择），不传玩家选择。
	var scenario_id := "" if _tutorial_mode else _selected_scenario
	_run_command(&"run.start", {"starting_scenario": scenario_id, "seed": seed, "tutorial": true})


func _on_continue() -> void:
	var loaded := _context.save.load_autosave()
	if not bool(loaded.get("ok", false)):
		_set_status(String(loaded.get("error", "load failed")), true)
		_refresh()
		return
	var validation := _context.save.validate_mods(loaded.get("header", {}), _context.mod_summaries())
	if not bool(validation.get("ok", false)):
		_set_status(", ".join(validation.get("errors", [])), true)
		_refresh()
		return
	_context.set_state(loaded["state"])
	_context.set_seed(_context.state.seed())
	MarketOps.ensure_sell_only_entries(_context.registries, _context.state)
	if not MarketMemoryService.has_memory(_context.state, _context.state.current_port_id()):
		MarketMemoryService.remember(_context.state, _context.state.current_port_id())
	_selected_strategy = ""
	_chart_departure = {}
	_pending_chart_clue = ""
	_sea_chart_return = "overview"
	_reset_voyage_presentation()
	_active_screen = "overview"
	_victory_dismissed = false
	_set_status("已载入自动存档", false)
	_refresh(true)


func _run_command(command: StringName, params: Dictionary) -> void:
	if _context == null:
		return
	# Marks the status feedback as interaction-driven so `_set_status` also pops the
	# floating hint at the cursor (dev.3 feedback #4). Cleared on every exit path.
	# `run.start` comes from the new-game menu, so it must not pop a port-page hint.
	_interactive_command = command != &"run.start"
	# 4.5.2：剧情阶段可以临时锁住某个动作（如补给限购），由 Core 阶段表声明。
	if _story_action_locked(command):
		_set_status(_tr("ui.story.supply_locked", "补给暂时受限：先看完海图的目的港"), true)
		_interactive_command = false
		return
	var result := _context.commands.execute(command, params)
	if bool(result.get("ok", false)):
		_handle_success(command, result)
		# 4.5：把成功命令转发给剧情状态机（剧情自身的命令不再回灌）。
		if command != &"run.start" and not String(command).begins_with("story."):
			_observe_story("cmd:%s" % String(command), result.get("data", {}))
	else:
		_set_status(_error_text(result), true)
	# `voyage.start` / `event.choose_option` hand over to the cloud transition,
	# so the generic page fade would fight the veil — rebuild without animation.
	var presentation_handoff := _presentation != null and command in [
		&"voyage.start", &"event.choose_option", &"explore.start", &"clue.travel",
	]
	var animate := command in [
		&"run.start", &"voyage.start", &"event.choose_option", &"clue.travel",
	] and not presentation_handoff
	_refresh(animate)
	_interactive_command = false


func _handle_success(command: StringName, result: Dictionary) -> void:
	var data: Dictionary = result.get("data", {})
	if command in [&"trade.buy", &"trade.sell", &"contract.accept", &"supply.buy_coal", &"supply.buy_water", &"ship.craft_module"]:
		_play_pickup()
	match String(command):
		"story.advance", "story.skip", "story.observe":
			pass
		"run.start":
			_active_screen = "overview"
			_selected_strategy = ""
			_chart_departure = {}
			_pending_chart_clue = ""
			_victory_dismissed = false
			_settlement_summary = {}
			_reset_voyage_presentation()
			_set_status("新航程开始 · 种子 %d" % int(data.get("seed", 0)), false)
		"voyage.start", "clue.travel":
			_handle_voyage_result(data)
		"explore.start":
			# 探索出航走同一套演出，只是目的地要等 `explore.settle`。
			_start_explore_presentation(data)
		"clue.buy":
			_handle_clue_bought(data)
		"clue.investigate":
			_handle_clue_investigated(data)
		"chart.buy":
			# 2026-10-26 航线解锁：酒馆买到海图后状态栏确认「哪条航线已测绘」。
			# 页面由 `_run_command` 的常规 `_refresh()` 重建（area 的 chart_offers 变已解锁）。
			_set_status(_tr(
				"ui.notice.chart_purchased", "已购买 %s 海图（%d 金币），航线已测绘。"
			) % [_port_name(String(data.get("to", ""))), int(data.get("cost", 0))], false)
		"event.choose_option":
			if bool(data.get("failed", false)):
				_presentation = null
				_presentation_explore = {}
				_at_sea_screen = null
				_sync_cloud_veil(0.0)
				_active_screen = "overview"
				_set_status("航行失败，已恢复到出航前状态。", true)
			elif _presentation != null:
				# Resume the remaining leg of the voyage: the veil comes back, the
				# chart page returns, and the presentation plays out to arrival.
				var summary: Variant = data.get("summary", data.get("event_result", null))
				_presentation_summary = summary if summary is Dictionary else {}
				_presentation.resolve_event()
				_sync_cloud_veil(0.0)
			else:
				_full_stop_after_voyage(data)
		"trade.buy":
			if String(data.get("destination", "cargo")) == "warehouse":
				_set_status(_tr("ui.notice.trade_buy_warehouse", "买入 %s ×%d，存入 %s 仓库，花费 %d 金币。") % [
					_item_name(String(data.get("item_id", ""))),
					int(data.get("amount", 0)),
					_port_name(String(data.get("port_id", _last_port_view.get("current_port_id", "")))),
					int(data.get("total", 0)),
				], false)
			else:
				_set_status("买入 %s ×%d，花费 %d 金币。" % [
					_item_name(String(data.get("item_id", ""))),
					int(data.get("amount", 0)),
					int(data.get("total", 0)),
				], false)
		"trade.sell":
			if String(data.get("source", "cargo")) == "warehouse":
				_set_status(_tr("ui.notice.trade_sell_warehouse", "从 %s 仓库卖出 %s ×%d，收入 %d 金币。") % [
					_port_name(String(data.get("port_id", _last_port_view.get("current_port_id", "")))),
					_item_name(String(data.get("item_id", ""))),
					int(data.get("amount", 0)),
					int(data.get("revenue", 0)),
				], false)
			else:
				_set_status("卖出 %s ×%d，收入 %d 金币。" % [
					_item_name(String(data.get("item_id", ""))),
					int(data.get("amount", 0)),
					int(data.get("revenue", 0)),
				], false)
		"supply.buy_coal", "supply.buy_water":
			var supply_kind := "ui.label.coal" if String(data.get("kind", "")) == "coal" else "ui.label.water"
			_set_status("已购买%s ×%d，花费 %d 金币。" % [
				_tr(supply_kind, ""),
				int(data.get("amount", 0)),
				int(data.get("total", 0)),
			], false)
		"supply.repair":
			_set_status("维修完成，花费 %d 金币。" % int(data.get("cost", 0)), false)
		"ship.install_module":
			var install_source := String(data.get("source", "purchase"))
			var replaced := String(data.get("replaced_module_id", ""))
			var install_message := ""
			if install_source == "purchase":
				install_message = _tr("ui.notice.module_installed", "已购买并安装 %s，花费 %d 金币。") % [
					_module_name(String(data.get("module_id", ""))),
					int(data.get("price", 0)),
				]
			else:
				install_message = _tr("ui.notice.module_installed_free", "已免费安装 %s。") % [
					_module_name(String(data.get("module_id", ""))),
				]
			if not replaced.is_empty():
				install_message += _tr("ui.notice.module_replaced", " 旧件已存入当前港仓库。")
			var install_victory: Variant = data.get("victory", null)
			if install_victory is Dictionary and bool(install_victory.get("newly_achieved", false)):
				_victory_dismissed = false
				install_message += _tr("ui.notice.victory", " 已达成通关条件。")
			_set_status(install_message, false)
		"ship.uninstall_module":
			_set_status(_tr("ui.notice.module_uninstalled", "已卸下 %s，存入当前港仓库。") % [
				_module_name(String(data.get("module_id", ""))),
			], false)
		"ship.craft_module":
			var order_port := String(data.get("port_id", _last_port_view.get("current_port_id", "")))
			_set_status(_tr("ui.notice.craft_ordered", "") % [
				_port_name(order_port),
				_module_name(String(data.get("module_id", ""))),
				_fmt(float(data.get("craft_time_hours", 0.0))),
				int(data.get("craft_cost", 0)),
			], false)
		"port.wait":
			var wait_hours := float(data.get("hours", 0.0))
			var wait_port := String(data.get("port_id", _last_port_view.get("current_port_id", "")))
			var wait_message := _tr("ui.notice.waited", "") % [_port_name(wait_port), _fmt(wait_hours)]
			for order in data.get("completed_orders", []):
				if not (order is Dictionary):
					continue
				wait_message += " " + _tr("ui.notice.craft_completed", "") % [
					_module_name(String(order.get("module_id", ""))),
					_port_name(String(order.get("port_id", wait_port))),
				]
			_set_status(wait_message, false)
		"warehouse.store_module":
			_set_status(_tr("ui.notice.warehouse_module_stored", "已把 %s 存入港口仓库。") % [
				_module_name(String(data.get("module_id", ""))),
			], false)
		"warehouse.take_module":
			_set_status(_tr("ui.notice.warehouse_module_taken", "已把 %s 取到船上。") % [
				_module_name(String(data.get("module_id", ""))),
			], false)
		"warehouse.store_materials":
			_set_status(_tr("ui.notice.warehouse_materials_stored", "已存入 %s ×%d。") % [
				_item_name(String(data.get("item_id", ""))),
				int(data.get("amount", 0)),
			], false)
		"warehouse.take_materials":
			_set_status(_tr("ui.notice.warehouse_materials_taken", "已取出 %s ×%d。") % [
				_item_name(String(data.get("item_id", ""))),
				int(data.get("amount", 0)),
			], false)
		"contract.accept":
			var contract: Dictionary = data.get("contract", {})
			_set_status("已接受委托：%s" % _tr(String(contract.get("name_key", "")), String(contract.get("template_id", ""))), false)
		"intel.refresh":
			_set_status("情报已刷新 · %s" % String(data.get("generated_label", "")), false)
		"debt.borrow":
			_set_status("已借款 %d，到期需偿还 %s。" % [
				int(data.get("principal", 0)),
				_fmt(float(data.get("total_due", 0.0))),
			], false)
		_:
			_set_status("", false)


func _handle_voyage_result(data: Dictionary) -> void:
	# Every successful departure runs the phase-3 presentation: clouds over the
	# port, the chart with the ship sailing, then event/arrival. The voyage itself
	# was already settled by the command, so this only decides how it is shown.
	_start_voyage_presentation(data)


## `clue.buy` 成功：状态栏只报来源（不泄露等级/目标港），海图由 `_run_command`
## 的常规 `_refresh()` 重建，新的 `clues` 自然出现在图上。
func _handle_clue_bought(data: Dictionary) -> void:
	var clue: Dictionary = {}
	if data.get("clue", null) is Dictionary:
		clue = data["clue"] as Dictionary
	elif data.get("source_key", null) != null or data.get("id", null) != null:
		clue = data
	var source_key := String(clue.get("source_display_key", ""))
	if source_key.is_empty():
		source_key = "ui.clue.source." + String(clue.get("source_key", ""))
	var source := _tr(source_key, "线索")
	_set_status(_tr("ui.notice.clue_acquired", "获得线索：%s") % source, false)


## `clue.investigate`（4.3.2 / 4.4.3）：成功只报新的线索等级（不泄露目标港 / 可信度）；
## 4.4.3 起可能因成功率判定失败或工时耗尽时效，分别给出可重试 / 已过期的状态提示。
## 海图由 `_run_command` 的常规 `_refresh()` 重建，等级裁剪后的线索层自然更新。
func _handle_clue_investigated(data: Dictionary) -> void:
	if bool(data.get("expired", false)):
		_set_status(_tr("ui.error.clue_expired", "这条线索已经过期"), true)
		return
	if not bool(data.get("success", true)):
		_set_status(
			_tr("ui.notice.clue_investigation_failed", "调查没有结果：线索未升级，可以再试"),
			true
		)
		return
	_set_status(
		_tr("ui.notice.clue_investigated", "线索调查完成：已升至 %d 级") % int(data.get("level", 0)),
		false
	)


func _full_stop_after_voyage(data: Dictionary) -> void:
	var summary: Variant = data.get("summary", data.get("event_result", null))
	if summary is Dictionary:
		_settlement_summary = summary
		_active_screen = "settlement"
		_status_message = ""
		# dev.3 #1：没有演出可播的旧路径（读档后停在事件点）同样只在结算这一刻
		# 上报一次抵达事件，不由结算页重建重复推进剧情。
		_observe_story("ui:arrival_settled")
	else:
		_active_screen = "overview"
		_set_status("已抵达目的港。", false)


## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------

func _resolve_context() -> AppContext:
	var active := AppContext.get_active()
	if active != null:
		return active
	var autoload := get_node_or_null("/root/AppBootstrap")
	if autoload != null and autoload.context != null:
		return autoload.context
	return null


## Persists the status message for the top banner, and — when the feedback comes
## from a player interaction on a port page — also pops the floating hint at the
## cursor. dev.3 feedback #4: the banner is at the top of the page while the player
## interacts lower down; the banner stays (persistent state + tests), the hint is the
## immediate feedback. Text still comes from `_tr` / localization keys.
func _set_status(message: String, is_error: bool) -> void:
	_status_message = message
	_status_is_error = is_error
	if _interactive_command and not message.is_empty() and _in_port_interaction():
		_show_interaction_hint(message, is_error)


func _retry_bootstrap() -> void:
	var boot := Bootstrap.new()
	var report := boot.run()
	AppContext.set_active(boot.context)
	_context = boot.context
	_settings_applied = false
	_set_status("" if not report.has_fatal() else _tr("ui.error.start_failed", ""), report.has_fatal())
	_refresh(true)


func _show_diagnostics() -> void:
	if _context == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = _tr("ui.button.log", "Diagnostics")
	dialog.dialog_text = _context.report.format_text() + "\n\ncommands: " + ", ".join(_context.commands.names()) + "\n\n" + _context.logger.to_text()
	dialog.ok_button_text = _tr("ui.button.close", "Close")
	add_child(dialog)
	dialog.popup_centered(Vector2i(1000, 700))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _error_text(result: Dictionary) -> String:
	var message_key := String(result.get("message_key", ""))
	var error_code := String(result.get("error_code", ""))
	return _tr(message_key, error_code)


func _tr(key: String, fallback: String = "") -> String:
	if _context == null:
		return fallback if not fallback.is_empty() else key
	return _context.translate(key, fallback)


## Label factory. The color defaults to the `text.light` token (a transparent
## sentinel keeps the default argument a compile-time constant while the real
## token still lives in skin.json).
func _label(text: String, font_size: int = 15, color: Color = Color.TRANSPARENT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color if color.a > 0.0 else SNSkin.color("text.light"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _badge(text: String, tone: int = SNBadge.Tone.NEUTRAL) -> Label:
	var badge := SNBadge.new()
	badge.text = text
	badge.tone = tone
	return badge


func _page_heading(eyebrow: String, title: String, detail: String = "") -> SNSectionHeader:
	var header := SNSectionHeader.new()
	header.eyebrow = eyebrow
	header.title = title
	header.detail = detail
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return header


func _button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.pressed.connect(callback)
	return button


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)
	return panel


func _panel_add(panel: PanelContainer, node: Node) -> void:
	var content := panel.get_node_or_null("Content")
	if content is VBoxContainer:
		content.add_child(node)
	else:
		panel.add_child(node)


func _fmt(value: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f") % value


func _facility_name(facility: String) -> String:
	var names := {
		"exchange": "交易所",
		"contracts": "港务承运局",
		"supply": "补给码头",
		"shipyard": "造船厂",
		"tavern": "酒馆",
		"intel": "情报站",
	}
	return names.get(facility, facility)


## Short label for an edge signboard ("市场" / "Market"); the long facility name
## above stays in the detail panels.
func _facility_sign_name(facility: String) -> String:
	return _tr("ui.facility.%s" % facility, _facility_name(facility))


func _age_text(age_hours: float) -> String:
	if age_hours < 0.5:
		return "刚刚刷新"
	return "%s 小时前" % _fmt(age_hours)


func _definition_name(definition_id: String) -> String:
	for content_type in ContentTypes.all():
		var definition := _context.registries.get_by_id(content_type, definition_id)
		if definition != null:
			return _tr(definition.name_key, definition_id)
	return definition_id


func _item_name(item_id: String) -> String:
	var definition := ShipOps.item_definition(_context.registries, item_id)
	return _tr(definition.name_key, item_id) if definition != null else item_id


func _module_name(module_id: String) -> String:
	var definition := ShipOps.find_installable(_context.registries, module_id)
	return _tr(definition.name_key, module_id) if definition != null else module_id


## Localized display name of a port. Ports are generated from the run seed and
## their ids/names never change during a run, so the table is cached per seed:
## status messages ask for 1–3 names per interaction and each miss used to run a
## full `map.view` query (i.e. a whole GameState clone, 13.5 ms).
func _port_name(port_id: String) -> String:
	if port_id.is_empty():
		return port_id
	if _context == null:
		return port_id
	var cache := _port_name_cache
	if _port_name_seed != _context.state.seed():
		cache.clear()
		_port_name_seed = _context.state.seed()
	if cache.has(port_id):
		return _tr(String(cache[port_id]), port_id)
	var map_result := _context.queries.execute(&"map.view")
	if bool(map_result.get("ok", false)):
		for port in map_result["data"].get("ports", []):
			var id := String(port.get("id", ""))
			if id.is_empty():
				continue
			cache[id] = String(port.get("name_key", ""))
		if cache.has(port_id):
			return _tr(String(cache[port_id]), port_id)
	return port_id



func _value_name(port: Dictionary, fallback: String) -> String:
	return _tr(String(port.get("name_key", "")), fallback)


func _standard_strategy_id() -> String:
	for strategy in _context.registries.get_all(ContentTypes.BOILER_STRATEGY):
		if strategy.has_tag("strategy.standard"):
			return strategy.id
	var strategies := _context.registries.get_all(ContentTypes.BOILER_STRATEGY)
	return strategies[0].id if not strategies.is_empty() else ""


func _neighbor_ids() -> Array[String]:
	var result: Array[String] = []
	for destination in _last_port_view.get("destinations", []):
		result.append(String(destination.get("port_id", "")))
	return result


func _is_neighbor(port_id: String) -> bool:
	return _neighbor_ids().has(port_id)


func _cargo_amount_on_ship(item_id: String) -> int:
	var ship: Dictionary = _last_port_view.get("ship", {})
	for stack in ship.get("cargo", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("item_id", "")) != item_id:
			continue
		if bool(stack.get("is_contract", false)):
			continue
		return int(stack.get("amount", 0))
	return 0
