# `tools/modeling/generators/sn_iron_harbor_warehouse_short_generator.py`

> 作用：铁港建筑套件第二批：`SN_HT_Warehouse_Short` LOD0 的几何唯一真源（纯 Python，无 bpy），Part 交给 `sn_iron_harbor_kit_batch2.py` 装配/上材质/导出。

- 类型：项目配置/数据文件

## 契约与约束

- 实测 **3 788 tri / 2 294 顶点**、11.000×9.000×9.500 m、轴心底面中心、zmin 0、材质槽 6、边界边/非流形边/孤立点/退化面全 0；`dryrun_props.py` 干跑 ALL OK。
- 主立面在本地 **+X** 端面（槽位 yaw −90° 时正对固定机位，偏轴 ≈11°）；+Y 侧是单坡侧棚所在的次可见面（掠射 ≈78°），−X/−Y 放服务门、后勤窗、落水管。
- 该栋特征：3 级收分石基 0.55 m、不对称单坡侧棚（3 木柱 + 斜撑 + 4.60→3.35 屋面）、1 个内凹 0.26 m 的 3.0×4.3 装卸门（含滑轨）、2 扇 1.15×1.45 真凹窗（凹 0.14）、山墙灰泥三角 + 0.8×0.8 山墙窗、2.0×0.55 空白木招牌、1 根偏置铁通风管（Ø0.24）、屋脊沿 X 的双坡铁屋面 0.22 厚（3 道立缝/坡）。
- 与参考实现 `sn_iron_harbor_architecture_kit_generator.py` 同一套 `panel()` 真凹口墙板 + 显式倒角写法，辅助函数逐字复制，保证套件语言一致。

模块索引：[tools](../../README.md)
