# `framework/ui/skin/sn_skin.gd`

> 作用：UI 皮肤运行时访问层。所有「外部贴图控件」的纹理、九宫格 StyleBox、图标、颜色 token 都从 `assets/ui/skin/<skin>/skin.json` 解析，页面与控件只通过本类取素材，不在代码里写贴图路径或业务色值。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNSkin` | L1 |
| `DEFAULT_SKIN_DIR` | L26 |
| `MANIFEST_NAME` | L27 |
| `SETTING_SKIN_DIR` | L28 |
| `PANEL_ALIASES` | L30 |
| `skin_dir() -> String` | L47 |
| `manifest() -> Dictionary` | L60 |
| `is_available() -> bool` | L79 |
| `style_ids() -> Array` | L83 |
| `icon_ids() -> Array` | L87 |
| `texture(id: String) -> Texture2D` | L92 |
| `icon(id: String) -> Texture2D` | L104 |
| `decor(id: String) -> Texture2D` | L116 |
| `style(id: String) -> StyleBoxTexture` | L129 |
| `panel(kind: String) -> StyleBoxTexture` | L164 |
| `button_style(state: String, variant: String = "secondary") -> StyleBox` | L197 |
| `color(token: String) -> Color` | L253 |
| `font_size(token: String) -> int` | L261 |
| `icon_rect(id: String, logical_size: float = 24.0) -> TextureRect` | L270 |
| `clear_cache() -> void` | L281 |

## 目录契约
- 默认皮肤：`res://assets/ui/skin/sn_v1/`；可用 ProjectSettings `ui/skin_dir` 指向另一套 skin 目录（文件级换肤）。
- `skin.json` 由 `tools/build_ui_skin.ps1` 生成：`styles`（file/texture_margin/content_margin）、`icons`、`colors`、`fonts`。
- 换肤方式：替换 skin 目录内同名同尺寸 PNG（`nine_slice/*`、`icons/*`、`parts/*`）即整体换肤；换九宫格参数或整套新皮肤时重跑生成器并重新导入。

## 核心 API
- `skin_dir()` / `manifest()`：当前皮肤目录与解析后的 manifest（空字典表示皮肤缺失，调用方应回退到无纹理样式）。
- `texture(id)` / `icon(id)` / `decor(id)`：取 Texture2D（带缓存，缺失返回 null）。
- `style(id)`：按 manifest 构造 StyleBoxTexture；固定配件与未知 id 返回 null。
- `panel(kind)`：语义面板 steel / recess / parchment / blueprint / canvas / glass / frame_open。
- `button_style(state, variant)`：state = normal/hover/pressed/disabled/focus，variant = primary/secondary/danger/ghost；Ghost normal 返回 StyleBoxEmpty。
- `color(token)` / `font_size(token)`：颜色与字号 token；缺失时 push_warning 并回退白色/14。
- `icon_rect(id, logical_size)`：直接生成 24px 级图标的 TextureRect，供程序化 UI 使用。

## 约束
- 不在本类之外硬编码 `res://assets/ui/skin/...` 路径；不在业务脚本写十六进制颜色。
- StyleBox 是运行时克隆，调用方可安全修改单个实例；缓存以 id 为键，改皮肤后调用 `clear_cache()`。
- 本类不依赖场景树与渲染，可在 headless 测试中直接使用。

模块索引：[framework/ui](../README.md)
