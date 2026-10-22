# Core 内容基线（MVP）

> 从 README 拆出的内容/数值概览；数值真源始终是 [dev_mods/core/content/](../../dev_mods/core/content/)，修改后跑校验与测试。

- 5 个港口模板（`port_templates` 2.0，C4 由 port_archetypes 改名）：铁港、香料港、自由镇、渔村、玻璃港。
- 每局生成 4–5 个港口的连通分支网络；造船厂与情报站保证在起点 2 条边内。
- 7 种普通商品（含委托货箱）+ 2 种补给商品（煤炭/淡水）+ 3 种专用造船材料，统一为 `items` 2.0（`data.crafting_material` 区分材料）。
- 4 个船体（小型/中型/大型）、`modules` 2.0 的锅炉 / 货舱 / 导航 / 安全 / 客舱（C1 由六类模块合并）。
- `modules` 都带打造配方：tier1 为**仅金币**配方（`materials: []` + `craft_cost` + `craft_time_hours`，反馈 1），tier≥2 额外消耗材料与 `craft_cost`；两个造船厂港口限量出售精密齿轮。
- `boiler_strategies` 2.0 三种策略（经济 / 标准 / 极速）；`crew_roles` 2.0 工程师 / 领航员岗位（C4 由 strategies/roles 改名）。
- 5 段主线 + 4 种普通委托，属于 `contracts` 2.0（C4-D 升级）；2 类 `voyage_events` 2.0（C4-C 由 events 改名，锅炉过热 / 偶遇商船）。
- 2 套初始场景（`starting_scenarios` 2.0，C4 由 starting_builds 改名）：低耗稳健型、高速冒险型；显式补丁使用 `patches` 2.0
  （`v2/patch.schema.json`，默认文件 `content/patches.json`；Core 当前不随包发布补丁文件）。
- 2 条 Quest 内容：`core:quest/first_voyage_guide`（`auto_start:true`，开局自动接取的燃料/出航引导）与
  `core:quest/shipyard_refit`（`auto_start:false`，预备 / 调试内容，玩家入口后续切片接入）。
- 15 条 Core 实体已配置新版 `information.texture/model`：船体、锅炉、商品、造船材料与铁港可直接解析对应贴图或 GLB 模型。
- D1 战斗内容 6 个文件（均 2.0，capability `content.combat.v1`）：`weapons` 5 件（甲板速射炮 / 重型加农 / 臼炮 / 连发炮 / 舷炮，对齐 SNBattleSim 数值与 `weapon-assembly@2`）、`damage_types` 4 种（动能 / 爆炸 / 燃烧 / 电击）、`combat_abilities` 4 个、`enemy_archetypes` 4 个、`encounter_tables` 2 张、`loot_tables` 2 张。
- D0 模拟时钟是运行时状态而非内容：`data.sim` 惰性保存 `paused` / `speed` / `tick`，以 1 游戏小时固定步长推进，不新增 Core 内容文件、不改现有数值。
- Core 当前共 **25 个内容文件**（19 个基础/世界/战役/任务 + 6 个战斗；`patches` 只在类型层，无 Core 补丁文件）。
- 所有数值均为数据驱动，位于 `dev_mods/core/content/*.json`。
