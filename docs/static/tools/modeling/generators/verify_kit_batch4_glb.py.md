# `tools/modeling/generators/verify_kit_batch4_glb.py`

> 作用：模型素材库批次 4（M1-1 architecture_kit 扩展，6 件）GLB 只读验收（纯 Python，

- 类型：项目配置/数据文件

不进 Blender）。复用 `verify_cranes_glb.py` 的 GLB 解析辅助与
`glb_world_bounds.py` 的世界空间几何读取，逐件核对：
- 节点 / 网格 / 图元数 > 0；tri 由 GLB accessor 实算并打印，对照生成器所报
  tri_budget（不写死 tri 数字）；
- 世界 bbox 按节点 TRS 合成后与工单 dimensions 对照，贴地 min z（glTF Y）≈ 0；
- 材质全部为 `SN_Tex_*` 共享贴图、全部 doubleSided、每个图元有 TEXCOORD_0；
- 所有 image.uri 指向 `shared_materials/<texture>.png`，无内嵌 bufferView 图，
  外部 PNG 与 `docs/design/textures/shared_materials/tiles/` 授权 tile 逐字节一致；
- `assets/` 与 `dev_mods/core/` 两处 GLB / shared_materials 副本一致；
- root extras 契约、socket 节点父级与坐标。

用法：
    python tools/modeling/generators/verify_kit_batch4_glb.py

通过标准：每件 ALL OK 并输出 `verify_kit_batch4_glb: N/N ALL OK`，否则非 0 退出。

模块索引：[tools](../../README.md)
