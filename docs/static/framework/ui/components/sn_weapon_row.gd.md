# `framework/ui/components/sn_weapon_row.gd`

> 作用：船厂武器分类里的可拖行武器条目：显示本地化武器名、等级 / 重量 / 伤害与来源标签，仓库武器 / 购买候选都可通过它拖到蓝图炮位或右侧槽位卡；可选行内操作按钮（安装到指定炮位、购买并安装）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNWeaponRow` | L1 |
| `command_requested (signal)` | L31 |
| `activated (signal)` | L33 |
| `drag_started (signal)` | L35 |
| `TAG_MIN_WIDTH` | L37 |
| `configure(data: Dictionary) -> void` | L57 |
| `drag_payload() -> Dictionary` | L74 |

One draggable weapon row in the shipyard refit operations dock.

`SNPartRow` owns the module (`ship_parts`) drag contract; weapons are a
separate content type with their own command (`ship.install_weapon`) and a
socket-class gate, so they get their own row instead of overloading the module
payload. The row only paints the data and owns the `ship_weapon` drag payload:
the shipyard screen decides which sockets are offered and emits the command.

## 外观来源（外部贴图 + SNSkin）
- 底板取 `SNSkin.style("panel_recess")`；可拖行 / 悬停时换 `panel_steel` 并用
  `modulate_color = SNSkin.color("state.water")` 染色；内容边距固定 8 / 4，保持旧行高。
- 文字色全部取 `SNSkin.color(token)`，不写十六进制色、不新增 StyleBoxFlat。
- 尺寸约束：标题 13、meta 11、提示 10；标题省略号截断，不撑宽固定宽度操作坞。

## 契约与约束
- `configure(data)` 接收 `{title, tag, tag_color, meta, hint, draggable,
  payload: Dictionary, actions?: Array}`；`payload` 必须带顶层
  `kind == "ship_weapon"`（`weapon_id` / `weapon_class` / `source`）。
- `actions` 条目：`{text: String, command: StringName, params: Dictionary, disabled?: bool}`；
  点击只发 `command_requested`，不写状态。
- `drag_payload()` 返回副本（测试可直接调用）；`_get_drag_data()` 复用同一份载荷并挂预览。
- 拖拽只表达意图：class 匹配、重量 / 金币 / 仓库数量由落点与命令层校验。

模块索引：[framework/ui](../README.md)
