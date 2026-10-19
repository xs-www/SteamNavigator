# Asset Map

## 决策

- `.design/` 继续作为**本地美术原型/源文件**，由 `.gitignore` 排除，不参与构建。
- 全局表现层资源进入 `assets/`（`res://assets/...`）。
- 内容专属资源进入 `dev_mods/core/assets/`，由 Core 模组 manifest 声明。
- 音频按用途分 `ui/`、`economy/`、`music/`。

## 本次落地

| 来源 | 运行时路径 | 说明 |
| --- | --- | --- |
| `.design/assets/main-menu-harbor.png` | `assets/ui/banners/main_menu_harbor.png` | 主菜单背景，1672×941 |
| `.design/assets/iron-harbor-banner.png` | `dev_mods/core/assets/ports/iron_harbor_banner.png` | 铁港横幅，2172×724；manifest 键 `banner.port.iron_harbor` |
| `.design/tokens.json` | `assets/ui/tokens.json` | UI token |
| `270408__littlerobotsoundfactory__pickup_gold_00.wav` | `assets/audio/sfx/economy/pickup_gold_00.wav` | 购买/金币音效 |

## 3D 资产

| 来源（本地源文件） | 运行时路径 | 说明 |
| --- | --- | --- |
| `.design/ships/SN_Ship_Prototype.blend` | `assets/models/ships/SN_Ship_Prototype.glb` | 低多边形帆船原型；2608 三角面、36 节点、5 种材质（木 / 深木 / 甲板木 / 帆布 / 金属） |
| `.design/ships/sn_ship_prototype_generator.py` | — | 帆船参数化生成脚本；改 `STATIONS` / `MASTS` 表即可生成不同吨位船体 |
| `.design/SN_Asset_Workbench.blend` | `assets/models/props/SN_Harbor_Crane.glb` | 工作台主场景（帆船 36 对象 + 塔吊 34 对象 + 相机/灯光）；锤头式塔吊 3420 三角面、34 节点、4 材质（木 / 深木 / 金属 / 石材），主臂 20 m 水平、总高 21.5 m，场景摆放 (0, 16, 0) |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合） | `assets/models/props/` 下 6 个独立 `.glb` | 铁港码头第一批小部件：石砌岸壁 `SN_Dock_Wall` / 木护舷 `SN_Dock_Fender` / 系缆桩 `SN_Mooring_Bollard` / 木箱 `SN_Crate` / 木桶 `SN_Barrel` / 矿石堆 `SN_Ore_Pile`；P0 整改后合计 **1360 三角面**，材质 `SN_Ore` 已改为锈红铁矿色 |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合，第二批） | `assets/models/props/` 下 6 个独立 `.glb` | 铁港第二批：煤气灯 `SN_Gas_Lamp` / 船岸跳板 `SN_Gangway` / 双瓣抓斗 `SN_Grab_Bucket` / 煤堆 `SN_Coal_Pile` / 码头爬梯 `SN_Dock_Ladder` / 钢板堆 `SN_Plate_Stack`；合计 **1214 三角面**，新增材质 `SN_Coal`（base 0.020/0.019/0.018、rough 0.95、metallic 0） |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合，第三批） | `assets/models/props/` 下 6 个独立 `.glb` | 铁港第三批（堆场 / 管线）：木料堆 `SN_Timber_Stack` / 麻袋堆 `SN_Sack_Pile` / 蒸汽管段 `SN_Steam_Pipe` / 缆绳卷 `SN_Mooring_Rope` / 吊货网 `SN_Cargo_Net` / 托盘 `SN_Pallet`；合计 **1024 三角面**，不新增材质 |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合，第四批） | `assets/models/props/` 下 6 个独立 `.glb` | 铁港第四批（机械 / 水上件）：浮标 `SN_Buoy` / 锚链堆 `SN_Chain_Coil` / 手动绞盘 `SN_Capstan` / 平板手推车 `SN_Handcart` / 圆形碰垫 `SN_Fender_Ball` / 精密齿轮箱 `SN_Gear_Crate`；合计 **1452 三角面**，不新增材质。齿轮箱对应 Core 的 `precision_gear` 商品，可作市场货台道具 |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合，第五批） | `assets/models/props/` 下 7 个独立 `.glb` | 铁港第五批（结构 / 标识 / 动力）：码头石阶 `SN_Dock_Stairs` / 港口牌 `SN_Port_Sign` / 港口钟 `SN_Bell` / 旗杆 `SN_Flag_Pole` / 煤溜槽 `SN_Coal_Chute` / 锅炉机组 `SN_Boiler_Unit` / 龙骨墩 `SN_Keel_Block`；合计 **1232 三角面**，不新增材质。锅炉与煤溜槽是同批最重的两件 |
| `tools/modeling/generators/sn_iron_harbor_batch5_generator.py` | — | 第五批参数化生成器（自带几何工具函数，单文件可执行） |
| `tools/modeling/generators/sn_iron_harbor_batch4_generator.py` | — | 第四批参数化生成器（自带几何工具函数，单文件可执行） |
| `tools/modeling/generators/sn_iron_harbor_batch3_generator.py` | — | 第三批参数化生成器（自带几何工具函数，单文件可执行） |
| `tools/modeling/generators/sn_iron_harbor_batch2_generator.py` | — | 第二批参数化生成器：6 件的尺寸/分段/材质全部由顶部参数表生成，改数值即可重建 |
| `tools/modeling/generators/sn_mooring_bollard_generator.py` | — | 系缆桩参数化生成器：PLATE（方形法兰板）/ BOLTS（四角六角螺栓）/ SHAFT（喇叭脚 + 粗柱身）/ ARM（圆柱十字横臂）四张参数表，改数值即可重建 |
| `tools/modeling/generators/dryrun_props.py` | — | 通用纯 Python 干跑：传生成器路径即可离线校验 tri 预算 / 包围盒 / 边界边 / 非流形边 / 退化面 |
| `tools/modeling/generators/dryrun_batch2.py` | — | 第二批专用干跑（通用版 dryrun_props.py 的前身，保留兼容） |
| `tools/modeling/generators/p0_rework_2026-10-19.py` | — | 第一批 P0 整改脚本：重建系缆桩 → `SN_Ore` 改锈红 → 三段岸壁拼接测试（临时对象验收后清理） |
| `tools/modeling/generators/p0_finalize.py` | — | P0 归档脚本：备份旧 GLB → 清临时对象 → 导出 → 保存工作台 |
| `tools/modeling/generators/export_props_glb.py` | — | 道具 GLB 导出：逐件把 `location` 临时归零、只导出选中对象、导出后还原；单节点 / 轴心在底面中心 |
| `tools/godot/verify_props.gd` | — | GLB 导入验收（只读）：核对 Godot 侧包围盒、三角面与材质名，专抓"改了 .blend 忘了重导 GLB" |
| `tools/modeling/briefs/sn_iron_harbor_batch1.json` | — | 铁港第一批批量工单（6 件一次派发）；系缆桩尺寸在 P0 整改中改为 0.62 × 0.62 × 0.70 |
| `tools/modeling/briefs/sn_iron_harbor_batch2.json` | — | 铁港第二批批量工单（6 件，y=30 一排，预算 1900 tri） |

> `.design/SN_Asset_Workbench.blend` 是当前主场景；`.design/ships/SN_Ship_Prototype.blend` 是帆船的独立快照。新增资产一律进工作台的新集合，交付时按集合导出独立 `.glb`。

- 轴向：Blender 中 +X 为船首、+Z 向上；glTF 导出后 +Y 向上，进入 Godot 需绕 Y 轴 +90° 才对齐引擎的 −Z 前方。
- 轴心：船体中部水线，1 unit = 1 m，可直接按水面高度摆放。
- 帆为单层平面，材质必须双面（glTF 已标 `doubleSided`）；其余单层曲面（甲板 / 舷墙 / 腰板）也保持双面，后续可按材质开启背面剔除。
- `.blend` 按本文件第 5 行决策留在 `.design/`（gitignore，不进构建）；只有 `.glb` 进入运行时资源。

## 为什么这样分

- 主菜单背景属于**框架表现层**，所有内容包共用。
- 铁港横幅属于**港口内容**，未来可能随模组/港口扩展，放在 Core 资产目录。
- 购买音效是**通用经济反馈**，不绑定具体港口或商品。
- `.design` 里的 HTML/CSS/JS 是原型，不直接进入 Godot 导出包。

## 明天 UI 更新的入口

1. `assets/ui/theme/steam_navigator_theme.tres`（待建）
2. `assets/ui/tokens.json`
3. `assets/ui/banners/main_menu_harbor.png`
4. `assets/audio/sfx/economy/pickup_gold_00.wav`
5. `dev_mods/core/assets/ports/iron_harbor_banner.png`

所有路径均以 `res://` 开头在 Godot 中使用。

## 后续界面重构

市场、委托、补给与船厂的页面骨架、组件拆分、ViewModel 建议和验收标准见 [高频决策页面重构指南](HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md)。
