# `tools`

> PowerShell 辅助脚本、Godot 验收 / 截图脚本、建模工单 / 参数化生成器与静态文档生成器。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `art/gen_shipyard_textures.py` | 船厂两张授权贴图的确定性生成器：纵剖图 `ship_section.png`（1792×1008）与船卡缩略图 `ship_thumb_ironclad.png`（640×360）。 | [查看](./art/gen_shipyard_textures.py.md) |
| `capture_ui.ps1` | `tools/ui_snapshot.gd` 的 PowerShell 包装：窗口 1440×900 跑真实渲染截图，并校验产物新鲜度。 | [查看](./capture_ui.ps1.md) |
| `gen_content_types.mjs` | 从 content_types.json 生成框架 ContentTypes 与 SNModMaker 的类型目录；提供 `--check` 过期检查。 | [查看](./gen_content_types.mjs.md) |
| `gen_static_docs.mjs` | 静态文档生成器：读取本文件的 FILE_DOCS/MODULES，生成镜像文档、模块 README、总计索引与带 SHA-256 的 manifest。 | [查看](./gen_static_docs.mjs.md) |
| `godot/capture_harbor_diorama.gd` | 港口样片真实渲染截图（窗口模式）：加载 harbor_diorama.tscn，等水面/浮船稳定后抓固定 3/4 机位与纵帆船近景两张 1440×900 截图。 | [查看](./godot/capture_harbor_diorama.gd.md) |
| `godot/capture_port_stage.gd` | PortStage 真实渲染截图（窗口模式 1440×900）：加载 `port_stage_preview.tscn`，等水面/船体稳定后抓 `preview`，再切 `sparse` 抓第二张，输出到 `docs/design/screenshots/port_stage/`。 | [查看](./godot/capture_port_stage.gd.md) |
| `godot/verify_harbor_diorama.gd` | 港口样片验收（只读）：场景可加载、新浮船 SN_Schooner_Fame 在场景且旧船已移除、无星条旗、水面使用自定义着色器、浮船随波运动、未接入主场景。 | [查看](./godot/verify_harbor_diorama.gd.md) |
| `godot/verify_port_facilities.gd` | 港口设施锚点 GLB 导入验收（只读）：加载 `assets/models/port/SN_*.glb` 6 件，量测 Godot 侧包围盒 / 三角面 / 材质名，对照工单尺寸与调色板判定。 | [查看](./godot/verify_port_facilities.gd.md) |
| `godot/verify_props.gd` | 道具 GLB 导入验收（只读）：加载 `assets/models/props/*.glb`，量测 Godot 侧包围盒、三角面与材质名，对照 brief 尺寸判定尺度与轴向。 | [查看](./godot/verify_props.gd.md) |
| `modeling/briefs/IRON_HARBOR_PLAN.md` | 铁港小部件 31 件 / 5 批的工单总表、布局、材质与已知坑。 | 本页 |
| `modeling/briefs/PORT_FACILITIES_PLAN.md` | 港口设施锚点建模总表：设施→锚点映射、尺寸/tri/材质、已有道具复用、PortStage 装配与验收约定。 | 本页 |
| `modeling/briefs/_template.json` | 建模工单模板：字段说明与必填项。 | 本页 |
| `modeling/briefs/sn_harbor_crane.json` | 港口塔吊工单（锤头式，含回转枢轴与吊钩层级）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch1.json` | 铁港第一批 6 件道具工单（岸壁/护舷/系缆桩/木箱/木桶/矿堆，y=24）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch2.json` | 铁港第二批 6 件工单（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆，y=30）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch3.json` | 铁港第三批 6 件工单（堆场/管线，y=36）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch4.json` | 铁港第四批 6 件工单（机械/水上件，y=42）。 | 本页 |
| `modeling/briefs/sn_iron_harbor_batch5.json` | 铁港第五批 7 件工单（结构/标识/动力，y=48）。 | 本页 |
| `modeling/briefs/sn_ironclad_broadside.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/sn_paddle_freighter.json` | 明轮蒸汽货轮工单：59.5 × 14.1 × 19.5 m、≤14000 tri、33 个必做部件的尺寸 / 材质 / 命名约定；含明轮轮系、半包轮罩、艏艉楼侧封板与 15 对零交面验收。 | 本页 |
| `modeling/briefs/sn_port_facilities_batch1.json` | 港口设施锚点第一批工单：市场棚 / 告示板 / 水箱 / 信号塔 / 龙门吊 / 干船坞，总预算 10500 tri；工作台暂存排原定 y=60，因与 SN_Ship_Modules 冲突改为 y=75（layout_revision）。 | 本页 |
| `modeling/briefs/sn_schooner_fame.json` | 1795 Salem 双桅纵帆船工单：船体 LOA 24.4 m / 总长 33.44 m / 总高 26.82 m、≤18000 tri、12 材质、双桅后倾/斜桁帆/方顶帆/艏三角帆/完整索具/艉廊 FAME 铭牌；用户 2026-10-19 明确不要星条旗，只保留红白长旒；帆腹朝 -Y。 | 本页 |
| `modeling/briefs/sn_ship_modules_batch1.json` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `modeling/briefs/sn_ship_paddle_steamer.json` | 小型明轮蒸汽船工单：24.4 × 8.7 × 10.5 m、≤12000 tri、8 材质、明轮 10 桨叶/轮罩 10 道格栅、驾驶室 ENTERPRISE 铭牌；明确蒸汽不建模（游戏内 VFX）、明轮 8 旋转角零穿模与水线轴心验收。 | 本页 |
| `modeling/briefs/sn_ship_prototype.json` | 帆船原型工单（三桅六帆低模）。 | 本页 |
| `modeling/dispatch.workflow.js` | 批量派发脚本：串行 Builder + 独立 Verifier，脚本内不落盘（导出由 Lead 在人工验收后执行）。 | 本页 |
| `modeling/generators/check_ironclad_connectivity.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/dryrun_batch2.py` | 第二批专用干跑（dryrun_props.py 的前身，保留兼容）。 | 本页 |
| `modeling/generators/dryrun_ironclad.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/dryrun_paddle_steamer.py` | 明轮蒸汽船纯 Python 干跑：空壳替换 bpy/bmesh 后核对 tri 预算、包围盒/Z 范围、边界/非流形边、退化面、孤立点、材质名单、父级键与左右镜像误差。 | 本页 |
| `modeling/generators/dryrun_props.py` | 通用纯 Python 干跑：把 bpy/bmesh 换成空壳加载生成器，离线校验 tri 预算、包围盒、边界边/非流形边/退化面。 | 本页 |
| `modeling/generators/dryrun_schooner_fame.py` | 纵帆船纯 Python 干跑：对 FORE/MAIN 子件施加 pivot 世界变换后核对 tri/bbox/边界边/非流形/退化/孤立点/材质/命名/父级，并断言两桅轴距 6.4 m、双桅后倾与主桅更高（R1 P0 回归护栏）。 | 本页 |
| `modeling/generators/dryrun_ship.py` | 船只生成器纯 Python 干跑：空壳替换 bpy/bmesh 后加载生成器，核对 tri 预算、包围盒、边界/非流形边、退化面、材质名与父级。 | 本页 |
| `modeling/generators/export_ironclad_glb.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/export_modules_glb.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/export_paddle_steamer_glb.py` | 明轮蒸汽船 GLB 归档：备份旧 GLB → 保存工作台 → 根节点临时归零导出 → libraries.write 船体快照（不切文件）→ 还原 (45,0,0) 并重存工作台。 | 本页 |
| `modeling/generators/export_port_glb.py` | 港口设施 GLB 归档：备份旧 GLB → 保存工作台 → 逐件 location 归零导出 `assets/models/port/SN_<Name>.glb` → `libraries.write` 单件 `.blend` 快照 → 还原摆位；人工验收后由 Lead 运行。 | 本页 |
| `modeling/generators/export_props_glb.py` | 道具 GLB 导出：逐件把 location 临时归零、只导出选中对象、导出后还原；按批次分组避免无谓重导。 | 本页 |
| `modeling/generators/export_schooner_fame_glb.py` | 纵帆船 GLB 归档：备份旧 GLB → 保存工作台 → 根节点临时归零导出 → `bpy.data.libraries.write` 船体快照（不切文件）→ 还原 (0,-70,0) 并重存工作台。 | 本页 |
| `modeling/generators/export_ship_glb.py` | 船只 GLB 归档：备份旧 GLB → 保存工作台 → 导出（临时归零 SN_PF_Root）→ 写船体快照；人工验收后由 Lead 运行。 | 本页 |
| `modeling/generators/p0_finalize.py` | P0 归档：备份旧 GLB → 清临时对象 → 导出 → 保存工作台。 | 本页 |
| `modeling/generators/p0_rework_2026-10-19.py` | 第一批 P0 整改：重建系缆桩 → SN_Ore 改锈红 → 三段岸壁拼接测试。 | 本页 |
| `modeling/generators/render_ironclad_preview.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/render_modules_preview.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/render_paddle_steamer_preview.py` | 明轮蒸汽船预览渲染：临时相机/双太阳/深色世界/临时 matte 水面，输出 3/4、正侧、艏、艉 3/4、俯视 5 张入库截图，渲染后还原场景并删除临时对象。 | 本页 |
| `modeling/generators/render_port_preview.py` | 港口设施预览渲染：临时相机/双太阳/深色世界，逐件 3/4 与正视 + 一排总览 + 船厂组总览，干船坞单独抬高机位看坞内台阶；渲染后还原场景并删除临时对象。 | 本页 |
| `modeling/generators/render_schooner_fame_preview.py` | 纵帆船预览渲染：临时相机/双太阳/深色世界/临时水面，输出 3/4、正侧、艏 3/4、艉 3/4、俯视 5 张入库截图，渲染后还原场景并删除临时对象。 | 本页 |
| `modeling/generators/ship_parts/README.md` | 可复用部件库使用说明与部件契约：分层、新增部件步骤、坐标/材质约定、输出不变的验收口径。 | 本页 |
| `modeling/generators/ship_parts/__init__.py` | 部件库入口：导出 Part/PartSpec/tri_count 与 assembly/deck/bow/stern 子模块；约定纯几何不依赖 bpy。 | 本页 |
| `modeling/generators/ship_parts/assembly.py` | 可复用 Blender 装配层：BuildConfig/PivotSpec、清理/集合/材质/空物体/文字铭牌/report；bpy 只在函数内 import，干跑可安全加载生成器。 | 本页 |
| `modeling/generators/ship_parts/bow.py` | 可复用艏部构件：艏斜桁/jibboom 铁箍、雕刻艏饰（黄铜卷饰+赭黄胸像）；船体主色由调用方传入。 | 本页 |
| `modeling/generators/ship_parts/core.py` | 部件库核心：Part 数据容器、向量/基本体/放样/镜像工具、PartSpec 装配契约、tri_count；纯 Python，不 import bpy。 | 本页 |
| `modeling/generators/ship_parts/deck.py` | 可复用甲板属具构建器：舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯；位置与甲板高度由调用方传入。 | 本页 |
| `modeling/generators/ship_parts/palette.py` | 跨船共享材质名常量（木/深木/甲板木/帆布/金属/黄铜/旗帜色）；船体主色由各船生成器定义。 | 本页 |
| `modeling/generators/ship_parts/stern.py` | 可复用艉部构件：艉廊/3 艉窗/檐口/双艉灯；x0/x1/窗位/灯位/主色由调用方传入。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch2_generator.py` | 铁港第二批 6 件生成器（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch3_generator.py` | 铁港第三批 6 件生成器（木料堆/麻袋堆/蒸汽管/缆绳卷/吊货网/托盘）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch4_generator.py` | 铁港第四批 6 件生成器（浮标/锚链堆/绞盘/手推车/碰垫/齿轮箱）。 | 本页 |
| `modeling/generators/sn_iron_harbor_batch5_generator.py` | 铁港第五批 7 件生成器（石阶/港口牌/钟/旗杆/煤溜槽/锅炉/龙骨墩）。 | 本页 |
| `modeling/generators/sn_ironclad_generator.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/sn_mooring_bollard_generator.py` | 系缆桩生成器（十字桩头 + 方形法兰板 + 四螺栓 + 喇叭脚柱身）；单件 API，不走 dryrun_props。 | 本页 |
| `modeling/generators/sn_paddle_freighter_generator.py` | 明轮货轮参数化生成器：铁壳船身 + 两舷明轮（14 桨叶/8 辐条/双轮缘/内加强环/斜撑）+ 半包轮罩箱板（观察窗/端封让开轮扫掠）+ 双烟囱 + 三岛甲板 + 艏艉楼侧封板 + 货舱吊杆，全部几何由顶部参数表重建（预算 ≤14000 tri）。 | 本页 |
| `modeling/generators/sn_paddle_steamer_generator.py` | 小型明轮蒸汽船（PS Enterprise 参考）参数化生成器：24 m 白漆内河船身 + 两舷 10 桨叶明轮 + 梯形格栅轮罩 + 前驾驶室（ENTERPRISE 文字铭牌）+ 后部雨棚游步甲板 + 黑烟囱 + 艏旗杆澳洲旗 + 艉部弧形平台/舵；蒸汽不建模（留给游戏内 VFX），预算 ≤12000 tri，几何全部由顶部参数表重建。 | 本页 |
| `modeling/generators/sn_port_facilities_generator.py` | 港口设施锚点第一批 6 件生成器（市场棚 / 告示板 / 水箱 / 信号塔 / 龙门吊 / 干船坞）：纯几何函数可离线干跑，单件一个 mesh、原点在底面中心，集合 SN_Port_Facilities，合计 4996 tri；本批新增 SN_Iron。 | 本页 |
| `modeling/generators/sn_schooner_fame_generator.py` | 1795 年 Salem 双桅纵帆船 SN_Schooner_Fame 参数化生成器：18 站放样黑船身 + 赭黄上舷带 + 双桅后倾（Fore -2.5° / Main -3.2°）+ 斜桁帆/方顶帆/三角顶帆 + 两面艏三角帆 + 舷侧绳梯/支索/动索 + 甲板属具（舱口/绞盘/舵轮/罗经柜/锚/木桶/盘绳/fife rails/短梯）+ 艉廊/3 窗/FAME 铭牌 + 红白长旒；帆腹镜像到 -Y（Godot +Z 相机侧），预算 ≤18000 tri。 | 本页 |
| `modeling/generators/sn_ship_modules_generator.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/verify_ironclad_glb.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/verify_modules_glb.py` | 铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。 | 本页 |
| `modeling/generators/verify_paddle_steamer_glb.py` | 明轮蒸汽船 GLB 结构自检（纯 Python）：节点/网格数、8 材质 doubleSided、tris=11764、glTF Y-up 包围盒与 −1.32 m 水线轴心，并拒绝蒸汽几何泄漏。 | 本页 |
| `modeling/generators/verify_paddle_steamer_scene.py` | 明轮蒸汽船场景只读验收：集合/命名/层级/Pivot/包围盒/tri/材质槽/网格健康/明轮 8 旋转角与轮罩·船体·明轮台世界坐标 BVH 交面/左右镜像/连通岛悬空/工作台回归，输出 JSON。 | 本页 |
| `modeling/generators/verify_port_glb.py` | 港口设施 GLB 结构自检（纯 Python）：单节点/无相机灯光贴图、三角面 ≤1.2× 预算、glTF Y-up 包围盒换算与 items.size 误差 ≤0.1 m、轴心在底面中心、材质在调色板且 doubleSided。 | 本页 |
| `modeling/generators/verify_schooner_fame_glb.py` | 纵帆船 GLB 结构自检（纯 Python）：32 节点/29 网格/12 doubleSided 材质/13174 tri/glTF Y-up 包围盒 33.44×26.85×6.88/水线轴心 −2.74。 | 本页 |
| `modeling/generators/verify_ship_glb.py` | 船只 GLB 结构自检（纯 Python，不进 Blender/Godot）：读 GLB 头 + JSON chunk 核对节点/网格/材质 doubleSided/三角面/包围盒与轴心。 | 本页 |
| `pack_core.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `static_docs_data.mjs` | 静态文档的策展数据：文件职责/契约/L2、模块简介与分组角色。 | [查看](./static_docs_data.mjs.md) |
| `test.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `ui_snapshot.gd` | 真实渲染 UI 截图验收：以与框架测试一致的 bootstrap 启动 Core，挂载 main.tscn，截取船厂正常态/改装态/分类/受损状态，并可选截取总览页 3D 港口舞台（含 2D 设施热点）。 | [查看](./ui_snapshot.gd.md) |

## 模块契约

- `test.ps1` / `pack_core.ps1` / `capture_ui.ps1` 通过 `-GodotBin` / `GODOT_BIN` 定位引擎。
- `gen_static_docs.mjs` 读取 `static_docs_data.mjs` 生成 `docs/static/`。
- `ui_snapshot.gd` 必须窗口模式运行（`--headless` 时视口纹理为空），bootstrap 顺序与 `framework/tests/test_case.gd` 一致；只写 `docs/design/screenshots/`，失败退出码 1。
- `capture_ui.ps1` 是 `ui_snapshot.gd` 的包装入口：默认 1440×900、seed 5201、输出 `res://docs/design/screenshots`，并检查产物比本次运行更新（防旧图冒充验收）；`-OverviewStage` 额外要求 `overview_port_stage.png` 新鲜。
- `godot/capture_port_stage.gd` 是 PortStage 预览截图入口：窗口模式 1440×900，抓 `port_stage_preview.png` / `port_stage_sparse.png` 两张到 `docs/design/screenshots/port_stage/`；`--headless` 直接失败，失败退出码 1。
- `art/gen_shipyard_textures.py` 是船厂两张贴图的唯一真源：`python tools/art/gen_shipyard_textures.py` 可重建；纵剖图构图比例需与 `sn_ship_view.gd` 的 `_chip_anchor` 同步。
- `modeling/briefs/*.json` 是建模子代理的自包含工单；尺寸/预算/材质只改这里，不靠口述传递。
- 港口设施锚点工单见 `modeling/briefs/sn_port_facilities_batch1.json` 与 `PORT_FACILITIES_PLAN.md`：6 件设施锚点，总预算 10500 tri，轴心统一在底面中心；工作台暂存排原定 y=60，因与 `SN_Ship_Modules`（y 58.6–69.2）冲突改为 y=75（见工单 layout_revision）。
- `modeling/generators/sn_port_facilities_generator.py` 是港口设施 6 件的几何唯一真源；`export_port_glb.py` 逐件归零导出 + 写 `.design/port/SN_<Name>.blend` 快照，`verify_port_glb.py` 纯 Python 复核单节点 / 调色板 / 尺寸 / 轴心 / doubleSided，`render_port_preview.py` 出逐件 3/4 预览。
- `modeling/generators/*.py` 是几何唯一真源：改了参数重跑即可重建，禁止手工摆点；`.blend` 只是产物。
- `modeling/generators/dryrun_props.py` 必须在进 Blender 前跑通（tri 预算 / 包围盒 / 边界边 / 退化面）。
- `modeling/dispatch.workflow.js` 必须串行派发：Blender 单实例，禁止 `parallel`/`pipeline` 并发建模。
- `godot/verify_props.gd` 是道具 GLB 导入的回归闸门，`godot/verify_port_facilities.gd` 是港口设施 6 件锚点的导入闸门；改动资产后先 `godot --headless --import` 再重跑对应脚本。
