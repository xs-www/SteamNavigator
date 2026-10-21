# `tools/godot/verify_cranes.gd`

> 作用：四台起重机 GLB 在 Godot 侧的导入验收（只读）：尺寸 / 三角面 / 材质 / 贴地。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `TOL` | L18 |
| `EXPECTED` | L21 |
| `_init() -> void` | L29 |

用法：
  godot --headless --path . --import
  godot --headless --path . --script res://tools/godot/verify_cranes.gd

判定口径：
- glTF 由 Blender 的 Z-up 转为 Y-up，因此 Godot 尺寸 = (Blender X, Blender Z, Blender Y)；
- 尺寸与工单误差 <= 0.05 m；
- 三角面数必须与 Blender 场景 / GLB 自检完全相等：专门用来抓
  「改了 .blend 却忘了重导 GLB」或「Godot 读到旧导入缓存」；
- 包围盒底面 y 必须贴 0（起重机轴心在轨道面 / 地面中心）；
- 至少 1 个网格节点、1 个材质。

模块索引：[tools](../README.md)
