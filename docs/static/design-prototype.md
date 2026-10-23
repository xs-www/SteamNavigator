# `.design` 美术与交互原型

> 作用：Steam Navigator 的本地美术方向与界面交互验证台。该目录按约定由 `.gitignore` 排除，不进入游戏构建、发行包或源码提交。

## 文件索引

| 文件 | 职责 |
| --- | --- |
| `.design/index.html` | 可点击的全流程界面原型，覆盖主菜单、港口、市场、委托、船厂、补给、情报、出航和抵达结算。 |
| `.design/styles.css` | 蒸汽朋克视觉系统、响应式布局、按钮/卡片/面板状态与环境动效。 |
| `.design/app.js` | 页面淡入淡出、轻量点击音效、交易反馈、委托盖章和出航结算演示。 |
| `.design/tokens.json` | 可映射至 Godot Theme 的颜色、字体、间距、9-slice 与动效令牌。 |
| `.design/assets/main-menu-harbor.png` | 主菜单蒸汽船与港口概念背景。 |
| `.design/assets/iron-harbor-banner.png` | 铁港港口页横幅概念图。 |

## Godot 落地

- `assets/ui/theme/steam_navigator_theme.tres` 是运行时共享 Theme。
- `framework/ui/components/` 提供可拖入场景的语义按钮、面板、徽标、章节标题和资源存量条。
- 船厂界面分成两态：正常态三列「已有船舶船卡 / `SNShipView` 实机渲染（面板内的 3D 船体舞台）/ 组件分类入口」。
- 改装态是独立的「船厂工作台」页面，画在连续港区的 3D 船厂站位上（镜头 = `STATIONS.shipyard`，干船坞 + 吊架 + 玩家船），不再有整页不透明背景。页面从左到右是：九宫格蓝图底板（侧视/俯视每船线稿 + 底部可拖放槽位贴片）→ 中间的 3D 窗口（露出场景与玩家船）→ 右侧半透明操作坞（`SNGlassPanel`）。
- 操作坞从上到下：舰船整体数据卡（船名 + 重量 / 耐久 / 货舱 / 客舱 / 武器 / 剩余货舱）、七项部件分类选择、`装配 / 购买 / 打造` 三个独立页签（购买与打造不再混在同一条滚动列表里），以及页签内容。`杂项` 不显示页签，直接展示打造订单 / 在港等待 / 仓库材料 / 仓库模块。
- 武器分类：装配页列出 `weapon_sockets` 并高亮蓝图武器框，购买页列出炮位候选；悬停候选仍蓝图标出目标槽位。装配页会把当前分类可安装的槽位贴片高亮成青色，拖拽仓库/随船部件即可安装或替换同槽位旧件。
- 改装态不再出现测试向文案（`改装蓝图` / `蓝图线稿` / `贴图剖面` / 实机渲染提示），金币与耐久只在顶栏与数据卡里出现；顶栏左侧的品牌位换成当前港口名。
- 改装态蓝图优先使用船体 `blueprint_views` 绑定的每船 side/top 线稿：`SNShipView` 同屏绘制侧视（上）与俯视（下），两视图共享显示宽度并按各自线稿等比矩形映射武器槽位框；交互槽位贴片停靠在蓝图下方的 dock 区，不遮挡顶视线稿。没有 `blueprint_views` 的船体回退到 `assets/ui/shipyard/ship_section.png`（cover 裁切）或程序化占位。
- 旧整页下方面板（打造订单 / 港口仓库 / 配方 / 可购买模块 / 通关清单）已删除，命令迁入改装分类与「杂项」；通关清单只在总览页。2.5D 渲染器仍经 `SNShipView.set_renderer()` 接入。
- 截图：`docs/design/screenshots/shipyard_normal.png`（正常态）、`shipyard_refit.png`（改装态·装配页）、`shipyard_refit_buy.png`（购买页）、`shipyard_refit_craft.png`（打造页）、`shipyard_refit_cargo.png`（货舱）、`shipyard_refit_misc.png`（杂项）；完整重构说明见 [SHIPYARD_UI_REFACTOR.md](../specs/SHIPYARD_UI_REFACTOR.md)。
- `framework/ui/showcase/ui_kit_showcase.tscn` 用于独立预览与视觉冒烟。
- 页面先使用 Theme variation 表达公共状态，业务脚本只负责布局和数据绑定。
- 2.5D 固定舞台的后续升级方案见 [2.5D_STAGE_PLAN.md](2.5D_STAGE_PLAN.md)。

## 原型契约

- 原型只用于视觉与流程验证，不直接读写游戏状态，也不作为运行时依赖。
- 当前港、已访问港、可航行港、未知港使用形状、颜色和明度三重区分，不能只依赖颜色。
- 海图航线为三次贝塞尔曲线；每个港口的出港方向由邻接港口组中心推导，保证同一港口的所有航线从同一侧离港。
- 抵达采用独立结算页，至少显示收入、奖金、耗时、煤水、耐久和声望变化。

模块索引：[静态代码文档](../static/README.md)
