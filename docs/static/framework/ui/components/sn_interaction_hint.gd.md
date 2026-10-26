# `framework/ui/components/sn_interaction_hint.gd`

> 作用：框架级「交互处浮出提示」：把命令成功 / 失败的一句话反馈画在最后鼠标位置旁（皮肤底板 + 语义图标 + 短淡出），挂在 Shell 的页面滚动区之外，任意页面都能复用，顶部状态 banner 仍保留。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNInteractionHint` | L1 |
| `PANEL_STYLE_ID` | L35 |
| `SUCCESS_TINT_TOKEN` | L36 |
| `ERROR_TINT_TOKEN` | L37 |
| `SUCCESS_ICON_ID` | L38 |
| `ERROR_ICON_ID` | L39 |
| `CONTENT_MARGIN` | L40 |
| `POINTER_OFFSET` | L41 |
| `ICON_SIZE` | L42 |
| `MESSAGE_FONT_SIZE` | L43 |
| `HOLD_SECONDS` | L45 |
| `FADE_SECONDS` | L46 |
| `show_at(at: Vector2, message: String, is_error: bool) -> void` | L65 |
| `hide_hint() -> void` | L83 |
| `is_showing() -> bool` | L91 |
| `current_message() -> String` | L95 |
| `current_error() -> bool` | L99 |
| `place_at(at: Vector2) -> Vector2` | L105 |

Floating command feedback rendered at the interaction point
(v0.2.0-dev.3 feedback #4: the old status banner sits at the top of the page,
but the player interacts at the bottom and has to look up).

The shell owns the message text (`_set_status` already receives a localized
string) and only injects it here; the component has no localization dependency
and no knowledge of ports / trades, so any page can call `show_at()`.

## 外观来源（外部贴图 + SNSkin）
- 底板取 `SNSkin.style("panel_steel")` 克隆，内容边距 10 / 6，成功
  `modulate_color = brass.highlight`、失败 `state.danger`；语义图标取
  `SNSkin.icon("action_confirm")` / `SNSkin.icon("status_warning")`，文字色取
  `text.light`。不新增 `StyleBoxFlat`、不写十六进制色。
- 根节点与全部子树 `mouse_filter = IGNORE`：提示绝不吞掉已落在光标下的点击
  （点击落点放下 / 右键取消必须继续生效）。

## 契约与约束
- `show_at(at, message, is_error)` 显示并重置淡出；`hide_hint()` 立即收起；
  `is_showing()` / `current_message()` 供测试与调试断言。
- `place_at(at)` 是纯函数：提示出现在指针上方（+14, -height-14），X/Y 都钳制在
  视口内；960×540 与 1440×900 都不会露出视口或压到页面外。
- 挂载点必须是页面滚动区之外的 Shell 浮层（`HintLayer`，在转场淡出层之下），
  `PageScroll` 不会裁切它；本组件自身 `clip_contents = false`。
- 淡出用 `create_tween()`（HOLD_SECONDS 后 FADE_SECONDS 淡到透明再隐藏）；
  新消息会 kill 旧 tween 并重置 alpha，连续交互不会叠加计时。
- 显示频率由 Shell 决定：只在 run 内的港口页面、由玩家交互触发的 `_set_status`
  调用，菜单 / 演出期间不弹。

模块索引：[framework/ui](../README.md)
