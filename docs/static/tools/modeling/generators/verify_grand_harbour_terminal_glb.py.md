# `tools/modeling/generators/verify_grand_harbour_terminal_glb.py`

> 作用：`SN_Grand_Harbour_Terminal` 大型航站楼 GLB 的只读验收（纯 Python，不 import

- 类型：项目配置/数据文件

bpy，不进 Blender）。

复用 `verify_cranes_glb.py` 的 GLB 解析 / 世界 bbox / 共享 tile 校验辅助，核对：
- 期望值来自 `sn_grand_harbour_terminal_generator.build_geometry()` 的纯几何
  （tri / bbox / 材质 / 部件名）与常量 `TARGET_SIZE` / `TRI_BUDGET` / `TRI_FLOOR`；
- 节点数 / 网格数 = root + parts + 文字铭牌（`.design/terminal/build_report.json`
  存在时以其中 Blender 只读实测为准，否则按 build_geometry 推导）；
- tri：`build_report.json` 存在时要求 GLB 实算 == 报告实测，且 >= 几何 parts 的
  tri；报告缺失时只校验 TRI_FLOOR..TRI_BUDGET 且 >= 几何 parts tri；
- 世界 Y-up bbox 与 `TARGET_SIZE`（Blender X/Y/Z → glTF X/Z/Y）容差 ±0.15，
  贴地 zmin（glTF Y）≈ 0；与 build_geometry 局部 bbox、报告 bbox 交叉核对；
- 所有图元有 TEXCOORD_0、材质全部 doubleSided、无白名单外材质、无相机 / 灯光；
- 每张外部贴图 URI 为 `shared_materials/<texture>.png`，字节与
  `docs/design/textures/shared_materials/tiles/` 的授权 tile 一致，两处 runtime
  `shared_materials/` 副本齐全；
- `assets/models/architecture/` 与 `dev_mods/core/assets/models/architecture/`
  的 GLB 逐字节一致；
- root extras 关键字段（asset 必填；collection / tri_budget / tri_floor /
  bbox_target / units 等**存在即校验**）。

用法：
    python tools/modeling/generators/verify_grand_harbour_terminal_glb.py
    python tools/modeling/generators/verify_grand_harbour_terminal_glb.py <GLB 路径>

通过标准：打印 ALL OK 且退出码 0；有失败项时退出码 1。

模块索引：[tools](../../README.md)
