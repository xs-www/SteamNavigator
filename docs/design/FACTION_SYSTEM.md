# 势力 / 自由模式玩法（Faction System）

> 状态：**Draft 0.1（2026-10-26）**。自由模式势力玩法的设计契约；剧情模式（固定地图固定流程）共用同一套规则，差异只来自内容与初始状态。
>
> 前置与相关：[FULL_GAME_ROADMAP.md](FULL_GAME_ROADMAP.md)、[WORLD_SCHEMA_V2_RUNTIME.md](WORLD_SCHEMA_V2_RUNTIME.md)、[NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md)、[ROUTE_UNLOCK_SYSTEM.md](ROUTE_UNLOCK_SYSTEM.md)、[STORY_MODE.md](STORY_MODE.md)、[BASE_SYSTEM.md](BASE_SYSTEM.md)。
>
> 内容真源：[factions.json](../../dev_mods/core/content/factions.json)、[faction.schema.json](../../schemas/v2/faction.schema.json)、[contracts.json](../../dev_mods/core/content/contracts.json)、[port_templates.json](../../dev_mods/core/content/port_templates.json)；运行态：[game_state.gd](../../framework/state/game_state.gd)、[contract_ops.gd](../../framework/domain/contracts/contract_ops.gd)、[faction_assembler.gd](../../framework/domain/campaign/faction_assembler.gd)。

## 0. 决策记录（2026-10-26）

| 项 | 结论 |
| --- | --- |
| 版本节奏 | **剧情模式先做**（固定地图、固定流程，作为第一版公开模式）；**自由模式**（随机大地图、无主线、纯模拟经营）先作为玩法系统的试验场，不进入第一版公开模式，但长期可玩性按自由模式验收。 |
| 名望 / 关系 | **名望**（`player.reputation`）是存档积分/成就分，用于结算与评分；**关系**（`campaign.factions[*].reputation`）才是衡量具体势力友好程度的数值。两者分离，不再互相代替。 |
| 玩家组织层 | **本期不做**（加盟/公司/等级/总部/代理人留到 P2 以后）。势力玩法的「组织」侧先由许可证与港口准入承担。 |
| 世界唯一真相 | 港口归属、准入、势力海域全部从唯一海图/世界数据派生，不引入第二套地图拓扑（沿用 [NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md) 与 [ROUTE_UNLOCK_SYSTEM.md](ROUTE_UNLOCK_SYSTEM.md) 的不变量）。 |

## 1. 定位与目标

势力玩法不是再加一套平行数值，而是给现有「跑商—接单—出航—战斗—基地」加一层**世界反应**：

1. **立场有代价**：帮一方必然得罪其对手（`rival_factions`），但保留低收益、低风险的「中立商人」路线。
2. **关系即权限**：关系不是分数，而是准入、税费、委托条款、禁运品、装备获取方式。
3. **海图有主人**：港口归属于势力或自由城邦，势力海域需要许可证才能深入。
4. **长期可玩性**（自由模式验收目标）：没有任何主线的情况下，玩家仍会因为「关系—许可—特产—走私—装备」持续做取舍，而不是只剩刷钱。

## 2. 现状与差距

| 已有 | 位置 | 差距 |
| --- | --- | --- |
| `factions` 内容类型（kind / attitude_thresholds / patrol_strength / trade_goods / home_region_tags / rival_factions） | [faction.schema.json](../../schemas/v2/faction.schema.json)、[factions.json](../../dev_mods/core/content/factions.json) | `trade_goods` / `patrol_strength` / `rival_factions` 尚无运行消费 |
| 运行态 `campaign.factions[id] = {reputation, attitude, discovered, met_at}` | [game_state.gd](../../framework/state/game_state.gd) L216–278、[faction_assembler.gd](../../framework/domain/campaign/faction_assembler.gd) | 只有装配器读写，规则层不消费；没有许可证、没有关系变更源 |
| 全局 `player.reputation` 驱动委托上限与模块 `unlock_reputation` | [contract_ops.gd](../../framework/domain/contracts/contract_ops.gd) L297–300、[ship_ops.gd](../../framework/domain/ship/ship_ops.gd) L485 | 与「名望=存档积分」的新定位冲突，需要解耦/迁移 |
| 委托模板、奖励、期限、迟到只扣奖金 | [contracts.json](../../dev_mods/core/content/contracts.json)、[contract_ops.gd](../../framework/domain/contracts/contract_ops.gd) L214–270 | 没有发起方、没有关系条款、没有迟到罚金 |
| 港口有模板、设施、市场库存与 `price_bias` | [port_templates.json](../../dev_mods/core/content/port_templates.json) | 没有 owner、准入、禁运、势力特产；自由港/公开港/限制港不存在 |
| 航线解锁（委托/剧情/酒馆买图） | [ROUTE_UNLOCK_SYSTEM.md](ROUTE_UNLOCK_SYSTEM.md) | 没有「势力海域通行权」这一层门禁 |
| 航行事件 DSL（条件/效果 op） | [condition_op_registry.gd](../../framework/domain/events/condition_op_registry.gd)、[effect_op_registry.gd](../../framework/domain/events/effect_op_registry.gd) | 没有势力关系/许可证相关的条件与效果 |
| 舰队/基地/自动贸易/遗迹（D2–D5） | [FULL_GAME_ROADMAP.md](FULL_GAME_ROADMAP.md) | 后续都需要接势力门禁（P2+） |

> 关键约束：**内容定义不进存档，运行态只追加 ID 与原始数值**；港口归属、准入、特产优先由「唯一世界 + 内容」派生，不改 `WorldMap` 序列化，避免存档迁移面扩大。

## 3. 自由模式开局：6 港准入模型

### 3.1 开局状态

自由模式开局时玩家**已知 6 个港口**：

| 类型 | 数量 | 说明 |
| --- | --- | --- |
| 初始自由港 | 3 | 玩家出生海域的自由城邦，无 owner、无准入限制；开局三者互相已测绘航线。 |
| 势力公开港（准入港） | 3 | 每势力 1 个，位于该势力海域边缘，**无需许可证即可进出**；开局已发现、已测绘航线，是指向势力腹地的跳板。 |
| 其余港口 | 隐藏 | 势力限制港与野外/遗迹港；海图上不可见，需要许可证揭示、情报/线索、探索发现。 |

### 3.2 三类港口与准入

| 港口类型 | owner | 是否需要许可证 | 允许内容 |
| --- | --- | --- | --- |
| 自由港 | 无 | 否 | 全部交易、委托（中立为主）、酒馆/黑市、无港口禁运检查（但可能有风险事件） |
| 公开港 | 势力 | 否 | 基础交易与补给；可**购买该势力通行许可证**；限制设施（高级船厂/势力装备）按关系开放 |
| 限制港 | 势力 | 是（该势力许可证） | 势力特产、势力装备、势力委托、更深层线索；敌对关系下直接拒绝入港 |

> 「势力范围内航行」在当前的**点对点航线**模型里落地为「进出该势力限制港的资格」。未来若做坐标自由航行/海域边界，再把门禁升级为「航线穿越海域」，本层接口不变。

### 3.3 通航许可证（navigation permit）

- 在任一**公开港**的港务页购买（玩家必须在该港）。
- 费用内容化：`factions.data.permits[]` 的 `cost`（默认 300–600，按势力经济强弱）；关系低于该势力 `hostile_below` 时**不可购买**。
- 购买效果（一次性买断、不退还）：
  1. 写入 `campaign.factions[id].permits`；
  2. **直接揭示该势力 1 个限制港**并写进海图发现列表；
  3. 自动测绘「当前公开港 ↔ 该揭示港」航线（`WorldOps.unlock_route`），保证买完立刻能出航，不会出现「看得见但走不了」；
  4. 该势力限制港此后可作为出航目的地/起点（除非态度回到 hostile）。
- 剩余限制港：通过酒馆情报、线索、探索发现；发现只揭示海图，**仍需正常测绘航线**（酒馆买图/委托自带海图/剧情效果），与既有「发现不解锁航线」规则一致。
- 敌对时：已购买的许可证保留，但态度降到 `hostile` 后限制港拒绝入港；关系回到非敌对自动恢复（不重复收费）。

### 3.4 海域与港口归属的生成

- 区域（`campaign.world.regions[]`）已经带 `definition_id`，区域内容（`regions.data.factions[]`）给出势力归属；**港口 owner 从所在区域派生**，不写入 `WorldMap`。
- 自由模式 `world_profile` 建议默认：`region_count 6 / port_count 15 / faction_count 3`。
  - 1 个自由区域（3 个自由港）；
  - 3 个势力区域（每区域 4 港：1 公开 + 3 限制）；
  - 2 个边陲区域（无港口或仅遗迹/基地点，负责探索纵深）。
- 生成期新增硬约束（`CampaignFactory` 校验 + 失败重试，测试守护）：
  - 每个势力恰好 1 个公开港、≥2 个限制港；
  - 公开港 = 该势力所有港口中离自由区域最近的港口（按航程/坐标确定性排序）；
  - 开局 6 港（3 自由 + 3 公开）全连通且航线已测绘（初始 `unlocked_route_keys` 直接写入 15 对）；
  - 限制港至少 1 个可被许可证揭示、至少 1 个留给探索；
  - 边陲区域 `port_density = 0`，不参与港口分配。
- **自由模式需要独立的「势力领地配额」分配步骤**（新增装配器或在 `CampaignFactory` 内按配额分配港口），不能沿用 [region_assembler.gd](../../framework/domain/campaign/region_assembler.gd) 的纯 `port_density` 加权：先按势力区域配额（1 公开 + 3 限制）分港口，再按「离自由区域最近」确定公开港，最后按港 id 稳定性决定揭示/探索候选。
- 生成链前置改造：`MapGenerationSpec.MAX_PORTS_THIS_SLICE` 当前为 **5**，且 `_chart_world_profile` 硬编码 5 块陆地布局（[map_generation_spec.gd](../../framework/domain/campaign/map_generation_spec.gd)、[campaign_factory.gd](../../framework/domain/campaign/campaign_factory.gd) L374–416）；自由模式 15 港需要先扩布局、上限与生成约束，再谈内容。
- 生成元数据写 `campaign.world.faction_territory = { <faction_id>: { region_ids: [], open_port_ids: [] } }`（只存 ID，可惰性补齐）；不写 `world_map`。

### 3.5 开局与模式

- 自由模式 = 无主线、`tutorial=false`、自由 start profile（内容标签 `start.mode.free`）；菜单从内容枚举 `start_profiles` 标签生成入口，框架不写死 `core:*` ID。
- 剧情模式 = `start.mode.story` + 固定地图关卡（依赖 [STORY_MODE.md](STORY_MODE.md) S2/S4 的固定地图加载链，不在本文范围）；势力规则同一套，许可证/关系由剧情效果授予与调整。
- 第一版公开发布只开放剧情模式；自由模式先在开发构建中开放（或菜单标注「测试」），验收长期可玩性后再决定公开时机。

## 4. 关系模型

### 4.1 名望与关系

| 概念 | 存档字段 | 语义 | 驱动 | 用途 |
| --- | --- | --- | --- | --- |
| 名望 | `player.reputation`（沿用字段） | 船长个人成就积分 | 委托完成、大型发现、通关、战斗、遗迹 | 结算/评分/成就；**不再作为各势力友好度** |
| 关系 | `campaign.factions[id].reputation`（`[-100,100]`） | 该势力对玩家的好感 | 派系委托、走私、战斗、许可证、捐献 | 准入、税费、委托条款、禁运品、装备解锁 |
| 态度 | `campaign.factions[id].attitude` | `hostile / neutral / friendly`（阈值来自内容） | 由关系派生（`FactionAssembler.attitude_for`） | UI 与规则门禁的粗粒度判断 |

- 关系变更**只经命令/事件**：`FactionService.adjust_relation(faction, delta, reason)`，内部做 clamp、rival 传播、态度重算、事件发布；UI 只读。
- rival 传播：对 A 的 `delta` 以其 `rival_factions` 为对手，按内容 `rival_factor`（默认 0.5）反向施加：`delta_rival = -round(delta * rival_factor)`；双方都受 clamp。
- 本期**不做自然衰减**（避免玩家离线回来发现关系变了）；衰减留作后续可选项。
- `discovered` / `met_at`：首次在港口或事件中接触时置位；未接触的势力不在 UI 展示具体关系。

### 4.2 关系变更源（P0/P1）

| 来源 | 变化 | 备注 |
| --- | --- | --- |
| 完成势力委托 | 发起方 `+relation_reward`，对手 `-relation_reward * rival_factor` | 模板字段，默认 +2 |
| 委托迟到/违约 | 发起方 `-2`（可内容化） | 与迟到罚金区分：关系是长期代价 |
| 走私被查获 | owner `-8` | 与罚金同时结算 |
| 敌对势力船只被击沉 | 该势力 `-10`，其对手 `+3` | D1 战斗已可结算；航行遭遇接线在 P1 |
| 购买许可证 | 该势力 `+2` | 只算一次 |
| 捐献/投资（P1） | 按金额 `+1..+5` | 有每日/每港上限，防刷 |
| 剧情/事件效果 | 内容指定 | 新效果 op `add_faction_relation` |

## 5. 委托发起方与关系条款

### 5.1 数据

- 模板新增可选 `issuer: { faction: <faction_id> }`；缺省 = **中立委托**（独立委托人/自由港商会）。
- 实例生成时快照 `issuer` 与条款（`deadline_mul / reward_mul / late_penalty_mul`），保证存档后条款不随关系漂移（同类「奖励在生成时锁定」的既有约定，见 [contract_ops.gd](../../framework/domain/contracts/contract_ops.gd) 头注释）。
- 委托出现位置：
  - 中立模板：所有有 `contracts` 设施的港口；
  - 势力模板：该势力港口（公开/限制）必出；自由港按「友好/中立」低权重出现（掮客）；
  - 敌对势力模板：只在自由港掮客处少量出现，明确标注敌对条款，避免「敌对势力公开招募你」的叙事矛盾。
- 委托生成的目的地必须**当前可访问**（自由港/公开港/已购许可的限制港），避免生成玩家进不去的委托。

### 5.2 关系条款

| 态度 | 期限 | 基础报酬 | 迟到罚金 | 说明 |
| --- | --- | --- | --- | --- |
| friendly | ×1.25（更长） | ×1.15（更高，按关系线在这条带内插值） | ×1.0 | 长期合作红利 |
| neutral | ×1.0 | ×1.0 | ×1.0 | 基准 |
| hostile | ×0.8（更短） | **×1.0（不降基础报酬）** | ×1.5（额外扣款） | 用期限与罚金体现风险，不用降报酬激怒玩家 |

- 数值放内容：`map_configs.data.faction_contract_terms`（全局风格），模板可覆盖单项。
- **迟到罚金（本次补实现）**：当前 `complete()` 迟到只失去 `on_time_bonus`（[contract_ops.gd](../../framework/domain/contracts/contract_ops.gd) L214–270），没有额外扣款。新增：
  - 实例字段 `late_penalty_rate`（每小时按基础报酬的比例，如 5%）与 `late_penalty_cap`（如基础报酬 40%）；
  - `payout = max(0, base + bonus(准时) - compensation - late_penalty)`；
  - 罚金与「迟到」事件写进结算结果与 UI；无期限委托不参与。
- 名望奖励：模板可选 `rewards.fame`（新增，默认沿用 `rewards.reputation` 作为名望，保持旧内容语义）；势力关系奖励用 `rewards.relation`（新增）。
- 委托上限与名望解耦：`active_limit = 1 + 已购许可证数`（默认上限 4，参数进 `map_configs`）。旧公式 `maxi(1, 1 + reputation/2)`（[contract_ops.gd](../../framework/domain/contracts/contract_ops.gd) L297–300）退役；`unlock_reputation` 迁移到势力关系/许可证（见 §7）。

## 6. 港口特色：特产、需求、禁运与走私

### 6.1 责任划分

| 层级 | 内容来源 | 表现 |
| --- | --- | --- |
| 势力特产 | `factions.data.trade_goods`（已有） | 该势力所有港口对列表内货物需求更高（价格上浮）、库存更稳；势力专属货物只在该势力港口出现 |
| 港口特产 | `port_templates.data.market[]`（已有 `stock_range` / `price_bias`） | 不同模板的低价高产货物 / 高价缺货货物；模板数量要够（自由模式建议 ≥10 个模板 / 15 港） |
| 港口禁运 | 新增 `port_templates.data.forbidden_goods[]`；势力级 `factions.data.contraband_goods[]` | 入港检查；携带即收缴 + 罚金 + 关系下降；黑市可卖 |
| 势力法律 | `factions.data.attitude_thresholds` + 新税费字段 | 敌对/中立/友好的交易税、停靠费差异化 |

### 6.2 特产与需求（不做新类型）

- 需求：`market` 条目的 `price_bias` 已经能表达「贵/缺」（>1 = 高价需求，<1 = 产地低价）。势力 `trade_goods` 对已在该港市场表内的货物再叠加一个查询期系数（如 friendly +10% 售价、neutral +5%），不改 NPC 市场均衡、不写存档。
- 产地：模板给某货物高 `stock_range` + 低 `price_bias`，就是「产地」。势力特产货物用 item 的 `faction` 字段限制「只在该势力港口买卖」，其他港口市场直接不展示/拒绝买入。
- 港口特色文案：用模板 `description_key` + 既有市场表现，不新增 UI 数据类型；需要强提示时用本地化键（`ui.port.specialty.*`）。

### 6.3 违禁品与走私

- 违禁品 = 带 `item.contraband` 标签的货物（如私酒、军械、遗物），不新增物品字段；该港禁运清单 = `port_templates.forbidden_goods[]`（港口级，所有港口生效）+ 该港为限制港时再并入 `factions.contraband_goods[]`（势力级）——公开港检查松、限制港检查严。
- **入港检查**（`VoyageService` 抵港结算统一入口，与到达/探索/漂流共用）：
  1. 只检查玩家自购货物（无 `contract_id` 的货堆）；**委托申报货物豁免**，避免「接单即走私」的互锁；
  2. 命中禁运：货物全部收缴（进该港仓库或销毁，内容配置），罚金 = 货值 × `fine_rate`（默认 50%）+ 固定手续费；
  3. 关系 `-8`，发通知与结算页明细；
  4. 敌对态度可能直接拒绝入港（与许可证规则一致）。
- **规避手段**（P1 至少给一种）：
  - 航行事件「海关检查」：支付贿赂（金币）或接受检查；贿赂金额与成功率和势力关系/通缉度相关；
  - 海盗/自由港黑市：可卖出违禁品（折价），也是违禁品的进货源；
  - 势力 `black_market` 许可（海盗线，P2）可降低被查概率。
- 禁运不是全有全无：公开港检查松（只查港口级禁运）、限制港检查严（并集 + 更高罚金），给玩家「绕公开港走私」的空间。

### 6.4 税费

- 交易税按 owner 势力态度：friendly 0–2%、neutral 3%、hostile 8%（或直接拒绝交易），`map_configs` 可调；以**成交手续费**形式在 `trade.buy/sell` 结算时额外记账（`record_expense`），不改变市场价与 NPC 模拟。
- 自由港固定低税但设施少；势力港税高但设施/装备/委托更好——形成「税 vs 机会」的取舍。

## 7. 势力专属装备（船 / 模块 / 武器 / 船员）

- 内容新增可选字段（加法，不改既有语义）：
  - `hulls` / `modules` / `weapons` / `crew_roles` 的 `data.faction`（完整 faction id）与 `data.faction_relation_min`（整数，默认 0）；
  - 旧 `unlock_reputation` 保留兼容；新规则优先判定 `faction + relation_min`。
- 获取方式（按优先级）：
  1. **势力港口船厂购买/打造**：关系达到 `faction_relation_min` 且在该势力港口；
  2. 委托 `unlock_ids`（既有机制）；
  3. P2 以后：捕获、遗迹掉落、黑市。
- 视图与命令门禁：`shipyard.view` 展示 `locked_by_faction / locked_by_relation` 及所需关系；`ship.purchase / craft / refit` 同口径校验（参照既有 `locked_by_reputation / locked_by_contract` 结构）。
- 美术策略：首版用现有船体/模块/武器资产做**数值与外观变体**（换色/换配件/改参数），避免内容被 3D 资产卡住；独立模型进 [MODELING_BACKLOG.md](MODELING_BACKLOG.md) 后续排期。

## 8. 与剧情模式的共享边界

| 项 | 自由模式 | 剧情模式（第一版公开） |
| --- | --- | --- |
| 地图 | 随机大地图（world_profile 生成） | 固定地图/固定关卡（[STORY_MODE.md](STORY_MODE.md) S2+，另行实现） |
| 主线 | 无 | 固定流程 |
| 势力初始关系 | 内容 + start profile 播种 | 剧情脚本设置 |
| 许可证 | 玩家花钱购买 | 剧情授予/购买皆可；关键节点可免费发放 |
| 关系条款/禁运/装备 | 同一套规则 | 同一套规则，内容控制开关与数值 |
| 名望/关系 | 同一套存档字段 | 同一套 |

- 框架只认「势力规则 + 内容字段」，不认模式；模式差异全部由 `start_profile` / 剧情内容 / 固定地图加载链决定。
- 旧存档兼容：缺少势力规则标记的旧档按**规则关闭**处理（无许可证门禁、无禁运检查、委托无发起方条款），只展示关系数据；新开局启用。禁止用「补发全部许可证」之类会改变既有存档平衡的迁移。

## 9. 数据与内容变更清单

### 9.1 内容 Schema（全部为可选字段，加法）

| 内容类型 | 新增 | 说明 |
| --- | --- | --- |
| `factions` | `permits[]`（`id / cost / relation_min / reveal_ports`）、`contraband_goods[]`、`black_market`（P2） | 许可证与禁运 |
| `contracts` | `issuer.faction`、`rewards.relation`、`rewards.fame`、`late_penalty_rate / late_penalty_cap`（可覆盖全局） | 发起方与关系条款 |
| `port_templates` | `forbidden_goods[]`、`customs_level`（`lenient/normal/strict`） | 港口禁运与检查强度 |
| `items` | 标签 `item.contraband`；可选 `data.faction`、`data.faction_relation_min` | 违禁品与势力特产 |
| `hulls` / `modules` / `weapons` / `crew_roles` | `data.faction`、`data.faction_relation_min` | 势力专属装备 |
| `map_configs` | `faction_contract_terms`、`tariffs`、`permits`（默认价/上限）、`contracts.active_limit` 参数 | 全局调参 |
| `world_profiles` | 新增 `free_world` profile（region/port/faction 数量） | 自由模式世界 |
| `regions` | 自由/势力/边陲区域定义（`factions[]` 归属） | 自由模式内容 |
| `start_profiles` | `free_standard`（标签 `start.mode.free`） | 自由模式开局 |
| 本地化 | 势力/许可/禁运/条款/结算 键 | 中英双语 |

> 所有 Schema 变更需同步 `schemas/v2/*`、`SNModMaker` 内嵌 bundle（`node SNModMaker/tools/sync-schemas.mjs`）、Core 内容、SDK 示例，并通过 `node tools/check_content_schema_v2.mjs` 与跨引用校验（新增 `factions.contraband_goods[]` / `port_templates.forbidden_goods[]` / `issuer.faction` 的硬引用检查）。

### 9.2 运行态（全部惰性补齐）

```text
campaign.factions.<id> = { reputation, attitude, discovered, met_at, permits: [] }
campaign.world.faction_territory = { <faction_id>: { region_ids: [], open_port_ids: [] } }
player.reputation                 # 语义改为「名望」，字段不变
contracts.<instance> = { issuer, deadline_mul, reward_mul, late_penalty_rate, late_penalty_cap, ... }
```

- 港口 owner / 准入 / 势力特产 / 禁运全部**派生**（区域定义 + 唯一世界 + 内容），不写 `WorldMap`；`campaign.world.faction_territory` 只存生成元数据。
- 旧档：`permits` 默认空、`faction_territory` 惰性生成或空（规则关闭）；不做破坏性迁移。

## 10. 命令 / 查询 / 事件 / DSL

| 层 | 新增 | 说明 |
| --- | --- | --- |
| 命令 | `faction.buy_permit {faction_id}` | 在公开港购买通行许可；校验港口/关系/金币；事务提交后发事件 |
| 命令 | `faction.donate {faction_id, amount}`（P1） | 捐献换关系，有上限 |
| 命令 | `faction.enroll`（P2 组织层） | 暂不实现 |
| 查询 | `faction.view` | 各势力关系/态度/许可证/海域/公开港/可购许可/当前港 owner |
| 查询扩展 | `port.view`（owner/access/forbidden/tariff）、`sea_chart.view`（territory/open 标记）、`contracts` 视图（issuer/条款）、`shipyard.view`（势力装备锁定原因） | 只读投影 |
| 事件 | `faction.relation_changed`、`faction.permit_granted`、`faction.attitude_changed`、`faction.contraband_seized` | 供 UI/测试/后续脚本 |
| 条件 op | `faction_relation_gte`、`faction_has_permit`、`faction_attitude_is` | 剧情/航行事件/委托约束复用 |
| 效果 op | `add_faction_relation`、`grant_permit`、`add_fame`、`confiscate_contraband` | 内容不执行代码，仍走白名单 |

## 11. UI 触点

| 位置 | 表现 |
| --- | --- |
| 海图 | 势力海域底色/旗帜、公开港/限制港图标区分、许可证锁定提示、买许可后揭示动画；未发现港口继续迷雾 |
| 港务页 | 「势力」区块：owner、态度、关系条、许可证状态、可购许可与价格、该港禁运清单；公开港显示购买入口 |
| 委托页 | 委托卡显示发起方旗帜/名称与条款徽标（友好：期限+25%/报酬+15%；敌对：期限-20%/迟到重罚）；结算显示关系变化 |
| 市场 | 违禁品徽标、交易税行、黑市区块（自由港/海盗港）；持有禁运品时入港前提示 |
| 出航确认 | 目的地限制港无许可 → 阻断 `need_permit`；携带禁运品 → 风险提示（可能被收缴/罚款） |
| 抵港结算 | 收缴/罚金/关系变化明细；许可证揭示新港提示 |
| HUD | 名望 chip（取代/重命名原「声望」）；势力关系不在顶栏堆叠，进势力页查看 |
| 主菜单 | 剧情模式 / 自由模式入口（自由模式第一版测试用，文案标注） |

## 12. 自由模式内容清单（P0–P3 目标）

- 内容：3 势力各 1 张许可证 + 2–3 个禁运品 + 1 艘/2 模块/2 武器/1 船员的关系装备 + 1–2 个派系委托模板；中立委托 3 个；港口模板 ≥10（15 个港口按模板差异化：3 自由港 / 3 公开港 / 9 限制港）；自由模式区域 6、港口 15、start profile 1。
- 生成：自由模式 `world_profile` 与势力领地硬约束；开局 6 港已发现已测绘；许可证揭示/探索规则。
- 验收（长期可玩性）：
  - 同一 seed 下，「投靠公会 / 投靠海军 / 做海盗 / 保持中立」四条路线在 3 小时内产生不同的港口、货物、委托、装备与风险；
  - 玩家在 10–20 小时存档里仍有「下一个许可证/关系/特产/装备」目标；
  - 没有任何主线的情况下，通关式目标由名望/资产/势力关系里程碑承担。

## 13. 确定性、存档与测试

- 确定性：港口 owner/准入由生成顺序和内容决定；许可证揭示目标按「港 id 排序 + 航程」确定性选取；关系变更只经命令；事件/遭遇 RNG 走命名流（新增 `STREAM_FACTION` 或复用 `STREAM_VOYAGE_EVENT` 子流）。
- 存档：新增字段全部惰性补齐；`state.hash()` 保存/加载一致；`campaign.world.faction_territory` 与 `campaign.factions[*].permits` 进存档。
- 测试矩阵：

| 套件 | 覆盖 |
| --- | --- |
| `test_faction_rules` | 许可证购买/揭示/航线解锁/门禁；敌对拒绝入港；重复购买幂等 |
| `test_faction_contracts` | 发起方、友好/敌对条款、迟到罚金、无期限不受影响、名望与关系分离 |
| `test_faction_contraband` | 禁运收缴、罚金、委托货物豁免、黑市拒绝/接受、关系变化 |
| `test_faction_world` | 自由模式 15 港生成约束、6 港开局、同 seed 复现、存档往返 |
| 回归 | `test_contract_refresh`（委托上限新公式）、`test_campaign_assembly`（territory 元数据）、`test_world_schema_refs`（新引用）、`test_ui_shell`/`test_ui_views`（新增投影字段） |

## 14. 分期

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| **P0 准入骨架** | 港口 owner/access、faction_territory、许可证购买与揭示、航行门禁、6 港开局、名望/关系解耦、存档兼容 | 自由模式能靠 3 张许可证打开 3 片海域；无许可无法进限制港；同 seed 可复现 |
| **P1 经济特色** | 势力/港口特产、禁运清单、入港检查、罚金、税费、黑市、航行海关事件 | 走私能赚但有代价；不同势力港口有明显买卖差异 |
| **P2 关系条款与装备** | 委托发起方与关系条款、迟到罚金、关系变更源、势力专属装备、捐献 | 友好/敌对委托与装备可感知；关系可通过玩法改变 |
| **P3 自由模式内容与 UI** | 15 港大地图内容、菜单入口、势力页/海图/结算 UI、长期验收 | 10–20 小时无主线存档仍有目标；四条路线差异成立 |

> 剧情模式（固定地图）不等待本表：P0 的规则与数据先落地，剧情内容可以按需引用；固定地图加载链按 [STORY_MODE.md](STORY_MODE.md) 独立推进。

## 15. 风险与开放问题

| 风险/问题 | 处理建议 |
| --- | --- |
| 15 港完全图（105 条边）的海图绘制与存档体积 | 实测当前 5 港（10 边）存档 519 KB：航线表 68 KB（13%）、雾 309 KB（59%）、其余 143 KB；航线表 31 B/采样点（全精度浮点 + tab 缩进）。105 边按 150–200 采样点/边估算航线表 0.5–0.7 MB、整档 1.0–1.3 MB；整档 gzip 后约 0.1–0.15 MB（当前 519 KB → 27 KB）。先做存档压缩/雾紧凑编码，再上 15 港；必要时降 12 港或 path 抽稀/存控制点 |
| 许可证经济：开局 900 金 vs 许可 300–600 | 首版按 2–3 次航程可买第一张；价格进内容，可调 |
| 敌对势力为何招募玩家 | 只在自由港掮客出现、低权重、明确敌对条款；或改为「敌对势力不提供委托，只提供黑市」——开放问题 |
| 名望解耦影响既有测试/门禁 | `active_limit`、`unlock_reputation` 迁移；旧存档规则关闭；测试明确改造清单 |
| 势力装备美术量 | 首版数值/配色变体，独立模型进建模 backlog |
| 探索与许可的边界 | 本期只做港口门禁（发现 ≠ 准入）；坐标自由航行时再升级海域边界 |
| 固定地图剧情模式依赖 | 本文不实现固定地图；规则接口不依赖生成方式，剧情内容可先用生成地图验证 |
| 旧存档 | 规则默认关闭；不补发许可证；只在 UI 展示势力数据 |
| 禁运与委托货物互锁 | 委托货物豁免检查；违约另算 |
| 港口检查影响现有市场/自动贸易 | 税费只加手续费；禁运只做入港检查，不改 NPC 市场与价格均衡 |

**本期不做**：玩家组织层（公司/等级/总部/代理人）、势力间战争与外交模拟、港口投资/占有度、攻防与占领、势力海军 AI、玩家自立为第四势力、动态封锁。这些留到 P2+ 或后续版本，但数据结构（`faction_territory`、关系、许可证）为它们预留扩展位。
