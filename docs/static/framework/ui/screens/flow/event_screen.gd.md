# `framework/ui/screens/flow/event_screen.gd`

> 作用：航行事件流程场景：展示事件说明、当前资源和本次抽取的处理选项。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `EventScreen` | L1 |
| `command_requested (signal)` | L22 |
| `DEFAULT_HINT` | L25 |
| `bind(vm: Dictionary, translate: Callable) -> void` | L29 |

普通航行事件与 4.2 资源告急页共用这一版式。选项按钮只发 `command_requested`，
由 Shell 决定把它接到 `event.choose_option` 还是资源告急决策；提示行默认是
「选择后会立即结算」，事件 VM 可以用 `hint_text`（已本地化）或 `hint_key`
（交给翻译回调）覆盖它——资源告急的 `continue` 不会立刻结算，需要换文案。

- 关键依赖：`event.view` / 资源告急 ViewModel、`SNSkin`、纹理化 Theme

## 皮肤与节点约束（UI 贴图层）
- 事件正文是航海文书：面板用 `SNParchmentPanel` 纸面承托，标题用
  `state.danger`、正文 `ink.primary`、资源/提示行 `paper.ink_muted`；选项按钮
  统一 `SNSecondaryButton`（钢制铭牌），文字色与四态由 Theme 提供。
- 文案完全来自 `_loc()`（本地化缺失时回退中文/键名），DEFAULT_HINT 保持原文。
- 只依赖 `_label(text, size, color)` / `_panel` 结构；不新增节点名，也不改
  `command_requested(command, params)` 的 `event.choose_option` 契约。

模块索引：[framework/ui](../../README.md)
