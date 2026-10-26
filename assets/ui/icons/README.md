# UI Icons

全局业务图标由 `docs/design/ui_icons_v1/` 生成，运行文件在 `assets/ui/skin/sn_v1/icons/`（128×128，已裁透明留白并居中）。

## 已生成图标（30 + 4 派生）

- `nav_*`：market / contracts / shipyard / resupply / intelligence / chart / departure
- `resource_*`：coins / coal / water / durability / cargo
- `shipyard_*`：hull / boiler / cargo / navigation / safety / cabin
- `action_*`：add / remove / confirm
- `status_*`：warning / locked / unlocked / anchor / time / weather / storm / reputation / route
- 派生（theme 直接引用，不写入 skin.json 业务图标表）：`check_empty` / `check_checked` / `check_empty_disabled` / `check_checked_disabled`

## 使用

- 程序化 UI：`SNSkin.icon(id)` + `SNSkin.icon_rect(id, 24)`；按钮用 `Button.icon` + `icon_max_width`（16–20）。
- 图标本身已带墨线与材质色，不要再统一 tint；禁用态由按钮/Theme 的 modulate 表达。
- 最小推荐显示尺寸 24px（主 HUD 可 28–32）；20px 以下会丢失手绘细节。
- 语义缺口与临时映射见 [docs/design/UI_SKIN_PIPELINE.md §6](../../../docs/design/UI_SKIN_PIPELINE.md)。

## Core 资源键（`icon.ui.*`）

同一套 30 枚图标也复制进 Core 包（`dev_mods/core/assets/icons/ui/*.png`，与运行图标逐字节一致），并在 `dev_mods/core/manifest.json` 登记为 **`icon.ui.<id>`** 资源键，方便内容 / 后续系统按 key 调用：

- 内容 JSON：`"information.texture": "icon.ui.nav_market"`（与 `icon.item.*` 同一套解析规则）。
- 运行时：`AssetService.find_key("icon.ui.nav_market")` → `asset://core/icon.ui.nav_market`。
- 同步门禁：`test_mod_loading::test_core_registers_the_ui_icon_set` 逐字节比较 Core 副本与运行图标；重切母版后除了重新生成皮肤，还要把 `assets/ui/skin/sn_v1/icons/*.png` 复制到 `dev_mods/core/assets/icons/ui/`。

## 母版更新

图标母版在 `docs/design/ui_icons_v1/`（图集 `sn_ui_icons_v1.png` + 切好的 `icons/*.png` 256×256 + `manifest.json`）。

1. 图集有变化时先重新切片（先 `--dry-run` 看检测结果）：
   `godot --headless --path . --script res://tools/ui/slice_ui_icons.gd`
   —— 生成式图集不能按固定等分网格裁切，脚本按「全透明行/列」分格并取内容紧包围盒居中，同时更新 `manifest.json`。
2. 再运行 `pwsh ./tools/build_ui_skin.ps1` 重新生成运行图标 / Theme，并跑 `-Check` 与 `-Suite ui_skin`。
3. 复制 30 张运行图标到 `dev_mods/core/assets/icons/ui/`，并确认 Core manifest 的 `icon.ui.*` 声明与 `test_mod_loading` 同步门禁通过。
