# `framework/ui/components/sn_voyage_confirm.gd`

> 作用：海图内的出航确认弹窗（阶段 4.3.4 / U7）。以半透明遮罩 + 居中面板覆盖海图，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNVoyageConfirm` | L1 |
| `confirmed (signal)` | L46 |
| `cancelled (signal)` | L47 |
| `strategy_changed (signal)` | L48 |
| `SHADE_ALPHA` | L51 |
| `bind(data: Dictionary, translate: Callable) -> void` | L77 |
| `get_strategy_id() -> String` | L86 |
| `is_feasible() -> bool` | L94 |

展示航线预估（距离 / 预计时间 / 煤水 / 风险 / 发现概率）、可行性 blockers、
锅炉策略切换与「取消 / 启航」。普通出航与「循线索出航」共用同一个弹窗。

- 关键依赖：Shell 组合好的 `departure` 字典与本地化回调；本控件不查询、不发命令。

## 契约与约束
- `bind(data, translate)` 注入数据，数据形状见 `main.gd` 的 `_chart_departure_model()`：
  `{kind: "voyage"|"explore", target_name, current_port_name, strategy_id,
    strategies: [{id, name}], preview: {feasible, blockers, distance,
    duration_hours, coal_required, water_required, risk_score, risk_label,
    discovery_chance}}`（名称/文案由 Shell 预翻译）。
- 信号：`strategy_changed(strategy_id)`（Shell 用新策略重新查询预估并重开弹窗）、
  `confirmed(strategy_id)`（Shell 直接执行 `voyage.start` / `explore.start`）、
  `cancelled`（关闭弹窗）。
- 不可行时「启航」禁用、blockers 逐条列出被翻译后的文案；面板不自行判断可行性。
- 弹窗打开时遮罩吃掉点击（`mouse_filter = STOP`），避免误触下层海图。
- 4.3.5 连续消耗只改页面读数与结算，不改变本弹窗的数据契约。

## 场景化结构（P0；契约见 docs/specs/UI_SCENE_MIGRATION.md）
- `sn_voyage_confirm.tscn` 拥有静态骨架：`ConfirmShade`（全屏遮罩）/ `Center` /
  `ConfirmPanel`（Theme 变体 `SNPanel`，最小宽度 520）/ `Body`（VBox，sep 10）/
  `Title` / `Subtitle` / `SeparatorA` / `EstimateBox` / `StrategyRow`
  （`StrategyLabel` + `StrategyPicker`）/ `BlockersBox` / `SeparatorB` / `Hint` /
  `Actions`（`Spacer` + `CancelButton` + `ConfirmButton`）。
- 脚本只负责：本地化文本、估值/阻断行填充、策略项填充、遮罩/文字颜色（`SNSkin` token）、
  按钮禁用与信号；不再 `remove_child` 整棵重建。重复 `bind()` 只清空
  `EstimateBox` / `BlockersBox` 这类动态容器，静态骨架复用。
- 实例化契约：必须 `preload(".../sn_voyage_confirm.tscn").instantiate()`；
  `SNVoyageConfirm.new()` 只有脚本、没有子树，`bind()` 会安全空返回。
- 节点名 `ConfirmShade` / `ConfirmPanel` / `CancelButton` / `ConfirmButton` 与
  面板最小宽 520（场景 `custom_minimum_size.x`）仍是 Shell / 测试的契约。

## 外观来源（外部贴图 + SNSkin）
- 面板底层用 Theme 变体 `SNPanel`（黄铜钢框 + 凹槽承托），选钢而不是羊皮纸是因为
  弹窗叠在海图上、正文含风险/阻断色；深底 + text.light/text.muted 的对比度更稳。
- 遮罩色取 `SNSkin.color("bg.abyss")` 再降 alpha；正文/风险色全部取
  `SNSkin.color(token)`（text.light / text.muted / brass.highlight / state.danger /
  state.success），本文件无 `StyleBoxFlat`、无十六进制色。
- 按钮样式由场景的 Theme 变体给出：取消 `SNGhostButton`、启航 `SNPrimaryButton`。

模块索引：[framework/ui](../README.md)
