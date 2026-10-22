# `tools/modeling/generators/verify_kit_batch5_glb.py`

> 作用：模型素材库批次 5（M1-2 base_kit 生产建筑，5 件）GLB 只读验收（纯 Python，

- 类型：项目配置/数据文件

不进 Blender）。复用 `verify_cranes_glb.py` 的 GLB 解析辅助与
`glb_world_bounds.py` 的世界空间几何读取，逐件核对：
- 节点 / 网格 / 图元数 > 0；tri 由 GLB accessor 实算并打印，对照生成器纯几何
  期望与所报 tri_budget（不写死 tri 数字）；
- 世界 bbox 按节点 TRS 合成后与工单 dimensions / 生成器 SPECS 对照，贴地
  min z（glTF Y）≈ 0；
- 材质全部为 `SN_Tex_*` 共享贴图、全部 doubleSided、每个图元有 TEXCOORD_0；
- 所有 image.uri 指向 `shared_materials/<texture>.png`，无内嵌 bufferView 图，
  外部 PNG 与 `docs/design/textures/shared_materials/tiles/` 授权 tile 逐字节一致；
- `assets/models/base/` 与 `dev_mods/core/assets/models/base/` 两处 GLB /
  shared_materials 副本一致；
- root extras 契约（含 module_grid=4.0、production；防御塔 production=false）、
  socket 节点父级与坐标（Blender (x, y, z) → glTF (x, z, -y)）。

用法：
    python tools/modeling/generators/verify_kit_batch5_glb.py

通过标准：每件 ALL OK 并输出 `verify_kit_batch5_glb: 5/5 ALL OK`，否则非 0 退出。

模块索引：[tools](../../README.md)
