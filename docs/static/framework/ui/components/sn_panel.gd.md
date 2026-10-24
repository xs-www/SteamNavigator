# `framework/ui/components/sn_panel.gd`

> 作用：可复用界面表面：基础、高架、内嵌三种层级，外加羊皮纸、蓝图（技术页）、画布与玻璃浮层四种材质变体；只通过 Theme variation 换材质，不在调用处复制 StyleBox。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNPanel` | L2 |
| `VARIATIONS` | L25 |

- 关键依赖：`assets/ui/theme/steam_navigator_theme.tres` 的 `SN*Panel` 变体（由 skin.json 生成的纹理化九宫格）。

## 契约与约束
- `Variant` 前三个枚举值 BASE=0 / ELEVATED=1 / INSET=2 必须保持不变，历史场景与脚本用整数索引赋值。
- 新增材质只追加在末尾（PARCHMENT/BLUEPRINT/CANVAS/GLASS），不重排枚举，避免旧调用语义漂移。
- 变体只表达视觉层级与材质；内容布局、内边距与文字颜色仍由调用页面负责。
- 玻璃浮层用 `SNGlassPanel`（低 alpha 纹理）让 3D 舞台透出；同一页面最多一层。

## 用法
```gdscript
var panel := SNPanel.new()
panel.variant = SNPanel.Variant.PARCHMENT   # 或 SNPanel.Variant.GLASS
```

模块索引：[framework/ui](../README.md)
