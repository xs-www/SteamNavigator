# `framework/ui/showcase/ui_kit_showcase.gd`

> 作用：皮肤验收展示页：在一个可滚动页面里集中展示纹理化 Theme 与 SNSkin 素材的全部可复用控件状态——按钮矩阵、面板材质、徽标、表单、资源条、进度条、九宫格拉伸对照、图标网格、parts 装饰、旗帜与 sparkline；供 1440×900 / 960×540 截图验收与视觉冒烟。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `COLUMNS_WIDE` | L36 |
| `COLUMNS_NARROW` | L37 |
| `WIDE_MIN_WIDTH` | L40 |
| `BUTTON_STATE_WIDE_WIDTH` | L42 |
| `BUTTON_STATES_WIDE` | L43 |
| `BUTTON_STATES_NARROW` | L44 |
| `SECTION_MIN_WIDTH` | L45 |
| `SECTION_SEPARATION` | L46 |
| `CELL_SEPARATION` | L47 |
| `ICON_SIZE` | L48 |
| `ICON_SECTION_SIZE` | L49 |
| `BUTTON_STATES` | L51 |
| `BUTTON_VARIANTS` | L53 |
| `PANEL_VARIANTS` | L60 |
| `BADGES` | L70 |
| `HUD_ICONS` | L77 |
| `SHIPYARD_ICONS` | L80 |
| `ACTION_STATUS_ICONS` | L84 |
| `NAV_ICONS` | L90 |
| `DECOR_PARTS` | L94 |
| `FLAGS` | L102 |

- 关键依赖：`assets/ui/theme/steam_navigator_theme.tres`、`SNSkin`（运行纹理/图标/颜色 token）、
  `sn_button/sn_panel/sn_badge/sn_section_header/sn_resource_meter/sn_sparkline` 场景，
  新增的 `sn_icon.gd` / `sn_nav_button.gd` 只在本页用 `preload()` 引用（避免依赖全局类缓存）。

## 契约与约束
- 不依赖 AppContext / Core 内容：可在编辑器与 headless 截图工具中独立实例化。
- 页面结构保持 `UIKitShowcase` → `Margin/Scroll` 骨架，场景只负责骨架，全部内容由脚本构建。
- 颜色统一 `SNSkin.color(token)`，不写十六进制；不新建 StyleBoxFlat。
- 状态演示只用 `add_theme_stylebox_override` 静态套用 SNSkin 纹理（hover/pressed/selected/focus 不需要
  真实鼠标），不把状态色写死在页面里。
- 内容区按 `Margin/Scroll` 可用宽度自适应 2/3 列，960×540 下只纵向滚动、不横向溢出。

## 重点逻辑
### `_build_showcase()`
- 先建全宽区段（页头、按钮矩阵、铭牌/导航、旗帜），再建自适应网格区段（面板、徽标、表单、资源条、
  九宫格、图标、parts、sparkline）。
### `_apply_columns()`
- 监听滚动容器尺寸：可用宽度 ≥ 1350 时区段网格用 3 列、否则 2 列；按钮状态行 ≥ 960 时 6 列、
  否则 3 列（两行）。两个阈值都来自实测最小宽度，保证窄窗只纵向滚动、不横向裁切。

模块索引：[framework/ui](../README.md)
