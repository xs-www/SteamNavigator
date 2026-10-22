# 任务追踪与任务系统设计（阶段 4.6）

> 状态：Phase A（任务追踪聚合）Implemented；Phase B（正式 Quest 内容类型，C3）Implemented（2026-10-22）。
> 2026-10-22 决策：**委托（Contract）与任务（Quest）彻底解耦**——Contract 只负责运输请求，
> Quest 负责剧情演出、游戏指引与除运输请求外的一切系统需求；Quest 采用持久 `data.quests` +
> `QuestService`。Story 暂时保留，后续剧情模式开发时由 Quest 自动上位替代其功能。

## 1. 目标与范围

**要解决的问题**：当前玩家侧有两套目标来源——剧情阶段（`data.story`）与委托
（`contracts.main` / `active`）——但只有剧情有目标条；委托接取后玩家需要自己推断
「先备货、再出航、到了自动交付」。玩家反馈「关图后不知道还要买多少煤」就是同一类
信息断层的表现。

**Phase A（本切片）**：新增只读聚合查询 `task.view` 与任务追踪 UI：
- 汇总剧情当前目标、主线委托、已接普通委托；
- 把委托拆成可执行的步骤（备货 / 接客 / 前往 / 抵达交付），标出当前步骤与进度；
- HUD 顶部任务条显示优先级最高的任务；委托页顶部显示全部任务与步骤；
- 不写状态、不改存档、不新增业务命令。

**Phase B（正式任务系统，C3 已实现）**：
- 新增内容驱动的 **Quest**（抽象引导层），服务剧情演出、游戏指引与一切非运输类系统需求；
- **Contract 保持独立**：仍是「一单运输生意」的经济实例（payload / 目的地 / 时限 / 报酬）；
- **解耦但联动**：委托被接取后生成一条**追踪实例**写入 `data.quests`（`source=contract`），
  只存 `contract_instance_id` 作为追踪 / 历史引用；Quest 定义与实例不复制 Contract 的 payload/目的地/结算；
- `task.view` 聚合 Quest 任务项；**委托任务仍由 `contracts` 派生**，contract 来源的 Quest 追踪实例
  不重复渲染，避免同一委托出现两次。

**暂缓**：Quest 完成的奖励与 effects（`grant_money` / `grant_item` / `unlock_contract` / `start_quest` /
`complete_quest` / `set_flag`、`spawn_contract` 等）与任务发布点 / 任务日志 UI 不在 C3 范围，后续切片再定。

## 2. 现有系统边界

| 系统 | 负责 | 数据 |
|---|---|---|
| 委托 Contract | 一单生意的 payload / 目的地 / 时限 / 报酬 / 接取与结算 | `data.contracts.main`、`main_offer`、`active`、`offers` |
| 剧情 Story | 新手教学的固定阶段 / 文本 / 解锁 / 目标 | `data.story` |
| 任务追踪 Task | 只读聚合与步骤推导，供 HUD / 页面展示；C3 起聚合 Quest 任务项与已接 Contract（委托任务仍由 contracts 派生） | 派生自 `data.quests` / `data.story` / `contracts` |
| Quest（C3） | 抽象引导：剧情演出、游戏指引、非运输类系统需求；委托接取后生成追踪实例 | `data.quests`（惰性 ensure） |

关键原则：**任务追踪不复制业务状态**。委托或剧情一变化，`task.view` 重新推导即可；`data.quests`
只保存 Quest 实例自身的 `quest_id / stage_index / counters / flags / contract_instance_id`，不保存
Contract 的 payload / 目的地 / 结算。contract 来源的追踪实例只用于持久追踪与历史记录，`task.view`
不会据此重复渲染委托任务。

## 3. Phase A：`task.view` 实现契约

### 3.1 查询形状

```text
task.view → {
  has_run, current_port_id, current_port_name_key,
  tasks: [Task],
  active_task_id: String,
  active_task: Task | null,
}

Task = {
  id: String,                 # "story" / "quest:<instance_id>" / "main:<instance_id>" / "contract:<instance_id>" / "main_offer:<id>"
  kind: "story" | "quest" | "main" | "contract" | "main_offer",
  category_key: String,       # ui.task.kind.story / quest / main / contract / main_offer
  title_key: String,          # 剧情用 stage 标题或 ui.task.kind.story；委托用 contract.name_key
  destination_id: String,     # 委托目的地（剧情为空）
  destination_name_key: String,
  deadline: float,            # 0 = 无
  remaining_hours: float,
  steps: [Step],
  current_step_index: int,    # -1 = 全部完成
  current_step: Step | null,
  priority: int,              # 排序用：story 300 / quest 250 / main 200 / main_offer 150 / contract 100
  tracking_priority: int,     # Quest 的 tracking.priority（同 priority 内排序，可选）
}

Step = {
  kind: "objective" | "accept" | "load" | "passenger" | "sail" | "deliver",
  done: bool,
  progress: int,
  target: int,
  text_key: String,           # objective 直接用剧情 objective 的 key
  item_name_key: String,      # load（可选）
  destination_name_key: String,
  fuel_sourced: bool,         # load 时按煤舱而不是货舱计数
}
```

### 3.2 剧情任务

剧情进行中且 `story.view.objective` 非空时生成：

- `id = "story"`，`priority = 300`，`title_key = "ui.task.kind.story"`；
- `steps = [{kind:"objective", text_key, progress, target,
  progress/target 来自 story objective}]`；
- 剧情卡打开期间任务条不渲染（剧情卡优先），与现有行为一致。

### 3.3 委托步骤推导

对 `contracts.main`（priority 200）、`contracts.active`（priority 100）与
`contracts.main_offer`（priority 150，步骤只有 `accept`）：

1. **接取**（仅 main_offer）：`done=false`，`text_key = ui.task.step.accept`。
2. **备货**（cargo payload）：
   - `fuel_sourced`：进度 = `floor(ship.coal)`，目标 = 该 payload 数量；
   - 其它：进度 = 船上该货物数量（`ShipOps.cargo_amount`），目标 = payload 数量；
   - 多个 payload 合并为一个步骤，进度按各货物 `min(可用, 需求)` 求和。
   - 接取时自动装船的普通委托货箱会立即显示为完成。
3. **接客**（passenger payload）：目标 = 旅客数；接取成功即完成（步骤保留作为记录）。
4. **前往**：`done = current_port_id == destination`，否则目标 1、进度 0。
5. **抵达交付**：目的港抵达后由到港服务自动结算，因此该步骤只作为最后提示；
   `done = current_port_id == destination`（若尚未抵达则进度 0/1）。

`current_step` = 第一个未完成步骤；全部完成时 `-1`（通常任务会被结算移除）。

### 3.4 排序与 HUD

- 排序：`priority` 降序（story 300 > quest 250 > main 200 > main_offer 150 > contract 100），
  同优先级先按 Quest `tracking.priority` 降序、再按 `id`；`active_task = tasks[0]`。
- HUD 任务条（`SNTaskTracker`）显示：类别 + 标题 + 当前步骤 + 进度；
  若还有其它任务，追加「另有 N 个任务」。
- 剧情目标条存在时，HUD 仍显示剧情目标（剧情按优先级最高），任务条不重复；
- 剧情结束后，HUD 自动改为显示主线 / 委托任务。
- 委托页顶部新增「任务追踪」面板，列出全部任务及步骤（完成打勾 / 当前高亮）。

### 3.5 约束

- 查询只读，由 `QueryBus` 在状态克隆上执行；不写 `data`、不发事件。
- 不输出内部字段（`player_sourced` 等只用于推导，不暴露原始 payload）。
- 目的地名 / 货物名一律通过注册表 key 输出，框架不写死内容 ID。
- 旧存档没有 `data.story` 时只显示委托任务；没有委托时 `tasks=[]`。

## 4. Phase B：正式 Quest 系统（C3 已实现）

> 2026-10-22 拍板：Contract 与 Quest **不合并**；Quest 是抽象引导层，Contract 仍是运输请求。
> 委托接取后由 `QuestService` **生成追踪实例写入 `data.quests`**（解耦联动，`source=contract`），不复制
> Contract 的 payload / 目的地 / 时限 / 结算字段。Story 暂时保留；后续剧情模式开发时由 Quest 自动上位
> 替代 Story 的演出/目标功能。
>
> **实现（2026-10-22）**：`quests` 2.0 + `QuestOps` / `QuestService` + `quest.start|complete|observe`
> 命令；`data.quests = {schema_version:1, instances:[{instance_id, source:"content"|"contract",
> quest_id, contract_instance_id, stage_index, counters, flags, status, started_at, completed_at}]}`
> （惰性 ensure，旧档无块 = 无任务）。委托 `accept_offer` / 教程直接挂主线时 `track_contract`，
> 完成时关闭实例；task.view 增加 `kind:"quest"`（priority 250）；contract 来源实例不重复渲染，
> 委托任务仍由 contracts 派生。`auto_start` 仅存储 / 校验，开局自动接取与失败/放弃钩子留给后续切片。
> **奖励与 effects 暂缓**：C3 只做目标推进与追踪，不做发奖、`spawn_contract` 或 effects 执行。

### 4.1 内容类型

`quests`（2.0，capability `content.quests.v1`）定义抽象目标链，字段以实现为准：

- `kind`：`story`（剧情演出）/ `guide`（游戏指引）/ `system`（非运输类系统需求）；
- `stages`：顺序目标，复用剧情条件模型（事件 + counter + 阈值 + match），每 stage 有 `id` / `title_key` / `objectives`；
- 可选 `auto_start` / `repeatable` / `prerequisites{quests_completed,flags}` / `tracking{label_key,priority,hidden}`；
- **不包含**运输 payload、目的地、时限与经济奖励；这些仍由 Contract / 后续奖励系统负责。

单个目标（Objective）复用剧情条件模型：

```json
{"event": "cmd:trade.buy", "counter": "textiles_bought", "at_least": 6,
 "match": {"item_id": "core:item/textiles"}}
```

支持类型：`deliver_cargo` / `carry_passenger` / `visit_port` / `discover_port` /
`buy_good` / `sell_good` / `install_module` / `earn_money` / `story_stage`。
**奖励与 effects 暂缓**：C3 只推进目标与追踪，不实现 `grant_money` / `grant_item` / `unlock_contract` /
`start_quest` / `complete_quest` / `set_flag` 等效果，也不实现 `spawn_contract` 奖励；奖励系统后续切片再定。

### 4.2 与现有系统的关系

- **Contract 独立**：接受委托时生成 Quest 追踪实例（`data.quests`，`source:"contract"`），
  只存 `contract_instance_id` 作为追踪 / 历史引用；payload/目的地/时限/结算仍由 `ContractOps` 负责；
- **Story 暂时保留**：剧情阶段仍由 Story 驱动，Quest 的目标条件可观察 `story_stage`；剧情与 Quest 的
  相互替代（含 `start_quest` / `complete_quest` effects）留给后续剧情模式切片；
- **Task 追踪器**：`task.view` 增加 `kind:"quest"` 任务项；contract 来源的追踪实例**不重复渲染**，
  委托任务仍由 `contracts` 派生，HUD / 任务页无需重写；
- **存档**：`data.quests` 惰性 ensure（旧存档无块 → 无任务），任务实例只存
  `quest_id / stage_index / counters / flags / contract_instance_id`，内容仍在 Core JSON。

### 4.3 UI（后续切片，未在 C3 实现）

- 任务日志页（可与委托页合并为「委托与任务」两个 tab）；
- 任务发布点：酒馆告示板 / 港务告示牌（复用现有设施）；
- HUD 追踪器支持点击切换追踪任务（后续切片引入 `tracked_quest_id` 会话状态）。

### 4.4 落地顺序（建议）

1. ✅ `task.view` + HUD / 委托页任务追踪（4.6 Phase A）；
2. ✅ 任务链内容类型 + `QuestService`（状态机、目标事件、存档；奖励暂缓）；
3. 后续：发布点 UI（酒馆 / 港务）与任务日志页；
4. 后续：奖励 / effects 系统与 `spawn_contract`（独立切片）；
5. 后续：把剧情目标迁移为 Quest（可选，保持剧情阶段状态机不变）。

### 4.5 验收口径（Phase B / C3）

- 内容定义的 Quest 可被启动、按目标事件推进、完成并持久化（奖励与 effects 暂缓）；
- 任务目标事件复用 `cmd:*` / `ui:*`，不需要为每个玩法复制计数逻辑；
- 存档 round-trip 一致，旧存档无任务块时行为不变；
- 同一 Quest 不会重复启动；委托追踪实例不重复渲染（task.view 仍以 contracts 派生委托任务）；
- 任务页与 HUD 的步骤进度和实际状态一致。

## 5. 风险

- **双份状态**：若 Quest 复制 contract 的 payload / 目的地，结算会漂移；必须引用
  contract 实例或只读推导。
- **任务爆炸**：普通委托池不进入任务追踪（只显示已接），避免 HUD 被可接任务淹没。
- **HUD 拥挤**：只显示当前任务 + 数量提示，完整列表在委托页 / 任务页。
- **旧存档**：Phase A 完全派生，无迁移风险；Phase B 的 `data.quests` 必须惰性 ensure。
