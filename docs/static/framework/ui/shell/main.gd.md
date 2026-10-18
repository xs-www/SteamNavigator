# `framework/ui/shell/main.gd`

> 作用：最小可玩 UI：菜单、状态栏、海图、市场、委托、船只、船厂、情报、出航预览与事件选择。

- 类型：GDScript 源文件

## 契约与约束

- 所有数据经 QueryBus 获取，所有修改经 CommandBus；UI 不保存规则状态。
- 每轮命令后整页重建；选项/目的地/构筑选择保存在 UI 成员。
- 每个 PanelContainer 只允许一个 VBoxContainer 内容容器；面板子节点必须经 `_panel_add()` 添加，避免多子节点互相重叠。
- 事件面板只展示本次抽样出的 2 个选项。
- Continue 读取 autosave 并做模组兼容性校验。

模块索引：[framework/ui](../README.md)
