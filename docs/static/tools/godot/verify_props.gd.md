# `tools/godot/verify_props.gd`

> 作用：道具 GLB 导入验收（只读）：加载 `assets/models/props/*.glb`，量测 Godot 侧包围盒、三角面与材质名，对照 brief 尺寸判定尺度与轴向。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `_init() -> void` | L57 |

## 契约与约束

- glTF 由 Blender Z-up 转 Y-up，故期望尺寸 = (Blender X, Blender Z, Blender Y)；`EXPECTED` 表必须按此口径维护。
- 尺寸容差 0.05 m；三角面必须与 `EXPECTED` 精确相等——这条专门抓"改了 .blend 忘了重导 GLB"与"读到旧导入缓存"。
- 只读，不写场景也不改导入设置；失败退出码 1。
- 改了 GLB 之后必须先 `godot --headless --import` 刷新缓存，否则量到的是 `.godot/imported` 里的旧产物。

模块索引：[tools](../README.md)
