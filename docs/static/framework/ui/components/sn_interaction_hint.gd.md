# `framework/ui/components/sn_interaction_hint.gd`

> 作用：框架级「交互处浮出提示」：把命令成功 / 失败的一句话反馈画在最后鼠标位置旁（皮肤底板 + 语义图标 + 短淡出），挂在 Shell 的页面滚动区之外，任意页面都能复用，顶部状态 banner 仍保留。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNInteractionHint` | L1 |
| `PANEL_STYLE_ID` | L55 |
| `SUCCESS_TINT_TOKEN` | L56 |
| `ERROR_TINT_TOKEN` | L57 |
| `SUCCESS_ICON_ID` | L58 |
| `ERROR_ICON_ID` | L59 |
| `CONTENT_MARGIN` | L60 |
| `POINTER_OFFSET` | L61 |
| `MAX_TEXT_WIDTH` | L65 |
| `HOLD_SECONDS` | L67 |
| `FADE_SECONDS` | L68 |
| `show_at(at: Vector2, message: String, is_error: bool) -> void` | L113 |
| `hide_hint() -> void` | L134 |
| `is_showing() -> bool` | L142 |
| `current_message() -> String` | L146 |
| `current_error() -> bool` | L150 |
| `place_at(at: Vector2) -> Vector2` | L156 |

## 场景化（P0，见 docs/specs/UI_SCENE_MIGRATION.md）
静态骨架在 `sn_interaction_hint.tscn`：根 `Control` 挂本脚本（`visible = false`、
`mouse_filter = IGNORE`、根节点引用 `steam_navigator_theme.tres`），子树为
`HintPanel(PanelContainer, IGNORE) → HintRow(HBoxContainer, separation 6, IGNORE) →
Icon(TextureRect, 18×18, expand_mode=1, stretch_mode=5, IGNORE) +
Message(Label, font_size 13, autowrap_mode=0, text_overrun_behavior=3, IGNORE)`。
层级、尺寸、间距、字号、`mouse_filter`、初始隐藏都是设计常量，只写在场景里。

**实例化契约（R1）**：调用方必须
`preload("res://framework/ui/components/sn_interaction_hint.tscn").instantiate()`，
禁止 `SNInteractionHint.new()`——脚本 `.new()` 没有场景子树，`_ensure_refs()` 全部解析
为空，提示会静默空白；节点名 `HintPanel` / `HintRow` / `Icon` / `Message` 是测试与
Shell 的查找契约（R2），不要改名。脚本只做延迟解析（`_ensure_refs()`）、动态色调、
`_sync_bounds()`、`place_at()` 与淡出 Tween，允许在未进树时先 `show_at()`（R3）。

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
  `text.light`。不新增 `StyleBoxFlat`、不写十六进制色（场景里也不写颜色值，R4）。
- 根节点与全部子树 `mouse_filter = IGNORE`：提示绝不吞掉已落在光标下的点击
  （点击落点放下 / 右键取消必须继续生效）。

## 契约与约束
- `show_at(at, message, is_error)` 显示并重置淡出；`hide_hint()` 立即收起；
  `is_showing()` / `current_message()` 供测试与调试断言。
- 消息宽度由脚本实测（`MAX_TEXT_WIDTH` = 520）：Godot 4.7 的 Label 在
  `OVERRUN_TRIM_ELLIPSIS` 下最小宽度只报 1 px，若直接交给容器排版，面板会塌缩成
  图标宽度、文字只剩省略号。`show_at()` 用主题字体量出文本宽度并写入
  `Message.custom_minimum_size.x`（上限 520），所以短消息完整可读、超长消息到
  520 px 才用省略号截断；场景里的 `text_overrun_behavior = 3` 保持不变。
- `place_at(at)` 是纯函数：提示出现在指针上方（+14, -height-14），X/Y 都钳制在
  视口内；960×540 与 1440×900 都不会露出视口或压到页面外。
- 挂载点必须是页面滚动区之外的 Shell 浮层（`HintLayer`，在转场淡出层之下），
  `PageScroll` 不会裁切它；本组件自身 `clip_contents = false`。
- 淡出用 `create_tween()`（HOLD_SECONDS 后 FADE_SECONDS 淡到透明再隐藏）；
  新消息会 kill 旧 tween 并重置 alpha，连续交互不会叠加计时。
- 显示频率由 Shell 决定：只在 run 内的港口页面、由玩家交互触发的 `_set_status`
  调用，菜单 / 演出期间不弹。

模块索引：[framework/ui](../README.md)
