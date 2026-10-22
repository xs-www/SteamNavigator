# `tools/modeling/generators/sn_lod1_kit_ships_generator.py`

> 作用：LOD1 基础套件（M0-5）的派生生成器：把工作台里 **kit 26 件**（weapon_kit /

- 类型：项目配置/数据文件

ship_parts / machinery / cargo / dock / architecture / environment）与 **4 艘可玩船**
的 LOD0 层级就地简化成单 mesh 的远景低模 `SN_<Asset>_LOD1`，写共享贴图材质 + 盒式 UV，
并把每个 LOD1 作为独立对象放回工作台 `SN_LOD1_Kit_Ships` 集合；随后可逐件导出 GLB
候选并把内嵌贴图外部化为 `shared_materials/<texture>.png`。

## 契约与约束
- 纯 Python 数据段（`PLAN` / `budget_plan` / `CAP_RATIO`）不 import bpy，dryrun /
  verifier / installer 可以直接加载本文件读计划；Blender 相关 import 全部在函数内。
- **LOD0 是唯一几何真源**：不复制生成器参数，不手摆点；LOD1 由工作台 LOD0 网格
  `Decimate(collapse)` 派生。≤`KEEP_TRI` 的小件原样保留，其余按资产预算统一 ratio，
  因此小结构（吊环、栏杆、系缆、铰链）不会先被吃掉。
- 包围盒钉死：LOD1 顶点在**根节点局部空间**按 LOD0 的 x/y/z min/max 逐轴重映射，
  保证 LOD0↔LOD1 世界包围盒逐轴一致（远景切换不跳尺寸、轴心落地/水线不变）。
- 单 mesh 交付：LOD1 把 LOD0 的所有 mesh 子件合并成一个 mesh（按材质分 primitive），
  不保留 socket / pivot / 层级；远景 LOD 不参与装配，接口契约只属于 LOD0。
- 材质：只允许 `SN_Tex_*` 共享贴图材质；先按面记录材质名，合并后去重再交给
  `sn_shared_materials.apply_to_object(space="local")` 重写槽位与 UV（几何不变）。
- 只写 `SN_LOD1_Kit_Ships` 集合与 `_LOD1` 对象；不删改任何 LOD0 / 其它集合对象。
- 导出候选写 `.design/lod1_kit_ships/`，不直接覆盖内容目录；安装由
  `install_lod1_kit_ships.py` 在独立验收通过后执行。

## 重点逻辑
### `build_all(assets=None)`
- 逐件取根节点的全部 mesh 后代（含 root 自身为 mesh 的 Ironclad），按 tri 预算决定
  每件 ratio；大件复制对象加 Decimate 后用 depsgraph 求值取网格（不 apply 修改器），
  小件直接读原网格；把三者统一变换到根局部空间、累加进一个 bmesh、三角化、去退化面。
- 生成 mesh 后写材质/UV、按 LOD0 bbox 重映射顶点、挂到 LOD1 集合，记录逐件报告。
### `report()`
- 逐件门禁：tri ≤ 上限且 ≤ LOD0×cap、bbox 与 LOD0 逐轴一致、LOD1 网格健康
  （边界边 / 非流形 / 退化面 / 孤立点）不高于 LOD0、材质全部是共享贴图材质、UV 完整。
### `export_candidates()`
- 逐件把对象矩阵临时置单位阵、selection-only 导出 GLB，再用
  `glb_shared_textures.externalize_glb(prefer_authored=True)` 外部化贴图；候选目录
  保留 `<category>/shared_materials/` 同级结构，安装时可整目录复制。

模块索引：[tools](../../README.md)
