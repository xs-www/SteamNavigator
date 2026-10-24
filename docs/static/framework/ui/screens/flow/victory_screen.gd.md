# `framework/ui/screens/flow/victory_screen.gd`

> 作用：通关总结流程场景：展示种子、构筑、航次、准时率、事故、财务、债务、耐久和最终模块。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VictoryScreen` | L1 |
| `action_requested (signal)` | L24 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L29 |

Run reset/dismiss remain shell actions.

- 关键依赖：`victory.view` 查询结果、`ClockService`、`SNSectionHeader`、`SNSkin`

## 契约与约束
- bind(vm, translate) 只消费 victory.view，不查询通关条件或修改存档。
- 再来一局与继续游玩分别发出 play_again/keep_playing action_requested；
  reset_state 与会话 dismiss 由 Shell 执行。
- on_time_rate 缺失时仅按 summary 的 on_time/voyages 做展示回退，超过 1 的旧百分比
  值兼容除以 100。

## 皮肤与节点约束（UI 贴图层）
- 通关总结是航程账册：主面板用 `SNParchmentPanel` 纸面，正文 `ink.primary`、
  字段名 `paper.ink_muted`、收入/利润等强调 `brass.shadow`、支出/事故/债务
  `state.danger`；两个操作按钮沿用 `SNPrimaryButton` / `SNGhostButton`。
- `_stat` / `_kv` / `_label` 的排版与 160 px 字段宽、文本内容不变
  （test_victory 只断言 ViewModel，但 Shell 截图依赖版式）。

模块索引：[framework/ui](../../README.md)
