# `framework/ui/screens/flow/settlement_screen.gd`

> 作用：抵达结算页。展示委托收入 / 准时 / 延误、船况资源、交付明细与旅客受伤，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SettlementScreen` | L1 |
| `navigation_requested (signal)` | L16 |
| `TEXT` | L18 |
| `MUTED` | L19 |
| `BRASS` | L20 |
| `RED` | L21 |
| `GREEN` | L22 |
| `EXPLORE_RESULT_FALLBACK` | L24 |
| `EXPLORE_CLUE_STATUS_FALLBACK` | L29 |
| `EXPLORE_CLUE_STATUS_KEY` | L35 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L43 |

并在 `summary.explore` 存在时追加**探索结果**区块（探索系统 4.1 / 4.3）：结果
（发现 / 失败漂流 / 掉头返航）、港口名、额外煤水与耐久损失、线索状态说明。
4.3 起失败不再作废线索：失败结果显示「线索保留 + 已尝试次数」。

## 契约与约束
- 只读 `bind(vm)` 里的 summary / ship / money；不查询后端、不发命令。
- 探索区块只在 `summary.explore` 存在时追加，委托结算的既有布局不变。
- 新文案走 `_loc(key, fallback)`：键先按契约编码，本地化缺失时回退中文，
  不渲染 `ui.*` 原始键名。

模块索引：[framework/ui](../../README.md)
