# `framework/ui/shell/main.gd`

> 作用：可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并挂载已场景化的菜单/港口/流程页。主界面是「全窗 3D 港口舞台 + 紧凑顶部 chrome + 两侧设施招牌 + 底部状态条 + 详细总览抽屉」的分层外壳；Shell 只保留上下文解析、ViewModel 组合、会话导航状态与命令派发。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI_THEME` | L57 |
| `HARBOR_SIGN_SCRIPT` | L59 |
| `MARKET_SCREEN_SCENE` | L60 |
| `CONTRACTS_SCREEN_SCENE` | L61 |
| `SUPPLY_SCREEN_SCENE` | L62 |
| `INTEL_SCREEN_SCENE` | L63 |
| `OVERVIEW_SCREEN_SCENE` | L64 |
| `SHIPYARD_SCREEN_SCENE` | L65 |
| `BASE_SCREEN_SCENE` | L66 |
| `AUTO_TRADE_SCREEN_SCENE` | L67 |
| `RUINS_SCREEN_SCENE` | L68 |
| `PORT_MEMORY_SCREEN_SCENE` | L69 |
| `SETTLEMENT_SCREEN_SCENE` | L70 |
| `AT_SEA_SCREEN_SCENE` | L71 |
| `EVENT_SCREEN_SCENE` | L72 |
| `SEA_CHART_SCREEN_SCENE` | L73 |
| `CLUE_LOG_SCREEN_SCENE` | L74 |
| `STORY_CARD_SCRIPT` | L75 |
| `STORY_OBJECTIVE_SCRIPT` | L76 |
| `TASK_TRACKER_SCRIPT` | L77 |
| `VICTORY_SCREEN_SCENE` | L78 |
| `MAIN_MENU_SCREEN_SCENE` | L79 |
| `NEW_GAME_SCREEN_SCENE` | L80 |
| `MODS_SCREEN_SCENE` | L81 |
| `SETTINGS_SCREEN_SCENE` | L82 |
| `NAV_ICONS` | L85 |
| `NAV_ICON_MAX_WIDTH` | L96 |
| `DEV_TEAM` | L97 |
| `GAME_VERSION_FALLBACK` | L98 |
| `SCREENS` | L102 |
| `PORT_STAGE_SCENE_PATH` | L105 |
| `PORT_STAGE_FACILITY_SCREENS` | L107 |
| `STAGE_SCREENS` | L120 |
| `DOCK_PANEL_WIDTH` | L129 |
| `TOP_CHROME_MAX_HEIGHT` | L133 |
| `PORT_STATUS_BAR_HEIGHT` | L135 |
| `PORT_STATUS_BAR_GAP` | L136 |
| `PORT_SIGN_WIDTH` | L139 |
| `PORT_SIGN_HEIGHT` | L140 |
| `PORT_SIGN_GAP` | L141 |
| `PORT_SIGN_MARGIN` | L142 |
| `HUD_ICON_KEYS` | L146 |
| `HUD_SKIN_ICONS` | L157 |
| `HUD_ICON_SIZE` | L167 |
| `PAGE_BOTTOM_MARGIN` | L170 |
| `PAGE_BOTTOM_MARGIN_WITH_BAR` | L171 |

## 皮肤接线（ui-skin-v1）
- 所有纹理/图标/颜色经 `SNSkin`（`framework/ui/skin/sn_skin.gd`）读取 `assets/ui/skin/sn_v1/skin.json`；
  本文件不写贴图路径、不写十六进制颜色，也不再手写 StyleBoxFlat。
- 顶栏 `_chrome_style()` = `SNSkin.panel("chrome")`（半透明钢框、content 16/12）；底部状态条
  `_bottom_bar_style()` = `SNSkin.panel("status_bar")`（content 14/6）。皮肤缺失时退回 Theme 的
  `SNChromePanel` / `SNStatusBarPanel` 变体，文字与交互不丢。
- 导航/小按钮走 Theme 变体：当前页 `SNPrimaryButton`，其余 `SNCompactButton`；图标来自
  `SNSkin.icon()`（`button.icon` + `icon_max_width = 18`），正文仍由 Theme 绘制，`text` 保持原样供测试精确查找。
- HUD chip 图标：内容包 `icon.*` 资产优先（`AssetService.find_key/load_texture`），缺失时按
  `HUD_SKIN_ICONS` 回退到皮肤图标；两者都没有时只显示文字。
- 边缘设施招牌交给 `SNHarborSign`（纹理化 Button）；Shell 只负责 `facilities → 页面` 的布局与导航。

## 尺寸预算
- `TOP_CHROME_MAX_HEIGHT = 130`：两行 chrome（品牌/状态/时间·金钱·声望 + 资源 chip/导航）实测最小高度必须 ≤130；
  3D 舞台是主视图，HUD 只做画框。
- `PORT_STATUS_BAR_HEIGHT = 60`：总览底部状态条固定高度，chip 字号 10/15、按钮 32 高，不得裁内容。
- 招牌 `172×42`、右列固定「海图 ▶」入口；`PageMargin` 底部为页脚/状态条预留 56/84。

## 契约
- 数据只走 QueryBus，修改只走 CommandBus；UI 会话状态不写存档。
- `SCREENS` / `STAGE_SCREENS` / `PORT_STAGE_FACILITY_SCREENS` 是导航契约，换皮不得改动键名或命令路径。
- 每个 PanelContainer 只允许一个 VBox 内容容器（`_panel_add()`）；页面场景只发意图，不持有 AppContext。

模块索引：[framework/ui](../README.md)
