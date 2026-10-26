# `framework/ui/components/sn_carry_ghost.tscn`

> 作用：市场「拿起 / 放下」光标幽灵的场景骨架（P0 场景化，契约见 `docs/specs/UI_SCENE_MIGRATION.md`）：黄铜底板 + 商品图标 + 标题 / ×数量 / 预计消费 / 提示四行；`sn_carry_ghost.gd` 负责延迟解析、固定黄铜色调、跟随鼠标与位置钳制。

- 类型：Godot 场景

## 节点结构

- `SNCarryGhost`（Control，挂 `sn_carry_ghost.gd`，`visible = false`、`mouse_filter = IGNORE`，根节点引用 `steam_navigator_theme.tres`）
  - `GhostPanel`（PanelContainer，`mouse_filter = IGNORE`；底板样式由脚本克隆 `SNSkin.style("panel_steel")` + `brass.highlight` tint，场景不写颜色）
    - `GhostRow`（HBoxContainer，separation 8，`mouse_filter = IGNORE`）
      - `Icon`（TextureRect，40×40，`expand_mode = 1`，`stretch_mode = 5`，`mouse_filter = IGNORE`）
      - `Labels`（VBoxContainer，separation 1，`mouse_filter = IGNORE`）
        - `Title`（Label，font_size 13）
        - `Amount`（Label，font_size 14，文本为 `×N`）
        - `Cost`（Label，font_size 11，初始 `visible = false`，预计消费行）
        - `Hint`（Label，font_size 10）

## 契约

- 必须从 `framework/ui/components/sn_carry_ghost.tscn` 实例化；`SNCarryGhost.new()` 没有子树，`begin()` 会安全空返回。
- 节点名 `GhostPanel` / `GhostRow` / `Icon` / `Labels` / `Title` / `Amount` / `Cost` / `Hint`、根 `visible = false`、整棵子树 `mouse_filter = IGNORE` 是测试与 Shell 的契约。
- 字号 / 尺寸 / 间距属于设计常量，只写在场景里；四行文字颜色与底板 tint 由脚本从 `SNSkin` token 写入。

模块索引：[framework/ui](../README.md)
