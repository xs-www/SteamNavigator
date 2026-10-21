# `tools`

> PowerShell 辅助脚本、Godot 验收 / 截图脚本、建模工单 / 参数化生成器与静态文档生成器。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `art/gen_iron_harbor_trim_sheet.py` | 铁港建筑套件**共享 trim sheet 的确定性画图器**：按 `docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.spec.json` 画出 4×4×512 px 图集（评审件）与 16 张 512² 独立平铺贴图（运行时采样件），并写 stats。 | [查看](./art/gen_iron_harbor_trim_sheet.py.md) |
| `art/gen_shared_material_textures.py` | 生成通用共享材质贴图库（每张 512² 无缝平铺的 sRGB 贴图对应一个 `SN_*` 材质）， | [查看](./art/gen_shared_material_textures.py.md) |
| `art/gen_shipyard_textures.py` | 船厂两张授权贴图的确定性生成器：纵剖图 `ship_section.png`（1792×1008）与船卡缩略图 `ship_thumb_ironclad.png`（640×360）。 | [查看](./art/gen_shipyard_textures.py.md) |
| `capture_ui.ps1` | `tools/ui_snapshot.gd` 的 PowerShell 包装：窗口 1440×900 跑真实渲染截图，并校验产物新鲜度。 | [查看](./capture_ui.ps1.md) |
| `fog_grid_simulator.html` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `gen_content_types.mjs` | 从 content_types.json 生成框架 ContentTypes 与 SNModMaker 的类型目录（active `TYPES` + Schema 2.0 草案 `DRAFT_TYPES`）；提供 `--check` 过期检查。 | [查看](./gen_content_types.mjs.md) |
| `gen_static_docs.mjs` | 从源码静态文档注释、sidecar 头文件和旧策展数据生成镜像文档、模块索引与 SHA-256 manifest。 | [查看](./gen_static_docs.mjs.md) |
| `godot/capture_clue_expansion.gd` | 阶段 4.4 线索扩展的真实渲染截图工具（窗口模式）。开一局真实对局（seed | [查看](./godot/capture_clue_expansion.gd.md) |
| `godot/capture_exploration.gd` | 探索系统（海图阶段 4.1 + 4.2 资源告急决策）的真实渲染截图工具。窗口模式 | [查看](./godot/capture_exploration.gd.md) |
| `godot/capture_harbor_diorama.gd` | 港口样片真实渲染截图（窗口模式）：加载 harbor_diorama.tscn，等水面/浮船稳定后抓固定 3/4 机位与纵帆船近景两张 1440×900 截图。 | [查看](./godot/capture_harbor_diorama.gd.md) |
| `godot/capture_port_stage.gd` | PortStage 真实渲染截图（窗口模式 1440×900）：加载 `port_stage_preview.tscn`，依次抓 `preview`（harbor/stage）、`sparse`、`market` 站位、`supply` 站位与 `harbor` 的 panel 构图共 5 张，输出到 `docs/design/screenshots/port_stage/`。 | [查看](./godot/capture_port_stage.gd.md) |
| `godot/capture_port_stage_res.gd` | 铁港建筑验收的 PortStage 实机截图（分辨率参数化）：加载 `port_stage_preview.tscn`，把窗口设到命令行给定尺寸后抓一张 PNG，并顺带打印内容 GLB 的材质/贴图自证行；第三个参数可切换 LOD0/LOD1 标签与 tri 期望，用于 LOD1 临时入舞台的 960×540 可读性证据。 | [查看](./godot/capture_port_stage_res.gd.md) |
| `godot/capture_sea_chart.gd` | 海图系统（阶段 2）的真实渲染截图工具，窗口 1440×900 挂载 | [查看](./godot/capture_sea_chart.gd.md) |
| `godot/capture_story_act0.gd` | 阶段 4.5.2「开局幕」真实渲染截图工具（窗口模式）。走完整教学首段： | [查看](./godot/capture_story_act0.gd.md) |
| `godot/capture_story_tutorial.gd` | 阶段 4.5.1 新手剧情框架的真实渲染截图工具（窗口模式）。开一局教程局 | [查看](./godot/capture_story_tutorial.gd.md) |
| `godot/capture_voyage_presentation.gd` | 航行演出（海图系统阶段 3）的真实渲染截图工具。窗口模式挂载真正的 | [查看](./godot/capture_voyage_presentation.gd.md) |
| `godot/measure_port_stage.gd` | PortStage 真实渲染预算实测（窗口 1440×900）：挂载 `port_stage_preview.tscn`，依次采样 `preview`、`sparse` 与三个站位（market/harbor/supply，stage 构图），优先用 `RenderingServer.get_rendering_info()` 读取整帧 draw calls / primitives，并输出场景 mesh/MultiMesh/粒子/surface/triangle 分析、舞台分层 surface、`batch_stats()`、`town_density()`、`station_prop_count()`、`painted_backdrop_layer_count()` 与「排除玩家船后的 stage draws」。 | [查看](./godot/measure_port_stage.gd.md) |
| `godot/preview_voyage_presentation.gd` | 航行演出（海图系统阶段 3）的**实机演示**：窗口模式下自动开一局、发出真实的 | [查看](./godot/preview_voyage_presentation.gd.md) |
| `godot/verify_crane_materials.gd` | 四台起重机 GLB 的**共享贴图运行时验收**（只读）：外部贴图 URI 解析、 | [查看](./godot/verify_crane_materials.gd.md) |
| `godot/verify_cranes.gd` | 四台起重机 GLB 在 Godot 侧的导入验收（只读）：尺寸 / 三角面 / 材质 / 贴地。 | [查看](./godot/verify_cranes.gd.md) |
| `godot/verify_harbor_diorama.gd` | 港口样片验收（只读）：场景可加载、新浮船 SN_Schooner_Fame 在场景且旧船已移除、无星条旗、水面使用自定义着色器、浮船随波运动、未接入主场景。 | [查看](./godot/verify_harbor_diorama.gd.md) |
| `godot/verify_port_facilities.gd` | 港口设施锚点 GLB 导入验收（只读）：加载 `assets/models/port/SN_*.glb` 6 件，量测 Godot 侧包围盒 / 三角面 / 材质名，对照工单尺寸与调色板判定。 | [查看](./godot/verify_port_facilities.gd.md) |
| `godot/verify_props.gd` | 道具 GLB 导入验收（只读）：加载 `assets/models/props/*.glb`，量测 Godot 侧包围盒、三角面与材质名，对照 brief 尺寸判定尺度与轴向。 | [查看](./godot/verify_props.gd.md) |
| `godot/verify_shared_textures.gd` | 共享贴图建筑 GLB 的只读验收探针：通过 `ContentAssetLoader` 加载 5 栋 `SN_HT_*`，统计每栋 surfaces/tri/材质 albedo `Texture2D` 实例，验证同 cell 跨建筑共享同一实例、不同 cell 不塌缩、全局唯一贴图数 = 唯一 cell 数，并支持松散与挂载 ZIP 两种加载路径。 | [查看](./godot/verify_shared_textures.gd.md) |
| `modeling/briefs/IRON_HARBOR_PLAN.md` | 铁港小部件 31 件 / 5 批的工单总表、布局、材质与已知坑。 | 本页 |
| `modeling/briefs/PORT_FACILITIES_PLAN.md` | 港口设施锚点建模总表：设施→锚点映射、尺寸/tri/材质、已有道具复用、PortStage 装配与验收约定。 | 本页 |
| `modeling/briefs/_template.json` | 建模工单模板：字段说明与必填项。 | 本页 |
| `modeling/briefs/sn_crane_batch1.json` | 四台港口起重机的自包含建模工单（塔吊补全 / 大型龙门吊 / 木制桅杆起重机 / 手摇悬臂吊）。 | [查看](./modeling/briefs/sn_crane_batch1.json.md) |
| `modeling/briefs/sn_harbor_crane.json` | 港口塔吊工单（锤头式，含回转枢轴与吊钩层级）。 | 本页 |
| `modeling/briefs/sn_harbor_town_batch1.json` | 港口街景建筑/人物/小船第一批 10 件建模工单：集合 `SN_Harbor_Town`、前缀 `SN_HT_`、工作台 y=110 一排；定义 10 件尺寸/单件 tri 预算（合计 ≤11500）/调色板（含新增 SN_Brick/SN_Plaster/SN_Glass_Dark）/轴心与验收规则。 | [查看](./modeling/briefs/sn_harbor_town_batch1.json.md) |
| `modeling/briefs/sn_iron_harbor_architecture_kit_v1.json` | 铁港近中景城镇建筑视觉升级工单：以模块化中等精度建筑替换 PortStage 白盒，定义 8 类建筑、共享材质与纹理、LOD 和固定机位门禁。 | [查看](./modeling/briefs/sn_iron_harbor_architecture_kit_v1.json.md) |
| `modeling/briefs/sn_iron_harbor_batch1.json` | 铁港第一批 6 件道具工单（岸壁/护舷/系缆桩/木箱/木桶/矿堆，y=24）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch2.json` | 铁港第二批 6 件工单（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆，y=30）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch3.json` | 铁港第三批 6 件工单（堆场/管线，y=36）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch4.json` | 铁港第四批 6 件工单（机械/水上件，y=42）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch5.json` | 铁港第五批 7 件工单（结构/标识/动力，y=48）。 | 本页 |
| `modeling/briefs/sn_ironclad_broadside.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/sn_kit_batch1.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/sn_kit_batch2.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/sn_kit_batch3.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/sn_paddle_freighter.json` | 明轮蒸汽货轮工单：59.5 × 14.1 × 19.5 m、≤14000 tri、33 个必做部件的尺寸 / 材质 / 命名约定；含明轮轮系、半包轮罩、艏艉楼侧封板与 15 对零交面验收。 | 本页 |
| `modeling/briefs/sn_port_facilities_batch1.json` | 港口设施锚点第一批工单：市场棚 / 告示板 / 水箱 / 信号塔 / 龙门吊 / 干船坞，总预算 10500 tri；工作台暂存排原定 y=60，因与 SN_Ship_Modules 冲突改为 y=75（layout_revision）。 | 本页 |
| `modeling/briefs/sn_schooner_fame.json` | 1795 Salem 双桅纵帆船工单：船体 LOA 24.4 m / 总长 33.44 m / 总高 26.82 m、≤18000 tri、12 材质、双桅后倾/斜桁帆/方顶帆/艏三角帆/完整索具/艉廊 FAME 铭牌；用户 2026-10-19 明确不要星条旗，只保留红白长旒；帆腹朝 -Y。 | 本页 |
| `modeling/briefs/sn_ship_modules_batch1.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/sn_ship_paddle_steamer.json` | 小型明轮蒸汽船工单：24.4 × 8.7 × 10.5 m、≤12000 tri、8 材质、明轮 10 桨叶/轮罩 10 道格栅、驾驶室 ENTERPRISE 铭牌；明确蒸汽不建模（游戏内 VFX）、明轮 8 旋转角零穿模与水线轴心验收。 | 本页 |
| `modeling/briefs/sn_ship_prototype.json` | 帆船原型工单（三桅六帆低模）。 | 本页 |
| `modeling/briefs/sn_weapon_batch1.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/sn_weapon_batch2.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/weapon_assembly_v2.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/dispatch.workflow.js` | 批量派发脚本：串行 Builder + 独立 Verifier，脚本内不落盘（导出由 Lead 在人工验收后执行）。 | 本页 |
| `modeling/generators/check_ironclad_connectivity.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/crane_kit.py` | Steam Navigator 起重机类资产的共用低模几何部件库（纯 Python，不 import bpy）。 | [查看](./modeling/generators/crane_kit.py.md) |
| `modeling/generators/dryrun_batch2.py` | 第二批专用干跑（dryrun_props.py 的前身，保留兼容）。 | 本页 |
| `modeling/generators/dryrun_cranes.py` | 四台起重机生成器的纯 Python 干跑（不起 Blender），进 Blender 前拦几何缺陷。 | [查看](./modeling/generators/dryrun_cranes.py.md) |
| `modeling/generators/dryrun_ironclad.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/dryrun_kit_batch1.py` | 模型素材库批次 1（武器套件 + 船体部件 8 件）生成器的纯 Python 干跑；核对 | [查看](./modeling/generators/dryrun_kit_batch1.py.md) |
| `modeling/generators/dryrun_kit_batch2.py` | 模型素材库批次 2（机械 / 货物 / 码头 10 件）生成器的纯 Python 干跑；核对 | [查看](./modeling/generators/dryrun_kit_batch2.py.md) |
| `modeling/generators/dryrun_kit_batch3.py` | 模型素材库批次 3（建筑 / 环境 8 件）生成器的纯 Python 干跑；核对命名、 | [查看](./modeling/generators/dryrun_kit_batch3.py.md) |
| `modeling/generators/dryrun_lod1_batch_a.py` | 批次 A（5 栋建筑 LOD1）的**纯 Python 干跑**：不进 Blender，先把 LOD1 的 tri / 上限 / | [查看](./modeling/generators/dryrun_lod1_batch_a.py.md) |
| `modeling/generators/dryrun_paddle_steamer.py` | 明轮蒸汽船纯 Python 干跑：空壳替换 bpy/bmesh 后核对 tri 预算、包围盒/Z 范围、边界/非流形边、退化面、孤立点、材质名单、父级键与左右镜像误差。 | 本页 |
| `modeling/generators/dryrun_props.py` | 通用纯 Python 干跑：把 bpy/bmesh 换成空壳加载生成器，离线校验 tri 预算、包围盒、边界边/非流形边/退化面。 | 本页 |
| `modeling/generators/dryrun_prototypes_batch_b.py` | 批次 B 第一阶段（三栋新原型 LOD0）的**纯 Python 干跑**：不进 Blender，先收敛 | [查看](./modeling/generators/dryrun_prototypes_batch_b.py.md) |
| `modeling/generators/dryrun_prototypes_lod1.py` | 批次 B 第二阶段（三栋新原型 **LOD1**）的纯 Python 干跑：不进 Blender，把 | [查看](./modeling/generators/dryrun_prototypes_lod1.py.md) |
| `modeling/generators/dryrun_schooner_fame.py` | 纵帆船纯 Python 干跑：对 FORE/MAIN 子件施加 pivot 世界变换后核对 tri/bbox/边界边/非流形/退化/孤立点/材质/命名/父级，并断言两桅轴距 6.4 m、双桅后倾与主桅更高（R1 P0 回归护栏）。 | 本页 |
| `modeling/generators/dryrun_ship.py` | 船只生成器纯 Python 干跑：空壳替换 bpy/bmesh 后加载生成器，核对 tri 预算、包围盒、边界/非流形边、退化面、材质名与父级。 | 本页 |
| `modeling/generators/dryrun_weapon_batch1.py` | 舰载武器五件套生成器的纯 Python 干跑（不起 Blender），在进 Blender 之前拦住 | [查看](./modeling/generators/dryrun_weapon_batch1.py.md) |
| `modeling/generators/dryrun_weapon_batch2.py` | 舰载特殊武器三件套（弩炮 / 箭塔 / 蒸汽鱼叉）生成器的纯 Python 干跑；核对 | [查看](./modeling/generators/dryrun_weapon_batch2.py.md) |
| `modeling/generators/export_cranes_glb.py` | 四台起重机的 GLB 归档导出脚本（验收通过后由 Lead 执行）；导出后把 GLB 内嵌的 | [查看](./modeling/generators/export_cranes_glb.py.md) |
| `modeling/generators/export_iron_harbor_architecture_glb.py` | 把 `SN_HT_Warehouse_Long_LOD0` 装配进 PortStage 的导出/还原工具：备份旧内容 GLB → 单对象导出（带内嵌 trim sheet 贴图）到内容路径 → 保留候选副本；`restore_legacy_glb()` 还原。 | [查看](./modeling/generators/export_iron_harbor_architecture_glb.py.md) |
| `modeling/generators/export_iron_harbor_architecture_lod_glb.py` | 批次 A 的 Blender 侧导出器：把工作台里 5 栋 LOD0 + 5 栋 LOD1 逐件导出为单对象、根节点归零、内嵌贴图的 GLB 候选，并输出逐件 tri/尺寸/材质槽/cell/结构报告；后续由 `glb_shared_textures.py`（纯 Python、Blender 外）统一外部化共享贴图并安装进内容模组。 | [查看](./modeling/generators/export_iron_harbor_architecture_lod_glb.py.md) |
| `modeling/generators/export_iron_harbor_prototypes_glb.py` | 批次 B 的 Blender 侧导出器：把工作台 y=200 / y=225 两排的三栋新原型（LOD0 + LOD1）逐件导出为单对象、根节点归零、内嵌贴图的 GLB 候选，并输出 tri/尺寸/材质槽/cell 报告；随后由 `glb_shared_textures.py` 外部化为共享贴图并安装进内容模组。 | [查看](./modeling/generators/export_iron_harbor_prototypes_glb.py.md) |
| `modeling/generators/export_ironclad_glb.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/export_kit_batch2_glb.py` | 模型素材库批次 2（机械 / 货物 / 码头 10 件）的 GLB 归档导出；复用 | [查看](./modeling/generators/export_kit_batch2_glb.py.md) |
| `modeling/generators/export_kit_batch3_glb.py` | 模型素材库批次 3（建筑 4 + 环境 4）的 GLB 归档导出；复用 | [查看](./modeling/generators/export_kit_batch3_glb.py.md) |
| `modeling/generators/export_kit_glb.py` | 模型素材库批次 1（武器套件 4 件 + 船体部件 4 件）的 GLB 归档导出（人工验收 | [查看](./modeling/generators/export_kit_glb.py.md) |
| `modeling/generators/export_modules_glb.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/export_paddle_steamer_glb.py` | 明轮蒸汽船 GLB 归档：备份旧 GLB → 保存工作台 → 根节点临时归零导出 → libraries.write 船体快照（不切文件）→ 还原 (45,0,0) 并重存工作台。 | 本页 |
| `modeling/generators/export_port_glb.py` | 港口设施 GLB 归档：备份旧 GLB → 保存工作台 → 逐件 location 归零导出 `assets/models/port/SN_<Name>.glb` → `libraries.write` 单件 `.blend` 快照 → 还原摆位；人工验收后由 Lead 运行。 | 本页 |
| `modeling/generators/export_props_glb.py` | 道具 GLB 导出：逐件把 location 临时归零、只导出选中对象、导出后还原；按批次分组避免无谓重导。 | 本页 |
| `modeling/generators/export_schooner_fame_glb.py` | 纵帆船 GLB 归档：备份旧 GLB → 保存工作台 → 根节点临时归零导出 → `bpy.data.libraries.write` 船体快照（不切文件）→ 还原 (0,-70,0) 并重存工作台。 | 本页 |
| `modeling/generators/export_ship_glb.py` | 船只 GLB 归档：备份旧 GLB → 保存工作台 → 导出（临时归零 SN_PF_Root）→ 写船体快照；人工验收后由 Lead 运行。 | 本页 |
| `modeling/generators/export_town_glb.py` | 把 Blender 工作台 `SN_Harbor_Town` 集合的 10 件 `SN_HT_*` 逐件导出为单对象 GLB，写入 `dev_mods/core/assets/models/props/`（内容资产随 core 模组发布）。 | [查看](./modeling/generators/export_town_glb.py.md) |
| `modeling/generators/export_weapon_batch2_glb.py` | 舰载特殊武器三件套（弩炮 / 箭塔 / 蒸汽鱼叉）的 GLB 归档导出；复用 | [查看](./modeling/generators/export_weapon_batch2_glb.py.md) |
| `modeling/generators/export_weapon_glb.py` | 舰载武器五件套的 GLB 归档导出脚本（人工验收通过后由 Lead 执行）；导出后把 | [查看](./modeling/generators/export_weapon_glb.py.md) |
| `modeling/generators/gen_kit_catalog.py` | 从批次 1/2/3 生成器的纯几何数据生成机器可读的模型素材库目录 | [查看](./modeling/generators/gen_kit_catalog.py.md) |
| `modeling/generators/glb_shared_textures.py` | 把铁港建筑 GLB 的内嵌 trim-sheet 贴图外部化为稳定共享 URI（`iron_harbor_shared/<cell>.png`）并压缩 BIN chunk，使多栋建筑在 Godot 中共享同一 `Texture2D`；纯 Python（无 bpy），支持 dry-run / GLB 结构报告。 | [查看](./modeling/generators/glb_shared_textures.py.md) |
| `modeling/generators/glb_weapon_nodes.py` | 武器装配规范 v2 的 GLB 节点名归一化（纯 Python）。 | [查看](./modeling/generators/glb_weapon_nodes.py.md) |
| `modeling/generators/kit_batch1_generator.py` | 模型素材库批次 1（武器套件 + 船体部件）的参数化生成器与 Blender 装配入口。 | [查看](./modeling/generators/kit_batch1_generator.py.md) |
| `modeling/generators/kit_batch2_generator.py` | 模型素材库批次 2（P1：机械 / 货物 / 码头）的参数化生成器与 Blender 装配入口。 | [查看](./modeling/generators/kit_batch2_generator.py.md) |
| `modeling/generators/kit_batch3_generator.py` | 模型素材库批次 3（P2：建筑 / 环境）的参数化生成器与 Blender 装配入口。 | [查看](./modeling/generators/kit_batch3_generator.py.md) |
| `modeling/generators/p0_finalize.py` | P0 归档：备份旧 GLB → 清临时对象 → 导出 → 保存工作台。 | 本页 |
| `modeling/generators/p0_rework_2026-10-19.py` | 第一批 P0 整改：重建系缆桩 → SN_Ore 改锈红 → 三段岸壁拼接测试。 | 本页 |
| `modeling/generators/render_cranes_preview.py` | 四台起重机的预览渲染（Lead 验收截图，非游戏资产）。 | [查看](./modeling/generators/render_cranes_preview.py.md) |
| `modeling/generators/render_iron_harbor_architecture_preview.py` | 铁港建筑套件验收截图：临时相机 + 三盏太阳 + 地面 + 世界背景，只对 `SN_HT_Warehouse_Long_LOD0` 出图，渲染后还原可见性/相机/引擎/分辨率/世界并删除临时对象，不保存 .blend、不导出 GLB。 | [查看](./modeling/generators/render_iron_harbor_architecture_preview.py.md) |
| `modeling/generators/render_ironclad_preview.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/render_kit_batch2_preview.py` | 模型素材库批次 2（机械 / 货物 / 码头 10 件）的预览渲染（Lead 在人工验收前 | [查看](./modeling/generators/render_kit_batch2_preview.py.md) |
| `modeling/generators/render_kit_batch3_preview.py` | 模型素材库批次 3（建筑 4 + 环境 4）的预览渲染（Lead 在人工验收前执行， | [查看](./modeling/generators/render_kit_batch3_preview.py.md) |
| `modeling/generators/render_kit_preview.py` | 模型素材库批次 1（武器套件 + 船体部件）的预览渲染（Lead 在人工验收前执行， | [查看](./modeling/generators/render_kit_preview.py.md) |
| `modeling/generators/render_modules_preview.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/render_paddle_steamer_preview.py` | 明轮蒸汽船预览渲染：临时相机/双太阳/深色世界/临时 matte 水面，输出 3/4、正侧、艏、艉 3/4、俯视 5 张入库截图，渲染后还原场景并删除临时对象。 | 本页 |
| `modeling/generators/render_port_preview.py` | 港口设施预览渲染：临时相机/双太阳/深色世界，逐件 3/4 与正视 + 一排总览 + 船厂组总览，干船坞单独抬高机位看坞内台阶；渲染后还原场景并删除临时对象。 | 本页 |
| `modeling/generators/render_schooner_fame_preview.py` | 纵帆船预览渲染：临时相机/双太阳/深色世界/临时水面，输出 3/4、正侧、艏 3/4、艉 3/4、俯视 5 张入库截图，渲染后还原场景并删除临时对象。 | 本页 |
| `modeling/generators/render_weapon_batch2_preview.py` | 舰载特殊武器三件套（弩炮 / 箭塔 / 蒸汽鱼叉）的预览渲染；复用 | [查看](./modeling/generators/render_weapon_batch2_preview.py.md) |
| `modeling/generators/render_weapon_preview.py` | 舰载武器五件套的预览渲染（Lead 在人工验收前执行，不进游戏）。 | [查看](./modeling/generators/render_weapon_preview.py.md) |
| `modeling/generators/ship_parts/README.md` | 可复用部件库使用说明与部件契约：分层、新增部件步骤、坐标/材质约定、输出不变的验收口径。 | 本页 |
| `modeling/generators/ship_parts/__init__.py` | 部件库入口：导出 Part/PartSpec/tri_count 与 assembly/deck/bow/stern 子模块；约定纯几何不依赖 bpy。 | 本页 |
| `modeling/generators/ship_parts/assembly.py` | 可复用 Blender 装配层：BuildConfig/PivotSpec、清理/集合/材质/空物体/文字铭牌/report；bpy 只在函数内 import，干跑可安全加载生成器。 | 本页 |
| `modeling/generators/ship_parts/bow.py` | 可复用艏部构件：艏斜桁/jibboom 铁箍、雕刻艏饰（黄铜卷饰+赭黄胸像）；船体主色由调用方传入。 | 本页 |
| `modeling/generators/ship_parts/core.py` | 部件库核心：Part 数据容器、向量/基本体/放样/镜像工具、PartSpec 装配契约、tri_count；纯 Python，不 import bpy。 | 本页 |
| `modeling/generators/ship_parts/deck.py` | 可复用甲板属具构建器：舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯；位置与甲板高度由调用方传入。 | 本页 |
| `modeling/generators/ship_parts/palette.py` | 跨船共享材质名常量（木/深木/甲板木/帆布/金属/黄铜/旗帜色）；船体主色由各船生成器定义。 | 本页 |
| `modeling/generators/ship_parts/stern.py` | 可复用艉部构件：艉廊/3 艉窗/檐口/双艉灯；x0/x1/窗位/灯位/主色由调用方传入。 | 本页 |
| `modeling/generators/sn_crane_materials.py` | 起重机四件套的**共享贴图材质视图**（纯 Python，不 import bpy）：材质名 → | [查看](./modeling/generators/sn_crane_materials.py.md) |
| `modeling/generators/sn_hand_jib_crane_generator.py` | SN_Hand_Jib_Crane 手摇悬臂吊（码头小型回转吊）的参数化生成器。 | [查看](./modeling/generators/sn_hand_jib_crane_generator.py.md) |
| `modeling/generators/sn_harbor_crane_generator.py` | SN_Harbor_Crane 锤头式塔吊的参数化生成器（补全此前缺失的几何真源）。 | [查看](./modeling/generators/sn_harbor_crane_generator.py.md) |
| `modeling/generators/sn_harbor_town_generator.py` | 港口街景第一批 10 件的参数化几何唯一真源：顶部 `ITEMS` 参数表（名称/布局/tri 预算/目标包围盒）+ 各 `build_*` 纯几何函数，负责在 Blender 集合 `SN_Harbor_Town` 重建 10 件 `SN_HT_*` 单 mesh 对象。 | [查看](./modeling/generators/sn_harbor_town_generator.py.md) |
| `modeling/generators/sn_iron_harbor_architecture_kit_generator.py` | 铁港建筑套件样板：`SN_HT_Warehouse_Long` LOD0 的几何唯一真源（纯 Python 几何 + Blender 内 `build_all()/report()`），建单 mesh 对象 `SN_HT_Warehouse_Long_LOD0` 并把材质/UV 交给共享材质模块；几何已在 R1 冻结。 | [查看](./modeling/generators/sn_iron_harbor_architecture_kit_generator.py.md) |
| `modeling/generators/sn_iron_harbor_architecture_lod1_generator.py` | 铁港建筑套件批次 A（LOD1）的**参数化真源生成器 + Blender 侧装配/自检/渲染 harness**： | [查看](./modeling/generators/sn_iron_harbor_architecture_lod1_generator.py.md) |
| `modeling/generators/sn_iron_harbor_batch2_generator.py` | 铁港第二批 6 件生成器（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch3_generator.py` | 铁港第三批 6 件生成器（木料堆/麻袋堆/蒸汽管/缆绳卷/吊货网/托盘）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch4_generator.py` | 铁港第四批 6 件生成器（浮标/锚链堆/绞盘/手推车/碰垫/齿轮箱）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch5_generator.py` | 铁港第五批 7 件生成器（石阶/港口牌/钟/旗杆/煤溜槽/锅炉/龙骨墩）。 | 本页 |
| `modeling/generators/sn_iron_harbor_cargo_shed_generator.py` | 铁港建筑套件第二批：`SN_HT_Cargo_Shed` LOD0 的几何唯一真源（纯 Python，无 bpy）；低矮**开敞**货棚。 | [查看](./modeling/generators/sn_iron_harbor_cargo_shed_generator.py.md) |
| `modeling/generators/sn_iron_harbor_harbor_office_generator.py` | 铁港建筑套件第二批：`SN_HT_Harbor_Office` LOD0 的几何唯一真源（纯 Python，无 bpy）；镇里最高的钟楼地标。 | [查看](./modeling/generators/sn_iron_harbor_harbor_office_generator.py.md) |
| `modeling/generators/sn_iron_harbor_kit_batch2.py` | 铁港建筑套件第二批的 Blender 装配/自检/导出 harness：把 4 个纯 Python 生成器的 Part 变成单 mesh 对象、按栋写共享 trim sheet 材质与 UV、逐栋自检、导出内容 GLB、出预览图。 | [查看](./modeling/generators/sn_iron_harbor_kit_batch2.py.md) |
| `modeling/generators/sn_iron_harbor_materials.py` | 铁港建筑套件的**共享材质库**：6 个调色板材质槽 → trim sheet 的 6 个 cell（一张 512² 平铺贴图）+ 盒投影 UV + 自检；所有 SN 铁港建筑生成器都调用它，不各自建材质。 | [查看](./modeling/generators/sn_iron_harbor_materials.py.md) |
| `modeling/generators/sn_iron_harbor_prototypes_generator.py` | 铁港建筑套件**批次 B**（三栋新原型 LOD0 + LOD1）的**参数化真源生成器 + Blender 侧 | [查看](./modeling/generators/sn_iron_harbor_prototypes_generator.py.md) |
| `modeling/generators/sn_iron_harbor_tavern_generator.py` | 铁港建筑套件第二批：`SN_HT_Tavern` LOD0 的几何唯一真源（纯 Python，无 bpy）；两层门廊酒馆。 | [查看](./modeling/generators/sn_iron_harbor_tavern_generator.py.md) |
| `modeling/generators/sn_iron_harbor_warehouse_short_generator.py` | 铁港建筑套件第二批：`SN_HT_Warehouse_Short` LOD0 的几何唯一真源（纯 Python，无 bpy），Part 交给 `sn_iron_harbor_kit_batch2.py` 装配/上材质/导出。 | [查看](./modeling/generators/sn_iron_harbor_warehouse_short_generator.py.md) |
| `modeling/generators/sn_ironclad_generator.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/sn_kit_materials.py` | 模型素材库（批次 1 武器套件/船体部件 + 批次 2 机械/货物/码头套件 + | [查看](./modeling/generators/sn_kit_materials.py.md) |
| `modeling/generators/sn_mega_gantry_generator.py` | SN_Mega_Gantry 大型龙门吊（巨型钢结构 + 可读复杂传动）的参数化生成器。 | [查看](./modeling/generators/sn_mega_gantry_generator.py.md) |
| `modeling/generators/sn_mooring_bollard_generator.py` | 系缆桩生成器（十字桩头 + 方形法兰板 + 四螺栓 + 喇叭脚柱身）；单件 API，不走 dryrun_props。 | 本页 |
| `modeling/generators/sn_paddle_freighter_generator.py` | 明轮货轮参数化生成器：铁壳船身 + 两舷明轮（14 桨叶/8 辐条/双轮缘/内加强环/斜撑）+ 半包轮罩箱板（观察窗/端封让开轮扫掠）+ 双烟囱 + 三岛甲板 + 艏艉楼侧封板 + 货舱吊杆，全部几何由顶部参数表重建（预算 ≤14000 tri）。 | 本页 |
| `modeling/generators/sn_paddle_steamer_generator.py` | `SN_Paddle_Steamer`（澳大利亚内河明轮蒸汽船）的**参数化真源生成器 + Blender 侧装配/自检**： | [查看](./modeling/generators/sn_paddle_steamer_generator.py.md) |
| `modeling/generators/sn_port_facilities_generator.py` | 港口设施锚点第一批 6 件生成器（市场棚 / 告示板 / 水箱 / 信号塔 / 龙门吊 / 干船坞）：纯几何函数可离线干跑，单件一个 mesh、原点在底面中心，集合 SN_Port_Facilities，合计 4996 tri；本批新增 SN_Iron。 | 本页 |
| `modeling/generators/sn_schooner_fame_generator.py` | 1795 年 Salem 双桅纵帆船 SN_Schooner_Fame 参数化生成器：18 站放样黑船身 + 赭黄上舷带 + 双桅后倾（Fore -2.5° / Main -3.2°）+ 斜桁帆/方顶帆/三角顶帆 + 两面艏三角帆 + 舷侧绳梯/支索/动索 + 甲板属具（舱口/绞盘/舵轮/罗经柜/锚/木桶/盘绳/fife rails/短梯）+ 艉廊/3 窗/FAME 铭牌 + 红白长旒；帆腹镜像到 -Y（Godot +Z 相机侧），预算 ≤18000 tri。 | 本页 |
| `modeling/generators/sn_shared_materials.py` | 共享贴图材质库（材质名 ↔ 贴图 / tile_m / PBR 参数），以及 Blender 侧的材质绑定、 | [查看](./modeling/generators/sn_shared_materials.py.md) |
| `modeling/generators/sn_ship_modules_generator.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/sn_weapon_batch1_generator.py` | 舰载武器五件套（甲板速射炮 / 重型舰炮 / 曲射迫击炮 / 机关连发炮 / 侧弦炮列） | [查看](./modeling/generators/sn_weapon_batch1_generator.py.md) |
| `modeling/generators/sn_weapon_batch2_generator.py` | 舰载特殊武器三件套（舰载弩炮 / 载人箭塔 / 蒸汽鱼叉发射器）的参数化生成器 | [查看](./modeling/generators/sn_weapon_batch2_generator.py.md) |
| `modeling/generators/sn_weapon_materials.py` | 舰载武器五件套的**共享贴图材质视图**（纯 Python，不 import bpy）：材质名常量、 | [查看](./modeling/generators/sn_weapon_materials.py.md) |
| `modeling/generators/sn_wooden_mast_crane_generator.py` | SN_Wooden_Mast_Crane 木制桅杆起重机（历史港口吊）的参数化生成器。 | [查看](./modeling/generators/sn_wooden_mast_crane_generator.py.md) |
| `modeling/generators/verify_cranes_glb.py` | 四台起重机 GLB 的结构与共享贴图自检（纯 Python，不进 Blender）。 | [查看](./modeling/generators/verify_cranes_glb.py.md) |
| `modeling/generators/verify_iron_harbor_architecture_lod_glb.py` | 批次 A 运行时建筑资产的纯 Python 结构复检：逐件解析 `dev_mods/core/assets/models/props/SN_HT_*.glb`（5×LOD0 + 5×LOD1），核对 tri/单根节点/材质槽/共享外部贴图 URI/LOD0↔LOD1 包围盒与轴心，并汇总「模型+纹理」总量是否 ≤4.5 MB。不依赖 Blender/Godot，可在 CI 与验收脚本里复跑。 | [查看](./modeling/generators/verify_iron_harbor_architecture_lod_glb.py.md) |
| `modeling/generators/verify_iron_harbor_prototypes_glb.py` | 批次 B 三栋新原型（Boiler House / Workshop Row / Brick Tenement）运行时 GLB 的纯 Python 结构复检：逐件解析 LOD0+LOD1，核对 tri（LOD0 精确值 / LOD1 硬上限）、单根节点、材质槽、共享外部贴图 URI、LOD0↔LOD1 包围盒与轴心，并汇总「新原型模型+新增共享贴图」的包体增量。不依赖 Blender/Godot，可在 CI 与验收脚本里复跑。 | [查看](./modeling/generators/verify_iron_harbor_prototypes_glb.py.md) |
| `modeling/generators/verify_ironclad_glb.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/verify_kit_batch2_glb.py` | 模型素材库批次 2（机械 / 货物 / 码头）GLB 结构与共享贴图自检（纯 Python， | [查看](./modeling/generators/verify_kit_batch2_glb.py.md) |
| `modeling/generators/verify_kit_batch3_glb.py` | 模型素材库批次 3（建筑 / 环境）GLB 结构与共享贴图自检（纯 Python，不进 | [查看](./modeling/generators/verify_kit_batch3_glb.py.md) |
| `modeling/generators/verify_kit_glb.py` | 模型素材库批次 1 的 GLB 结构与共享贴图自检（纯 Python，不进 Blender）。 | [查看](./modeling/generators/verify_kit_glb.py.md) |
| `modeling/generators/verify_modules_glb.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/verify_paddle_steamer_glb.py` | 明轮蒸汽船 GLB 结构自检（纯 Python）：节点/网格数、8 材质 doubleSided、tris=11764、glTF Y-up 包围盒与 −1.32 m 水线轴心，并拒绝蒸汽几何泄漏。 | 本页 |
| `modeling/generators/verify_paddle_steamer_scene.py` | 明轮蒸汽船场景只读验收：集合/命名/层级/Pivot/包围盒/tri/材质槽/网格健康/明轮 8 旋转角与轮罩·船体·明轮台世界坐标 BVH 交面/左右镜像/连通岛悬空/工作台回归，输出 JSON。 | 本页 |
| `modeling/generators/verify_port_glb.py` | 港口设施 GLB 结构自检（纯 Python）：单节点/无相机灯光贴图、三角面 ≤1.2× 预算、glTF Y-up 包围盒换算与 items.size 误差 ≤0.1 m、轴心在底面中心、材质在调色板且 doubleSided。 | 本页 |
| `modeling/generators/verify_schooner_fame_glb.py` | 纵帆船 GLB 结构自检（纯 Python）：32 节点/29 网格/12 doubleSided 材质/13174 tri/glTF Y-up 包围盒 33.44×26.85×6.88/水线轴心 −2.74。 | 本页 |
| `modeling/generators/verify_ship_glb.py` | 船只 GLB 结构自检（纯 Python，不进 Blender/Godot）：读 GLB 头 + JSON chunk 核对节点/网格/材质 doubleSided/三角面/包围盒与轴心。 | 本页 |
| `modeling/generators/verify_weapon_batch2_glb.py` | 舰载特殊武器三件套 GLB 的结构与共享贴图自检；复用 | [查看](./modeling/generators/verify_weapon_batch2_glb.py.md) |
| `modeling/generators/verify_weapon_glb.py` | 舰载武器五件套 GLB 的结构与共享贴图自检（纯 Python，不进 Blender）。 | [查看](./modeling/generators/verify_weapon_glb.py.md) |
| `modeling/generators/weapon_kit.py` | Steam Navigator 舰载武器资产的共用低模几何部件库（纯 Python，不 import bpy）。 | [查看](./modeling/generators/weapon_kit.py.md) |
| `modeling/kit_catalog.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `pack_core.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `static_docs_data.mjs` | 静态文档的兼容策展数据：保留尚未迁移文件的职责/契约，并维护模块简介与分组角色。 | [查看](./static_docs_data.mjs.md) |
| `test.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `tests/static_docs.test.mjs` | 静态文档生成器的 Node 单元测试，守护源码注释解析与符号提取。 | [查看](./tests/static_docs.test.mjs.md) |
| `ui_snapshot.gd` | 真实渲染 UI 截图验收：以与框架测试一致的 bootstrap 启动 Core，挂载 main.tscn，截取船厂正常态/改装态/分类/受损状态，并可选截取主界面（全窗 3D 港口舞台 + 紧凑 HUD + 两侧招牌 + 底部状态条）、详细总览抽屉，以及市场/补给页的泊位侧栏（舞台 + 右侧面板）及其 960×540 版本。 | [查看](./ui_snapshot.gd.md) |

## 模块契约

- `test.ps1` / `pack_core.ps1` / `capture_ui.ps1` 通过 `-GodotBin` / `GODOT_BIN` 定位引擎。
- `gen_static_docs.mjs` 优先读取源码 `@static-doc` 与 `docs/static_headers/` sidecar，旧 `static_docs_data.mjs` 仅作兼容；默认原子生成，`--check` 只读检查过期。
- `ui_snapshot.gd` 必须窗口模式运行（`--headless` 时视口纹理为空），bootstrap 顺序与 `framework/tests/test_case.gd` 一致；只写 `docs/design/screenshots/`，失败退出码 1。
- `capture_ui.ps1` 是 `ui_snapshot.gd` 的包装入口：默认 1440×900、seed 5201、输出 `res://docs/design/screenshots`，并检查产物比本次运行更新（防旧图冒充验收）；`-OverviewStage` 额外要求 `overview_port_stage.png` 新鲜，`-OverviewDetail` 再要求 `overview_detail.png`。
- `godot/capture_port_stage.gd` 是 PortStage 预览截图入口：窗口模式 1440×900，依次抓 `port_stage_preview.png` / `port_stage_sparse.png` / `port_stage_market.png` / `port_stage_supply.png` / `port_stage_harbor_page.png` 五张到 `docs/design/screenshots/port_stage/`；`--headless` 直接失败，失败退出码 1。
- `art/gen_shipyard_textures.py` 是船厂两张贴图的唯一真源：`python tools/art/gen_shipyard_textures.py` 可重建；纵剖图构图比例需与 `sn_ship_view.gd` 的 `_chip_anchor` 同步。
- `modeling/briefs/*.json` 是建模子代理的自包含工单；尺寸/预算/材质只改这里，不靠口述传递。
- 港口街景第一批工单在 `modeling/briefs/sn_harbor_town_batch1.json`：10 件 `SN_HT_*`、集合 `SN_Harbor_Town`、工作台 y=110、总预算 11500 tri；`sn_harbor_town_generator.py` 是几何唯一真源（纯 Python 可干跑、`build_all()/report()` 在 Blender 内执行），`export_town_glb.py` 验收后逐件归零导出到 `dev_mods/core/assets/models/props/`。Verifier R1 复验 passed=true，场景 244 objects / 223 mesh、既有对象 digest 不变。
- `modeling/briefs/sn_iron_harbor_architecture_kit_v1.json` 是铁港近中景建筑升级契约：现有 5 个 `SN_HT_*` 资产原名原位升级，并新增 3 类建筑；要求真实窗门深度、共享 2K trim sheet、LOD1 <= LOD0 的 35%，典型 PortStage 同屏建筑 <=60000 tri。
- 港口设施锚点工单见 `modeling/briefs/sn_port_facilities_batch1.json` 与 `PORT_FACILITIES_PLAN.md`：6 件设施锚点，总预算 10500 tri，轴心统一在底面中心；工作台暂存排原定 y=60，因与 `SN_Ship_Modules`（y 58.6–69.2）冲突改为 y=75（见工单 layout_revision）。
- `modeling/generators/sn_port_facilities_generator.py` 是港口设施 6 件的几何唯一真源；`export_port_glb.py` 逐件归零导出 + 写 `.design/port/SN_<Name>.blend` 快照，`verify_port_glb.py` 纯 Python 复核单节点 / 调色板 / 尺寸 / 轴心 / doubleSided，`render_port_preview.py` 出逐件 3/4 预览。
- `modeling/generators/*.py` 是几何唯一真源：改了参数重跑即可重建，禁止手工摆点；`.blend` 只是产物。
- `modeling/generators/dryrun_props.py` 必须在进 Blender 前跑通（tri 预算 / 包围盒 / 边界边 / 退化面）。
- `modeling/dispatch.workflow.js` 必须串行派发：Blender 单实例，禁止 `parallel`/`pipeline` 并发建模。
- `godot/verify_props.gd` 是道具 GLB 导入的回归闸门，`godot/verify_port_facilities.gd` 是港口设施 6 件锚点的导入闸门；改动资产后先 `godot --headless --import` 再重跑对应脚本。
