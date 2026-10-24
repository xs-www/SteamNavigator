# `framework/ui/screens/flow/settlement_screen.gd`

> 作用：抵达结算页。展示委托收入 / 准时 / 延误、船况资源、交付明细与旅客受伤，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SettlementScreen` | L1 |
| `navigation_requested (signal)` | L24 |
| `EXPLORE_RESULT_FALLBACK` | L27 |
| `EXPLORE_CLUE_STATUS_FALLBACK` | L32 |
| `EXPLORE_CLUE_STATUS_KEY` | L38 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L46 |

并在 `summary.explore` 存在时追加**探索结果**区块（探索系统 4.1 / 4.3）：结果
（发现 / 失败漂流 / 掉头返航）、港口名、额外煤水与耐久损失、线索状态说明。
4.3 起失败不再作废线索：失败结果显示「线索保留 + 已尝试次数」。

## 契约与约束
- 只读 `bind(vm)` 里的 summary / ship / money；不查询后端、不发命令。
- 探索区块只在 `summary.explore` 存在时追加，委托结算的既有布局不变。
- 新文案走 `_loc(key, fallback)`：键先按契约编码，本地化缺失时回退中文，
  不渲染 `ui.*` 原始键名。

## 皮肤与节点约束（UI 贴图层）
- 抵达回执是港务文书：主面板用 `SNParchmentPanel` 纸面，正文取
  `SNSkin.color("ink.primary")`、次要文字 `paper.ink_muted`、数字强调
  `brass.shadow`、风险/延误/受伤 `state.danger`；进入港口按钮统一
  `SNPrimaryButton`。颜色不写常量，本页无内联 StyleBox。
- 资源徽标继续用 `SNBadge` 的四色纹理变体；`_stat` / `_label` / `_panel` 的
  现有结构与文本（含 `ExploreBlock` 节点名）不变（test_voyage_flow 断言）。

模块索引：[framework/ui](../../README.md)
