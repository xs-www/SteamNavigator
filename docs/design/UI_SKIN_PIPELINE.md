# UI 皮肤管线（外部贴图驱动）V1

> 状态：V1 已落地。目标：UI 的材质与图标全部来自 `assets/ui/skin/<skin>/` 下的外部 PNG，页面只引用 Theme / `SNSkin`，**换掉同名同尺寸贴图即可整体换肤**。
>
> 视觉规范仍以 [UI_VISUAL_BASELINE.md](UI_VISUAL_BASELINE.md) 与 [UI_FOUNDATION_SPEC_V1.md](UI_FOUNDATION_SPEC_V1.md) 为准；本文只描述实现管线与换肤操作。

## 1. 一句话流程

```text
docs/design/ui_controls_v1/   30 个控件图集（无字透明，九宫格）
docs/design/ui_icons_v1/      30 个 256×256 透明图标（母版 sn_ui_icons_v1.png，切片器 tools/ui/slice_ui_icons.gd）
        │  tools/build_ui_skin.ps1
        ▼
assets/ui/skin/sn_v1/
  nine_slice/*.png            控件九宫格运行纹理（源区域 0.5×）
  icons/*.png                 128×128 图标（已裁透明留白、居中）
  parts/*.png                 固定比例配件（复选框、滑柄、挂钩…）
  skin.json                   样式/九宫格边距/颜色 token/图标表
        │  同一脚本调用 build_ui_theme.gd
        ▼
assets/ui/theme/steam_navigator_theme.tres   所有控件状态 = StyleBoxTexture / 外部图标
        │
        ▼
framework/ui/skin/sn_skin.gd（SNSkin）      程序化 UI 的纹理/样式/token 访问层
        │
        ▼
Shell / 页面 / 控件                         只写 Theme variation 或 SNSkin API
```

## 2. 换贴图怎么做

### 2.1 只换现有皮肤的贴图（推荐，改代码 0 行）

1. 用同名同尺寸 PNG 覆盖 `assets/ui/skin/sn_v1/nine_slice/` 或 `icons/` 下对应文件。
2. 重新让 Godot 导入（编辑器打开一次，或 `godot --headless --path . --editor --quit`）。
3. 运行 `godot ... --editor --quit` 后直接跑游戏即可；Theme 引用的是固定路径，无需重新生成。
4. 跑一致性门禁：`pwsh ./tools/build_ui_skin.ps1 -Check`（若你只替换了 PNG 而未改母版/参数，这一步会报内容不一致——这是预期：门禁校验的是「母版→运行纹理」可复现性；只换运行纹理时跳过 `-Check`，并在美术分支记录来源）。

> 九宫格边距写在 `skin.json` / Theme 的 `texture_margin_*` 里。**同位置换图必须保持画布尺寸与角件比例**，否则角件会拉伸；需要改边距时走 2.2 重新生成。

### 2.2 换整套皮肤 / 调九宫格参数

1. 复制 `assets/ui/skin/sn_v1/` → `assets/ui/skin/<new_id>/`（或只改母版图集与 `regions.json`）。
2. 生成：`pwsh ./tools/build_ui_skin.ps1 -Skin <new_id>`。
   - 会重新裁切 PNG、写 `<new_id>/skin.json`、并生成指向该目录的 Theme（运行时默认皮肤路径由 `tools/ui/build_ui_theme.gd` 写入）。
3. 若要在运行时切换皮肤 pack（不重生成 Theme），把 ProjectSettings `ui/skin_dir` 指向新目录——这只影响 `SNSkin` 访问的程序化样式；Theme 仍绑定生成时的目录。多皮肤运行时切换留到后续版本（见 §8）。
4. 验收：`-Suite ui_skin` + 两分辨率截图（§7）。

### 2.3 图集母版更新

- 控件母版：`docs/design/ui_controls_v1/sn_controls_atlas_v1.png` + `regions.json`。
- 图标母版：`docs/design/ui_icons_v1/sn_ui_icons_v1.png`（图集）+ `icons/*.png`（切好的 256×256 独立 PNG）+ `manifest.json`（id 列表 / 内容包围盒 / 未映射图标）。
- **图标图集是生成式出图，行高不是整数等分、每行列数也不完全相等，不要用固定等宽/等高网格裁切**。切片统一走 `godot --headless --path . --script res://tools/ui/slice_ui_icons.gd`（先加 `-- --dry-run` 看检测结果）：它按「全透明行/列」分格、取 alpha 内容紧包围盒并居中到 256×256 画布，同时更新 `manifest.json`。旧的固定 256×256 裁切会把下一行图标顶端带进每张 PNG 的底部。
- 改完母版必须跑 `pwsh ./tools/build_ui_skin.ps1`，然后 `-Check`、`-Suite ui_skin`，并提交运行纹理 + `skin.json` + Theme 三者的变化（图标内容变化会连带影响由 `action_confirm` 派生的 `check_*` 复选框图标）。

## 3. 目录与文件契约

| 路径 | 作用 | 谁维护 |
| --- | --- | --- |
| `assets/ui/skin/<skin>/nine_slice/*.png` | 控件九宫格纹理 | 生成器（勿手改） |
| `assets/ui/skin/<skin>/icons/*.png` | 128×128 图标（30 业务 + 4 派生 `check_*`） | 生成器（勿手改） |
| `assets/ui/skin/<skin>/parts/*.png` | 固定比例配件（6） | 生成器（勿手改） |
| `assets/ui/skin/<skin>/skin.json` | 样式/边距/颜色/字号/图标唯一数据源 | 生成器（勿手改） |
| `assets/ui/theme/steam_navigator_theme.tres` | 纹理化 Theme | `build_ui_theme.gd` 生成（勿手改） |
| `framework/ui/skin/sn_skin.gd` | 运行时访问层 `SNSkin` | 手写 |
| `tools/ui/build_ui_skin.gd` | 图集→PNG + skin.json | 手写 |
| `tools/ui/slice_ui_icons.gd` | 图标图集→30 个居中 256×256 母版 + manifest | 手写 |
| `tools/ui/build_ui_theme.gd` | skin.json→Theme | 手写 |
| `tools/build_ui_skin.ps1` | 一键生成 / `-Check` | 手写 |

`skin.json` 结构：

```json
{
  "id": "sn_v1", "version": 1, "scale": 0.5,
  "source": { "controls_atlas": "...", "controls_regions": "...", "icon_dir": "...", "icon_manifest": "..." },
  "colors": { "brass.highlight": "#EDC46D", "text.light": "#F0E4C8", "...": "..." },
  "fonts": { "display": 36, "h1": 28, "body": 15, "...": 0 },
  "styles": {
    "button_normal": { "file": "nine_slice/button_normal.png", "texture_margin": [20,17,20,17], "content_margin": [20,10,20,10] },
    "checkbox_empty": { "file": "parts/checkbox_empty.png", "fixed": true, "size": [62,60] }
  },
  "icons": { "nav_market": "icons/nav_market.png", "...": "..." }
}
```

- `texture_margin` / `content_margin` 单位是**逻辑像素**（源图 0.5× 后）：`texture_margin` 是九宫格不可拉伸边距，`content_margin` 是安全文字区。
- `fixed: true` 的 style 不是 StyleBox，`SNSkin.style(id)` 返回 null；用 `SNSkin.decor(id)` 取纹理。

## 4. Theme 状态映射（唯一来源见 `tools/ui/build_ui_theme.gd`）

| 控件 | 变体 | normal | hover | pressed | disabled | focus |
| --- | --- | --- | --- | --- | --- | --- |
| Button | 默认 / `SNSecondaryButton` | `button_normal` | `button_hover` | `button_pressed` | `button_disabled` | `focus_ring` |
| Button | `SNPrimaryButton` | `button_selected` | `button_hover` | `button_pressed` | `button_disabled` | `focus_ring` |
| Button | `SNDangerButton` | `button_danger` | `button_danger` 提亮 | `button_pressed` | `button_disabled` | `focus_ring` |
| Button | `SNGhostButton` | 空（content 12/4） | `button_normal` α0.45 | `button_pressed` α0.7 | 空 | `focus_ring` |
| Button | `SNCompactButton` | `badge` | `button_hover` | `button_pressed` | `button_disabled` | `focus_ring` |
| Button | `SNPlateButton` | `badge` | `button_hover` | `button_pressed` | `button_disabled` | `focus_ring` |
| Panel | `SNPanel` / `PanelContainer` | `panel_steel` α0.96 | — | — | — | — |
| Panel | `SNElevatedPanel` | `panel_steel` ×1.08，content 24/22 | — | — | — | — |
| Panel | `SNInsetPanel` | `panel_recess` α0.95 | — | — | — | — |
| Panel | `SNGlassPanel` | `panel_steel` α0.62，content 14/12 | — | — | — | — |
| Panel | `SNChromePanel` | `panel_steel` α0.84，content 16/12 | — | — | — | — |
| Panel | `SNStatusBarPanel` | `panel_steel` α0.90，content 14/6 | — | — | — | — |
| Panel | `SNParchmentPanel` | `panel_parchment` | — | — | — | — |
| Panel | `SNBlueprintSheetPanel` | `panel_blueprint` | — | — | — | — |
| Panel | `SNCanvasPanel` | `panel_canvas` | — | — | — | — |
| Panel | `SNBlueprintPanel` | 既有 `blueprint_panel.png`（56/54、66/62） | — | — | — | — |
| Badge | `SNBadge`/`SNSuccessBadge`/`SNWarningBadge` | `badge` + tone 染色 | — | — | — | — |
| Badge | `SNDangerBadge` | `badge_danger` | — | — | — | — |
| Progress | `ProgressBar` / `SNBrassProgressBar` | 槽 `meter_trough` + 填充 `meter_fill_amber` | — | — | — | — |
| Progress | `SNWaterProgressBar` | `meter_fill_aqua` | — | — | — | — |
| Progress | `SNDangerProgressBar` | `meter_fill_rust` | — | — | — | — |
| Input | `LineEdit` | `input_recess` | — | — | 只读 0.82× | 提亮 1.22× |
| Scroll | `V/HScrollBar` | 槽 `scrollbar_track`，滑块 `scrollbar_grabber` | 提亮 | 压暗 | — | — |
| Check | `CheckBox` | `check_empty` / `check_checked` 图标 | — | — | `check_*_disabled` | — |
| 其他 | `TooltipPanel` / `PopupPanel` / `TabBar` | steel / recess / button 纹理 | — | — | — | `focus_ring` |

`SNTitleLabel` 使用系统衬线字体回退链（Noto Serif SC → Source Han Serif → SimSun → YaHei）；其余文字保持无衬线。

### 派生纹理（图集未单独提供、由生成器合成）

`fill_rust`（危险填充）、`badge` / `badge_danger`（小铭牌 / Badge / 侧牌）、`meter_trough` + `meter_fill_amber|aqua|sage|rust`（10–14px 资源条）、`cell_recess`（18–22px 密集表格单元格，如情报矩阵）、`scrollbar_track` / `scrollbar_grabber`、`check_empty|checked|*_disabled`（20×20 复选框图标）、`focus_ring`（黄铜焦点描边）。

纸面（Parchment）上的 Ghost 按钮必须把文字颜色覆盖为 `ink.primary` / `brass.shadow`（`victory` / `new_game` / `story_card` / `clue_log` 已处理）；钢制背景继续使用默认浅色 Ghost 文字。

## 5. SNSkin API（程序化 UI 唯一入口）

```gdscript
SNSkin.panel("steel" | "recess" | "parchment" | "blueprint" | "canvas" | "glass" | "chrome" | "status_bar")
SNSkin.button_style(state, "primary" | "secondary" | "danger" | "ghost" | "compact")
SNSkin.style(id)                  # 按 skin.json 构造 StyleBoxTexture
SNSkin.icon(id) / SNSkin.decor(id)
SNSkin.color("text.light")        # 颜色 token（禁止业务脚本写十六进制）
SNSkin.font_size("label")
SNSkin.icon_rect(id, 24.0)        # 直接可用的 TextureRect
```

禁止事项：
- 业务脚本/控件里出现 `StyleBoxFlat.new()`（Theme 已无 flat；数据可视化绘制除外，绘制颜色必须来自 token）；
- 出现 `res://assets/ui/skin/...` 硬路径或业务十六进制颜色；
- 绕开 Theme 手搓 `add_theme_stylebox_override("normal", ...)` 三态按钮。

## 6. 图标语义与缺口

30 个业务图标（`icons/`）+ 4 个派生复选框图标（`check_*`，由 `checkbox_empty` 底 + `action_confirm` 勾派生，theme 直接引用文件，不进 `skin.json` 业务图标表）。

已接线位置：顶部 HUD 资源 chip、已发布导航页（总览 / 市场 / 委托 / 船厂 / 酒馆）+ 海图、侧牌设施、船厂 7 类分类与三个操作页签、菜单/结算/委托/补给/遗迹等行动按钮。

内容侧调用：同一套 30 枚图标也复制进 Core 包（`dev_mods/core/assets/icons/ui/*.png`）并登记为 `icon.ui.<id>` 资源键，内容 JSON / 事件 / 后续系统可直接写 `information.texture: "icon.ui.nav_market"` 或 `AssetService.find_key("icon.ui.nav_market")`；Core 副本与运行图标由 `test_mod_loading::test_core_registers_the_ui_icon_set` 逐字节守同步（见 [ASSET_MAP.md](ASSET_MAP.md)「UI 图标资源键」）。

> 2026-10-26：基地 / 贸易 / 遗迹三个未发布系统不再出现在玩家导航
> （`main.gd` 的 `HIDDEN_NAV_SCREENS`），下表仍保留给内部页面（截图 / 未来重新发布）
> 的图标语义参考；遗迹属于航行探索玩法，后续应在探索侧接入而非港口导航。

已知缺口（需要美术后补，当前用语义近似 id）：
- 导航：总览 → `status_anchor`、基地 → `shipyard_hull`、自动贸易 → `status_route`、遗迹 → `nav_chart`（与海图重复；基地 / 贸易 / 遗迹入口当前隐藏）。
- 船厂：utility → `shipyard_navigation`、weapons → `nav_shipyard`、misc → `nav_shipyard`。
- 行动：购买/补满 → `action_confirm` 或 `resource_coins`、修复 → `action_add`、等待 → `status_time`；缺 repair/buy/sell/wait 专用图标。
- 状态：风险等级用 `status_warning` 近似；`status_weather/status_storm` 目前没有消费点（项目尚无天气系统）。
- 布旗 `flag_*`（6 个）已生成但当前 64×36 紧凑导航与 172×42 侧牌都放不下，保留给后续布局改版（出航确认/主导航）。
- 内容专属图标（商品、设施、港口）仍走内容模组 `manifest.assets` 的 `icon.*` 机制，不在全局皮肤里。

## 7. 验证门禁

```powershell
# 母版 → 运行纹理 / Theme 的可复现性
pwsh ./tools/build_ui_skin.ps1 -Check

# 皮肤契约测试（manifest、九宫格、图标、variation、token、SNSkin API、无 flat 守门）
& ./tools/test.ps1 -Suite ui_skin

# 全页面截图（1440×900 + 960×540，各 26 张）
pwsh ./tools/capture_ui.ps1 -AllScreens

# 静态文档
node tools/gen_static_docs.mjs && node tools/gen_static_docs.mjs --check
```

截图输出：`docs/design/screenshots/skin/<1440x900|960x540>/<name>.png`（该目录被 `.gitignore` 忽略，作为本地验收证据；需要入库时 `git add -f`）。

## 8. 边界与后续

- V1 的「换贴图」是**运行纹理级**：Theme 引用固定 `sn_v1` 路径；多套皮肤运行时切换需要重生成 Theme 或后续做 `Theme` 动态重建。
- 保留绘制（非 UI 材质，属于数据/内容表现）：`sn_sea_chart_view`（海面/陆地/迷雾/航线/港口）、`sn_ship_view` 线稿与槽位、`sn_sparkline` 折线、`sn_cloud_veil` 演出云；它们的颜色已 token 化，贴图不参与换肤。
- 九宫格纹理不内嵌文字/状态色；状态色仍由 Theme 与 `modulate_color` 表达。
- 换肤后必须复核固定层预算：TopChrome ≤130px、PortStatusBar 高 60、侧牌 172×42、PageMargin 20/14/20/56；低于 38px 高的按钮用 `SNCompactButton`/`SNPlateButton`，不要套标准按钮九宫格。
- `assets/ui/tokens.json` 是旧原型 token 快照，运行期唯一数值来源已改为 `assets/ui/skin/sn_v1/skin.json`。
