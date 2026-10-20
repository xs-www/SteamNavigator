# `tools/modeling/generators/sn_iron_harbor_materials.py`

> 作用：铁港建筑套件的**共享材质库**：6 个调色板材质槽 → trim sheet 的 6 个 cell（一张 512² 平铺贴图）+ 盒投影 UV + 自检；所有 SN 铁港建筑生成器都调用它，不各自建材质。

- 类型：项目配置/数据文件

## 契约与约束

- `MATERIAL_SURFACES` 是材质↔cell↔tile_m↔roughness/metallic 的唯一表：Brick→brick_wall、Plaster→plaster_light、Wood→wood_plank_weathered、Iron→iron_dark、Stone→stone_base_dirty、Glass→glass_dark；tile_m 一律 2.0 m（= 256 px/m，与 spec 的 `px_per_m` 一致）。
- 贴图源：`docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.spec.json`（16 cell 4×4×512 px，无 gutter）+ `tiles/<cell>.png`；图集 `iron_harbor_trim_sheet_2048.png` 只做评审，**不**被 UV 直接采样。
- 为什么不直接采图集：墙/屋面/石基是单个 20 m 级四边形，UV 限在 cell 内必须切面（实测 +5 416 tri @2 m cell、+1 484 tri @4 m cell，超 7 436+564 的预算），故每材质各取一张 REPEAT 平铺贴图，UV = world/tile_m 无上限，0 tri 增加。
- UV 规则：按面法线主轴盒投影（±Y→(x,z)、±X→(y,z)、±Z→(x,y)），不做每部件偏移 ⇒ 砖缝/石缝绕整栋连续、屋面立缝沿坡、门板竖直。
- `apply_to_object(obj)` 只改 UV 层与材质槽内容，不动几何（`geometry_unchanged` 自证）；`mesh.materials.clear()` 会把多边形 material_index 归零，因此**必须**先快照每面材质名再清槽（曾因此把整栋刷成 Stone）。
- `apply_to_object(obj, cells={material: cell})` 支持**每栋换 cell**（同一套 6 槽/6 贴图，砖石木铁玻璃各选一档；未知材质或未知 cell 直接抛错，不静默回退）；`verify_object(obj)` 校验调色板、槽位 ≤6、UV 完整、每槽贴图绑定 512²、无塌陷 UV 面、palette_spread（至少 5 个材质被用），以及 **`uv_projection_ok`**（按面主轴重算期望 `world/tile_m` 并与存盘 UV 逐 loop 比对，容差 1e-4——这是防下一栋建筑错投影的门禁）；贴图缺失时退回 R=G=B 灰阶占位让几何轮次仍可跑。

模块索引：[tools](../../README.md)
