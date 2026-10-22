# `framework/tests/cases/test_story_ui.gd`

> 作用：阶段 4.5.1 新手剧情 UI 冒烟测试：教程局挂出剧情卡 / 目标条、导航与海图入口

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `MAIN_SCENE` | L13 |
| `NEW_GAME_SCENE` | L14 |
| `STEADY_BUILD` | L15 |
| `test_tutorial_shell_mounts_card_and_locks_features() -> void` | L18 |
| `test_continue_unlocks_market_then_buying_advances_to_the_chart() -> void` | L34 |
| `test_skip_confirmation_unlocks_everything_and_removes_the_card() -> void` | L104 |
| `test_non_tutorial_shell_has_no_card_and_no_gating() -> void` | L121 |
| `test_new_game_screen_hides_build_picker_in_tutorial_mode() -> void` | L159 |

按功能解锁过滤、剧情卡继续推进阶段、跳过教程的确认页与全解锁。

## 契约与约束
- 用真实 `main.tscn` 与真实 Core 内容；教程局通过 `run.start tutorial=true` 建立，
  非教程局用于对照（不弹卡、不门禁）。
- 只驱动 Shell 的公开信号 / 命令，不断言内部节点布局尺寸；卡片按钮按节点名
  `ContinueButton` / `SkipButton` / `SkipConfirmButton` 查找。

模块索引：[framework/tests](../README.md)
