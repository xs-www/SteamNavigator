# Nine-Slice Textures

运行期的控件九宫格纹理已由控件图集切出，位于 **`assets/ui/skin/sn_v1/nine_slice/`**（生成物，勿手改）：

- 按钮六态：`button_normal` / `button_hover` / `button_pressed` / `button_selected` / `button_disabled` / `button_danger`
- 面板：`panel_steel` / `panel_recess` / `panel_parchment` / `panel_blueprint` / `panel_canvas` / `frame_open`
- 输入与列表：`input_recess` / `list_parchment`
- 仪表：`meter_trough`、`meter_fill_amber/aqua/sage/rust`；常规 `progress_trough`、`fill_amber/aqua/sage/rust`
- 布旗（V1 未接入布局）：`flag_teal/blue/cream/red/disabled/selected`
- 派生小件：`badge` / `badge_danger` / `scrollbar_track` / `scrollbar_grabber` / `focus_ring`

规格与九宫格边距以 `assets/ui/skin/sn_v1/skin.json` 的 `texture_margin` / `content_margin` 为准；规范见 [UI_FOUNDATION_SPEC_V1.md](../../../docs/design/UI_FOUNDATION_SPEC_V1.md) §5。

## 约定

- 角件/铆钉/挂环/纸夹/蜡封属于不可拉伸区（`texture_margin` 内）。
- 中心拉伸区不得包含明显噪点、文字或可识别图案。
- 源图集在 `docs/design/ui_controls_v1/sn_controls_atlas_v1.png` + `regions.json`；更新后跑 `pwsh ./tools/build_ui_skin.ps1`。
- 同位置换图必须保持画布尺寸与角件比例；改边距必须重新生成 Theme。
