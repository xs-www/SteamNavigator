# `framework/ui/shell/main.gd`

> 作用：可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并挂载已场景化的菜单/港口/流程页。主界面是「全窗 3D 港口舞台 + 紧凑顶部 chrome（图标 + 文字导航）+ 两侧设施招牌」的分层外壳；底部状态条与详细总览抽屉已在 2026-10-28 UI 轮移除（功能由顶部 chrome / 2D 总览页承担）。Shell 只保留上下文解析、ViewModel 组合、会话导航状态与命令派发。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI_THEME` | L166 |
| `HARBOR_SIGN_SCRIPT` | L168 |
| `MARKET_SCREEN_SCENE` | L169 |
| `CARGO_HOLD_PANEL_SCRIPT` | L171 |
| `ITEM_FALLBACK_ICON` | L173 |
| `CARRY_GHOST_SCENE` | L177 |
| `INTERACTION_HINT_SCENE` | L178 |
| `CONTRACTS_SCREEN_SCENE` | L179 |
| `SUPPLY_SCREEN_SCENE` | L180 |
| `INTEL_SCREEN_SCENE` | L181 |
| `OVERVIEW_SCREEN_SCENE` | L182 |
| `SHIPYARD_SCREEN_SCENE` | L183 |
| `BASE_SCREEN_SCENE` | L184 |
| `AUTO_TRADE_SCREEN_SCENE` | L185 |
| `RUINS_SCREEN_SCENE` | L186 |
| `PORT_MEMORY_SCREEN_SCENE` | L187 |
| `SETTLEMENT_SCREEN_SCENE` | L188 |
| `AT_SEA_SCREEN_SCENE` | L189 |
| `EVENT_SCREEN_SCENE` | L190 |
| `SEA_CHART_SCREEN_SCENE` | L191 |
| `CLUE_LOG_SCREEN_SCENE` | L192 |
| `STORY_CARD_SCRIPT` | L193 |
| `STORY_OBJECTIVE_SCRIPT` | L194 |
| `STORY_FOCUS_SCRIPT` | L195 |
| `TASK_TRACKER_SCRIPT` | L196 |
| `VICTORY_SCREEN_SCENE` | L197 |
| `MAIN_MENU_SCREEN_SCENE` | L198 |
| `UPDATE_DIALOG_SCENE` | L199 |
| `NEW_GAME_SCREEN_SCENE` | L200 |
| `MODS_SCREEN_SCENE` | L201 |
| `SETTINGS_SCREEN_SCENE` | L202 |
| `NAV_ICONS` | L205 |
| `NAV_ICON_MAX_WIDTH` | L218 |
| `DEV_TEAM` | L219 |
| `GAME_VERSION_FALLBACK` | L220 |
| `SCREENS` | L224 |
| `HIDDEN_NAV_SCREENS` | L229 |
| `PORT_STAGE_SCENE_PATH` | L232 |
| `PORT_STAGE_FACILITY_SCREENS` | L234 |
| `STAGE_SCREENS` | L247 |
| `DOCK_PANEL_WIDTH` | L256 |
| `CARGO_HOLD_PANEL_WIDTH` | L258 |
| `MARKET_COLUMN_GAP` | L260 |
| `TOP_CHROME_MAX_HEIGHT` | L264 |
| `PORT_SIGN_WIDTH` | L267 |
| `PORT_SIGN_HEIGHT` | L268 |
| `PORT_SIGN_GAP` | L269 |
| `PORT_SIGN_MARGIN` | L270 |
| `HUD_ICON_KEYS` | L276 |
| `HUD_SKIN_ICONS` | L280 |
| `HUD_ICON_SIZE` | L292 |
| `PAGE_BOTTOM_MARGIN` | L295 |
| `EXIT_UPLOAD_WAIT_SECONDS` | L297 |

## 皮肤接线（ui-skin-v1）
- 所有纹理/图标/颜色经 `SNSkin`（`framework/ui/skin/sn_skin.gd`）读取 `assets/ui/skin/sn_v1/skin.json`；
  本文件不写贴图路径、不写十六进制颜色，也不再手写 StyleBoxFlat。
- 顶栏 `_chrome_style()` = `SNSkin.panel("chrome")`（半透明钢框、content 16/12）；皮肤缺失时
  退回 Theme 的 `SNChromePanel` 变体，文字与交互不丢。底部状态条（`SNStatusBarPanel`）已移除。
- 导航/小按钮走 Theme 变体：当前页 `SNPrimaryButton`，其余 `SNCompactButton`；图标来自
  `SNSkin.icon()`（`button.icon` + `icon_max_width = 18`）。2026-10-28 UI 轮：导航是
  「图标 + 本地化页名」按钮，入口身份仍走 `nav_screen` meta（剧情引导与测试按 meta 解析）。
- HUD chip 图标：皮肤表 `HUD_SKIN_ICONS` 是唯一来源（语义键 → 皮肤 icon id）；内容包仍可
  经 `HUD_ICON_KEYS` 覆盖（本轮为空表，`AssetService.find_key` 返回空则安全回退到皮肤），
  两者都没有时只显示数值文字。
- 边缘设施招牌交给 `SNHarborSign`（纹理化 Button）；Shell 只负责 `facilities → 页面` 的布局与导航。

## 尺寸预算
- `TOP_CHROME_MAX_HEIGHT = 130`：两行 chrome（品牌/状态/时间·金钱·声望 + 资源 chip/导航）实测最小高度必须 ≤130；
  3D 舞台是主视图，HUD 只做画框。图标轮后 chip 是 24 px 图标 + 数值单行，比旧的两行 label 更矮。
- 招牌 `172×42`、右列固定「海图 ▶」入口；`PageMargin` 底部为页脚预留 56。
  底部状态条移除后页脚在页面态常驻，3D 总览主视图隐藏页脚（`_sync_footer_visibility()`）。

## 契约
- 数据只走 QueryBus，修改只走 CommandBus；UI 会话状态不写存档。
- `SCREENS` / `STAGE_SCREENS` / `PORT_STAGE_FACILITY_SCREENS` 是导航契约，换皮不得改动键名或命令路径。
- 顶部导航只渲染 `SCREENS` 中不在 `HIDDEN_NAV_SCREENS` 里的页面：基地（D3 基地建设）、
  贸易（D4 自动贸易）、遗迹（D5 遗迹远征）三个系统尚未作为玩家功能发布，入口暂隐藏；
  其中遗迹属于**航行探索**玩法（海图 → 探索），不作为港口页入口。三个页面的场景、
  `_screen_*` 挂载函数与 `ui.nav.*` 本地化键保留：`tools/ui_snapshot.gd` 仍直接路由
  这些页面做视觉验收，未来重新发布时只需从 `HIDDEN_NAV_SCREENS` 移除对应键。
- 每个 PanelContainer 只允许一个 VBox 内容容器（`_panel_add()`）；页面场景只发意图，不持有 AppContext。
- `-- --release-smoke` 专供成品启动门禁：真实 Autoload 与主场景启动后检查 Core 报告、
  MainMenuScreen 脚本/ready/按钮树；成功打印 `[release-smoke] main-menu-ready`，再走
  `_graceful_quit(exit_code)` 的真实退出路径，检查结果只通过退出码表达。
  未传参数时不执行检查；不创建新局、不修改正常启动流程。
- 自动更新（`docs/design/AUTO_UPDATE.md`）：`_setup_update_service()` 只在发布版（`OS.has_feature("template")`）
  创建 `UpdateService`；主菜单的 `UpdateButton` 只显示状态，「游戏更新」对话框由 Shell 持有并只转发意图。
  `_on_update_restart()` 启动自替换后的新 exe 再走 `_graceful_quit()`。编辑器与无头测试永不联网。
  `-- --update-selftest` 是发布包专用内部验收钩子：自动 check → available 时 download，staged/up_to_date
  时打印 `[update-selftest]` 后退出，供 `tools/update_e2e.ps1` 在真实安装目录验证下载/替换/重启。

## HUD 图标化 / 文字精简（2026-10-28 图标轮）
- 顶部 chrome 的品牌列删掉 9 px `ui.label.port` 小标题，只留港口名（语义进 tooltip）；
  时间 / 金币 / 声望 chip 只剩图标 + 数值。
- `_stat_chip()` 统一为「皮肤图标 + 数值」单行容器：`label_text` 变成 chip 的
  `tooltip_text`，不再画 label；`chip_key` 与内部 `Value` 子节点名保留（煤 / 水逐帧插值依赖）。
- `HUD_SKIN_ICONS` 语义键：free_weight→resource_cargo、free_capacity→shipyard_cargo、
  coal→resource_coal、water→resource_water、durability→resource_durability、cargo→resource_cargo、
  money→resource_coins、reputation→status_reputation、time→status_time、damaged→status_warning；
  `HUD_ICON_KEYS` 已清空（早期 `icon.money/coal/water` 内容资产退役），只保留内容包覆盖通道。
- 导航是「图标 + 本地化页名」：`SCREENS` 每个入口 64×36、`icon` + `text`、
  `set_meta("nav_screen", screen)`；海图 toggle 同样带 `nav_screen = "sea_chart"`。
  `_story_nav_button()` 先按 meta 解析、再按旧文字回退，隐藏入口仍返回 null。
- 2026-10-28 UI 轮：底部状态条与「详细总览」抽屉整条移除（与顶部 chrome 重复）；
  耐久/货舱/煤/水/受损读数留在顶部 chip，海图入口留在导航，等待 6/12/24 h 与
  航行记录留在 2D 总览页。「详细总览」= 顶部「2D 总览」开关切到的 2D 页面。

## 剧情 UI 事件时机与强制引导（v0.2.0-dev.3 #1 / #3）
- `ui:*` 是**玩家动作**，由 Shell 在动作发生处上报一次：`ui:chart_opened` 在
  `_on_nav("sea_chart")`、`ui:chart_closed` 在 `_on_sea_chart_closed`、
  `ui:arrival_settled` 在 `_finish_presentation()` / `_full_stop_after_voyage()`
  的抵达结算点。页面挂载函数（`_screen_settlement` / `_screen_sea_chart`）只渲染、
  不再 observe，因此剧情卡继续 / resize / 状态刷新引起的页面重建不会重复推进剧情。
- `DEPARTURE_VEIL` 归入 `_presentation_on_stage()`：离港云层期间继续挂出发港 3D
  舞台（origin 视图），不会在演出中途掉回海图页并重复上报 `ui:chart_opened`。
- 离开结算页清空 `_settlement_summary`，避免旧航次摘要被后续重建再次“结算”。
- `SNFocusOverlay`（framework/ui/components/sn_focus_overlay.gd）：剧情阶段的
  `story.view.focus.target` 由 `_resolve_story_focus_target()` 解析成真实控件
  （`market_supply` / `chart_entry` / `<screen>_nav`）；页面挂好、每次重建与窗口
  resize 后由 `_sync_story_focus()` 更新，剧情卡 / 演出 / 结算页时清除。
- **重建后的引导框定位**：`_rebuild_ui_body()` 里的同步 `_sync_story_focus()` 只能
  读到刚重建的 TopChrome/Nav 还没排版时的旧 `global_rect`。所以重建后紧接
  `_sync_story_focus_soon()`（两次 deferred，同 `_refresh_port_hotspots_soon` 手法）
  兜底目标重解析；遮罩本身通过 `focus_target()` 绑定真实控件并逐帧自愈，
  容器排版 / resize 导致目标移动时框自动追上（不再停在旧位置）。

## 退出与性能（P0，2026-10-24）
- **优雅退出**：`_ready()` 设 `get_tree().auto_accept_quit = false`，窗口关闭请求走
  `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` → `_graceful_quit()`；「退出游戏」按钮同样走它。
  `_prepare_quit()` 幂等：停演出、`unmount_stage()` 并释放 `_port_stage_host`（它持有
  SubViewport + 世界 + MSAA framebuffer）、释放页面树/全屏层与热点层，随后
  `ContentAssetLoader.clear_cache()` + `FrameworkRuntime.shutdown()`（此前只有测试会调用）。
- **导出构建退出崩溃的引擎兜底**：Godot 4.7.2 GL Compatibility 在「本会话渲染过 3D 舞台」
  后退出时于 GLES3 storage teardown 崩溃（0xC0000005，dev.3 与 HEAD 导出版均可复现，应用层
  清理无效）。因此 `_had_3d_stage` 为真且非编辑器构建时，清理完成后用 `OS.kill()` 结束进程，
  玩家看到的是正常关闭而不是 Windows 崩溃弹窗；纯菜单会话仍走 `get_tree().quit()`。引擎升级后应移除该兜底。
- **整页重建读作用域**：`_rebuild_ui()` 包在 `QueryBus.begin_read_scope()` /
  `end_read_scope()` 里，一次重建只克隆一次 GameState（每查询克隆 11.6 ms → 一次）；
  `CommandBus` 提交成功后 `invalidate_read_snapshot()` 保证后续查询看到已提交状态。
- **港口名缓存**：`_port_name()` 以 run seed 为键缓存 `port_id → name_key`，一次 `map.view`
  填满整表；状态消息不再每条触发一次 `map.view` 全状态克隆（13.5 ms/次）。

## 市场页（图标直接交易，`docs/design/MARKET_UI_REFACTOR.md`）
- `_screen_market()` 先执行 `market.view`；查询不可用时回退用 `port.view` 的行情 / 船摘要
  组装同名字段的 ViewModel，页面不崩。
- 每个行情 / 船舱 / 仓库行的 `icon_key` 由 Shell 经 `AssetService.find_key` →
  `AssetService.load_texture` 解析成 `Texture2D`（实例内缓存）；缺失时回退
  `assets/ui/icons/item_fallback.svg`，再缺失回退框架占位贴图。
- 舞台可用时挂三栏 `DockPanelRow`：`CargoHoldPanel`(360) + 透明 `StageWindow`
  (expand, `MOUSE_FILTER_IGNORE`, 只露出 3D 港区) + `DockPanel`(640)；舞台不可用时
  退化成 `CargoHoldPanel` + 市场面板两栏，不出现空白舞台窗口。
- 角标分工：市场行情格右上角显示**剩余库存**（`SNItemTile` 的 `remaining` 模式，
  `stock - pending`）；玩家已选数量（`×N`）与**预计消费**（`unit_price × amount`，
  文案键 `ui.market.estimated_cost`）显示在跟随鼠标的 `SNCarryGhost` 上。行情格
  `meta` 只保留单价 + 趋势，不和角标重复。`offer` 由 `MarketScreen._offer_for()`
  组装并携带 `unit_price`。
- 页面只发命令意图：`trade.buy{destination}` / `trade.sell{source}` /
  `warehouse.store_materials` / `warehouse.take_materials`。

## 委托页（反馈 #2 / #3）
- 可接委托列表直接来自 `port.view`（已在查询层过滤掉目的港未发现的普通委托）；
  Shell 不再做二次雾判断，也不隐藏主线 offer（生成时已揭示目的地）。
- 无期限委托（`has_deadline=false`）在总览奖励文案里用「完成 +N」而不是「准时 +N」；
  委托页卡片的期限显示由 `contracts_screen` 负责。

## 航线解锁（2026-10-26）
- 酒馆页「海图（航线解锁）」区块发 `chart.buy {port_id}`；成功由 `_handle_success` 的
  `"chart.buy"` 分支在状态栏确认已测绘航线，`_refresh()` 重建页面后
  `tavern.view.chart_offers` 的该港口变为 `unlocked=true`（显示「已测绘」）。
- 海图页签 `voyage.preview` / `voyage.start` / `clue.travel` 的 `route_locked` 失败按
  既有错误路径显示 `ui.error.route_locked`；面板在未测绘航线上禁用启航并显示酒馆提示。

## 游玩数据上传（`docs/design/TELEMETRY.md`，唯一契约）
- 首次解析到 AppContext 时（`_apply_settings_if_needed`）按设置创建 `TelemetryService`
  并挂到 `AppContext.telemetry`；`TelemetryUploader` 作为 Shell 子节点，Shell 退出时随
  场景树一起释放。`_settings_applied` 的重置（retry bootstrap）会重新绑定新 context。
- 开启时 `begin_session(meta)`；`DomainEventBus.event_published` 只把契约白名单事件
  （`voyage/port/contract/combat/story/quest/market/run.*`）交给服务，CommandBus 负责命令记录。
- 设置页 VM 的 `telemetry_enabled` 来自 `SettingsService`；`toggle_telemetry` 先写设置、
  再切换服务（关闭时服务清空缓冲并删除 pending 队列），最后保存配置。
- 退出：`_graceful_quit()` 先 `finalize_session` 写 pending，再最多等
  `EXIT_UPLOAD_WAIT_SECONDS`（3 秒）尝试上传，然后才执行原有 teardown / 3D 退出兜底；
  `_prepare_quit()` 不做网络（测试直接调用它）。启动时的遗留队列补传在后台进行、不阻塞 UI。
- 无头进程（测试/工具）不发起真实网络请求：启动补传在 headless 下跳过；`_prepare_quit` 不联网。

模块索引：[framework/ui](../README.md)
