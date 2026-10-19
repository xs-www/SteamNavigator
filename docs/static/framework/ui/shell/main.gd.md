# `framework/ui/shell/main.gd`

> 作用：可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并把已迁移页面挂载到场景宿主；总览页的 3D 港口舞台宿主与 2D 设施热点层也由 Shell 持有（页面只发切换意图）。

- 类型：GDScript 源文件

## 契约与约束

- 所有数据经 QueryBus 获取，所有修改经 CommandBus；UI 不保存规则状态。
- 顶部信息条在船只存在受损部件时追加「部件 N · NN%」chip（来自 port.view.ship 的 damaged_modules / worst_module_condition），健康时不占位；chip 颜色在失效时为红。
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
- 反馈5：顶部信息条固定显示当前港口（在航时显示“在航 → 目的港”）、剩余载重 free_weight/max_weight 与剩余货舱 free_cargo_capacity/cargo_capacity。
- 反馈6：总览“当前目标”显示通关条件清单（主线 n/5 → 大型船体 → 锅炉 → ≥1 货舱 → 造船厂组装），主线完成后给出下一步提示；数据来自 port.view.victory.conditions 与 contracts.main_done/main_total。船厂页不再重复通关清单，只做组件分类入口。
- 反馈3：情报页用 SNIntelTable 渲染 intel.view 的 columns/rows 矩阵（含未知港口列），替代旧的逐港商品表格。
- 反馈4：打造订单与在港等待迁入船厂改装态「杂项」页签：等待按钮按 wait_options 生成 6/12/24 小时 `port.wait`，总览快捷入口同样提供等待按钮；模块类分类内保留「按配方打造」，打造按钮文案带工时。
- 反馈2：补给卡绑定 SNSupplyCard 时传入 _tr 回调，显示“上限损失/剩余可装”本地化文案。
- `_notice_text(notice)` 用 `_format_slots(template)`（`%[sd]` 正则、保序）取槽位：字符串参数先按本地化键解析，再按 push 顺序 `template % args`；槽位数与参数数不符、或 `%d` 槽位对应参数不是 int/float 时原样返回模板而不报格式错误；缺键时返回键名。空模板 / 无参数 / 无槽位直接返回模板本身，「航行记录」由此渲染成句。通知文案本地化由 test_ui_shell 的两个用例守护（真实渲染 + 源码 `push_notice` 键扫描，中英槽位序列保序一致）。
- 总览 3D 港口舞台由 Shell 持有：`PORT_STAGE_SCENE_PATH`（`port_stage.tscn`）懒加载，`PORT_STAGE_FACILITY_SCREENS` 映射设施→页面（exchange→market / contracts / supply / intel / shipyard）；`_overview_stage_mode` 是 UI 会话状态，不写存档。
- 舞台宿主 `_port_stage_host` 为全窗 `SNStageHost`，放在 `Background` 之上、所有 UI 之下；2D 热点层 `_port_hotspot_layer` 放在 `PageMargin` 之后，层本身 `MOUSE_FILTER_IGNORE`，只有热点按钮吃点击。
- `_sync_port_stage(data)` 只在有 run、非在航、当前页为 overview、`_overview_stage_mode` 且场景可用时显示；菜单/无 run/通关/在航/错误分支在 `_rebuild_ui()` 里由 `_hide_port_stage()` 隐藏并清空热点。
- `_port_stage_payload(data)` 从 `current_port` 组装 `port.{id,size,facilities,banner_path}`，可选透传 `facility_visuals/palette/landmark_path`，ship 只传 `hull_model_path/hull_tier`；`_port_banner_path()` 统一解析 `asset://<mod>/<banner_asset>`（替代原来内联在 `_overview_model` 的解析）。
- 热点用 `facility_anchors()` → `facility_screen_anchor()` 投影成 136×36 的 `SNGhostButton`，按钮中心落在投影点；`_refresh_port_hotspots_soon()` 做两次 deferred 布局（等容器重排与 SubViewport 尺寸），视口 size_changed 时重排。
- 加载失败 `_on_port_stage_fallback(reason)`：置 `_port_stage_load_failed`（本会话不再重试）、退出 stage 模式、回退 2D、写状态提示 `ui.error.port_stage_unavailable` 并 deferred refresh。
- 总览页在 stage 模式下只保留「返回总览」控制行 + expanding spacer，让全窗 3D 舞台露出；顶部 HUD/导航/状态条仍在页面外，不随切换重建。

## 重点逻辑

### `_sync_port_stage(data) / _ensure_port_stage_host()`

- 显示条件 = `has_run && !at_sea && _active_screen == "overview" && _overview_stage_mode && 场景存在`；宿主首次懒创建（全窗锚定、先隐藏），随后 `load_stage(PORT_STAGE_SCENE_PATH)` → `bind_view_model(_port_stage_payload(data))` → `set_stage_visible(true)`，并把热点层置可见。
- 宿主与热点层的层级通过 `move_child(..., $Background.get_index() + 1)` / `(..., $PageMargin.get_index() + 1)` 固定：3D 在背景之上、2D UI 之下；热点层在页面之后，透明区域点击落回页面。

### `_layout_port_hotspots() / _on_port_hotspot(facility)`

- 每次重排先清空旧按钮；只对 `facility_anchors()` 中设施生成热点，投影返回 `ZERO` 的跳过；按钮尺寸 136×36，位置为 `normalized × 层尺寸 - size/2`。
- 点击热点查 `PORT_STAGE_FACILITY_SCREENS` 得到 screen id 后走 `_on_nav`，与顶部导航共用同一条页面切换路径；未知设施直接 return。

模块索引：[framework/ui](../README.md)
