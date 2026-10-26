# `framework/ui/components/sn_weapon_socket_card.gd`

> 作用：船厂改装操作坞里的单个武器槽位卡：显示本地化炮位名 / 武器等级、已装武器或空槽位、卸下按钮，并作为 `ship_weapon` 拖放落点（等级匹配才接受），把玩家意图交回船厂页。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNWeaponSocketCard` | L1 |
| `weapon_dropped (signal)` | L31 |
| `command_requested (signal)` | L32 |
| `hovered (signal)` | L33 |
| `unhovered (signal)` | L34 |
| `CONTENT_MARGIN` | L36 |
| `configure(row: Dictionary) -> void` | L50 |
| `is_dragover() -> bool` | L57 |
| `weapon_text() -> String` | L62 |

One weapon mount card in the shipyard operations dock.

The screen lists the same sockets on the blueprint chips (`SNShipView`), so the
card is a second, larger drop target for players who drag from the warehouse /
purchase list: it never executes commands itself, it only validates the socket
class and forwards `weapon_dropped(payload, socket)` or `command_requested`.

## 外观来源（外部贴图 + SNSkin）
- 底板取 `SNSkin.style("panel_recess")`；拖入兼容武器 / 悬停时换 `panel_steel`
  并以 `modulate_color = SNSkin.color("state.water")` 高亮；内容边距固定 8 / 6。
- 已装状态用 `SNBadge`（SUCCESS 变体）+ `text.light` 武器名；空槽用 `text.muted`。
- 不写十六进制色、不手搓 StyleBoxFlat。

## 契约与约束
- `configure(row)` 接收 `{socket, socket_class, occupied, display_name, slot_title,
  slot_label, empty_text, weight, damage, can_uninstall, drop_hint}`；字段全部由
  船厂页本地化后传入，本组件不访问注册表 / 不翻译。
- 接受拖放载荷 `kind == "ship_weapon"`：`weapon_class` 必须等于本槽位
  `socket_class`，且不能是「已装同型同 id」；`_drop_data` 只发
  `weapon_dropped(payload, socket)`。
- `hovered` / `unhovered` 用于让船厂页高亮左侧蓝图上的同名贴片。
- 卸下按钮只发 `command_requested(&"ship.uninstall_weapon", {socket})`。

模块索引：[framework/ui](../README.md)
