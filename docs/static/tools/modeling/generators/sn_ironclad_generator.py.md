# `tools/modeling/generators/sn_ironclad_generator.py`

> 作用：舷侧炮铁甲舰 `SN_Ironclad` 的参数化生成脚本（纯 Python 几何 + Blender 装配入口），

- 类型：项目配置/数据文件

同时是**炮门几何参数**唯一真源：`GUN_X` / `GUN_Z0..1` / `GUN_LENGTH` / `gun_port_pose()`，
供 `sn_ship_gun_ports.py`（船体 socket）与 `sn_casemate_gun_generator.py`（独立炮模块）复用。

工单：tools/modeling/briefs/sn_ironclad_broadside.json
集合：`SN_Ironclad_Prototype`；工作台摆位 (0, 90, 0)；轴心 = 水线中心（x=0 船中、z=0 水线、+X 船首）
尺寸：60.0 × 18.0 × 28.65 m（LOA 含艏斜桁与艉廊；z -4.2 .. 24.45），预算 ≤ 12 000 tri
材质：共享贴图 `SN_Tex_*`（8 个槽）；UV 由 `sn_shared_materials.apply_collection(space="local")` 写

设计（1860 年代舷侧炮铁甲舰）
- 低干舷铁壳：17 站放样，装甲带外凸 380 mm；水下锈红、水线以上铁灰。
- 撞角艏 + 艉廊；水线装甲带带竖向板缝。
- 舷侧炮门：每舷 6 个（炮门框 + 深色炮口板 + 上翻炮门盖），另 2 门艏 pivot 炮。
- 中央装甲炮房（斜壁）+ 指挥塔 + 双后倾烟囱 + 通风筒 + 天窗。
- 三桅横桁 + 艏斜桁 + 支索/侧支索；甲板：木甲板、舷墙、舱口格栅、绞盘、舵轮、小艇、锚、螺旋桨、艉旗。

2026-10-22 casemate 模块化（本批）：船体**不再烘炮管/炮口箍**——
`build_guns(with_barrels=False)` 只留炮门框 + 深色炮口板 + 炮门盖；炮管改为独立模块
`SN_Weapon_CasemateGun`，经 12 个 `SN_Socket_GunPort_*` 挂载（契约见
docs/design/WEAPON_SOCKET_CONTRACT.md §9）。`with_barrels=True` 仍保留“炮管烘死”的旧变体，
仅供 `apply_casemate_assets.py` 做“现存资产 = 生成器”的几何门禁与差异比对。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_ironclad.py`

模块索引：[tools](../../README.md)
