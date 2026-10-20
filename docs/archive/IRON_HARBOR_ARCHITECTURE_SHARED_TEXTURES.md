# 铁港建筑套件 · 批次 A 技术样板：共享外部贴图与材质复用

> 前置：[IRON_HARBOR_ARCHITECTURE_BATCH2.md](IRON_HARBOR_ARCHITECTURE_BATCH2.md)（5 栋 LOD0 交付与已知问题）、[MODELING_REQUIREMENTS_NEXT_BATCH.md](MODELING_REQUIREMENTS_NEXT_BATCH.md) §5.2。
> 本轮目标：验证「5 栋建筑在 Godot 中真实复用同一 Texture2D / Material」，回收 batch B 记录的 **+20 draw calls** 与 **6.82 MB** 包体，并给出三条加载路径的证据。**不涉及 LOD1**（LOD1 见 `IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md`），**不实现运行时 LOD 切换**。

## 1. 结论

| 指标 | 改造前（内嵌贴图 GLB） | 改造后（GLB + 外部共享贴图） | 目标 | 判定 |
| --- | ---: | ---: | ---: | --- |
| PortStage 舞台分析面（`draw_meshes` 口径，harbor 构图） | **91** | **73** | ≤75（硬上限 80） | PASS |
| 渲染器整帧 draw calls（1440×900，`RenderingServer`，含已合批玩家船） | 89（harbor）/ 71（market）/ 87（supply） | **71 / 65 / 69** | ≤75（建筑相关增量回收） | PASS |
| 静态合批批次（static batches） | 59 | **41**（−18） | — | — |
| 5 栋 GLB 体积合计 | 6 860 480 B（6.86 MB） | **1 895 364 B**（1.90 MB） | — | — |
| 5 栋运行时模型 + 纹理总量 | 6.86 MB（每栋内嵌 1.02 MB 贴图副本） | **4 168 841 B（4.17 MB；LOD0+LOD1 10 个 GLB 2.28 MB + 11 张共享 PNG 1.88 MB）** | ≤4.5 MB | PASS |
| 唯一 Texture2D 实例数（5 栋合计） | 29 | **11**（= 11 个唯一 trim cell） | 真实共享 | PASS |
| 唯一材质签名数（5 栋合计） | 29 | **11** | 可跨建筑合批 | PASS |

- 选择方案 1「保留 GLB，image 改为共享外部 URI」；方案 2「.gltf + .bin + 贴图」被内容模组扩展名白名单结构性拒绝（§3）。
- 松散 `dev_mods` 与挂载 `.snavmod.zip` 两条路径得到**相同的 71 draws / 73 面 / 41 批次**，证明共享方案不依赖编辑器导入缓存（§5）。

## 2. 问题与机制

- 每栋 GLB 内嵌同一组 512² trim tile（每栋 5–6 张，合计约 1.0 MB），Godot 运行时为每份内嵌图各建一个 `ImageTexture`。
- `PortStage._batch_static_meshes()` 按 `_material_signature()` 合批，签名包含 `albedo_texture.get_instance_id()`；贴图实例不同 ⇒ 同材质槽的 5 栋建筑无法合并 ⇒ 29 个建筑 surface 各自成批（batch B 实测 71→91）。
- 共享方案把"同一张源 PNG"在运行时归一到**同一个 `Texture2D` 实例**，签名随之相同；5 栋建筑按"材质槽 × trim cell"收敛为 **11 个批次**：
  - 唯一 cell：`brick_wall / plaster_light / plaster_grime / wood_plank / wood_plank_weathered / iron_dark / iron_rust / stone_base / stone_base_dirty / glass_dark / glass_reflect`
  - 跨建筑共享示例：`brick_wall` 被 4 栋使用、`glass_dark` 被 3 栋、`glass_reflect` 被 2 栋。

## 3. 方案对比（§5.2 要求的至少两种）

| 维度 | 方案 1：GLB + 外部共享 image URI（采用） | 方案 2：`.gltf` + `.bin` + 共享贴图（拒绝） | 方案 0：现状内嵌贴图 |
| --- | --- | --- | --- |
| 模组兼容性 | PASS：`.glb` + `.png` 都在 `PathGuard.ASSET_EXTENSIONS` 白名单内，`.snavmod.zip` 仍自包含 | **FAIL**：`ASSET_EXTENSIONS = [.png .webp .svg .ogg .wav .glb]`，`.gltf`/`.bin` 会被 `ModScanner` 以 "file type is not allowed in a content mod" 拒绝；且破坏"单文件 GLB 模型"的资源契约 | PASS |
| 运行时稳定性 | 松散/ZIP 两路径均实测通过；旧格式（内嵌贴图）仍然可用 | 未实施（不可达） | PASS |
| draw calls | 91 → **73**（−18） | — | 91 |
| 包体 | 3.78 MB（5 GLB 1.90 + 11 PNG 1.88） | — | 6.86 MB |
| 维护复杂度 | 中：多一个纯 Python 后处理步骤 + 加载器按 URI 缓存；loader 逻辑约 60 行且无新格式 | 高：需改白名单/打包/加载三条链路 | 低 |
| 结论 | **采用** | 本批不迁移，仅记录 | 被替换 |

补充：方案 1 的 GLB 仍是标准 glTF 2.0 二进制容器（`images[].uri` 指向同目录子目录的 PNG），没有自定义扩展；外部 PNG 与 GLB 同在 core 模组内，`.snavmod.zip` 解压/挂载后路径自洽。

## 4. 实现

### 4.1 纯 Python GLB 后处理：`tools/modeling/generators/glb_shared_textures.py`

- 解析 GLB（12 字节头 + JSON/BIN chunk）→ 对每个内嵌 image 取字节、按 image name 归一 `<cell>`（兜底按字节 sha256 匹配源 tile）→ 写 `dev_mods/core/assets/models/props/iron_harbor_shared/<cell>.png` → 把 image 换成 `{"name": <cell>, "uri": "iron_harbor_shared/<cell>.png"}`。
- 删除 image 的 bufferView，只保留被 accessor 引用的 bufferView，按 4 字节对齐重建 BIN 并重映射 accessor；重写 JSON/BIN chunk（空格/0 补齐、总长自洽）。
- 共享 PNG 的字节与手写源 `docs/design/textures/iron_harbor/tiles/<cell>.png` **逐字节一致**（11/11 `tile_matches=true`）。
- 提供 `--dry-run`（只估算体积）、`--structure`（单 GLB 结构报告）与 `--report`；`structure_report()` 同时给 glTF Y-up 与 Godot Z-up 两套包围盒。

### 4.2 运行时共享：`framework/services/content_asset_loader.gd`

- 新增 `material_image_uris(path)`：只读 GLB 头 + JSON chunk，按 `materials[i].pbrMetallicRoughness.baseColorTexture.index → textures[].source → images[].uri` 取出每材质主色图 URI（解析失败/旧格式返回空 → 完全退回旧行为）。
- `load_scene()` 在 `append_from_file()` 之后、`generate_scene()` 之前调用 `_apply_shared_textures()`：把 `GLTFState` 材质的 `albedo_texture` 换成 `load_texture()` 按路径缓存的实例。由此：
  - 同一外部 PNG 在**任意数量的 GLB** 之间共享同一个 `Texture2D`（进程级缓存）；
  - 旧格式（无外部 URI）无任何改写；
  - 不引入新文件格式、不改 GLB 解析流程。
- `clear_cache()` 同步清空 URI 缓存；失败仍按路径缓存。

### 4.3 验收工具

- `tools/godot/verify_shared_textures.gd`：只读探针，`-- --mode=loose|zip`。输出每栋 surfaces/tri/材质→贴图实例、跨建筑 cell 共享矩阵、唯一贴图数，退出码即判定。
- `tools/godot/measure_port_stage.gd`：新增 `-- --core-zip[=PATH]`；把 `dev_mods/core` 打包挂载后，通过 `SN_TOWN_ASSET_ROOT` 把街景根指向 `res://mods/core/assets/models/props`，从而用**原始 `ContentAssetLoader` 路径**实测 ZIP/发布包布局下的 draw calls。
- `dev_scenes/port_stage/port_stage_preview.gd`：`_town_visuals()` 支持 `SN_TOWN_ASSET_ROOT`，只改写位于松散 core props 目录的路径（框架资产路径不动）。
- `framework/tests/cases/test_content_asset_loader.gd`（5 例，已注册进 `test_runner.gd`）：外部 URI 契约、跨建筑共享（同 cell 同实例 / 不同 cell 不同实例 / 唯一实例 = 唯一 cell）、旧格式与缺失文件回退、**ZIP 挂载**路径共享（2 栋 → 9 个唯一贴图）。

## 5. 加载路径矩阵

| 路径 | 触发方式 | 贴图共享证据 | draw calls 证据 |
| --- | --- | --- | --- |
| Core 松散目录（编辑器 dev 模式） | `ResourceLoader.exists()` 命中导入资源 → 导入场景引用同一导入 PNG | `verify_shared_textures.gd --mode=loose`：11 个唯一实例 | `measure_port_stage.gd`（1440×900）：preview 71 / sparse 64 / market 65 / harbor 71 / supply 69 |
| Core `.snavmod.zip` 挂载（运行时/发布路径） | `ResourceLoader.exists()` 未命中 → `ContentAssetLoader` 原始 GLB + 外部 PNG | `verify_shared_textures.gd --mode=zip`：5 栋 11 个唯一实例、29 个材质面全部有贴图 | `measure_port_stage.gd -- --core-zip`：与松散路径**完全相同**（71/64/65/71/69，batches 41、surfaces 73） |
| 发布包（导出 exe + 同级 `mods/*.snavmod.zip`） | 重新导出 `dist/build/windows`（release，含新 `ContentAssetLoader`），core zip 放入 `mods/` 启动 | 发布 exe 启动日志 `mod load complete {"content":51,"mods":["core"],"status":"ok"}`；资产加载与 ZIP 行走同一挂载包代码 | 同 ZIP 行（71/64/65/71/69；发布包渲染实测受主菜单流程限制，见批次 A 验收报告 §5） |

## 6. 批次 A 终态补充（LOD0+LOD1 全部落地后）

- 10 个 GLB（5 LOD0 + 5 LOD1）全部改为外部共享贴图，共用同一套 11 张 `iron_harbor_shared/*.png`，**没有新增纹理**。
- 终态体积：10 个 GLB 合计 **2 283 968 B**（LOD0 1 895 364 + LOD1 388 604）；共享 PNG **1 884 873 B**；合计 **4 168 841 B = 4.17 MB ≤ 4.5 MB**（`verify_iron_harbor_architecture_lod_glb.py` 复算）。
- 终态 draw calls 与 LOD0-only 样板相同（LOD1 未接线）：preview 71 / sparse 64 / market 65 / harbor 71 / supply 69；整帧 tri 73 228。
- LOD1 临时入舞台（非接线）实测：整帧 tri **49 760**（= 73 228 − 30 032 + 6 564），draw calls 不变（合批按材质），1440×900 / 960×540 截图见批次 A 验收报告 §9。
- core `.snavmod.zip` 终态 **6.14 MB / 121 files**（含 10 个建筑 GLB + 11 张共享 PNG；清理了 Godot 从旧内嵌 GLB 解包的 39 张构建产物 6.64 MB）。
- 发布包：`dist/build/windows` 重新导出（release），`mods/core-1.0.0.snavmod.zip` 启动验证 `content=51 status=ok`。

## 7. 回归与不变量

- 5 栋 GLB 结构对账（改造前备份 vs 改造后）：tri 全部不变（7 436 / 3 788 / 10 336 / 3 356 / 5 116），节点名、材质名、glTF/Godot 包围盒尺寸完全一致（`.design/buildings/iron_harbor/a3_structure_compare.json`）。
- 旧内容 GLB 备份：`.design/buildings/iron_harbor/a3_legacy_textured/`（改造前 5 个内嵌贴图版本），可回滚。
- 无头测试：新增 suite 5 例全绿；完整套件记录见批次 A 验收报告。
- 未改动：manifest（A4 接线）、`PortStage` 运行时逻辑、LOD 切换逻辑、其它资产。

## 8. 已知限制与后续

1. **LOD1 增量（已落地）**：5 栋 LOD1 复用同一套 11 张共享 PNG，不新增纹理，几何仅 388 604 B；终态 4.17 MB 已对照 4.5 MB 目标（见 §6）。
2. **依赖导出工具**：若以后重新导出建筑时又内嵌贴图，共享会回退。`test_content_asset_loader.gd` 对内容 GLB 的「全部 image 必须为外部 URI」做硬断言，可提前拦截。
3. **导入资源分支**：dev 模式下 `_instantiate_visual()` 优先走导入资源；该分支的共享来自 Godot 对同一 PNG 导入资源的缓存。两条路径都实测过，避免"只在编辑器里成立"。
4. **路径形式**：外部 URI 使用 GLB 同目录子目录（`iron_harbor_shared/`），不使用 `..`，不依赖挂载包对父目录路径的简化行为。
5. **`_material_signature` 口径**：合批签名包含贴图实例 id，因此共享是合批的前提；若引擎侧贴图实例化策略变化，需重新跑本报告的实测（工具已固化）。
