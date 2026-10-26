# `framework/ui/screens/port/overview_screen.gd`

> 作用：港口总览页面场景：组合港口横幅、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录；三种呈现由 Shell 控制——裸 3D 舞台（页面只留 spacer）、详细总览抽屉（原 2D 面板覆盖舞台）与 2D 回退总览。阶段 4.3 / U6 起不再渲染旧线稿海图。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `OverviewScreen` | L1 |
| `navigation_requested (signal)` | L20 |
| `command_requested (signal)` | L21 |
| `stage_toggle_requested (signal)` | L24 |
| `detail_toggle_requested (signal)` | L27 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L32 |

Port overview presentation. The shell supplies all resolved application data.

## 外观来源（外部贴图 + SNSkin）
- 面板保持 Theme 默认钢制 `Panel` / `SNInsetPanel`（纹理化黄铜钢板）；
  资源条 `SNResourceMeter` 用主题 ProgressBar 纹理，徽标用 `SNBadge`。
- 横幅压暗层取 `SNSkin.color("bg.abyss")` 后设 alpha（0.6）；文字与状态色全部取
  `SNSkin.color(token)`（text.light / text.muted / brass.highlight / state.water /
  state.success / state.danger），本文件无内联十六进制色与 StyleBoxFlat。
- 尺寸约束：横幅 236 px、右列 `custom_minimum_size = (400, 0)`、左右 1.7:1、
  快捷入口 / 等待按钮文本与信号不变；不新增节点层级。
- 反馈 #3：主线摘要的期限行在 `has_deadline=false` 时显示「引导委托 · 无期限」，
  奖励文案（`reward_text`，由 Shell 生成）对无期限委托显示「完成 +N」。

模块索引：[framework/ui](../../README.md)
