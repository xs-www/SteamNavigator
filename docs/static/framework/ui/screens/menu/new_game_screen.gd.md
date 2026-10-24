# `framework/ui/screens/menu/new_game_screen.gd`

> 作用：新航程配置页面场景：选择初始构筑和随机种子，展示启动内容摘要与警告。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `NewGameScreen` | L1 |
| `action_requested (signal)` | L27 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L36 |

New-voyage form. It owns local form state and emits a start intent.
C4: the picker lists `starting_scenarios` (retired `starting_builds`).

- 关键依赖：`app.view` 启动内容摘要、`SNSectionHeader`、`SNSkin`、纹理化 Theme

## 契约与约束
- bind(vm, translate) 接收 builds、selected_scenario、seed_text、mods、内容计数和
  warnings，不访问注册表或命令总线。
- 构筑与种子是页面局部表单状态；只有点击开始时才通过 start_run 意图一并交给 Shell。
- 构筑选择变化只更新本页描述，不触发整页重建。
- 返回只发出 back 意图；run.start 的参数解析与执行仍由 Shell 负责。
- 新手剧情模式（tutorial_mode）不渲染 OptionButton，test_story_ui 断言行数。

## 皮肤与节点约束（UI 贴图层）
- 启动摘要用 `SNPanel`（钢框），表单与警告用 `SNParchmentPanel` 纸面承托；
  LineEdit / OptionButton 的凹槽、聚焦框与按钮四态由 Theme 纹理表达。
- 纸面文字取 `ink.primary` / `paper.ink_muted`、强调 `brass.shadow`；钢框文字取
  `text.light` / `text.muted`；不再写颜色常量。
- 尺寸结构不变：表单纵向堆叠、开始按钮 Primary、返回 Ghost、种子行横向、
  `_label(..., autowrap_word_smart)` 签名被 test_story_ui 间接依赖。

模块索引：[framework/ui](../../README.md)
