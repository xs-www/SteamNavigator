# `tools/modeling/generators/sn_iron_harbor_prototypes_generator.py`

> 作用：铁港建筑套件**批次 B**（三栋新原型 LOD0 + LOD1）的**参数化真源生成器 + Blender 侧

- 类型：项目配置/数据文件

装配/自检/渲染 harness**：纯 Python 生成 `SN_HT_Boiler_House` / `SN_HT_Workshop_Row` /
`SN_HT_Brick_Tenement` 的 LOD0 与 LOD1 单 mesh 几何，并负责工作台建对象、共享材质/UV、逐栋门禁
自检、LOD0↔LOD1 bbox 对比、全场景 digest 回归与 EEVEE 预览渲染（含 LOD0/LOD1 同机位对比）。
第二阶段 LOD1 使用同一份 LOD0 真源常量，只保留需求 §6 的轮廓识别点。

- 关键依赖：`sn_iron_harbor_materials.py`（6 个 `SN_Town_*` 材质 + trim-sheet cell + 盒投影 UV）、
  `sn_iron_harbor_kit_batch2.py`（report/render 模板参考）、
  `docs/archive/MODELING_REQUIREMENTS_NEXT_BATCH.md` §6.1–6.4（尺寸/tri/必须包含项/轮廓门禁）、
  `docs/archive/IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_BUILD.md`（构建报告 + LOD1 章节）。

## 契约与约束
- **参数化真源唯一**：三栋的尺寸、墙线、开洞表、构件坐标全部由本文件的模块常量与
  `build_boiler_house() / build_workshop_row() / build_brick_tenement()`（LOD0）及
  `build_*_lod1()`（LOD1，读同一组常量）生成；导出都从这里重建；禁止只在 `.blend` 里手改。
- **三角面区间/上限**：LOD0 = BH/WR 6 000–7 500（cap 8 000）、BT 9 000–12 000（cap 14 000）；
  LOD1 = BH/WR cap 2 800、BT cap 4 900，且 ≤ 对应 LOD0 实测的 35%（dryrun/Blender 双重校验）。
- **必须包含项**（需求 §6）：BH = 错落屋顶 + 高砖烟囱 + 外露粗管 + 侧墙百叶 + 煤槽/灰斗 +
  检修平台；WR = 3 个连续工坊 bay + ≥2 种门宽 + 锯齿采光顶 + 墙面风机 + 雨棚 + 外置楼梯/猫道；
  BT = 三层砖立面 + 成列真凹窗洞 + 转角壁柱 + 后侧铁质逃生楼梯 + 多个烟囱 + 首层小店雨棚/封板。
  每个必须项/轮廓点在 `Part` 里用 `m.group(tag)` 打标，`report()` / `report_lod1()` 用 tag 的
  面数/tri/包围盒给出**几何证据**（不是口头声明）。
- **LOD1 保留/删除**：保留外轮廓、屋顶、主要开口、烟囱/平台/楼梯等大轮廓；删除窗框/窗棂/窗台
  窗楣/隅石/落水管/次要管线，百叶改整板、栏杆改连续实体板、屋面立缝减半（见 `LOD1_SPECS`）。
- **通用门禁**：+X 为正向；轴心底面中心（zmin=0、x/y 包围盒中心 = 0）；LOD1 与 LOD0 局部 bbox
  逐轴 ≤0.02 m；材质槽 ≤6 且只用 `SN_Town_*`；窗/门真凹口；网格健康孤立点/退化面/非流形边/
  边界边 = 0（每个实体闭合，独立闭合实体拼装）。
- **只动本批对象**：`build_all()` 只删/建 3 个 LOD0，`build_lod1()` 只删/建 3 个 LOD1（y=225）；
  所有其它对象（A 批 10 个 + 三栋 LOD0 + 旧场景）不得被改动（digest 回归）。
  不保存 `.blend`、不导出 GLB、不改 framework/dev_mods/manifest/tests/docs-static/todo/ASSET_MAP。
- **共享材质坑**：6 个 `SN_Town_*` 是全局 datablock，`apply_to_object(cells=...)` 每次重建
  node tree，所以测量/渲染前必须"轮到谁就重写一次"（`_apply_cells`；LOD1 沿用 LOD0 cells）。

## 重点逻辑
### `Part.group(tag)` + `feature_report()`
- 每个必须包含项/立面构件在生成时用 `with m.group("chimney"): ...` 打标；`feature_report()`
  把标签翻译成「面数 / tri / 包围盒」，供 report 输出硬证据（如 chimney 顶 z=12.00）。
### `build_boiler_house()` / `build_workshop_row()` / `build_brick_tenement()`
- 三栋 LOD0 全部用同一套闭合实体工具（`box / tb / prism_* / panel / lprism_u / lbox / beam /
  rod / arch_band`）拼装：石基 → 带真凹口的墙板 → 屋顶 → 附件。
### `build_*_lod1()` + `build_all_geometry_lod1()`
- 读同一组 LOD0 常量重建简化外壳：BH 保留烟囱/3 条主粗管/检修平台（连续栏板）/错落屋顶/煤场围墙；
  WR 保留 3 联锯齿顶 + 3 面天窗带 + 3 樘不同宽 bay 门 + 外置楼梯/猫道 + 风机；BT 保留三层体量/
  主立面凹窗/店面封板/3 烟囱/逃生楼梯大轮廓。纯 Python 入口供 `dryrun_prototypes_lod1.py` 干跑。
### `build_all()` / `report()` / `render_previews()`（LOD0）
- `build_all()`：先删旧 LOD0 再抓基线 → 只建 3 个对象 → 按栋写共享材质/UV。
- `report()`：tri 区间/上限、尺寸 ±0.10、zmin/轴心、材质槽、网格健康、UV/贴图、必须项证据、
  墙面打断、差异项、全场景 digest 回归；落盘 `prototypes_report.json`。
- `render_previews()`：EEVEE 1280×800，每栋 3 张 + 三栋 lineup；`finally` 还原相机/灯/世界/
  引擎/分辨率/隐藏状态并删临时对象。
### `build_lod1()` / `report_lod1()` / `render_lod1_previews()`（LOD1，y=225）
- `build_lod1()`：先删旧 LOD1 再抓基线（258 对象）→ 建 3 个 LOD1 → 按栋写同一 cells；
- `report_lod1()`：cap/35%、LOD0↔LOD1 bbox/轴心对比、健康/UV/轮廓 tag 证据、全场景 digest 回归
  （期望 258→261，除 3 个 LOD1 外零改动，LOD0/A 批逐对象状态不变）；落盘 `lod1_report.json`。
- `render_lod1_previews()`：每栋 3 张 LOD1 + 3 张 LOD0/LOD1 同机位对比（LOD1 临时平移，渲染后
  还原），命名含 `_LOD1_` / `_LOD1_vs_LOD0_`；`finally` 还原所有临时场景状态。

模块索引：[tools](../../README.md)
