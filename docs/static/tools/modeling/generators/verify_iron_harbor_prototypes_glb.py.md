# `tools/modeling/generators/verify_iron_harbor_prototypes_glb.py`

> 作用：批次 B 三栋新原型（Boiler House / Workshop Row / Brick Tenement）运行时 GLB 的纯 Python 结构复检：逐件解析 LOD0+LOD1，核对 tri（LOD0 精确值 / LOD1 硬上限）、单根节点、材质槽、共享外部贴图 URI、LOD0↔LOD1 包围盒与轴心，并汇总「新原型模型+新增共享贴图」的包体增量。不依赖 Blender/Godot，可在 CI 与验收脚本里复跑。

- 类型：项目配置/数据文件

### 契约与约束
- LOD0 期望 tri 精确等于需求/构建报表：BH 7 388 / WR 7 312 / BT 9 376；LOD1 期望精确 2 536 / 2 444 / 2 704 且必须 ≤ 硬上限 2 800 / 2 800 / 4 900 与 ≤ LOD0 35%。
- 所有 image 必须是外部 URI（`iron_harbor_shared/<cell>.png`）且文件存在、与 `docs/design/textures/iron_harbor/tiles/` 源字节一致。
- 尺寸以 Godot/glTF Y-up 顺序校验：BH 12×12×10、WR 18×8.5×7、BT 10×12×8（x, height, depth，容差 ±0.10）；LOD0↔LOD1 逐轴差 ≤0.02；zmin=0、x/z 包围盒中心=0。
- 读取 `export_iron_harbor_prototypes_glb.CELLS` 作为每栋应使用的 trim cell 期望；材质名必须全部是 `SN_Town_*`。
- 失败项逐条打印并以退出码 2 失败；输出 `[verify-iron-harbor-prototypes] JSON {...}`。

模块索引：[tools](../../README.md)
