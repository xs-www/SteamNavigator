# 后续开发计划（2026-10-20 对齐）

> 定位：这份计划接在「MVP 闭环 + 内容全部模组化 + 编辑器原生工作区 + 3D 船厂首个切片」之后，
> 用于决定接下来 2–4 周做什么、为什么做、怎样算完成。
> 详细路线图见 [FULL_GAME_ROADMAP.md](FULL_GAME_ROADMAP.md)，战斗边界见
> [COMBAT_ARCHITECTURE_REVIEW.md](COMBAT_ARCHITECTURE_REVIEW.md)，舞台方案见
> [2.5D_STAGE_PLAN.md](2.5D_STAGE_PLAN.md)。

## 0. 当前基线（已完成）

- MVP：贸易 / 委托 / 航行 / 船厂 / 通关闭环稳定，144 个 Godot 测试、33 个 Node 用例、1 个服务冒烟、17 个浏览器用例通过。
- 内容交付：数据、模型、横幅全部随 `core` 模组发布；发布 PCK 已排除 `assets/models/*`，本体只保留框架资源。
- 运行时加载：`ContentAssetLoader` 从模组包读原始 `.glb/.png`；船体模型由 `information.model` 资产键决定。
- 编辑器：`dev_mods/core` 可作原生工作区直接编辑保存（删除/新增定义与内容文件会写回，资产不动）。
- 3D：船厂正常态已有固定机位 3D 舞台；第二切片已交付通用 `StageHost`/`LocationStage`、`ShipyardStage` 迁移与 `PortStage` 骨架（独立预览 + 9 个舞台测试）；港口设施锚点的 6 件模型已接线 `facility_visuals`。
- 持久化：存档 Schema 2.0、Campaign 分区、模块实例与部件损耗、Save 迁移完成。

## 1. 近期：P0 收口（1 天）

| 任务 | 为什么 | 完成标准 |
| --- | --- | --- |
| 提交剩余改动 | 仓库里仍有其他会话未提交的编辑器 CLI / 港口生成器；未提交会让 CI 与发布不一致 | `git status` 干净；`core-index`、静态文档与源码一致 |
| 发布包再验一次 | 资产改为模组后、编辑器工作区上线后，发布链需要回归 | `pack_core` + 导出 + exe 启动；3D 船厂与港口横幅都来自 `mods/` |
| CI 门禁补齐 | 新增 `workspace-smoke`、`core-index --check` 等还没有进发布流程 | release workflow 跑 Node/服务/工作区冒烟与 `gen_content_types --check` |

## 2. 近期：编辑器工作区闭环（P1，1–2 天）

1. **保存前校验**：工作区保存时先跑编辑器 Schema 校验，`error > 0` 时阻止写入或强提示；保存成功后调用 `node SNModMaker/tools/content.mjs validate --mod dev_mods/core`（可选 `--godot`）。
2. **保源写入**：用 `content_json.mjs` 的节点级编辑替代整文件 `JSON.stringify`，让 core 的 git diff 只包含真正改动（当前第一次保存会重排格式）。
3. **core 索引自动同步**：保存 `manifest.id === "core"` 的工作区后自动跑 `sync-core-index.mjs`，避免编辑器索引过期。
4. **资产工作区**：资源页列出 manifest 资产键（当前为占位），支持新增/替换 GLB 并写入 `core/assets`；新增模型后刷新 Core 索引。
5. **打包入口**：工作区页提供「打包 core」按钮或命令提示，导出 `dist/mods/core-<version>.snavmod.zip`，避免手动拼发布包。

验收：在编辑器里删一条定义、加一条定义、加一个本地化键、加一个模型资产，`git diff` 只出现对应文件与最小行；`content.mjs validate --godot` 通过。

## 3. 近期：3D 舞台第二切片（P1，2–3 天）

1. **StageHost + LocationStage 泛化** ✅ **已完成**：`SNStageHost` 独占 SubViewport/World3D，驱动 `enter → bind → exit`；支持隐藏即停更、缺失场景回退 2D、`render_shrink`；`SNShipStage3D` 重写为宿主适配器，船厂舞台迁入 `ShipyardStage`。
2. **PortStage 骨架** ✅ **已完成**：按 `facilities` 装配设施（billboard 默认，`facility_visuals` GLB 替换，缺席只放货堆 filler），L0 天空/L1 banner 背板（缺失不放黑盒）/L2 确定性岸线剪影/L3 设施/L5 玩家船已跑通；`facility_anchors()`/`facility_screen_anchor()` 已提供；独立预览 `dev_scenes/port_stage/` 与截图脚本已产出 [完整港口](screenshots/port_stage/port_stage_preview.png) / [稀疏港口](screenshots/port_stage/port_stage_sparse.png)。6 件锚点 GLB 已接线 `facility_visuals`。
3. **场景填充**（待办）：L0 天空 + L1 远景背板（先用 5 张港口 banner 烘焙）+ L2 岸线，按 2.5D 方案 §7 的层级预算细化；当前 L0–L2 只是初版，L6 前景框与 L7 蒸汽/雾未做。
4. **港口差异参数**（待办）：`diorama` 块（kit/size/palette/landmark/facility_visuals）接入 `port_archetypes`，保证「设施决定建模」。

验收（待完成）：总览页可切换到 3D 港口舞台，2D HUD 不变；不同 `facilities` 的港口出现/缺少对应设施；资产缺失时回退 2D 背景。当前 PortStage 只在独立预览场景验证（页面背景层、2D 热点、场景填充细化与 diorama 参数仍待接入）。

## 4. 中期：玩法主线（P2，阶段 1 → 2）

1. **模块 condition 进入派生属性**（0.5 天）：受损锅炉/导航/安全/货舱/客舱按状态降低速度、载重、风险与容量；补回归测试。
2. **战斗内容 Schema 2.0 草案**（1 天）：`weapons` / `enemy_archetypes` / `encounter_tables` / `loot_tables`，保持 `planned`；有效/无效样本测试。
3. **自动结算原型**（2–3 天）：`CombatResolver` 纯函数 + `combat.resolve` 命令 + 单船 vs 单船；战利品进仓库/市场；失败接现有维修与债务。
4. **世界探索运行时**（阶段 1 主线，3–5 天）：把 `regions/sites/route_templates/world_profiles/start_profiles` 从 `planned` 提升 active；接世界生成、`campaign.world` 探索进度、海图迷雾与低细节远方模拟。

## 5. 中期：发布与质量（持续）

- 导出实测矩阵：Windows / Linux、1440×900 / 1280×720 / 960 宽；3D 舞台与模组资产加载纳入验收。
- 性能预算：单舞台 draw call ≤ 120、三角面 ≤ 60k；隐藏舞台停更；低配回退。
- 内容量：5 个港口原型 + 玩家舰船 + 至少 1 套港口设施锚点；新内容全部走 `core` 模组与 `content.mjs`。
- 文档：每轮改动更新 `docs/static`、`todo.md` 与相关 design 文档；发布前 `sdk/validate.gd` + `pack_core` 零错误。

## 6. 依赖与风险

| 风险 | 影响 | 应对 |
| --- | --- | --- |
| 多会话同时改仓库 | 未提交改动与冲突 | 先收口再开工；工具类文件按 ownership 分开；每次提交前 `git status` |
| 编辑器整文件重排 | core 的 diff 过大、review 困难 | P1 的「保源写入」优先做 |
| 3D 资产量与性能 | 港口舞台卡顿 | 先 billboard 占位验证构图，再逐件替换；LOD + 远景剪影 |
| 模组资产加载（原始 GLB/PNG） | 发布包与开发态行为不一致 | 每次发布验收都跑「本体无模型 + core 模组」组合 |
| Content Schema 2.0 提升 active | 旧档/旧内容兼容 | 提升前补迁移与回归矩阵；先只提升世界生成需要的类型 |

## 7. 建议执行顺序

1. P0 收口（提交、发布回归、CI 补齐）
2. 编辑器工作区闭环（校验 + 保源写入 + 索引同步）
3. StageHost + PortStage 骨架（配你的设施模型）
4. 模块 condition 进属性 → 战斗 Schema 草案 → 自动结算
5. 世界探索运行时
