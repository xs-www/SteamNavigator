# `tools/modeling/generators/dryrun_combat_kit.py`

> 作用：`combat_kit` 敌舰套件（M2-1，4 艘）生成器的纯 Python 干跑 —— 不进 Blender，

- 类型：项目配置/数据文件

直接加载 `combat_kit_generator.py` 的几何与规格表，核对：
- 命名 / 对象前缀 / 父级键（ROOT 或 Pivot key）/ 集合内无重名；
- 每艘 tri 预算、包围盒（含 target ± tol）、吃水（zmin）/ 桅顶（zmax）合理；
- 网格健康：非流形边 / 退化面 / 孤立点全 0；闭合件边界边 0；开放件（甲板 / 帆面）
  允许边界边但必须 > 0（确实是单层面）；
- 材质白名单：全部是 `SN_Tex_*` 共享贴图材质，无旧纯色 / 未声明材质；
- socket 规格：class 合法、左右镜像、y 在甲板内、clearance 口径；
- 炮门规格：8 个 / port_class 与开口能接 `SN_Weapon_CasemateGun`（Medium 1.9×1.9）。

用法：
    python tools/modeling/generators/dryrun_combat_kit.py
    python tools/modeling/generators/dryrun_combat_kit.py SN_Enemy_Gunboat

模块索引：[tools](../../README.md)
