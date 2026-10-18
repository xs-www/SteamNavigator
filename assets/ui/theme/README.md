# UI Theme

运行时文件：`assets/ui/theme/steam_navigator_theme.tres`

## 来源

- `assets/ui/tokens.json`：颜色、字号、间距、动效时长。
- `.design/styles.css`：按钮、Panel、Tab、Tooltip 的视觉参考。

## 已落地映射

| Token | Godot |
| --- | --- |
| `color.abyss_950` | `Window`/背景 |
| `color.petrol_900/800` | `PanelContainer`、`Button` |
| `color.brass_500/300` | 标题、active tab、强调 |
| `color.paper_200` | 正文 |
| `color.rust_500` | 危险/亏损 |
| `color.success_500` | 成功/利润 |
| `type.display/title` | Noto Serif SC（未随包时回退系统字体） |
| `type.body/caption` | Noto Sans SC |
| `space.*` | 容器 separation / content margin |
| `motion_ms.*` | Tween 时长 |
| `nine_slice.corner_px` | StyleBox 圆角/九宫格角区 |

## Theme variations

- 按钮：`SNPrimaryButton`、`SNSecondaryButton`、`SNDangerButton`、`SNGhostButton`
- 面板：`SNPanel`、`SNElevatedPanel`、`SNInsetPanel`
- 徽标：`SNBadge`、`SNSuccessBadge`、`SNWarningBadge`、`SNDangerBadge`
- 标签：`SNEyebrowLabel`、`SNTitleLabel`、`SNDetailLabel`
- 存量条：`SNBrassProgressBar`、`SNWaterProgressBar`、`SNDangerProgressBar`

配套控件位于 `framework/ui/components/`，展示场景为 `framework/ui/showcase/ui_kit_showcase.tscn`。主界面已直接加载该 Theme；领域逻辑未改动。
