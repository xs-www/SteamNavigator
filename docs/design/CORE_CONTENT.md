# Core 内容基线（MVP）

> 从 README 拆出的内容/数值概览；数值真源始终是 [dev_mods/core/content/](../../dev_mods/core/content/)，修改后跑校验与测试。

- 5 个港口原型：铁港、香料港、自由镇、渔村、玻璃港。
- 每局生成 4–5 个港口的连通分支网络；造船厂与情报站保证在起点 2 条边内。
- 7 种普通商品（含委托货箱）+ 2 种补给商品（煤炭/淡水）+ 3 种专用造船材料。
- 4 个船体（小型/中型/大型）、3 个锅炉、3 个货舱、2 个导航、2 个安全、1 个固定客舱。
- 六类模块都带打造配方：tier1 为**仅金币**配方（`materials: []` + `craft_cost` + `craft_time_hours`，反馈 1），tier≥2 额外消耗材料与 `craft_cost`；两个造船厂港口限量出售精密齿轮。
- 经济 / 标准 / 极速三种锅炉策略；工程师 / 领航员岗位。
- 5 段主线 + 4 种普通委托；2 类事件（锅炉过热、偶遇商船）。
- 2 套初始构筑：低耗稳健型、高速冒险型。
- 2 条 Quest 内容：`core:quest/first_voyage_guide`（`auto_start:true`，开局自动接取的燃料/出航引导）与
  `core:quest/shipyard_refit`（`auto_start:false`，预备 / 调试内容，玩家入口后续切片接入）。
- 15 条 Core 实体已配置新版 `information.texture/model`：船体、锅炉、商品、造船材料与铁港可直接解析对应贴图或 GLB 模型。
- 所有数值均为数据驱动，位于 `dev_mods/core/content/*.json`。
