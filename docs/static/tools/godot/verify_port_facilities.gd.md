# `tools/godot/verify_port_facilities.gd`

> 作用：港口设施锚点 GLB 导入验收（只读）：加载 `assets/models/port/SN_*.glb` 6 件，量测 Godot 侧包围盒 / 三角面 / 材质名，对照工单尺寸与调色板判定。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TOL` | L14 |
| `EXPECTED` | L17 |
| `PALETTE` | L26 |
| `_init() -> void` | L32 |

## 契约与约束

- glTF 由 Blender Z-up 转 Y-up，故期望尺寸 = (Blender X, Blender Z, Blender Y)；`EXPECTED` 表必须按此口径维护。
- 尺寸容差 0.1 m（龙门吊 Y 含爬梯外凸，期望值 4.014）；三角面必须与 `EXPECTED` 精确相等，抓"改了 .blend 忘了重导 GLB"与旧缓存。
- 包围盒最低点必须在 y=0（原点在底面中心）；材质名必须全部在调色板内；只读，失败退出码 1。
- 改 GLB 后先 `godot --headless --import` 刷新缓存再跑本脚本。

模块索引：[tools](../README.md)
