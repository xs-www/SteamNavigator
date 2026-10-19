# 港口设施锚点 · 建模工单总表

> 用途：2.5D 固定机位港口舞台（`PortStage`）的设施可辨认锚点。
> 工单：[`sn_port_facilities_batch1.json`](sn_port_facilities_batch1.json)（6 件，总预算 10500 tri）。
> 规范来源：[2.5D_STAGE_PLAN.md](../../docs/design/2.5D_STAGE_PLAN.md) §8「设施锚点」。

## 1. 结论先说

设施需要建模，但**只建锚点**：

- 建：一眼能认出的外轮廓 + 1–2 个标志性细节（市场棚、告示板、水箱、信号塔、龙门吊、干船坞）。
- 不建：室内、柜台内部、可进入的门、NPC、碰撞体、设施背面、镜头看不到的面。
- 不烘焙：招牌和纸张上**不写文字**，文字交给 2D UI 标签层，避免每种语言一套贴图。
- 复用：货箱、木桶、煤堆、煤气灯、绞盘、系缆桩、龙骨墩、跳板、石阶、港口牌、旗杆、港口钟、蒸汽管、煤溜槽全部已有，不要重做。

## 2. 六件总览

| # | 资产 | 设施 | 尺寸 (L×W×H m) | tri 预算 | 材质 | 优先级 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `SN_Market_Stall` | exchange 市场 | 5.0 × 3.0 × 3.2 | 1800 | Wood / Wood_Dark / Canvas / Metal / Brass | P0 |
| 2 | `SN_Notice_Board` | contracts 委托 | 2.8 × 0.5 × 2.6 | 500 | Wood / Wood_Dark / Canvas / Metal | P0 |
| 3 | `SN_Water_Tank` | supply 补给 | 4.0 × 4.0 × 5.2 | 1400 | Metal / Iron / Wood_Dark / Brass / Stone | P0 |
| 4 | `SN_Signal_Tower` | intel 情报 | 3.2 × 2.4 × 8.5 | 1600 | Metal / Iron / Wood_Dark / Canvas / Brass | P1 |
| 5 | `SN_Shipyard_Gantry` | shipyard 船厂 | 14.0 × 4.0 × 10.0 | 2600 | Metal / Iron / Wood_Dark / Brass | P0 |
| 6 | `SN_Dry_Dock` | shipyard 船厂 | 18.0 × 8.0 × 2.6 | 2200 | Stone / Metal / Wood_Dark | P0 |

预算合计 10500 tri；单件允许上浮到 1.2×，超了先删细节不加预算。

## 3. 每件建模要点

### 3.1 `SN_Market_Stall`（市场棚）

- 结构：4 根木柱（前后高差 0.4 m 让棚顶前倾）→ 前柜台（1.1 m 高）→ 两侧半高挡板 → 帆布棚顶（前后两片微下垂、双面材质）→ 2 个挂灯钩 → 一块**空图标招牌板**（留 0.6 × 0.4 m 平面）→ 柜台后货架 + 2 个木箱（可引用现有 `SN_Crate` 尺寸）。
- 读感：3/4 视角必须同时看到柜台、帆布顶、挂灯钩；柱子不要糊死柜台开口。
- 坑：帆布是单层曲面 → 必须双面；棚顶与柱顶留 5 mm 间隙，避免共面黑斑。

### 3.2 `SN_Notice_Board`（委托告示板）

- 结构：2 根立柱 → 木框布告板（略后仰 5°）→ 后挡板 → 6 张浅色纸张（厚 ≥ 4 mm，双面，前后错位 10–20 mm）→ 小披檐 → 侧挂灯托架。
- 读感：远看是“一块贴满纸的板”，纸张对比度要够（`SN_Canvas` 浅色 vs `SN_Wood_Dark`）。
- 坑：纸张不能与板面共面；纸张不得超出框边。

### 3.3 `SN_Water_Tank`（港口水箱）

- 结构：石/木基座环 → 16 边铆接圆筒 → 锥形顶盖 → 3 道铁箍 → 出水弯管 + 阀门 → 侧爬梯 → 细长液位计条 → 黄铜铭牌（空白）。
- 读感：圆筒 + 锥顶 + 铁箍三件套是识别点；液位计用深色窄条，不做自发光。
- 坑：爬梯与筒壁留 30 mm 间隙；铁箍比筒壁凸出 20–30 mm，别做共面。

### 3.4 `SN_Signal_Tower`（情报信号塔）

- 结构：4 根收分钢腿 → X 斜撑（2–3 层）→ 顶部平台 + 栏杆 → 旗语桅杆 + 2 片摆臂（留 0.15 m 间隙）→ 灯室 → 旗绳 → 底部工具柜 → 爬梯。
- 读感：必须是港口最高剪影；摆臂与桅杆之间要能透光，否则远看是一根柱。
- 坑：摆臂与桅杆共面是黑斑高发区；灯室不做透明玻璃，用黄铜框 + 深色面板。

### 3.5 `SN_Shipyard_Gantry`（船厂龙门吊）

- 结构：2 组 A 形腿 → 箱形主梁（下沿净高 ≥ 8.5 m）→ 小车 + 吊钩滑轮组（放在第 3/4 跨）→ 钢缆 2 根 → 横向斜撑 → 侧爬梯 → 小型操作平台。
- 读感：主梁要能“跨过一条船”；吊钩组偏离中心，3/4 视角才看得见。
- 坑：钢缆用细圆柱（≥ 20 mm），别用单面片；腿与地面接触处加底板，避免悬空。

### 3.6 `SN_Dry_Dock`（干船坞底座）

- 结构：3 级收分石砌坞壁（内壁台阶）→ 2 条滑道轨 → 5 组龙骨墩（间距 3 m，可复用 `SN_Keel_Block` 造型）→ 排水沟 → 两侧短石阶。
- 读感：坞壁台阶 + 滑道轨要能读出“干船坞”；龙骨墩中心线对齐，能承载 60 m 船体。
- 坑：坞壁与地面交界做 50 mm 倒角，避免 z-fighting；龙骨墩顶面高度统一。

## 4. 已有资产（不要重做）

| 用途 | 已有资产 |
| --- | --- |
| 货箱/木桶/麻袋/托盘 | `SN_Crate` `SN_Barrel` `SN_Sack_Pile` `SN_Pallet` |
| 煤/矿石/钢板/木料堆 | `SN_Coal_Pile` `SN_Ore_Pile` `SN_Plate_Stack` `SN_Timber_Stack` |
| 靠泊件 | `SN_Mooring_Bollard` `SN_Dock_Fender` `SN_Fender_Ball` `SN_Gangway` `SN_Dock_Ladder` `SN_Dock_Stairs` `SN_Buoy` |
| 装卸件 | `SN_Harbor_Crane` `SN_Grab_Bucket` `SN_Cargo_Net` `SN_Coal_Chute` `SN_Handcart` |
| 照明/标识/动力 | `SN_Gas_Lamp` `SN_Port_Sign` `SN_Bell` `SN_Flag_Pole` `SN_Steam_Pipe` `SN_Boiler_Unit` |
| 结构件 | `SN_Dock_Wall` `SN_Keel_Block` `SN_Capstan` `SN_Chain_Coil` |

## 5. 装配约定（PortStage）

- 舞台按 `facilities` 数据实例化锚点：`facilities` 里没有的设施**不得出现模型**，用通用岸线/货堆/空场填槽。
- 每个设施 = 1 个锚点 + 0–2 个辅助件（从第 4 节挑）+ 2D 热点；热点坐标由框架按设施槽位生成，不依赖模型细节。
- 港口差异只允许：`size`（槽位数量/尺度）、`palette`（材质色调）、`landmark`（每港最多 1 个定制件）、`facility_visuals`（设施换道具资产）。
- `size` 建议：small = 锚点 ×0.9、medium = ×1.0、large = ×1.15；锚点不单独缩放，缩放由舞台统一施加。
- LOD：每个锚点两级——L0 全模、L1 远景剪影（unshaded）；远景版本在导出时另存 `SN_<Name>_LOD1.glb`。
- 第三方 mod 只能通过 `facility_visuals` 换成白名单 GLB，不能新增设施类型或改布局。

## 6. 命名、导出与验收

```text
.design/port/SN_<Name>.blend                    源文件（本地，gitignore）
tools/modeling/generators/sn_port_facilities_generator.py   参数化生成器（入库）
assets/models/port/SN_<Name>.glb                运行时资产（进 res://）
docs/design/ASSET_MAP.md                        登记 6 行
```

- 对象命名 `SN_` 前缀；集合 `SN_Port_Facilities`；根空物体 `SN_<Name>_Root`（需要动画的摆臂/吊钩挂 Pivot）。
- 单位米、+X 朝前、+Z 向上；轴心统一在**底面中心**（`object.location` = 布局位置，几何局部坐标）。
- 导出前逐件把 `location` 临时归零，导出后还原；单个 `.glb` 只含一个网格节点。
- 验收：命名/集合/预算/原点/材质/包围盒误差 ≤ 0.1 m/网格健康/无文字/回归/3/4 视角可辨认。

## 7. 建议顺序

1. `SN_Dry_Dock` + `SN_Shipyard_Gantry`（船厂是当前唯一有 3D 舞台的页面，先补这组最有价值）
2. `SN_Market_Stall`（总览/市场舞台的主视觉锚点）
3. `SN_Water_Tank`（补给舞台）
4. `SN_Notice_Board` + `SN_Signal_Tower`（小件，可并到最后一批）

## 8. 已知坑（沿用铁港批次）

- Builder 不落盘：由 Lead 验收后保存工作台并导出 `.glb`。
- 铁箍/包角与木面共面 → 一律留 1–2 mm 凸出。
- 单层帆布/纸张/招牌 → 双面材质，否则背面透明或发黑。
- 细长件（旗绳、钢缆）用圆柱，不用单面片；否则侧看消失。
- 组件之间（爬梯 vs 筒壁、摆臂 vs 桅杆）先留缝再谈贴合，避免共面黑斑。
- 远景剪影版本单独导出，不在游戏里用 visibility_range 缩模。
