# 迭代 2 · MVP 反馈优化 — 实现契约与决策记录

> 来源：`docs/MVP反馈.md`（玩家 Xiao_Si_swx 的 6 条试玩反馈）。
> 基线：Framework 0.1.0 · Core 1.0.0 · Schema 1.0 · 迭代 1（MVP 闭环）已完成。
> 本文是实现期契约，代码完成后同步进静态文档。

## 0. 反馈 → 方案对照

| # | 反馈 | 方案 | 主要落点 |
| --- | --- | --- | --- |
| 1 | 低级部件不应消耗材料，只需金钱 | tier1 配方改为「仅金币」，并给 tier1 补 `craft_cost` | Core JSON、`CraftOps.craftable` |
| 2 | 补给比例条会因买另一项而「上涨」 | 上限改为稳定物理上限，上限损失用灰/红反向条表示 | `SupplyViewQuery`、`SNResourceMeter`、`SNSupplyCard` |
| 3 | 情报栏需要与市场合并成对比表 | 商品 × 港口对比矩阵 + 新表格组件 | `IntelService`、`IntelViewQuery`、`SNIntelTable` |
| 4 | 打造等耗时操作应能在本港等待完成 | 打造改为订单 + `port.wait` 在港等待，让时间流动可感知 | `CraftOps`、`PortCommands`、`VoyageService` |
| 5 | 信息显示需要当前港口与剩余容量 | 顶部信息条增加「当前港口 + 剩余载重 + 剩余货舱」 | `PortViewQuery`、`main.gd` |
| 6 | 完成主线后不知道如何通关 MVP | 常驻「通关条件」清单 + 主线完成后的醒目提示 | `PortViewQuery`、`main.gd` |

## 1. 需求澄清（用户确认）

1. **反馈 3 的未探索港口**：用户答复「整列不显示是指整列信息不显示。还是要告诉玩家有港口未探索的」。
   → 未探索港口**保留整列**，列名显示「未知港口」，该列所有单元格显示 `？`。
   `-` 仅表示「该港既不收购也不出售该商品」。
2. **反馈 4 的等待**：用户答复「现在主要是玩家无法感知到时间流动」。
   → 打造不再瞬间完成：下单扣材料与金币、生成带工时的订单，时间到位才入库；新增 `port.wait` 让玩家主动推进时间，
   并让市场（NPC 商船）与委托期限随之变化，使时间流动可感知且有代价。

## 2. 数值与内容（Core JSON，框架不写死）

- `dev_mods/core/content/*.json` 中 7 个可打造且 `tier == 1` 的模块：`materials = []`，新增 `craft_cost`：
  （`materials.json` 里唯一的 `tier: 1` 条目是打造材料，不是模块，不计入。）

  | 模块 | purchase_price | craft_cost | craft_time_hours |
  | --- | --- | --- | --- |
  | `core:hull/small_efficient` | 380 | 170 | 4 |
  | `core:boiler/small_efficient` | 420 | 190 | 4 |
  | `core:boiler/standard` | 650 | 290 | 5 |
  | `core:cabin/passenger_cabin` | 600 | 270 | 4 |
  | `core:cargo_module/small_hold` | 260 | 120 | 3 |
  | `core:navigation_module/spyglass` | 300 | 140 | 2 |
  | `core:safety_module/lifeboat` | 280 | 130 | 2 |

- tier2 / tier3 配方与数值**不变**。

## 3. 领域与应用层

### 3.1 `CraftOps`（修改）

- `craftable(hub, module_id) -> bool`：类型属于 `CRAFTABLE_TYPES` 且（`materials` 非空 **或** `craft_cost > 0`）。
  因此 tier1 的「仅金币」配方可打造，且不会返回 `missing_materials`。
- `craft(state, hub, module_id) -> Dictionary`：仍即时扣除材料（当前港仓库优先，再扣船上非委托货物）与 `craft_cost`（计入支出），
  但**不再** `advance_time`、**不再**立刻入库；生成订单并返回 `order_id / ready_at / remaining_hours / orders`，
  事件 `ship.craft_ordered`。
- `ensure_orders(state)`：幂等补齐 `state.data.shipyard_orders`（数组）与 `order_serial`（int），旧存档兼容。
- `settle_orders(state, hub) -> Array`：`ready_at <= now` 的订单入库到**下单港口**的仓库（`WarehouseOps.add_module`），
  推 notice `ui.notice.craft_completed`，返回完成明细。

### 3.2 `PortCommands`（新）— `port.wait`

| 命令 | 参数 | 行为 | 错误码 |
| --- | --- | --- | --- |
| `port.wait` | `hours`（int，1..240） | 校验在港 → `advance_time(hours)` → `CraftOps.settle_orders` → `NpcTraderSimulator.advance`（命名流含 port+时间）→ `DebtService.check_overdue` → notice `ui.notice.waited`；事件 `port.waited` 与完成订单的 `ship.module_crafted` | `not_at_port`、`invalid_hours` |

data：`{hours, game_time, time_label, completed_orders[], npc_events[], debt_events[]}`（不含 `port_id`；界面用事件 payload 里的 `port_id` 或当前港兜底）。

### 3.3 `VoyageService`（修改）

- 时间推进路径后调用 `CraftOps.settle_orders`：`VoyageService` 在**抵达结算**一次性推进整段航时并结算订单（出航本身不推进时间），`port.wait` 与 `craft()` 开头同样结算，因此航行/等待都会让订单推进，回到下单港即可取件。

### 3.4 `SupplyViewQuery`（修改）

每个资源按「稳定物理上限」计算，避免共享载重导致比例上涨：

```text
base_weight       = total_weight − coal_weight − water_weight
baseline_capacity = floor((max_weight − base_weight) / unit_weight)        # 另一项为空时的上限
capacity          = floor((max_weight − base_weight − other_weight) / unit_weight)
cap_loss          = max(0, baseline_capacity − capacity)
max_buy           = max(0, min(capacity − current, port_stock, floor(money / price)))
```

新增导出：`capacity`、`baseline_capacity`、`cap_loss`、`headroom`；既有字段（`current / fill_to / maximum / max_buy / fill_cost / blockers / estimated_days / unit_weight`）保持兼容。

### 3.5 `IntelService` / `IntelViewQuery`（修改）

- 快照 market 行增加 `trend_percent`（最近 8 条价格首尾变化率）。
- `intel.view` 新增：
  - `columns`：当前港口第一列，其后为已发现港口、未发现港口（各按 port_id 排序）；
    每列 `{port_id, name_key, discovered, visited, is_current, in_snapshot, age_hours}`。
  - `rows`：商品全集（当前港普通商品 ∪ 快照普通商品，按 item_id 排序）；
    每行 `{item_id, name_key, unit_weight, ref_price, cells[]}`。
  - `cell`：`{port_id, known, buy_price, sell_price, trend, trend_percent}`。
    价格口径与 `MarketOps` 一致：**港口收购价（玩家卖出）= floor(price × DEFAULT_TRADE_MARGIN)**，
    **港口出售价（玩家买入）= buyable 时 round(price)，否则 −1**。`−1` 由 UI 显示为 `-`；`known == false` 显示 `？`。
    当前港口列使用**实时市场**，其它港口使用情报快照并标注快照年龄。

## 4. 表现层

### 4.1 顶部信息条（反馈 5）

`_build_stats_bar` 显示：**当前港口**（在航时为「在航 → 目的港」）、时间、金币、声誉、**剩余载重（可载 / 上限）**、
**剩余货舱（可装 / 上限）**、煤炭、淡水、耐久。`port.view.ship` 新增 `free_weight`、`free_cargo_capacity`。

### 4.2 通关引导（反馈 6）

`port.view.victory.conditions`（来自 `VictoryService.conditions`）与 `contracts.main_done / main_total` 驱动一个常驻清单：

- 总览「当前目标」面板与船厂页顶部都显示：完成 5 段主线（n/5）→ 大型船体（tier 3）→ 锅炉 → ≥1 货舱 → 在造船厂完成组装。
- 主线全部完成时给出醒目提示：「主线已完成，前往造船厂组装大型船即可通关。」
- 条件全部满足时提示「条件已满足：安装模块即触发通关。」

### 4.3 补给页（反馈 2）

`SNSupplyCard` 把 `capacity / baseline_capacity / cap_loss` 传给 `SNResourceMeter`；
`loss_value > 0` 时进度条改为三分段：填充（当前）、空余、**损失带（从右边缘起的灰/红半透明反向段）**，
`loss_value == 0` 时保持原主题进度条（耐久/货舱不受影响）。

### 4.4 情报页（反馈 3）

`_screen_intel` 改用 `SNIntelTable`：表头 = 商品 / 单位重量 / 参考价 / 各港口列；单元格 = `收购价/出售价`；
`-` = 该港不经营；`？` = 未探索或情报未覆盖；趋势用红降/绿升的百分比数字（不再显示「看涨/看跌」文字）；当前港口列高亮。

### 4.5 船厂页（反馈 4）

- 打造按钮显示「下单打造 · X h」；仅金币配方显示「仅需金币，不消耗材料」。
- 新增「打造订单」面板：进行中订单与剩余工时、**在港等待 6/12/24 小时**按钮与时间代价提示。
- 总览「快捷入口」同样提供 6/12/24 小时等待按钮。

## 5. 测试

- 更新：`test_warehouse_craft`（下单不推进时间/不入库 → 等待后入库）、`test_ship_upgrade`（tier1 `craft_cost`）、
  `test_supply`（上限单调、cap_loss、比例不上涨）、`test_ui_views`（intel 矩阵结构）。
- 新增：`test_craft_wait`（tier1 仅金币打造、订单结算、`port.wait` 边界、旧存档补齐）、
  `test_ui_shell`（信息条/通关/订单+等待/补给损失带/情报矩阵 5 条接线，外加通报文案真实渲染与 `push_notice` 键的中英一致性 2 条）。

## 6. 实现结果

无头测试：**96 passed / 0 failed / 96 total**（Godot 4.7.2 headless，退出码 0，连续两次一致）。
命令：`godot --headless --path . --script res://framework/tests/test_runner.gd`
（迭代 1 基线为 74 passed；本次新增 `test_craft_wait` 8 例、`test_ui_shell` 7 例，并扩写 `test_warehouse_craft` / `test_ship_upgrade` / `test_supply` / `test_ui_views`。）

逐条反馈的验收证据：

| 反馈 | 实现 | 守护用例 |
| --- | --- | --- |
| 1 · 低级部件只要钱 | 7 个 tier1 模块 `materials: []` + `craft_cost`；`CraftOps.craftable()` 接受「无材料但有金币成本」的配方 | `test_craft_wait::test_tier1_module_needs_only_money` |
| 2 · 比例条不因买另一项而上浮 | `SupplyViewQuery` 输出稳定 `capacity` / `baseline_capacity` / `cap_loss` / `headroom`；`SNResourceMeter` 在 `loss_value > 0` 时自绘「填充 + 空 + 右端反向损失带」 | `test_supply`（上限单调、cap_loss）、`test_ui_shell::test_supply_screen_paints_the_lost_capacity_band` |
| 3 · 情报页合并为商品 × 港口矩阵 | `IntelViewQuery` 输出 `columns`（含未探索列）/`rows`/`cells` + `trend_percent`；`SNIntelTable` 渲染 `-`、`？`、红降/绿升数字与当前港高亮 | `test_ui_views`（矩阵结构/未探索掩码）、`test_ui_shell::test_intel_screen_renders_the_port_comparison_table` |
| 4 · 让玩家感知时间流动 | 打造变为订单（`shipyard_orders`/`order_serial`，下单不动时间、不入库）；`port.wait`（1..240h）+ 船厂/总览 6/12/24 小时等待按钮；抵达亦结算 | `test_craft_wait`（边界/结算/旧存档）、`test_warehouse_craft`、`test_ui_shell::test_shipyard_order_and_port_wait_make_time_move` |
| 5 · 显示当前港口与剩余容量 | 顶部信息条常显「当前港口（在航时为 在航 → 目的港）」+「剩余载重」+「剩余货舱」 | `test_ui_shell::test_stats_bar_shows_the_current_port_and_remaining_capacity` |
| 6 · 主线完成后如何通关 | 总览与船厂常驻通关清单（主线 n/5 → 大型船体 → 锅炉 → ≥1 货舱 → 造船厂组装）+ 主线完成后的下一步提示 | `test_ui_shell::test_victory_plan_explains_how_to_clear_the_mvp` |

### 6.1 独立验证（T5，只读）与修复

第三方（`verify-iter2`，只读、自写探针、不复用实现者用例）分三轮复核：6 条反馈全部 PASS（用原始重量/价格复算、`VictoryService.conditions` 逐项对照、存档 hash 与确定性比对），并独立确认 25/25 套件真实执行、**96/96 全绿、退出码 0**（第一轮当时为 94 例）。发现的**用户可见文案缺陷**已在交付前修复：

| 缺陷 | 现象 | 修复 |
| --- | --- | --- |
| `port.wait` 状态栏参数序 | 中文实测「在 6.0 等待了 铁港 小时。」 | `main.gd` 改为 `[港口, 小时]`，与模板一致 |
| `ui.notice.craft_ordered` 英文模板序 | 英文实测「Ordered Iron Harbor at Small Hold …」 | en 模板改为 `Ordered at %s: %s · …`（对齐代码参数序） |
| 「航行记录」显示裸模板 | 面板出现「· 在 %s 等待了 %s 小时。」等三条 | 新增 `_notice_text()`：按 `push_notice` 参数替换模板、字符串参数先作本地化键解析；`craft_completed` 参数序改为 `模块 → 港口` |
| 三个通报键缺失 | 面板出现「· ui.notice.run_started」等裸键 | 补齐 `discovered_port` / `run_started` / `no_contract_offer`；`arrived` 改为带港口名 |

配套守护（不依赖编辑器）：

- `test_ui_shell::test_notice_log_renders_filled_localized_text`：真实下单 + 等待后，对 **zh 与 en 各渲染一次**（用例显式 pin locale，因为外壳 locale 取自玩家存档设置），逐行断言无 `%s/%d` 残留、无裸键，并与**逐语言写死的期望句子**相等。为什么必须是字面期望：槽位互换的模板照样能渲染成句（`Waited %s hours at %s.` 也会输出一句通顺英文），只有字面期望能抓住「某一种语言的文案说反了」。已做变异验证：把 en 模板改回错误顺序 → 该用例在 en 那条断言上 FAIL，zh 遍仍 PASS。
- 上面的模板相等断言叠加源码里全部 `push_notice("<key>"` 字面量的键/槽位校验：`test_every_pushed_notice_key_is_localized_in_both_languages` 断言每个键**恰好被一套 locale 定义**，且中英键集合与**保序**槽位序列一致（把 `%d` 挪位即失败）。
- 同时按验证意见把信息条/情报用例的期望值改为独立复算（`RegistryHub` 翻译 + `ShipOps` 重量/舱容 + `MapOps.ports`），去掉 3 处「被测函数给自己出题」的自证式断言。

与契约的偏差 / 实现说明：

- **tier1 模块数量为 7 而不是 8**：`dev_mods/core/content/materials.json` 中唯一 `tier: 1` 的条目是打造**材料**（不是可打造模块），故只有 7 个模块获得「仅金币」配方。
- **订单只入下单港仓库**：跨港订单不转运；抵达其它港口只会结算该港的订单，符合「在哪下单在哪取」的直觉，也避免玩家忘记取货。
- **`port.wait` 的 NPC 随机流键未变**：仍为 `npc_trade::<npc_id>`（同 seed + 同命令序列完全可复现，已由确定性用例守护）；若日后要让「等待时段/港口」参与派生，需同时更新 `NpcTraderSimulator` 并补确定性用例（已记入 `todo.md`）。
- **测试运行器改为在首个渲染帧执行**：`test_runner.gd` 从 `SceneTree._initialize` 迁移到首帧 `_process`。原因：`_initialize` 阶段场景树尚未进入可挂载状态（`root.add_child` 会被「busy setting up children」拒绝），UI 套件无法获得真实的 `_ready` / viewport 语义。迁移后所有 25 个套件仍在同一进程内执行，退出码为 0，既有用例结果不变。
- **未做视觉确认**：无头环境无法截图，反馈 2/3 的颜色与布局（损失带宽度、红降/绿升配色）由 `test_ui_shell` 的组件级断言与自绘区间断言守护，最终观感建议在编辑器内跑一次 `main.tscn` 复核。
- **本地化**：新增 UI 文案统一走 `framework/localization/{zh_CN,en}.json`（335 键，中英键集合与**保序**槽位序列一致，由测试守护）；`main.gd` 中与迭代 1 同风格的少量页面内嵌文案保持不变（如设施/时间行）。

### 6.2 已知残余风险（第三方复核记录，均不阻断）

- **通报渲染是「宽进」策略**：`_notice_text` 在槽位数量不符、`%d` 槽位收到非数字、或缺键时**原样显示模板/键名**，而不是抛格式错误（避免每帧整页刷新时报错）。这些情况在 UI 上表现为裸模板或裸键，仓库内无运行时告警，只由用例守护；若希望生产日志也能发现，可加一条限频 `logger.warn`。
- **跨语言顺序回归**由「字面期望」守护，且该守护被**强制覆盖**：扫描用例要求所有 `push_notice` 键里**槽位多于一个**的键必须出现在逐语言字面期望清单中（新增多槽位通报时如果忘了补期望，套件会直接失败并指明该键）；单槽位文案的顺序无从分歧。当前 7 个键中 3 个多槽位键均已在清单内。
- **`_format_slots` 每次渲染新建 `RegEx`**（最多 6 条通知 × 每次整页重建），开销可忽略；如需优化可提为 `static var`。
- **小时数格式不统一**：通知面板显示 `6 小时`（int 参数），顶部状态栏显示 `6.0 小时`（`_fmt` 的 `%.1f`）。仅观感差异。
- **测试环境依赖玩家存档 locale**：外壳 `_ready` 会用 `user://config/config.json` 的 `locale` 覆盖本地化（本机为 `en`）。凡断言具体文案的用例都应像 `test_notice_log_renders_filled_localized_text` 一样显式 pin locale，否则结果随机器状态而变。
- **旧存档/异常数据**：`order_serial` 为 float 时按 int 归一化（一次性）；`shipyard_orders` 若被外部改成非数组会被静默忽略（宁可丢订单也不崩界面）。
- **无头环境不覆盖真实像素**：布局溢出、英文长串换行、动画语言切换（tween）路径未端到端验证，建议真机/编辑器跑一次 `main.tscn` 复核观感。