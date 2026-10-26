# 市场界面重构 · 图标直接交互（V1）

> 状态：**V1 已落地（2026-10-24）**。目标：把市场里的「数字 + 买卖按钮」改成 Bounty Train 式的直接操作——点图标累计数量，拖到落点完成交易；市场页同时变成「左侧玩家船背包 / 中间 3D 港区窗口 / 右侧市场」。
>
> 交互与数据契约以本文为准；视觉规范仍遵循 [UI_SKIN_PIPELINE.md](UI_SKIN_PIPELINE.md) 与 [UI_VISUAL_BASELINE.md](UI_VISUAL_BASELINE.md)。

## 1. 布局

```text
┌──────────────────── 市场页（PageScroll 内） ────────────────────┐
│ ┌─ 船只背包（CargoHoldPanel 360） ┐  ┌ 3D 港区窗口 ┐  ┌ 市场（DockPanel 640） ┐ │
│ │ 载重 / 货舱摘要                  │  │ StageWindow  │  │ 标题 · 金币 / 重量 / 货舱摘要 │ │
│ │ 船舱货物  [icon][icon][icon] …  │  │ 透明、不吃  │  │ 行情网格 [icon][icon][icon]  │ │
│ │ 港口仓库  [icon][icon] …        │  │ 鼠标        │  │ 补给（煤 / 水）卡片           │ │
│ └─────────────────────────────────┘  └─────────────┘  └──────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

- 左侧 `SNCargoHoldPanel`：玩家船「背包」= 船舱货物（`ship.cargo`，含委托货物但不可拖拽）+ 当前港仓库材料。
- 中间 `StageWindow`：透明 `Control`，继续复用现有 `PortStage` 市场站位（`STATIONS.market`、`_stage_framing = "panel"`），后续可替换为 3D 船内交互。
- 右侧 `MarketScreen`：行情网格 + 补给区块；整个市场面板同时是「卖出」落点。
- 3D 舞台不可用时（`_stage_backed_page() == false`），页面退化为「船只背包 + 市场」两栏，不出现空白舞台窗口。

## 2. 交互契约

数量只作为「待交易数量」存在于图标上，不再有买卖按钮；主手势是**拿起 / 放下**
（v0.2.0-dev.3 反馈 #1），原生拖拽保留为兼容手势：

| 操作 | 结果 |
| --- | --- |
| 左键点市场图标 | 待交易数量 +1（受 `stock` / `buyable` 限制），同时进入「拿起」：图标 + ×数量浮在鼠标指针旁（`SNCarryGhost`） |
| 左键点船舱 / 仓库区 | 放下：执行 `trade.buy {amount = 待交易数量, destination}`；点落点内的货物格子同样生效（格子把点击转给 `drop_host`） |
| 右键（页面任意处） | 取消拿起：清空该图标待交易数量并收起光标幽灵 |
| 右键点图标 | 清空该图标待交易数量（与取消拿起同一语义） |
| 拖拽图标 | 携带 `max(待交易数量, 1)`；拖拽预览显示图标 + 名称 + ×数量（兼容手势，拖拽期间隐藏光标幽灵） |

拖拽落点与命令（点击落点的 `dropped` 载荷与拖拽完全一致）：

| 拖拽来源 | 落点 | 命令 |
| --- | --- | --- |
| 市场商品图标 | 左侧「船舱货物」区 | `trade.buy {item_id, amount, destination: "cargo"}` |
| 市场商品图标 | 左侧「港口仓库」区 | `trade.buy {item_id, amount, destination: "warehouse"}` |
| 船舱货物图标 | 右侧市场面板 | `trade.sell {item_id, amount, source: "cargo"}` |
| 港口仓库图标 | 右侧市场面板 | `trade.sell {item_id, amount, source: "warehouse"}` |
| 船舱货物图标 | 左侧「港口仓库」区 | `warehouse.store_materials {item_id, amount}` |
| 港口仓库图标 | 左侧「船舱货物」区 | `warehouse.take_materials {item_id, amount}` |

约束：

- 委托货物（`contract_id` 非空）不可拖拽、不可卖、不可存仓，图标显示锁定标记。
- 市场里 `buyable=false` 或 `stock<=0` 的品种不可拖拽（仍可显示，标明「仅收购」）。
- 命令成功后由 Shell 统一 `_refresh()` 重建页面，待交易数量与光标幽灵随之重置；失败时沿用状态栏错误提示（顶部 banner 保留，同时 `SNInteractionHint` 在光标处浮出同一条文本，见 [交互处浮出提示](#交互处浮出提示dev3-反馈-4)）。
- 拖拽 / 落点高亮只改 `SNSkin` 纹理 `modulate_color`，不新增 `StyleBoxFlat`、不写十六进制色值。
- 光标幽灵与浮出提示都挂在 Shell 的全窗浮层（`HintLayer`，`PageScroll` 之外、转场淡出层之下），全部 `MOUSE_FILTER_IGNORE`，不吞落点点击。

### 拿起 / 放下组件契约

```text
MarketScreen.carry_changed(offer)                # offer {} = 未携带
  → Shell._show_carry_ghost(offer)               # SNCarryGhost.begin(icon, name, amount, hint)
  → SNCargoHoldPanel.set_offer(offer)            # 转发给两个 SNDropZone
       → SNDropZone.set_offer(offer)             # 仅接受 accept_kinds 的载荷，命中即高亮
玩家左键落点
  → SNDropZone._gui_input(release) → try_click_offer()
  → dropped(offer) → SNCargoHoldPanel.handle_*_drop() → trade.buy / warehouse.*
```

- `SNItemTile.drop_host` 指向所在 `SNDropZone`：落点内的货物格子是
  `MOUSE_FILTER_STOP`，点击先交给 `drop_host.try_click_offer()`，被消费就不再给格子 +1。
- 切换携带：新格子 pending > 0 时先 `clear_pending()` 旧格子（先清 `_carry_tile`
  防重入），保证同时只有一个格子被拿起。
- 右键取消走 `MarketScreen._input`；`_clear()`（页面重建）丢弃携带引用，Shell 在
  `_rebuild_ui_body()` 开头收起幽灵。
- 原生拖拽与点击放下共用 `dropped` 契约；`Viewport.gui_is_dragging()` 期间幽灵隐藏，
  避免和原生拖拽预览叠两个图标。

### 交互处浮出提示（dev.3 反馈 #4）

`SNInteractionHint`（`framework/ui/components/sn_interaction_hint.gd`）是**框架级**
组件，任何页面都能调用 `show_at(at, message, is_error)`：

- Shell 的 `_set_status()` 在「run 内的港口页面 + 玩家交互命令」时额外调用它，
  文本沿用同一条本地化消息（顶部 banner 保留，仍是持久状态的契约）；
  菜单、剧情卡、航行演出、页面淡出期间不弹。
- 浮层是 Shell 的 `HintLayer`（全窗、`MOUSE_FILTER_IGNORE`、在 `PageScroll` 之外、
  转场淡出层之下）：960×540 与 1440×900 都不会被裁切，也不吞光标下的点击。
- 位置在指针上方（`place_at()` 纯函数，钳制在视口内），`HOLD_SECONDS` 后
  `FADE_SECONDS` 淡出；新消息会重置计时。
- 外观只用 `SNSkin.style("panel_steel")` + `brass.highlight` / `state.danger` 染色与
  `action_confirm` / `status_warning` 图标，不新增 `StyleBoxFlat`、不写十六进制色。


## 3. `market.view` 查询契约

新增查询 `market.view`（`MarketViewQuery`，注册于 `QueryRegistry`），复用 `PortViewQuery.execute` 的行情行，再补充船舱 / 仓库与图标键：

```gdscript
{
  "has_run": bool,
  "at_port": bool,
  "current_port": { "id": String, "name_key": String },
  "money": int,
  "ship": {
    "total_weight": float, "max_weight": float,
    "cargo_used": float, "cargo_capacity": float,
    "free_weight": float, "free_cargo_capacity": float,
    "cargo_cost_basis": float, "coal": float, "water": float,
    "hold": [{
      "item_id": String, "name_key": String, "category": String,
      "crafting_material": bool, "unit_weight": float,
      "amount": int, "sellable_amount": int,
      "is_contract": bool, "contract_id": String,
      "avg_cost": float, "icon_key": String
    }]
  },
  "market": [ /* port.view 行情行 + "icon_key" */ ],
  "trends": { item_id: "up" | "down" | "stable" },
  "warehouse": {
    "port_id": String,
    "materials": [{
      "item_id": String, "name_key": String, "category": String,
      "crafting_material": bool, "unit_weight": float,
      "amount": int, "icon_key": String
    }]
  }
}
```

- `icon_key` 取 `ContentDefinition.information["texture"]` 的逻辑资产键（如 `icon.item.iron_ore`），为空表示内容没提供图标。
- 展示层（Shell）负责把 `icon_key` 解析成 `Texture2D` 填到每一行的 `"icon"` 字段：`AssetService.find_key` → `AssetService.load_texture`，缺失时回退 `res://assets/ui/icons/item_fallback.svg`。
- `trends` 沿用现有 `_market_trends()` 的语义：来自 `intel.view` 当前港报告的价格趋势；无报告时为空字典，页面按 `stable` 处理。

## 4. 物品图标（临时占位）

正式图标尚未产出，本轮用内容模组资产 + SVG 占位：

- `dev_mods/core/assets/icons/items/<local_id>.svg`：10 个贸易货物 / 材料图标（铜、纺织、香料、木材、玻璃器、铁矿石、锅炉板、精密齿轮、密封剂、委托货箱）；煤 / 水沿用现有 `icon.coal` / `icon.water` PNG。
- `dev_mods/core/content/items.json` 的 `information.texture` 写入 `icon.item.<local_id>`；`dev_mods/core/manifest.json` 注册对应 `icon.item.*` 资产键。
- 框架不硬编码 `core:*` ID：图标键由内容定义提供，Shell 只认逻辑键；内容缺失时回退框架通用占位 `assets/ui/icons/item_fallback.svg`。
- 美术替换时保持同名键与 1:1 画布即可整体替换，不需要改页面代码。

## 5. 命令层扩展

```text
trade.buy  { item_id, amount, destination?: "cargo" | "warehouse" }   # 默认 cargo
trade.sell { item_id, amount, source?: "cargo" | "warehouse" }        # 默认 cargo
```

- `destination="warehouse"`：校验商品可买、库存、金币后直接写入当前港仓库材料区，不占船上载重 / 货舱（`WarehouseOps.add_material`）。
- `source="warehouse"`：从当前港仓库材料区扣减后卖出（`WarehouseOps.remove_material`），船舱不变。
- 非法 `destination` / `source` 返回 `Result.fail("invalid_destination" | "invalid_trade_source", "ui.error.invalid_destination" | "ui.error.invalid_trade_source")`，事务不提交。
- 命令结果与 `market.changed` 事件载荷携带实际落点，供状态栏与后续表现层使用。

## 6. 验收

```powershell
# 领域命令
pwsh ./tools/test.ps1 -Suite market_trade
pwsh ./tools/test.ps1 -Suite warehouse_craft
# UI 接线
pwsh ./tools/test.ps1 -Suite ui_shell
pwsh ./tools/test.ps1 -Suite ui_views
pwsh ./tools/test.ps1 -Suite ui_skin
# 视觉证据（1440×900 / 960×540）
pwsh ./tools/capture_ui.ps1 -Screens "market" -Resolution "1440x900,960x540"
# 静态文档
node tools/gen_static_docs.mjs --check
```

截图输出在 `docs/design/screenshots/skin/<res>/market.png`（该目录被 `.gitignore` 忽略，作为本地验收证据）。

### V1 验收结果（2026-10-24）

- Godot 全量 **665/665** 通过（新增 13 例：`market_trade` 9、`ui_shell` 20、`ui_views` 9、`mod_loading` 7；含 `ui_skin` 9/9 的外观守门）。
- `capture_ui.ps1 -Screens "market" -Resolution "1440x900,960x540"` 两分辨率通过：三栏布局、4 列图标网格、船舱 / 仓库落点与 3D 港区窗口均正常，无横向裁切。
- `node tools/gen_static_docs.mjs --check` 通过；`node tools/check_content_schema_v2.mjs` 通过（42 active + 3 draft，2.0 only）。
- 已知边界：格子 `max_pending` 只按港存 / 可售 / 仓库存量限制，不预扣金币与剩余载重，超限由命令失败并在状态栏提示；补给卡按钮本轮保留。

## 7. 后续（不在本轮）

- 从 3D 港区窗口推进到「3D 船内」：左侧背包面板可退化为 3D 船体的货舱热点，交互仍是同一套 `market_item` / `cargo_item` 拖拽载荷。
- 补给（煤 / 水）也用图标直接交互；本轮保留补给卡按钮（见 [UI_SKIN_PIPELINE.md](UI_SKIN_PIPELINE.md) 的卡片规范）。
- 市场商品按分类分组 / 筛选、买卖音效与拖拽动效。

### V1.1 已落地（2026-10-24）：拿起 / 放下 + 交互处浮出提示

- 反馈 #1：市场图标左键「拿起」后，图标 + ×数量由 `SNCarryGhost` 跟随鼠标；
  船舱 / 仓库落点被 arm（高亮），左键落点即 `trade.buy`，右键取消；原生拖拽保留。
- 反馈 #4：命令成功 / 失败的瞬时反馈由 `SNInteractionHint` 在鼠标处浮出并短淡出，
  顶部 banner 继续保留；Shell 通过 `_set_status()` 统一触发，页面无需各自接线。
- 本节的「分类筛选 / 音效 / 动效」与「补给图标化」仍未做，留给市场 V2。

