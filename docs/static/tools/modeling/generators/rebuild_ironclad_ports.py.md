# `tools/modeling/generators/rebuild_ironclad_ports.py`

> 作用：炮门贴合船壳弧度的**重建脚本**（Blender 内跑一次，2026-10-22 修复批次）——

- 类型：项目配置/数据文件

按 `sn_ironclad_generator.build_all(with_barrels=False)` 重造船体网格（炮门框 / 深色炮口板 /
上翻门盖改为逐角取 `hull_surface_y()`，贴合 17 站放样壳面），再幂等复挂 4 武器 + 9 帆索 +
12 炮门 socket，并做只读复核。

## 为什么可以整船重建
M0-6 批次已把生成器同步到资产真源（`SN_Tex_*` 材质 + `apply_collection(space="local")` UV +
`with_barrels` 开关），`apply_casemate_assets.py` 的几何门禁也证明过“现存网格 = 生成器变体”。
本轮只改炮门件形状、三角面数不变（8158），重建后 socket 由各自脚本复原。

## 门禁与断言
- 重建前：现存网格必须是 5133 顶点 / 4624 面 / 8158 tri，8 个材质槽，逐材质面数等于基线；
- 重建后：三角面仍 8158、包围盒不变（60.13 × 18.00 × 28.64）、网格健康四项全 0；
- 复挂后：`sn_ship_weapon_sockets` / `sn_ship_rig_sockets` / `sn_ship_gun_ports` 只读复核全过，
  炮门中心与 `gun_port_pose()` 一致（误差 ≤ 1e-4）。

用法（已连 Blender 的会话）：
    import runpy; runpy.run_path(<本文件>, run_name="__main__")

模块索引：[tools](../../README.md)
