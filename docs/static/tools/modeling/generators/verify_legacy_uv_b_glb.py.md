# `tools/modeling/generators/verify_legacy_uv_b_glb.py`

> 作用：旧资产 UV 迁移 B 的 GLB 独立验收（纯 Python，不进 Blender/Godot）——

- 类型：项目配置/数据文件

核对 12 件船模块 / 4 艘船 / 5 件旧小镇道具的节点 / 网格 / 图元 / 三角面 / 世界尺寸 /
材质名 / doubleSided，以及"每个图元都有 TEXCOORD_0"、"材质全部 SN_Tex_* 且引用外部
shared_materials/<texture>.png"、"外部 PNG 与授权 tile 逐字节一致"、"没有内嵌图片"；
模块与船的 Core 副本必须与 assets 副本逐字节一致。

期望值来自迁移前 GLB 基线（.design/legacy_uv_b/baseline.json）：节点数 / 网格数 /
tri / 尺寸必须与迁移前一致，证明这次只改材质与 UV、没有动几何。图元数允许**少于**
基线：多个旧材质映射到同一张 `SN_Tex_*` 时（如 `SN_Canvas` / `SN_Canvas_Shade`、
`SN_Flag_White` / `SN_White`）同一 mesh 的槽位会合并，图元随之减少；只要不增加且
不少于网格数即视为合法。

用法：
  python tools/modeling/generators/verify_legacy_uv_b_glb.py
  python tools/modeling/generators/verify_legacy_uv_b_glb.py <单个 GLB>

通过标准：每件 ALL OK，否则返回非 0 退出码。

模块索引：[tools](../../README.md)
