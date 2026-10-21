# `tools/modeling/generators/verify_weapon_glb.py`

> 作用：舰载武器五件套 GLB 的结构与共享贴图自检（纯 Python，不进 Blender）。

- 类型：项目配置/数据文件

复用 `verify_cranes_glb.py` 的 GLB 解析与 BBox 合成：核对节点数 / 网格数 / 三角面 /
材质名 / doubleSided / glTF Y-up 包围盒 / 贴图外部化 URI 与授权 PNG 字节一致 /
每个图元都有 TEXCOORD_0。额外核对 Yaw / Pitch Pivot 节点名与根节点。

用法：
    python tools/modeling/generators/verify_weapon_glb.py
    python tools/modeling/generators/verify_weapon_glb.py <GLB 目录或单文件>
通过标准：每件 ALL OK，否则返回非 0 退出码。

模块索引：[tools](../../README.md)
