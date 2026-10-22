# `tools/modeling/generators/verify_casemate_glb.py`

> 作用：casemate gun 模块化的 **GLB 独立验收**（纯 Python，不进 Blender / Godot）——

- 类型：项目配置/数据文件

一次核对两个交付物：

1. `SN_Weapon_CasemateGun.glb`：节点/网格/图元/三角面、炮门平面轴心（门外 1.5407 m /
   门内 0.95 m）、标准节点链（Mount → Pitch → Recoil → Muzzle）、`port_pitch` 装配 extras、
   外部共享贴图（URI + 授权 PNG 逐字节）与 UV；
2. `SN_Ironclad.glb`：空炮门版几何不变量（8158 tri / 1 mesh / 8 图元 / 世界尺寸不变）、
   26 个节点（1 mesh + 4 武器 socket + 9 帆索 socket + 12 炮门 socket）、每个炮门节点的
   局部 translation / 朝向 / extras 与 `sn_ship_gun_ports` 声明值一致、Root 三套 socket 名单。

用法：
    python tools/modeling/generators/verify_casemate_glb.py
    python tools/modeling/generators/verify_casemate_glb.py --gun <glb> --ship <glb>
通过标准：两个文件都 ALL OK；否则返回非 0 退出码。

模块索引：[tools](../../README.md)
