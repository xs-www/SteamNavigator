# `framework/tests/cases/test_ui_shell.gd`

> 作用：迭代 2 主界面接线测试：把真实外壳场景挂进场景树，断言六条反馈在界面构建路径上真的生效，并守护通报文案的本地化；另覆盖 Bounty Train 式主界面（默认 3D 舞台 + 紧凑顶部 HUD + 资源图标 + 主题化两侧招牌 + 底部状态条 + 详细总览抽屉 + 2D 回退）、连续港区三站位的页面接线（overview/market/supply 共用同一舞台实例、镜头与船移动、右侧泊位面板），以及 960 窄布局 helper。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L9 |
| `METER_SCRIPT` | L10 |
| `CARD_SCRIPT` | L11 |
| `INTEL_TABLE_SCRIPT` | L12 |
| `MARKET_SCREEN_SCRIPT` | L14 |
| `CONTRACTS_SCREEN_SCRIPT` | L15 |
| `TAVERN_SCREEN_SCRIPT` | L16 |
| `OVERVIEW_SCREEN_SCRIPT` | L17 |
| `SHIPYARD_SCREEN_SCRIPT` | L18 |
| `PORT_MEMORY_SCREEN_SCRIPT` | L19 |
| `SETTLEMENT_SCREEN_SCRIPT` | L20 |
| `AT_SEA_SCREEN_SCRIPT` | L21 |
| `EVENT_SCREEN_SCRIPT` | L22 |
| `SEA_CHART_SCREEN_SCRIPT` | L23 |
| `VICTORY_SCREEN_SCRIPT` | L24 |
| `MAIN_MENU_SCREEN_SCRIPT` | L25 |
| `NEW_GAME_SCREEN_SCRIPT` | L26 |
| `MODS_SCREEN_SCRIPT` | L27 |
| `SETTINGS_SCREEN_SCRIPT` | L28 |
| `STEADY_BUILD` | L29 |
| `LITERAL_EXPECTED_NOTICE_KEYS` | L35 |
| `test_dense_screen_fields_keep_horizontal_minimum_widths() -> void` | L169 |
| `test_damaged_module_is_visible_in_the_shell() -> void` | L205 |
| `test_stats_bar_shows_the_current_port_and_remaining_capacity() -> void` | L224 |
| `test_victory_plan_explains_how_to_clear_the_mvp() -> void` | L293 |
| `test_shipyard_order_and_port_wait_make_time_move() -> void` | L339 |
| `test_market_supply_block_paints_the_lost_capacity_band() -> void` | L389 |
| `test_tavern_screen_renders_price_intel_and_port_clues() -> void` | L420 |
| `test_notice_log_renders_filled_localized_text() -> void` | L476 |
| `test_every_pushed_notice_key_is_localized_in_both_languages() -> void` | L534 |
| `test_overview_defaults_to_the_3d_port_stage_with_compact_chrome() -> void` | L567 |
| `test_overview_stage_falls_back_to_the_usable_2d_overview() -> void` | L775 |
| `test_overview_status_strip_and_detail_drawer() -> void` | L795 |
| `test_sea_chart_entry_integration() -> void` | L875 |
| `test_sea_chart_buys_an_intel_clue_from_the_panel() -> void` | L968 |

## 契约与约束

- 首帧运行器让 `_ready` 正常投递，因此控件树（含 SNSectionHeader 等自行构建子节点的组件）与游戏内一致。
- 覆盖信息条（当前港口 + 剩余载重/剩余舱容，反馈 5）、通关清单与两种提示分支（反馈 6）；期望值独立复算（RegistryHub 翻译 + ShipOps 重量/舱容 + printf），不使用被测 helper 自证。通关清单只在总览页渲染：船厂页断言不再出现 `ui.victory.plan_title`，改为出现「组件」分类入口。
- 模块损耗可见性：健康船信息条不出现「部件」chip；对锅炉实例造成 50% 损耗后刷新，信息条出现「部件」chip 与「1 · 50%」，船厂船卡出现「受损部件」行与同一数值（期望文案来自 shell._tr 与实例状态，不用 UI helper 自证）。
- 覆盖船厂下单按钮 → CraftOps 订单 → 在港等待按钮 → 时间推进与成品入下单港仓库（反馈 4，经由真实按钮 pressed 信号）；打造入口在改装态模块分类内，下单后重建的页面必须保持改装态与分类，24 小时等待按钮在「杂项」页签。
- 场景接线断言覆盖独立总览、市场、委托、船厂、补给、情报、海图页面及四个菜单页面；船厂流程从 ShipyardScreen 的真实按钮驱动。
- 流程场景接线覆盖港口记忆、抵达结算、航行中、航行事件与通关总结，逐一调用 Shell 构建入口并按脚本类型断言实例。
- 依赖详细总览面板的旧用例（信息条、通关清单、航行记录）先在 `_overview_detail = true` 下 `_refresh()`，因为默认主视图是裸 3D 舞台；其余断言不改。
- 覆盖设置/总览/市场/船厂/港口记忆密集字段禁用自动换行、市场与快照单元格最小宽度，以及情报矩阵固定元数据列、可扩展港口列、最小列宽和深色单元格背景。
- 覆盖补给页损失带：买煤后水的 meter.loss_value/cap_loss 与 baseline 跨度（反馈 2）、情报页 SNIntelTable 与未知港口掩码（反馈 3，列数对照 MapOps.ports）。
- 覆盖「航行记录」：真实下单 + 等待后在 zh 与 en 两种 locale 下逐行断言通报无 `%s/%d` 残留、无裸键，并与**逐语言写死的期望句子**相等（模板槽位互换照样能渲染，只有字面期望能抓住「某一种语言的文案说反了」；en 只写错顺序时该用例会失败）。
- 扫描 domain/application 源码里所有 `push_notice("…")` 字面量：每个键在 framework 或 core 的 zh_CN/en 中恰好被一套定义，两套 locale 的键集合与**保序**槽位序列一致；槽位多于一个的键必须出现在用例的逐语言字面期望清单里。
- 组件按路径 preload，不依赖编辑器全局类缓存。
- `test_overview_defaults_to_the_3d_port_stage_with_compact_chrome`：seed 5205 切总览后断言 `_overview_stage_mode` 默认 true、`PortStage` 已挂载且设施数 = port.view；`_top_chrome` 最小高度 ≤130 px，且港口/金钱/声望/剩余载重/货舱/耐久/煤/水 chip 与 6 个导航按钮 + 海图切换、诊断/刷新按钮全部保留（4.3.4/U7 删除出航导航页）。
- HUD 图标：`AssetService.find_key("icon.money")` / coal / water 均能解析且 `has()` 为真；chrome 里至少 3 个 `TextureRect` 且每个都有已加载纹理（缺资产时页面应退化为纯文字，不产生空纹理节点）。
- 窗口缩放说明：`canvas_items + expand` 把 960×540 窗口映射为缩放后的 1600×900 逻辑画布，因此 chrome 保留全部 chip（含剩余载重/货舱），不设 compact 分支；960×540 验收截图是这条布局的证据。
- 招牌组件：present 设施的 Button 必须 `has_method("configure")`（SNHarborSign）、`custom_minimum_size == 172×42`，`arrow_direction` 与投影左右列一致（左列 -1、右列 1）；文字仍以 `设施 ▶` / `◀ 设施` 结尾/开头。
- 同一用例断言两侧招牌：投影 x<0.5 进左列（文字 `设施 ▶`）、≥0.5 进右列（`◀ 设施`），数量 = 设施数 + 1（`Hotspot_sea_chart` 固定在右下，4.3.4 起替代出航招牌）；1280×720 重排后数量不丢不重；点 exchange 招牌进入 market。
- 连续港区页面接线：切到 market 后宿主的 `PortStage` 实例不变（`host.current_stage()` 与切页前同一节点）、舞台保持可见、`_stage_station==market`/`_stage_framing==panel`、`PortStage.current_station()==market`；`_root_box` 下出现 `DockPanelRow` 与 ≥640 px 的 `DockPanel`，页面脚本仍恰好一个实例。headless 不推进帧，用例直接 `port_stage.advance_station()` 断言镜头落到 `station_camera_pose(market, panel)`、船落到 market 泊位。
- 切到 supply 后仍是同一舞台实例，船从 market 泊位沿岸向东航行到 supply 泊位（两泊位相距 >40 m）；切到 contracts 等非舞台页时宿主隐藏；回到 overview 时舞台恢复并回到 harbor 站位。
- `test_overview_stage_falls_back_to_the_usable_2d_overview`：调 `_on_port_stage_fallback` 后 `_port_stage_load_failed` 记忆、stage 模式关闭、2D 地图挂载、显示 `ui.error.port_stage_unavailable`、导航仍可用。
- `test_overview_status_strip_and_detail_drawer`：底部状态条可见且最小高度 ≤72，含耐久/货舱/受损/最新通告与「详细总览/出航/等待 12 小时」；打开抽屉后地图与 `ui.victory.plan_title` 出现、舞台未销毁、backdrop 显示、招牌隐藏；返回主界面后抽屉关闭；点等待按钮让 `GameState.now()` +12 h；切到 intel 时状态条隐藏、返回总览恢复、点出航进入 voyage 页。

模块索引：[framework/tests](../README.md)
