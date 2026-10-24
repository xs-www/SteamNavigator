# `tools/ui/build_ui_skin.gd`

> 作用：把 `docs/design/` 下的 UI 控件图集与图标图集切成运行纹理，输出到 `assets/ui/skin/<skin>/`，并写 `skin.json`（样式/九宫格/颜色 token/图标表）。这是「外部贴图驱动 UI」的唯一素材入口：页面与 Theme 只引用本脚本产出的 PNG，换同名同尺寸贴图即可整体换肤。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SCALE` | L30 |
| `DEFAULT_SKIN` | L31 |
| `SKIN_ROOT` | L32 |
| `CONTROL_ATLAS_PATH` | L33 |
| `CONTROL_REGIONS_PATH` | L34 |
| `ICON_DIR` | L35 |
| `ICON_MANIFEST_PATH` | L36 |
| `CHECK_ROOT` | L37 |
| `COLORS` | L40 |
| `FONT_SIZES` | L65 |
| `CONTENT_MARGINS` | L77 |
| `FIXED_IDS` | L111 |
| `DERIVED_STYLES` | L114 |
| `_init() -> void` | L137 |

## 用法
```powershell
godot --headless --path . --script res://tools/ui/build_ui_skin.gd -- [--skin=sn_v1] [--check]
```
- 默认输出 `res://assets/ui/skin/sn_v1/`；`--skin=<id>` 选择输出目录。
- `--check`：生成到 `user://ui_skin_check/` 并与已提交文件逐字节比对（PNG + skin.json），不覆盖仓库文件；有任何差异退出码 1。改完图集/参数后必须让 `--check` 通过。

## 输入
- `docs/design/ui_controls_v1/sn_controls_atlas_v1.png` + `regions.json`（30 个控件区域，源图像素坐标）。
- `docs/design/ui_icons_v1/icons/<id>.png`（30 个 256×256 透明图标；manifest.json 只用于校验 id 列表）。
- 颜色/字号 token 内置于本脚本（与 `docs/design/UI_FOUNDATION_SPEC_V1.md` §6/§7 对应），随 skin.json 输出，供 SNSkin 与主题生成器共用。

## 输出契约
- `nine_slice/<id>.png`：控件九宫格纹理，源区域 0.5× 缩放；`texture_margin` 为缩放后的九宫格边距，`content_margin` 是安全文字区（逻辑像素）。
- `parts/<id>.png`：固定比例配件（复选框、滑柄、挂钩、绳环、纸夹、蜡封），不做九宫格。
- `icons/<id>.png`：128×128 图标（已裁掉透明留白并居中，便于 24/28/32 逻辑像素显示）。
- 派生件：`fill_rust`（危险填充）、`badge`/`badge_danger`（小铭牌）、`meter_trough`/`meter_fill_*`（仪表用低边距槽/填充）、`scrollbar_track`/`scrollbar_grabber`、`check_*`（复选框 20×20 图标）、`focus_ring`（黄铜焦点描边）。
- `skin.json`：`id/version/scale/colors/fonts/styles/icons/parts/source`；styles 每项含 `file/texture_margin/content_margin/modulate`，是 Theme 生成器与 SNSkin 的唯一数据源。

## 约束
- 生成必须确定性：固定排序、无时间戳、JSON `sort_keys`，同一输入重复运行逐字节一致。
- 不要手改 `assets/ui/skin/` 下的 PNG / skin.json；改图集或本脚本后重新生成。
- 源母版留在 `docs/design/`，运行时只用派生副本（与 blueprint_panel 的做法一致）。

模块索引：[tools](../README.md)
