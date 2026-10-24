# `framework/ui/shell/main.gd`

> 作用：可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并挂载已场景化的菜单/港口/流程页。主界面是「全窗 3D 港口舞台 + 紧凑顶部 chrome + 两侧设施招牌 + 底部状态条 + 详细总览抽屉」的分层外壳；Shell 只保留上下文解析、ViewModel 组合、会话导航状态与命令派发。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI_THEME` | L69 |
| `HARBOR_SIGN_SCRIPT` | L71 |
| `MARKET_SCREEN_SCENE` | L72 |
| `CARGO_HOLD_PANEL_SCRIPT` | L74 |
| `ITEM_FALLBACK_ICON` | L76 |
| `CONTRACTS_SCREEN_SCENE` | L77 |
| `SUPPLY_SCREEN_SCENE` | L78 |
| `INTEL_SCREEN_SCENE` | L79 |
| `OVERVIEW_SCREEN_SCENE` | L80 |
| `SHIPYARD_SCREEN_SCENE` | L81 |
| `BASE_SCREEN_SCENE` | L82 |
| `AUTO_TRADE_SCREEN_SCENE` | L83 |
| `RUINS_SCREEN_SCENE` | L84 |
| `PORT_MEMORY_SCREEN_SCENE` | L85 |
| `SETTLEMENT_SCREEN_SCENE` | L86 |
| `AT_SEA_SCREEN_SCENE` | L87 |
| `EVENT_SCREEN_SCENE` | L88 |
| `SEA_CHART_SCREEN_SCENE` | L89 |
| `CLUE_LOG_SCREEN_SCENE` | L90 |
| `STORY_CARD_SCRIPT` | L91 |
| `STORY_OBJECTIVE_SCRIPT` | L92 |
| `TASK_TRACKER_SCRIPT` | L93 |
| `VICTORY_SCREEN_SCENE` | L94 |
| `MAIN_MENU_SCREEN_SCENE` | L95 |
| `NEW_GAME_SCREEN_SCENE` | L96 |
| `MODS_SCREEN_SCENE` | L97 |
| `SETTINGS_SCREEN_SCENE` | L98 |
| `NAV_ICONS` | L101 |
| `NAV_ICON_MAX_WIDTH` | L112 |
| `DEV_TEAM` | L113 |
| `GAME_VERSION_FALLBACK` | L114 |
| `SCREENS` | L118 |
| `PORT_STAGE_SCENE_PATH` | L121 |
| `PORT_STAGE_FACILITY_SCREENS` | L123 |
| `STAGE_SCREENS` | L136 |
| `DOCK_PANEL_WIDTH` | L145 |
| `CARGO_HOLD_PANEL_WIDTH` | L147 |
| `MARKET_COLUMN_GAP` | L149 |
| `TOP_CHROME_MAX_HEIGHT` | L153 |
| `PORT_STATUS_BAR_HEIGHT` | L155 |
| `PORT_STATUS_BAR_GAP` | L156 |
| `PORT_SIGN_WIDTH` | L159 |
| `PORT_SIGN_HEIGHT` | L160 |
| `PORT_SIGN_GAP` | L161 |
| `PORT_SIGN_MARGIN` | L162 |
| `HUD_ICON_KEYS` | L166 |
| `HUD_SKIN_ICONS` | L177 |
| `HUD_ICON_SIZE` | L187 |
| `PAGE_BOTTOM_MARGIN` | L190 |
| `PAGE_BOTTOM_MARGIN_WITH_BAR` | L191 |

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

## 市场页（图标直接交易，`docs/design/MARKET_UI_REFACTOR.md`）
- `_screen_market()` 先执行 `market.view`；查询不可用时回退用 `port.view` 的行情 / 船摘要
  组装同名字段的 ViewModel，页面不崩。
- 每个行情 / 船舱 / 仓库行的 `icon_key` 由 Shell 经 `AssetService.find_key` →
  `AssetService.load_texture` 解析成 `Texture2D`（实例内缓存）；缺失时回退
  `assets/ui/icons/item_fallback.svg`，再缺失回退框架占位贴图。
- 舞台可用时挂三栏 `DockPanelRow`：`CargoHoldPanel`(360) + 透明 `StageWindow`
  (expand, `MOUSE_FILTER_IGNORE`, 只露出 3D 港区) + `DockPanel`(640)；舞台不可用时
  退化成 `CargoHoldPanel` + 市场面板两栏，不出现空白舞台窗口。
- 页面只发命令意图：`trade.buy{destination}` / `trade.sell{source}` /
  `warehouse.store_materials` / `warehouse.take_materials`。

模块索引：[framework/ui](../README.md)
