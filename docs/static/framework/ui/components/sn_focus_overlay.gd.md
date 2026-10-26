# `framework/ui/components/sn_focus_overlay.gd`

> 作用：框架级「强制引导」遮罩（v0.2.0-dev.3 反馈 #3）。全屏半透明遮罩只留一个

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNFocusOverlay` | L1 |
| `MASK_STYLE_ID` | L37 |
| `MASK_TINT_TOKEN` | L38 |
| `MASK_ALPHA` | L39 |
| `RING_STYLE_ID` | L41 |
| `RING_TINT_TOKEN` | L42 |
| `RING_PAD` | L43 |
| `TEXT_STYLE_ID` | L45 |
| `TEXT_STYLE_FALLBACK` | L46 |
| `TEXT_FONT_SIZE` | L47 |
| `TEXT_MAX_WIDTH` | L48 |
| `TEXT_GAP` | L49 |
| `TEXT_SCREEN_MARGIN` | L50 |
| `TEXT_CONTENT_MARGIN` | L51 |
| `_init() -> void` | L62 |
| `focus(rect: Rect2, text: String = "") -> void` | L78 |
| `clear_focus() -> void` | L94 |
| `is_active() -> bool` | L110 |
| `get_target_rect() -> Rect2` | L115 |
| `get_mask_rects() -> Array` | L123 |
| `get_focus_text() -> String` | L132 |

目标矩形可交互：遮罩用四块纹理拼出目标之外的四边（不开洞、不改 GUI 命中），
目标矩形上再画一圈 focus ring 与一行提示文案。剧情 / 任务等内容只声明语义目标，
由 Shell 解析成真实控件矩形后调用 `focus(rect, text)`。

Full-window guided-focus mask (dev.3 feedback #3: only the one interaction the
tutorial asks for should stay clickable, everything else under a dim veil). The
component is content-agnostic: the caller resolves a semantic target into a
screen rect and passes it in.

## 外观来源（外部贴图 + SNSkin）
- 四块遮罩是 `SNSkin.style("fill_aqua")` 的克隆，`modulate_color` 取
  `SNSkin.color("bg.abyss")` 并压到 `MASK_ALPHA`；高亮边框取
  `SNSkin.style("focus_ring")`、`brass.highlight`；提示底板取
  `SNSkin.style("panel_steel")`，文字 `text.light`。不新增 `StyleBoxFlat`、
  不写十六进制色、不硬编码皮肤路径。
- 皮肤缺失（manifest 为空）时四块遮罩退回 `ColorRect` + 同一个 token 色，
  不给业务脚本留下裸色值。

## 契约与约束
- 根节点 `mouse_filter = IGNORE`；四块遮罩 `STOP`（吃掉目标之外的点击 /
  滚轮 / 拖拽），目标矩形区域没有任何遮罩子节点，因此目标控件仍是该点的最上层
  可交互控件。ring / 提示都是 `IGNORE`，不会抢目标边框附近的点击。
- `focus(rect, text)` 的 `rect` 是**屏幕 / 全局坐标**（Shell 用
  `Control.get_global_rect()` 直接传入）；组件内部转成自身局部坐标，并在
  `NOTIFICATION_RESIZED` 时重新布局，`960×540` 与 `1440×900` 都不会溢出视口。
- `clear_focus()` 立即隐藏并清空目标；`is_active()` / `get_target_rect()` /
  `get_mask_rects()` / `get_focus_text()` 供 Shell 与无头测试断言。
- 该组件不做剧情判定也不发命令：何时显示由 Shell 依据 `story.view.focus`
  决定（剧情卡打开时卡片优先，遮罩不出现）。

模块索引：[framework/ui](../README.md)
