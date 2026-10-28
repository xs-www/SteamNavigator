# `framework/tests/cases/test_story_ui.gd`

> 作用：新手剧情 UI 冒烟测试：教程局挂出剧情卡 / 目标条、导航与海图入口按功能

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L23 |
| `NEW_GAME_SCENE` | L24 |
| `FOCUS_OVERLAY_SCRIPT` | L25 |
| `STEADY_BUILD` | L26 |
| `test_tutorial_shell_mounts_card_and_locks_features() -> void` | L29 |
| `test_continue_unlocks_market_then_buying_advances_to_the_chart() -> void` | L45 |
| `test_skip_confirmation_unlocks_everything_and_removes_the_card() -> void` | L116 |
| `test_non_tutorial_shell_has_no_card_and_no_gating() -> void` | L133 |
| `test_new_game_screen_hides_build_picker_in_tutorial_mode() -> void` | L171 |
| `test_first_voyage_advances_the_arrival_story_once_at_arrival() -> void` | L208 |
| `test_chart_events_are_reported_once_per_player_action() -> void` | L267 |
| `test_focus_overlay_tracks_the_market_nav_after_rebuild() -> void` | L296 |
| `test_guided_focus_masks_the_supply_block_and_clears_on_advance() -> void` | L344 |
| `test_focus_overlay_component_masks_everything_but_the_target() -> void` | L397 |

解锁过滤、剧情卡继续推进阶段、跳过教程的确认页与全解锁；dev.3 #1 的触发时机
回归（真实航海驱动：出航收出航指示、抵达才推抵达剧情、事件只上报一次）与
dev.3 #3 的框架级强制引导遮罩（组件遮罩契约 + Shell 在剧情阶段挂载 / 解析目标 /
推进后清除）；2026-10-28 P0 反馈的引导框错位回归（页面/顶栏重建后遮罩目标洞
必须追到真实「市场」按钮、提示板保持一行高、四块遮罩贴在目标四边）。

## 契约与约束
- 用真实 `main.tscn` 与真实 Core 内容；教程局通过 `run.start tutorial=true` 建立，
  非教程局用于对照（不弹卡、不门禁）。
- 只驱动 Shell 的公开信号 / 命令，不断言内部节点布局尺寸；卡片按钮按节点名
  `ContinueButton` / `SkipButton` / `SkipConfirmButton` 查找。
- 时间线回归用真实 `voyage.start → _process 逐帧 → _finish_presentation` 驱动，
  并用 `story.observe` 命令执行日志计数证明「一次玩家动作只上报一次 UI 事件」。
- 测试跑在单帧里，不能 await；需要「等布局稳定」时用 `Container.NOTIFICATION_SORT_CHILDREN`
  同步推完挂起的容器排版，再让遮罩 `refresh_target()` 做一帧自愈 tick。
- 组件测试同时守护皮肤合约：遮罩对 `SNSkin.style()` 的共享 StyleBox 只改 `duplicate()`
  克隆，不能把 tint / content_margin 污染到全局主题缓存。

模块索引：[framework/tests](../README.md)
