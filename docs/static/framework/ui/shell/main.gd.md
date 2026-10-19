# `framework/ui/shell/main.gd`

> 作用：可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并把已迁移页面挂载到场景宿主。

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

模块索引：[framework/ui](../README.md)
