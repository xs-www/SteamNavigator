# `assets/ui/theme/steam_navigator_theme.tres`

> 作用：全局 Godot Theme：把深青、黄铜、纸色令牌映射为基础控件与语义变体。

- 类型：项目配置/数据文件

## 契约与约束

- 基础类型覆盖 Button、PanelContainer、LineEdit、OptionButton、ProgressBar 与容器间距。
- 自定义 variation 包含按钮/面板/徽标/标签/进度条；删除或改名时必须同步控件脚本。
- 字体使用 SystemFont 回退链，不把本机字体文件写入资源。
