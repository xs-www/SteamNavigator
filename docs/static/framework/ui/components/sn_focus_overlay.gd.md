# `framework/ui/components/sn_focus_overlay.gd`

> 作用：框架级「强制引导」遮罩（v0.2.0-dev.3 反馈 #3）。全屏半透明遮罩只留一个

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNFocusOverlay` | L1 |
| `MASK_STYLE_ID` | L53 |
| `MASK_TINT_TOKEN` | L54 |
| `MASK_ALPHA` | L55 |
| `RING_STYLE_ID` | L57 |
| `RING_TINT_TOKEN` | L58 |
| `RING_PAD` | L59 |
| `TEXT_STYLE_ID` | L61 |
| `TEXT_STYLE_FALLBACK` | L62 |
| `TEXT_FONT_SIZE` | L63 |
| `TEXT_MAX_WIDTH` | L64 |
| `TEXT_GAP` | L65 |
| `TEXT_SCREEN_MARGIN` | L66 |
| `TEXT_CONTENT_MARGIN` | L71 |
| `_init() -> void` | L83 |
| `focus_target(target: Control, text: String = "") -> void` | L108 |
| `refresh_target() -> void` | L122 |
| `focus(rect: Rect2, text: String = "") -> void` | L140 |
| `clear_focus() -> void` | L146 |
| `is_active() -> bool` | L184 |
| `get_target_rect() -> Rect2` | L189 |
| `get_mask_rects() -> Array` | L197 |
| `get_focus_text() -> String` | L206 |

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
- `SNSkin.style()` 返回的是按 id 缓存的**共享** StyleBox：所有 `modulate_color`
  与 `content_margin` 覆盖都只在 `duplicate()` 出来的克隆上做，避免改到其他面板用的
  同一份皮肤（曾直接 mutate 缓存实例）。
- 皮肤缺失（manifest 为空）时四块遮罩退回 `ColorRect` + 同一个 token 色，
  不给业务脚本留下裸色值。

## 目标追踪与自愈（2026-10-28 P0）
- `focus_target(control, text)` 绑定真实目标控件：每帧 `refresh_target()` 重新读
  `get_global_rect()`，容器排版 / resize / 页面重建导致目标移动时框自动追上；
  目标被释放、隐藏或矩形归零时立即 `clear_focus()` 并解绑，不留悬空引用。
- Shell 在页面重建后仍会做两次 deferred 重同步（兜底目标语义重解析 / 页面挂载顺序），
  但位置正确性不再依赖那一帧的同步快照。
- `focus(rect, text)` 保留给没有控件可绑定的调用方（如组件单测）；它会解绑目标，
  不再逐帧自愈。
- 提示板高度按字体实测换行结果计算（`clip_text` + 明确 `custom_minimum_size`），
  不受 Label 尚未拿到最终宽度时的过期最小高度影响（曾把提示板撑到 387 px 高）。
- 提示板内容边距取 24/8：水平 24 px 让文字避开 `panel_steel` 九宫格 19 px 黄铜
  角饰（12 px 时首字会压在角饰上，看起来像被裁掉）。

## 契约与约束
- 根节点 `mouse_filter = IGNORE`；四块遮罩 `STOP`（吃掉目标之外的点击 /
  滚轮 / 拖拽），目标矩形区域没有任何遮罩子节点，因此目标控件仍是该点的最上层
  可交互控件。ring / 提示都是 `IGNORE`，不会抢目标边框附近的点击。
- `focus(rect, text)` 的 `rect` 是**屏幕 / 全局坐标**（Shell 用
  `Control.get_global_rect()` 直接传入）；组件内部转成自身局部坐标，并在
  `NOTIFICATION_RESIZED` 与目标移动时重新布局，`960×540` 与 `1440×900` 都不会溢出视口。
- `clear_focus()` 立即隐藏、清空目标并解绑；`is_active()` / `get_target_rect()` /
  `get_mask_rects()` / `get_focus_text()` 供 Shell 与无头测试断言。
- 该组件不做剧情判定也不发命令：何时显示由 Shell 依据 `story.view.focus`
  决定（剧情卡打开时卡片优先，遮罩不出现）。

模块索引：[framework/ui](../README.md)
