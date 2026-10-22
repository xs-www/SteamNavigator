# architecture_kit 扩展 M1-1 验收（批次 4：可围合基地 6 件，2026-10-22）

> 状态：**已交付并验收**。本文档保留验收证据与决策快照；契约与目录以
> [KIT_ASSET_LIBRARY.md §12](../design/KIT_ASSET_LIBRARY.md) 为准。

## 1. 范围

backlog [M1-1](../design/MODELING_BACKLOG.md) 的 6 件可围合建筑件（用户 2026-10-22 选定
「只做 M1-1」；`base_kit` / `interior_kit` 留后续批次）：

| 资产 | 角色 | 体量 / 包围盒（Blender 口径, m） | tri / 预算 |
| --- | --- | --- | ---: |
| `SN_Arch_Perimeter_Wall` | 围墙段（8 m 平铺） | 8.36 × 1.46 × 3.90 | 1 436 / 1 600 |
| `SN_Arch_Gate` | 大门门楼（门洞 3.72 × 3.82） | 8.40 × 2.30 × 5.34 | 2 112 / 3 400 |
| `SN_Arch_Road` | 道路段（8×8 四向平铺） | 8.00 × 8.00 × 0.29 | 1 368 / 1 500 |
| `SN_Arch_Loading_Platform` | 装卸平台（月台面 1.25 m） | 10.95 × 6.20 × 5.25 | 1 552 / 3 400 |
| `SN_Arch_Warehouse_Variant` | 仓库变体（14 级外楼梯上 3.48 m） | 11.80 × 8.51 × 8.55 | 4 216 / 4 600 |
| `SN_Arch_Workshop_Annex` | 工坊扩建（Drive_Shaft 接工坊） | 6.61 × 5.74 × 7.15 | 1 900 / 2 900 |
| **合计** | | | **12 584 / 16 800** |

工单：`tools/modeling/briefs/sn_kit_batch4_architecture_extension.json`。
生成器：`tools/modeling/generators/kit_batch4_generator.py`。

## 2. 自动验收证据

### 2.1 纯 Python 干跑（`dryrun_kit_batch4.py`）

6/6 `ALL OK`：命名 / 父级 / tri / bbox / zmin=0 / 边界边 / 非流形边 / 退化面 / 材质白名单 /
共享贴图 / socket 契约；本批专属断言：门扇-门柱净间隙 0.05（0.02–0.10）、吊闸最低 3.64 > 门顶
3.62、月台行走面 1.25、外楼梯到 3.48、地面接触面检查。

### 2.2 GLB 自检（`verify_kit_batch4_glb.py`）

```text
glb                            nodes  mesh prims   tris budget size(Y-up x,y,z)   textures flags
SN_Arch_Perimeter_Wall            12     6    19   1436   1600 8.36,3.90,1.46       7 external ok
SN_Arch_Gate                      16     7    22   2112   3400 8.40,5.34,2.30       7 external ok
SN_Arch_Road                      11     5     8   1368   1500 8.00,0.29,8.00       5 external ok
SN_Arch_Loading_Platform          13     6    16   1552   3400 10.95,5.25,6.20      8 external ok
SN_Arch_Warehouse_Variant         16     8    26   4216   4600 11.80,8.55,8.51      9 external ok
SN_Arch_Workshop_Annex            14     7    26   1900   2900 6.61,7.15,5.74       8 external ok
shared textures: 11 x 2 runtime dirs
verify_kit_batch4_glb: 6/6 ALL OK
```

逐件断言：节点/网格/图元非空、tri 与生成器几何一致且 ≤ 预算、世界 bbox 与工单一致、
min z ≈ 0、材质全 `SN_Tex_*`、全 doubleSided、每图元 `TEXCOORD_0` 且 UV 数量一致、
`images[].uri = shared_materials/<texture>.png` 且与授权 tile 逐字节一致、assets ↔ Core 双副本一致、
Root extras（含 `module_grid=4.0` / `enclosure`）与 socket 父级/坐标正确。

### 2.3 独立 Verifier（只读，Blender 4.4.3）

`passed = true / 0 failures`：82 对象、39 mesh 网格健康四项全 0、UV 39/39、37 socket 坐标误差
≤ 2.44e-5、Root extras 齐全；支撑面实测：装卸平台 5 级踏面 0.25→1.25、仓库变体 14/14 级到
3.48 m 且与 -Y 上层侧门门槛相接、15 个 z=0 底面、工坊送煤槽低端落在煤堆上、烟囱穿屋面；
大门射线净间隙 0.10–0.15 m；回归 817 非本批对象 / 62 既有集合 + 6 本批 / Camera=2 / Light=1 /
抽样 Root 坐标与文档一致。视觉 each 3/4 + 正 + 侧视无破面/黑面/明显穿模。

## 3. Godot 运行时

- 新增 `framework/tests/cases/test_architecture_extension_assets.gd`（2 例）：6 件 GLB 全部外链
  `shared_materials/*.png`、每面 UV、材质全 `SN_Tex_*`、tri 锁定（逐件 + 合计 12 584）、跨 6 件
  同一 `Texture2D` 实例（11 张）。
- 全量 headless：**425 passed / 0 failed**（含新用例）。

## 4. 预览

`docs/design/screenshots/kits/`：

- `kit_architecture_extension_lineup.png`（6 件 lineup）
- `kit_architecture_extension_assembly.png` / `_assembly_detail.png`（围墙 + 大门 + 道路 +
  装卸平台 + 仓库变体 + 工坊扩建的基地街景与近景）
- `kit_{perimeter_wall,gate,road,loading_platform,warehouse_variant,workshop_annex}_{three_quarter,side}.png`

## 5. 交付物

- 6 个 GLB：`assets/models/architecture/` + `dev_mods/core/assets/models/architecture/`
- 共享贴图 11 张 ×2 目录（无新增贴图）
- 生成器 / 干跑 / 导出 / GLB 验收 / 预览 5 个脚本
- `kit_catalog.json` v1.4（32 件 / 54 642 tri，+4 条基地装配配方）
- Godot 用例 + [KIT_ASSET_LIBRARY §12](../design/KIT_ASSET_LIBRARY.md) /
  [MODELING_WORKFLOW §11.20](../design/MODELING_WORKFLOW.md) /
  [ASSET_MAP 批次 4](../design/ASSET_MAP.md) 文档

## 6. 过程记录（返工与决策）

| 轮次 | 触发 | 处理 |
| --- | --- | --- |
| 干跑 v1 | mesh/socket 同名 2 处（Lantern / Chimney）、围墙超预算 76 tri | 网格改名 Lamp / Smokestack；铆钉行 9→6 |
| Builder R0 | 3 处工单验收偏差：月台行走面 1.39（被木板抬高）、仓库外楼梯只到 1.44、大门门扇净间隙 0.13–0.23 且吊闸与门顶相交 0.12 | 改生成器参数：月台整体下移、楼梯改 14 级到 3.48 + 上层侧门（bbox 8.46、预算 4000→4600）、门扇加宽到 ±1.80、吊闸抬高 |
| Builder R1 | 视觉挑刺：LP 末级 4 cm 钢包边台阶、WH 侧门与平台 x 只重叠 0.70/1.30 m | 包边压到踏面下、平台块顶 = 3.48、侧门收宽落在平台面内（tri 4228→4216） |
| 环境事故 | 建模期间用户机器死机，活体 Blender 丢失未保存场景 | 重新打开 `.design/SN_Asset_Workbench.blend`（817 对象基线）+ 重跑生成器恢复；生成器是唯一几何真源，工作台在导出时保存 |
| 导出 | — | `export_kit_batch4_glb.py` 6 件导出 + 外部贴图 + Core 副本 + 保存工作台 |

遗留（非阻塞，记录备查）：

1. 大门「净间隙」口径待统一：按门洞角柱测 0.05、按无箍带门柱面测 0.12–0.15；
2. 吊闸与门顶仅 0.02 m 余量，后续若加动画需再抬高；
3. `Wall_Top` socket z=3.90 是立柱黄铜尖端高度，中央压顶顶面 3.84；
4. `Module_Next/Prev` 是模块边界接口而非相邻体量中心距（沿 X 平铺时首尾相接，按 socket
   坐标直接叠放会半格重叠）——catalog/工单层语义需要在接入运行时前明确；
5. 仓库变体实心落地楼梯体量偏厚重、上层侧门与深色木墙同色（可读性，非验收项）；
6. 本批 LOD1 未做，运行时接入（PortStage / 基地舞台）另立任务。
