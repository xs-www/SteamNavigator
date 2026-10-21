# `tools/modeling/briefs/sn_crane_batch1.json`

> 作用：四台港口起重机的自包含建模工单（塔吊补全 / 大型龙门吊 / 木制桅杆起重机 / 手摇悬臂吊）。

- 类型：JSON 数据/配置

- 施工真源：`tools/modeling/generators/sn_harbor_crane_generator.py`、`sn_mega_gantry_generator.py`、`sn_wooden_mast_crane_generator.py`、`sn_hand_jib_crane_generator.py`。
- 共用部件库：`tools/modeling/generators/crane_kit.py`（桁架臂 / 格构柱 / 梯子 / 栏杆 / 轮 / 卷筒 / 滑轮 / 齿轮 / 钢缆 / 吊钩组 / 手摇绞车，纯 Python）。
- 离线干跑：`python tools/modeling/generators/dryrun_cranes.py`；导出：`export_cranes_glb.py`；结构自检：`verify_cranes_glb.py`；预览：`render_cranes_preview.py`。
- 尺寸 / 预算 / 材质 / 必含部件与验收条件全部写在本 JSON 的 `items[]`，子代理不依赖主会话上下文。
- 场景规则：Blender 单写者；不保存、不导出、不新建相机灯光、不修改其它集合；所有几何由参数表生成。
- 新增三件（龙门吊 / 木制桅杆起重机 / 手摇悬臂吊）本次只交付 Blender 集合 + GLB，不接入 Core manifest / PortStage；塔吊沿用既有 `model.prop.harbor_crane` 资产键，重建后需同步 `dev_mods/core` 副本。
- 木制桅杆起重机的参考图（图 1）是黑白港口照片，钢构/码头氛围用于语言参考；该件按历史木质桅杆吊处理，不照搬照片里的钢构塔吊。

模块索引：[tools](../../README.md)
