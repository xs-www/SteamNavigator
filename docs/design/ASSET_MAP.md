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
| `.design/ships/SN_Ship_Prototype.blend` | `assets/models/ships/SN_Ship_Prototype.glb` | 低多边形帆船原型；2608 三角面、36 节点、5 种材质（木 / 深木 / 甲板木 / 帆布 / 金属）；**遗留纯色资产（`model.ship.prototype` 键），未纳入批次 B** |
| `.design/ships/sn_ship_prototype_generator.py` | — | 帆船参数化生成脚本；改 `STATIONS` / `MASTS` 表即可生成不同吨位船体 |
| `.design/SN_Asset_Workbench.blend`（`SN_Paddle_Freighter_Prototype` 集合）+ `.design/ships/SN_Paddle_Freighter.blend` | `assets/models/ships/SN_Paddle_Freighter.glb` | 大型明轮蒸汽货轮：**59.53 × 14.10 × 19.52 m**（船体 LOA 55 m，总长含艏斜桁）、**12200 三角面**、**56 节点（39 mesh + 17 empty，含 4 个武器 socket + 6 个帆索 socket）**、6 材质（`SN_Iron_Hull` / `SN_Iron_Red` / `SN_Brass` 新增，复用 `SN_Wood` / `SN_Wood_Deck` / `SN_Metal`）。双明轮（14 桨叶 / 每侧 8 辐条 / 16 段双轮缘 + 内加强环 + 黄铜轮缘条 + 4 斜撑）、半包轮罩箱板（-6°..186° + 中央观察窗 + 黄铜包边 / 铭牌，端封 r_in 2.75 避让轮扫掠、内板窗 2.30 避让蒸汽管）、双后倾烟囱、锅炉机舱围罩 + 蒸汽管、桥楼 + 驾驶室、4 货舱口 + 4 吊杆、双桅横桁 + 艏斜桁、艏楼 / 艉楼侧封板、吊艇架救生艇、舵轮 / 旗；根节点 `SN_PF_Root` 水线轴心、工作台摆位 (-45, 0, 0)；2 个明轮 Pivot + 4 个 `SN_Socket_*`；**4 个武器 socket**（`_Port_1/2` + `_Starboard_1/2`：Side×2 / Light×2）；**6 个帆索 socket**（`SN_Socket_Mast/Yard/Sail × Fore/Main`） |
| `.design/SN_Asset_Workbench.blend`（`SN_Ironclad_Prototype` 集合）+ `.design/ships/SN_Ironclad.blend` | `assets/models/ships/SN_Ironclad.glb` | 舷侧炮铁甲舰：**60.14 × 18.00 × 28.64 m**（水线轴心，z -4.2..24.44）、**8158 三角面**、**26 节点（1 mesh + 4 个武器 socket + 9 个帆索 socket + 12 个炮门 socket）** / 8 材质；装甲带 + 板缝、每舷 6 个空炮门（1.9×1.9 m 框 + 深色炮口板 + 上翻门盖；炮管 Ø0.88→0.72 / 外露 1.5407 m 自 2026-10-22 起是独立模块 `SN_Weapon_CasemateGun`）+ 2 门艏 pivot 炮、2.2 m 装甲带（外凸 380 mm）与 120 mm 板缝、中央装甲炮房 + 指挥塔、双后倾烟囱、三桅横桁收帆 + 艏斜桁基座、锚吊架、撞角艏、艉廊、螺旋桨/舵；单节点 GLB、工作台摆位 (0, 90, 0)；**4 个武器 socket**（`_Port_1/2` + `_Starboard_1/2`：Heavy×2 / Medium×2）；**9 个帆索 socket**（`SN_Socket_Mast/Yard/Sail × Fore/Main/Mizzen`）；**12 个炮门 socket**（`SN_Socket_GunPort_Port/Starboard_1..6`） |
| `.design/SN_Asset_Workbench.blend`（`SN_Paddle_Steamer_Prototype` 集合）+ `.design/ships/SN_Paddle_Steamer.blend` | `assets/models/ships/SN_Paddle_Steamer.glb` | 小型澳洲明轮蒸汽客船（参考 PS Enterprise）：**24.56 × 8.74 × 10.47 m**（LOA 24.0 m，水线轴心 z=0）、**11764 三角面**、**38 节点（32 mesh + 6 empty，含 3 个武器 socket）**、8 材质（新增 `SN_White` / `SN_Flag_Blue` / `SN_Flag_White`，复用 5）；白漆双层船身 + 暗红水线/舷缘压条 + 深色船底、两舷 10 桨叶明轮（14 段双轮缘 / 8 辐条 / 内加强环 / 黄铜轮缘条 / 4 斜撑）+ 10 道水平格栅轮罩、前驾驶室（双侧 ENTERPRISE 文字铭牌）、后部白色立柱雨棚游步甲板、黑烟囱 + 黄铜箍/红顶圈、锅炉围罩 + 黄铜蒸汽管、艏旗杆澳洲旗、艉部弧形低平台 + 舵；**不含蒸汽几何**（留给游戏内 VFX）；根节点 `SN_PS_Root` 工作台摆位 (45, 0, 0)；**3 个武器 socket**（`_Port_1` / `_Starboard_1` / `_Stern`：Light×2 / Medium×1） |
| `.design/SN_Asset_Workbench.blend`（`SN_Schooner_Fame_Prototype` 集合）+ `.design/ships/SN_Schooner_Fame.blend` | `assets/models/ships/SN_Schooner_Fame.glb` | 1795 年 Salem 双桅纵帆船 **SN_Schooner_Fame**：**33.44 × 6.88 × 26.82 m**（船体 LOA 24.4 m，总长含艏斜桁/艏三角帆）、**13174 三角面**、**42 节点（29 mesh + 13 empty，含 3 个武器 socket + 7 个帆索 socket）**、12 材质（新增 `SN_Hull_Black` / `SN_Ochre` / `SN_Canvas_Shade` / `SN_Flag_Red`，复用 8）；18 站放样黑船身 + 赭黄上舷带 + 黑腰板/压顶、艉楼甲板；双桅后倾（Fore −2.5° / Main −3.2°，轴距 6.4 m）、前桅斜桁帆 + 方顶帆、主桅大斜桁帆 + 三角顶帆、两面艏三角帆（jib + fore staysail）、舷侧绳梯（shrouds + ratlines）/支索/动索、艉廊 3 蓝窗 + 双灯 + FAME 铭牌、舱口格栅/绞盘/起锚机/舵轮/罗经柜/锚/钟/木桶/盘绳/fife rails/短梯/艏饰；**无星条旗**（用户 2026-10-19 要求移除，仅保留主桅顶红白长旒）；帆腹镜像朝 −Y（Godot +Z 相机侧）；根节点 `SN_SF_Root` 水线轴心、工作台摆位 (0, −70, 0)；**3 个武器 socket**（`_Port_1` / `_Starboard_1` / `_Bow`：Light×2 / Medium×1）；**7 个帆索 socket**（`SN_Socket_Mast/Yard/Sail × Fore/Main` + `SN_Socket_Sail_Jib`） |
| `.design/SN_Asset_Workbench.blend` | `assets/models/props/SN_Harbor_Crane.glb` + `dev_mods/core/assets/models/props/SN_Harbor_Crane.glb` | 工作台主场景（全场景 298 对象；塔吊集合 33 对象）；锤头式塔吊重建为**参数化生成器产物**：**3912 三角面**、33 节点（31 mesh + 根空物体 + 回转 Pivot）、4 材质（木 / 深木 / 金属 / 石材），主臂 20.1 m 水平、总高 21.47 m，吊钩最低点 4.42 m，场景摆放 (0, 16, 0)。Core 资产键 `model.prop.harbor_crane` 不变，GLB 已同步 `dev_mods` 副本 |

| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合） | `assets/models/props/` 下 6 个独立 `.glb` | 铁港码头第一批小部件：石砌岸壁 `SN_Dock_Wall` / 木护舷 `SN_Dock_Fender` / 系缆桩 `SN_Mooring_Bollard` / 木箱 `SN_Crate` / 木桶 `SN_Barrel` / 矿石堆 `SN_Ore_Pile`；P0 整改后合计 **1360 三角面**，材质 `SN_Ore` 已改为锈红铁矿色 |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合，第二批） | `assets/models/props/` 下 6 个独立 `.glb` | 铁港第二批：煤气灯 `SN_Gas_Lamp` / 船岸跳板 `SN_Gangway` / 双瓣抓斗 `SN_Grab_Bucket` / 煤堆 `SN_Coal_Pile` / 码头爬梯 `SN_Dock_Ladder` / 钢板堆 `SN_Plate_Stack`；合计 **1214 三角面**，新增材质 `SN_Coal`（base 0.020/0.019/0.018、rough 0.95、metallic 0） |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合，第三批） | `assets/models/props/` 下 6 个独立 `.glb` | 铁港第三批（堆场 / 管线）：木料堆 `SN_Timber_Stack` / 麻袋堆 `SN_Sack_Pile` / 蒸汽管段 `SN_Steam_Pipe` / 缆绳卷 `SN_Mooring_Rope` / 吊货网 `SN_Cargo_Net` / 托盘 `SN_Pallet`；合计 **1024 三角面**，不新增材质 |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合，第四批） | `assets/models/props/` 下 6 个独立 `.glb` | 铁港第四批（机械 / 水上件）：浮标 `SN_Buoy` / 锚链堆 `SN_Chain_Coil` / 手动绞盘 `SN_Capstan` / 平板手推车 `SN_Handcart` / 圆形碰垫 `SN_Fender_Ball` / 精密齿轮箱 `SN_Gear_Crate`；合计 **1452 三角面**，不新增材质。齿轮箱对应 Core 的 `precision_gear` 商品，可作市场货台道具 |
| `.design/SN_Asset_Workbench.blend`（`SN_IronHarbor_Props` 集合，第五批） | `assets/models/props/` 下 7 个独立 `.glb` | 铁港第五批（结构 / 标识 / 动力）：码头石阶 `SN_Dock_Stairs` / 港口牌 `SN_Port_Sign` / 港口钟 `SN_Bell` / 旗杆 `SN_Flag_Pole` / 煤溜槽 `SN_Coal_Chute` / 锅炉机组 `SN_Boiler_Unit` / 龙骨墩 `SN_Keel_Block`；合计 **1232 三角面**，不新增材质。锅炉与煤溜槽是同批最重的两件 |

> **2026-10-22 · 旧资产 UV 迁移 B（4 艘可玩船）**：`SN_Ironclad` / `SN_Paddle_Freighter` / `SN_Paddle_Steamer` / `SN_Schooner_Fame` 全部补 UV（多节点船体用根节点局部空间盒式投影）、切换 `SN_Tex_*` 共享贴图材质并重导 GLB；tri / 节点 / 网格数不变（合计 45 968 tri），详见 [LEGACY_UV_MIGRATION_B_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_B_ACCEPTANCE.md)。`SN_Ship_Prototype` 是遗留原型，仍是旧纯色材质，不在本批。

> **2026-10-22 · 船侧武器安装点 M0-3（4 艘可玩船）**：4 艘船各 2–4 个 `SN_Socket_Weapon*` 空节点（PF 4 / PS 3 / SF 3 / IC 4，合计 **14 个**），**无几何改动**（45 968 tri、mesh 数不变）；BLEND 内带 `SN_PF_` / `SN_PS_` / `SN_SF_` / `SN_IC_` 前缀，GLB 导出后归一化为标准名；节点 extras 写 `socket_class` / `clearance_r` / `clearance_x` / `clearance_y` / `clearance_h` / `mount_scale` / `socket_index`，Root 写 `weapon_sockets` 列表。GLB 节点数 PF 46→50 / PS 35→38 / SF 32→35 / IC 1→5。契约见 [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md) §8；脚本 `sn_ship_weapon_sockets.py` / `glb_ship_sockets.py` / `export_ship_weapon_sockets_glb.py` / `verify_ship_weapon_sockets_glb.py`（4/4 ALL OK），验收 [SHIP_WEAPON_SOCKETS_ACCEPTANCE.md](../archive/SHIP_WEAPON_SOCKETS_ACCEPTANCE.md)。

> **2026-10-22 · 船体帆索部件库 rig_kit M0-4（3 艘船 + 12 件套件）**：新增 `tools/modeling/generators/rig_kit.py`（桅杆 / 横桁 / 斜桁 / 帆杠 / 艏斜桁 / 帆面 / 索具的参数化部件库）与 12 件独立 `SN_Rig_*` GLB（**3,774 tri / 7,050 预算**，`assets/models/rig/` + Core 副本）；PF / SF / IC 的帆索改为调用同一份部件库生成，**逐对象顶点/面 digest 与重构前 0 差异**（PF 12,200 / IC 8,830 tri、mesh 数不变；SF 纯帆索基线 28 对象 / 12,994 tri，整船场景含既有 `SN_SF_Nameplate` 为 29 / 13,174；`rig_kit_baseline.py --compare` 3/3 SAME）。3 艘船各新增 `SN_Socket_Mast/Yard/Sail_*` 空节点（PF 6 / SF 7 / IC 9，合计 **22 个**，零几何），GLB 节点 PF 50→56 / SF 35→42 / IC 5→14，Root 写 `rig_sockets` 列表。契约 [RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md)、机器目录 [rig_kit_catalog.json](../../tools/modeling/rig_kit_catalog.json)、验收 [RIG_KIT_ACCEPTANCE.md](../archive/RIG_KIT_ACCEPTANCE.md)。

> **2026-10-22 · 旧资产 UV 迁移 A（M0-1，已完成）**：以上 31 件铁港道具全部补 `UVMap`（局部空间盒式投影，`len(uv) == len(loops)`）、材质槽从旧纯色 `SN_*` 切换为 `SN_Tex_*` 共享贴图材质（实际 7 个），并重导 GLB（`images[].uri = shared_materials/<texture>.png`，Core 副本同步）；三角面与尺寸完全不变（合计 **6 282 tri**）。旧 `SN_Ore` 按锈红铁矿色映射到 `SN_Tex_Iron_Red`，`SN_Canvas` → `SN_Tex_Canvas_Shade`。迁移脚本 / 映射 / 验收见 [LEGACY_UV_MIGRATION_A_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_A_ACCEPTANCE.md)。
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
| `tools/modeling/generators/sn_paddle_freighter_generator.py` | — | 明轮货轮参数化生成器（`STATIONS` / `PROFILE` / `PADDLE` / `PADDLE_BOX` / `FUNNELS` / `MASTS` / `HATCHES` / `BOOMS` / `DECKHOUSE` 参数表；纯几何函数 + Blender 装配 + `report()`；M0-4 起桅杆/横桁/艏斜桁/索具委托 `rig_kit`，只保留船型布局） |
| `tools/modeling/generators/dryrun_ship.py` | — | 船舶生成器纯 Python 干跑：tri / 包围盒 / 边界边 / 非流形边 / 退化面 / 命名 / 父级键 / 明轮 Pivot 归属 |
| `tools/modeling/generators/export_ship_glb.py` | — | 船舶归档：备份旧 GLB → 保存工作台 → 根节点归零导出 GLB → `bpy.data.libraries.write` 船体快照 → 还原根节点 |
| `tools/modeling/generators/verify_ship_glb.py` | — | GLB 结构自检：节点 / 网格 / 材质 doubleSided / 三角面 / 世界包围盒（Y-up） |
| `tools/modeling/briefs/sn_ironclad_broadside.json` | — | 舷侧炮铁甲舰工单（60 m 级、12000 tri、8 材质、水线轴心、纯展示资产） |
| `tools/modeling/generators/sn_ironclad_generator.py` | — | 铁甲舰参数化生成器（`STATIONS` / `GUN_X` / `MASTS` / `FUNNELS` 参数表；船体放样 + 装甲带 + 炮列 + 炮房/烟囱 + 甲板件，单 mesh 装配 + `report()`；M0-4 起三桅与索具委托 `rig_kit.ironclad_masts/rigging`） |
| `tools/modeling/generators/sn_ship_weapon_sockets.py` | — | M0-3 船侧武器 socket 规格真源 + Blender 就地补齐/实测/自检：`SHIPS` 表、`DECK_Z_EXPECTED`、`validate_spec()`、`apply_all()`、`verify_all()`；`--check` 可纯 Python 干跑 |
| `tools/modeling/generators/glb_ship_sockets.py` | — | socket GLB 后处理：BLEND 前缀名 → `SN_Socket_Weapon_*`，并写 Root `weapon_sockets` / `weapon_socket_count` / `socket_spec` |
| `tools/modeling/generators/export_ship_weapon_sockets_glb.py` | — | 4 艘船 GLB 重导：外部共享贴图、旧 GLB 备份、Core 副本同步、socket 名称归一化 |
| `tools/modeling/generators/verify_ship_weapon_sockets_glb.py` | — | 船体 socket GLB 独立验收：几何不变量 + 武器/帆索 socket 父子/translation/朝向/extras + Root extras（4/4 ALL OK） |
| `tools/modeling/generators/rig_kit.py` | — | **M0-4 船体帆索部件库**（纯 Python）：`RigBuilder` 适配器 + 通用积木（rope/spar/jaws/block）+ 帆面曲面/帆缝/帆缘绳 + 帆船/蒸汽船/铁甲舰部件函数；3 艘船与 12 件套件共用同一份几何 |
| `tools/modeling/generators/rig_kit_batch1_generator.py` | — | 12 件 `SN_Rig_*` 套件生成器：套件布局参数、`SN_Mount` + `SN_Socket_*` 接口、Root extras、Blender 装配 + `report()` |
| `tools/modeling/generators/sn_rig_materials.py` | — | rig_kit 12 件套件的共享贴图材质白名单 / 回退色 |
| `tools/modeling/generators/dryrun_rig_kit.py` | — | rig_kit 纯 Python 干跑：命名 / tri / bbox / z 基准 / 材质白名单 / 网格健康（帆面允许边界边）/ Mount+Socket 契约 |
| `tools/modeling/generators/gen_rig_kit_catalog.py` | — | 从套件与船侧 socket 真源导出 `tools/modeling/rig_kit_catalog.json` |
| `tools/modeling/generators/sn_ship_rig_sockets.py` | — | M0-4 帆索 socket 规格真源：3 艘船 22 个 `SN_Socket_Mast/Yard/Sail_*`、`apply_all()` / `verify_all()`（零几何） |
| `tools/modeling/generators/glb_ship_rig_sockets.py` | — | 船体帆索 socket GLB 后处理：BLEND 前缀 → `SN_Socket_*` + Root `rig_sockets` 列表 |
| `tools/modeling/generators/glb_rig_kit.py` | — | 套件 GLB 后处理：接口节点归一化（`SN_Mount` / `SN_Socket_*`）+ Root `rig_sockets` |
| `tools/modeling/generators/export_rig_kit_glb.py` | — | 12 件套件 GLB 导出：根归零、共享贴图外部化、接口归一化、Core 同步 |
| `tools/modeling/generators/verify_rig_kit_glb.py` | — | 12 件套件 GLB 独立验收（12/12 ALL OK） |
| `tools/modeling/generators/rig_kit_baseline.py` | — | 3 艘船重构前后的逐对象几何基线（`--capture` / `--compare`，digest 0 差异） |
| `tools/modeling/generators/dryrun_ironclad.py` | — | 铁甲舰纯 Python 干跑：tri / 包围盒（水线轴心）/ z 范围 / 边界边 / 非流形边 / 退化面 / 孤立点 / 材质 |
| `tools/modeling/generators/render_ironclad_preview.py` | — | 铁甲舰预览渲染：3/4 / 正侧 / 舰艏 / 舰艉 3/4 四视角 |
| `tools/modeling/generators/export_ironclad_glb.py` | — | 铁甲舰归档：备份旧 GLB → 轴心归零导出 → `bpy.data.libraries.write` 单对象快照 |
| `tools/modeling/generators/verify_ironclad_glb.py` | — | 铁甲舰 GLB 结构自检：26 节点 / 8 图元 / 8158 tri / 材质 / Y-up 包围盒 / z 范围 |
| `tools/modeling/generators/check_ironclad_connectivity.py` | — | 铁甲舰连通性检查（只读）：拆连通岛 + BVH 三角面相交/最近距离，抓 `revolved()` 忘 translate、小艇漏偏移等"悬空/错位" |
| `tools/modeling/briefs/sn_ship_paddle_steamer.json` | — | 小型明轮蒸汽船工单（24.4×8.7×10.5 m、12000 tri、8 材质、明轮 10 桨叶 / 10 道格栅、ENTERPRISE 铭牌；明确蒸汽不建模，明轮 8 旋转角零穿模） |
| `tools/modeling/generators/sn_paddle_steamer_generator.py` | — | 明轮蒸汽船参数化生成器（`STATIONS` / `PROFILE` / `PADDLE` / `PADDLE_BOX` / `WHEELHOUSE` / `CANOPY` / `FLAG` 参数表；纯几何 + Blender 装配 + 文字铭牌 + `report()`） |
| `tools/modeling/generators/dryrun_paddle_steamer.py` | — | 明轮蒸汽船纯 Python 干跑：tri / 包围盒 / z 范围 / 边界边 / 非流形边 / 退化面 / 孤立点 / 材质 / 父级 / 左右镜像误差 |
| `tools/modeling/generators/render_paddle_steamer_preview.py` | — | 明轮蒸汽船预览渲染：3/4、正侧、艏、艉 3/4、俯视；临时双太阳/水面，渲后还原场景 |
| `tools/modeling/generators/verify_paddle_steamer_scene.py` | — | 明轮蒸汽船场景只读验收：命名/层级/Pivot/网格健康/明轮 8 旋转角世界坐标 BVH 交面/左右镜像/连通岛悬空/工作台回归，输出 JSON |
| `tools/modeling/generators/export_paddle_steamer_glb.py` | — | 明轮蒸汽船 GLB 归档：备份旧 GLB → 保存工作台 → 轴心归零导出 → `libraries.write` 快照 → 还原摆位 |
| `tools/modeling/generators/verify_paddle_steamer_glb.py` | — | 明轮蒸汽船 GLB 结构自检：35 节点 / 32 网格 / 8 doubleSided 材质 / 11764 tri / Y-up bbox / 水线 −1.32，并拒绝蒸汽节点 |
| `tools/modeling/briefs/sn_schooner_fame.json` | — | 1795 双桅纵帆船工单：船体 LOA 24.4 m / 总长 33.44 m / 总高 26.82 m、≤18000 tri、12 材质；双桅后倾 / 斜桁帆 / 方顶帆 / 艏三角帆 / 完整索具 / 艉廊 FAME 铭牌；用户明确不要星条旗，只保留红白长旒 |
| `tools/modeling/generators/sn_schooner_fame_generator.py` | — | 纵帆船参数化生成器（`STATIONS` / `PROFILE` / `MASTS` / `FORE_SAIL` / `MAIN_SAIL` / `FORE_TOPSAIL` / `MAIN_TOPSAIL` 参数表；18 站放样 + 甲板属具 + 艉廊 + 文字铭牌 + `report()`；M0-4 起桅杆/斜桁/帆/索具委托 `rig_kit`，只保留船型布局） |
| `tools/modeling/generators/ship_parts/` | — | **可复用船体部件库 v1**：`core`（Part/基本体/PartSpec）/ `deck`（舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯）/ `bow`（艏斜桁/jibboom/艏饰）/ `stern`（艉廊/艉窗/艉灯）/ `assembly`（集合/材质/Pivot/文字/report）/ `palette`；生成器只保留船型布局，重构后纵帆船逐对象 digest 不变 |
| `tools/modeling/generators/ship_parts/README.md` | — | 部件库契约：分层、`PartSpec`、新增部件步骤、坐标/材质约定、输出不变的验收口径 |
| `tools/modeling/generators/dryrun_schooner_fame.py` | — | 纵帆船纯 Python 干跑：对 FORE/MAIN 子件施加 Pivot 世界变换后核对 tri / bbox / 边界边 / 非流形 / 退化 / 孤立点 / 材质 / 命名 / 父级，并断言两桅轴距 6.4 m、后倾与主桅更高 |
| `tools/modeling/generators/export_schooner_fame_glb.py` | — | 纵帆船 GLB 归档：备份旧 GLB → 保存工作台 → 根节点归零导出 → `libraries.write` 快照 → 还原 (0, −70, 0) |
| `tools/modeling/generators/verify_schooner_fame_glb.py` | — | 纵帆船 GLB 结构自检：32 节点 / 29 网格 / 12 doubleSided 材质 / 13174 tri / Y-up bbox 33.44×26.85×6.88 / 水线轴心 −2.74 |
| `tools/modeling/generators/render_schooner_fame_preview.py` | — | 纵帆船预览渲染：3/4、正侧、艏 3/4、艉 3/4、俯视 5 张；临时相机/太阳/水面，渲后还原场景 |
| `tools/godot/verify_props.gd` | — | GLB 导入验收（只读）：核对 Godot 侧包围盒、三角面、贴地与 `SN_Tex_*` 材质名，专抓"改了 .blend 忘了重导 GLB"或旧纯色材质回流 |
| `tools/modeling/briefs/sn_iron_harbor_batch1.json` | — | 铁港第一批批量工单（6 件一次派发）；系缆桩尺寸在 P0 整改中改为 0.62 × 0.62 × 0.70 |
| `tools/modeling/briefs/sn_iron_harbor_batch2.json` | — | 铁港第二批批量工单（6 件，y=30 一排，预算 1900 tri） |

> `.design/SN_Asset_Workbench.blend` 是当前主场景；`.design/ships/SN_Ship_Prototype.blend` 是旧帆船原型的独立快照，`.design/ships/SN_Schooner_Fame.blend` 是 1795 双桅纵帆船的独立快照（32 对象，轴心水线），`.design/ships/SN_Paddle_Freighter.blend` 是明轮货轮的独立快照（`bpy.data.libraries.write` 只打包该集合 46 对象，轴心水线、不切换当前文件），`.design/ships/SN_Paddle_Steamer.blend` 是小型明轮蒸汽船的独立快照（35 对象）。新增资产一律进工作台的新集合，交付时按集合导出独立 `.glb`。

- 轴向：Blender 中 +X 为船首、+Z 向上；glTF 导出后 +Y 向上，进入 Godot 需绕 Y 轴 +90° 才对齐引擎的 −Z 前方。
- 轴心：船体中部水线，1 unit = 1 m，可直接按水面高度摆放。
- 帆为单层平面，材质必须双面（glTF 已标 `doubleSided`）；其余单层曲面（甲板 / 舷墙 / 腰板）也保持双面，后续可按材质开启背面剔除。
- `.blend` 按本文件第 5 行决策留在 `.design/`（gitignore，不进构建）；只有 `.glb` 进入运行时资源。

## 3D 港口起重机四件套（2026-10-21）

同一批交付四台起重机（塔吊为补全生成器后的重建）。全部由参数化生成器驱动、纯 Python 干跑，
工作台集合独立；**四件均已接入 Core manifest**（`model.prop.harbor_crane` 沿用，
`model.prop.mega_gantry` / `model.prop.wooden_mast_crane` / `model.prop.hand_jib_crane` 新增），
PortStage 槽位接线仍待做。材质不再用纯色：四件全部使用 `SN_Tex_*` 共享贴图材质
（贴图 URI `shared_materials/<texture>.png`，见下节）。

| 资产 | 运行时 GLB | 集合 / 摆位 | 尺寸 L×W×H (m) | tri | 材质数 | 结构要点 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Harbor_Crane` | `assets/models/props/SN_Harbor_Crane.glb`（Core 副本同路径） | `SN_Harbor_Crane_Prototype` / (0, 16, 0) | 26.50 × 6.30 × 21.47 | **3912** | 4 | 石基座 + 收分格构塔 + 回转环 / 平台 + 20.1 m 桁架主臂 + 6 m 配重臂 + 3 块石配重 + A 字塔头 / 6 拉杆 + 司机室 + 主卷扬（卷筒 / 电机 / 齿轮组 / 制动盘）+ 小车 + 吊钩组；回转 Pivot `SN_Crane_Slew_Pivot`（z=17.3），吊钩最低 4.42 m |
| `SN_Mega_Gantry` | `assets/models/props/SN_Mega_Gantry.glb` | `SN_Mega_Gantry_Prototype` / (-20, 260, 0) | 39.60 × 14.80 × 29.65 | **9420** | 6 | 地面双轨 + 枕木、4 台带齿轮传动的台车、4 条收分格构腿 + 两条顶梁 + 40 m 主桁架桥（走台 / 小车轨 / 栏杆）、小车卷扬、桥端机械房（双卷筒 / 电机 / 齿轮箱 / 齿轮组 / 传动轴 / 制动盘）、4 根起升钢缆 + 双钩横担 + 吊装集装箱、爬梯 / 平台 |
| `SN_Wooden_Mast_Crane` | `assets/models/props/SN_Wooden_Mast_Crane.glb` | `SN_Wooden_Mast_Crane_Prototype` / (30, 260, 0) | 14.77 × 7.00 × 14.25 | **1932** | 6 | 石台基 + 木梁底盘 + 方木桅杆（8 道铁箍 / 四向斜撑）、后倾木吊臂（双颊板 / 铁箍 / 端部滑轮）、桅顶四根后拉索 + 石锚、A 字木架手摇绞车（卷筒 / 棘轮 / 摇柄 / 二级齿轮）、吊钩组、爬梯、甲板盘绳 / 木箱 / 木料堆 |
| `SN_Hand_Jib_Crane` | `assets/models/props/SN_Hand_Jib_Crane.glb` | `SN_Hand_Jib_Crane_Prototype` / (55, 260, 0) | 4.60 × 1.70 × 5.17 | **896** | 6 | 石基座 + 木垫板 + 地脚螺栓、立柱（法兰 / 柱帽 / 铁箍）、悬臂 + 拉杆 + 斜撑 + 端部滑轮、手摇绞车（卷筒 / 棘轮 / 摇柄）、吊钩组、踏步 / 铭牌 |

- 共用部件库：`tools/modeling/generators/crane_kit.py`（桁架臂 / 格构柱 / 梯子 / 栏杆 / 车轮 / 卷筒 / 滑轮 / 齿轮 / 钢缆 / 吊钩组 / 手摇绞车 / 木料堆，纯 Python，不 import bpy）。
- 共享贴图材质库：`tools/modeling/generators/sn_shared_materials.py`（读 spec、建 `SN_Tex_*` 材质节点、世界空间盒式 UV、验收）；资产侧视图 `sn_crane_materials.py`（`MAT_*` 常量 + 每资产材质白名单 + `colors_for()` 回退）。
- 生成器：`sn_harbor_crane_generator.py`、`sn_mega_gantry_generator.py`、`sn_wooden_mast_crane_generator.py`、`sn_hand_jib_crane_generator.py`；工单 `tools/modeling/briefs/sn_crane_batch1.json`。
- 干跑 / 导出 / 自检 / 预览：`dryrun_cranes.py`（含贴图库与材质白名单校验）、`export_cranes_glb.py`（导出后把贴图外部化为共享 URI 并同步 Core）、`verify_cranes_glb.py`（世界空间 bbox、外部 URI、贴图字节、`TEXCOORD_0`）、`render_cranes_preview.py`。
- Godot 验收：`tools/godot/verify_cranes.gd`（尺寸 / tri / 材质 / 贴地）与 `tools/godot/verify_crane_materials.gd`（外部 URI、UV、跨 GLB 贴图实例共享）。
- 轴向：Blender +X 为臂架伸出方向、+Z 向上；glTF 转 Y-up 后进入 Godot 尺寸为 (Blender X, Blender Z, Blender Y)。
- 预览截图（本地产物，`.design` 被 gitignore）：`.design/props/preview/crane_*.png`。

### 共享材质贴图库（`shared_materials`，2026-10-21）

> 约定：**新资产不再用纯色代表材质**。材质 = 贴图 + spec 参数；贴图是外部共享 PNG，
> 模型只保留几何与 UV。旧资产的纯色 `SN_*` 材质按“补 UV → 切 `SN_Tex_*` → 重导 GLB”
> 逐批迁移：**2026-10-22 已完成批次 A（31 件铁港道具 + 6 件港口设施）与批次 B（船模块 /
> 4 艘船 / 旧小镇剩余 5 件）**；仅 `SN_Ship_Prototype` 遗留键仍是旧纯色。

| 材质 | 贴图 | tile_m | 粗糙度 / 金属度 | 用途 |
| --- | --- | ---: | --- | --- |
| `SN_Tex_Metal` | `metal.png` | 2.0 | 0.36 / 0.90 | 钢构、桁架、机械件 |
| `SN_Tex_Iron` | `iron.png` | 2.0 | 0.52 / 0.62 | 铸铁、台车、车轮 |
| `SN_Tex_Iron_Red` | `iron_red.png` | 2.0 | 0.62 / 0.10 | 锈红漆面、机械房、吊具 |
| `SN_Tex_Wood` | `wood.png` | 2.0 | 0.70 / 0.00 | 木结构、桅杆、吊臂 |
| `SN_Tex_Wood_Dark` | `wood_dark.png` | 2.0 | 0.64 / 0.00 | 深色木、卷筒、走台 |
| `SN_Tex_Wood_Deck` | `wood_deck.png` | 2.0 | 0.76 / 0.00 | 甲板、平台铺板 |
| `SN_Tex_Stone` | `stone.png` | 2.0 | 0.90 / 0.00 | 石基座、配重、地锚 |
| `SN_Tex_Brass` | `brass.png` | 1.0 | 0.28 / 0.85 | 黄铜件、铭牌、轴承 |
| `SN_Tex_Canvas_Shade` | `canvas.png` | 0.5 | 0.92 / 0.00 | 帆布、绳索 |
| `SN_Tex_Glass_Dark` | `glass_dark.png` | 2.0 | 0.25 / 0.35 | 深色玻璃窗 |
| `SN_Tex_Coal` | `coal.png` | 1.0 | 0.78 / 0.15 | 碎煤堆、煤斗（批次 2 新增） |

- 真源：`docs/design/textures/shared_materials/shared_materials.spec.json`；贴图生成器 `tools/art/gen_shared_material_textures.py`（11 张 512² 无缝贴图 + montage + stats，确定性可复现）。
- 授权贴图：`docs/design/textures/shared_materials/tiles/<texture>.png`；评审 montage：`docs/design/textures/shared_materials/shared_materials_montage.png`。
- 运行时副本：`assets/models/{props,port,modules,ships,weapons,ship_parts,machinery,cargo,dock,rig}/shared_materials/`（开发态）与对应 `dev_mods/core/assets/models/.../shared_materials/`（发布，共 24 个 `runtime_dirs`）；GLB `images[].uri` = `shared_materials/<texture>.png`。
- 运行时共享：`ContentAssetLoader` 按路径缓存 `Texture2D`，四台起重机、31 件铁港道具、6 件港口设施、12 件船模块与 4 艘船等资产共用同一贴图实例；`PortStage` 按材质签名合批。
- 契约与迁移细节：`docs/design/MODELING_WORKFLOW.md` §12；批次 A/B 的迁移映射、脚本与验收见 [LEGACY_UV_MIGRATION_A_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_A_ACCEPTANCE.md) / [LEGACY_UV_MIGRATION_B_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_B_ACCEPTANCE.md)。

### 旧资产 UV 迁移 A（31 件铁港道具 + 6 件港口设施，2026-10-22）

按 backlog M0-1 完成：**只改材质与 UV，不改几何 / 轴心 / 对象变换**。37 件合计 **11 278 tri**（props 6 282 / port 4 996，与迁移前逐件一致），UV loops **24 188**，材质槽全部为 `SN_Tex_*`（props 7 种 / port 7 种，共 14 个运行时共享贴图实例；props 与 port 各持一份 `shared_materials/` 副本）。

| 旧纯色材质 | 共享贴图材质 | 说明 |
| --- | --- | --- |
| `SN_Wood` / `SN_Wood_Dark` / `SN_Wood_Deck` | `SN_Tex_Wood` / `SN_Tex_Wood_Dark` / `SN_Tex_Wood_Deck` | 一对一 |
| `SN_Metal` / `SN_Iron` / `SN_Iron_Red` / `SN_Brass` | 同名 `SN_Tex_*` | 一对一 |
| `SN_Stone` | `SN_Tex_Stone` | 石阶 / 岸壁 / 干船坞石壁 |
| `SN_Canvas` / `SN_Canvas_Shade` | `SN_Tex_Canvas_Shade` | 两类旧帆布合并到唯一贴图 |
| `SN_Coal` | `SN_Tex_Coal` | 煤堆 |
| `SN_Ore` | `SN_Tex_Iron_Red` | 锈红铁矿色与 iron_red 均值一致，不新增贴图 |

- 迁移脚本：`tools/modeling/generators/sn_legacy_uv_migration.py`（材质映射 + 局部空间盒式 UV + 几何签名对比）；`dryrun_legacy_uv.py` 纯 Python 预检。
- 导出：`tools/modeling/generators/export_legacy_uv_glb.py`（逐件归零导出、`glb_shared_textures.externalize_glb(prefer_authored=True)`、旧 GLB 备份 `.design/legacy_uv/backup_glb/`、Core 副本同步、共享贴图运行时副本补齐 11 张）。
- 验收：`verify_legacy_uv_glb.py`（37/37：tri/尺寸与迁移前一致、每图元 TEXCOORD_0、材质 `SN_Tex_*`、外部 PNG 与授权 tile 逐字节一致）；`tools/godot/verify_legacy_uv_materials.gd`（37/37、14 个共享贴图实例、0 失败）；`framework/tests/cases/test_legacy_uv_assets.gd` 2 例守护。

### 旧资产 UV 迁移 B（船模块 / 4 艘船 / 旧小镇，2026-10-22）

按 backlog M0-2 完成：**只改材质与 UV，不改几何 / 轴心 / 对象变换**。实际重导 **21 个 GLB**（12 船模块含占位副本 + 4 艘可玩船 + 5 件旧小镇道具），合计 **55 256 tri**（modules 7 492 / ships 45 968 / town 1 796，与迁移前逐件一致）、UV loops **111 564**、118 个 mesh 对象、10 个 `SN_Tex_*` 材质；Godot 运行时 21 件 / **24 个共享贴图实例** / 0 失败。

| 旧纯色材质 | 共享贴图材质 | 说明 |
| --- | --- | --- |
| `SN_Iron_Hull` / `SN_Hull_Black` | `SN_Tex_Iron` | 铁船体 / 纵帆船黑船身（铸铁贴图比深木更接近原黑） |
| `SN_Ochre` | `SN_Tex_Wood_Deck` | 赭黄腰线 |
| `SN_White` / `SN_PS_UpperWhite` | `SN_Tex_Canvas_Shade` | 无纯白贴图，映射到最接近的浅色帆布（二级白层次合并） |
| `SN_Flag_Red` / `SN_Flag_White` / `SN_Flag_Blue` | `SN_Tex_Iron_Red` / `SN_Tex_Canvas_Shade` / `SN_Tex_Glass_Dark` | 旗帜 |
| 其余 `SN_Wood*` / `SN_Metal` / `SN_Brass` / `SN_Stone` / `SN_Canvas*` / `SN_Iron_Red` | 同名 `SN_Tex_*` | 与批次 A 一致 |

- 迁移脚本：`sn_legacy_uv_migration.py` 的 `migrate_all_b()`；单 mesh 用 `space="local"`，多节点船体用 `space="root"`（新增支持，跨子件连续、不烘入工作台摆位）。
- 导出：`export_legacy_uv_b_glb.py`；`dryrun_legacy_uv_b.py` 预检；`verify_legacy_uv_b_glb.py` 21/21 验收；`tools/godot/verify_legacy_uv_materials_b.gd` 运行时验收；`test_legacy_uv_assets_b.gd` 2 例守护。
- 旧小镇：backlog 的 10 件中，**5 栋旧建筑已在建筑套件批次升级为 `SN_Town_*` trim-sheet LOD0**（运行时 GLB 已替换，本次不重做）；本次迁移剩余 **5 件**旧纯色道具（Fence_Row / Dock_Worker_A/B / Rowboat / Cargo_Lighter）。
- `SN_Ship_Prototype`（`model.ship.prototype` 遗留键）不在 4 艘可玩船内，仍是旧纯色资产，留待后续清理批次。
- 验收细节见 [LEGACY_UV_MIGRATION_B_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_B_ACCEPTANCE.md)。


## 3D 资产：舷侧炮铁甲舰（SN_Ironclad）

1860 年代舷侧炮铁甲舰，60 m 级纯展示资产（不接入 Core 内容键）。单 mesh / 8 材质槽，轴心在水线中心（x=0 船中、z=0 水线、+X 船首），工作台摆位 (0, 90, 0)：

| 项 | 数值 |
| --- | --- |
| 包围盒 | **60.14 × 18.00 × 28.64 m**（LOA 含艏斜桁与艉廊；z -4.20 .. 24.44） |
| 三角面 | **8158 / 12000**（2026-10-22 casemate 模块化：12 门炮管 + 炮口箍拆出为独立模块，−672 tri） |
| 材质 | Iron_Hull / Iron_Red / Wood_Deck / Wood / Wood_Dark / Metal / Brass / Canvas（复用既有调色板，不新增） |
| 结构 | 17 站放样铁壳 + 撞角艏；**英雄化装甲带**（2.2 m 高、外凸 380 mm、120 mm 竖向板缝/黄铜压条）；**每舷 6 个空炮门**（炮门 1.9×1.9 m 框 + 深色炮口板 + 上翻炮门盖；炮管/炮口箍自 2026-10-22 起是独立模块 `SN_Weapon_CasemateGun`，经 `SN_Socket_GunPort_*` 挂载，见 [WEAPON_SOCKET_CONTRACT.md §9](WEAPON_SOCKET_CONTRACT.md)）+ 2 门放大艏 pivot 炮；中央装甲炮房 + 指挥塔 + 艏驾驶台；双后倾烟囱 + 通风筒 + 天窗；三桅横桁（收帆卷）+ 艏斜桁 + 支索/侧支索；舷墙 + 黄铜压条；舱口格栅/绞盘/舵轮/罗经柜/小艇/锚（吊架）/螺旋桨/舵/艉廊/旗 |
| 运行时 GLB | `assets/models/ships/SN_Ironclad.glb`（**26 节点 = 1 mesh + 4 武器 socket + 9 帆索 socket + 12 炮门 socket 空节点 / 8 图元 / 8158 tri / 573.3 KB / glTF Y-up，轴心水线中心；Root extras 另写 `weapon_sockets` / `rig_sockets` / `gun_port_sockets` 三套名单） |
| 源文件 | `.design/SN_Asset_Workbench.blend`（`SN_Ironclad_Prototype` 集合）+ `.design/ships/SN_Ironclad.blend`（单对象快照） |
| 工单/脚本 | `briefs/sn_ironclad_broadside.json`、`sn_ironclad_generator.py`、`dryrun_ironclad.py`、`check_ironclad_connectivity.py`、`render_ironclad_preview.py`、`export_ironclad_glb.py`、`verify_ironclad_glb.py`；casemate 批次：`apply_casemate_assets.py`、`export_casemate_glb.py`、`verify_casemate_glb.py`、`render_casemate_preview.py`、`sn_ship_gun_ports.py`、`glb_gun_ports.py` |
| 截图 | `docs/design/screenshots/ironclad_{three_quarter,broadside,bow,bow_closeup,guns_closeup,stage_ortho}.png`；casemate 批次：`ironclad_casemate_{three_quarter,guns_closeup,empty_closeup}.png` |

> 纯展示资产：核心玩法仍使用现有 4 种船体；若将来把铁甲舰作为第 5 种船体或港口战舰接入，需要补内容 JSON、manifest 资源键、本地化与测试。

## 3D 资产：小型明轮蒸汽船（SN_Paddle_Steamer）

参考澳大利亚国家博物馆的明轮蒸汽船 **PS Enterprise**（堪培拉伯利·格里芬湖）的小型公开甲板客船，24 m 级纯展示资产（不接入 Core 内容键）。轴心在船体中部水线（x=0 船中、z=0 水线、+X 船首），工作台摆位 (45, 0, 0)：

| 项 | 数值 |
| --- | --- |
| 包围盒 | **24.56 × 8.74 × 10.47 m**（LOA 24.0 m，总宽含轮罩，总高含烟囱顶；z -1.32 .. 9.15） |
| 三角面 | **11764 / 12000** |
| 材质 | `SN_White` / `SN_Iron_Hull` / `SN_Iron_Red` / `SN_Wood_Deck` / `SN_Metal` / `SN_Brass` / `SN_Flag_Blue` / `SN_Flag_White`（新增 3 个，复用 5 个；批次 C 后为 9 槽，新增仅本船使用的 `SN_PS_UpperWhite`） |
| 结构 | 16 站放样白漆船身 + 深色水线以下船底 + 暗红压条；两舷 10 桨叶明轮（14 段双轮缘 / 每侧 8 辐条 / 内加强环 / 黄铜轮缘条 / 4 斜撑 / 曲柄销）+ 梯形格栅轮罩（10 道水平格栅 + 深色内衬 + 暗红顶沿 + 黄铜铭牌）+ 明轮台走台/栏杆；主甲板客舱（白墙 + 玻璃窗 + 黄铜窗台 + 木门）、游步甲板 + 白色立柱雨棚 + 前后栏杆；前驾驶室（三面窗 + 顶板 + 双侧 `ENTERPRISE` 文字铭牌 + 黄铜钟）；锅炉围罩 + 黑烟囱（黄铜箍 / 暗红顶圈）+ 黄铜蒸汽管；艏旗杆 + 澳洲旗（蓝底 / 白十字 / 红星 / 南十字星）、艏部锚/绞盘/系缆桩、艉部弧形低平台 + 栏杆 + 舵/舵柄 + 救生圈/卷缆 |
| 蒸汽 | **不建模**：烟囱蒸汽由游戏内粒子/VFX 渲染（用户 2026-10-19 明确要求） |
| 运行时 GLB | `dev_mods/core/assets/models/ships/SN_Paddle_Steamer.glb`（38 节点 = 32 mesh + 6 empty，含 **3 个武器 socket** / 32 网格 / 11764 tri / 9 材质 doubleSided / 815.8 KB / sha256 `d5225d8e05de` / glTF Y-up，轴心水线 z=0） |
| 源文件 | `.design/SN_Asset_Workbench.blend`（`SN_Paddle_Steamer_Prototype` 集合，工作台 196 对象）+ `.design/ships/SN_Paddle_Steamer.blend`（35 对象独立快照） |
| 工单/脚本 | `briefs/sn_ship_paddle_steamer.json`、`sn_paddle_steamer_generator.py`、`dryrun_paddle_steamer.py`、`render_paddle_steamer_preview.py`、`verify_paddle_steamer_scene.py`、`export_paddle_steamer_glb.py`、`verify_paddle_steamer_glb.py` |
| 截图 | before `paddle_steamer_{three_quarter,broadside,bow,stern_quarter,top}.png`；after `paddle_steamer_*_batchc.png`；Godot 实机 `docs/design/screenshots/paddle_steamer_c/shipyard_paddle_steamer_{1440x900,960x540}.png` |
| 批次 C 精修 | 雨棚减重（覆盖 63.72→41.34 m2 / 游步甲板 71.4→46.3%，4 薄板+3 分缝+后段 3 m 露空，薄边 0.14→0.07）；明度层级（白船身 0.870 > 舱室 0.680 > 甲板 0.300）；暗红压条加粗（舷墙压顶 0.055→0.075 等）；tri/尺寸/轴心/层级/旗/铭牌/明轮安全不变，共享材质已恢复。报告 [PADDLE_STEAMER_VISUAL_POLISH_C.md](../archive/PADDLE_STEAMER_VISUAL_POLISH_C.md) |

> 纯展示资产：若将来作为第 5 种船体 / 内河客运场景接入，需要补 Core 内容 JSON、manifest 资源键、本地化、Godot 导入验收与 2.5D 舞台目标机位试装。明轮几何挂在 `SN_PS_Paddle_*_Pivot` 下，可直接绕 Y 轴做旋转动画；蒸汽建议在 Godot 侧用烟囱顶 `SN_PS_Funnel` 作为发射点做粒子。

## 3D 资产：combat_kit 敌舰（M2-1，2026-10-22）

阶段 2 自动战斗的 **3 类敌人**。4 艘敌舰复用现有船体骨架（同一套「横剖面站 + 剖面轮廓」放样）
与 `rig_kit` / `ship_parts` 部件库，**不新增贴图、不烘炮**；甲板炮位按
[WEAPON_SOCKET_CONTRACT.md §8](WEAPON_SOCKET_CONTRACT.md) 给空节点，铁甲舰变体舷侧炮门按
[§9](WEAPON_SOCKET_CONTRACT.md) 给空节点并复用 `SN_Weapon_CasemateGun`。机器目录见
[`combat_kit_catalog.json`](../../tools/modeling/combat_kit_catalog.json)。

| 资产 | 敌人类别 | 运行时 GLB | 包围盒 x×y×z（m） | tri | 节点（mesh + empty + socket） | 武器 socket / 炮门 |
| --- | --- | --- | --- | ---: | --- | --- |
| `SN_Enemy_Pirate_Sloop` | Light | `assets/models/combat/SN_Enemy_Pirate_Sloop.glb` | 29.08 × 6.32 × 24.18 | 8 678 | 20（15 + 2 + 3） | 3 / 0 |
| `SN_Enemy_Merchant_Armed` | Medium | `assets/models/combat/SN_Enemy_Merchant_Armed.glb` | 40.77 × 9.40 × 28.77 | 11 746 | 27（18 + 3 + 6） | 6 / 0 |
| `SN_Enemy_Ironclad_Raider` | Heavy | `assets/models/combat/SN_Enemy_Ironclad_Raider.glb` | 44.83 × 14.73 × 21.09 | 7 440 | 25（12 + 1 + 4 + 8） | 4 / 8 |
| `SN_Enemy_Gunboat` | Light | `assets/models/combat/SN_Enemy_Gunboat.glb` | 16.90 × 4.73 × 10.07 | 3 460 | 14（10 + 1 + 3） | 3 / 0 |
| **合计** | 3 类 | 4 个 GLB / 2 235 780 B | | **31 324 / 32 400** | 86 | **16 / 8** |

| 项 | 数值 |
| --- | --- |
| 材质 | 9 张既有共享贴图（Wood / Wood_Dark / Wood_Deck / Metal / Brass / Iron / Iron_Red / Canvas_Shade / Glass_Dark），**无新增**；`assets/models/combat/shared_materials/` 与 Core 副本各 11 张 PNG，每艘 GLB 外部引用 8 张 |
| 结构 | 海盗单桅（22.5 m 船体、单桅后倾 + 大斜桁帆 + 方顶帆 + 两面艏三角帆、艉楼 + 三艉窗、黑旗 + 红长旒）；武装商船（34 m 宽体、双桅各两面方帆、艉楼 + 艉旗、两舷 2×2 中型炮位 + 艏/艉炮位）；铁甲舰变体（44 m 低干舷、2.2 m 外凸装甲带 + 撞角 + 螺旋桨、中央斜壁炮房 + 指挥塔 + **单**后倾烟囱、单蒸汽桅收帆横桁、每舷 4 空炮门）；小型炮艇（16 m 铁壳、艏部 U 形装甲炮盾 + 中央炮口、单烟囱 + 小驾驶室 + 短信号桅） |
| 轴心 / 摆位 | 水线中心（+X 船首、+Z 向上、吃水为负 z）；工作台 4 艘并排于 y=-110 空走廊，导出时根节点归零 |
| 源文件 | `.design/SN_Asset_Workbench.blend` 的 4 个 `SN_Enemy_*_Prototype` 集合 |
| 工单/脚本 | `briefs/sn_combat_kit_batch1.json`、`combat_kit_generator.py`、`dryrun_combat_kit.py`、`sn_enemy_weapon_sockets.py`、`sn_enemy_gun_ports.py`、`glb_enemy_sockets.py`、`export_combat_kit_glb.py`、`verify_combat_kit_glb.py`、`render_combat_kit_preview.py`、`gen_combat_kit_catalog.py`；Godot 用例 `test_combat_kit_assets.gd` |
| 截图 | `docs/design/screenshots/combat/combat_lineup.png`；单件 3/4 + side 在 `.design/combat/preview/`（本地产物） |
| 验收 | [COMBAT_KIT_ACCEPTANCE.md](../archive/COMBAT_KIT_ACCEPTANCE.md) |

> 本批只交付资产 / socket / 目录；敌人内容 Schema（`enemy_archetypes`）、运行时遭遇表与 AI
> 留后续。LOD1 未做。

## 3D 船舶模块（11 件）

`SN_Ship_Modules` 集合把 Core 里除船体外的全部模块实体做成独立可摆放的 3D 件：锅炉 3、货舱 3、导航 2、安全 2、客舱 1，合计 **7016 三角面**。每件一个 mesh 对象、3–6 个既有调色板材质槽、原点在底面中心（1 unit = 1 m，+X 为前向），导出为 `assets/models/modules/` 下的独立 `.glb`（单节点 / glTF Y-up），可直接按槽位摆到船体或舞台 socket 上。

| Core 模块实体 | 运行时 GLB | 尺寸 L×W×H (m) | tri | 主要材质 |
| --- | --- | ---: | ---: | --- |
| `core:module/small_efficient` | `assets/models/modules/SN_Boiler_Efficient.glb` | 1.81 × 1.60 × 2.60 | 540 | Wood_Dark / Metal / Iron_Hull / Brass |
| `core:module/standard` | `assets/models/modules/SN_Boiler_Standard.glb` | 2.82 × 1.90 × 2.62 | 860 | Wood_Dark / Metal / Iron_Hull / Brass |
| `core:module/performance` | `assets/models/modules/SN_Boiler_Performance.glb` | 3.40 × 2.11 × 2.94 | 1152 | Wood_Dark / Metal / Iron_Hull / Brass |
| `core:module/small_hold` | `assets/models/modules/SN_Cargo_Small_Hold.glb` | 2.40 × 2.00 × 1.80 | 456 | Wood / Wood_Dark / Metal / Brass |
| `core:module/medium_hold` | `assets/models/modules/SN_Cargo_Medium_Hold.glb` | 3.20 × 2.40 × 2.20 | 492 | Wood / Wood_Dark / Metal / Brass |
| `core:module/large_hold` | `assets/models/modules/SN_Cargo_Large_Hold.glb` | 4.01 × 2.81 × 2.60 | 672 | Wood / Wood_Dark / Metal / Brass |
| `core:module/spyglass` | `assets/models/modules/SN_Nav_Spyglass.glb` | 1.38 × 0.80 × 1.75 | 328 | Brass / Metal / Wood_Dark / Wood |
| `core:module/chart_room` | `assets/models/modules/SN_Nav_Chart_Room.glb` | 2.80 × 2.20 × 2.60 | 636 | Wood / Wood_Dark / Metal / Brass / Iron_Hull |
| `core:module/lifeboat` | `assets/models/modules/SN_Safety_Lifeboat.glb` | 4.20 × 1.50 × 1.10 | 660 | Wood / Wood_Dark / Canvas / Brass |
| `core:module/safety_valve` | `assets/models/modules/SN_Safety_Valve.glb` | 1.49 × 1.26 × 1.84 | 428 | Metal / Iron_Hull / Brass |
| `core:module/passenger_cabin` | `assets/models/modules/SN_Cabin_Passenger.glb` | 3.40 × 2.40 × 2.55 | 792 | Wood_Deck / Wood / Wood_Dark / Metal / Brass / Iron_Hull |

> 本批只交付 Blender 源场景 + GLB，**尚未接入 Core 内容键**：三种锅炉仍共用 `model.module.boiler`，货舱 / 导航 / 安全 / 客舱没有模型键。接入时需要同时改 `dev_mods/core/content/*.json` 的 `information.model`、manifest 的资源声明与校验测试。
>
> **2026-10-22 迁移 B（M0-2）**：11 件专用模块 + `modules/SN_Boiler_Unit` 占位副本（manifest `model.module.boiler` 引用）共 **12 个 GLB** 已补 `UVMap` / 切换 `SN_Tex_*` 共享贴图；合计 **7 492 tri** 不变、Core 副本同步。表中"主要材质"为迁移前旧名，迁移后的对应关系见上文「旧资产 UV 迁移 B」小节。

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
- 材质：只用调色板；本批新增 `SN_Iron`（氧化铁，base 0.072/0.076/0.084、rough 0.52、metallic 0.62，仅被水箱/信号塔/龙门吊引用）。`SN_Wood_Deck` / `SN_Canvas_Shade` 本批未使用。**2026-10-22 迁移 A 后**：6 件全部补 `UVMap` 并切换 `SN_Tex_*` 共享贴图材质（Stone / Metal / Iron / Wood / Wood_Dark / Canvas_Shade / Brass），GLB 外部贴图 URI + Core 副本已同步，tri 与尺寸不变（合计 **4 996 tri**），见 [LEGACY_UV_MIGRATION_A_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_A_ACCEPTANCE.md)。
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

## 3D 港口街景（铁港建筑套件 LOD0 + 批次 A LOD1）

主界面港口舞台的「码头广场 + 仓库街区」背景 kit。第一批 10 件低模道具（围栏/工人/小船等）仍在工作台 `SN_Harbor_Town` 集合（y=110），运行时为 `dev_mods/core/assets/models/props/SN_HT_*.glb`；其中 **5 栋建筑已在铁港建筑套件（M1 + 批次 B + 批次 A）升级为带共享 trim sheet 贴图的 LOD0，并新增 5 件 LOD1**，随 core 模组发布（发布包 PCK 排除 `assets/models/*`，内容只从 `.snavmod.zip` / 松散目录读取）。

> **2026-10-22 迁移 B**：旧小镇剩余 **5 件旧纯色道具**（`SN_HT_Fence_Row` / `Dock_Worker_A` / `Dock_Worker_B` / `Rowboat` / `Cargo_Lighter`）已补 `UVMap` / 切换 `SN_Tex_*` 共享贴图并重导 GLB（合计 **1 796 tri** 不变）；5 栋建筑早在建筑套件批次已用 `SN_Town_*` 图集 + UV 完成，本次只核验、未重做。详见 [LEGACY_UV_MIGRATION_B_ACCEPTANCE.md](../archive/LEGACY_UV_MIGRATION_B_ACCEPTANCE.md)。

### 建筑资产（批次 A 终态）

| 资产 | LOD0 运行时 GLB | LOD1 运行时 GLB | 尺寸 X×Y×Z (m) | LOD0 tri | LOD1 tri | LOD1 上限 | 材质槽 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| `SN_HT_Warehouse_Long` | `…/SN_HT_Warehouse_Long.glb` | `…/SN_HT_Warehouse_Long_LOD1.glb` | 20 × 9 × 11 | 7 436 | **1 584** | 2 602 | 6 |
| `SN_HT_Warehouse_Short` | `…/SN_HT_Warehouse_Short.glb` | `…/SN_HT_Warehouse_Short_LOD1.glb` | 11 × 9 × 9.5 | 3 788 | **1 060** | 1 325 | 6 |
| `SN_HT_Harbor_Office` | `…/SN_HT_Harbor_Office.glb` | `…/SN_HT_Harbor_Office_LOD1.glb` | 9 × 8 × 14 | 10 336 | **1 896** | 3 617 | 6 |
| `SN_HT_Cargo_Shed` | `…/SN_HT_Cargo_Shed.glb` | `…/SN_HT_Cargo_Shed_LOD1.glb` | 8 × 6 × 4.5 | 3 356 | **776** | 1 174 | 5（无砖） |
| `SN_HT_Tavern` | `…/SN_HT_Tavern.glb` | `…/SN_HT_Tavern_LOD1.glb` | 10 × 8 × 8 | 5 116 | **1 248** | 1 790 | 6 |
| **合计** | — | — | — | **30 032** | **6 564（21.85%）** | 10 508 | — |

- 材质：6 槽固定为 `SN_Town_Brick / Plaster / Wood / Iron / Stone / Glass`；贴图来自同一张 2048² trim sheet 的 16 个 512² cell，每栋按 M1/B 批选定 cell（不新增独占大贴图）。
- **共享外部贴图（批次 A）**：10 个 GLB 的 `images[].uri` 统一指向 `assets/models/props/iron_harbor_shared/<cell>.png`（11 张、与 `docs/design/textures/iron_harbor/tiles/` 逐字节一致）；`ContentAssetLoader` 按 URI 缓存 `Texture2D`，5 栋建筑共用同一贴图实例，`PortStage` 静态合批因此把建筑材质批次从 29 收敛到 11。
- LOD1 只作为「可被质量档位使用」的资产交付，**未接入运行时 LOD 切换**（按需求 §3/§5.1）。
- Core manifest 新增 5 个 `model.prop.*_lod1` 资产键（LOD0 路径不变；清单资产键 75→80）。
- 生成器/导出/自检：`tools/modeling/generators/sn_iron_harbor_architecture_kit_generator.py`（Long LOD0）、`sn_iron_harbor_{warehouse_short,harbor_office,cargo_shed,tavern}_generator.py`（其余 LOD0）、`sn_iron_harbor_architecture_lod1_generator.py`（5 栋 LOD1）、`sn_iron_harbor_materials.py`（共享材质/UV）、`glb_shared_textures.py`（内嵌贴图→外部共享 URI + BIN 压缩）、`export_iron_harbor_architecture_lod_glb.py`（Blender 侧 LOD0+LOD1 逐件导出）、`verify_iron_harbor_architecture_lod_glb.py`（纯 Python 结构/tri/bbox/贴图总量复检）。
- 验收工具：`tools/godot/capture_port_stage_res.gd`（1440×900 / 960×540，第三参数 LOD0/LOD1）、`tools/godot/measure_port_stage.gd`（draw calls / batches / surfaces，`-- --core-zip` 走挂载 ZIP 路径）、`tools/godot/verify_shared_textures.gd`（共享贴图实例探针）。

### 批次 B 新增三栋原型（2026-10-20）

| 资产 | LOD0 GLB | LOD1 GLB | 尺寸 X×Y×Z (m) | LOD0 tri | LOD1 tri | 上限 |
| --- | --- | --- | --- | ---: | ---: | ---: |
| `SN_HT_Boiler_House` | `…/SN_HT_Boiler_House.glb` | `…/SN_HT_Boiler_House_LOD1.glb` | 12×10×12 | 7 388 | 2 536 | 8 000 / 2 800 |
| `SN_HT_Workshop_Row` | `…/SN_HT_Workshop_Row.glb` | `…/SN_HT_Workshop_Row_LOD1.glb` | 18×7×8.5 | 7 312 | 2 444 | 8 000 / 2 800 |
| `SN_HT_Brick_Tenement` | `…/SN_HT_Brick_Tenement.glb` | `…/SN_HT_Brick_Tenement_LOD1.glb` | 10×8×12 | 9 376 | 2 704 | 14 000 / 4 900 |

- 复用同一套共享 trim sheet；新增共享 tile 仅 `brick_wall_soot`（12 张共享 PNG，2.03 MB）；新原型 6 GLB 合计 1.96 MB；8 栋建筑模型+纹理 6.27 MB，core zip 6.65 MB。
- 组合接线：`iron_harbor` = WR + BH（warehouse_long/tavern 槽）；`spice_port` = WR + BT（warehouse_long/harbor_office 槽）；其余三港保持旧 5 栋。组合截图见 `docs/design/screenshots/iron_harbor_architecture/…_combo_{a,b,old}_port_stage_{1440x900,1280x720,960x540}.png`。
- 实测：combo_a 75 376 tri / 72 draws / 42 batches；combo_b 72 144 tri / 71 draws / 41 batches（松散与 ZIP 一致）。报告：[IRON_HARBOR_ARCHITECTURE_BATCH_B.md](../archive/IRON_HARBOR_ARCHITECTURE_BATCH_B.md)。
- **LOD1 收口（2026-10-22）**：铁港建筑 LOD1 至此为 **8 栋建筑 × (LOD0 + LOD1) = 16 个 GLB**（批次 A 5 栋 + 批次 B 3 栋），本套件不再扩栋；backlog M0-5 剩余的 **30 件**（kit 26 + 4 艘可玩船）见下方 [LOD1 基础套件](#lod1-基础套件m0-52026-10-22)。

### 舞台装配与性能（批次 A 实测）

- 5 栋建筑 + 7 围栏 + 7 工人 + 8 广场装饰 + 3 船 + 17 码头工业件 = **47 props**（sparse 28 / busy 63）；建筑 GLB 缺失回退程序化 blockout，town 存在时跳过 L2 剪影。
- 共享贴图合批后实测 **preview 71 / sparse 64 draw calls**（batch B 内嵌贴图时为 91 / 82；共享前整帧 89/82），阶段分析面 **73**（≤75 目标、≤80 硬上限），`batches=41`（原 59）、`meshes_before 163→42`；5 栋模型+纹理 **4.17 MB**（≤4.5 MB；LOD0+LOD1 GLB 2.28 MB + 11 张共享 PNG 1.88 MB）。
- LOD1 临时入舞台证据（非正式接线）：960×540 与 1440×900 固定机位截图可辨认 5 栋轮廓；量测见批次 A 验收报告。
- 截图：LOD1 单价/对比 30 张（`docs/design/screenshots/iron_harbor_architecture/*_LOD1_*`）、PortStage 固定机位 `SN_HT_Warehouse_Long_LOD0_port_stage_{1440x900,960x540}.png` 与 `..._LOD1_port_stage_{1440x900,960x540}.png`；舞台截图 `docs/design/screenshots/port_stage/port_stage_preview.png`、`port_stage_sparse.png`、`overview_port_stage.png`、`overview_port_stage_960.png`。
- 旧 `SN_Harbor_Town` 10 件占位（y=110）保留未动，作为回归基线；其上表第一批 tri 预算数字已被本套件取代。

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

## 3D 舰载武器五件套（2026-10-21）

把武器从船体资产里独立出来的第一批：每件一个 GLB、自带炮座与 Yaw / Pitch 两级 Pivot，
可单独摆放或后续挂到任意船体/舞台。**本批只交付资产**：不登记 Core manifest 键、不改 content JSON、
不改船体 GLB、不接战斗逻辑。

| 资产 | 运行时 GLB | 集合 / 摆位 | 尺寸 L×W×H (m) | tri | 材质数 | 结构要点 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Weapon_DeckGun` | `assets/models/weapons/SN_Weapon_DeckGun.glb` | `SN_Weapon_DeckGun_Prototype` / (0, 320, 0) | 2.81 × 1.41 × 1.61 | **1456** | 4 | 铁炮座底板 + 回转环 + 收分炮座、双片铁护盾 + 黄铜铆钉、黄铜水冷套 + 3 道箍、炮管 / 炮口箍 / 耳轴 / 后坐滑轨、俯仰弧齿 + 手轮 + 螺杆 + 瞄具 |
| `SN_Weapon_HeavyCannon` | `assets/models/weapons/SN_Weapon_HeavyCannon.glb` | `SN_Weapon_HeavyCannon_Prototype` / (0, 330, 0) | 4.80 × 2.20 × 2.20 | **1768** | 6 | 木炮床 + 双铁滑轨 + 横梁 + 四角螺栓、回转盘 + 滑座 + 颊板、双片炮盾 + 顶/底横梁 + 瞄具柱、俯仰弧齿 + 两侧手轮 + 止退索、粗炮管 + 4 道箍 + 炮口箍 + 炮尾 + 耳轴 + 双制退筒 |
| `SN_Weapon_Mortar` | `assets/models/weapons/SN_Weapon_Mortar.glb` | `SN_Weapon_Mortar_Prototype` / (0, 340, 0) | 3.20 × 2.20 × 2.62 | **1460** | 6 | 木底台 + 铁底板 + 8 颗螺栓 + 侧压条、炮弹架 + 3 发炮弹、回转环 + 双颊板摇架 + 耳轴、升降螺杆 + 手轮、摇架蒸汽助力筒、固定 60° 高角臼炮（深色炮口 + 黄铜口沿）+ 瞄具 |
| `SN_Weapon_Repeater` | `assets/models/weapons/SN_Weapon_Repeater.glb` | `SN_Weapon_Repeater_Prototype` / (0, 350, 0) | 2.86 × 1.60 × 1.86 | **1820** | 4 | 后部蒸汽机箱 + 飞轮（-Y 侧）+ 排气管 + 铆钉、回转台 + 立柱 + 三脚撑、6 管旋转炮簇 + 中央轴 + 机匣 + 轴承环 + 炮口前环、弹斗 + 盖板 + 手摇柄 + 蒸汽管、瞄具 |
| `SN_Weapon_Broadside` | `assets/models/weapons/SN_Weapon_Broadside.glb` | `SN_Weapon_Broadside_Prototype` / (0, 360, 0) | 2.23 × 8.00 × 2.06 | **3200** | 7 | 4 门短舰炮共用一条回转滑轨、木炮列底板 + 两端船舷挂架、4 台炮车（各带颊板 / 俯仰弧齿 / 止退索）+ 4 组炮盾（每组 2 片）、后部装填工具架、瞄准具；炮列沿 Y 排列、炮口 +X |

五件合计 **9,704 三角面**（预算 18,700），全部为闭合壳体、UV 完整、zmin = 0；详细验收见 [WEAPON_BATCH1_ACCEPTANCE.md](../archive/WEAPON_BATCH1_ACCEPTANCE.md)。

- 轴向/轴心：Blender `+X` 炮口、`+Z` 向上，根空物体原点在炮座底面中心（z = 0）；glTF 导出后 `+Y` 向上，进入 Godot 尺寸为 (Blender X, Blender Z, Blender Y)。
- Pivot：`SN_Weapon_<Name>_Yaw_Pivot` 绕 Z 回转、挂在 Root 下；`SN_Weapon_<Name>_Pitch_Pivot` 绕 Y 俯仰、挂在 Yaw 下，轴心在耳轴。侧弦炮列为 1 个 Yaw + 4 个独立 `Pitch_Pivot_1..4`；上船时把整个 Root 绕 Z 旋转 -90°，炮口朝舷外。
- 共享贴图：全部使用 `SN_Tex_*` 外部贴图，GLB `images[].uri = shared_materials/<texture>.png`；运行时副本在 `assets/models/weapons/shared_materials/` 与 `dev_mods/core/assets/models/weapons/shared_materials/`，`shared_materials.spec.json` 的 `runtime_dirs` 已加入这两个目录。
- 源/工具：工单 `tools/modeling/briefs/sn_weapon_batch1.json`；生成器 `tools/modeling/generators/sn_weapon_batch1_generator.py`；部件库 `weapon_kit.py`；材质视图 `sn_weapon_materials.py`；干跑 `dryrun_weapon_batch1.py`；导出 `export_weapon_glb.py`；GLB 自检 `verify_weapon_glb.py`；预览 `render_weapon_preview.py`。
- 验收图：`docs/design/screenshots/weapons/weapon_<slug>_{three_quarter,side}.png` 与 `weapon_batch1_lineup.png`。
- 后续：战斗内容 Schema 2.0 落地后再登记 `model.weapon.*`、补 `weapons` 内容类型与挂载 socket；本批不改 `dev_mods/core/manifest.json`。

## 3D 舰载特殊武器三件套（2026-10-21）

武器批次 2：三件**不规则形态**的舰载武器/载具。每件仍是独立 GLB，并首次显式导出
`SN_Weapon_<Name>_Mount` + `Anchor_1..4` 空节点与根属性，作为“不规则形态如何拼进 socket”的模型侧接口。
完整契约见 [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md)。

| 资产 | 运行时 GLB | 集合 / 摆位 | 尺寸 L×W×H (m) | tri | 材质数 | mount_class | Pivot |
| --- | --- | --- | --- | ---: | ---: | --- | --- |
| `SN_Weapon_Ballista` | `assets/models/weapons/SN_Weapon_Ballista.glb` | `SN_Weapon_Ballista_Prototype` / (0, 380, 0) | 5.04 × 3.05 × 2.20 | **1956** | 8 | Heavy | Yaw + Pitch + Mount + 4 Anchor |
| `SN_Weapon_ArrowTower` | `assets/models/weapons/SN_Weapon_ArrowTower.glb` | `SN_Weapon_ArrowTower_Prototype` / (0, 400, 0) | 3.80 × 3.80 × 6.55 | **3428** | 8 | Tower | Mount + 4 Anchor（fixed） |
| `SN_Weapon_HarpoonLauncher` | `assets/models/weapons/SN_Weapon_HarpoonLauncher.glb` | `SN_Weapon_HarpoonLauncher_Prototype` / (0, 420, 0) | 4.60 × 1.84 × 2.28 | **1908** | 5 | Medium | Yaw + Pitch + Mount + 4 Anchor |

三件合计 **7,292 三角面**（预算 14,500）；全部 zmin = 0、共享贴图外部化、UV 完整；GLB Root 的 `extras` 带 `mount_class / pivot_profile / base_footprint_* / envelope_* / height / swept_radius / anchor_count`。
- 弩炮：回转底座 + 双弩臂 + 扭力弹簧 + 弩弦 + 大型弩箭 + 后部绞盘 + 前护盾。
- 箭塔：方形底座 + 四角塔柱 + X 斜撑 + 作战平台 + 三面栏杆 + 竖缝箭窗 + 侧梯 + 帆布棚 + 箭袋/盾牌/铜钟；4 个底座拉索锚点。
- 蒸汽鱼叉：回转底座 + 黄铜压力罐 + 蒸汽管 + 发射轨 + 大型鱼叉（倒钩/尾环）+ 绞盘/链条。
- socket 契约：只标准化 Mount 帧、底座接口（collar / 方形 pad）与净空包络（footprint / height / swept_radius）；塔身、弩臂、鱼叉上部轮廓自由，不从外形做匹配。
- 源/工具：工单 `tools/modeling/briefs/sn_weapon_batch2.json`；生成器 `sn_weapon_batch2_generator.py`；干跑 `dryrun_weapon_batch2.py`；导出 `export_weapon_batch2_glb.py`；GLB 自检 `verify_weapon_batch2_glb.py`；预览 `render_weapon_batch2_preview.py`。
- 验收图：`docs/design/screenshots/weapons/weapon_batch2_lineup.png` 与 `weapon_{ballista,arrow_tower,harpoon_launcher}_*.png`。
- 本批同样不登记 manifest、不接游戏侧；Mount/Anchor 是给未来 hull socket / assembler 用的。

> 2026-10-22：武器装配规范升级 v2（`SN_Socket_Weapon` / `SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch` / `SN_Recoil` / `SN_Muzzle`），8 件舰载武器 + kit 武器部件 + 甲板 socket 已重建并重导 GLB，详见 [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md)。

## 3D 舰载武器：穿壳炮 casemate gun 模块（2026-10-22）

把铁甲舰舷侧“从船壳里伸出来”的炮从船体网格拆成独立、可复用的模块：船体只保留炮门
（框 + 深色炮口板 + 上翻门盖），炮管 + 炮口箍成为一件独立 GLB，经 12 个
`SN_Socket_GunPort_*` 挂到铁甲舰上；换炮 / 空载 / 装到别的船都走同一套 socket 契约。
契约见 [WEAPON_SOCKET_CONTRACT.md §9](WEAPON_SOCKET_CONTRACT.md)，验收见
[CASEMATE_GUN_ACCEPTANCE.md](../archive/CASEMATE_GUN_ACCEPTANCE.md)。

| 资产 | 运行时 GLB | 集合 / 摆位 | 尺寸 L×W×H (m) | tri | 材质数 | 接口 / 基准 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Weapon_CasemateGun` | `assets/models/weapons/SN_Weapon_CasemateGun.glb` | `SN_Weapon_CasemateGun_Prototype` / (0, 430, 0) | 2.4907 × 1.00 × 1.00 | **108** | 3 | 根 = **炮门平面中心**（`+X` = 炮膛轴线 / 舷外）；`port_pitch`：Mount → Pivot_Pitch（耳轴 x=−0.15）→ Recoil → Muzzle；炮管 56 tri + 门内炮尾/双耳轴 52 tri |

- 轴心与甲板武器不同：**原点在炮门平面中心**，局部 `x ≥ 0` 是门外可见段（外露 1.5407 m），
  `x < 0` 是藏在船壳里的炮尾 / 耳轴（0.95 m），后坐与 ±6…12° 俯仰都不会让隐藏段露出来。
- 几何与拆炮前的烘焙炮管**逐顶点重合**（`dryrun_casemate_gun.py` 对 12 个炮门断言，误差 0）；
  因此铁甲舰装炮后的读感与拆炮前一致，但炮管现在可换、可空载、可由战斗/装配层驱动俯仰与后坐。
- 材质：`SN_Tex_Metal` / `SN_Tex_Brass` / `SN_Tex_Iron`（3 槽，外部共享贴图）。
- 关键 extras：`assembly_profile=port_pitch`、`has_yaw=false`、`port_class=Medium`、
  `port_w/port_h=1.9/1.9`、`muzzle_protrusion=1.5407`、`breech_depth=0.95`、
  `trunnion_offset=0.15`、`elev_min/max_deg=-6/12`。
- 源/工具：`sn_casemate_gun_generator.py`、`dryrun_casemate_gun.py`、`sn_ship_gun_ports.py`、
  `glb_gun_ports.py`、`apply_casemate_assets.py`、`export_casemate_glb.py`、
  `verify_casemate_glb.py`、`render_casemate_preview.py`。
- 预览：[单件 3/4](screenshots/weapons/casemate_gun_three_quarter.png) /
  [单件正侧](screenshots/weapons/casemate_gun_side.png) /
  [装舰 3/4](screenshots/ironclad_casemate_three_quarter.png) /
  [炮列近景](screenshots/ironclad_casemate_guns_closeup.png) /
  [空炮门近景](screenshots/ironclad_casemate_empty_closeup.png)。
- 炮门框 / 深色炮口板 / 上翻门盖**逐角取放样壳面**（`hull_surface_y()`，2026-10-22 修复：边缘间隙 0.241 m → 0，tri 不变），空载近景不再浮边；炮门 socket 中心随之落在壳面上。
- 本批不登记 Core manifest 键（与武器批次 1/2 一致）；其它 3 艘船没有炮门开口，
  要给它们装穿壳炮需要先做「炮门舱段 / port cassette」适配件（后续批次）。

## 模型素材库批次 1：武器套件 + 船体部件（2026-10-21）

把「搭船 / 搭场景 / 战斗演出」的 P0 模块抽成 8 件可拼装资产：每组 4 件，每件独立 GLB，
根下固定 `Mount` + 接口空节点，根 `extras` 带 `kit_family / part_role / footprint / height`。
完整目录与装配配方见 [KIT_ASSET_LIBRARY.md](KIT_ASSET_LIBRARY.md)，机器可读目录见
[kit_catalog.json](../../tools/modeling/kit_catalog.json)。

| 资产 | 运行时 GLB | 集合 | 尺寸 X×Y×Z (m) | tri | 材质数 | 接口 / 基准 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Weapon_Cannon` | `assets/models/weapons/SN_Weapon_Cannon.glb` | `SN_Weapon_Cannon_Prototype` | 4.00 × 1.44 × 0.82 | **1156** | 5 | 根 = 耳轴轴心；Pitch + Trunnion_L/R + Muzzle + Breech |
| `SN_Weapon_GunCarriage` | `assets/models/weapons/SN_Weapon_GunCarriage.glb` | `SN_Weapon_GunCarriage_Prototype` | 2.96 × 1.79 × 1.10 | **2256** | 7 | 地面 z=0；Trunnion_L/R 在 z=0.62 |
| `SN_Weapon_Turret` | `assets/models/weapons/SN_Weapon_Turret.glb` | `SN_Weapon_Turret_Prototype` | 5.12 × 3.44 × 3.04 | **1904** | 6 | 甲板面 z=0；Yaw_Pivot z=0.22；Heavy |
| `SN_Weapon_Pedestal` | `assets/models/weapons/SN_Weapon_Pedestal.glb` | `SN_Weapon_Pedestal_Prototype` | 1.90 × 1.90 × 1.20 | **940** | 4 | 甲板面 z=0；Collar z=1.10；Medium |
| `SN_ShipPart_Deck` | `assets/models/ship_parts/SN_ShipPart_Deck.glb` | `SN_ShipPart_Deck_Prototype` | 8.40 × 6.00 × 0.36 | **576** | 4 | 底面 z=0 / 甲板面 0.33；5 个 Socket_*（weapon socket ±2.30,1.10） |
| `SN_ShipPart_Mast` | `assets/models/ship_parts/SN_ShipPart_Mast.glb` | `SN_ShipPart_Mast_Prototype` | 1.77 × 6.20 × 12.84 | **2764** | 6 | 甲板面 z=0；桅顶瞭望台 z=12.16；Top + Lookout + 双横桁 socket |
| `SN_ShipPart_Funnel` | `assets/models/ship_parts/SN_ShipPart_Funnel.glb` | `SN_ShipPart_Funnel_Prototype` | 2.40 × 2.00 × 4.66 | **1528** | 4 | 甲板面 z=0；Exhaust + Stay_1..4 |
| `SN_ShipPart_HatchCover` | `assets/models/ship_parts/SN_ShipPart_HatchCover.glb` | `SN_ShipPart_HatchCover_Prototype` | 2.72 × 2.00 × 0.49 | **840** | 6 | 甲板面 z=0；Lid_Pivot_Fwd/Aft |

八件合计 **11,964 三角面**（预算 16,500），闭合壳体、四项网格健康全 0、UV 完整、共享贴图外部化。
- 结构要点：火炮 = 12 边收分炮管 + 5 道加强箍 + 炮口箍 + 尾体/尾环/尾钮 + 双耳轴 + 准星；炮架 = 四轮炮车（辐条轮/铁轮箍/颊板/耳轴 U 型座/俯仰螺杆+手轮/侧挂炮刷）；炮塔 = 12 边铆接基座环 + 收分装甲体（12 条竖向板缝 + 3 道加固带）+ 炮口盾与炮管 + 顶部舱盖/潜望镜/通风帽；基座 = 八角安装板 + 收分柱 + 黄铜领圈 + 回转轴承；甲板 = 24 条铺板 + 四边压条 + 4 角黄铜护角 + 3 道横梁 + 6 个排水口；桅杆 = 下桅 + **桅顶瞭望台（平台/栏杆/登台长梯/黄铜望远镜）** + 上桅 + 顶桅 + 双横桁 + 支索眼板；烟囱 = 底座法兰 + 后倾收分烟囱 + 3 道铁箍 + 黄铜顶箍 + 防雨帽 + 蒸汽管/手轮 + 4 根拉索；货舱盖 = 围板 + 双开盖板 + 铁包条 + 铰链/搭扣 + 内部格栅。
- 坐标：Blender `+X` 前向、`+Z` 向上；地面类根在底面中心，火炮根 = 耳轴轴心（局部 z −0.24…0.58），单独导入时轴心在地面以上。
- 共享贴图：`assets/models/{weapons,ship_parts}/shared_materials/` + `dev_mods/core/.../shared_materials/`；`shared_materials.spec.json` 的 `runtime_dirs` 已加入 ship_parts 两处。
- 源/工具：工单 `tools/modeling/briefs/sn_kit_batch1.json`；生成器 `kit_batch1_generator.py`；部件库 `weapon_kit.py`；材质视图 `sn_kit_materials.py`；干跑 `dryrun_kit_batch1.py`；导出 `export_kit_glb.py`；GLB 自检 `verify_kit_glb.py`；预览 `render_kit_preview.py`；目录导出 `gen_kit_catalog.py`。
- 验收图：`docs/design/screenshots/kits/kit_weapon_lineup.png` / `kit_ship_parts_lineup.png` / `kit_assembly_gun.png` / `kit_assembly_deck.png` / `kit_assembly_deck_detail.png` 与 8 件 × {3/4, 侧视}。
- 本批不登记 manifest、不接运行时装配；详细验收见 [KIT_BATCH1_ACCEPTANCE.md](../archive/KIT_BATCH1_ACCEPTANCE.md)。

## 船体帆索部件库 rig_kit（M0-4，2026-10-22）

12 件独立套件，几何全部来自 `rig_kit.py`（与 PF/SF/IC 共用同一份源码）。每件 Root 下
唯一 `SN_Mount` + 语义 `SN_Socket_*`；GLB 导出后接口名归一化为标准名，Root extras 写
`rig_sockets` / `rig_socket_count` / `rig_socket_spec`。契约见
[RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md)，机器目录
[rig_kit_catalog.json](../../tools/modeling/rig_kit_catalog.json)。

| 资产 | 运行时 GLB | 集合 | 尺寸 X×Y×Z (m) | tri | 材质数 | 接口 / 基准 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Rig_Mast_Sail` | `assets/models/rig/SN_Rig_Mast_Sail.glb` | `SN_Rig_Mast_Sail_Prototype` | 1.87 × 2.90 × 21.50 | **448** | 4 | 甲板 z=0；Mount + Yard_Lower/Upper + Sail_Head/Tack + Deadeye_Port/Starboard |
| `SN_Rig_Mast_Steam` | `assets/models/rig/SN_Rig_Mast_Steam.glb` | `SN_Rig_Mast_Steam_Prototype` | 0.72 × 0.72 × 11.18 | **144** | 2 | 甲板 z=0；Mount + Yard + Stay_Fore/Aft |
| `SN_Rig_Yard` | `assets/models/rig/SN_Rig_Yard.glb` | `SN_Rig_Yard_Prototype` | 0.48 × 6.94 × 0.48 | **72** | 3 | 桁中心原点、沿 Y；Mount + Sail + Brace_Port/Starboard |
| `SN_Rig_Gaff` | `assets/models/rig/SN_Rig_Gaff.glb` | `SN_Rig_Gaff_Prototype` | 5.46 × 0.50 × 2.06 | **72** | 2 | 夹钳原点；Mount + Sail_Peak + Halyard |
| `SN_Rig_Boom` | `assets/models/rig/SN_Rig_Boom.glb` | `SN_Rig_Boom_Prototype` | 6.24 × 0.50 × 0.52 | **72** | 2 | tack 原点；Mount + Sail_Clew + Sheet |
| `SN_Rig_Bowsprit` | `assets/models/rig/SN_Rig_Bowsprit.glb` | `SN_Rig_Bowsprit_Prototype` | 4.52 × 0.52 × 2.65 | **72** | 3 | 甲板 z=0；Mount + Jib_Tack + Stay_Fore |
| `SN_Rig_Sail_Gaff` | `assets/models/rig/SN_Rig_Sail_Gaff.glb` | `SN_Rig_Sail_Gaff_Prototype` | 5.98 × 0.64 × 8.24 | **756** | 2 | tack 原点；Mount + Sail_Head/Peak/Clew（单层双面） |
| `SN_Rig_Sail_Square` | `assets/models/rig/SN_Rig_Sail_Square.glb` | `SN_Rig_Sail_Square_Prototype` | 0.62 × 6.04 × 5.64 | **624** | 2 | 帆脚中心；Mount + Yard + Sheet_Port/Starboard（单层双面） |
| `SN_Rig_Sail_Jib` | `assets/models/rig/SN_Rig_Sail_Jib.glb` | `SN_Rig_Sail_Jib_Prototype` | 5.04 × 0.47 × 7.24 | **578** | 2 | tack 原点；Mount + Sail_Head/Clew（单层双面） |
| `SN_Rig_Shrouds` | `assets/models/rig/SN_Rig_Shrouds.glb` | `SN_Rig_Shrouds_Prototype` | 2.59 × 2.55 × 7.26 | **568** | 2 | 链板 z=0；Mount + Mast_Top + Chainplate_Port/Starboard |
| `SN_Rig_Stays` | `assets/models/rig/SN_Rig_Stays.glb` | `SN_Rig_Stays_Prototype` | 9.00 × 2.94 × 7.26 | **188** | 3 | 甲板眼板 z=0；Mount + Mast_Top + Bowsprit_Tip |
| `SN_Rig_Running` | `assets/models/rig/SN_Rig_Running.glb` | `SN_Rig_Running_Prototype` | 5.09 × 6.83 × 7.22 | **180** | 2 | 甲板羊角 z=0；Mount + Mast_Top + Sail_Clew |

12 件合计 **3,774 三角面**（预算 7,050）；桅/桁/索具为闭合壳体，三种帆面是单层开放曲面
（`doubleSided`，干跑允许边界边）；GLB 合计 308.3 KB，共享贴图
`assets/models/rig/shared_materials/`（11 张）+ Core 副本。
- 源/工具：工单 `tools/modeling/briefs/sn_rig_kit_batch1.json`；库 `rig_kit.py`；生成器 `rig_kit_batch1_generator.py`；干跑 `dryrun_rig_kit.py`；导出 `export_rig_kit_glb.py`；GLB 自检 `verify_rig_kit_glb.py`；目录 `gen_rig_kit_catalog.py`。
- 本批纯资产 + 船侧 socket 契约：不接运行时 `ShipVisualAssembler`，不登记 Core manifest 键；验收见 [RIG_KIT_ACCEPTANCE.md](../archive/RIG_KIT_ACCEPTANCE.md)。

## 模型素材库批次 2：机械 / 货物 / 码头（2026-10-21）

P1 第二批 10 件：机械 3（齿轮组 / 卷扬机 / 动力装置）+ 货物 4（货箱 / 煤斗 / 储罐 / 托盘）+
码头 3（码头结构 / 栈桥 / 系缆设施）。同样每件独立 GLB + Mount + 语义 socket + 根 extras；
码头件根在水线，栈桥桩伸到 z=−1.30。完整目录与装配配方见 [KIT_ASSET_LIBRARY.md §9](KIT_ASSET_LIBRARY.md)。

| 资产 | 运行时 GLB | 集合 | 尺寸 X×Y×Z (m) | tri | 材质数 | 接口 / 基准 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Machinery_GearSet` | `assets/models/machinery/SN_Machinery_GearSet.glb` | `SN_Machinery_GearSet_Prototype` | 1.90 × 1.12 × 1.06 | **2020** | 5 | 地面 z=0；Shaft_In/Out + Crank |
| `SN_Machinery_Winch` | `assets/models/machinery/SN_Machinery_Winch.glb` | `SN_Machinery_Winch_Prototype` | 2.24 × 1.82 × 1.42 | **1776** | 7 | 地面 z=0；Drum_Pivot + Rope_Out |
| `SN_Machinery_PowerUnit` | `assets/models/machinery/SN_Machinery_PowerUnit.glb` | `SN_Machinery_PowerUnit_Prototype` | 3.78 × 1.44 × 2.11 | **2260** | 7 | 地面 z=0；Shaft_Out + Steam_In + Exhaust_Out |
| `SN_Cargo_Crate` | `assets/models/cargo/SN_Cargo_Crate.glb` | `SN_Cargo_Crate_Prototype` | 1.26 × 1.19 × 1.04 | **672** | 8 | 地面 z=0；Stack_Top z=1.02 |
| `SN_Cargo_CoalScuttle` | `assets/models/cargo/SN_Cargo_CoalScuttle.glb` | `SN_Cargo_CoalScuttle_Prototype` | 1.48 × 1.14 × 1.10 | **588** | 8 | 地面 z=0；Fill_Top；含 SN_Tex_Coal |
| `SN_Cargo_Tank` | `assets/models/cargo/SN_Cargo_Tank.glb` | `SN_Cargo_Tank_Prototype` | 3.37 × 1.60 × 1.95 | **1820** | 5 | 地面 z=0；Fill_Top + Outlet + Vent |
| `SN_Cargo_Pallet` | `assets/models/cargo/SN_Cargo_Pallet.glb` | `SN_Cargo_Pallet_Prototype` | 1.23 × 1.02 × 0.18 | **316** | 5 | 地面 z=0；Stack_Top z=0.18 |
| `SN_Dock_Structure` | `assets/models/dock/SN_Dock_Structure.glb` | `SN_Dock_Structure_Prototype` | 8.40 × 4.46 × 3.16 | **1628** | 3 | 水线 z=0；Module_Next/Prev + Mooring + Jetty socket |
| `SN_Dock_Jetty` | `assets/models/dock/SN_Dock_Jetty.glb` | `SN_Dock_Jetty_Prototype` | 8.03 × 2.66 × 2.80 | **1660** | 5 | 水线 z=0；桥面 1.30；桩到 −1.30；Module sockets |
| `SN_Dock_Mooring` | `assets/models/dock/SN_Dock_Mooring.glb` | `SN_Dock_Mooring_Prototype` | 1.56 × 1.15 × 0.95 | **940** | 5 | 甲板面 z=0；Bitt/Ring/Rope_Tie |

批次 2 合计 **13,680 三角面**（预算 20,600）；两批合计 **25,644 / 37,100**。
- 新增共享贴图 `SN_Tex_Coal`（512² 无缝碎煤），spec / 生成器 / runtime_dirs 已同步；`shared_materials` 现为 12 张（2026-10-24 新增 `SN_Tex_Copper_Green` 铜绿屋面）。
- 结构要点：齿轮组 = 开式机架 + 三级齿轮（24/14/12 齿）+ 三轴 + 轴承 + 手摇曲柄；卷扬机 = 木铁底座 + A 形机架 + 缠绳绳鼓 + 棘轮/棘爪 + 刹车带 + 曲柄 + 吊钩；动力装置 = 滑橇 + 卧式汽缸 + 活塞/十字头/连杆 + 飞轮 + 阀箱/手轮 + 蒸汽管/排气管 + 压力表 + 调速器；货箱 = 板条箱体 + 铁包角/铁带 + 黄铜铭牌 + 提手；煤斗 = 收分铁斗 + 碎煤堆 + 双轮 + 支腿 + 拉手 + 出料滑槽；储罐 = 卧式铆接罐 + 双鞍座 + 3 道红箍 + 人孔 + 黄铜阀 + 排气管；托盘 = 7 板条 / 3 纵梁 / 3 垫块 / 铁包角；码头结构 = 石砌岸壁 + 顶面铺石 + 木压顶 + 4 护舷 + 系缆环 + 爬梯；栈桥 = 8 桩 + 纵梁/横梁/斜撑 + 21 铺板 + 端部爬梯；系缆设施 = 双柱缆桩 + 横档 + 系缆环 + 链条 + 绳圈 + 木护舷。
- 源/工具：工单 `tools/modeling/briefs/sn_kit_batch2.json`；生成器 `kit_batch2_generator.py`；材质视图 `sn_kit_materials.py`；干跑 `dryrun_kit_batch2.py`；导出 `export_kit_batch2_glb.py`；GLB 自检 `verify_kit_batch2_glb.py`；预览 `render_kit_batch2_preview.py`；目录 `gen_kit_catalog.py`（合并两批）。
- 验收图：`docs/design/screenshots/kits/kit_machinery_lineup.png` / `kit_cargo_lineup.png` / `kit_dock_lineup.png` / `kit_assembly_dock.png` / `kit_assembly_dock_detail.png` 与 10 件 × {3/4, 侧视}。
- 本批不登记 manifest、不接运行时装配；详细验收见 [KIT_BATCH2_ACCEPTANCE.md](../archive/KIT_BATCH2_ACCEPTANCE.md)。

## 模型素材库批次 3：建筑 / 环境（2026-10-21）

P2 第三批 8 件：建筑 4（仓库 / 工坊 / 酒馆 / 厂房）+ 环境 4（礁石 / 残骸 / 灯塔 / 航标浮标）。
建筑按 4 m 网格拼装（`Module_Next/Prev` 沿 X 平铺），环境件根在水线；同样每件独立 GLB +
Mount + 语义 socket + 根 extras（建筑另写 `module_x/y`，环境件另写 `waterline`）。
完整目录与装配配方见 [KIT_ASSET_LIBRARY.md §10](KIT_ASSET_LIBRARY.md)。

| 资产 | 运行时 GLB | 集合 | 尺寸 X×Y×Z (m) | tri | 材质数 | 接口 / 基准 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Arch_Warehouse` | `assets/models/architecture/SN_Arch_Warehouse.glb` | `SN_Arch_Warehouse_Prototype` | 10.95 × 6.95 × 6.35 | **2704** | 8 | 地面 z=0；Module ±4 + Door/Hoist/Sign |
| `SN_Arch_Workshop` | `assets/models/architecture/SN_Arch_Workshop.glb` | `SN_Arch_Workshop_Prototype` | 9.32 × 6.63 × 7.04 | **1996** | 9 | 地面 z=0；Drive_Shaft(−1,−3.08,1.45) 接动力装置 |
| `SN_Arch_Tavern` | `assets/models/architecture/SN_Arch_Tavern.glb` | `SN_Arch_Tavern_Prototype` | 8.67 × 6.96 × 7.64 | **2884** | 9 | 地面 z=0；门廊 + 阳台 + 悬挑招牌 |
| `SN_Arch_Factory` | `assets/models/architecture/SN_Arch_Factory.glb` | `SN_Arch_Factory_Prototype` | 14.74 × 8.30 × 9.64 | **3020** | 8 | 地面 z=0；锯齿顶 + 双烟囱 + Gantry |
| `SN_Env_Reef` | `assets/models/environment/SN_Env_Reef.glb` | `SN_Env_Reef_Prototype` | 7.13 × 6.44 × 5.52 | **1944** | 3 | 水线 z=0；Top 落座灯塔（4.6 m 石砌基台） |
| `SN_Env_Wreck` | `assets/models/environment/SN_Env_Wreck.glb` | `SN_Env_Wreck_Prototype` | 8.62 × 3.96 × 4.72 | **1046** | 7 | 水线 z=0；船底 −1.50；横倾 13°；断桅穿龙骨 |
| `SN_Env_Lighthouse` | `assets/models/environment/SN_Env_Lighthouse.glb` | `SN_Env_Lighthouse_Prototype` | 4.62 × 4.60 × 13.16 | **1952** | 7 | 基座 z=0；环廊 / 灯室 / 穹顶 |
| `SN_Env_Buoy` | `assets/models/environment/SN_Env_Buoy.glb` | `SN_Env_Buoy_Prototype` | 1.88 × 1.88 × 3.84 | **868** | 5 | 水线 z=0；吃水裙 −0.74；Lamp/Bell/Chain |

批次 3 合计 **16,414 三角面**（预算 23,200）；三批合计 **42,058 / 60,300**。
- 结构要点：仓库 = 石基座 + 铁包木墙 + 双坡铁皮顶 + 滑门/雨棚/吊货梁；工坊 = 采光顶（monitor roof）+ 高烟囱 + 双开大门 + 外墙飞轮与皮带；酒馆 = 石首层 + 悬挑木二层 + 门廊/阳台/悬挑招牌/凸窗；厂房 = 4 跨锯齿采光顶 + 双烟囱 + 双滑门 + 外置吊车梁与装卸平台；礁石 = 宽平礁顶 + 石砌灯塔基台 + 水线上下礁石 + 潮痕面 + 倾斜礁板 + 系缆环；残骸 = 横倾断裂船壳 + 外露肋骨 + 断桅（穿甲板落龙骨）+ 压舱石；灯塔 = 八边形基座 + 收分石塔 + 环廊 + 灯室 + 穹顶 + 避雷针；浮标 = 浮筒 + 吃水裙 + 灯架 + 黄铜钟 + 锚链。
- 源/工具：工单 `tools/modeling/briefs/sn_kit_batch3.json`；生成器 `kit_batch3_generator.py`；材质视图 `sn_kit_materials.py`；干跑 `dryrun_kit_batch3.py`；导出 `export_kit_batch3_glb.py`；GLB 自检 `verify_kit_batch3_glb.py`；预览 `render_kit_batch3_preview.py`；目录 `gen_kit_catalog.py`（合并三批）。
- 验收图：`docs/design/screenshots/kits/kit_architecture_lineup.png` / `kit_environment_lineup.png` / `kit_assembly_town.png` / `kit_assembly_town_detail.png` / `kit_assembly_coast.png` / `kit_assembly_coast_detail.png` 与 8 件 × {3/4, 侧视}。
- 本批不登记 manifest、不接运行时装配；详细验收见 [KIT_BATCH3_ACCEPTANCE.md](../archive/KIT_BATCH3_ACCEPTANCE.md)。
- 共享贴图：`assets/models/{architecture,environment}/shared_materials/` + `dev_mods/core/.../shared_materials/`；`shared_materials.spec.json` 的 `runtime_dirs` 已扩到 16 个目录（12 张贴图；2026-10-24 新增 `SN_Tex_Copper_Green`，本批无新增）。

## 大型港口航站楼 `SN_Grand_Harbour_Terminal`（2026-10-24）

按用户参考图制作的大型港口航站楼（非现有 PortStage 槽位资产，暂不登记 manifest / 不接运行时装配）：
中央 15 m 宽三拱门廊 + 8 m 深玻璃门厅 + 四向钟楼 + 铜绿四坡顶 + 两翼连续拱廊 + 端部亭阁 + 海堤广场与 6 级大台阶。
1 unit = 1 m；根 `SN_GHT_Root` 在平台地面中心 `(0, −330, 0)`，`+X` 为正面、`+Z` 向上。

| 项 | 值 |
| --- | --- |
| 运行时 GLB | `assets/models/architecture/SN_Grand_Harbour_Terminal.glb` + `dev_mods/core` 副本 |
| 集合 | `SN_GHT_Grand_Harbour_Terminal_Prototype` |
| 尺寸 X×Y×Z | **72.45 × 133.70 × 56.65 m**（z=0..56.65） |
| 节点 / 网格 | **17 / 16**（root 空物体 + 15 结构 mesh + `SN_GHT_Sign` 文字 mesh） |
| 三角面 | **59,450**（geometry 58,072 + sign 1,378）/ 预算 90,000 |
| 材质 | 9 个 `SN_Tex_*`：Stone / Copper_Green / Iron / Iron_Red / Wood / Wood_Dark / Brass / Glass_Dark / Canvas_Shade |
| 文件 | GLB 3,991,540 B；`.design/architecture/SN_Grand_Harbour_Terminal.blend` 本地快照；`.design/terminal/build_report.json` |
| 验收 | `verify_grand_harbour_terminal_glb.py` **ALL OK**；结构 mesh 边界/非流形/退化/孤立点全 0；UV 16/16；9 张外部共享贴图 |
| 预览 | `docs/design/screenshots/architecture/grand_terminal_{three_quarter,front,aerial,entrance_detail}.png` |
| 源 / 工具 | 工单 `tools/modeling/briefs/sn_grand_harbour_terminal.json`；生成器 `sn_grand_harbour_terminal_generator.py`；干跑 `dryrun_grand_harbour_terminal.py`；导出 `export_grand_harbour_terminal_glb.py`；GLB 验收 `verify_grand_harbour_terminal_glb.py`；预览 `render_grand_harbour_terminal_preview.py` |

- 新增共享材质 `SN_Tex_Copper_Green`（第 12 张共享贴图，`verdigris` 画家：低对比云斑 + 细竖向雨痕 + 极少量露铜点，无 1 m 网格/大锈斑，避免大屋面平铺感），旧 11 张 tile 字节未变；`shared_materials.spec.json` / runtime_dirs / `sn_kit_materials.MAT_COPPER_GREEN` 已同步。
- 设计要点：中央拱门是真实 8 m 深凹洞（不是贴片），玻璃幕墙 + 黄铜竖棂 + 玫瑰窗 + 双扇木门；两翼 6 跨拱廊为真实墩柱 + 拱券；钟楼四向钟盘 + 鼓座 + 16 肋铜穹顶 + 采光亭 + 旗；正立面黄铜铭牌 `HARBOUR TERMINAL`。檐口为三层退台，**按用户要求不排齿饰**；用户指出副楼转角竖向隅石远看像锯齿后，**两翼 / 端亭 / 中央主楼的隅石全部移除**，所有转角为平直石墙转角。
- UV 去重复（2026-10-24 用户反馈“材质平铺感太重”）：**不改共享材质 spec**，只在 `SN_GHT_` 这套 mesh 的 `UVMap` 上做后处理——石/铜 UV 周期乘 0.45–0.60（有效 tile 约 3.3–4.6 m，砌块/铜板变大、重复频率下降）+ 每对象 ±10% 周期差 + SHA256 确定性 UV 偏移（切断相邻体量同频）；玻璃/木/黄铜保持原 UV。实测 Central_Block 12.4 × 19.8 m 墙 tile=4.59 m，无 NaN/拉伸。铜绿屋面另改用 `verdigris` 画家（低对比云斑 + 淡雨痕 + 少量小露铜点，无 1 m 网格/大锈斑），解决大屋面平铺感。
- **已接入当前港口舞台（主场景门面）**：`dev_mods/core/content/port_templates.json` 的 `iron_harbor` diorama 增加 `landmark: "model.building.grand_harbour_terminal"`；`PortViewQuery` 将其解析为物理 GLB 路径，`PortStage` 以 **scale 0.42 / yaw −90° / position (0, 1.9, −24)** 放在港口中轴、town row 前方；固定机位改为**垂直于码头、沿 −Z 看向港口**（harbor 相机 x=0、target x=0；market/shipyard/supply 同样相机与目标同 X 的正视构图）。
  - **最小门面模式**：landmark GLB **成功实例化**后才进入该模式（`landmark_path` 存在但加载失败时回退正常港区，不会剩一座几乎空的港）；模式内只保留 terminal、水/码头/天空、12 件小装饰（4 盏煤气灯、2 货箱、2 木桶、4 系缆桩）与 **3 艘氛围小艇**（2 rowboat + 1 cargo_lighter，复用 town kit、随静态合批），移除城镇建筑/市场/起重机/前景黑框/手绘 skyline 与 banner。设施锚点仍保留为空节点供 UI 热点定位，不渲染设施模型。**玩家船照常挂载**（玩家反馈 #5）：船位沿用站位相对偏移（market/harbor/supply = 站位中心 −13.5，shipyard = 14.5），泊位 z 由 9 收到 6 把水线拉进画面，`MINIMAL_SHIP_SCALE = 0.75` 让真尺度船体在 0.42 缩放 terminal 前仍读作「泊船」；船体照旧刚性合批并重算泡沫 AABB，`ShipSteam` 保留并锚到缩放后的船顶（Quay/ShoreSteam 与前景黑框隐藏）。manifest 新增 `model.building.grand_harbour_terminal`。端到端截图见 `docs/design/screenshots/port_stage/port_stage_preview.png`，测试 `test_stage_host.gd` 断言 landmark 路径/挂载、最小装饰 + 氛围船数量、玩家船挂载/缩放/泊位/合批/泡沫、离港入港 beat，以及缺 landmark 时回退正常港区仍出船。
- 已知非阻塞项：文字 mesh `SN_GHT_Sign` 因字体挤出固有 6 条零面积细缝边界边（不可见、无退化面）；Web 预览/导出路径仍使用 loose `dev_mods` 原始 GLB 外部贴图读取（发布包内需按 ContentAssetLoader 的共享贴图路径）。

## 模型素材库批次 4：architecture_kit 扩展 / 可围合基地（M1-1，2026-10-22）

backlog `M1-1` 的 6 件「可围合 + 生产性立面」建筑扩展件：围墙段 / 大门 / 道路 / 装卸平台 /
仓库变体 / 工坊扩建。沿用批次 1–3 的 Mount + 语义 socket + 根 extras 契约，4 m 网格沿 X 平铺，
可把批次 3 的 4 栋建筑围成基地，也可单独作港口/舞台建筑。完整目录、接口与装配配方见
[KIT_ASSET_LIBRARY.md §12](KIT_ASSET_LIBRARY.md)；工单
`tools/modeling/briefs/sn_kit_batch4_architecture_extension.json`。

| 资产 | 运行时 GLB | 集合 | 尺寸 X×Y×Z (m) | tri | 材质数 | 接口 / 基准 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Arch_Perimeter_Wall` | `assets/models/architecture/SN_Arch_Perimeter_Wall.glb` | `SN_Arch_Perimeter_Wall_Prototype` | 8.36 × 3.90 × 1.46 | **1 436** | 7 | 地面 z=0；Module ±4 + Wall_Top + Lantern |
| `SN_Arch_Gate` | `assets/models/architecture/SN_Arch_Gate.glb` | `SN_Arch_Gate_Prototype` | 8.40 × 5.34 × 2.30 | **2 112** | 7 | 地面 z=0；Gateway + Door_Hinge_L/R + Hoist |
| `SN_Arch_Road` | `assets/models/architecture/SN_Arch_Road.glb` | `SN_Arch_Road_Prototype` | 8.00 × 0.29 × 8.00 | **1 368** | 5 | 地面 z=0；四向 Module_Next/Prev/Left/Right |
| `SN_Arch_Loading_Platform` | `assets/models/architecture/SN_Arch_Loading_Platform.glb` | `SN_Arch_Loading_Platform_Prototype` | 10.95 × 5.25 × 6.20 | **1 552** | 8 | 月台面 1.25 m；Dock_Edge/Hoist/Stair_Foot |
| `SN_Arch_Warehouse_Variant` | `assets/models/architecture/SN_Arch_Warehouse_Variant.glb` | `SN_Arch_Warehouse_Variant_Prototype` | 11.80 × 8.55 × 8.51 | **4 216** | 9 | Door_Front/Hoist/Sign + 14 级外楼梯上 3.48 m 侧门 |
| `SN_Arch_Workshop_Annex` | `assets/models/architecture/SN_Arch_Workshop_Annex.glb` | `SN_Arch_Workshop_Annex_Prototype` | 6.61 × 7.15 × 5.74 | **1 900** | 8 | Drive_Shaft(+Y, z=1.45) 接工坊 / Chimney / Coal_Hatch |

（尺寸按 GLB 的 glTF Y-up 口径：X × Y × Z；Blender 口径见 §12.1。）
批次 4 合计 **12,584 三角面 / 16,800 预算**、39 mesh、37 socket、82 节点、117 图元，GLB 合计 966,464 B；
材质沿用既有 11 张共享贴图（无新增），`architecture/shared_materials/` 与 Core 副本各 11 张。
- 结构要点：围墙 = 石基座 + 铆接铁板墙 + 端部立柱 + 石压顶/铁披檐 + 三处射击孔 + 黄铜壁灯；大门 = 双侧铁包石柱 + 铆接门楣 + 双扇铁木门（关闭）+ 抬起吊闸 + 垛口 + 门灯 + 石门槛；道路 = 8×8 石板 + 4 处红铁修补片 + 双侧铁篦排水沟 + 路缘条石 + 铜钉；装卸平台 = 石砌月台（面 1.25 m）+ 木铺面 + 护舷/系缆桩 + 四柱铁雨棚 + 外挑吊货梁/滑轮/吊钩 + 5 级木楼梯；仓库变体 = 石砌下层 + 木构上层 + 山墙双坡铁皮顶 + 山墙装载门 + 上层吊货门/吊梁 + 铁框高窗 + 14 级外楼梯 + 招牌；工坊扩建 = 锅炉房 + 双坡顶 + 石烟囱/汽管 + +Y 传动轴飞轮 + 斜置送煤槽/煤堆 + 压力表/蒸汽管。
- 源/工具：生成器 `kit_batch4_generator.py`；干跑 `dryrun_kit_batch4.py`；导出 `export_kit_batch4_glb.py`；GLB 自检 `verify_kit_batch4_glb.py`（6/6 ALL OK）；预览 `render_kit_batch4_preview.py`；目录 `gen_kit_catalog.py`（v1.4，32 件 / 54,642 tri，4 条新配方）。
- 验收图：`docs/design/screenshots/kits/kit_architecture_extension_lineup.png` / `kit_architecture_extension_assembly.png` / `kit_architecture_extension_assembly_detail.png` 与 6 件 × {3/4, 侧视}。
- Godot 运行时：`framework/tests/cases/test_architecture_extension_assets.gd` 2 例（外链共享贴图 + tri 锁定 12,584、跨 6 件同一 `Texture2D` 实例）。
- 本批不登记 manifest、不接运行时装配（同 kit 批次 1–3，走 `kit_catalog.json`）；LOD1 未做（后续批次按 M0-5 派生）。

## 模型素材库批次 5：base_kit 生产建筑（M1-2，2026-10-22）

backlog `M1-2` 的 5 件基地生产建筑：锯木厂 / 冶炼炉 / 铸造车间 / 仓库堆场 / 防御塔。
与 `machinery_kit`、`cargo_kit`、批次 4 的边界件拼装成生产链基地。完整目录、接口与装配配方见
[KIT_ASSET_LIBRARY.md §13](KIT_ASSET_LIBRARY.md)；工单
`tools/modeling/briefs/sn_kit_batch5_base_kit.json`。

| 资产 | 运行时 GLB | 集合 | 尺寸 X×Y×Z (m, Blender) | tri | 材质数 | 接口 / 基准 |
| --- | --- | --- | --- | ---: | ---: | --- |
| `SN_Base_Sawmill` | `assets/models/base/SN_Base_Sawmill.glb` | `SN_Base_Sawmill_Prototype` | 11.30 × 7.54 × 6.05 | **2 684** | 9 | 地面 z=0；Drive_Shaft / Log_Input / Timber_Output |
| `SN_Base_Smelter` | `assets/models/base/SN_Base_Smelter.glb` | `SN_Base_Smelter_Prototype` | 9.10 × 7.72 × 11.40 | **3 012** | 7 | 地面 z=0；Coal/Ore_Input、Molten_Out、Chimney 11.40 |
| `SN_Base_Foundry` | `assets/models/base/SN_Base_Foundry.glb` | `SN_Base_Foundry_Prototype` | 12.95 × 8.55 × 9.15 | **4 096** | 9 | 地面 z=0；Door_Front / Hoist / Molten_In / Pour_Point |
| `SN_Base_Stockyard` | `assets/models/base/SN_Base_Stockyard.glb` | `SN_Base_Stockyard_Prototype` | 13.20 × 11.00 × 6.20 | **3 260** | 11 | 地面 z=0；Gate_In / Hoist / Scale 0.30 / Storage |
| `SN_Base_Defense_Tower` | `assets/models/base/SN_Base_Defense_Tower.glb` | `SN_Base_Defense_Tower_Prototype` | 7.50 × 7.26 × 12.25 | **2 896** | 8 | 地面 z=0；Weapon_Mount 9.20 / Searchlight / Flag / Magazine |

批次 5 合计 **15 948 三角面 / 19 000 预算**、42 mesh、37 socket、84 节点、159 图元，
GLB 合计 1 212 768 B；材质沿用既有 11 张共享贴图（无新增），新类别目录 `assets/models/base/`
+ Core 副本各 11 张 PNG（`shared_materials.spec.json` 的 `runtime_dirs` 已追加）。
- 结构要点：锯木厂 = 半开敞锯棚（后墙铁板/侧墙木构/前开敞立柱）+ 双坡铁皮顶 + 立式锯盘（齿圈/护罩/主轴）+ 进料辊道/原木坡道 + 木料堆 + 锯屑槽 + +Y 传动轴皮带轮；冶炼炉 = 石砌收分高炉（铁箍/风口/出渣口/出铁沟）+ 上料平台与围栏 + 上料斜桥/斜斗 + 双热风炉与热风管 + 煤/矿料仓 + 高烟囱（上升管接炉顶）；铸造车间 = 铁包木厂房（采光顶/石腰线/石门套滑门/门头招牌）+ 冲天炉 + 纵向行车梁/吊钩/浇包 + 浇注坑与模具台/砂箱 + 砂料仓；仓库堆场 = 12×10 石铺堆场 + 三面铁围栏与 +X 双扇门 + 木料/木箱/煤堆/矿石堆分区 + A 形龙门吊 + 地磅/读数表 + 门卫小亭 + 灯柱；防御塔 = 三级收分石塔（铁箍/射孔/角扶壁/底层铁门）+ 炮位平台与垛口（中央武器底座/探照灯/旗杆）+ 弹药库 + 外部铁梯（护笼 + 登台过桥）。
- 源/工具：生成器 `kit_batch5_generator.py`；干跑 `dryrun_kit_batch5.py`；导出 `export_kit_batch5_glb.py`；GLB 自检 `verify_kit_batch5_glb.py`（5/5 ALL OK）；预览 `render_kit_batch5_preview.py`；目录 `gen_kit_catalog.py`（v1.5，37 件 / 70 590 tri，4 条生产链配方）。
- 验收图：`docs/design/screenshots/kits/kit_base_lineup.png` / `kit_base_assembly.png` / `kit_base_assembly_detail.png` 与 5 件 × {3/4, 侧视}。
- Godot 运行时：`framework/tests/cases/test_base_kit_assets.gd` 2 例（外链共享贴图 + tri 锁定 15 948、跨 5 件同一 `Texture2D` 实例）。
- 本批不登记 manifest、不接运行时装配；防御塔只提供炮位/灯/弹药库接口，不含武器本体；LOD1 未做。

## LOD1 基础套件（M0-5，2026-10-22）

backlog `M0-5` 的剩余 **30 件**远景低模：kit 26 件 + 4 艘可玩船。全部由 LOD0 在工作台里派生（`Decimate(collapse)` + 小件保留 + 单 mesh 合并 + 包围盒逐轴钉死 + 盒式 UV 重投影），每件是单根节点 / 单 mesh 的 `SN_<Asset>_LOD1`，贴图走各类别已有的 `shared_materials/<texture>.png` 外部 URI。铁港建筑 8 个 LOD1（8 栋 × LOD0/LOD1 = 16 个 GLB）已在前序批次交付，见上节。派生契约 / 工具链见 [KIT_ASSET_LIBRARY.md §11](KIT_ASSET_LIBRARY.md)，验收见 [LOD1_BASE_KIT_ACCEPTANCE.md](../archive/LOD1_BASE_KIT_ACCEPTANCE.md)。

| 资产 | 类别 | LOD0 tri | LOD1 tri | 比例 | LOD1 GLB |
| --- | --- | ---: | ---: | ---: | --- |
| `SN_Weapon_Cannon` | weapons | 1 156 | 336 | 29.07 % | `assets/models/weapons/SN_Weapon_Cannon_LOD1.glb` |
| `SN_Weapon_GunCarriage` | weapons | 2 256 | 596 | 26.42 % | `assets/models/weapons/SN_Weapon_GunCarriage_LOD1.glb` |
| `SN_Weapon_Turret` | weapons | 1 904 | 482 | 25.32 % | `assets/models/weapons/SN_Weapon_Turret_LOD1.glb` |
| `SN_Weapon_Pedestal` | weapons | 940 | 246 | 26.17 % | `assets/models/weapons/SN_Weapon_Pedestal_LOD1.glb` |
| `SN_ShipPart_Deck` | ship_parts | 576 | 142 | 24.65 % | `assets/models/ship_parts/SN_ShipPart_Deck_LOD1.glb` |
| `SN_ShipPart_Mast` | ship_parts | 2 764 | 780 | 28.22 % | `assets/models/ship_parts/SN_ShipPart_Mast_LOD1.glb` |
| `SN_ShipPart_Funnel` | ship_parts | 1 528 | 392 | 25.65 % | `assets/models/ship_parts/SN_ShipPart_Funnel_LOD1.glb` |
| `SN_ShipPart_HatchCover` | ship_parts | 840 | 210 | 25.00 % | `assets/models/ship_parts/SN_ShipPart_HatchCover_LOD1.glb` |
| `SN_Machinery_GearSet` | machinery | 2 020 | 494 | 24.46 % | `assets/models/machinery/SN_Machinery_GearSet_LOD1.glb` |
| `SN_Machinery_Winch` | machinery | 1 776 | 498 | 28.04 % | `assets/models/machinery/SN_Machinery_Winch_LOD1.glb` |
| `SN_Machinery_PowerUnit` | machinery | 2 260 | 618 | 27.35 % | `assets/models/machinery/SN_Machinery_PowerUnit_LOD1.glb` |
| `SN_Cargo_Crate` | cargo | 672 | 150 | 22.32 % | `assets/models/cargo/SN_Cargo_Crate_LOD1.glb` |
| `SN_Cargo_CoalScuttle` | cargo | 588 | 146 | 24.83 % | `assets/models/cargo/SN_Cargo_CoalScuttle_LOD1.glb` |
| `SN_Cargo_Tank` | cargo | 1 820 | 462 | 25.38 % | `assets/models/cargo/SN_Cargo_Tank_LOD1.glb` |
| `SN_Cargo_Pallet` | cargo | 316 | 84 | 26.58 % | `assets/models/cargo/SN_Cargo_Pallet_LOD1.glb` |
| `SN_Dock_Structure` | dock | 1 628 | 434 | 26.66 % | `assets/models/dock/SN_Dock_Structure_LOD1.glb` |
| `SN_Dock_Jetty` | dock | 1 660 | 468 | 28.19 % | `assets/models/dock/SN_Dock_Jetty_LOD1.glb` |
| `SN_Dock_Mooring` | dock | 940 | 286 | 30.43 % | `assets/models/dock/SN_Dock_Mooring_LOD1.glb` |
| `SN_Arch_Warehouse` | architecture | 2 704 | 626 | 23.15 % | `assets/models/architecture/SN_Arch_Warehouse_LOD1.glb` |
| `SN_Arch_Workshop` | architecture | 1 996 | 444 | 22.24 % | `assets/models/architecture/SN_Arch_Workshop_LOD1.glb` |
| `SN_Arch_Tavern` | architecture | 2 884 | 600 | 20.80 % | `assets/models/architecture/SN_Arch_Tavern_LOD1.glb` |
| `SN_Arch_Factory` | architecture | 3 020 | 768 | 25.43 % | `assets/models/architecture/SN_Arch_Factory_LOD1.glb` |
| `SN_Env_Reef` | environment | 1 944 | 556 | 28.60 % | `assets/models/environment/SN_Env_Reef_LOD1.glb` |
| `SN_Env_Wreck` | environment | 1 046 | 268 | 25.62 % | `assets/models/environment/SN_Env_Wreck_LOD1.glb` |
| `SN_Env_Lighthouse` | environment | 1 952 | 482 | 24.69 % | `assets/models/environment/SN_Env_Lighthouse_LOD1.glb` |
| `SN_Env_Buoy` | environment | 868 | 256 | 29.49 % | `assets/models/environment/SN_Env_Buoy_LOD1.glb` |
| `SN_Paddle_Freighter` | ships | 12 200 | 2 507 | 20.55 % | `assets/models/ships/SN_Paddle_Freighter_LOD1.glb` |
| `SN_Paddle_Steamer` | ships | 11 764 | 2 379 | 20.22 % | `assets/models/ships/SN_Paddle_Steamer_LOD1.glb` |
| `SN_Schooner_Fame` | ships | 13 174 | 2 484 | 18.86 % | `assets/models/ships/SN_Schooner_Fame_LOD1.glb` |
| `SN_Ironclad` | ships | 8 158 | 1 656 | 20.30 % | `assets/models/ships/SN_Ironclad_LOD1.glb` |
| **kit 小计（26 件）** | — | **42 058** | **10 824** | **25.7 %** | 上限 = LOD0 × 35 % |
| **船小计（4 件）** | — | **45 296** | **9 026** | **19.9 %** | 上限 = LOD0 × 30 % |
| **合计（30 件）** | — | **87 354** | **19 850** | **22.7 %** | 外部共享贴图（LOD0 含 2026-10-22 casemate 批次铁甲舰 −672 tri） |

- 共享贴图：30 个 GLB 的 `images[].uri` 全部指向 `assets/models/<category>/shared_materials/<texture>.png`（8 个类别目录 × 11 张，另有 `dev_mods/core/...` 副本）；175 个 image 引用全部与授权 tile 逐字节一致，无新增贴图。
- 结构：30/30 单根节点 `<Asset>_LOD1`、单 mesh、每个 primitive 带 UV、材质是 LOD0 `SN_Tex_*` 集合的子集；LOD0↔LOD1 世界包围盒逐轴 0.000 m（复算最大 1×10⁻⁶ m）。**LOD1 不保留 socket / pivot / 层级**——远景不参与装配，装配契约只属于 LOD0。
- 登记：船的 4 个 LOD1 进 Core manifest（`model.ship.{ironclad,paddle_freighter,paddle_steamer,schooner_fame}_lod1`）；kit 26 件的 LOD1 同 kit LOD0 一样**不登记 manifest**，登记在 [kit_catalog.json](../../tools/modeling/kit_catalog.json) v1.3 的逐件 `lod1` 块与顶层 `lod1` 段（26 件 / 10 824 tri / 1 236 344 B）。
- **运行时 LOD 切换未接线**：与批次 A 同一口径，只交付可被质量档位使用的资产；切换阈值、低配回退与 LOD2 / impostor 留给 backlog `M2-5` 与 [todo.md](../../todo.md)。
- 验收证据：结构验收 30/30（单根节点 / 单 mesh / UV / 材质 / bbox / 外部贴图）；Godot 运行时探针 `tools/godot/verify_lod1_kit_ships.gd` **30 件 / 67 个共享贴图实例 / 0 失败**，全量无头测试 **391 passed / 0 failed**（新增 `framework/tests/cases/test_lod1_assets.gd` 3 例）。详见 [LOD1_BASE_KIT_ACCEPTANCE.md](../archive/LOD1_BASE_KIT_ACCEPTANCE.md)。
- 机器计划：`tools/modeling/lod1_kit_ships_plan.json`（30 件 tri / 比例 / 上限 / 路径 / bbox / 材质 / 字节 / sha256 + 总账）。构建 / 预览在工作台 `SN_LOD1_Kit_Ships` 集合（y=780），本批未重存 `.design/SN_Asset_Workbench.blend`。
- 预览：8 张类别 lineup（1440×620）[weapons](screenshots/lod1/LOD1_lineup_weapons_1440x620.png) / [ship_parts](screenshots/lod1/LOD1_lineup_ship_parts_1440x620.png) / [machinery](screenshots/lod1/LOD1_lineup_machinery_1440x620.png) / [cargo](screenshots/lod1/LOD1_lineup_cargo_1440x620.png) / [dock](screenshots/lod1/LOD1_lineup_dock_1440x620.png) / [architecture](screenshots/lod1/LOD1_lineup_architecture_1440x620.png) / [environment](screenshots/lod1/LOD1_lineup_environment_1440x620.png) / [ships](screenshots/lod1/LOD1_lineup_ships_1440x620.png)；30 张 LOD0 vs LOD1 同机位对比在 `docs/design/screenshots/lod1/SN_<Asset>_LOD0_vs_LOD1_three_quarter_1024x640.png`。

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

淡水实体继续使用既有 `icon.water` 贴图。Core manifest 当前声明 **179 个资源键**（含街景第一批 10 个 `model.prop.*`，见「3D 港口街景」章节；起重机三件新资产 `model.prop.mega_gantry` / `model.prop.wooden_mast_crane` / `model.prop.hand_jib_crane`；M0-5 新增 4 个船体 LOD1 键 `model.ship.*_lod1`，kit 26 件 LOD1 登记在 [kit_catalog.json](../../tools/modeling/kit_catalog.json) 而非 manifest；另有本批 30 个 `icon.ui.*`，见下）。

### UI 图标资源键（`icon.ui.*`，30 个）

`docs/design/ui_icons_v1/` 的 30 枚 UI 图标（导航 / 资源 / 船厂分类 / 动作 / 状态）已从 `assets/ui/skin/sn_v1/icons/` 复制进 Core 包内，并登记为 `icon.ui.<id>` 资源键（`<id>` 与 [ui_icons_v1/manifest.json](ui_icons_v1/manifest.json) 的 `assets[].id` 一致）：

| Core 资源键 | Core 包内路径 | 说明 |
|---|---|---|
| `icon.ui.nav_market` 等 7 个 `nav_*` | `assets/icons/ui/nav_*.png` | 市场 / 委托 / 船厂 / 补给 / 情报 / 海图 / 出航 |
| `icon.ui.resource_coal` 等 5 个 `resource_*` | `assets/icons/ui/resource_*.png` | 煤 / 水 / 耐久 / 货物 / 金币 |
| `icon.ui.shipyard_boiler` 等 6 个 `shipyard_*` | `assets/icons/ui/shipyard_*.png` | 船厂分类（船体 / 锅炉 / 货舱 / 导航 / 安全 / 客舱） |
| `icon.ui.action_add` 等 3 个 `action_*` | `assets/icons/ui/action_*.png` | 增加 / 减少 / 确认 |
| `icon.ui.status_anchor` 等 9 个 `status_*` | `assets/icons/ui/status_*.png` | 状态与航线 |

- 用途：内容 JSON 可直接写 `"information.texture": "icon.ui.nav_market"`；运行时走 `AssetService.find_key("icon.ui.nav_market")` / `asset://core/icon.ui.nav_market`，与 `icon.item.*` 同一套解析规则。
- 尺寸：Core 包内是 128×128（与运行皮肤图标同尺寸、同字节），UI 常规按 24–40 px 显示；母版 256×256 仍在 `docs/design/ui_icons_v1/icons/`。
- 同步门禁：`test_mod_loading::test_core_registers_the_ui_icon_set` 会逐字节比较 Core 副本与 `assets/ui/skin/sn_v1/icons/`，母版重切 / 换肤后两边必须一起更新（`tools/ui/slice_ui_icons.gd` → `tools/build_ui_skin.ps1` → 同步复制到 `dev_mods/core/assets/icons/ui/`）。

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

市场、委托、补给与船厂的页面骨架、组件拆分、ViewModel 建议和验收标准见 [高频决策页面重构指南](../specs/HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md)。
