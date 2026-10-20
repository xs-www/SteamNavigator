# `tools/modeling/generators/sn_iron_harbor_architecture_lod1_generator.py`

> 作用：铁港建筑套件批次 A（LOD1）的**参数化真源生成器 + Blender 侧装配/自检/渲染 harness**：

- 类型：项目配置/数据文件

为 5 栋 LOD0 建筑各生成一个简化版 `SN_HT_<Name>_LOD1` 单 mesh 对象，并负责 LOD0 可复现重建、
逐栋门禁自检、全场景 digest 回归与 EEVEE 预览渲染。

- 关键依赖：`sn_iron_harbor_architecture_kit_generator.py`（Warehouse_Long 真源）、
  `sn_iron_harbor_warehouse_short_generator.py` / `sn_iron_harbor_harbor_office_generator.py` /
  `sn_iron_harbor_cargo_shed_generator.py` / `sn_iron_harbor_tavern_generator.py`（其余 4 栋真源）、
  `sn_iron_harbor_materials.py`（共享 6 材质 + trim sheet cell + 盒投影 UV）、
  `sn_iron_harbor_kit_batch2.py`（LOD0 cell 方案的唯一来源）、
  `dryrun_lod1_batch_a.py` / `dryrun_props.py`（纯 Python 干跑）。

## 契约与约束
- **参数化真源唯一**：本文件不复制 LOD0 尺寸/墙线/开口表，而用 `lod0(asset)` importlib 加载
  5 个 LOD0 生成器，读取其 `TARGET_SIZE / HALF_* / WALL_* / EAVE_Z / RIDGE* / ROOF* /
  *_OPENINGS` 常量并复用其闭合实体工具（`Part / panel / box / tb / prism_* / lprism_u /
  lvchamfer_box / beam / rod / _stone_plinth / _gable / _cornice / _roof_section /
  _shed_roof_section / _plinth / _chimney / _arch_lune / larc_band / revolved / ring_at`）。
  `_check_sources()` 在 dry-run 与 Blender 构建时校验目标尺寸与 LOD0 真源一致，禁止两边漂移。
- **LOD1 预算是硬门禁**：≤ 对应 LOD0 实测的 35%，逐栋上限为 Warehouse_Long 2 602 /
  Warehouse_Short 1 325 / Harbor_Office 3 617 / Cargo_Shed 1 174 / Tavern 1 790（合计 10 508）。
- **LOD1 必须保留**（需求 §5.1）：外轮廓、屋顶、大型开口（装卸门凹口/拱形入口/开敞柱廊/门廊）、
  主要烟囱与钟楼、檐口、阳台大轮廓、石基、单坡侧棚、偏置通风管、山墙吊梁、工作台大体量、
  悬挂招牌；允许删除小窗棂/窗框/滑轮细件/立柱/雨水斗/次要管线，栏杆可改带厚度连续实体。
  窗体仍用 `panel()` 真凹口（不靠贴图），不得只靠贴图撑轮廓。
- **LOD1 与 LOD0 一致性**：世界包围盒目标尺寸 ±0.02 m、轴心底面中心（zmin=0、x/y 包围盒
  中心 = 0），材质槽 ≤6 且全为 `SN_Town_*`；每个实体闭合（边界边/非流形边/孤立点/退化面全 0），
  UV 盒投影逐 loop 可复算、6 张 512² 贴图全部绑定。
- **只动本批对象**：`build_all()` 只删除/重建集合 `SN_Iron_Harbor_Architecture` 内精确命名的
  10 个 `SN_HT_*_LOD0/_LOD1`；不保存 `.blend`、不导出 GLB、不改 manifest/framework/tests/
  docs/static/todo.md/ASSET_MAP.md（Lead 验收后处理）。
- **共享材质坑**：6 个 `SN_Town_*` 是全局 datablock，`apply_to_object(cells=...)` 每次重建
  node tree，因此测量/渲染前必须"轮到谁就重写一次"（`_apply_cells`）。
- **命名/摆放**：对象 `SN_HT_<Name>_LOD0/_LOD1`；LOD0 位置与 batch2/M1 一致（y=110/150 两排），
  LOD1 统一放工作台 y=175 一排，仅工作台摆放，不动 PortStage 槽位。

## 重点逻辑
### `lod0(asset)` / `_check_sources()`
- 懒加载 + 缓存 LOD0 模块；目标尺寸以 LOD0 `TARGET_SIZE` 为准，避免 LOD1 抄数字。
### `build_<name>_lod1()`（5 个）
- 每栋 = 读 LOD0 真源参数 → 用 LOD0 自己的闭合实体重建简化外壳：石基 + 带真凹口的墙板 +
  简化屋顶/檐口 + 只保留轮廓级附件。删掉的都是门框窗棂/雨水管/小五金等不可读小件。
### `build_all()`
- 先快照重建前 5 栋 LOD0 的几何签名（可复现证据）与全场景 digest（排除 10 个目标对象），
  再重建 5 栋 LOD0（验证生成器可复现、让 Warehouse_Short 屋面修复生效）、新建 5 栋 LOD1，
  每栋按 batch2 cells 写共享材质/UV。
### `report()`
- 逐栋 16 项检查 + LOD0↔LOD1 bbox/轴心对比 + LOD0 可复现对比 + 檐口修复前后实测
  （旧源码从 `.design/buildings/iron_harbor/a1/warehouse_short_pre_fix.py` 真实重建测量）+
  全场景 digest/集合回归；结果落盘 `.design/buildings/iron_harbor/a1/lod1_report.json`。
### `render_previews(assets=None)`
- EEVEE 1280×800：每栋 3 张 LOD1 + 3 张 LOD0/LOD1 同机位对比（LOD1 临时平移、渲染后还原）；
  临时相机/3 盏太阳/世界背景/引擎/分辨率/隐藏状态全部在 `finally` 还原，临时对象删除。
### `measure_part()` / `tri_count()` / `edge_stats()` / `degenerate_faces()`
- 纯 Python 度量（无 bpy），供 dryrun 在进 Blender 前拦住 tri 超限/开口/边界边/退化面。

模块索引：[tools](../../README.md)
