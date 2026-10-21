# `tools/modeling/generators/verify_cranes_glb.py`

> 作用：四台起重机 GLB 的结构自检（纯 Python，不进 Blender）。

- 类型：项目配置/数据文件

解析 glTF 2.0 二进制（GLB），核对节点数 / 网格数 / 图元 / 三角面 / 材质名 /
doubleSided / **世界空间** glTF Y-up 包围盒（按节点层级合成 TRS，能正确覆盖
挂在 Pivot 下的部件），专抓「改了场景忘了重导 GLB」「轴心/轴向错误」
「材质被改成单面」。用法：

    python tools/modeling/generators/verify_cranes_glb.py
    python tools/modeling/generators/verify_cranes_glb.py <GLB 目录或单文件>

通过标准：每件 ALL OK，否则返回非 0 退出码。

模块索引：[tools](../../README.md)
