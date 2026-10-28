# `framework/ui/screens/port/tavern_screen.gd`

> 作用：酒馆页（阶段 4.5.4，替换原情报站页面）——上半部分保留物价情报矩阵与

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TavernScreen` | L1 |
| `command_requested (signal)` | L38 |
| `INTEL_TABLE_SCRIPT` | L40 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L44 |

NPC 动向，中部是**海图（航线解锁）**，下半部分列出港口线索（购买线索、调查线索），
把「物价情报 + 海图 + 港口线索」合并到同一个设施入口。

- 关键依赖：`tavern.view` 查询（Shell 传入 ViewModel）、`sn_intel_table`
- 信号：`command_requested(command, params)` → Shell 执行 `intel.refresh` /
  `chart.buy` / `clue.buy` / `clue.investigate`

## 契约与约束
- 纯展示：不查状态、不发命令；线索不输出目标港 / credibility / 搜索区。
- 线索行由 `tavern.view.clues` 的等级裁剪字段渲染，购买与调查可用性完全由
  `can_buy_clue` / `clue.can_investigate` 决定，按钮不自行猜规则。
- **海图区**（2026-10-26 航线解锁）：`tavern.view.chart_offers` 每行一个已发现港口，
  未解锁显示价格 + 购买按钮（`chart.buy {port_id}`），已解锁显示「已测绘」；
  按钮可用性完全由查询的 `can_buy` / `reason_key` 决定，页面不猜价格或门禁。

## 外观来源（外部贴图 + SNSkin）
- 面板用 Theme 默认钢制 `Panel`（纹理化）；物价情报矩阵由 `SNIntelTable`
  自己换皮（钢制抬高面 + 凹槽格）。文字 / 状态色取 `SNSkin.color(token)`
  （text.light / text.muted / brass.highlight / state.water / state.danger）。
- 按钮保持默认纹理化 `Button`（刷新物价 / 购买线索 / 调查线索），按钮文字与
  节点名 `RefreshIntelButton` / `BuyClueButton` / `InvestigateButton` 不变。
- 尺寸约束：面板间距 8、线索行间距 12、字号 16/14/13/12 不变；不新增布局。

## 2026-10-28 图标化 / 文字精简
- 标题 detail（`ui.hint.tavern` 长句）不再占正文，转到标题 tooltip。
- 纯说明段落删除并转 tooltip：`ui.label.snapshot_tip` → 情报摘要行、
  `ui.tavern.chart_hint` → 海图标题、`ui.tavern.npc_empty` → NPC 标题（空态不再
  占一行）、`ui.tavern.clues_empty` → 持有线索计数行（空态不再占一行）。
- 按钮加 16 px 皮肤图标：刷新情报 / 购买线索 / 调查 → `nav_intelligence`，
  购买海图 → `nav_chart`；按钮文字（含价格）与节点名全部保留。
- 数据表格表头、线索信息行（港口 / 等级 / 航程）与价格数值保留。

模块索引：[framework/ui](../../README.md)
