# `framework/domain/story/story_service.gd`

> 作用：新手剧情 / 教学系统的领域状态机。读取当前场景定义（`map_configs`，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `StoryService` | L1 |
| `FEATURE_OVERVIEW` | L37 |
| `FEATURE_SUPPLY` | L38 |
| `FEATURE_CHART` | L39 |
| `FEATURE_MARKET` | L40 |
| `FEATURE_CONTRACTS` | L41 |
| `FEATURE_CLUES` | L42 |
| `FEATURE_TAVERN` | L43 |
| `FEATURE_SHIPYARD` | L44 |
| `FEATURES` | L45 |
| `EVENT_STAGE_ENTERED` | L50 |
| `EVENT_COMPLETED` | L51 |
| `EVENT_FEATURE_UNLOCKED` | L52 |
| `config(state: GameState, hub: RegistryHub) -> Dictionary` | L58 |
| `begin(state: GameState, hub: RegistryHub, rng: RngService = null) -> void` | L66 |
| `view(context) -> Dictionary` | L92 |
| `market_filter(state: GameState, hub: RegistryHub) -> Dictionary` | L149 |
| `module_filter(state: GameState, hub: RegistryHub) -> Dictionary` | L160 |
| `advance(context) -> Dictionary` | L170 |
| `skip(context) -> Dictionary` | L198 |
| `observe(context, event: String, data: Dictionary = {}) -> Dictionary` | L225 |
| `guaranteed_explore_clue_id(state: GameState) -> String` | L555 |
| `consume_guaranteed_explore_success(state: GameState, clue_id: String) -> bool` | L564 |

C4 起 `map_profiles` 退役）的 `data.story`（Core JSON）阶段表，维护
`GameState.data.story` 的进度、事件计数、标志、功能 / 商品 / 模块解锁，并分发
「发现委托目的港」等剧情效果。

- 关键依赖：`GameState.ensure_story()`、`ContentRefs.map_config_data()`、`WorldOps`、
  `MapOps`、`GameState.contracts()`

## 契约与约束
- 剧情步骤 / 文案 / 解锁 / 数值全部来自 Core JSON；框架只认识 feature 键
  （`FEATURES`）与效果类型，不写死内容 ID。
- `data.story` 惰性 ensure：旧存档没有该块时视为「已看完 / 已跳过」，功能全开、
  不弹剧情（`completed=true`），不改 `schema_version`。
- 阶段推进：`mode=confirm` 由 `story.advance` 推进；条件型阶段在
  `story.observe(event, data)` 中按 `event / counter / at_least / flag / all`
  评估，可一次跨多个阶段。未知效果只 warning，不崩。
- 4.5.4 效果：`grant_clue`（目标 `next_unknown` 时确定性选最近的未发现港并记忆，
  第二次授予复用同一目标；等级 / 来源来自 Core）、`set_market_price_bias`
  （把指定商品在起始港 / 其它港的库存与价格 bias 归位，保证教学价差稳定）、
  `guarantee_explore_success`（只对刚授予的剧情线索生效，探索成功即消费）。
- 4.5.5 效果：`add_facility`（给当前港补设施，第三港保证有船厂）、`upgrade_hull`
  （换成 Core 指定、带客舱位的船体，旧船进仓库）；`module_filter()` 给船厂提供
  `unlocked_modules` 裁剪，剧情期间只露出教学模块。
- 4.5.6 引导：`set_counter_from_ship` 用船上现有资源初始化计数器，条件支持
  `counter_from` 直接读取命令返回的数值（如补给购买后的煤舱 `stock`），
  目标条据此显示真实进度与「还差 N」。
- 跳过教程必须解锁 `skip_unlocks` 里的全部功能并执行
  `discover_contract_destination`，保证跳过不会卡死；跳过不会设置保底探索。
- 查询（`story.view`）只输出公开字段；counters / flags 只暴露剧情效果需要的
  `lock_actions` 语义，不泄露内部数值。

模块索引：[framework/domain](../README.md)
