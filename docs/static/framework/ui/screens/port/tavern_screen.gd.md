# `framework/ui/screens/port/tavern_screen.gd`

> 作用：酒馆页（阶段 4.5.4，替换原情报站页面）——上半部分保留物价情报矩阵与

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TavernScreen` | L1 |
| `command_requested (signal)` | L18 |
| `INTEL_TABLE_SCRIPT` | L20 |
| `TEXT` | L21 |
| `MUTED` | L22 |
| `BRASS` | L23 |
| `TEAL` | L24 |
| `RED` | L25 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L29 |

NPC 动向，下半部分列出港口线索（购买线索、调查线索），把「物价情报 + 港口线索」
合并到同一个设施入口。

- 关键依赖：`tavern.view` 查询（Shell 传入 ViewModel）、`sn_intel_table`
- 信号：`command_requested(command, params)` → Shell 执行 `intel.refresh` /
  `clue.buy` / `clue.investigate`

## 契约与约束
- 纯展示：不查状态、不发命令；线索不输出目标港 / credibility / 搜索区。
- 线索行由 `tavern.view.clues` 的等级裁剪字段渲染，购买与调查可用性完全由
  `can_buy_clue` / `clue.can_investigate` 决定，按钮不自行猜规则。

模块索引：[framework/ui](../../README.md)
