# `tools/modeling/generators/sn_casemate_gun_generator.py`

> 作用：**穿船壳炮（casemate gun）独立模块** `SN_Weapon_CasemateGun` 的参数化生成器

- 类型：项目配置/数据文件

与 Blender 装配入口 —— 把铁甲舰舷侧炮从船体网格里拆出来，改为可挂到任意带炮门
（`SN_Socket_GunPort_*`）的船体上的独立 GLB。

## 轴心 / 朝向（与甲板武器的“炮座底面 z=0”不同）
- 根节点原点 = **炮门平面中心**（炮膛轴线与船壳面的交点），不是甲板；
- 局部 `+X` = 炮膛轴线，指向舷外；`+Z` 向上；`+Y` 沿船体纵轴（左舷侧）；
- 可见几何全部在 `x >= 0`（门外），`x < 0` 是藏在船壳暗板后面的隐藏段
  （炮尾 / 耳轴 / 内膛遮挡件），后坐与俯仰都不应让它们露出来。

## 层级（武器装配规范 v2 + `port_pitch` profile）
```text
SN_Weapon_CasemateGun_Root
  SN_Mount            安装帧（=根，原点在炮门平面中心）
    SN_Pivot_Pitch    耳轴（x=-0.15，在门内）
      SN_Recoil       后坐节点（沿 -X 平移）
        SN_Muzzle     炮口端面中心
```
没有 Yaw（固定舷炮）。炮管 / 炮口箍 / 炮尾 / 耳轴网格都挂 `SN_Recoil`。

## 与船体的配合
- 船体保留“炮门框 + 深色炮口板 + 上翻炮门盖”，本模块只提供门外炮管；
  深色炮口板同时是隐藏段的遮挡面（空载时炮门读作暗腔，装炮后炮管从暗腔里伸出）。
- 几何取自 `sn_ironclad_generator.py` 的同一组参数（`GUN_*` / `gun_port_pose()`），
  因此装到铁甲舰 12 个炮门上时与拆炮前的烘焙炮管**逐顶点重合**（dryrun 断言）。
- 材质走共享贴图 `SN_Tex_*`（仅 Metal / Brass / Iron 3 个槽）。

用法：
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_casemate_gun.py`
- 导出 GLB：`python tools/modeling/generators/export_casemate_glb.py`（Blender 内）

模块索引：[tools](../../README.md)
