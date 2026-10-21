# `tools/modeling/generators/sn_ship_rig_sockets.py`

> 作用：M0-4 船体帆索安装点 `SN_Socket_Mast / Yard / Sail` 的**规格 + Blender 应用/复核**

- 类型：项目配置/数据文件

（纯 Python 规格段不依赖 bpy；`apply_all()` / `verify_all()` 在 Blender 内运行）。

背景：3 艘有帆索的船（明轮货轮 / 纵帆船 / 铁甲舰）的桅杆 / 横桁 / 帆安装点由
`rig_kit` 参数化几何定义后，**几何仍焊在船体 GLB 里**（本批不做运行时装配），
但要在场景与 GLB 里暴露标准空节点，供后续 `ShipVisualAssembler` / 战斗层接管：
- `SN_Socket_Mast_<Key>`：甲板上的桅杆安装点（世界 z = 该点甲板实测高度）；
- `SN_Socket_Yard_<Key>`：横桁 / 斜桁安装点（桅杆上的桁位）；
- `SN_Socket_Sail_<Key>`：帆面挂点（帆前下角 tack / 收帆卷中心）。

约束：
- **零几何**：apply 只增删空节点，逐集合 mesh 数 / tri / 对象名快照必须前后一致；
- socket 是 Root 的直接子节点，局部坐标 = 船体坐标（Root 在工作台摆位不影响）；
- BLEND 内名字带资产前缀（`SN_PF_Socket_Mast_Fore`）避免同工作台重名，
  GLB 导出后由 `glb_ship_rig_sockets.standardize()` 归一化为 `SN_Socket_*`；
- Blender IDProperty 不支持字符串数组，Root 侧只写 `rig_socket_count` /
  `rig_socket_spec`，`rig_sockets` 名单在 GLB JSON 层写。

用法：
- 纯 Python：`python tools/modeling/generators/sn_ship_rig_sockets.py --check`
- Blender：`runpy.run_path(<本文件>, run_name="__main__")`

模块索引：[tools](../../README.md)
