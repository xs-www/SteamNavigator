# `assets/ui/theme/steam_navigator_theme.tres`

> 作用：全局 Godot Theme：把深青、黄铜、纸色令牌映射为基础控件与语义变体。

- 类型：Godot 资源

## 契约与约束

- 基础类型覆盖 Button、PanelContainer、LineEdit、OptionButton、ProgressBar 与容器间距。
- 自定义 variation 包含按钮/面板/徽标/标签/进度条；删除或改名时必须同步控件脚本。
- 字体使用 SystemFont 回退链，不把本机字体文件写入资源。
- `SNBlueprintPanel`（`base_type = PanelContainer`，stylebox id `BlueprintPanel`）是船厂改装态左列的九宫格蓝图底板：`StyleBoxTexture` 引用 `assets/ui/shipyard/blueprint_panel.png`（841×299，即 `docs/design/ui_controls_v1/blueprint_panel/layout.json` 取图区域 1682×598 的 0.5 倍派生副本），`texture_margin_*` = 56/54，`content_margin_*` = 66/62；改纹理尺寸必须同步这四组边距，否则角件会拉伸、安全区会错位。母版（1860×846）保留在 `docs/design/ui_controls_v1/blueprint_panel/`，不要直接缩放整张母版当运行纹理。
- `SNGlassPanel`（`base_type = PanelContainer`，stylebox id `GlassPanel`）是画在 3D 港区舞台上的半透明操作坞：深青底 alpha 0.66 + 1 px 黄铜描边、圆角 10、内容边距 14/12。船厂改装态右侧 dock 使用；与 `SNInsetPanel` 的区别是更低不透明度（让 3D 场景透出），不要把它用在不透明钢板容器上。
