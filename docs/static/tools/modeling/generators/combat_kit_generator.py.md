# `tools/modeling/generators/combat_kit_generator.py`

> 作用：`combat_kit` 敌舰套件（M2-1）的参数化生成器（纯 Python 几何 + Blender 装配入口）——

- 类型：项目配置/数据文件

4 艘敌舰共用一套「船体骨架」放样/甲板/舷墙/龙骨/艏艉构件，按敌舰类型挂不同上层建筑、
桅帆 / 烟囱与武备安装点；几何复用现有船体的站表放样思路与 `rig_kit` / `ship_parts`
部件库，不维护第二套帆索几何。

## 资产（阶段 2 需要 3 类敌人；本批 4 艘 × 3 类，含 2 艘 Light）
| 资产 | 敌人类别 | 轮廓 | 预算 | 武器 socket | 炮门 socket |
| --- | --- | --- | ---: | ---: | ---: |
| `SN_Enemy_Pirate_Sloop` | Light | 单桅纵帆、黑船身 + 锈红舷带、22.5 m | 5200 | 3 | 0 |
| `SN_Enemy_Merchant_Armed` | Medium | 双桅横帆武装商船、34 m 宽体 + 艉楼 | 7200 | 6 | 0 |
| `SN_Enemy_Ironclad_Raider` | Heavy | 低干舷铁甲舰变体、单烟囱 + 中央炮房、44 m | 7600 | 4 | 8 |
| `SN_Enemy_Gunboat` | Light | 小型蒸汽炮艇、艏部装甲炮盾 + 单烟囱、16 m | 2600 | 3 | 0 |

## 复用边界（M2-1 工单）
- 船体骨架：沿用现有船体的「横剖面站 + 剖面轮廓」放样（与 `SN_Schooner_Fame` /
  `SN_Ironclad` 同一套数学），不新造船型语言；
- 帆索：桅杆 / 斜桁 / 帆面 / 索具全部走 `rig_kit`（M0-4 部件库）；
- 甲板属具：舱口 / 绞盘 / 舵轮 / 罗经柜 / 锚 / 木桶 / 系缆桩 / 短梯全部走
  `ship_parts.deck`；艏斜桁 / 艏部分件走 `ship_parts.bow` / 自带实现；
- 武备：**不烘炮**。甲板炮位按 `weapon-assembly@2`（`hull-sockets@1`）给空节点，
  铁甲舰变体的舷侧炮门按 `hull-gunports@1` 给空节点，复用现成
  `SN_Weapon_CasemateGun` 模块（M0-6）。

## 坐标 / 轴心 / 命名
- 单位米，+X 船首、+Z 向上；根 = 水线中心（x=0 船中、z=0 水线），吃水为负 z；
- `SN_<PFX>_` 对象前缀 + `SN_<PFX>_Root` 根空物体；BLEND 内 socket 名带资产前缀，
  GLB 后处理归一化为 `SN_Socket_Weapon_*` / `SN_Socket_GunPort_*`；
- 材质只用 10 张 `SN_Tex_*` 共享贴图；UV 由 `sn_shared_materials.apply_collection(space="root")` 写。

## 纯 Python 接口（供 dryrun / socket 脚本 / GLB 验收复用）
- `SHIPS[asset]`：`hull` / `masts` / `builder` / `tri_budget` / `bbox` / `enemy_class`；
- `WEAPON_SOCKETS[asset]`：甲板炮位规格（含实测期望 `deck_z`，由船体站表解析计算）；
- `GUN_PORTS[asset]`：舷侧炮门规格（`gun_port_pose()` 从同一个船体站表推导）；
- `build_all_geometry(asset)` / `build_config(asset)` / `build_all(asset)`。

## 用法
- Blender 内：`import runpy; runpy.run_path(<本文件>, run_name="__main__")` 或
  `import combat_kit_generator as ck; ck.build_all("SN_Enemy_Pirate_Sloop")`
- 纯 Python 干跑：`python tools/modeling/generators/dryrun_combat_kit.py`

模块索引：[tools](../../README.md)
