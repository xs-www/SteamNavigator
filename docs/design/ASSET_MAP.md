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
| `.design/SN_Asset_Workbench.blend`（`SN_Paddle_Freighter_Prototype` 集合）+ `.design/ships/SN_Paddle_Freighter.blend` | `assets/models/ships/SN_Paddle_Freighter.glb` | 大型明轮蒸汽货轮：**59.53 × 14.10 × 19.52 m**（船体 LOA 55 m，总长含艏斜桁）、**12200 三角面**、46 对象（39 mesh + 7 empty）、6 材质（`SN_Iron_Hull` / `SN_Iron_Red` / `SN_Brass` 新增，复用 `SN_Wood` / `SN_Wood_Deck` / `SN_Metal`）。双明轮（14 桨叶 / 每侧 8 辐条 / 16 段双轮缘 + 内加强环 + 黄铜轮缘条 + 4 斜撑）、半包轮罩箱板（-6°..186° + 中央观察窗 + 黄铜包边 / 铭牌，端封 r_in 2.75 避让轮扫掠、内板窗 2.30 避让蒸汽管）、双后倾烟囱、锅炉机舱围罩 + 蒸汽管、桥楼 + 驾驶室、4 货舱口 + 4 吊杆、双桅横桁 + 艏斜桁、艏楼 / 艉楼侧封板、吊艇架救生艇、舵轮 / 旗；根节点 `SN_PF_Root` 水线轴心、工作台摆位 (-45, 0, 0)；2 个明轮 Pivot + 4 个 `SN_Socket_*` |
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
| `tools/modeling/briefs/sn_paddle_freighter.json` | — | 明轮货轮工单（人工选定明轮船型 + 船长 55 m，二次追加「明轮补轮缘/辐条/桨叶 + 轮罩半包」；14000 tri 预算、6 材质、15 对零交面 + 明轮 8 旋转角 0 穿模验收） |
| `tools/modeling/generators/sn_paddle_freighter_generator.py` | — | 明轮货轮参数化生成器（`STATIONS` / `PROFILE` / `PADDLE` / `PADDLE_BOX` / `FUNNELS` / `MASTS` / `HATCHES` / `BOOMS` / `DECKHOUSE` 参数表；纯几何函数 + Blender 装配 + `report()`） |
| `tools/modeling/generators/dryrun_ship.py` | — | 船舶生成器纯 Python 干跑：tri / 包围盒 / 边界边 / 非流形边 / 退化面 / 命名 / 父级键 / 明轮 Pivot 归属 |
| `tools/modeling/generators/export_ship_glb.py` | — | 船舶归档：备份旧 GLB → 保存工作台 → 根节点归零导出 GLB → `bpy.data.libraries.write` 船体快照 → 还原根节点 |
| `tools/modeling/generators/verify_ship_glb.py` | — | GLB 结构自检：节点 / 网格 / 材质 doubleSided / 三角面 / 世界包围盒（Y-up） |
| `tools/godot/verify_props.gd` | — | GLB 导入验收（只读）：核对 Godot 侧包围盒、三角面与材质名，专抓"改了 .blend 忘了重导 GLB" |
| `tools/modeling/briefs/sn_iron_harbor_batch1.json` | — | 铁港第一批批量工单（6 件一次派发）；系缆桩尺寸在 P0 整改中改为 0.62 × 0.62 × 0.70 |
| `tools/modeling/briefs/sn_iron_harbor_batch2.json` | — | 铁港第二批批量工单（6 件，y=30 一排，预算 1900 tri） |

> `.design/SN_Asset_Workbench.blend` 是当前主场景；`.design/ships/SN_Ship_Prototype.blend` 是帆船的独立快照，`.design/ships/SN_Paddle_Freighter.blend` 是明轮货轮的独立快照（`bpy.data.libraries.write` 只打包该集合 46 对象，轴心水线、不切换当前文件）。新增资产一律进工作台的新集合，交付时按集合导出独立 `.glb`。

- 轴向：Blender 中 +X 为船首、+Z 向上；glTF 导出后 +Y 向上，进入 Godot 需绕 Y 轴 +90° 才对齐引擎的 −Z 前方。
- 轴心：船体中部水线，1 unit = 1 m，可直接按水面高度摆放。
- 帆为单层平面，材质必须双面（glTF 已标 `doubleSided`）；其余单层曲面（甲板 / 舷墙 / 腰板）也保持双面，后续可按材质开启背面剔除。
- `.blend` 按本文件第 5 行决策留在 `.design/`（gitignore，不进构建）；只有 `.glb` 进入运行时资源。

## 3D 港口样片（水面着色器试做）

独立场景 `dev_scenes/harbor/harbor_diorama.tscn`，不接入主流程；只用已有 GLB 资产 + 场景内程序化 BoxMesh 剪影。

| 运行时路径 | 说明 |
| --- | --- |
| `assets/shaders/water/harbor_water.gdshader` | 港口水面 shader：顶点波浪、噪声法线、菲涅耳反射、太阳耀斑、岸线/船体泡沫、远水雾色 |
| `assets/materials/water/harbor_water.tres` | 近处主水面材质（波浪/泡沫/太阳方向实际生效值） |
| `assets/materials/water/harbor_water_far.tres` | 远处水面材质：同一 shader，关闭波浪/细节/泡沫，只输出地平线雾色 |
| `assets/textures/water/water_normal.png` | 烘焙的无缝水面法线噪声（512²） |
| `assets/textures/water/water_foam.png` | 烘焙的无缝泡沫噪声（512²） |
| `dev_scenes/harbor/bobbing_boat.gd` | 浮船：采样与 shader 同源的波浪 |
| `docs/design/screenshots/harbor_diorama_dusk.png` | 样片黄昏机位截图（1440×900） |
| `docs/design/screenshots/harbor_diorama_detail.png` | 近景水面 / 船体截图（1440×900） |

`dev_scenes/harbor/README.md` 记录运行方式、调参入口与已知边界；`tools/godot/verify_harbor_diorama.gd` 是无头验收脚本。

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
