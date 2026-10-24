# `tools/ui/build_ui_theme.gd`

> 作用：从 `assets/ui/skin/<skin>/skin.json` 生成 `assets/ui/theme/steam_navigator_theme.tres`。Theme 里的每个可见状态都是一张外部 PNG（StyleBoxTexture 九宫格）或外部图标，因此换掉 skin 目录里的同名同尺寸贴图即可整体换肤；本脚本只在换整套皮肤/改九宫格参数时重新运行。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `DEFAULT_SKIN` | L25 |
| `SKIN_ROOT` | L26 |
| `THEME_PATH` | L27 |
| `CHECK_PATH` | L28 |
| `THEME_UID` | L29 |
| `BLUEPRINT_PANEL_PATH` | L30 |
| `FONT_SANS` | L32 |
| `FONT_SERIF` | L33 |
| `_init() -> void` | L47 |

## 用法
```powershell
godot --headless --path . --script res://tools/ui/build_ui_theme.gd -- [--skin=sn_v1] [--check]
```
- 默认读取 `res://assets/ui/skin/sn_v1/skin.json`，写 `res://assets/ui/theme/steam_navigator_theme.tres`。
- `--check`：生成到 `user://ui_theme_check/` 并与已提交 Theme 逐字节比对，不覆盖；有差异退出码 1。

## 主题映射（唯一来源，改映射必须同步改本文件与 SNSkin 文档）
- Button：normal/hover/pressed/disabled + focus 环；Primary=selected/hover/pressed，Danger=button_danger 提亮 hover，Ghost=空底 + 半透明底纹 hover。
- Panel：Panel/PanelContainer/SNPanel/SNElevatedPanel=panel_steel（modulate 区分层级），SNInsetPanel=panel_recess，SNGlassPanel=panel_steel α0.62，SNParchmentPanel=panel_parchment，SNBlueprintSheetPanel=panel_blueprint，SNCanvasPanel=panel_canvas，SNBlueprintPanel=既有 blueprint_panel 九宫格（56/54 边距、66/62 安全区）。
- ProgressBar：meter_trough + meter_fill_amber/aqua/rust（低边距版本，适配 14px 高资源条）。
- Badge：badge/badge_danger + tone 染色；Input：input_recess；ScrollBar：scrollbar_track/grabber；CheckBox：check_* 图标；Tooltip/Popup/Tab 用 steel/recess/button 纹理。
- 颜色与字号全部来自 skin.json 的 colors/fonts（对应 UI_FOUNDATION_SPEC_V1 §6/§7），不在 Theme 里另写业务色值。

## 约束
- `[gd_resource]` 保留既有 uid `uid://donrdopu47413`（main.tscn 按 uid 引用）；不要手改生成物。
- StyleBox 的内容边距与 skin.json `content_margin` 一致；新增变体必须同时更新 UI_FOUNDATION_SPEC_V1 的组件清单。
- 生成必须确定性：ext/sub 资源按固定顺序编号，输出无时间戳。

模块索引：[tools](../README.md)
