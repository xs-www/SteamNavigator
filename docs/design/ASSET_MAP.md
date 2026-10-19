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

## UI 贴图：船厂纵剖图与船卡缩略图

船厂改装态与正常态船卡使用两张**可替换的框架表现层贴图**（不是 Core 内容资源，不注册 `information.texture`）：

| 运行时路径 | 尺寸 | 用途 | 替换 / 生成 |
| --- | --- | --- | --- |
| `assets/ui/shipyard/ship_section.png` | 1792×1008（16:9） | 改装态纵剖图整幅背景；槽位贴片与引线由 `SNShipView` 叠加 | `python tools/art/gen_shipyard_textures.py`；也可手绘替换 |
| `assets/ui/shipyard/ship_thumb_ironclad.png` | 640×360 | 正常态「已有船舶」船卡缩略图（210×118 cover 区域） | 同上；`--thumb-only` 只重导缩略图 |

- 两张图由 `tools/art/gen_shipyard_textures.py` 确定性生成（Pillow + numpy，几何 / 配色 / 构图锚点都在文件顶部常量表）。改构图后重跑即可，不要手改像素。
- 纵剖图构图锚点（`ANCHORS`，画布比例）：明轮 0.108/0.590、锅炉 0.345/0.552、货舱 0.545/0.578、安全 0.674/0.330、导航 0.756/0.340、客舱 0.854/0.340；甲板 / 龙骨 / 水线约 0.400 / 0.782 / 0.675。这些比例要与 `framework/ui/components/sn_ship_view.gd` 的 `_chip_anchor()` 一起改，否则槽位引线会指错舱室。
- 替换贴图时保持 16:9（或同时调整 `sn_ship_view.gd` 的槽位行 `h*0.60` / `h*0.82` 与锚点），并让 Godot 重新导入生成 `.import`；缺失时 `SNShipView` 自动回退程序化剖面，船卡回退占位面板。
- 两张图都属于框架表现层（`assets/ui/`），不进入 Core 模组包，也不参与 mod 资源校验。

## 3D 资产

| 来源（本地源文件） | 运行时路径 | 说明 |
| --- | --- | --- |
| `.design/ships/SN_Ship_Prototype.blend` | `assets/models/ships/SN_Ship_Prototype.glb` | 低多边形帆船原型；2608 三角面、36 节点、5 种材质（木 / 深木 / 甲板木 / 帆布 / 金属） |
| `.design/ships/sn_ship_prototype_generator.py` | — | 帆船参数化生成脚本；改 `STATIONS` / `MASTS` 表即可生成不同吨位船体 |
| `.design/SN_Asset_Workbench.blend`（`SN_Paddle_Freighter_Prototype` 集合）+ `.design/ships/SN_Paddle_Freighter.blend` | `assets/models/ships/SN_Paddle_Freighter.glb` | 大型明轮蒸汽货轮：**59.53 × 14.10 × 19.52 m**（船体 LOA 55 m，总长含艏斜桁）、**12200 三角面**、46 对象（39 mesh + 7 empty）、6 材质（`SN_Iron_Hull` / `SN_Iron_Red` / `SN_Brass` 新增，复用 `SN_Wood` / `SN_Wood_Deck` / `SN_Metal`）。双明轮（14 桨叶 / 每侧 8 辐条 / 16 段双轮缘 + 内加强环 + 黄铜轮缘条 + 4 斜撑）、半包轮罩箱板（-6°..186° + 中央观察窗 + 黄铜包边 / 铭牌，端封 r_in 2.75 避让轮扫掠、内板窗 2.30 避让蒸汽管）、双后倾烟囱、锅炉机舱围罩 + 蒸汽管、桥楼 + 驾驶室、4 货舱口 + 4 吊杆、双桅横桁 + 艏斜桁、艏楼 / 艉楼侧封板、吊艇架救生艇、舵轮 / 旗；根节点 `SN_PF_Root` 水线轴心、工作台摆位 (-45, 0, 0)；2 个明轮 Pivot + 4 个 `SN_Socket_*` |
| `.design/SN_Asset_Workbench.blend`（`SN_Ironclad_Prototype` 集合）+ `.design/ships/SN_Ironclad.blend` | `assets/models/ships/SN_Ironclad.glb` | 舷侧炮铁甲舰：**60.14 × 18.00 × 28.64 m**（水线轴心，z -4.2..24.44）、**8830 三角面**、单 mesh / 8 材质；装甲带 + 板缝、每舷 6 门英雄化舷侧炮（炮门 1.9×1.9 m / 炮管 Ø0.88→0.72 m / 外露 1.55 m）+ 2 门艏 pivot 炮、2.2 m 装甲带（外凸 380 mm）与 120 mm 板缝、中央装甲炮房 + 指挥塔、双后倾烟囱、三桅横桁收帆 + 艏斜桁基座、锚吊架、撞角艏、艉廊、螺旋桨/舵；单节点 GLB、工作台摆位 (0, 90, 0) |
| `.design/SN_Asset_Workbench.blend`（`SN_Paddle_Steamer_Prototype` 集合）+ `.design/ships/SN_Paddle_Steamer.blend` | `assets/models/ships/SN_Paddle_Steamer.glb` | 小型澳洲明轮蒸汽客船（参考 PS Enterprise）：**24.56 × 8.74 × 10.47 m**（LOA 24.0 m，水线轴心 z=0）、**11764 三角面**、35 对象（32 mesh + 3 empty）、8 材质（新增 `SN_White` / `SN_Flag_Blue` / `SN_Flag_White`，复用 5）；白漆双层船身 + 暗红水线/舷缘压条 + 深色船底、两舷 10 桨叶明轮（14 段双轮缘 / 8 辐条 / 内加强环 / 黄铜轮缘条 / 4 斜撑）+ 10 道水平格栅轮罩、前驾驶室（双侧 ENTERPRISE 文字铭牌）、后部白色立柱雨棚游步甲板、黑烟囱 + 黄铜箍/红顶圈、锅炉围罩 + 黄铜蒸汽管、艏旗杆澳洲旗、艉部弧形低平台 + 舵；**不含蒸汽几何**（留给游戏内 VFX）；根节点 `SN_PS_Root` 工作台摆位 (45, 0, 0) |
| `.design/SN_Asset_Workbench.blend`（`SN_Schooner_Fame_Prototype` 集合）+ `.design/ships/SN_Schooner_Fame.blend` | `assets/models/ships/SN_Schooner_Fame.glb` | 1795 年 Salem 双桅纵帆船 **SN_Schooner_Fame**：**33.44 × 6.88 × 26.82 m**（船体 LOA 24.4 m，总长含艏斜桁/艏三角帆）、**13174 三角面**、32 对象（29 mesh + 3 empty）、12 材质（新增 `SN_Hull_Black` / `SN_Ochre` / `SN_Canvas_Shade` / `SN_Flag_Red`，复用 8）；18 站放样黑船身 + 赭黄上舷带 + 黑腰板/压顶、艉楼甲板；双桅后倾（Fore −2.5° / Main −3.2°，轴距 6.4 m）、前桅斜桁帆 + 方顶帆、主桅大斜桁帆 + 三角顶帆、两面艏三角帆（jib + fore staysail）、舷侧绳梯（shrouds + ratlines）/支索/动索、艉廊 3 蓝窗 + 双灯 + FAME 铭牌、舱口格栅/绞盘/起锚机/舵轮/罗经柜/锚/钟/木桶/盘绳/fife rails/短梯/艏饰；**无星条旗**（用户 2026-10-19 要求移除，仅保留主桅顶红白长旒）；帆腹镜像朝 −Y（Godot +Z 相机侧）；根节点 `SN_SF_Root` 水线轴心、工作台摆位 (0, −70, 0) |
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
| `tools/modeling/briefs/sn_ironclad_broadside.json` | — | 舷侧炮铁甲舰工单（60 m 级、12000 tri、8 材质、水线轴心、纯展示资产） |
| `tools/modeling/generators/sn_ironclad_generator.py` | — | 铁甲舰参数化生成器（`STATIONS` / `GUN_X` / `MASTS` / `FUNNELS` 参数表；船体放样 + 装甲带 + 炮列 + 炮房/烟囱 + 三桅 + 甲板件，单 mesh 装配 + `report()`） |
| `tools/modeling/generators/dryrun_ironclad.py` | — | 铁甲舰纯 Python 干跑：tri / 包围盒（水线轴心）/ z 范围 / 边界边 / 非流形边 / 退化面 / 孤立点 / 材质 |
| `tools/modeling/generators/render_ironclad_preview.py` | — | 铁甲舰预览渲染：3/4 / 正侧 / 舰艏 / 舰艉 3/4 四视角 |
| `tools/modeling/generators/export_ironclad_glb.py` | — | 铁甲舰归档：备份旧 GLB → 轴心归零导出 → `bpy.data.libraries.write` 单对象快照 |
| `tools/modeling/generators/verify_ironclad_glb.py` | — | 铁甲舰 GLB 结构自检：单节点 / 8 图元 / 8830 tri / 材质 / Y-up 包围盒 / z 范围 |
| `tools/modeling/generators/check_ironclad_connectivity.py` | — | 铁甲舰连通性检查（只读）：拆连通岛 + BVH 三角面相交/最近距离，抓 `revolved()` 忘 translate、小艇漏偏移等"悬空/错位" |
| `tools/modeling/briefs/sn_ship_paddle_steamer.json` | — | 小型明轮蒸汽船工单（24.4×8.7×10.5 m、12000 tri、8 材质、明轮 10 桨叶 / 10 道格栅、ENTERPRISE 铭牌；明确蒸汽不建模，明轮 8 旋转角零穿模） |
| `tools/modeling/generators/sn_paddle_steamer_generator.py` | — | 明轮蒸汽船参数化生成器（`STATIONS` / `PROFILE` / `PADDLE` / `PADDLE_BOX` / `WHEELHOUSE` / `CANOPY` / `FLAG` 参数表；纯几何 + Blender 装配 + 文字铭牌 + `report()`） |
| `tools/modeling/generators/dryrun_paddle_steamer.py` | — | 明轮蒸汽船纯 Python 干跑：tri / 包围盒 / z 范围 / 边界边 / 非流形边 / 退化面 / 孤立点 / 材质 / 父级 / 左右镜像误差 |
| `tools/modeling/generators/render_paddle_steamer_preview.py` | — | 明轮蒸汽船预览渲染：3/4、正侧、艏、艉 3/4、俯视；临时双太阳/水面，渲后还原场景 |
| `tools/modeling/generators/verify_paddle_steamer_scene.py` | — | 明轮蒸汽船场景只读验收：命名/层级/Pivot/网格健康/明轮 8 旋转角世界坐标 BVH 交面/左右镜像/连通岛悬空/工作台回归，输出 JSON |
| `tools/modeling/generators/export_paddle_steamer_glb.py` | — | 明轮蒸汽船 GLB 归档：备份旧 GLB → 保存工作台 → 轴心归零导出 → `libraries.write` 快照 → 还原摆位 |
| `tools/modeling/generators/verify_paddle_steamer_glb.py` | — | 明轮蒸汽船 GLB 结构自检：35 节点 / 32 网格 / 8 doubleSided 材质 / 11764 tri / Y-up bbox / 水线 −1.32，并拒绝蒸汽节点 |
| `tools/modeling/briefs/sn_schooner_fame.json` | — | 1795 双桅纵帆船工单：船体 LOA 24.4 m / 总长 33.44 m / 总高 26.82 m、≤18000 tri、12 材质；双桅后倾 / 斜桁帆 / 方顶帆 / 艏三角帆 / 完整索具 / 艉廊 FAME 铭牌；用户明确不要星条旗，只保留红白长旒 |
| `tools/modeling/generators/sn_schooner_fame_generator.py` | — | 纵帆船参数化生成器（`STATIONS` / `PROFILE` / `MASTS` / `FORE_SAIL` / `MAIN_SAIL` / `FORE_TOPSAIL` / `MAIN_TOPSAIL` 参数表；18 站放样 + 斜桁帆曲面 + 三角帆 + 索具 + 甲板属具 + 艉廊 + 文字铭牌 + `report()`） |
| `tools/modeling/generators/ship_parts/` | — | **可复用船体部件库 v1**：`core`（Part/基本体/PartSpec）/ `deck`（舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯）/ `bow`（艏斜桁/jibboom/艏饰）/ `stern`（艉廊/艉窗/艉灯）/ `assembly`（集合/材质/Pivot/文字/report）/ `palette`；生成器只保留船型布局，重构后纵帆船逐对象 digest 不变 |
| `tools/modeling/generators/ship_parts/README.md` | — | 部件库契约：分层、`PartSpec`、新增部件步骤、坐标/材质约定、输出不变的验收口径 |
| `tools/modeling/generators/dryrun_schooner_fame.py` | — | 纵帆船纯 Python 干跑：对 FORE/MAIN 子件施加 Pivot 世界变换后核对 tri / bbox / 边界边 / 非流形 / 退化 / 孤立点 / 材质 / 命名 / 父级，并断言两桅轴距 6.4 m、后倾与主桅更高 |
| `tools/modeling/generators/export_schooner_fame_glb.py` | — | 纵帆船 GLB 归档：备份旧 GLB → 保存工作台 → 根节点归零导出 → `libraries.write` 快照 → 还原 (0, −70, 0) |
| `tools/modeling/generators/verify_schooner_fame_glb.py` | — | 纵帆船 GLB 结构自检：32 节点 / 29 网格 / 12 doubleSided 材质 / 13174 tri / Y-up bbox 33.44×26.85×6.88 / 水线轴心 −2.74 |
| `tools/modeling/generators/render_schooner_fame_preview.py` | — | 纵帆船预览渲染：3/4、正侧、艏 3/4、艉 3/4、俯视 5 张；临时相机/太阳/水面，渲后还原场景 |
| `tools/godot/verify_props.gd` | — | GLB 导入验收（只读）：核对 Godot 侧包围盒、三角面与材质名，专抓"改了 .blend 忘了重导 GLB" |
| `tools/modeling/briefs/sn_iron_harbor_batch1.json` | — | 铁港第一批批量工单（6 件一次派发）；系缆桩尺寸在 P0 整改中改为 0.62 × 0.62 × 0.70 |
| `tools/modeling/briefs/sn_iron_harbor_batch2.json` | — | 铁港第二批批量工单（6 件，y=30 一排，预算 1900 tri） |

> `.design/SN_Asset_Workbench.blend` 是当前主场景；`.design/ships/SN_Ship_Prototype.blend` 是旧帆船原型的独立快照，`.design/ships/SN_Schooner_Fame.blend` 是 1795 双桅纵帆船的独立快照（32 对象，轴心水线），`.design/ships/SN_Paddle_Freighter.blend` 是明轮货轮的独立快照（`bpy.data.libraries.write` 只打包该集合 46 对象，轴心水线、不切换当前文件），`.design/ships/SN_Paddle_Steamer.blend` 是小型明轮蒸汽船的独立快照（35 对象）。新增资产一律进工作台的新集合，交付时按集合导出独立 `.glb`。

- 轴向：Blender 中 +X 为船首、+Z 向上；glTF 导出后 +Y 向上，进入 Godot 需绕 Y 轴 +90° 才对齐引擎的 −Z 前方。
- 轴心：船体中部水线，1 unit = 1 m，可直接按水面高度摆放。
- 帆为单层平面，材质必须双面（glTF 已标 `doubleSided`）；其余单层曲面（甲板 / 舷墙 / 腰板）也保持双面，后续可按材质开启背面剔除。
- `.blend` 按本文件第 5 行决策留在 `.design/`（gitignore，不进构建）；只有 `.glb` 进入运行时资源。

## 3D 资产：舷侧炮铁甲舰（SN_Ironclad）

1860 年代舷侧炮铁甲舰，60 m 级纯展示资产（不接入 Core 内容键）。单 mesh / 8 材质槽，轴心在水线中心（x=0 船中、z=0 水线、+X 船首），工作台摆位 (0, 90, 0)：

| 项 | 数值 |
| --- | --- |
| 包围盒 | **60.14 × 18.00 × 28.64 m**（LOA 含艏斜桁与艉廊；z -4.20 .. 24.44） |
| 三角面 | **8830 / 12000** |
| 材质 | Iron_Hull / Iron_Red / Wood_Deck / Wood / Wood_Dark / Metal / Brass / Canvas（复用既有调色板，不新增） |
| 结构 | 17 站放样铁壳 + 撞角艏；**英雄化装甲带**（2.2 m 高、外凸 380 mm、120 mm 竖向板缝/黄铜压条）；**每舷 6 门英雄化舷侧炮**（炮门 1.9×1.9 m、炮管 Ø0.88→0.72 m、外露 1.55 m、炮口箍 Ø1.0 m、上翻炮门盖、前外张 12°）+ 2 门放大艏 pivot 炮；中央装甲炮房 + 指挥塔 + 艏驾驶台；双后倾烟囱 + 通风筒 + 天窗；三桅横桁（收帆卷）+ 艏斜桁 + 支索/侧支索；舷墙 + 黄铜压条；舱口格栅/绞盘/舵轮/罗经柜/小艇/锚（吊架）/螺旋桨/舵/艉廊/旗 |
| 运行时 GLB | `assets/models/ships/SN_Ironclad.glb`（单节点 / 8 图元 / 约 468 KB / glTF Y-up，轴心水线中心） |
| 源文件 | `.design/SN_Asset_Workbench.blend`（`SN_Ironclad_Prototype` 集合）+ `.design/ships/SN_Ironclad.blend`（单对象快照） |
| 工单/脚本 | `briefs/sn_ironclad_broadside.json`、`sn_ironclad_generator.py`、`dryrun_ironclad.py`、`check_ironclad_connectivity.py`、`render_ironclad_preview.py`、`export_ironclad_glb.py`、`verify_ironclad_glb.py` |
| 截图 | `docs/design/screenshots/ironclad_{three_quarter,broadside,bow,bow_closeup,guns_closeup,stage_ortho}.png` |

> 纯展示资产：核心玩法仍使用现有 4 种船体；若将来把铁甲舰作为第 5 种船体或港口战舰接入，需要补内容 JSON、manifest 资源键、本地化与测试。

## 3D 资产：小型明轮蒸汽船（SN_Paddle_Steamer）

参考澳大利亚国家博物馆的明轮蒸汽船 **PS Enterprise**（堪培拉伯利·格里芬湖）的小型公开甲板客船，24 m 级纯展示资产（不接入 Core 内容键）。轴心在船体中部水线（x=0 船中、z=0 水线、+X 船首），工作台摆位 (45, 0, 0)：

| 项 | 数值 |
| --- | --- |
| 包围盒 | **24.56 × 8.74 × 10.47 m**（LOA 24.0 m，总宽含轮罩，总高含烟囱顶；z -1.32 .. 9.15） |
| 三角面 | **11764 / 12000** |
| 材质 | `SN_White` / `SN_Iron_Hull` / `SN_Iron_Red` / `SN_Wood_Deck` / `SN_Metal` / `SN_Brass` / `SN_Flag_Blue` / `SN_Flag_White`（新增 3 个，复用 5 个） |
| 结构 | 16 站放样白漆船身 + 深色水线以下船底 + 暗红压条；两舷 10 桨叶明轮（14 段双轮缘 / 每侧 8 辐条 / 内加强环 / 黄铜轮缘条 / 4 斜撑 / 曲柄销）+ 梯形格栅轮罩（10 道水平格栅 + 深色内衬 + 暗红顶沿 + 黄铜铭牌）+ 明轮台走台/栏杆；主甲板客舱（白墙 + 玻璃窗 + 黄铜窗台 + 木门）、游步甲板 + 白色立柱雨棚 + 前后栏杆；前驾驶室（三面窗 + 顶板 + 双侧 `ENTERPRISE` 文字铭牌 + 黄铜钟）；锅炉围罩 + 黑烟囱（黄铜箍 / 暗红顶圈）+ 黄铜蒸汽管；艏旗杆 + 澳洲旗（蓝底 / 白十字 / 红星 / 南十字星）、艏部锚/绞盘/系缆桩、艉部弧形低平台 + 栏杆 + 舵/舵柄 + 救生圈/卷缆 |
| 蒸汽 | **不建模**：烟囱蒸汽由游戏内粒子/VFX 渲染（用户 2026-10-19 明确要求） |
| 运行时 GLB | `assets/models/ships/SN_Paddle_Steamer.glb`（35 节点 / 32 网格 / 11764 tri / 8 材质 doubleSided / 632.7 KB / glTF Y-up，轴心水线 z=0） |
| 源文件 | `.design/SN_Asset_Workbench.blend`（`SN_Paddle_Steamer_Prototype` 集合，工作台 196 对象）+ `.design/ships/SN_Paddle_Steamer.blend`（35 对象独立快照） |
| 工单/脚本 | `briefs/sn_ship_paddle_steamer.json`、`sn_paddle_steamer_generator.py`、`dryrun_paddle_steamer.py`、`render_paddle_steamer_preview.py`、`verify_paddle_steamer_scene.py`、`export_paddle_steamer_glb.py`、`verify_paddle_steamer_glb.py` |
| 截图 | `docs/design/screenshots/paddle_steamer_{three_quarter,broadside,bow,stern_quarter,top}.png` |

> 纯展示资产：若将来作为第 5 种船体 / 内河客运场景接入，需要补 Core 内容 JSON、manifest 资源键、本地化、Godot 导入验收与 2.5D 舞台目标机位试装。明轮几何挂在 `SN_PS_Paddle_*_Pivot` 下，可直接绕 Y 轴做旋转动画；蒸汽建议在 Godot 侧用烟囱顶 `SN_PS_Funnel` 作为发射点做粒子。

## 3D 船舶模块（11 件）

`SN_Ship_Modules` 集合把 Core 里除船体外的全部模块实体做成独立可摆放的 3D 件：锅炉 3、货舱 3、导航 2、安全 2、客舱 1，合计 **7016 三角面**。每件一个 mesh 对象、3–6 个既有调色板材质槽、原点在底面中心（1 unit = 1 m，+X 为前向），导出为 `assets/models/modules/` 下的独立 `.glb`（单节点 / glTF Y-up），可直接按槽位摆到船体或舞台 socket 上。

| Core 模块实体 | 运行时 GLB | 尺寸 L×W×H (m) | tri | 主要材质 |
| --- | --- | ---: | ---: | --- |
| `core:boiler/small_efficient` | `assets/models/modules/SN_Boiler_Efficient.glb` | 1.81 × 1.60 × 2.60 | 540 | Wood_Dark / Metal / Iron_Hull / Brass |
| `core:boiler/standard` | `assets/models/modules/SN_Boiler_Standard.glb` | 2.82 × 1.90 × 2.62 | 860 | Wood_Dark / Metal / Iron_Hull / Brass |
| `core:boiler/performance` | `assets/models/modules/SN_Boiler_Performance.glb` | 3.40 × 2.11 × 2.94 | 1152 | Wood_Dark / Metal / Iron_Hull / Brass |
| `core:cargo_module/small_hold` | `assets/models/modules/SN_Cargo_Small_Hold.glb` | 2.40 × 2.00 × 1.80 | 456 | Wood / Wood_Dark / Metal / Brass |
| `core:cargo_module/medium_hold` | `assets/models/modules/SN_Cargo_Medium_Hold.glb` | 3.20 × 2.40 × 2.20 | 492 | Wood / Wood_Dark / Metal / Brass |
| `core:cargo_module/large_hold` | `assets/models/modules/SN_Cargo_Large_Hold.glb` | 4.01 × 2.81 × 2.60 | 672 | Wood / Wood_Dark / Metal / Brass |
| `core:navigation_module/spyglass` | `assets/models/modules/SN_Nav_Spyglass.glb` | 1.38 × 0.80 × 1.75 | 328 | Brass / Metal / Wood_Dark / Wood |
| `core:navigation_module/chart_room` | `assets/models/modules/SN_Nav_Chart_Room.glb` | 2.80 × 2.20 × 2.60 | 636 | Wood / Wood_Dark / Metal / Brass / Iron_Hull |
| `core:safety_module/lifeboat` | `assets/models/modules/SN_Safety_Lifeboat.glb` | 4.20 × 1.50 × 1.10 | 660 | Wood / Wood_Dark / Canvas / Brass |
| `core:safety_module/safety_valve` | `assets/models/modules/SN_Safety_Valve.glb` | 1.49 × 1.26 × 1.84 | 428 | Metal / Iron_Hull / Brass |
| `core:cabin/passenger_cabin` | `assets/models/modules/SN_Cabin_Passenger.glb` | 3.40 × 2.40 × 2.55 | 792 | Wood_Deck / Wood / Wood_Dark / Metal / Brass / Iron_Hull |

> 本批只交付 Blender 源场景 + GLB，**尚未接入 Core 内容键**：三种锅炉仍共用 `model.module.boiler`，货舱 / 导航 / 安全 / 客舱没有模型键。接入时需要同时改 `dev_mods/core/content/*.json` 的 `information.model`、manifest 的资源声明与校验测试。

- 工单：`tools/modeling/briefs/sn_ship_modules_batch1.json`
- 生成器：`tools/modeling/generators/sn_ship_modules_generator.py`（参数表驱动，改数值即可重建）
- 离线干跑：`tools/modeling/generators/dryrun_props.py`
- 预览渲染：`tools/modeling/generators/render_modules_preview.py`
- GLB 导出：`tools/modeling/generators/export_modules_glb.py`
- GLB 结构自检：`tools/modeling/generators/verify_modules_glb.py`
- 截图：`docs/design/screenshots/ship_modules_batch1_{overview,boilers,cargo,nav_safety_cabin}.png`
- 工作台：`.design/SN_Asset_Workbench.blend` → `SN_Ship_Modules` 集合（场景现 160 对象 / 145 mesh；GLB 备份在 `.design/modules/backup_glb/`）
- 返工记录：R0 独立质检发现 5 处同法线共面 + 9 处悬空壳体，已按参数级修正并重建（合计 6968 → 7016 tri），R1 复验见验收报告

## 3D 港口设施锚点（第一批 6 件）

2.5D 固定机位港口舞台（`PortStage`）的设施可辨认锚点：只做一眼可认的外轮廓 + 1–2 个标志性细节，不建室内 / 碰撞 / 可进入门，招牌与纸张上**不烘焙任何文字**（文字交给 2D UI 标签层）。6 件各是一个 mesh、原点在底面中心（`object.location` = 布局位置、几何为局部坐标、zmin=0），导出为 `assets/models/port/` 下的独立 `.glb`（单节点 / glTF Y-up / 全部材质 doubleSided）。合计 **4996 三角面**（预算 10500）。

| 设施 | 锚点（GLB） | 尺寸 L×W×H (m) | tri | 主要材质 |
| --- | --- | --- | ---: | --- |
| `exchange` 市场 | `assets/models/port/SN_Market_Stall.glb` | 5.00 × 3.00 × 3.20 | 768 | Wood / Wood_Dark / Canvas / Metal / Brass |
| `contracts` 委托 | `assets/models/port/SN_Notice_Board.glb` | 2.80 × 0.50 × 2.60 | 272 | Wood / Wood_Dark / Canvas / Metal |
| `supply` 补给 | `assets/models/port/SN_Water_Tank.glb` | 4.00 × 4.00 × 5.20 | 1324 | Stone / Metal / Iron / Brass |
| `intel` 情报 | `assets/models/port/SN_Signal_Tower.glb` | 3.20 × 2.40 × 8.50 | 1052 | Metal / Wood_Dark / Brass / Iron / Canvas |
| `shipyard` 船厂 | `assets/models/port/SN_Shipyard_Gantry.glb` | 14.00 × 4.014 × 10.00（Y 含爬梯外凸 14 mm） | 1064 | Metal / Iron / Wood_Dark / Brass |
| `shipyard` 船厂 | `assets/models/port/SN_Dry_Dock.glb` | 18.00 × 8.00 × 2.60 | 516 | Stone / Metal / Wood_Dark |

- 结构要点：市场棚（4 柱前倾帆布顶 + 柜台 + 空图标招牌 + 2 挂灯 + 货架/木箱）；告示板（2 柱 + 木框 + 后挡板 + 6 张空白纸 + 深色小披檐 + 侧挂灯托架，纸面朝 −Y 相机侧、整体后仰 5°）；水箱（石基座 + 16 边筒身 + 锥顶 + 3 道铁箍 + 32 颗铆钉 + 弯管/阀 + 侧爬梯 + 液位计 + 空白黄铜铭牌）；信号塔（4 收分腿 + X 斜撑 + 平台栏杆 + 旗语桅杆 + 2 摆臂 + 灯室 + 旗绳 + 工具柜 + 斜爬梯）；龙门吊（2 组 A 形腿 + 箱形主梁下沿净高 9.00 m + 第 3/4 跨小车/吊钩滑轮组 + 2 钢缆 + 横纵斜撑 + 侧爬梯 + 操作平台）；干船坞（坞底 + 每侧 3 级收分坞壁 + 2 条滑道轨 + 5 组龙骨墩（间距 3 m，骑轨）+ 排水沟 + 两侧各 6 级石阶）。
- 材质：只用调色板；本批新增 `SN_Iron`（氧化铁，base 0.072/0.076/0.084、rough 0.52、metallic 0.62，仅被水箱/信号塔/龙门吊引用）。`SN_Wood_Deck` / `SN_Canvas_Shade` 本批未使用。
- 工作台：`.design/SN_Asset_Workbench.blend` → `SN_Port_Facilities` 集合（场景 234 对象 / 213 mesh / 19 材质）；暂存排原定 y=60，因与 `SN_Ship_Modules` 冲突改为 **y=75**（x = 10 / 18 / 26 / 36 / −8 / −30），工单已记 `layout_revision`。
- 源快照：`.design/port/SN_<Name>.blend`（6 个，单件、轴心归零）；GLB 备份在 `.design/port/backup_glb/`；实测数据 `.design/port/report.json`。
- 工单 / 规划：`tools/modeling/briefs/sn_port_facilities_batch1.json`、`PORT_FACILITIES_PLAN.md`
- 生成器：`tools/modeling/generators/sn_port_facilities_generator.py`（顶部 ITEMS 参数表 + 各 `build_*`，纯几何可离线干跑）
- 离线干跑：`tools/modeling/generators/dryrun_props.py`
- 预览渲染：`tools/modeling/generators/render_port_preview.py`
- GLB 导出：`tools/modeling/generators/export_port_glb.py`（逐件归零导出 + 单件 `.blend` 快照）
- GLB 结构自检：`tools/modeling/generators/verify_port_glb.py`（单节点 / 调色板 / 尺寸 ≤0.1 m / 轴心 / doubleSided）
- 截图：`docs/design/screenshots/port_facilities_batch1_{overview,shipyard,market,notice,tank,tower,gantry,dock}.png`
- 验收记录：6/6 独立只读质检通过（命名/集合/轴心/尺寸误差 0.000/预算/材质/网格健康全 0/回归 digest 命中/视觉可辨）；工单里"信号塔是港口最高剪影"与本批尺寸表自相矛盾（塔 8.5 m < 龙门吊 10.0 m，场景既有铁甲舰 24.44 m），按尺寸表实现，塔为最高**塔类**竖向剪影。
- 已接线：`PortStage` 的 `facility_visuals` 已实现（`StageHost` 泛化完成后落地）；ViewModel 传入已解析 GLB 路径时按设施替换这 6 个锚点，路径缺失/非法时回退程序化 billboard（当前默认仍是 billboard 占位）。截图：[完整港口](screenshots/port_stage/port_stage_preview.png) / [稀疏港口](screenshots/port_stage/port_stage_sparse.png)。

## 3D 港口街景（第一批 10 件）

主界面港口舞台的「码头广场 + 仓库街区」背景 kit：10 件低模、平直着色、无贴图的建筑/人物/小船，放在工作台 `SN_Harbor_Town` 集合（y=110 一排），逐件导出为 `dev_mods/core/assets/models/props/SN_HT_*.glb`，随 core 模组发布（发布包 PCK 排除 `assets/models/*`）。合计 **6204 tri**（工单预算 11500）；场景总数 **244 objects / 223 mesh**，既有对象 digest `4fe3f250…` 未变。

| 对象 | 运行时 GLB | 尺寸 L×W×H (m) | tri 预算 | 主要材质 |
| --- | --- | ---: | ---: | --- |
| `SN_HT_Warehouse_Long` | `dev_mods/core/assets/models/props/SN_HT_Warehouse_Long.glb` | 20 × 9 × 11 | 2600 | Stone / Brick / Wood_Dark / Wood / Glass_Dark / Iron |
| `SN_HT_Warehouse_Short` | `…/SN_HT_Warehouse_Short.glb` | 11 × 9 × 9.5 | 1700 | Stone / Wood / Wood_Dark / Plaster / Glass_Dark |
| `SN_HT_Harbor_Office` | `…/SN_HT_Harbor_Office.glb` | 9 × 8 × 14 | 2200 | Brick / Plaster / Stone / Iron / Brass / Glass_Dark / Wood_Dark |
| `SN_HT_Cargo_Shed` | `…/SN_HT_Cargo_Shed.glb` | 8 × 6 × 4.5 | 700 | Wood / Wood_Dark / Canvas / Metal |
| `SN_HT_Tavern` | `…/SN_HT_Tavern.glb` | 10 × 8 × 8 | 1700 | Plaster / Brick / Wood / Wood_Dark / Glass_Dark / Stone / Iron |
| `SN_HT_Fence_Row` | `…/SN_HT_Fence_Row.glb` | 6 × 0.3 × 1.5 | 300 | Stone / Iron |
| `SN_HT_Dock_Worker_A` | `…/SN_HT_Dock_Worker_A.glb` | 0.7 × 0.45 × 1.8 | 250 | Wood_Dark / Canvas_Shade / Metal |
| `SN_HT_Dock_Worker_B` | `…/SN_HT_Dock_Worker_B.glb` | 0.8 × 0.5 × 1.8 | 250 | Wood_Dark / Canvas_Shade / Wood / Metal |
| `SN_HT_Rowboat` | `…/SN_HT_Rowboat.glb` | 4.2 × 1.5 × 0.8 | 550 | Wood / Wood_Deck / Metal / Iron |
| `SN_HT_Cargo_Lighter` | `…/SN_HT_Cargo_Lighter.glb` | 8 × 3 × 1.6 | 700 | Wood / Wood_Dark / Wood_Deck / Metal / Iron / Canvas_Shade |

- 工单：`tools/modeling/briefs/sn_harbor_town_batch1.json`（尺寸/预算/调色板/验收规则）；新增材质 `SN_Brick` / `SN_Plaster` / `SN_Glass_Dark`。
- 生成器：`tools/modeling/generators/sn_harbor_town_generator.py`（`ITEMS` + `build_*` 纯几何，可 `dryrun_props.py` 离线干跑；`build_all()/report()` 在 Blender 内执行）。
- 导出：`tools/modeling/generators/export_town_glb.py`（逐件临时归零 location → 单对象 GLB → 还原摆位；轴心=底面中心、glTF Y-up、无相机/灯光）。
- 质检：Builder 6204 tri；独立 Verifier R1 修复 Rowboat 压条悬空、Tavern 挂灯脱开、Office 塔身暗板过厚后复验 **passed=true**（244 objects / 223 mesh、回归 digest 命中）。
- Core 接线：`dev_mods/core/manifest.json` 新增 10 个 `model.prop.*`（资产数 65→75）；`port_archetypes.json` 五港 `diorama.kit/town` 引用这 10 个键 + 16 个复用道具/设施键（crate/barrel/coal_pile/timber_stack/handcart/gas_lamp + market_stall/harbor_crane/sack_pile/plate_stack/ore_pile/pallet/gangway/mooring_bollard/capstan/buoy）。
- 舞台装配：`PortStage` 的 L2b 按 `port.size` 与可选 `port.diorama.density`（small→sparse / medium→normal / large→busy）确定性放置：normal 为 5 建筑 + 7 围栏 + 7 工人 + 8 广场装饰 + 3 船 + 17 码头工业件 = **47 props**（sparse 28 / busy 63）；建筑 GLB 缺失回退程序化 blockout，town 存在时跳过 L2 剪影。设施/街景/玩家船在重建后静态合批（按材质合并），实测 preview 63 / sparse 56 draw calls。
- HUD 图标：`icon.money` / `icon.coal` / `icon.water` 由 `AssetService.find_key()` 按裸键从任一已挂载内容包解析（金币/煤炭/淡水 chip），缺资产回退纯文字；不新增资产。
- 截图：`docs/design/screenshots/port_stage/port_stage_preview.png`、`port_stage_sparse.png`、`docs/design/screenshots/overview_port_stage.png`、`overview_port_stage_960.png`。

## 3D 港口样片（水面着色器试做）

独立场景 `dev_scenes/harbor/harbor_diorama.tscn`，不接入主流程；只用已有 GLB 资产 + 场景内程序化 BoxMesh 剪影。浮船已从旧 `SN_Ship_Prototype` 换成 `SN_Schooner_Fame`（1795 双桅纵帆船），水面泡沫环的 `boat_half_size` 同步改为 13.2 × 3.9；场景相机构图已验证可容纳新船 33.44 m 总长 / 26.82 m 总高。

| 运行时路径 | 说明 |
| --- | --- |
| `assets/shaders/water/harbor_water.gdshader` | 港口水面 shader：顶点波浪、噪声法线、菲涅耳反射、太阳耀斑、岸线/船体泡沫、远水雾色 |
| `assets/materials/water/harbor_water.tres` | 近处主水面材质（波浪/泡沫/太阳方向实际生效值） |
| `assets/materials/water/harbor_water_far.tres` | 远处水面材质：同一 shader，关闭波浪/细节/泡沫，只输出地平线雾色 |
| `assets/textures/water/water_normal.png` | 烘焙的无缝水面法线噪声（512²） |
| `assets/textures/water/water_foam.png` | 烘焙的无缝泡沫噪声（512²） |
| `dev_scenes/harbor/bobbing_boat.gd` | 浮船：采样与 shader 同源的波浪 |
| `tools/godot/capture_harbor_diorama.gd` | 窗口模式截图脚本：加载港口样片，等水面/浮船稳定后抓固定机位与近景两张（1440×900） |
| `docs/design/screenshots/harbor_diorama_schooner.png` | **当前**港口样片固定 3/4 机位截图（1440×900，浮船为 SN_Schooner_Fame） |
| `docs/design/screenshots/harbor_diorama_schooner_detail.png` | **当前**纵帆船近景机位截图（1440×900） |
| `docs/design/screenshots/harbor_diorama_dusk.png` | 历史截图：旧 SN_Ship_Prototype 浮船版本（1440×900） |
| `docs/design/screenshots/harbor_diorama_detail.png` | 历史截图：旧浮船近景版本（1440×900） |
| `docs/design/screenshots/schooner_fame_three_quarter.png` | 纵帆船 3/4 预览（Blender EEVEE，1400×860） |
| `docs/design/screenshots/schooner_fame_broadside.png` | 纵帆船正侧预览（1500×780） |
| `docs/design/screenshots/schooner_fame_bow_quarter.png` | 纵帆船艏 3/4 预览（1200×860） |
| `docs/design/screenshots/schooner_fame_stern_quarter.png` | 纵帆船艉 3/4 预览（1200×860） |
| `docs/design/screenshots/schooner_fame_top.png` | 纵帆船俯视预览（1000×900） |

`dev_scenes/harbor/README.md` 记录运行方式、调参入口与已知边界；`tools/godot/verify_harbor_diorama.gd` 是无头验收脚本。

## Core 实体资源映射

Core 内容使用 `information.texture/model` 保存逻辑资源键；下列 GLB 从全局展示资产复制到 Core 包内，使松散 Core 与独立 `.snavmod.zip` 都能自行解析。全局副本继续供开发场景直接引用。

| Core 资源键 | Core 包内路径 | 使用实体 |
|---|---|---|
| `model.ship.prototype` | `assets/models/ships/SN_Ship_Prototype.glb` | 小型、标准中型船体 |
| `model.ship.paddle_freighter` | `assets/models/ships/SN_Paddle_Freighter.glb` | 两种大型船体 |
| `model.module.boiler` | `assets/models/modules/SN_Boiler_Unit.glb` | 三种锅炉 |
| `model.good.iron_ore` | `assets/models/goods/SN_Ore_Pile.glb` | 铁矿石 |
| `model.good.coal` | `assets/models/goods/SN_Coal_Pile.glb` | 煤炭；同时使用 `icon.coal` |
| `model.good.timber` | `assets/models/goods/SN_Timber_Stack.glb` | 木材 |
| `model.material.boiler_plate` | `assets/models/materials/SN_Plate_Stack.glb` | 锅炉钢板 |
| `model.material.precision_gear` | `assets/models/materials/SN_Gear_Crate.glb` | 精密齿轮 |
| `model.material.sealing_compound` | `assets/models/materials/SN_Barrel.glb` | 密封剂 |
| `banner.port.iron_harbor` | `assets/ports/iron_harbor_banner.png` | 铁港；作为贴图 |

淡水实体继续使用既有 `icon.water` 贴图。Core manifest 当前声明 **75 个资源键**（含街景第一批 10 个 `model.prop.*`，见「3D 港口街景」章节）。

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
