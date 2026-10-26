# `framework/ui/components/sn_interaction_hint.tscn`

> 作用：框架级「交互处浮出提示」的场景骨架（P0 场景化，契约见 `docs/specs/UI_SCENE_MIGRATION.md`）：皮肤底板 + 语义图标 + 单行消息；`sn_interaction_hint.gd` 负责延迟解析、成功/失败色调、位置钳制与淡出 Tween。

- 类型：Godot 场景

## 节点结构

- `SNInteractionHint`（Control，挂 `sn_interaction_hint.gd`，`visible = false`、`mouse_filter = IGNORE`，根节点引用 `steam_navigator_theme.tres`）
  - `HintPanel`（PanelContainer，`mouse_filter = IGNORE`；底板样式由脚本克隆 `SNSkin.style("panel_steel")` 并按成功/失败 tint，场景不写颜色）
    - `HintRow`（HBoxContainer，separation 6，`mouse_filter = IGNORE`）
      - `Icon`（TextureRect，18×18，`expand_mode = 1`，`stretch_mode = 5`，`mouse_filter = IGNORE`）
      - `Message`（Label，font_size 13，`autowrap_mode = 0`，`text_overrun_behavior = 3`，`mouse_filter = IGNORE`）

## 契约

- 必须从 `framework/ui/components/sn_interaction_hint.tscn` 实例化；`SNInteractionHint.new()` 没有子树，`show_at()` 会安全空返回。
- 节点名 `HintPanel` / `HintRow` / `Icon` / `Message`、根与全部子树 `mouse_filter = IGNORE`、根 `visible = false` 是 Shell / 测试的契约。
- 字号、尺寸、间距、初始隐藏属于设计常量，只写在场景里；文字颜色、图标与底板 tint 由脚本从 `SNSkin` token 写入。

模块索引：[framework/ui](../README.md)
