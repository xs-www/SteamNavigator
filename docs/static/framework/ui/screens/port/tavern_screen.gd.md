# `framework/ui/screens/port/tavern_screen.gd`

> 作用：酒馆页（阶段 4.5.4，替换原情报站页面）——上半部分保留物价情报矩阵与

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TavernScreen` | L1 |
| `command_requested (signal)` | L26 |
| `INTEL_TABLE_SCRIPT` | L28 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L32 |

NPC 动向，下半部分列出港口线索（购买线索、调查线索），把「物价情报 + 港口线索」
合并到同一个设施入口。

- 关键依赖：`tavern.view` 查询（Shell 传入 ViewModel）、`sn_intel_table`
- 信号：`command_requested(command, params)` → Shell 执行 `intel.refresh` /
  `clue.buy` / `clue.investigate`

## 契约与约束
- 纯展示：不查状态、不发命令；线索不输出目标港 / credibility / 搜索区。
- 线索行由 `tavern.view.clues` 的等级裁剪字段渲染，购买与调查可用性完全由
  `can_buy_clue` / `clue.can_investigate` 决定，按钮不自行猜规则。

## 外观来源（外部贴图 + SNSkin）
- 面板用 Theme 默认钢制 `Panel`（纹理化）；物价情报矩阵由 `SNIntelTable`
  自己换皮（钢制抬高面 + 凹槽格）。文字 / 状态色取 `SNSkin.color(token)`
  （text.light / text.muted / brass.highlight / state.water / state.danger）。
- 按钮保持默认纹理化 `Button`（刷新物价 / 购买线索 / 调查线索），按钮文字与
  节点名 `RefreshIntelButton` / `BuyClueButton` / `InvestigateButton` 不变。
- 尺寸约束：面板间距 8、线索行间距 12、字号 16/14/13/12 不变；不新增布局。

模块索引：[framework/ui](../../README.md)
