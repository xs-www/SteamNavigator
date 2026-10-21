# `tools/modeling/generators/verify_cranes_glb.py`

> 作用：四台起重机 GLB 的结构与共享贴图自检（纯 Python，不进 Blender）。

- 类型：项目配置/数据文件

解析 glTF 2.0 二进制（GLB），核对节点数 / 网格数 / 图元 / 三角面 / 材质名 /
doubleSided / **世界空间** glTF Y-up 包围盒（按节点层级合成 TRS），以及
**贴图是否已外部化**：每个材质必须引用 `shared_materials/<texture>.png`，
文件存在且与 `docs/design/textures/shared_materials/tiles/` 的授权源字节
逐字节一致；每个图元必须有 `TEXCOORD_0`（UV 箱投影已烘焙）。

用法：
    python tools/modeling/generators/verify_cranes_glb.py
    python tools/modeling/generators/verify_cranes_glb.py <GLB 目录或单文件>

通过标准：每件 ALL OK，否则返回非 0 退出码。

模块索引：[tools](../../README.md)
