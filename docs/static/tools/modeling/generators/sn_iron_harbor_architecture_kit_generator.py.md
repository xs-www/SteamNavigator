# `tools/modeling/generators/sn_iron_harbor_architecture_kit_generator.py`

> 作用：铁港建筑套件样板：`SN_HT_Warehouse_Long` LOD0 的几何唯一真源（纯 Python 几何 + Blender 内 `build_all()/report()`），建单 mesh 对象 `SN_HT_Warehouse_Long_LOD0` 并把材质/UV 交给共享材质模块；几何已在 R1 冻结。

- 类型：项目配置/数据文件

## 契约与约束

- R1 实测：**7 436 tri / 4 486 顶点**、20.000×9.000×11.000 m、轴心底面中心、`object.location=(-48,110,0)`，与旧占位资产同名同址；重跑只删除本集合内 `SN_HT_` 对象，`SN_Harbor_Town` 的旧 `SN_HT_Warehouse_Long` 原样保留（report 用全场景 digest 回归）。
- 主立面在本地 **+Y**、背面 −Y、山墙吊梁在 +X：PortStage town 槽位 yaw=−90° 时固定机位（world +X/+Z 一侧）只能看到本地 +X 山墙与 +Y 长墙，旧资产把门窗放 −Y 在该机位不可见，故样板按可见面重排主立面。
- R1 细化：双高门双道滑轨 + 3 吊架 + 每扇 2 滚轮 + 石/铁门槛 + 3.10×0.30 m 铁短平台；山墙吊梁加铁牛腿/双滑轮组/梁端板/斜拉杆；**4 段檐沟**接 4 落水管雨水斗；侧墙改 4 窗 + 3 壁柱；石基压到 **0.58 m** 并收窄到 19.56×8.56；檐口顶面抬到 7.53（与屋面底皮只留 0.02 阴影缝，消除檐口黑边）。
- `panel()` 生成带矩形凹口的闭合厚墙板：凹口侧壁/凹底按同一组网格线切分保证流形，窗凹 0.16 m、装卸门 0.28 m、人门/服务门 0.26 m（门扇面再退 0.16/0.20 m），墙体厚 0.46 m，不是共面深色板。
- 倒角不用全局 Bevel 修改器（会把砌块共面接缝切出沟槽），改显式倒角：主要轮廓 2 段（屋面檐口上棱 0.06 双段、石基压顶 0.015×2），次要构件 1 段（檐口 8 点型材最大出挑 0.30 m、吊货梁与壁柱/竖梃八边形截面、通风帽锥形帽、石窗台斜面）；主墙毛角由转角壁柱遮挡未单独倒角。
- 资产是多个互不相连的闭合实体拼装（非焊接单壳体），为保边界边=0 保留墙板内皮与石基底面；独立 Verifier 共面审计 477 对 / 5.74 m²，**0 对位于最外层 AABB 平面、0 对位于墙外表面**（最大外露为檐沟转角同材质 0.0112 m²，不可见；门槛挡铁 2 处跨材质 0.0088 m² 已内收 0.05 m 修掉），实机与六视图均无 z-fighting。
- 材质槽固定 6 个 `SN_Town_*`；`build_all(textured=True)` 建完对象后调用 `sn_iron_harbor_materials.apply_to_object()` 写 UV + 绑 trim sheet 贴图（模块按文件路径 importlib 加载，不依赖 sys.path；贴图缺失自动退回灰阶占位），`report()` 的 `textures` 段输出 uv 范围/loop 数/绑定贴图/校验，几何 `checks` 增加 `uv_loops_complete / geometry_unchanged_by_uv / all_images_bound / texture_slots_6` 四项，`checks.all_pass` 必须为 true。

模块索引：[tools](../../README.md)
