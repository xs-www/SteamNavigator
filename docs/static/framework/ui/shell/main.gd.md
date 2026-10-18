# `framework/ui/shell/main.gd`

> 作用：可玩 UI 外壳：共享 Theme 的主菜单、总览/市场/委托/船厂/补给/情报/出航、抵达结算、海图与诊断。

- 类型：GDScript 源文件

## 契约与约束

- 所有数据经 QueryBus 获取，所有修改经 CommandBus；UI 不保存规则状态。
- 每个功能有独立界面，通过顶部导航切换；面板分别构建完整 ViewModel，不把所有信息挤在同一滚动页。
- 每轮命令后整页重建；选项/目的地/构筑选择保存在 UI 成员。
- 每个 PanelContainer 只允许一个 VBoxContainer 内容容器；面板子节点必须经 `_panel_add()` 添加，避免多子节点互相重叠。
- 海图点击已访问港口：当前港跳转市场，远程港打开只读港口记忆。
- 海图航路使用三次贝塞尔曲线，叠加经纬网、洋流、罗盘和图内图例；当前港带脉冲光晕，未知港只保留低调轮廓。
- 启动主菜单使用全屏港口背景；进入游戏后保留顶部导航，并用共享 Theme 的徽标/章节标题/资源条构建信息层级。
- 总览港口横幅通过 Core manifest 的 `banner.port.*` 资产键与 `banner_asset` 字段解析；无横幅港口退回普通面板。
- 市场页显示 buyable 与持仓均价；仅收购品种不显示买入按钮，并用真实 price_history 绘制迷你折线。
- 委托页使用两列卡片和“可接/进行中”分区；固定结构含目的地、剩余期限、载重、预计航程、说明与声望。
- 补给页使用 SNSupplyCard 展示煤水存量、可补上限、港存、续航和补满花费；页面只发 command_requested。
- 补给页显示市场煤水价、港口库存、载重余量、可买上限和维修报价，按钮直接派发 supply.* 命令。
- 抵达后进入只读结算页，显示委托收入、准时、延误、煤水/耐久与交付明细。
- 交易、委托接取和补给购买成功后播放 pickup_gold_00.wav。
- 无存档时进入主菜单：开始游戏进入新航程配置，加载游戏读取 autosave，模组页只读展示本次加载结果，设置可切换语言与自动存档，退出直接关闭。
- 设置写入 `user://config/config.json`，默认值来自 `config/config.json`；首次加载会创建用户配置。
- 右下角固定显示开发团队与游戏版本；版本来自 `application/config/version`。
- 页面切换使用全屏 TransitionLayer：旧页淡出、重建、新页淡入；数据刷新不播放转场。
- 新航程主操作使用 `SNPrimaryButton`，返回使用 ghost；章节标题控件只声明语义标签（SNEyebrowLabel/SNTitleLabel/SNDetailLabel）。
- 加载游戏读取 autosave 并做模组兼容性校验。
- 根控件加载共享 `steam_navigator_theme.tres`；页面可继续局部覆写，但不再在运行时拼装全局 Theme。

模块索引：[framework/ui](../README.md)
