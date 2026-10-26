# `framework/ui/components/sn_weapon_socket_target.gd`

> 作用：蓝图上的单个武器槽位贴片：两行自绘（槽位短标签 + 已装武器名 / 空槽位），

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNWeaponSocketTarget` | L1 |
| `weapon_dropped (signal)` | L46 |
| `hovered (signal)` | L48 |
| `unhovered (signal)` | L50 |
| `CARD_PADDING` | L52 |
| `TITLE_FONT_SIZE` | L53 |
| `VALUE_FONT_SIZE` | L54 |
| `TITLE_BASELINE_RATIO` | L56 |
| `VALUE_BASELINE_RATIO` | L57 |
| `TEXT_BAND_INSET_X` | L61 |
| `TEXT_BAND_INSET_Y` | L62 |
| `TEXT_BAND_ALPHA` | L63 |
| `TEXT_OUTLINE_SIZE` | L64 |
| `TEXT_OUTLINE_ALPHA` | L65 |
| `CORNER_LENGTH` | L66 |
| `DRAG_SOURCES` | L67 |
| `SOCKET_PREFIX` | L68 |
| `configure(slot_row: Dictionary) -> void` | L92 |
| `set_highlighted(active: bool) -> void` | L128 |
| `set_drop_enabled(enabled: bool) -> void` | L137 |
| `socket_name() -> String` | L146 |
| `slot_label() -> String` | L150 |
| `display_name() -> String` | L155 |
| `display_text() -> String` | L160 |
| `is_occupied() -> bool` | L164 |
| `is_highlighted() -> bool` | L168 |
| `is_drop_hovering() -> bool` | L172 |
| `is_drop_enabled() -> bool` | L176 |
| `accepts_payload(data: Variant) -> bool` | L182 |

区分空槽 / 已装 / 高亮 / 拖拽悬停四种状态，并作为 `ship_weapon` 拖放落点。

## 状态语义
- 空槽：`panel_recess` 凹槽底板 + 暗色蒙版 + `text.muted` 文字；已装：`panel_steel`
  钢板 + `brass.base` 黄铜蒙版 + 亮色文字。两种状态的底板与第二行文字始终不同；
  高亮 / 悬停只改描边与青色蒙版，不会把已装与空槽画成同一种颜色（旧版小框把两者
  都涂成青色，玩家装配后看不出变化）。
- `set_highlighted(true)`（武器分类 / 右侧卡片 hover）：青色描边 + 四角标记。
- 拖放兼容悬停（`_can_drop_data` 返回 true）：更粗的青色描边 + 青色角标，表示当前
  载荷可以落在本槽位。

## 拖放载荷契约
- 只接受 `{kind:"ship_weapon", weapon_id, weapon_class, source, name}`：
  `weapon_class` 必须等于本行 `socket_class`（大小写不敏感），
  `source ∈ {warehouse, purchase}`；已装同一 `weapon_id` 时拒绝（避免重复安装）。
- `_drop_data` 把**完整载荷**与**槽位行字典**一起从 `weapon_dropped` 发出；
  `SNShipView` 汇总成 `weapon_drop_requested`，页面据此发 `ship.install_weapon`。
- 贴片默认接受拖放；页面用 `set_drop_enabled(false)` 关闭非武器分类 / 非装配页签的
  接收。可见性由 `SNShipView` 的模式与布局决定，与是否接受拖放无关。

## 字段契约（`configure(row)`）
- 必含：`socket`、`socket_class`、`weapon_id`、`display_name`、`slot_label`、
  `empty_text`、`occupied`；可选：`slot_title`（完整本地化炮位名，作 tooltip）、
  `view`（"side" / "top"，由 SNShipView 注入）。
- 旧调用兜底：缺 `slot_label` 用 socket 名尾部（`SN_Socket_Weapon_Port_1` → `Port 1`），
  缺 `display_name` 用 `name_key` / `weapon_id`，缺 `empty_text` 用 `"Empty"`，
  缺 `occupied` 按 `weapon_id` 是否为空推断；归一化后的字段写回 `row`。

## 外观来源（外部贴图 + SNSkin）
- 颜色只取 `SNSkin.color(token)`，底板只用 `SNSkin.style("panel_recess" /
  "panel_steel")`；本文件不写十六进制色、不自建 StyleBoxFlat。
- 36 px 贴片避不开九宫格 19 px 的黄铜角饰：两行文字下方有 `bg.abyss` 低透明内衬带，
  并带 2 px 深色描边（`draw_string_outline`），长武器名按可用宽度截断并加省略号，
  文字不再压角饰。
- 全部自绘、无子节点；尺寸由 `SNShipView.weapon_socket_display_rects()` 决定，
  本控件不设 custom_minimum_size。

模块索引：[framework/ui](../README.md)
