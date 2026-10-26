# `framework/tests/cases/test_story_ui.gd`

> 作用：新手剧情 UI 冒烟测试：教程局挂出剧情卡 / 目标条、导航与海图入口按功能

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L18 |
| `NEW_GAME_SCENE` | L19 |
| `FOCUS_OVERLAY_SCRIPT` | L20 |
| `STEADY_BUILD` | L21 |
| `test_tutorial_shell_mounts_card_and_locks_features() -> void` | L24 |
| `test_continue_unlocks_market_then_buying_advances_to_the_chart() -> void` | L40 |
| `test_skip_confirmation_unlocks_everything_and_removes_the_card() -> void` | L111 |
| `test_non_tutorial_shell_has_no_card_and_no_gating() -> void` | L128 |
| `test_new_game_screen_hides_build_picker_in_tutorial_mode() -> void` | L166 |
| `test_first_voyage_advances_the_arrival_story_once_at_arrival() -> void` | L203 |
| `test_chart_events_are_reported_once_per_player_action() -> void` | L262 |
| `test_guided_focus_masks_the_supply_block_and_clears_on_advance() -> void` | L289 |
| `test_focus_overlay_component_masks_everything_but_the_target() -> void` | L342 |

解锁过滤、剧情卡继续推进阶段、跳过教程的确认页与全解锁；dev.3 #1 的触发时机
回归（真实航海驱动：出航收出航指示、抵达才推抵达剧情、事件只上报一次）与
dev.3 #3 的框架级强制引导遮罩（组件遮罩契约 + Shell 在剧情阶段挂载 / 解析目标 /
推进后清除）。

## 契约与约束
- 用真实 `main.tscn` 与真实 Core 内容；教程局通过 `run.start tutorial=true` 建立，
  非教程局用于对照（不弹卡、不门禁）。
- 只驱动 Shell 的公开信号 / 命令，不断言内部节点布局尺寸；卡片按钮按节点名
  `ContinueButton` / `SkipButton` / `SkipConfirmButton` 查找。
- 时间线回归用真实 `voyage.start → _process 逐帧 → _finish_presentation` 驱动，
  并用 `story.observe` 命令执行日志计数证明「一次玩家动作只上报一次 UI 事件」。

模块索引：[framework/tests](../README.md)
