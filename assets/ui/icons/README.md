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

## 母版更新

图标母版在 `docs/design/ui_icons_v1/`（`icons/*.png` 256×256 + `manifest.json` 的 id 列表）。更新后运行 `pwsh ./tools/build_ui_skin.ps1` 重新生成，并跑 `-Check` 与 `-Suite ui_skin`。
