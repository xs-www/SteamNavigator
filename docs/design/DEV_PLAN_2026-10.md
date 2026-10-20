# 后续开发计划（2026-10-20 对齐）

> 定位：这份计划接在「MVP 闭环 + 内容全部模组化 + 编辑器原生工作区 + 3D 船厂首个切片」之后，
> 用于决定接下来 2–4 周做什么、为什么做、怎样算完成。
> 详细路线图见 [FULL_GAME_ROADMAP.md](FULL_GAME_ROADMAP.md)，战斗边界见
> [COMBAT_ARCHITECTURE_REVIEW.md](COMBAT_ARCHITECTURE_REVIEW.md)，舞台方案见
> [2.5D_STAGE_PLAN.md](2.5D_STAGE_PLAN.md)。

## 0. 当前基线（已完成）

- MVP：贸易 / 委托 / 航行 / 船厂 / 通关闭环稳定，168 个 Godot 测试、33 个 Node 用例、1 个服务冒烟、17 个浏览器用例通过。
- 内容交付：数据、模型、横幅全部随 `core` 模组发布；发布 PCK 已排除 `assets/models/*`，本体只保留框架资源。
- 运行时加载：`ContentAssetLoader` 从模组包读原始 `.glb/.png`；船体模型由 `information.model` 资产键决定。
- 编辑器：`dev_mods/core` 可作原生工作区直接编辑保存（删除/新增定义与内容文件会写回，资产不动）。
- 3D：船厂正常态已有固定机位 3D 舞台；`StageHost`/`LocationStage`、`ShipyardStage` 迁移、`PortStage` 骨架/场景填充、总览页接入、Bounty Train 式主界面 HUD、港口街景 10 件与 `port.diorama`/`town_visuals` 接线均已完成；第六切片再完成 HUD 图标化、主题化招牌、街景密度（normal 47 件）、设施/街景/玩家船静态合批（实测 63/56 draw calls）与无 banner 三层程序化远景；第七切片把港口做成连续港区，市场/港务/补给是同一码头上的相邻站位，切页只平移镜头、把船开到对应泊位并换上右侧 640 px 泊位面板（30 个舞台用例 + 主界面站位接线用例）。
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
2. **PortStage 骨架** ✅ **已完成**：按 `facilities` 装配设施（billboard 默认，`facility_visuals` GLB 替换，缺席只放货堆 filler），L0 天空/L1 banner 背板（缺失不放黑盒）/L2 确定性岸线剪影/L3 设施/L5 玩家船已跑通；`facility_anchors()`/`facility_screen_anchor()` 已提供；独立预览 `dev_scenes/port_stage/` 与截图脚本已产出 [完整港口](screenshots/port_stage/port_stage_preview.png) / [稀疏港口](screenshots/port_stage/port_stage_sparse.png)。6 件锚点 GLB 已接线 `facility_visuals`。**总览页接入已完成**：全窗 `PortStage` 背景层 + 2D 设施热点（相机投影 Ghost Button，点击进对应设施页）+ 俯瞰/返回切换 + 失败回退 2D；截图 [总览 3D 港口舞台](screenshots/overview_port_stage.png)，`test_ui_shell` 新增 1 例守护。
3. **场景填充** ✅ **已完成**：L0 程序化暖色天空 + 太阳光晕；L1 有 banner 用背板、无 banner 用 3 层程序化 painted backdrop（暖霞渐变 + 双光晕）；L2 双深度带 MultiMesh 剪影（小/中/大 7/10/13 栋 + 2/2/3 吊机，仅无 banner）；L6 左上角 3 根前景构件；L7 3 组蒸汽粒子 + 2–3 层雾带。全部程序化、无新资产，preview ≈114 draws / 17,954 tris、sparse ≈73 / 19,228（≤120 / ≤60k）。**注**：原计划「5 张港口 banner 烘焙」改为程序化 painted backdrop——目前内容侧只有铁港 1 张 banner，其余港口直接走兜底路径。截图 [完整港口](screenshots/port_stage/port_stage_preview.png) / [稀疏港口](screenshots/port_stage/port_stage_sparse.png)。
4. **港口差异参数** ✅ **已完成**：`port_archetype.schema` 新增 `diorama`（kit/town/facility_visuals/palette/landmark）；五港 `diorama.kit/town`（16 项）+ core manifest 10 个 `model.prop.*`（资产 65→75）；`map_generator` 持久化 `diorama`，`port.view` 解析 `town_visuals`（旧存档按 archetype 回填）；PortStage L2b 装配 29 件镇区道具、建筑缺失回退 blockout、town 存在时跳过 L2 剪影。
5. **Bounty Train 式主界面 + 港口街景** ✅ **已完成**：默认 3D 主界面、121 px 紧凑 chrome、左右设施招牌 + 出航招牌、60 px 底部状态条、详细总览抽屉、2D 回退；街景 10 件 `SN_HT_*`（6204 tri，Verifier R1 passed）与截图 [主界面](screenshots/overview_port_stage.png) / [详细总览](screenshots/overview_detail.png)。
6. **主界面美术收尾 + 街景密度 + 性能回收（第六切片）** ✅ **已完成**：HUD 资源图标（`AssetService.find_key` 裸键解析）、自绘木牌/铁框/黄铜铆钉招牌 + 设施徽记 + 悬停光晕；街景 normal 29→47（`port.size`/`diorama.density` 分档，sparse 28 / busy 63）；设施/街景/玩家船静态合批，实测 draw calls **63/56**（原 284/255），37k/30k tris；无 banner 港口 3 层程序化远景（1 个 MultiMesh）；截图 [主界面 1440](screenshots/overview_port_stage.png) / [主界面 960×540](screenshots/overview_port_stage_960.png) / [详细总览](screenshots/overview_detail.png)。新增 `tools/godot/measure_port_stage.gd` 实测工具。
7. **连续港区 + 港务/市场/补给相邻站位（第七切片）** ✅ **已完成**：按 Bounty Train「场景相邻、切场景只移动玩家船和镜头」重做港口表现——`PortStage` 的码头延长到 160 m，市场 / 港务 / 补给三个站位沿 X 相邻排布（`STATIONS` 定义每个站位的镜头 pose、泊位与道具组），`exchange` / `supply` 设施分别搬到 -30 / +30；新增 `focus_station(station, framing, immediate)` / `advance_station(delta)` / `is_station_transitioning()`：切页只在 0.6 s 内平移镜头并把玩家船（先转艏）以 24 m/s 开到新泊位，港口/街坊/设施/合批层不重建，泡沫环随船移动；相机朝向层（天空、painted backdrop、banner、前景框、雾带）按平移量保持构图，L2 剪影留半速视差；站前道具每站 5/8/11 件（复用现有 town kit，`station_prop_count()` 单独计数）。主界面 `STAGE_SCREENS` 让 overview/market/supply 共用同一 `PortStage` 实例，市场/补给页改为右侧 640 px 泊位面板 + 左侧 3D 街景，站位间导航不播黑场淡出。截图 [市场站位](screenshots/market_station.png) / [补给站位](screenshots/supply_station.png) / [市场站位 960×540](screenshots/market_station_960.png) / [连续港区市场镜头](screenshots/port_stage/port_stage_market.png)。

验收（已完成）：主界面默认全窗 3D 港口舞台 + 紧凑 HUD + 两侧招牌 + 底部状态条 + 详细抽屉，2D HUD 不变；不同 `facilities` 的港口出现/缺少对应设施；资产缺失时回退 2D 背景；场景填充与 diorama/街景接线完成；港口成为连续港区，港务/市场/补给切页只移动船与镜头、同一舞台实例复用；draw call 在预算内（167 测试全绿）。剩余：出航进港演出、质量档位/低配回退、L2 LOD、委托/情报页的舞台化（船厂已有独立舞台）。

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
