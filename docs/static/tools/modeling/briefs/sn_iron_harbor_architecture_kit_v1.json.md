# `tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json`

> 作用：铁港近中景城镇建筑视觉升级工单：以模块化中等精度建筑替换 PortStage 白盒，定义 8 类建筑、共享材质与纹理、LOD 和固定机位门禁。

- 类型：JSON 数据/配置

## 契约与约束

- 现有 SN_HT_Warehouse_Long / Warehouse_Short / Harbor_Office / Cargo_Shed / Tavern 保持资产名和近似占地尺寸，可原位替换；另新增 Boiler_House / Workshop_Row / Brick_Tenement。
- 几何必须提供真实窗门深度、墙顶厚度和受控倒角；长度超过 6 m 的可见墙面至少用两种结构方式打断，不允许退回纯盒子或共面窗门。
- 典型 PortStage 同屏建筑目标 <=60000 tri；LOD1 <= LOD0 的 35%；每栋材质槽 <=6，并共享 2K trim sheet 与 1K 污渍遮罩。
- Builder 只写 SN_Iron_Harbor_Architecture 集合并交付生成器/LOD/预览；运行时接线、manifest、打包和旧 GLB 替换由 Lead 在人工验收后执行。

模块索引：[tools](../../README.md)
