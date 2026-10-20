# `tools/modeling/generators/render_iron_harbor_architecture_preview.py`

> 作用：铁港建筑套件验收截图：临时相机 + 三盏太阳 + 地面 + 世界背景，只对 `SN_HT_Warehouse_Long_LOD0` 出图，渲染后还原可见性/相机/引擎/分辨率/世界并删除临时对象，不保存 .blend、不导出 GLB。

- 类型：项目配置/数据文件

## 契约与约束

- 固定机位由 `framework/ui/stages/port_stage.gd` 换算：Godot eye(46,28,64)/look_at(0,12,-8)/vfov 30°/keep_height + town 槽位 pos(-30,1.9,-33)/**yaw -106°** → Blender eye(24.30,209.79,26.1)/target(-32.24,145.73,10.1)；960×540 用同一垂直 FOV 的横向展开焦距。换算公式：`g = R_yaw⁻¹(p - slot_pos)`，`blender = (-48,110,0) + (g.x, -g.z, g.y)`。
- 输出 8 张到 `docs/design/screenshots/iron_harbor_architecture/`：固定机位 1440×900 与 960×540、同视角居中复查、街道低机位（1.7 m 眼高）、正交正视（+Y 主立面）、屋顶视图，以及材质近景 `*_detail_door_*`（装卸门一带：砖/木/铁/玻璃/石）与 `*_detail_base_*`（墙脚：石基/砖转角/落水管/檐沟）。
- 近景只为判读 trim sheet，不是验收机位：`DETAIL_DOOR` / `DETAIL_BASE` 的眼点与目标写在常量表里，改布局槽位不影响它们（它们用工作台坐标）。
- 渲染期间临时隐藏其它 mesh（含旧占位资产），结束后逐项恢复；不修改任何模型数据与运行时代码。

模块索引：[tools](../../README.md)
