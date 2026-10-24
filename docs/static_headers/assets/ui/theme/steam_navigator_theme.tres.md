作用：全局 Godot Theme，由 `tools/ui/build_ui_theme.gd` 从 `assets/ui/skin/sn_v1/skin.json` 生成：所有控件状态都引用外部九宫格贴图（StyleBoxTexture）或外部图标，换同名同尺寸贴图即可整体换肤。

## 契约与约束

- **生成物，禁止手改**。改样式/边距 → 改 `tools/ui/build_ui_theme.gd`（映射）或 `skin.json`（素材参数）后运行 `pwsh ./tools/build_ui_skin.ps1`；改完必须 `-Check` 通过。
- 生成器保留既有 uid `uid://donrdopu47413`（`framework/ui/shell/main.tscn` 按 uid 引用），不要删。
- `[ext_resource]` 纹理全部指向 `res://assets/ui/skin/sn_v1/nine_slice|icons/*.png`；唯一例外是船厂 `SNBlueprintPanel` 的 `assets/ui/shipyard/blueprint_panel.png`。
- 基础类型覆盖 Button、Panel、PanelContainer、LineEdit、OptionButton、CheckBox、ProgressBar、V/HScrollBar、TooltipPanel/Label、TabBar/TabContainer、PopupPanel/PopupMenu、HSeparator/VSeparator；容器间距与字体/字号沿用旧值，避免换皮改变布局。
- 自定义 variation（改名/删除必须同步控件脚本与 `test_ui_skin.gd`）：
  - 按钮：`SNPrimaryButton`、`SNSecondaryButton`、`SNDangerButton`、`SNGhostButton`、`SNCompactButton`、`SNPlateButton`；
  - 面板：`SNPanel`、`SNElevatedPanel`、`SNInsetPanel`、`SNGlassPanel`、`SNChromePanel`、`SNStatusBarPanel`、`SNParchmentPanel`、`SNBlueprintSheetPanel`、`SNCanvasPanel`、`SNBlueprintPanel`；
  - 徽标：`SNBadge`、`SNSuccessBadge`、`SNWarningBadge`、`SNDangerBadge`；
  - 标签：`SNTitleLabel`（衬线）、`SNEyebrowLabel`、`SNDetailLabel`；
  - 进度：`SNBrassProgressBar`、`SNWaterProgressBar`、`SNDangerProgressBar`。
- `SNGhostButton` 五个状态的 content margin 必须一致（12/4），否则 hover/focus 会改变按钮最小尺寸（`test_sea_chart` 有回归守卫）。
- 字体使用 SystemFont 回退链，不把本机字体文件写入资源；`SNTitleLabel` 使用衬线回退链。
- `SNBlueprintPanel` 是船厂改装态左列的九宫格蓝图底板：`StyleBoxTexture` 引用 `assets/ui/shipyard/blueprint_panel.png`（841×299，即 `docs/design/ui_controls_v1/blueprint_panel/layout.json` 取图区域 1682×598 的 0.5 倍派生副本），`texture_margin_*` = 56/54，`content_margin_*` = 66/62；改纹理尺寸必须同步这四组边距。
- `SNGlassPanel`（alpha 0.62，content 14/12）用于 3D 舞台上的船厂操作坞；`SNChromePanel`（alpha 0.84，content 16/12）用于 TopChrome（≤130px 预算）；`SNStatusBarPanel`（alpha 0.90，content 14/6）用于底部 60px 状态条。
- 进度条使用低边距派生纹理 `meter_trough` + `meter_fill_*`（4–6px 九宫格），适配 10–14px 高资源条；不要换回 `progress_trough`（17/14 边距会压扁）。
- 颜色/字号 token 来自 `skin.json` 的 `colors`/`fonts`（对应 `UI_FOUNDATION_SPEC_V1.md` §6/§7），不在 Theme 里另写业务色值。
- 设计说明与换肤流程见 `docs/design/UI_SKIN_PIPELINE.md`。
