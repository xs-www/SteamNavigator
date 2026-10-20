# 铁港建筑套件 · 批次 A 验收（LOD1 + 共享贴图 + Warehouse_Short 檐口修复）

> 需求：[MODELING_REQUIREMENTS_NEXT_BATCH.md](MODELING_REQUIREMENTS_NEXT_BATCH.md) §5（批次 A）、§8（交付物）、§9（自动门禁）、§10（人工视觉门禁）。
> 前置：[IRON_HARBOR_ARCHITECTURE_M1.md](IRON_HARBOR_ARCHITECTURE_M1.md)（共享 trim sheet 材质/UV）、[IRON_HARBOR_ARCHITECTURE_BATCH2.md](IRON_HARBOR_ARCHITECTURE_BATCH2.md)（5 栋 LOD0 + 已知问题）。
> 分项报告：[LOD1 构建](IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md)、[LOD1 独立验收](IRON_HARBOR_ARCHITECTURE_LOD1_VERIFY.md)、[共享贴图技术样板](IRON_HARBOR_ARCHITECTURE_SHARED_TEXTURES.md)。
> 日期：2026-10-20。状态：**自动门禁全部通过，等待人工视觉门禁（§10）**。

## 0. 判定摘要

| 需求项 | 目标 | 实测 | 判定 |
| --- | --- | --- | --- |
| 5 栋 LOD1 三角面 | ≤ LOD0 的 35%（逐栋 2 602 / 1 325 / 3 617 / 1 174 / 1 790） | **6 564 / 30 032 = 21.85%**（1 584 / 1 060 / 1 896 / 776 / 1 248） | PASS |
| LOD1 必须保留项 | 轮廓/屋顶/大型开口/烟囱/平台 | 需求 §5.1 清单逐项 PASS（独立几何检测 + 目视） | PASS |
| LOD0↔LOD1 一致性 | 包围盒/轴心/主方向一致 | 逐轴 **0.000 m**、轴心底面中心、zmin=0、rotation 0/scale 1 | PASS |
| 网格健康 | 边界边/非流形/孤立点/退化面 = 0 | 10/10 全 0（独立复算） | PASS |
| Warehouse_Short 檐口 | 修正 ~3.5 cm 残留；尺寸/轴心/主立面不变 | 顶皮@墙线 **−3.543 cm → 0.000 cm**；仅 8 个屋面顶点变化 | PASS |
| draw_meshes（同 PortStage/画质/构图） | ≤75（硬上限 80） | 舞台分析面 **91 → 73**；渲染器整帧 preview 89→**71** | PASS |
| 5 栋模型+纹理总量 | ≤4.5 MB | **4.17 MB**（10 个 GLB 2.28 MB + 11 张共享 PNG 1.88 MB） | PASS |
| 同屏城镇建筑三角面 | ≤60 000 | LOD0 **30 032** / LOD1 组合 **6 564** | PASS |
| LOD1 组合三角面 | ≤20 000 | **6 564** | PASS |
| 三条加载路径 | 松散 / `.snavmod.zip` / 发布包各一次 | 3/3 实测（见 §5） | PASS |
| 非目标对象 digest | 构建前后一致 | 245 对象 **0 missing / 0 added / 0 modified**（含几何哈希） | PASS |
| 无头测试 | 全绿 | **223 passed / 0 failed** | PASS |
| 人工视觉门禁 | 1440×900 与 960×540 可读、LOD1 不塌陷 | 材料齐全，待人工确认（§9） | 待确认 |

## 1. LOD1 清单与预算

| 资产 | LOD0 tri | LOD1 tri | 上限（35%） | 比例 | LOD1 保留（§5.1） |
| --- | ---: | ---: | ---: | ---: | --- |
| `SN_HT_Warehouse_Long` | 7 436 | **1 584** | 2 602 | 21.30% | 长体量、2 个双高装卸门真凹口、山墙吊梁、双坡铁屋面、石基、石檐口、通风帽 |
| `SN_HT_Warehouse_Short` | 3 788 | **1 060** | 1 325 | 27.98% | 不对称单坡侧棚、装卸门真凹口、偏置屋面通风管、不对称双坡主屋面、石基 |
| `SN_HT_Harbor_Office` | 10 336 | **1 896** | 3 617 | 18.34% | 三层分段（2 道石腰线）、拱形入口、钟楼+2 面空白钟盘、石檐口、2 个阳台大轮廓 |
| `SN_HT_Cargo_Shed` | 3 356 | **776** | 1 174 | 23.12% | 开敞柱廊、单坡棚顶、工作台大体量、后墙高位小窗 |
| `SN_HT_Tavern` | 5 116 | **1 248** | 1 790 | 24.39% | 两层轮廓、门廊、悬挂空白招牌、高烟囱、双坡屋面 |
| **合计** | **30 032** | **6 564** | **10 508** | **21.85%** | — |

- 生成器（参数化真源）：`tools/modeling/generators/sn_iron_harbor_architecture_lod1_generator.py`；纯 Python 干跑 `dryrun_props.py …` **ALL OK**；LOD1 工作台网格 vs 生成器顶点最大偏差 ≤ 8.2e-7 m（float32 精度）。
- 独立验收（Verifier 只读复算，`.design/verify_a/`）：3/4 剪影 IoU **0.9944 / 0.9938 / 0.9994 / 0.9905 / 0.9960**；无轮廓塌陷；LOD1 预览 30 张（15 单价 + 15 同机位对比）。

## 2. Warehouse_Short 檐口修复（唯一 LOD0 几何改动）

| 指标 | 修前 | 修后 | 判定 |
| --- | ---: | ---: | --- |
| 主屋面檐口顶皮 @ 砖墙顶线（−Y/+Y） | 7.4646 m（−3.543 cm） | **7.5000 m（0.000 cm）** | PASS（\|Δ\|≤0.005 m） |
| 立缝檐口端与屋面顶皮间隙（顶面参考） | 0.1013 m | 0.0627 m | 同向修复（底皮口径 4.525→0.688 cm） |
| tri / verts | 3 788 / 2 294 | 3 788 / 2 294 | 不变 |
| 尺寸 / 轴心 / 主立面 / 材质槽 | 11×9×9.5 / 底面中心 / +X / 6 槽 | 同左 | 不变 |

- 只改 `_roof_section()` 的 8 个屋面顶皮倒角顶点（z 方向 +0.01133 / +0.03861 m），x/y 未动；其余 4 栋 LOD0 重建后几何签名与构建前**逐字节一致**。
- 修复源码位置：`tools/modeling/generators/sn_iron_harbor_warehouse_short_generator.py`（`_roof_section()`，含注释说明原缺陷）。

## 3. 共享贴图 / 材质资源（§5.2）

- 方案对比：**采用「保留 GLB + 外部共享贴图 URI」**；`.gltf + .bin + 共享贴图` 被 `PathGuard.ASSET_EXTENSIONS`（只允许 `.glb/.png/...`）在模组扫描阶段结构性拒绝，未迁移。
- 10 个建筑 GLB 的 `images[].uri` 指向 `assets/models/props/iron_harbor_shared/<cell>.png`（11 张，与 `docs/design/textures/iron_harbor/tiles/` **逐字节一致**）；`ContentAssetLoader` 按 URI 缓存 `Texture2D`，5 栋建筑真实共享同一贴图实例（唯一实例数 11 = 唯一 cell 数，跨建筑同 cell 同实例、不同 cell 不同实例，独立探针 `verify_shared_textures.gd` 双路径验证）。
- `PortStage` 的材质签名合批因此把建筑材质批次从 29 收敛到 11：`batches 59→41`、`surfaces 91→73`。

## 4. 实测：性能与体积（1440×900，PortStage 固定机位）

| 指标 | batch B（内嵌贴图） | 批次 A（共享贴图） | 变化 |
| --- | ---: | ---: | ---: |
| 舞台分析面（draw_meshes 口径，harbor 构图） | 91 | **73** | −18 |
| 渲染器整帧 draw calls（preview） | 89 | **71** | −18 |
| 渲染器整帧 draw calls（sparse） | 82 | **64** | −18 |
| 渲染器整帧 draw calls（market / harbor / supply 站位） | 71 / 89 / 87 | **65 / 71 / 69** | −6 / −18 / −18 |
| 静态合批批次 | 59 | **41** | −18 |
| 5 栋 GLB 体积 | 6.86 MB | **2.28 MB（LOD0+LOD1）** | −4.58 MB |
| 5 栋模型+纹理总量 | 6.86 MB | **4.17 MB**（+ 共享 PNG 1.88 MB） | ≤4.5 MB |
| 同屏城镇建筑 tri（LOD0 / 本批可选 LOD1） | 30 032 | 30 032 / **6 564** | — |

- 整帧 `tris=73 228` 是「整场景」口径（含玩家船/水面/设施/道具），不是 §5.1 的「同屏城镇建筑」口径；后者按 5 栋 GLB 求和为 30 032（LOD0）/ 6 564（LOD1），均 ≤60 000。
- **LOD1 临时入舞台证据**（非正式接线，按需求「只交付可被质量档位使用的资产」）：把 5 个 LOD1 GLB 临时替换到街景槽位后，`[asset]` 行确认 tri 1 584 / 1 060 / 1 896 / 776 / 1 248、6×512² 贴图齐全；整帧 tri **73 228 → 49 760**（精确 = −30 032 + 6 564），draw calls 不变（71/64/65/71/69，合批按材质）；1440×900 与 960×540 固定机位截图 5 栋轮廓仍可辨认。随后已还原 LOD0 并重新 import。

## 5. 三条加载路径（§5.2 / §9）

| 路径 | 做法 | 结果 |
| --- | --- | --- |
| Core 松散目录（dev 模式） | `dev_mods/core` 直接读取；GLB 走编辑器导入资源，外部 PNG 走导入贴图共享 | measure：draw 71/64/65/71/69、blockouts=0；`[asset]` 5 栋 tri/贴图自证；1440/960 截图 |
| Core `.snavmod.zip`（运行时/发布路径） | `pack_core` 打包 → `measure_port_stage.gd -- --core-zip=<zip>` 挂载，`SN_TOWN_ASSET_ROOT=res://mods/core/...` 走原始 `ContentAssetLoader` | 与松散**完全一致**：draw 71/64/65/71/69、batches=41、surfaces=73、blockouts=0；共享贴图探针 `--mode=zip` 11 实例 |
| 发布包（导出 exe + 同级 `mods/*.snavmod.zip`） | 重新导出 `dist/build/windows`（Windows Desktop release），core zip 放入 `mods/` | 启动日志 `[INFO] mod load complete {"content":51,"mods":["core"],"status":"ok"}`、bootstrap ok；资产路径与 ZIP 行一致（同一挂载包加载代码） |

- core 包：`dist/mods/core-1.0.0.snavmod.zip` **6.14 MB**（121 files，含 10 个建筑 GLB + 11 张共享 PNG + 其余内容）。
- 已清理 Godot 从旧内嵌 GLB 解包的 39 张 `SN_HT_*.png` 构建产物（6.64 MB），避免被打进模组包。

## 6. 资产结构检查（10 个 GLB）

`verify_iron_harbor_architecture_lod_glb.py` 10/10 PASS：

| 资产 | LOD0 tri / bytes | LOD1 tri / bytes | 单根节点 | 材质槽 | 外部 URI | LOD0↔LOD1 bbox | 轴心/落地 |
| --- | --- | --- | --- | ---: | --- | --- | --- |
| Warehouse_Long | 7 436 / 455 256 | 1 584 / 89 988 | ✓ | 6 | 6 | 一致 | ✓ |
| Warehouse_Short | 3 788 / 240 292 | 1 060 / 64 252 | ✓ | 6 | 6 | 一致 | ✓ |
| Harbor_Office | 10 336 / 651 052 | 1 896 / 105 300 | ✓ | 6 | 6 | 一致 | ✓ |
| Cargo_Shed | 3 356 / 228 744 | 776 / 54 800 | ✓ | 5 | 5 | 一致 | ✓ |
| Tavern | 5 116 / 320 020 | 1 248 / 74 264 | ✓ | 6 | 6 | 一致 | ✓ |

- 每栋 cell 与 LOD0 cell 方案一致（Long：brick_wall / plaster_light / wood_plank_weathered / iron_dark / stone_base_dirty / glass_dark；其余见工单），材质名全部为 `SN_Town_*`，无材质槽越界；LOD1 根节点名 `SN_HT_<Name>_LOD1`。
- manifest 新增 5 个 `model.prop.*_lod1` 键（资产键 75→80）；LOD0 路径与旧存档/存档资源引用不变。

## 7. 回归与不变量

- 工作台：`SN_Iron_Harbor_Architecture` 集合内 5 LOD0（y=110/150 原位）+ 5 LOD1（y=175）；全场景 255 对象；**245 个非目标对象**（旧 `SN_Harbor_Town` 10 件占位、船/模块/设施/道具/干船坞等）0 modified / 0 missing / 0 added（含世界矩阵、dims、可见性、材质槽、逐对象几何哈希）。
- 交付快照：`.design/SN_Asset_Workbench.blend`（7.28 MB，含 10 个套件对象；旧快照备份 `.design/buildings/iron_harbor/a4/SN_Asset_Workbench_pre_batch_a_20261020.blend`）；候选/回滚：`.design/buildings/iron_harbor/a4/{embedded,external,legacy}/`。
- 旧内容 GLB 备份：`a4/legacy/`（5 个 LOD0 的共享贴图版本）+ `a3_legacy_textured/`（内嵌贴图版本）；`export_iron_harbor_architecture_lod_glb.py::restore_legacy()` 可回滚。

## 8. 测试与文档

- 无头测试：**223 passed / 0 failed**（新增 `test_content_asset_loader` 5 例：外部 URI 契约、跨建筑共享实例、旧格式回退、缺失失败缓存、ZIP 挂载共享）。
- 静态文档：`node tools/gen_static_docs.mjs` 已生成、`--check` 通过；新增/迁移 `@static-doc` 文件：`content_asset_loader.gd`、`measure_port_stage.gd`、`capture_port_stage_res.gd`、`verify_shared_textures.gd`、`glb_shared_textures.py`、`export_iron_harbor_architecture_lod_glb.py`、`verify_iron_harbor_architecture_lod_glb.py`、`sn_iron_harbor_architecture_lod1_generator.py`、`dryrun_lod1_batch_a.py`；移除对应旧 `FILE_DOCS` 条目。
- 文档同步：`ASSET_MAP.md`（建筑资产/共享贴图/舞台性能章节重写）、`todo.md`（批次 A 条目 + 当前下一步）、README 当前状态。
- 需求 §8 交付物对照见 §10。

## 9. 人工视觉门禁材料（§10）

1. **PortStage 固定机位 1440×900 / 960×540（LOD0 终态）**：`docs/design/screenshots/iron_harbor_architecture/SN_HT_Warehouse_Long_LOD0_port_stage_{1440x900,960x540}.png`。
2. **LOD1 固定机位 1440×900 / 960×540（临时入舞台证据）**：`…/SN_HT_Warehouse_Long_LOD1_port_stage_{1440x900,960x540}.png`（5 栋 LOD1 同时在场；960×540 下长仓库双高门、办公楼钟楼、货棚柱廊、酒馆山墙/烟囱、短仓库侧棚仍可辨认）。
3. **单栋 LOD1 三视图 + LOD0/LOD1 同机位对比**：`docs/design/screenshots/iron_harbor_architecture/<Asset>_LOD1_{street_3q,front_x,roof}_1280x800.png` 与 `<Asset>_LOD1_vs_LOD0_*`，共 30 张。
4. 风格层级：建筑与玩家船、港口设施、背景横幅同画面（截图 1/2）——请人工确认明度/饱和度/细节密度。
5. 性能收益 vs 资产格式复杂度：draw_meshes −18、包体 6.86→4.17 MB，代价是 GLB 外部 URI + 加载器共享缓存（无新格式、`.snavmod.zip` 自包含不变）。

## 10. 交付物对照（§8）

| §8 交付物 | 本批产物 |
| --- | --- |
| 1 参数化生成器 | `sn_iron_harbor_architecture_lod1_generator.py`（新增）、`sn_iron_harbor_warehouse_short_generator.py`（檐口修复）、`glb_shared_textures.py`、`export_iron_harbor_architecture_lod_glb.py`、`verify_iron_harbor_architecture_lod_glb.py` |
| 2 纯 Python dry-run 报告 | `dryrun_lod1_batch_a.py` + `.design/buildings/iron_harbor/a1/dryrun_lod1.json`（LOD1 6564/10508）；`verify_iron_harbor_architecture_lod_glb.py` 结构报告 `.design/buildings/iron_harbor/a4/structure_verify.json` |
| 3 工作台 + `.blend` 快照 | `.design/SN_Asset_Workbench.blend`（保存于验收后，含 5 LOD0 + 5 LOD1）+ 旧快照备份 |
| 4 运行时资产 + 结构检查 | 10 个 GLB（内容目录）+ §6 结构表 + `a4/structure_verify.json` |
| 5 3/4、主立面、屋顶、PortStage 截图 | §9 第 1–3 项（Blender 30 张 + PortStage 4 张） |
| 6 1440×900 / 960×540 Godot 截图 | §9 第 1–2 项 |
| 7 tri/材质/纹理/包体/draw calls/加载路径前后对比 | §4、§5、`IRON_HARBOR_ARCHITECTURE_SHARED_TEXTURES.md` |
| 8 ASSET_MAP / 验收报告 / 静态文档 / todo | 本报告 + 三份分项报告 + ASSET_MAP/todo/README/static docs |

## 11. 未闭合项与后续

1. **人工视觉门禁待确认**（§10）：本批自动门禁全绿；若人工认为 LOD1 某栋偏简，可在 18–28% 的比例上增加窗框/立缝（余量 3 944 tri），或调整批次 B 节奏。
2. **LOD1 未接入运行时质量档位**：按需求 §3/§5.1 不在本批实现切换逻辑；5 个 `model.prop.*_lod1` 键已登记，供后续质量档位/`visibility_range` 使用。
3. **已知简化**（不违反 §5.1 保留清单）：LOD1 窗只有真凹口无窗框/窗台；Office 只保留 2 面钟盘；Long/LOD1 屋面复用 LOD0 详细立缝；玻璃可见面积下降；Tavern 烟囱在 3/4 机位被屋脊部分遮挡。
4. **发布包共享贴图实测**：发布 exe 已用新代码重新导出并验证 mod 加载；渲染实测在松散/ZIP 两条同代码路径完成（发布包与 ZIP 行使用同一 `ContentAssetLoader` 挂载包路径）。
5. **后续批次**：批次 B（`SN_HT_Boiler_House` / `Workshop_Row` / `Brick_Tenement` 的 LOD0+LOD1）需等人工确认本批后开工；批次 C（Paddle Steamer 精修）需 A/B 完成后再确认。
