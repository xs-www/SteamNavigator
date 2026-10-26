# `tools/ui/slice_ui_icons.gd`

> 作用：把 `docs/design/ui_icons_v1/sn_ui_icons_v1.png`（1536×1024 的透明 UI 图标图集）

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ATLAS_PATH` | L32 |
| `ICON_DIR` | L33 |
| `MANIFEST_PATH` | L34 |
| `COLUMNS` | L35 |
| `ROWS` | L36 |
| `CANVAS_SIZE` | L37 |
| `SOLID_CUT` | L39 |
| `CONTENT_CUT` | L41 |
| `CONTENT_PAD` | L43 |
| `EDGE_SEARCH` | L45 |
| `_init() -> void` | L50 |

按「真实像素内容」重新切片：先用全透明行/列把图集分成图标格（不用固定等宽/等高网格），
再逐格求 alpha 紧包围盒，把每枚图标以原像素尺寸居中放进统一的 256×256 透明画布，
写回 `docs/design/ui_icons_v1/icons/<id>.png`，并更新 `manifest.json` 的
`atlas_region`（精确内容包围盒）、行带与「未映射图标」记录。

## 为什么不再用固定网格裁切
图集是生成式 AI 出图：行高不是整数等分（实际行带 28–219 / 235–411 / 426–620 /
625–795 / 810–996），第 3 行还多画了 1 枚图标（7 枚而不是 6 枚）。旧版按 256×256
固定方形从行偏移裁切，结果每张独立 PNG 底部都带下一行图标的顶端碎屑，第 3 行还会
逐格串进相邻图标。本工具只取当前图标「内容核心」的紧包围盒，不会再串行。

## 用法
```powershell
godot --headless --path . --script res://tools/ui/slice_ui_icons.gd -- [--dry-run]
```
- 默认写图标与 manifest；`--dry-run` 只打印检测结果，不落盘。
- 图标顺序/命名取自 `manifest.json` 的 `assets[].id`（行优先）。每行按内容检测到的
  列块从左到右绑定；多出来的列块（本图集第 3 行的交叉工具）不生成独立文件，但会把
  包围盒记录到 manifest 的 `unmapped`，方便以后提升为正式图标。

## 契约
- 每枚图标输出 256×256 RGBA 画布，内容按原像素尺寸居中（不缩放、不变形、不旋转）。
- `manifest.json` 仍是 30 个 `assets` + 3 个 `aliases`；`atlas_region` 为 `[x, y, w, h]`。
- 源图集保持不变；重跑同一输入逐字节一致（固定行/列顺序，无时间戳）。
- 下游 `tools/ui/build_ui_skin.gd` 会再裁透明留白并缩放居中到 128×128 运行图标，
  因此「原尺寸居中」不改变运行图标的尺寸基准。

模块索引：[tools](../README.md)
