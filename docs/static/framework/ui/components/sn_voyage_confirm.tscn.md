# `framework/ui/components/sn_voyage_confirm.tscn`

> 作用：海图内的统一出航确认弹窗场景（P0 场景化，契约见 `docs/specs/UI_SCENE_MIGRATION.md`）：全屏遮罩 + 居中钢框面板，静态骨架由本场景持有，`sn_voyage_confirm.gd` 只负责文本、估值/阻断行、策略项与信号。

- 类型：Godot 场景

## 节点结构

- `SNVoyageConfirm`（Control，全窗锚点，`mouse_filter = STOP`，挂 `sn_voyage_confirm.gd`，根节点引用 `steam_navigator_theme.tres`）
  - `ConfirmShade`（ColorRect，全窗；颜色由脚本按 `SNSkin.color("bg.abyss")` + `SHADE_ALPHA` 写入）
  - `Center`（CenterContainer，全窗，`mouse_filter = IGNORE`）
    - `ConfirmPanel`（PanelContainer，`theme_type_variation = "SNPanel"`，最小宽 520）
      - `Body`（VBoxContainer，sep 10）
        - `Title` / `Subtitle`（Label，字号 20 / 14）
        - `SeparatorA`（HSeparator）
        - `EstimateBox`（VBoxContainer，动态估值行容器）
        - `StrategyRow`（HBoxContainer，sep 10）
          - `StrategyLabel`（Label，宽 110）/ `StrategyPicker`（OptionButton，横向伸展）
        - `BlockersBox`（VBoxContainer，动态阻断行容器）
        - `SeparatorB`（HSeparator）
        - `Hint`（Label，字号 11）
        - `Actions`（HBoxContainer，sep 10）
          - `Spacer`（Control，横向伸展）
          - `CancelButton`（Button，`SNGhostButton`）
          - `ConfirmButton`（Button，`SNPrimaryButton`）

## 契约

- 必须从 `framework/ui/components/sn_voyage_confirm.tscn` 实例化；`SNVoyageConfirm.new()` 没有子树，`bind()` 会安全空返回。
- 节点名 `ConfirmShade` / `ConfirmPanel` / `CancelButton` / `ConfirmButton`、面板最小宽 520 是 Shell 与测试的契约。
- 文字颜色、遮罩色、风险色全部在脚本里取 `SNSkin` token；本场景不写十六进制颜色，静态样式走 Theme 变体。

模块索引：[framework/ui](../README.md)
