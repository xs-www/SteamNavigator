# `tools/modeling/generators/verify_legacy_uv_glb.py`

> 作用：旧资产 UV 迁移 A 的 GLB 独立验收（纯 Python，不进 Blender/Godot）——

- 类型：项目配置/数据文件

核对 37 件道具 / 设施的三角面、图元数、世界尺寸、贴地、材质名、doubleSided，
以及「每个图元都有 TEXCOORD_0」「每个材质都引用外部 shared_materials/<texture>.png」
「外部 PNG 与授权 tile 逐字节一致」「没有内嵌图片」。

期望值来自迁移前 GLB 基线（`capture_baseline.py`）：tri 与尺寸必须与迁移前一致，
证明这次只改材质与 UV、没有动几何。

用法：
  python tools/modeling/generators/verify_legacy_uv_glb.py
  python tools/modeling/generators/verify_legacy_uv_glb.py <单个 GLB>

通过标准：每件 ALL OK，否则返回非 0 退出码。

模块索引：[tools](../../README.md)
