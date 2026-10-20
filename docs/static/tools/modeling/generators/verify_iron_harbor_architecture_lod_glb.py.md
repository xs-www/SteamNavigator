# `tools/modeling/generators/verify_iron_harbor_architecture_lod_glb.py`

> 作用：批次 A 运行时建筑资产的纯 Python 结构复检：逐件解析 `dev_mods/core/assets/models/props/SN_HT_*.glb`（5×LOD0 + 5×LOD1），核对 tri/单根节点/材质槽/共享外部贴图 URI/LOD0↔LOD1 包围盒与轴心，并汇总「模型+纹理」总量是否 ≤4.5 MB。不依赖 Blender/Godot，可在 CI 与验收脚本里复跑。

- 类型：项目配置/数据文件

### 契约与约束
- 期望 tri 与需求 §5.1 表一致：LOD0 7436/3788/10336/3356/5116，LOD1 1584/1060/1896/776/1248；LOD1 另校验 ≤ 对应 LOD0 的 35% 与 per-asset 上限。
- 所有 image 必须是外部 URI（`iron_harbor_shared/<cell>.png`）且文件存在、与 `docs/design/textures/iron_harbor/tiles/` 源字节一致；5 栋 LOD0+LOD1 只允许 11 个唯一 PNG。
- bbox 以 GLB accessor 的 glTF Y-up 包围盒换算 Godot Z-up：尺寸逐轴等于工单目标（±0.05），LOD0↔LOD1 逐轴差 ≤0.02，zmin=0、x/y 包围盒中心=0。
- 读取 `export_iron_harbor_architecture_lod_glb.CELLS` 作为「每栋应使用的 trim cell」期望；材质名必须全部是 6 个 `SN_Town_*` 调色板成员。
- 失败项逐条打印并以退出码 2 失败；输出 `[verify-iron-harbor-lod] JSON {...}` 供报告引用。

模块索引：[tools](../../README.md)
