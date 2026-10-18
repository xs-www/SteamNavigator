# `framework/ui/shell/main.gd`

> 作用：可玩 UI 外壳：总览/市场/委托/船厂/情报/出航六个独立界面，以及海图、事件选择与诊断。

- 类型：GDScript 源文件

## 契约与约束

- 所有数据经 QueryBus 获取，所有修改经 CommandBus；UI 不保存规则状态。
- 每个功能有独立界面，通过顶部导航切换；面板分别构建完整 ViewModel，不把所有信息挤在同一滚动页。
- 每轮命令后整页重建；选项/目的地/构筑选择保存在 UI 成员。
- 每个 PanelContainer 只允许一个 VBoxContainer 内容容器；面板子节点必须经 `_panel_add()` 添加，避免多子节点互相重叠。
- 海图点击已访问港口：当前港跳转市场，远程港打开只读港口记忆。
- 市场页显示 buyable 与持仓均价；仅收购品种的买入按钮禁用。
- 事件面板只展示本次抽样出的 2 个选项。
- Continue 读取 autosave 并做模组兼容性校验。

模块索引：[framework/ui](../README.md)
