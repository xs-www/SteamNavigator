# UI Theme

运行时文件：`assets/ui/theme/steam_navigator_theme.tres`（**生成物，禁止手改**）

## 来源

- `assets/ui/skin/sn_v1/skin.json`：样式/九宫格边距/颜色/字号/图标表，唯一数据源。
- `tools/ui/build_ui_theme.gd`：skin.json → Theme 的映射（按钮/面板/徽标/输入/进度/滚动条/Tab/Tooltip）。
- 视觉规范：`docs/design/UI_VISUAL_BASELINE.md`、`docs/design/UI_FOUNDATION_SPEC_V1.md`。

## 生成

```powershell
pwsh ./tools/build_ui_skin.ps1          # 同时重生成运行纹理、skin.json 与 Theme
pwsh ./tools/build_ui_skin.ps1 -Check   # 提交前门禁
```

## Theme variations

- 按钮：`SNPrimaryButton`、`SNSecondaryButton`、`SNDangerButton`、`SNGhostButton`、`SNCompactButton`、`SNPlateButton`
- 面板：`SNPanel`、`SNElevatedPanel`、`SNInsetPanel`、`SNGlassPanel`、`SNChromePanel`、`SNStatusBarPanel`、`SNParchmentPanel`、`SNBlueprintSheetPanel`、`SNCanvasPanel`、`SNBlueprintPanel`
- 徽标：`SNBadge`、`SNSuccessBadge`、`SNWarningBadge`、`SNDangerBadge`
- 标签：`SNTitleLabel`（衬线）、`SNEyebrowLabel`、`SNDetailLabel`
- 进度：`SNBrassProgressBar`、`SNWaterProgressBar`、`SNDangerProgressBar`

状态→纹理映射与尺寸预算见 [docs/design/UI_SKIN_PIPELINE.md](../../../docs/design/UI_SKIN_PIPELINE.md)。配套控件位于 `framework/ui/components/`，皮肤运行时访问层为 `framework/ui/skin/sn_skin.gd`（SNSkin），展示场景为 `framework/ui/showcase/ui_kit_showcase.tscn`。
