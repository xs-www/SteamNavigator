# `tools/modeling/generators/dryrun_casemate_gun.py`

> 作用：casemate gun 模块（`SN_Weapon_CasemateGun`）的**纯 Python 干跑**——不进 Blender，

- 类型：项目配置/数据文件

在写场景/导出前拦住几何、接口与“装上去对不对”的错误。

核对项：
1. 材质白名单 / 共享贴图库（`sn_weapon_materials` + `sn_shared_materials.texture_report()`）；
2. 几何：对象命名/父级、三角面预算、包围盒 = 模块 `envelope()`、闭合壳体（边界边/非流形/退化面）；
3. 轴心契约：`x < 0` 全部是门内隐藏段（炮尾 / 耳轴），且都落在 1.9×1.9 炮门开口内；
4. Pivot 链：Mount → Pitch（耳轴 x=-0.15）→ Recoil → Muzzle，Muzzle 落点在炮口端面中心；
5. **装到铁甲舰 12 个炮门上时与拆炮前的烘焙炮管逐顶点重合**（这是本批最关键的验收断言）；
6. 俯仰极限：±ELEV 时可见段仍在炮门开口内、隐藏段仍在门内（不会被看见）。

用法：`python tools/modeling/generators/dryrun_casemate_gun.py`
通过标准：打印 `ALL OK`；任何一项失败返回非 0 退出码。

模块索引：[tools](../../README.md)
