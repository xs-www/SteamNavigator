# 铁港码头小部件 · 工单总表

> 全量 31 件，拆成 5 批。**五批全部交付**，共 6282 三角面，31 个独立 `.glb`。
> 每批 = 一个工单 JSON = 一次 Builder 派发 + 一次 Verifier 批量验收。

## 批次总览

| 批次 | 工单文件 | 件数 | 三角面预算 | 状态 |
| --- | --- | --- | --- | --- |
| 1 | `sn_iron_harbor_batch1.json` | 6 | 2500 | ✅ 已完成：1260 tri（P0 整改后 1360 tri），已导出 `.glb` |
| 2 | `sn_iron_harbor_batch2.json` | 6 | 1900 | ✅ 已完成：1214 tri，已导出 6 个 `.glb` |
| 3 | `sn_iron_harbor_batch3.json` | 6 | 1300 | ✅ 已完成：1024 tri，已导出 6 个 `.glb` |
| 4 | `sn_iron_harbor_batch4.json` | 6 | 1600 | ✅ 已完成：1452 tri，已导出 6 个 `.glb` |
| 5 | `sn_iron_harbor_batch5.json` | 7 | 2100 | ✅ 已完成：1232 tri，已导出 7 个 `.glb` |

合计 **31 件 / 6282 三角面**，全部完成并导出独立 `.glb`（另含帆船 2608 tri 与塔吊 3420 tri）。
| 3 | `sn_iron_harbor_batch3.json` | 6 | 1300 | ⏳ 待派发 |
| 4 | `sn_iron_harbor_batch4.json` | 6 | 1600 | ⏳ 待派发 |
| 5 | `sn_iron_harbor_batch5.json` | 7 | 2100 | ⏳ 待派发 |

合计 **31 件 / 约 9400 三角面**（其中已完成 6 件 / 1260 tri）。

## 物件清单

**第一批（已完成）**：石砌岸壁 `SN_Dock_Wall`、木护舷 `SN_Dock_Fender`、系缆桩 `SN_Mooring_Bollard`、木箱 `SN_Crate`、木桶 `SN_Barrel`、矿石堆 `SN_Ore_Pile`

**第二批（照明 / 靠泊 / 装卸 / 煤）**：
`SN_Gas_Lamp` 煤气灯、`SN_Gangway` 跳板、`SN_Grab_Bucket` 双瓣抓斗、`SN_Coal_Pile` 煤堆、`SN_Dock_Ladder` 爬梯、`SN_Plate_Stack` 钢板堆

**第三批（堆场 / 管线）**：
`SN_Timber_Stack` 木料堆、`SN_Sack_Pile` 麻袋堆、`SN_Steam_Pipe` 蒸汽管段、`SN_Mooring_Rope` 缆绳卷、`SN_Cargo_Net` 吊货网、`SN_Pallet` 托盘

**第四批（机械 / 水上件）**：
`SN_Buoy` 浮标、`SN_Chain_Coil` 锚链堆、`SN_Capstan` 绞盘、`SN_Handcart` 手推车、`SN_Fender_Ball` 碰垫、`SN_Gear_Crate` 齿轮箱

**第五批（结构 / 标识 / 动力）**：
`SN_Dock_Stairs` 石阶、`SN_Port_Sign` 港口牌、`SN_Bell` 港口钟、`SN_Flag_Pole` 旗杆、`SN_Coal_Chute` 煤溜槽、`SN_Boiler_Unit` 锅炉机组、`SN_Keel_Block` 龙骨墩

## 场景布局

- 集合统一为 `SN_IronHarbor_Props`，对象前缀 `SN_`；
- 每批一排，避免重叠：第一批 y=24（已建），二/三/四/五批 y=30 / 36 / 42 / 48，x 从 −12 起每件 5 m；
- 每件轴心在自身底面中心（`object.location` = 布局位置，几何为局部坐标）；
- 导出时逐件把 `location` 临时归零，导出后还原。

## 材质

- 复用：`SN_Wood`、`SN_Wood_Dark`、`SN_Metal`、`SN_Stone`、`SN_Canvas`、`SN_Ore`；
- 第二批新增：`SN_Coal`（base 0.020/0.019/0.018，roughness 0.95，metallic 0），煤堆专用；
- 所有材质参数不得改动，只允许新增。

## 低谷窗口执行步骤（每批）

1. **Builder**：一个子代理一次建完整批（6–7 件），在同一个集合里追加，不改已有对象；
2. **Verifier**：一个只读子代理一次验收整批（命名 / 预算 / 原点 / 材质 / 网格 / 回归 / 视觉）；
3. **导出**：主会话一段脚本逐件零位移导出到 `assets/models/props/`，同时保存工作台；
4. 全部批次完成后：更新 `docs/design/ASSET_MAP.md`，再做码头场景装配。

## 派发提示词模板（简版）

```text
你是 Steam Navigator 的建模子代理（Builder），在 Blender 4.4 中工作，MCP 已连接。
按工单 <brief 路径> 一次性建完 <N> 件：
- 集合 SN_IronHarbor_Props，对象前缀 SN_，命名严格按工单；
- 每件几何用局部坐标（底面中心 = 原点），object.location = 工单里的 position；
- 材质只用调色板，新增材质仅在工单声明时创建；
- 禁止删除/修改 Camera、Light、SN_Ship_Prototype、SN_Harbor_Crane_Prototype 以及已建好的道具；
- 不保存、不导出、不新建灯光相机；
- 自检后用 JSON 返回（对象清单 / 三角面 / bbox / 材质 / 网格健康 / 原有对象未变）。
```

## 已知约定与坑

- Builder **不落盘**，验收后必须由 Lead 保存工作台并导出 `.glb`；
- 木箱的金属箍曾与木芯共面，已把木芯内缩 1.45 mm 修复；后续同类"铁箍包木"结构直接留 1–2 mm 凸出；
- 小件取景容易被塔吊/帆船挡住，验收用 +Y 侧分组机位；
- 单个 `.glb` 只含一个网格节点，轴心在底面中心，Godot 里直接放在地面上即可。
