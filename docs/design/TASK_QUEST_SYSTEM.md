# 任务追踪与任务系统设计（阶段 4.6）

> 状态：Phase A（任务追踪聚合）Implemented；Phase B（正式 Quest 内容类型）Planned。
> 本文同时是 `task.view` 的实现契约。正式任务系统在 Phase B 落地前不改存档结构、
> 不新增内容类型。

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

**Phase B（后续正式任务系统）**：新增内容驱动 Quest（任务链），支持酒馆悬赏、
港务告示、连环任务、条件解锁；委托继续作为「一单生意」的经济实例，Quest 负责
「一串目标」；两者通过引用组合，不互相取代。

**不做**：本切片不做任务接受 / 放弃 / 追踪切换命令，不做分支、时限奖励、每日刷新；
这些属于 Phase B。

## 2. 现有系统边界

| 系统 | 负责 | 数据 |
|---|---|---|
| 委托 Contract | 一单生意的 payload / 目的地 / 时限 / 报酬 / 接取与结算 | `data.contracts.main`、`main_offer`、`active`、`offers` |
| 剧情 Story | 新手教学的固定阶段 / 文本 / 解锁 / 目标 | `data.story` |
| 任务追踪 Task（本切片） | **只读**聚合与步骤推导，供 HUD / 页面展示 | 无（派生自上面两者） |
| Quest（Phase B） | 内容定义的目标链 / 前置 / 奖励 / 发布者 | 新增 `data.quests`（惰性 ensure） |

关键原则：**任务追踪不复制状态**。委托或剧情一变化，`task.view` 重新推导即可；
不要为追踪器写入 `active_task_id` 之类的存档字段，除非 Phase B 需要玩家手动追踪。

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
  id: String,                 # "story" / "main:<instance_id>" / "contract:<instance_id>" / "main_offer:<id>"
  kind: "story" | "main" | "contract" | "main_offer",
  category_key: String,       # ui.task.kind.story / main / contract / main_offer
  title_key: String,          # 剧情用 stage 标题或 ui.task.kind.story；委托用 contract.name_key
  destination_id: String,     # 委托目的地（剧情为空）
  destination_name_key: String,
  deadline: float,            # 0 = 无
  remaining_hours: float,
  steps: [Step],
  current_step_index: int,    # -1 = 全部完成
  current_step: Step | null,
  priority: int,              # 排序用：story 300 / main 200 / active 100
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

- 排序：`priority` 降序，同优先级按 `id`；`active_task = tasks[0]`。
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

## 4. Phase B：正式 Quest 系统（待实现）

### 4.1 内容类型

建议新增两个内容类型（名称待定）：

- `quest_chains`：任务链，含 `stages`（顺序目标）、前置条件、发布者、奖励；
- `quests`：单任务定义（可选，若任务链足够可先只做 chain）。

单个目标（Objective）复用剧情条件模型：

```json
{"event": "cmd:trade.buy", "counter": "textiles_bought", "at_least": 6,
 "match": {"item_id": "core:good/textiles"}}
```

支持类型：`deliver_cargo` / `carry_passenger` / `visit_port` / `discover_port` /
`buy_good` / `sell_good` / `install_module` / `earn_money` / `story_stage`。
目标完成可发效果：`grant_money` / `grant_item` / `unlock_contract` / `start_quest` /
`complete_quest` / `set_flag`。

### 4.2 与现有系统的关系

- **Contract 不变**：Quest 可以 `accept_contract` / 引用 `contract_template`，
  但委托实例仍由 `ContractOps` 生成与结算；
- **Story 不变**：剧情阶段可以 `start_quest` / `complete_quest`，把教学目标交给
  Quest 系统统一追踪；
- **Task 追踪器不变**：`task.view` 在 Phase B 增加 `kind:"quest"` 的任务来源，
  HUD / 任务页无需重写；
- **存档**：`data.quests` 惰性 ensure（旧存档无块 → 无任务），不改 `schema_version`；
  任务实例只存 `quest_id / stage_index / counters / flags`，内容仍在 Core JSON。

### 4.3 UI

- 任务日志页（可与委托页合并为「委托与任务」两个 tab）；
- 任务发布点：酒馆告示板 / 港务告示牌（复用现有设施）；
- HUD 追踪器支持点击切换追踪任务（Phase B 才引入 `tracked_quest_id` 会话状态）。

### 4.4 落地顺序（建议）

1. `task.view` + HUD / 委托页任务追踪（本切片）；
2. 任务链内容类型 + `QuestService`（状态机、目标事件、奖励、存档）；
3. 发布点 UI（酒馆 / 港务）与任务日志页；
4. 把剧情目标迁移为 Quest（可选，保持剧情阶段状态机不变，只复用目标/奖励）；
5. 联调、回归、静态文档与截图。

### 4.5 验收口径（Phase B）

- 内容定义的任务链可被接取、追踪、完成并发放奖励；
- 任务目标事件复用 `cmd:*` / `ui:*`，不需要为每个玩法复制计数逻辑；
- 存档 round-trip 一致，旧存档无任务块时行为不变；
- 同一任务不会重复接取 / 重复发奖；
- 任务页与 HUD 的步骤进度和实际状态一致。

## 5. 风险

- **双份状态**：若 Quest 复制 contract 的 payload / 目的地，结算会漂移；必须引用
  contract 实例或只读推导。
- **任务爆炸**：普通委托池不进入任务追踪（只显示已接），避免 HUD 被可接任务淹没。
- **HUD 拥挤**：只显示当前任务 + 数量提示，完整列表在委托页 / 任务页。
- **旧存档**：Phase A 完全派生，无迁移风险；Phase B 的 `data.quests` 必须惰性 ensure。
