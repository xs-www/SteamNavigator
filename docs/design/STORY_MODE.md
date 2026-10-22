# 剧情模式（Story Mode）设计草案 — Draft 5

> 作用：定义与「自由模式」并列的**剧情模式**——在手工固定地图上、按固定任务线推进的关卡
> 集合。本文确定三种边界：剧情模式与自由模式的模式边界、与持久战役（`campaign`）的命名
> 边界、与现有新手剧情（`data.story`，见 [STORY_TUTORIAL.md](STORY_TUTORIAL.md)）的迁移边界；
> 并给出**剧情数据包**与关卡的数据化存储契约。
>
> 状态：Active（讨论中，未定稿；S1 数据契约已落地为 Schema 2.0 草案与示例包，游戏运行时尚未加载）。
>
> 本版（Draft 5）已确认：
> - 游戏侧**不做任何剧情内容**，只交付「固定地图、剧情演出、初始状态、关卡数值」四类能力 +
>   一个**可完全手动配置、可直接加载为剧情战役的数据包**。
> - **World Forge 只交付世界观设定**；世界观 → 可导入剧情配置需要**人工**在剧情编辑器里完成，
>   游戏运行时不依赖 World Forge，也不自动转换设定。
> - **数据包就是「只加剧情的模组」**：仍然是内容模组格式，仍按模组格式加载；一个包内支持
>   **多个剧情关卡**。
> - 剧情编辑器 **`SNStoryMaker/`** 放在**仓库根目录**（与 `SNModMaker/`、`SNBattleSim/`
>   同级），能复用 SNModMaker 的 Schema / 校验 / 打包就复用。
> - 首发 **1 关**验证纯数据驱动演出；**固定主角**；**每关数值独立**；失败按 **checkpoint**
>   回档，「重开剧情」= **重开本关**；通关奖励不影响自由模式。
> - **成就系统延后**：本文只保留奖励字段与「不影响自由模式」的约束，成就实装放到正式版交付前。

## 0. 一句话定义

> 自由模式在**程序生成的海图**上跑沙盒；剧情模式加载**剧情数据包**，在**手工固定、可完全
> 手动配置的关卡**里，按既定任务线讲述一段**独立完整的故事**；正式版中由剧情模式接管新手
> 引导，自由模式不再内置强制新手任务。

对外文案：

| 模式 | 一句话 |
|---|---|
| 自由模式 Free Mode | 在无尽的海图上经营、贸易，自己决定要做什么。 |
| 剧情模式 Story Mode | 在一段完整的故事里启航，一关一关认识这片海。 |

## 0.1 落地状态（S1：数据契约）

S1 已交付（2026-10-22），实现先于游戏侧能力：

| 交付物 | 位置 |
|---|---|
| 篇章 / 关卡 Schema 2.0 草案 | `schemas/v2/story_arc.schema.json`、`schemas/v2/story_level.schema.json`（共用 `v2/common.schema.json#/$defs/story_stage`） |
| 类型登记（草案，运行时未加载） | `content_types.json` → `draft_schemas` + `draft_types` + `planned`（capability `content.story.v1`） |
| 编辑器元数据（标签 / 默认值 / 枚举可读名） | `SNModMaker/js/catalog.js` |
| 校验（白名单 + 篇章 / 关卡语义） | `SNModMaker/js/validate.js`（`story_pack_off_whitelist`、`story_level_checkpoint_missing` 等） |
| 可导入的示例数据包（1 篇章 + 2 关卡 + 中英文本） | `sdk/templates/story_pack_iron_tide/` |
| 校验命令 | `node SNModMaker/tools/content.mjs validate --mod sdk/templates/story_pack_iron_tide`（0 error / 2 个预期 `draft_content` warning） |

- **不改游戏运行时**：`ContentCompiler` 只加载 1.0，剧情包因 `schema_version` 不匹配不会进入注册表（与 `weapons` 草案同一流程）。
- S2 起才做加载链与 `story_mode.*`；S1 的验收是「数据包能写、能校验、能 round-trip」，不是「能进游戏玩」。

## 1. 模式边界

### 1.1 两种模式对照

| 维度 | 自由模式（Free Mode） | 剧情模式（Story Mode） |
|---|---|---|
| 地图 | 由 seed + `map_configs` 程序生成，每局不同 | **手工固定**，由数据包声明，seed 不参与布局 |
| 目标 | 沙盒 + 可选主线委托，玩家自定节奏 | **固定任务线**，关卡目标与顺序由数据包定义 |
| 系统开放 | 正式版开局全开（新手引导交给剧情模式） | 按关卡**逐关解锁**，每关只引入一组系统 |
| 叙事 | 弱叙事，事件驱动 | **强叙事**：正史世界观 + 每关一个完整故事 |
| 主角 | 玩家自建 / 无固定身份 | **固定剧情主角**，关间叙事连续 |
| 关卡间资产 | 单局内持续积累 | **每关独立起始**，不继承船 / 钱 / 货 |
| 失败 | 航行失败回滚 / 债务与破产 | **按 checkpoint 回档**；或「重开本关」 |
| 存档 | 单局自动存档（现状） | 关卡运行时存档 + 关卡 checkpoint + 独立剧情档案 |
| 内容来源 | `map_configs` / 模板委托 | **剧情数据包**（只加剧情的模组，完全人工配置，支持多关） |
| 通关奖励 | 数值成长 | 只记录 / 成就 / 图鉴 / 外观，**不影响自由模式数值** |

### 1.2 命名隔离（重要）

项目里已经有「战役」一词，含义是**持久模拟经营存档**（[PERSISTENT_CAMPAIGN_ARCHITECTURE.md](../specs/PERSISTENT_CAMPAIGN_ARCHITECTURE.md)，
`data.campaign` 分区）。剧情模式在**玩法文案**里可以说「剧情战役」，但代码与数据必须避开：

| 概念 | 对外叫法 | 代码 / 数据前缀 | 禁止 |
|---|---|---|---|
| 持久模拟经营存档 | 战役 | `campaign`（维持现状） | 不要用它指剧情关卡 |
| 剧情节目的可玩单位 | 剧情战役 / 篇章 | `story_arc`（一个数据包 = 一个篇章） | 不要叫 `campaign` / `chapter` |
| 固定关卡的剧本集合 | 剧情模式 | `story_mode` / `story_level` | — |
| 现有新手教学状态机 | 新手剧情（教学） | `data.story`（维持现状） | 迁移完成前不要合并 |

- 对外：**剧情模式**；内部：`story_mode`。
- 剧情模式**不使用** `campaign` 分区；一个数据包加载后成为剧情模式里的一个「可玩篇章」。
- 与现有 `data.story`（教学流）**并存但分轨**，迁移步骤见 §8.4。

### 1.3 职责边界

| 角色 | 负责 | 不负责 |
|---|---|---|
| **World Forge**（独立项目） | 世界观设定：时代、地理、势力、人物、术语、时间线、正史边界 | 关卡配置、地图几何、游戏运行时 |
| **剧情编辑器**（`SNStoryMaker/`，仓库根目录，Node Web） | 人工把设定转成配置：固定地图、关卡任务线、演出文本、初始状态、数值、checkpoint、导出数据包 | 世界观创作、运行时、存档 |
| **游戏框架 / 运行时** | 数据包加载与校验、固定地图装配、剧情演出、初始状态应用、关卡数值接口、存档 / checkpoint / 成就 | 任何具体剧情、具体地图、具体数值 |
| **现有 `data.story`（教学）** | 过渡期继续服务自由模式 | 不承载剧情模式内容 |

- 游戏侧不写死任何剧情内容 ID；剧情模式的全部内容都是可替换的数据包。
- 游戏侧只定义**契约**：数据包长什么样、关卡能引用什么、演出支持哪些表现类型、初始状态能设置哪些字段。
- **World Forge → 数据包不是自动流水线**：设定到配置的转换由人工在编辑器里完成（见 §2.2）。

### 1.4 定位（与正式版路线图的关系）

- 剧情模式是**内容形态**，不依赖持久战役、不要求 tick 模拟、不要求舰队 / 基地。
- 可以在现有 MVP 框架上先行落地（单船 + 贸易 + 航行 + 探索 + 委托 / 模块），后续系统
  （战斗、舰队、基地）以「新关卡引入新系统」的方式挂进来。
- 正式版中剧情模式是**新手引导的第一入口**；自由模式保留完整沙盒能力但不再强制教学。

## 2. 世界观与内容生产

### 2.1 已确认边界

**同一个蒸汽朋克宇宙，叙事上独立的"正史海域"。**

- 共享：基础时代、技术母题、美术资产、商品与模块体系——避免第二套美术与数值。
- 独立：剧情模式发生在正史区域的正史时间线上；自由模式是同一世界观下程序生成的
  "另一片海"，不承担正史叙事，也不被剧情关卡的结局约束。
- 已否决：完全独立的新宇宙（需要独立的世界观、资产、商品表与数值，成本显著更高）。
- 推论：只有剧情模式的内容算 "canon"；自由模式里的随机事件、港口起伏与玩家行为不写入
  正史；两边的同一商品 / 船体 / 技术名词必须一致。

### 2.2 生产链路（人工，不是自动）

```text
World Forge（设定）
      │  世界观文档：时代 / 地理 / 势力 / 人物 / 术语 / 时间线
      ▼
人工转换（剧情编辑器）
      │  选关、摆固定地图、写任务线、写演出文本、设初始状态、
      │  调数值、标 checkpoint、补本地化
      ▼
剧情数据包（.snavmod.zip，完全手动配置）
      │  内容 JSON + 本地化 + 资产；manifest 声明 content.story.v1
      ▼
游戏加载：扫描 mods/ → 校验 → 剧情模式出现该篇章 → 选关 → 开玩
```

- **游戏侧不解析世界观的散文**；它只读数据包里已经人工写好的结构化配置。
- 世界设定与游戏配置的对应关系（哪个港口对应哪个地名、哪个人物对应哪个 character id）
  由编辑者负责；游戏只做引用校验，不做语义转换。
- 数据包可以记录可选的溯源字段（`source.world_bible: "iron_tide@1.4.0"`、`source.author`），
  仅用于追溯，**不参与加载与校验**；没有它也能正常玩。

### 2.3 游戏不依赖 World Forge

- 不引入 World Forge 的 Schema、不读它的文件、不建运行时 import / export。
- 世界包若需要更新，由人工把变化重新写进数据包（或编辑器里改配置），游戏侧无感知。
- 因此不存在「World Forge 版本漂移导致游戏加载失败」这一类耦合；只有数据包自身的版本与哈希。

## 3. 关卡：每关一个完整故事

### 3.1 叙事结构（硬性验收）

每个关卡必须是一个**可独立理解的完整故事**，至少包含：

| 段落 | 内容 | 数据字段 |
|---|---|---|
| 起 | 关卡简报：谁、在哪、为什么出发、风险是什么 | `narrative.brief` |
| 承 | 主任务与阻碍（玩家要做的核心循环） | `stages` / `objectives` |
| 转 | 至少 1 个关卡内剧情节点：意外、选择或真相揭露 | `narrative.beats[]` |
| 合 | 结算卡：结果、代价、对下一关的钩子 | `narrative.debrief` |

验收口径：

- 只读本关的简报 + 剧情节点 + 结算，玩家能说清「发生了什么、我为什么这么做、结果如何」；
- 人物与名词由数据包自带（角色 / 术语键），不依赖游戏仓库里的长文；
- 关间共享世界观与主线弧，但**不做连续剧式的强制前情提要**；
- 文本量建议：简报 150–400 字、节点 3–8 个、结算 150–300 字（中英同步）。

### 3.2 固定主角

- 剧情模式使用 **1 名固定剧情主角**（数据包 `story_arcs.characters` 中的 `protagonist_id`），
  关间叙事连续。
- 每关数值独立（不继承船 / 钱 / 货）：主角是**叙事连续、数值不滚雪球**，船与资金由关卡
  初始状态决定，避免手工难度被上一关资产破坏。
- 演出文本统一以固定主角视角书写；不做玩家自建角色、不做多主角切换（首版）。
- 主角形象 / 配音 / 立绘属于数据包资产与文本，游戏侧只提供展示位。

### 3.3 任务线

- 关卡内任务线是**有向、基本线性**的：`stages[]` 顺序推进，允许用 `all/any` 条件表达
  并行目标，但不做大规模分支（分支留给后续版本）。
- 复用现有剧情阶段 DSL（`advance: confirm / event+counter+at_least / match / flag`）与
  效果 DSL（`unlock_features` / `grant_*` / `set_*`），见 STORY_TUTORIAL §6–§7。
- 关卡与**委托（Contract）**：关卡可以生成脚本化委托实例作为任务载体，但关卡目标不依赖
  随机委托池；委托只是「这一单生意」的表现层。
- 关卡与 **Quest 系统（TASK_QUEST_SYSTEM Phase B）**：若 Quest 先落地，关卡任务线优先用
  Quest 链表达；否则沿用 `stages[]`，接口保持可替换。

### 3.4 关卡类型

| 类型 | 作用 | 失败策略 |
|---|---|---|
| 教学关 | 只考 1 组系统，提示全开 | 默认无失败；意外失败按 checkpoint 回档 |
| 经营关 | 贸易 / 补给 / 时限 | 按 checkpoint 回档，或重开本关 |
| 探索关 | 海图、线索、未知海域 | 按 checkpoint 回档，或重开本关 |
| 综合关 | 多系统组合，作为篇章收尾 | 按 checkpoint 回档，或重开本关 |

## 4. 循序渐进与首发范围

### 4.1 系统解锁矩阵（设计空间，非首发承诺）

| 关卡 | 引入的系统 | 复用/考核 | 建议关卡类型 |
|---|---|---|---|
| L1 启航 | 总览、补给、海图、出航抵达 | — | 教学关 |
| L2 价格 | 市场、买卖、重量与航速 | L1 航行 | 教学关 |
| L3 锅炉 | 三种锅炉策略、煤水消耗、风险 | L2 贸易 | 教学关 |
| L4 船厂 | 船厂、模块购买 / 打造 / 安装 | L2–L3 | 经营关 |
| L5 客运 | 客舱、旅客、时限与声誉 | L4 船厂 | 经营关 |
| L6 探索 | 线索、调查、迷雾、未知港口 | L1 海图 | 探索关 |
| L7 综合 | 多系统组合 + 篇章结局 | 全部 | 综合关 |

规则（对首发 1 关同样适用）：

- **每关只新引入一组系统**；上一关的系统在下一关必须被再次使用。
- 关卡开始时系统是**硬门禁**（未解锁不可见 / 命令被拒绝），与现有 story feature 门禁一致。
- 难度不是「敌人更强」，而是五个可调旋钮：起始资金、地图规模 / 航程、期限松紧、
  风险与事故率、提示密度。全部进关卡数据，不写死框架。

### 4.2 首发范围：1 关内容，多关格式

**首发只做 L1 一关内容，目标是验证「纯数据驱动演出 + 数据包直接加载」这条链路；
但包格式与加载链从第一天起就按「一个包内多个关卡」设计。**

首发必须跑通：

1. 把数据包放进 `mods/` → 启动游戏 → 主菜单出现剧情模式 → 选篇章 → **选关列表**
   （首发包只有 1 关）→ 简报 → 固定地图 → 任务线 → 结算 → 回主菜单 / 重新挑战；
2. 全部文本、目标、解锁、演出、地图、初始状态、难度、checkpoint 都来自数据包，改数据即可改关；
3. 失败按 checkpoint 回档；「重开本关」从简报重演；
4. 通关只产生剧情档案记录（成就系统延后），不改自由模式任何数值；
5. 没有数据包时，剧情模式入口显示「未安装剧情内容」而不是崩溃；
6. 换成一个含 2–3 关的手写测试包，能正确列出关卡、按 `order` 解锁、逐关进入。

明确不做（首发内容）：多关**正式内容**、篇章选择列表（多 arc）、跨关资产连续性、分支结局、
战斗 / 舰队 / 基地系统、成就系统。格式与加载器不砍多关能力。

### 4.3 难度档位（关卡数据，可调）

```text
difficulty = {
  profile: "story.intro" | "story.standard" | "story.hard",
  knobs: {
    starting_money_scale,        # 起始资金
    deadline_scale,              # 委托期限系数
    risk_scale,                  # 风险分数系数
    coal_water_scale,            # 补给消耗系数
    hint_level: "full" | "light" | "none",
  }
}
```

- 教学关 `hint_level = full`：目标条常驻 + 关键按钮高亮 + 失败按 checkpoint 回档。
- 后续关卡逐步降为 `light` / `none`；难度只影响数值与提示，不改变系统规则。

### 4.4 与自由模式新手任务的替代关系（后续阶段）

| 阶段 | 自由模式 | 剧情模式 |
|---|---|---|
| 现在（MVP / 4.5） | 新局强制五幕教学（`data.story`） | 未实现 |
| 首发 | 教学保留，不受影响 | 1 关数据包，主菜单可选入口 |
| 后续 | 教学保留；剧情模式扩到 L1–L3 | 承担新手引导 |
| 正式版 | **不再内置强制教学**：开局全解锁 + 可选「快速上手」提示；5 段主线改为可选沙盒目标 | L1–L3 是默认新手入口；`map_configs.data.story.enabled=false` |

- 不删 `data.story`：旧存档按现有逻辑打开；正式版只关闭新局的强制教学。
- Shell 的剧情卡 / 门禁 / 跳过逻辑保留给剧情模式复用；不用「删代码」方式实现替换。

## 5. 游戏侧提供的四类能力

游戏侧不写剧情，只交付以下四项能力。它们既是剧情编辑器的工作面，也是运行时契约。

### 5.1 能力总表

| 能力 | 游戏侧交付 | 数据落点 |
|---|---|---|
| 固定地图编写与存储 | 固定布局 Schema + 校验 + 存储 + 运行时装配 | `story_levels.data.map.fixed`（可选引用 `map.map_config` 复用经济参数） |
| 剧情编写与演出 | 阶段 / 效果 DSL、叙事块、演出表现类型、本地化键 | `story_levels.stages/narrative` + 本地化 |
| 初始状态设置 | 起始构筑 / 港口 / 资金 / 补给 / 货物 / 模块 / 已解锁系统 | `story_levels.start` + `systems` |
| 关卡数据调整 | 难度旋钮、目标数值、时限公式、奖励、失败与 checkpoint 策略 | `story_levels.difficulty/rewards/fail/checkpoint` |

### 5.2 固定地图编写与存储

**固定地图属于关卡本身，不新增平行地图结构，也不进自由模式的 `map_configs` 生成池。**
关卡数据的 `map` 块同时承载「地形」与「可选经济参数引用」：

```text
story_levels.data.map = {
  map_config: "core:map_config/standard",   # 可选：只复用经济 / 探索参数
  fog: "revealed" | "explored" | "unknown",
  fixed: {                                  # 必填：本关唯一地形来源
    ports: [{
      id,                                   # port_0..N，稳定 id，存档只存 id
      archetype, name_key,                  # 显示名走数据包本地化键
      position: [x, y],                     # 世界坐标
      facilities: ["exchange", "shipyard", "supply", ...],
      market: { <goods_id>: {stock, price} }   # 初始市场基线（可空）
    }],
    edges: [{from, to, distance, risk, bidirectional}],
    start_port: "port_0",
  }
}
```

- 关卡通过 `map.fixed` 直接装配固定布局；生成器跳过随机布局，只替换「布局来源」。
- 固定地图必须通过校验：港口 / 航线连通、id 唯一、引用存在、无随机依赖、世界坐标在范围内。
- 航线 / 海图 / 港口舞台 / 航行演出沿用现有运行时，只替换「布局来源」。
- 存储：数据包内 JSON；编辑器可导出、可 diff、可版本化；运行时不写回数据包。

### 5.3 剧情编写与演出

- 编排单位：`stages[]`（目标推进）+ `narrative.beats[]`（剧情节点）+ 简报 / 结算卡。
- 演出表现类型（首版最小集，数据里用 `presentation` 声明）：
  - `card`：全屏剧情卡（标题 + 多段正文 + 继续），复用现有 `SNStoryCard`；
  - `objective`：非阻塞目标条；
  - `briefing` / `debrief`：关卡开始 / 结算专用版式；
  - `toast`：轻提示；
  - 预留 `choice`（选项）、`radio`（无线电 / 通信）、`camera_hint`（镜头提示）。
- 文本只存本地化键；演出层不解析行为，行为仍由 `stages[]` 的条件与效果驱动。
- 编辑器可预览单段演出（不跑完整关卡），运行时按阶段顺序推送。

### 5.4 初始状态设置

```text
start = {
  starting_build: "core:starting_scenario/...",   # 船体 / 模块 / 初始补给（字段名沿用，值为 starting_scenario ID）
  port_id: "port_0",
  money: 180,
  ship_fuel: 6, ship_water: 4,
  cargo: [{item: <def_id>, amount}],           # 可空
  equipped_modules: [],                        # 可空
  world_time: "day_1_0600",                    # 可选，用于时限与文本
}

systems = {                                    # 与 start 分开：系统开放不是「初始资源」
  unlock_features: ["market", "contracts"],
  unlock_items: [], unlock_modules: [],
  lock_actions: ["loan"],
}
```

- 全部可被关卡数据覆盖；未声明字段走现有 `RunFactory` 默认。
- 与「每关独立」一致：不读取自由模式或上一关的资产。

### 5.5 关卡数据调整

- 可调项：难度旋钮、目标数值 / 计数、时限公式、风险系数、奖励、checkpoint 标记、重试策略、提示等级。
- 调整只改数据、不重编代码；首发关应能在编辑器里改完立即重新导出验证。
- 数值来源优先级：关卡数据 > 数据包 / Core 数值 > 框架默认；不在框架写死。

## 6. 剧情数据包（Story Pack）

**一个数据包 = 剧情模式里一个可直接玩的篇章（剧情战役）。** 完全手动配置，不经过任何生成器；
放进 `mods/` 即可被游戏加载，不需要改代码或重新编译。

### 6.1 包格式：只加剧情的模组

- **剧情包就是一个内容模组**，而且是一个「只加剧情」的模组：manifest 声明
  `content.story.v1`，内容文件只允许包含剧情相关类型；不新增包格式、不新增加载器。
- 采用现有 **`.snavmod.zip`**（或同结构的松散目录），复用扫描、Manifest 校验、依赖解析、
  资源挂载、Schema 校验、本地化与资源打包。
- 理由：项目的第一原则是「官方内容也是模组」；剧情包与第三方模组走同一条加载链，天然可
  被编辑器导出、可被 SDK 校验、可被玩家安装。
- **只加剧情的边界**（首发校验规则，已实现为 `story_pack_off_whitelist`）：

  | 允许 | 说明 |
  |---|---|
  | `story_arcs` | 篇章：标题 / 角色 / 术语 / 关卡顺序 |
  | `story_levels` | 关卡：**内嵌固定地图**、初始状态、任务线、叙事、难度、checkpoint、奖励 |
  | `localization` / `assets` | 剧情文本与演出资源 |

  **不允许**新增会被自由模式消费的通用内容（商品 / 船体 / 锅炉 / 模块 / 港口原型 / 委托 /
  事件 / 策略 / `map_configs` / `patch` 等）；剧情需要这些内容时，依赖 `core` 引用现有定义，
  而不是在剧情包里复制或新增。关卡地形不走 `map_configs`，直接内嵌在 `story_levels.data.map.fixed`
  （见 §7.3 与 D2），避免「固定地图」变成自由模式可抽取的公共内容。
  这样可以保证「装剧情包不会改变自由模式的玩法与数值」——与「奖励不影响自由模式」同一条不变量。

- 包内结构（一个包一个篇章，篇章内含多个关卡）：

```text
mods/<pack_id>/
  manifest.json            # id / name / version / capabilities: ["content.story.v1"]
  content/
    story_arcs.json        # 1 个 arc = 1 个可玩篇章
    story_levels.json      # N 个关卡定义（N >= 1，首发 N = 1）；固定地图内嵌在关卡里
  localization/
    zh_CN.json
    en.json
  assets/                  # 可选：立绘 / 音效 / 背景
```

- 参考实现：`sdk/templates/story_pack_iron_tide/`（1 篇章 + 2 关卡，中英文本齐全）。
  该目录放在 `sdk/templates/` 而不是 `sdk/examples/`：后者是运行时启动扫描根，而剧情包是
  Schema 2.0 草案内容，当前运行时不加载。

- **1 个包 = 1 个篇章 = N 个关卡**；关卡由 arc 的 `levels[]` 排序列出，加载器按顺序解锁。
  首发内容 N = 1，但格式与加载器必须支持 N > 1（用 2–3 关的手写测试包验证）。
- 包内内容只引用已注册类型；跨包引用（例如依赖 core 的商品 / 船体）走现有依赖规则。
- 未来若要一个包放多个篇章，再扩 arc 列表；首发不预留多 arc 的编辑器 UI。

### 6.2 加载与出现

```text
启动 → ModScanner 扫描 mods/ → Compile / 校验（含 content.story.v1 类型 + 只加剧情白名单）
     → 剧情模式入口可用 → story_mode.view 列出数据包中的 arc 与 arc.levels[]
     → 选 arc → 选关列表（按 arc.levels 顺序 / 解锁状态）→ run.start story_level=<id>
```

- 没有任何剧情包：主菜单「剧情模式」可置灰或进入后显示「未安装剧情内容」。
- 包校验失败：按 mod error 处理（不进入剧情模式；其他模组/自由模式不受影响）。
- 包内出现白名单外的通用内容类型：按剧情包校验错误处理，阻止加载（避免改动自由模式）。
- 包内的 `arc` 记录标题 / 摘要 / 角色 / 术语 / 关卡顺序 / 结局记录；`level` 记录地图、初始状态、
  任务线、叙事、难度、checkpoint、奖励。
- 关卡列表由 `arc.levels[]` 顺序 + 通关档案推导：未通关的下一关可选，已通关可重玩。
- 存档只记 `pack_id + version + arc_id + level_id`，不存定义本体；卸载包后进度保留，
  重新安装即可继续。

### 6.3 版本与兼容

- 数据包版本用 SemVer；存档记录版本与内容哈希，缺失/降级时给出可读错误，不静默继续。
- 内容更新只做兼容增量：已通关进度不重排、不重置；改关卡结构时升 minor 并在包内声明。
- 数据包可以声明最低 Framework API 版本；低于要求时拒绝加载。

### 6.4 验收（包级）

- [ ] 完全手写的 1 关数据包放进 `mods/` 后，游戏无需改代码即可进入并玩完。
- [ ] 含 2–3 关的手写测试包能正确列出关卡、按 `arc.levels` 顺序解锁、逐关进入。
- [ ] 包内若包含白名单外的通用内容，校验期报错并阻止加载。
- [ ] 删除数据包后剧情模式入口不可用、自由模式不受影响；重装后进度仍在（成就延后）。
- [ ] 数据包内所有引用可解析；缺本地化键、缺资源、循环依赖、引用缺失均在校验期报错。
- [ ] 同一数据包在两次加载间行为完全一致（固定地图、固定任务线、无随机布局）。
- [ ] 编辑器导出的包与手写包结构一致，round-trip 不丢字段。

## 7. 数据化存储契约

### 7.1 新增内容类型（Schema 2.0 草案，落地前登记为 `planned`）

| 类型 | 简写 | 作用 | capability |
|---|---|---|---|
| `story_arcs` | 剧情篇章 | 一个可玩篇章：标题 / 角色 / 术语 / **关卡顺序（N 关）** / 结局记录；可选溯源 | `content.story.v1` |
| `story_levels` | 剧情关卡 | 单关固定地图、初始状态、任务线、叙事、难度、checkpoint、奖励、失败策略 | `content.story.v1` |

- 两者以 `schema_version: "2.0"` 进 `content_types.json` 的 `draft_schemas` / `draft_types`，
  运行时暂不加载（与 `weapons` 草案同一流程）；S1 已完成登记，实现阶段再提升为 active。
- **固定地图内嵌在关卡数据里**（`story_levels.data.map.fixed`，见 D2）：港口 / 航道 / 坐标由
  关卡自己拥有，不进自由模式的 `map_configs` 生成池；`map.map_config` 只是**可选引用**，
  用于复用 Core 的经济 / 探索参数，地形始终以 `fixed` 为准。
- 关卡可以通过完整 ID 引用 `core` 的 `starting_scenarios` / `items` / `map_configs` 等现有定义，
  **不复制定义**；剧情包内不允许新增这些类型（白名单）。
- 角色 / 术语不单设内容类型：放进 `story_arcs.characters` / `story_arcs.terms`，由包本地化
  提供文本；游戏只按 id 引用与展示。

### 7.2 篇章定义形状（S1 已落地）

```json
{
  "id": "example:story_arc/iron_tide",
  "name_key": "story_mode.iron_tide.title",
  "description_key": "story_mode.iron_tide.summary",
  "enabled": true,
  "data": {
    "protagonist_id": "captain",
    "characters": [
      {"id": "captain", "name_key": "character.captain.name",
       "description_key": "character.captain.description",
       "role": "protagonist"}
    ],
    "terms": [
      {"id": "black_tide", "term_key": "term.black_tide.name",
       "definition_key": "term.black_tide.definition"}
    ],
    "levels": ["example:story_level/01_first_smoke", "example:story_level/02_homeward"],
    "canon": false,
    "completion_achievement": "iron_tide.complete",
    "source": {"world_bible": "iron_tide@1.4.0", "author": "story-team"}
  }
}
```

- 定义 envelope 与其它 2.0 类型一致（`schema_version` / `content_type` / `definitions[]`）；
  篇章标题 / 摘要直接用定义的 `name_key` / `description_key`，**不再单独设** `title_key` /
  `summary_key`，避免同一语义两处维护。
- `characters[].id` / `terms[].id` 是**篇章内局部标识符**（`^[a-z][a-z0-9_]{0,31}$`），
  不是跨定义引用；名称与释义文本全部来自本地化键。
- `levels` 是**有序、唯一**的关卡完整 ID 列表；顺序即解锁 / 展示顺序。关卡自身**不写**
  `arc_id` / `order` / `next_level`，篇章是唯一顺序来源（双写会漂移）。
- `levels` **允许为空**（先写世界观、后补关卡）：语义 warning `story_arc_empty_levels` 不阻塞
  编辑器 / CLI 写入；「至少一关」的硬要求放到 S2 加载与选关阶段。
- `canon` 标记官方正史（示例包为 `false`）；`completion_achievement` 可空，成就系统延后。
- `source` 可选，仅溯源，不参与校验。

### 7.3 关卡定义形状（S1 已落地）

```json
{
  "id": "example:story_level/01_first_smoke",
  "name_key": "story_mode.iron_tide.01.title",
  "description_key": "story_mode.iron_tide.01.summary",
  "enabled": true,
  "data": {
    "map": {
      "fog": "revealed",
      "fixed": {
        "ports": [
          {"id": "port_0", "name_key": "port.ash_harbor.name", "position": [40, 80],
           "facilities": ["exchange", "supply"], "market": {"coal": {"stock": 30, "price": 4}}},
          {"id": "port_1", "name_key": "port.iron_bay.name", "position": [160, 80],
           "facilities": ["exchange", "shipyard"]}
        ],
        "edges": [
          {"from": "port_0", "to": "port_1", "distance": 120, "risk": 0.05, "bidirectional": true}
        ],
        "start_port": "port_0"
      }
    },

    "start": {
      "starting_build": "core:starting_scenario/steady",
      "port_id": "port_0",
      "money": 200,
      "ship_fuel": 4,
      "ship_water": 3,
      "cargo": [],
      "equipped_modules": [],
      "world_time": "day_1_0600"
    },

    "systems": {
      "unlock_features": ["market", "contracts"],
      "unlock_items": [],
      "unlock_modules": [],
      "lock_actions": ["loan"]
    },

    "stages": [
      {
        "id": "opening",
        "checkpoint": true,
        "presentation": "briefing",
        "dialogue": {"title_key": "...", "body_keys": ["..."]},
        "advance": {"mode": "confirm"}
      },
      {
        "id": "buy_fuel",
        "presentation": "card",
        "objective": {"text_key": "...", "target": 6},
        "advance": {"event": "cmd:supply.buy_coal"}
      },
      {
        "id": "closing",
        "checkpoint": true,
        "presentation": "debrief",
        "advance": {"event": "story.level_complete"}
      }
    ],

    "narrative": {
      "brief": {
        "presentation": "briefing",
        "speaker_key": "character.captain.name",
        "title_key": "...",
        "body_keys": ["...", "..."]
      },
      "beats": [
        {"id": "farewell", "stage_id": "buy_fuel", "presentation": "choice",
         "dialogue": {"title_key": "...", "body_keys": ["..."]}}
      ],
      "debrief": {
        "presentation": "debrief",
        "success_keys": ["..."],
        "failure_keys": ["..."],
        "hook_key": "..."
      }
    },

    "difficulty": {
      "profile": "story.intro",
      "knobs": {"starting_money_scale": 1.0, "deadline_scale": 1.25,
                "risk_scale": 0.5, "coal_water_scale": 1.0, "hint_level": "full"}
    },

    "rewards": {
      "achievements": ["iron_tide.first_smoke"],
      "codex_entries": [],
      "cosmetics": []
    },

    "fail": {"default_mode": "checkpoint", "allow": ["checkpoint", "level_start"]}
  }
}
```

字段约束：

- 只存 ID 与键，不存本地化文本、不存生成结果；文本进数据包本地化（`story_mode.*`）。
- `map.fixed` 是本关唯一地形来源：`ports` ≥ 2、`edges` ≥ 1，港口 ID 形如 `port_0`；
  `start_port`、`start.port_id` 与航道两端都必须是已声明港口（语义错误
  `story_fixed_start_port_unknown` / `story_fixed_edge_port_unknown` / `story_start_port_unknown`）。
  从起点走不到的港口只报 warning（`story_fixed_map_disconnected`），不阻塞写作。
- `map.map_config` 是**可选引用**：只复用 Core `map_configs` 的经济 / 探索参数，地形仍以
  `fixed` 为准；不写也能完整跑一关。
- `stages[]` 复用 `common.schema.json#/$defs/story_stage`（阶段 ID、对白、unlock、objective、
  advance、effects），关卡层在其上新增 `checkpoint` / `presentation`；**至少一个**
  `checkpoint: true`（`story_level_checkpoint_missing`）。
- `narrative.beats[].stage_id` 必须属于本关阶段（`story_beat_stage_unknown`）；
  `fail.default_mode` 必须出现在 `fail.allow` 中（`story_fail_default_not_allowed`）。
- `rewards` 不允许出现数值奖励（钱 / 货 / 模块 / 解锁自由模式内容）；Schema 只允许
  `achievements` / `codex_entries` / `cosmetics`，且 `additionalProperties: false`。
- 关卡不可引用未注册内容；跨引用校验与现有规则同一套（草案文件跳过 Core 缺失检查）。

### 7.4 运行时状态（存档）

`GameState` 新增惰性块（不改 `schema_version` 的兼容增量，与 `data.story` 同一模式）：

```text
data.story_mode = {
  active: bool,
  pack_id: String,
  pack_version: String,
  arc_id: String,
  level_id: String,
  level_index: int,
  stage_index: int,        # -1 = 未开始
  attempt: int,
  counters: {String: int},
  flags: {String: bool},
  seen: [String],
  unlocked_features: [String],
  unlocked_items: [String],
  unlocked_modules: [String],
  checkpoint_stage_id: String,   # 最近一个 checkpoint 阶段
  failed: bool,
  completed: bool,
}
```

- 缺块 = 非剧情模式（自由模式），旧存档天然兼容。
- 一关 = 一次独立 run：进入关卡时走现有 `run.start` 链路（新增可选 `story_level` 参数），
  运行时存档仍是现有 autosave / checkpoint。
- **跨 run 的剧情档案独立存放**：新建 `StoryProfileService` 写
  `user://story_mode/profile.json`，保存 `completed_levels` / `achievements` / `best_results` /
  已解锁篇章；run 存档被重试或放弃覆盖时不丢进度。
- 重试 / 重开只重置关卡局部状态（`data.story_mode` + run 状态），不动 profile。

### 7.5 checkpoint 与失败 / 重试

- **按 checkpoint 走**：`stages[].checkpoint: true` 的阶段（以及关卡开始时）写入**关卡存档点**。
  实现为每关一个 checkpoint 存档（`user://story_mode/checkpoints/<level_id>.save`），复用现有
  `SaveService` 序列化路径，不引入第二套存档格式。
- 失败结算页默认给 **「回到最近存档点」**；同时保留 **「重开本关」** 作为第二选项：
  1. `story_mode.retry {mode: "checkpoint"}`：加载最近 checkpoint 存档，保留剧情进度；
  2. `story_mode.retry {mode: "level_start"}`：**重开本关**，状态回到关卡起点、剧情从简报重演。
- 关卡数据的 `fail.default_mode` 决定默认高亮哪个，两个选项首发都必须可用。
- **「重开剧情」= 重开本关**，不是重开整个篇章（已确认，2026-10-22）。
- 主动放弃（`abandon`）回主菜单，不写失败、不动通关进度。

### 7.6 命令与查询（草案）

| 类型 | 名称 | 说明 |
|---|---|---|
| Query | `story_mode.view` | 模式状态 + 当前关卡 + 目标 + 解锁 + 失败 / 重试选项 + 可用篇章列表（只读，QueryBus 克隆执行） |
| Query | `story_profile.view` | 剧情档案：已完成关卡、成就、最佳结果（主菜单 / 选关用） |
| Command | `run.start`（扩展） | 新增可选 `story_level`；存在时按关卡装配固定地图与初始状态，否则走现有自由模式 |
| Command | `story_mode.advance` | 剧情卡「继续」 |
| Command | `story_mode.observe` | Shell 在成功命令 / UI 事件后转发，驱动阶段推进 |
| Command | `story_mode.retry` | `{mode: "checkpoint" \| "level_start"}` |
| Command | `story_mode.abandon` | 放弃本关回主菜单（不清除通关进度与成就） |
| Command | `story_mode.skip` | 跳过剧情卡文本（不跳过关卡目标与系统门禁） |

- 阶段效果 / 条件语义与现有 `StoryService` 一致，优先**复用**而不是复制一套状态机；
  实现时把 `StoryService` 泛化为「教学流 / 关卡流」两种配置来源。
- 查询不得泄露 `target_port_id` 之类隐藏字段（沿用现有探索 / 线索裁剪规则）。

### 7.7 奖励：先留字段，成就延后

- 通关奖励**不写自由模式状态**：不送钱、不送船体、不送模块、不开放功能——这条首发就要守住。
- **成就系统延后到正式版交付前开发**。首发只保留数据字段与档案占位：
  `story_levels.rewards` 允许为空；`StoryProfileService` 预留 `achievements: []` 与
  `completed_levels`，UI 先不做成就页。
- 数据包里的 `rewards.achievements` 先只作为 ID 记录，不要求首发有成就定义、解锁动画或成就页。
- 图鉴 / 名词解释读数据包自带的 `terms` / `characters`，不额外复制文本（图鉴页同样延后）。

## 8. 剧情编辑器（Node Web）

### 8.1 定位

- **独立于 SNModMaker**，与 [SNBattleSim](../../SNBattleSim/README.md) / [SNModMaker](../../SNModMaker/README.md)
  同型：**Node 本地服务 + 浏览器 Web 应用**，零第三方依赖、无 CDN、无构建步骤。
- 它不替代 World Forge：输入是人工理解后的设定，输出是**剧情数据包**。
- 首发服务「1 个 arc + N 个 level」的编辑与导出（内容 1 关，格式支持多关）；不追求完整游戏编辑器。

### 8.2 形态：仓库根目录的 `SNStoryMaker/`

- 目录放在**仓库根目录**，与 `SNModMaker/`、`SNBattleSim/` 同级；名称确认为 **`SNStoryMaker`**。
- 与 SNModMaker / SNBattleSim 同型：Node 本地服务 + 浏览器 Web 应用，零第三方依赖、
  无 CDN、无构建步骤。

```text
SNStoryMaker/
├── index.html                # 应用外壳
├── css/app.css               # 暗色蒸汽朋克主题
├── js/schema-bundle.js       # 从 /schemas 生成（复用 SNModMaker 的 sync-schemas 流程）
├── js/store.js               # 篇章 / 多关卡 / 地图 / 本地化项目模型
├── js/validate.js            # Schema + 引用 + 本地化覆盖 + 剧情包白名单校验
├── js/map-editor.js          # 固定地图画布：港口 / 航线 / 设施 / 市场
├── js/flow-editor.js         # 关卡列表 + 阶段 / 条件 / 效果
├── js/ui.js                  # 表单、叙事文本、初始状态、难度、checkpoint
├── js/io.js                  # 导入 / 导出 .snavmod.zip 与项目文件
├── tools/serve.mjs           # Node 本地静态服务 + 磁盘 API
├── tools/export.mjs          # 无头导出 / 校验（供 agent / CI）
├── tests/                    # node --test + 浏览器冒烟
└── mods/                     # 本地工作区（gitignore）
```

- **能复用就复用**，不复制分叉：
  - Schema 包生成：复用 `SNModMaker/tools/sync-schemas.mjs` 的做法（或在仓库工具里抽公共生成器）；
  - ZIP 读写：复用 `SNModMaker/js/zip.js`（store / deflate-raw、CRC32、Godot `ZIPReader` 可读）；
  - 校验：复用 `SNModMaker/js/validate.js` 的 Schema 子集与语义校验，再追加剧情包白名单、
    地图连通、checkpoint、引用与本地化覆盖规则；
  - 导出：复用 `.snavmod.zip` 的 `mods/<id>/` 结构，保证导出包与 SNModMaker / SDK 同构。
- 如果复用需要跨目录引用，优先把共享纯逻辑抽到仓库级公共目录（例如 `tools/shared/`），
  而不是在两个编辑器里各留一份；具体抽法在实现时定，但**校验与包格式必须只有一份**。
- 与 SNModMaker 的差异：SNModMaker 是**按内容类型**的通用表单；SNStoryMaker 是**按篇章 →
  关卡流程**的专用工作台（多关列表 + 地图画布 + 阶段流程图 + 演出文本），面向非程序员。
- 沿用 SNModMaker 的约定：纯经典脚本、`globalThis.SN*` 暴露模块、`file://` 可打开、
  `tools/*.mjs` 为 Node ESM、测试分「Node 纯逻辑」与「CDP 浏览器冒烟」。
- 若后续发现编辑量太大，可把地图画布 / 流程图拆成独立子模块，但包格式与校验器保持一份。

### 8.3 功能（首发）

| 功能 | 说明 |
|---|---|
| 篇章配置 | 标题 / 摘要 / 主角 / 角色表 / 术语表；**多关卡列表与顺序**（首发 1 关，格式支持 N 关） |
| 固定地图 | 画布摆放港口（坐标 / 原型 / 设施 / 初始市场）与航线（距离 / 风险 / 双向）；连通性与 id 校验 |
| 关卡流程 | 阶段列表 / 条件 / 效果 / 目标文本；`checkpoint` 开关；失败默认重试方式 |
| 叙事编辑 | 简报 / beats / 结算 / 钩子；`presentation` 选择；本地化表格（中英覆盖率） |
| 初始状态 | 起始构筑 / 港口 / 资金 / 煤水 / 货物 / 模块 / 已解锁系统 |
| 数值调整 | 难度旋钮、目标数值、时限公式、奖励字段、风险系数 |
| 校验 | Schema、引用、本地化键、地图连通、白名单、checkpoint 至少 1 个、奖励无非法数值 |
| 导出 | `.snavmod.zip` + 项目文件；可写 `mods/`（本地服务） |
| 无头 CLI | `export` / `validate`，供 agent 与 CI 复用 |

### 8.4 不在编辑器里做的事

- 不写世界观（World Forge 的职责）；不做数值平衡模拟；不运行游戏领域逻辑。
- 不做模组启用 / 禁用、加载顺序（那是游戏侧 `mods/` 的职责）。
- 不做成就 / 图鉴页面（成就系统延后到正式版交付前）。
- 不做完整对话系统 / 分支剧情编辑器（首版线性）；预留扩展位。

## 9. 实施分片（建议）

| 切片 | 内容 | 验收口径 |
|---|---|---|
| S1 包与类型契约 | **✅ 已交付（2026-10-22）**：`story_arcs` / `story_levels` Schema 2.0 草案 + 内嵌固定地图 + 只加剧情白名单 + 多关包结构 + 有效 / 无效样本 + `sdk/templates/story_pack_iron_tide/` 示例包 | `gen_content_types --check` / `sync-schemas` / Node 与 Godot 草案测试通过；Core 不加载 |
| S2 加载链 | 剧情包作为内容模组加载、白名单校验、注册；`story_mode.view` 列出篇章与关卡列表 | 手动包放进 `mods/` 后入口出现；坏包 / 越界内容有可读错误；2–3 关测试包能列出关卡 |
| S3 垂直切片 | **首发 1 关内容**：固定地图、L1 系统、完整简报 / 节点 / 结算 | 主菜单进入 → 走完 → 结算 → 回主菜单 / 重新挑战 |
| S4 运行时 | `data.story_mode`、`run.start story_level`、`StoryService` 泛化、`story_mode.*`、checkpoint 重试 | 同数据两次进入完全一致；checkpoint / 重开本关可用；存档 round-trip |
| S5 UI | 主菜单模式入口、篇章 / 选关页（N 关）、简报 / 结算卡、关卡内 HUD、失败二选一弹窗 | 960×540 与 1440×900 不裁切；中英同步 |
| S6 剧情档案 | `StoryProfileService` + 通关进度 + 重玩（成就预留字段，实装延后） | 放弃 / 重试 / 重开不丢已通关进度 |
| S7 剧情编辑器 | `SNStoryMaker/` MVP：篇章 / 多关列表 / 地图 / 流程 / 叙事 / 初始状态 / 校验 / 导出 | 能编辑并导出首发关数据包，round-trip 一致 |
| S8 数据驱动验收 | 只改数据包（文本 / 目标 / 数值 / 地图坐标 / 关卡数量）重跑 | 不改代码即可产生可感知差异；框架 0 具体剧情 ID |
| S9 迁移（后续） | 正式版关闭自由模式教学、快速上手提示 | 旧存档可继续；新玩家 30 分钟内理解核心循环 |
| S10 成就（正式版前） | 成就定义 / 解锁 / 展示页；仍不写自由模式状态 | 通关后可查看成就；自由模式数值不变 |

优先做 S1–S3：先让 1 关数据包能加载、能玩完，再补编辑器；编辑器可以在 S3 之后用 JSON + 校验器
手工产出第一个包。

## 10. 与现有系统的关系

| 系统 | 关系 |
|---|---|
| World Forge（外部） | 只产出设定；游戏不读取、不依赖；转换由人工在编辑器完成 |
| 剧情编辑器（`SNStoryMaker/`，新，Node Web，仓库根目录） | 产出剧情数据包；与 SNModMaker / SNBattleSim 同级、同型、零依赖，复用其 Schema / 校验 / 打包 |
| 模组加载链 | 剧情包 = 内容模组，复用扫描 / Manifest / 依赖 / 资源 / 校验，不新增包格式 |
| `data.story`（教学） | 并存；剧情模式复用其阶段 / 效果 / 门禁语义，状态分开 |
| `StoryService` | 泛化为双配置来源；教学流与关卡流共用推进逻辑 |
| `run.start` / `RunFactory` | 增加 `story_level` 入参；固定地图路径与程序生成路径并列 |
| `MapGenerator` / `map_configs` | 不变量：自由模式仍走生成；固定布局只来自 `story_levels.data.map.fixed`，不注册进 `map_configs` |
| `SaveService` | run 存档照旧；新增 checkpoint 存档与剧情档案；旧档无 `story_mode` 块 = 自由模式 |
| `campaign` 分区 | 不参与；剧情模式不写 `data.campaign` |
| 委托 / 事件 / 线索 | 作为关卡内容被引用，不修改其定义 |
| Quest Phase B | 落地后关卡任务线优先复用 Quest 链 |
| Shell / UI | 新增模式选择与选关；关卡内剧情卡 / 目标条 / 门禁复用现有组件 |
| 静态文档 | 新增源码按 `@static-doc` 约定；本文档定稿后迁入 `docs/specs/` |

## 11. 风险

- **双轨状态机**：教学流与关卡流若各写一套推进逻辑，后续必然漂移 → 强制复用 `StoryService`。
- **固定地图 vs 生成地图双路径**：容易在航行 / 海图 / 迷雾里分叉 → 只替换布局来源，
  运行时不感知地图来源。
- **包与运行时解耦不足**：若数据包需要改代码才能加载新内容，就失去「直接加载为剧情战役」的
  意义 → 包格式、类型与校验必须先固化，再加内容。
- **存档语义冲突**：run 存档会覆盖，跨 run 进度（及后续成就）必须独立文件 → `StoryProfileService`。
- **编辑器重复建设**：独立剧情编辑器与 SNModMaker 可能各写一半 → 共用 Schema 与打包器，
  只做「地图 + 流程 + 演出」专用工作台；包格式单一。
- **1 关验证不足**：1 关只能验证数据驱动与演出，验证不了长线节奏 → 首发验收只承诺链路，
  第二关立项前先复盘数据契约是否够用。
- **人工转换成本**：World Forge 设定到配置全靠手工 → 编辑器必须把重复工作（本地化、引用、
  地图摆放）做顺，否则内容产能受限。
- **只加剧情白名单过严**：剧情若需要专用事件 / 委托，可能被迫塞进 core → 白名单要在
  「不污染自由模式」与「剧情表达力」间取舍；首版先要求引用 core，观察实际需求再决定是否
  引入「剧情私有内容」机制。
- **新手引导断档**：自由模式关掉教学后，跳过剧情模式的玩家没有引导 → 保留「快速上手」
  提示作为兜底（迁移阶段再做）。

## 12. 决策记录

| id | 决策 | 结论 | 日期 |
|---|---|---|---|
| D1 | 世界观归属 | 已确认：同一蒸汽朋克宇宙 + 独立正史海域 | 2026-10-22 |
| D2 | 固定地图表达 | **已确认（S1 修正）：固定地图内嵌在 `story_levels.data.map.fixed`**，不新增平行地图结构、不进 `map_configs` 生成池；`map.map_config` 仅可选复用经济参数 | 2026-10-22 |
| D3 | 关卡进度存储 | 建议：独立 `StoryProfileService`（`user://story_mode/profile.json`） | 待实施验证 |
| D4 | 失败策略 | **已确认：按 checkpoint 回档**；「重开剧情」= 重开本关（从简报重演） | 2026-10-22 |
| D5 | 与现有教学关系 | 先并存；首发不动自由模式教学，正式版由剧情模式接管 | 2026-10-22 |
| D6 | 内容类型命名 | **已确认并落地（S1）：`story_arcs` + `story_levels`**（Schema 2.0 草案，capability `content.story.v1`） | 2026-10-22 |
| D7 | 跳关 / 重玩 | 通关后可重玩，不可跳未解锁关 | 建议 |
| D8 | 关卡间资产继承 | **已确认：每关独立起始条件，不继承船 / 钱 / 货** | 2026-10-22 |
| D9 | 分支叙事 | 首版线性 + 单点选择 | 建议 |
| D10 | 世界观生产方 | **已确认：World Forge 只交付世界观；游戏侧不依赖、不自动转换，配置由人工完成** | 2026-10-22 |
| D11 | 主角 | **已确认：固定剧情主角**（叙事连续、数值不滚雪球） | 2026-10-22 |
| D12 | 首发范围 | **已确认：只做 1 关，验证纯数据驱动演出** | 2026-10-22 |
| D13 | 通关奖励 | **已确认：不影响自由模式**（不送数值 / 不解锁玩法）；成就 / 图鉴 / 外观延后到正式版前 | 2026-10-22 |
| D14 | 剧情编辑器 | **已确认：独立于 SNModMaker，Node Web；`SNStoryMaker/` 放仓库根目录**（与 SNModMaker / SNBattleSim 同级），能复用就复用 | 2026-10-22 |
| D15 | 数据包格式 | **已确认：内容模组 `.snavmod.zip`，且是「只加剧情的模组」**，加载即玩 | 2026-10-22 |
| D16 | checkpoint 粒度 | **已确认：按阶段标记 `checkpoint`，每个 checkpoint 阶段一个存档点** | 2026-10-22 |
| D17 | 包内关卡数 | **已确认：一个包支持多个剧情关卡**（`arc.levels[]`）；首发内容 1 关，格式与加载器按多关设计 | 2026-10-22 |
| D18 | 成就系统 | **已确认：延后到正式版交付前开发**；首发只留字段与档案占位 | 2026-10-22 |

## 13. 验收口径

### 13.1 S1（数据契约，已通过）

- [x] `story_arcs` / `story_levels` 进入 `content_types.json` 的 `draft_schemas` / `draft_types` / `planned`，
      `gen_content_types --check` 与 `sync-schemas` 通过，运行时类型表不变。
- [x] 合法样本零错误；非法样本（缺必填 / 非法枚举 / 非法港口 ID / 缺 checkpoint 等）能被 Schema
      与语义校验分别报出。
- [x] `sdk/templates/story_pack_iron_tide/` 作为手写包：`content.mjs validate --mod` 0 error，
      只出现预期的 `draft_content` warning；导入 / 导出 round-trip 不丢字段。
- [x] 白名单：同一故事包里加入 `items` 内容会产生 `story_pack_off_whitelist` error（CLI 退出码 1）。
- [x] `catalog.DEFAULTS` 的篇章 / 关卡默认值可直接通过对应 Schema，空篇章 / 孤儿关卡只警告。
- [x] 全量无头测试 0 failed；`gen_static_docs --check` 通过。

### 13.2 首发（1 关数据包，游戏侧）

首发（1 关数据包）验收：

- [ ] 完全手写的数据包放进 `mods/` 后，游戏**不改代码**即可进入剧情模式并玩完。
- [ ] 含 2–3 关的手写测试包能正确列出关卡、按顺序解锁并逐关进入（首发正式内容仍 1 关）。
- [ ] 剧情包只含白名单类型；若含商品 / 船体等通用内容，校验期报错并阻止加载。
- [ ] 没有数据包时剧情模式入口友好不可用；删除 / 重装数据包不影响自由模式与进度。
- [ ] 首发关地图在两次进入间**完全一致**（无随机布局），seed 不影响布局。
- [ ] 关卡内容全部来自数据包；框架内不存在具体剧情 / 港口 / 商品 ID。
- [ ] 只改数据包（文本、目标数值、初始状态、地图坐标、难度旋钮、checkpoint、关卡数量）即可改变体验。
- [ ] 关卡满足 §3.1 起承转合结构；固定主角视角一致。
- [ ] 失败后「回到 checkpoint」与「重开本关」都可用，且不会丢已通关进度。
- [ ] 通关只产生剧情档案记录（成就延后），**自由模式数值与解锁状态不变**（测试守护）。
- [ ] 数据包校验覆盖 Schema、引用、本地化键、地图连通、白名单、奖励类型；坏包有可读错误。
- [ ] 旧存档无 `story_mode` 块时行为不变；中英文本同步；960×540 与 1440×900 不裁切。
- [ ] 全量无头测试 0 failed；`gen_static_docs --check` 通过。
- [ ] `SNStoryMaker/` 能打开、编辑、校验、导出该数据包，round-trip 不丢字段。

后续（多关 / 引导接管）另立验收：每关只引入一组系统、自由模式教学关闭后的兜底提示、
新手 30 分钟理解核心循环等。

## 14. 开放问题

- **只加剧情白名单的边界**：剧情关卡若需要专用航行事件 / 委托模板，是允许包内新增（会进全局
  注册表）还是必须引用 core？首版建议先只允许引用 core；真需要时再评估「剧情私有内容」机制。
- 一个数据包是否允许包含多个 arc？首发明确 1 包 1 arc（多关）；多 arc 留到有需求再扩格式。
- 角色 / 术语是否长期留在 `story_arcs` 内，还是后续升格为独立内容类型
  （`story_characters` / `story_terms`）？
- checkpoint 存档点数量上限：每关最多几个？建议 3–5 个，防止存档体积与回档选择膨胀。
- 「通关记录 / 最佳结果」记什么：耗时、事故数、评级？首版可只记 completed + 时间戳。
- 编辑器是否需要「导出前模拟跑一遍」（无头领域模拟）来发现数值不可行？首版建议不做。
- 剧情包与自由模式共享存档目录时，是否需要「剧情模式专用存档槽」的 UI 区分？
