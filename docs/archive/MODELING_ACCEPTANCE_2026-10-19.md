# 建模资产第一轮验收报告（2026-10-19）

> 验收范围：`tools/modeling/briefs/` 中的帆船、港口吊机与铁港第一批 6 件小部件。  
> 验收依据：建模 brief、当前 GLB 导出文件、Blender 现状截图与 Godot 导入记录。  
> 补充：第 10 / 11 节分别为小型明轮蒸汽船与 1795 双桅纵帆船（SN_Schooner_Fame，2026-10-19 追加）。  
> 本轮结论：**有条件通过，可进入 Godot 场景试装；完成指定小修和交付补件后再封版。**

## 1. 验收范围与状态

| 资产 | 对应 brief | 技术验收 | 美术验收 | 当前结论 |
|---|---|---:|---:|---|
| `SN_Ship_Prototype` | `sn_ship_prototype.json` | 通过 | 基本通过 | 可试装 |
| `SN_Harbor_Crane` | `sn_harbor_crane.json` | 通过 | 基本通过 | 可试装 |
| 铁港第一批 6 件小部件 | `sn_iron_harbor_batch1.json` | 通过 | 需小修 | 修正后封版 |
| 铁港第二至第五批 | `sn_iron_harbor_batch2~5.json` | 未交付 | 未验收 | 继续制作 |

本报告只验收当前已经提供的 8 个模型。第二至第五批共 25 件规划资产不计入本轮完成率，也不作为本轮退回原因。

## 2. 自动检查结果

### 2.1 帆船 `SN_Ship_Prototype`

| 检查项 | brief 要求 | 实际结果 | 结论 |
|---|---:|---:|---:|
| 三角面 | `<= 3000` | `2608` | 通过 |
| 尺寸 | `17.83 × 8.00 × 14.47 m`，容差 `0.5 m` | 约 `17.83 × 8.00 × 14.47 m` | 通过 |
| 根节点 | `SN_Ship_Root` | 存在，单位变换 | 通过 |
| 桅杆枢轴 | 前桅、主桅、后桅独立 Pivot | 3 个 Pivot 均存在，子层级正确 | 通过 |
| 必要部件 | 船体、甲板、舷墙、艉楼、桅杆、帆、帆桁、舵、艏斜桅、腰板 | 均存在 | 通过 |
| 材质 | Wood / Wood_Dark / Wood_Deck / Canvas / Metal | 5 类材质齐全 | 通过 |
| Godot 导入 | 可作为运行时资产导入 | 已生成 `.glb.import` | 通过 |

### 2.2 港口吊机 `SN_Harbor_Crane`

| 检查项 | brief 要求 | 实际结果 | 结论 |
|---|---:|---:|---:|
| 三角面 | `<= 4000` | `3420` | 通过 |
| 尺寸 | `26.00 × 6.09 × 21.50 m`，容差 `0.8 m` | 约 `26.20 × 6.30 × 21.47 m` | 通过 |
| 根节点 | `SN_Crane_Root` | 存在，单位变换 | 通过 |
| 回转枢轴 | `SN_Crane_Slew_Pivot` | 存在；驾驶室、吊臂、配重和吊钩均在其下 | 通过 |
| 结构部件 | 基座、塔身、驾驶室、A 架、主臂、平衡臂、拉杆、配重、小车、吊钩和卷扬机构 | 均存在 | 通过 |
| 材质 | Stone / Metal / Wood / Wood_Dark | 4 类材质齐全 | 通过 |
| Godot 导入 | 可作为运行时资产导入 | 已生成 `.glb.import` | 通过 |

### 2.3 铁港第一批 6 件小部件

| 资产 | 三角面 | 预算 | 尺寸 | 根节点/原点 | 结论 |
|---|---:|---:|---:|---:|---:|
| `SN_Dock_Wall` | 588 | 1000 | `6.0 × 3.0 × 3.5 m` | 底面中心 | 通过 |
| `SN_Dock_Fender` | 46 | 100 | `0.3 × 0.3 × 2.5 m` | 底面中心 | 通过 |
| `SN_Mooring_Bollard` | 188 | 200 | `0.5 × 0.5 × 0.85 m` | 底面中心 | 通过 |
| `SN_Crate` | 120 | 150 | `1.2 × 1.2 × 1.2 m` | 底面中心 | 通过 |
| `SN_Barrel` | 168 | 200 | `0.9 × 0.9 × 1.1 m` | 底面中心 | 通过 |
| `SN_Ore_Pile` | 150 | 700 | `4.0 × 3.0 × 1.5 m` | 底面中心 | 通过 |
| **合计** | **1260** | **2500** | — | — | **通过** |

六件资产的名称、根节点、尺寸、三角面与材质范围均符合 brief。GLB 使用标准 Y-up 坐标；这是 Blender Z-up 导出至 glTF/Godot 后的正常轴向转换，不判定为轴向错误。

当前尚未看到这六件小部件对应的 Godot `.glb.import` 记录，因此只能确认 GLB 结构正确，尚不能确认其在游戏内的材质、朝向、尺度与阴影表现。

## 3. 美术验收

### 3.1 帆船：基本通过

优点：

- 三桅六帆、深色腰板、高艉楼和艏斜桅均能在 3/4 视角中识别。
- 船体、甲板和帆面的低多边形语言统一，远距离轮廓成立。
- 深浅木色与帆布形成了足够的明度分区。

需要继续改进：

- 六面帆的鼓起程度和分段规律过于接近，重叠后轮廓略显拥挤；建议让迎风边更紧、后缘更松，并微调上下帆的投影关系。
- 甲板机械细节较少，目前更接近传统木帆船。它符合本轮 sailing ship brief，但与项目整体的蒸汽朋克方向仍有距离。
- 蒸汽朋克强化应另开 revision brief，增加烟囱、机械绞盘、锅炉附件、管线或黄铜构件，不作为本轮硬性退回项。

### 3.2 港口吊机：基本通过

优点：

- 塔身、水平长臂、平衡臂、配重、A 架、吊索和吊钩形成了明确的塔吊轮廓。
- 功能部件位置合理，回转部分层级也可支持后续的简单旋转表现。
- 石质基座和桁架结构足以承担铁港地标资产的视觉职责。

需要继续改进：

- 桁架密度明显高于船和小部件，实际游戏镜头下可能形成大面积黑色噪点。
- 木结构与金属节点的色相、明度差异不足，当前容易被读成全金属吊机。
- 建议先在目标机位测试，再决定是否删除远距离不可见的短斜撑；不建议在 Blender 单件视图中继续增加细节。

### 3.3 铁港第一批小部件：需小修

#### `SN_Mooring_Bollard`

当前顶部偏尖，远看更像路桩或小型灯柱，没有充分表达 brief 要求的“蘑菇头 + 柱身 + 底座法兰”。

整改要求：

- 顶盘横向扩大约 25%–35%；
- 降低顶盘高度，使轮廓更扁；
- 强化底部法兰；
- 从侧面检查缆绳是否能形成可信的挂靠关系。

#### `SN_Ore_Pile`

当前颜色接近深棕木料，与木箱、木桶的色域过于接近，不符合“锈红铁矿”的识别要求。

整改要求：

- 将 `SN_Ore` 调整为偏暗的氧化铁红；
- 保留少量深褐块面以维持低多边形层次；
- 避免使用高饱和鲜红色。

#### `SN_Dock_Wall`

单件轮廓和材质分区合格，但“可沿 X 连续拼接”尚未经过场景验证。

整改/验证要求：

- 连续复制三段进行拼接测试；
- 检查端部石缝、木压顶高度和阴影裂缝；
- 确认铁护角不会在接缝处重复叠加。

#### 木护舷、木箱与木桶

本轮通过。三件资产轮廓清楚、尺度关系合理；后续只需结合场景检查小尺寸下的材质分区是否仍然可读。

## 4. 交付物检查

### 已存在

- `.design/ships/SN_Ship_Prototype.blend`
- `.design/ships/sn_ship_prototype_generator.py`
- `.design/SN_Asset_Workbench.blend`
- `assets/models/ships/SN_Ship_Prototype.glb`
- `assets/models/props/SN_Harbor_Crane.glb`
- 第一批 6 件港口道具 GLB

### 缺失或尚未归档

1. 吊机 brief 指定的 `.design/props/sn_harbor_crane_generator.py` 当前不存在。
2. 帆船与吊机 brief 要求的 `three_quarter / side / top` 三视图没有归档到仓库工作资料中；聊天截图不能替代可追溯的交付文件。
3. 第一批 6 件小部件尚无 Godot 导入记录和场景试装截图。
4. 尚缺少三段岸壁连续拼接的验证图。

## 5. 返工优先级

### P0：进入场景前完成

- 修正系缆桩的蘑菇头和底座法兰。
- 调整 `SN_Ore` 为锈红铁矿色。
- 将第一批 6 件 GLB 导入 Godot，并检查尺度、朝向、材质和阴影。
- 用三段岸壁完成连续拼接测试。

### P1：本轮封版前完成

- 归档帆船和吊机的 3/4、侧视、顶视截图。
- 补齐吊机生成脚本，或修改 brief 明确工作台 `.blend` 是唯一源文件，避免交付约定与实际流程不一致。
- 在游戏目标机位验证吊机桁架是否产生黑块噪点，必要时简化短斜撑并拉开木材/金属的颜色层级。

### P2：下一轮迭代

- 单独编写蒸汽朋克船体 revision brief。
- 在第一批资产进入港口灰盒后，再开始铁港第二批建筑骨架，避免继续脱离真实机位堆叠细节。

## 6. 最终判定

本轮资产在命名、尺寸、三角面预算、必要部件、层级与基础轮廓方面均达到原型要求，没有发现需要整体推倒重做的问题。

**验收状态：有条件通过。**

完成以下四项后可转为正式通过：

1. 修正系缆桩轮廓；
2. 修正铁矿石材质；
3. 完成六件小部件的 Godot 导入与岸壁拼接验证；
4. 补齐吊机生成脚本和规定视角截图，或同步修订对应交付约定。

## 7. P0 整改完成记录（同日第二轮）

第 5 节 P0 四项已全部执行完毕，另按人工要求改了系缆桩的工单尺寸。

| P0 项 | 结果 | 证据 |
| --- | --- | --- |
| ① 系缆桩桩头与法兰 | **改十字桩头**（方形法兰板 + 四角六角螺栓 + 粗圆柱桩身带喇叭脚 + 圆柱十字横臂端部倒角收口 + 柱顶平盘），参考实船舱面系缆桩照片 | 288 三角面；0.62 × 0.62 × 0.70 m；`non_manifold_edges=0`、`boundary_edges=0`、`loose_verts=0`、`degenerate_faces=0`；单网格 datablock 无孤儿 |
| ② `SN_Ore` 锈红 | base 改为线性 `(0.155, 0.038, 0.024)`，roughness 0.95、metallic 0 不变 | 与木箱/木桶棕褐色域已拉开；低多边形面明暗层次由 flat shading 保留 |
| ③ Godot 导入 | 6 件全部 PASS：尺寸、轴向（glTF Y-up）、材质名、三角面 | `tools/godot/verify_props.gd`；`godot --headless --import` 后复验 exit 0 |
| ④ 三段岸壁拼接 | 3 段 `SN_Dock_Wall` 严格对接（6 m 段长，接缝无缝隙、无 z-fighting），木压顶连续 | 临时对象 `SN_TMP_Splice_1..3` 截图验收后已删除，场景回到 78 对象 |

### 7.1 工单尺寸变更

系缆桩按实船照片重做后与工单原尺寸冲突：照片里是**矮壮**的装货桅桩（高/宽 ≈ 1.1），
而原工单 `0.5 × 0.5 × 0.85` 高/宽为 1.70，读起来像"细柱顶十字"。经人工确认后改工单：

- `tools/modeling/briefs/sn_iron_harbor_batch1.json`：`SN_Mooring_Bollard` size
  `[0.5, 0.5, 0.85]` → **`[0.62, 0.62, 0.70]`**（高/宽 1.13），desc 同步改为十字桩头描述；
- 三角面 188 → 288（预算 200，验收上限 1.5× = 300，未超）；
- 摆放位置 `(-2, 24, 0)` 与 5 m 间距布局不变。

本批合计三角面 1260 → **1360**。

### 7.2 归档产物

- 工作台：`.design/SN_Asset_Workbench.blend`（78 对象 = 70 mesh + 6 empty + 1 light + 1 camera）；
- 重导 GLB：`assets/models/props/SN_Mooring_Bollard.glb`、`SN_Ore_Pile.glb`（导出前已备份到 `.design/props/backup_glb/`）；
- 生成器与脚本（**已入库**）：`tools/modeling/generators/sn_mooring_bollard_generator.py`、`p0_rework_2026-10-19.py`、`p0_finalize.py`、`export_props_glb.py`、`dryrun_props.py`；
- 验收脚本：`tools/godot/verify_props.gd`。

### 7.3 仍未完成（P1，不阻断本轮）

1. 帆船与吊机的 3/4、侧视、顶视截图仍未归档到仓库；
2. 吊机参数化生成脚本仍缺失（`briefs/sn_harbor_crane.json` 指定的生成器不存在，应补到 `tools/modeling/generators/sn_harbor_crane_generator.py`）；
3. ~~生成器脚本全部位于被 gitignore 的 `.design/`~~ **已解决**：全部生成器与工具脚本已迁到 `tools/modeling/generators/` 并纳入版本管理；只有 `.blend`、GLB 备份、基线快照这类本地产物留在 `.design/`。

## 8. 船舶模块 11 件（R0 → R2，最终通过）

### 8.1 范围与交付物

覆盖 Core 里除船体外的全部模块实体：锅炉 3、货舱 3、导航 2、安全 2、客舱 1。这是 2.5D 舞台与船厂改装台需要的"可摆放模块件"，本批只交付 Blender 工作台 + 独立 GLB，**不接入 Core 内容键**。

| 项 | 内容 |
| --- | --- |
| 工单 | `tools/modeling/briefs/sn_ship_modules_batch1.json`（11 件、尺寸/预算/材质/摆位自包含） |
| 生成器 | `tools/modeling/generators/sn_ship_modules_generator.py`（参数表驱动，纯几何 + Blender 装配 + 自检） |
| 离线干跑 | `tools/modeling/generators/dryrun_props.py`（bpy 空壳加载生成器，查 tri/包围盒/边界边/非流形/退化面） |
| 预览渲染 | `tools/modeling/generators/render_modules_preview.py`（EEVEE、临时相机/太阳、逐件 3/4 + 正前 + 3 组 + 总览，共 26 张） |
| GLB 导出 | `tools/modeling/generators/export_modules_glb.py`（逐件归零位置导出、旧 GLB 先备份） |
| GLB 自检 | `tools/modeling/generators/verify_modules_glb.py`（单节点 / tri / 材质 / Y-up 尺寸） |
| 工作台 | `.design/SN_Asset_Workbench.blend` → `SN_Ship_Modules` 集合（160 对象 / 145 mesh / 11 材质） |
| 运行时 GLB | `assets/models/modules/` 下 11 个独立 `.glb`（单节点、轴心底面中心、glTF Y-up） |
| 截图 | `docs/design/screenshots/ship_modules_batch1_{overview,boilers,cargo,nav_safety_cabin}.png` |

逐件结果（合计 **7016 tri**，预算 8300）：

| 资产 | tri | 尺寸 L×W×H (m) | 材质数 |
| --- | ---: | ---: | ---: |
| `SN_Boiler_Efficient` | 540 | 1.81 × 1.60 × 2.60 | 4 |
| `SN_Boiler_Standard` | 860 | 2.82 × 1.90 × 2.62 | 4 |
| `SN_Boiler_Performance` | 1152 | 3.40 × 2.11 × 2.94 | 4 |
| `SN_Cargo_Small_Hold` | 456 | 2.40 × 2.00 × 1.80 | 4 |
| `SN_Cargo_Medium_Hold` | 492 | 3.20 × 2.40 × 2.20 | 4 |
| `SN_Cargo_Large_Hold` | 672 | 4.01 × 2.81 × 2.60 | 4 |
| `SN_Nav_Spyglass` | 328 | 1.38 × 0.80 × 1.75 | 4 |
| `SN_Nav_Chart_Room` | 636 | 2.80 × 2.20 × 2.60 | 5 |
| `SN_Safety_Lifeboat` | 660 | 4.20 × 1.50 × 1.10 | 4 |
| `SN_Safety_Valve` | 428 | 1.49 × 1.26 × 1.84 | 3 |
| `SN_Cabin_Passenger` | 792 | 3.40 × 2.40 × 2.55 | 6 |

### 8.2 自动质检

- 干跑：11 件 `ALL OK`，包围盒误差 ≤0.1 m，底面 z=0，边界边 / 非流形边 / 退化面全 0。
- Blender 自检：孤立点 / 退化面 / 材质槽越界 / 非流形边 / 边界边全 0；每件单 mesh、多材质槽、flat shading；原有 149 对象位置零漂移。
- GLB 自检：11/11 PASS，单节点、无平移、Y-up 尺寸与工单一致、三角面与场景逐件相等。
- 独立 Verifier 在 R2 还做了**几何哈希三方核对**：解析 GLB POSITION 缓冲逆变换回 Blender 坐标后，11/11 件的去重点数与 sha1 与场景一致，证明 GLB 确为最终版而非旧导出。

### 8.3 独立 Verifier 三轮记录（只读）

| 轮次 | 结论 | 发现 | 处理 |
| --- | --- | --- | --- |
| R0 | `passed=false` | 5 处同法线共面（客舱角柱 1.84 m²、小货舱角柱 1.14 m²、大货舱通风口 0.378 m²、高效锅炉铭牌 0.072 m²、救生艇舷缘端面 0.009 m²）+ 9 处悬空壳体（性能锅炉灰门 ×2、三货舱横撑各 ×2、望远镜手轮 + 准星 ×2） | 全部按 fix_hint 改参数；另主动补了压力表嵌入、标准锅炉给水管贴筒、性能锅炉立管连过热器、大货舱尾门内嵌、救生艇桨架/内底板/艏甲板/储物箱、海图室与客舱管件嵌屋顶 |
| R1 | `passed=false`（硬指标全绿） | 上一轮问题清零，但同规则又抓到 4 处 cm 级共面（客舱通风帽、大货舱格栅内端、救生艇储物箱底/桨架顶）+ 高效锅炉 24 面黄铜蒸汽包被穹顶完全包住（隐藏几何） | 5 处一行数值收尾：帽顶 2.392、格栅内端 1.322、储物箱底 0.862、桨架顶 0.985、蒸汽包 z+0.18 |
| R2 | **`passed=true`** | 4 处共面 + 隐藏几何清零；0 悬空；无新穿模。仅剩 2 处**完全被遮挡**的微小共面（大货舱铭牌/端肋背面 0.0335 m²、客舱腰线/门框背面 0.0128 m²，均背面朝内、外部首击被遮挡），R0 起即存在、不影响任何视角渲染，记录在案 | 不再返工 |

### 8.4 结论与遗留

**本批通过。** 11 件模块的命名、集合归属、三角面预算、网格健康、尺寸轴心、材质调色板、回归、Core 实体映射与 GLB 同步均达到验收要求；3/4、正前、顶视三套视角下五类模块轮廓可辨、无可见穿模或悬空。

遗留（不阻断本批交付）：

1. **Core 接入**：三种锅炉仍共用 `model.module.boiler`，货舱 / 导航 / 安全 / 客舱还没有模型资源键；接入要同时改 `dev_mods/core/content/*.json` 的 `information.model`、manifest 的 `assets` 声明与资源校验测试。
2. **Godot 导入验收**：本机当前没有可用的 Godot 可执行文件（`GODOT_BIN` 未设置），11 个 GLB 尚未生成 `.import` 与引擎侧尺寸/材质复核；下次打开编辑器或跑 `godot --headless --import` 后补 `tools/godot/` 验收。
3. **2.5D 舞台试装**：按 `ShipyardStage` / `PortStage` 的 socket 摆位复核模块朝向（+X 前向）、轴心与尺度。
4. 文档小瑕疵已修：`ASSET_MAP` 的 Standard / Performance 尺寸列已改为实测值。

## 9. 舷侧炮铁甲舰 SN_Ironclad（R0 → R3，最终通过）

### 9.1 范围与交付物

1860 年代**舷侧炮铁甲舰**，60 m 级**纯展示资产**（不接入 Core 内容键、不改游戏逻辑）。单 mesh / 8 材质槽，轴心在水线中心（x=0 船中、z=0 水线、+X 船首），工作台摆位 (0, 90, 0)。

| 项 | 内容 |
| --- | --- |
| 工单 | `tools/modeling/briefs/sn_ironclad_broadside.json` |
| 生成器 | `tools/modeling/generators/sn_ironclad_generator.py`（17 站放样 + 装甲带 + 炮列 + 炮房/烟囱 + 三桅 + 甲板件） |
| 干跑 / 连通性 | `dryrun_ironclad.py`、`check_ironclad_connectivity.py`（拆岛 + BVH 相交/最近距离） |
| 预览 / 导出 / 自检 | `render_ironclad_preview.py`、`export_ironclad_glb.py`、`verify_ironclad_glb.py` |
| 尺寸 | **60.13 × 18.00 × 28.64 m**（LOA 含艏斜桁与艉廊；z -4.20 .. 24.44） |
| 三角面 | **8830 / 12000** |
| 材质 | Iron_Hull / Iron_Red / Wood_Deck / Wood / Wood_Dark / Metal / Brass / Canvas（8 个，复用既有调色板） |
| 场景 | `SN_Ironclad_Prototype` 集合；全场景 161 对象 / 146 mesh / 11 材质 |
| 运行时 GLB | `assets/models/ships/SN_Ironclad.glb`（467948 B；1 节点 / 1 网格 / 8 图元 / 8830 tri / glTF Y-up） |
| 源文件 | `.design/SN_Asset_Workbench.blend`（工作台）+ `.design/ships/SN_Ironclad.blend`（数据块快照） |
| 截图 | `docs/design/screenshots/ironclad_{three_quarter,broadside,bow,bow_closeup,guns_closeup,stage_ortho}.png` |

结构（R3 英雄化后）：17 站放样铁壳 + 撞角艏；2.2 m 高/外凸 380 mm 装甲带（120 mm 板缝 + 黄铜压条）；每舷 6 门英雄化舷侧炮（炮门 1.9×1.9 m、炮管 Ø0.88→0.72 m、外露 1.55 m、炮口箍 Ø1.0 m、上翻炮门盖、前外张 12°）+ 2 门放大艏 pivot 炮；中央斜壁装甲炮房 + 指挥塔 + 艏驾驶台；双后倾烟囱 + 通风筒 + 天窗；三桅横桁（收帆卷）+ 艏斜桁 + 支索/侧支索；舷墙 + 黄铜压条；舱口格栅/绞盘/舵轮/罗经柜/双小艇/锚/螺旋桨/舵/艉廊/旗。

### 9.2 自动质检

- 干跑：8830 tri、bbox 60.13×18.00×28.64、z -4.20..24.44，边界边/非流形边/退化面/孤立点全 0，材质全部在调色板内。
- Blender 自检：`loose=0 / degenerate=0 / nonmanifold=0 / boundary=0 / mat_overflow=0 / size_ok / waterline_ok` 全 true；舰本体 1 mesh / 8 材质（R2 时场景 161 对象 / 146 mesh；之后并行会话加入明轮蒸汽船，现 196 对象，非本任务）。
- 连通性：551 个连通岛，floating=0、loose=0（阈值 0.05 / 0.005 m，三角面相交计为连接）。
- GLB 自检：1 节点 / 1 网格 / 8 图元 / 8830 tri、Y-up bbox (60.13, 28.64, 18.00)、Y 范围 -4.20..24.44、8 材质名正确；快照含对象/mesh/8 材质。
- Godot 编辑器已为其生成 `SN_Ironclad.glb.import`（PackedScene）；引擎侧的轴向/包围盒/材质复核仍待跑。

### 9.3 独立 Verifier 首轮复核（R0 / R1；R2 见 9.5、R3 见 9.6）

| 轮次 | 结论 | 发现 | 处理 |
| --- | --- | --- | --- |
| R0 | `passed=false`（硬指标全绿） | 8 类装配问题：3 个桅顶饰件/指挥塔/2 个通风筒/绞盘+舵轮+罗经柜+锚环等 `revolved()` 忘 `translate`（堆在原点成隐藏几何或悬空）；双小艇截面漏 y 偏移导致完全重合；螺旋桨叶片未连毂；炮房黄铜条离斜壁 0.21 m、艏驾驶台整体悬空 0.62 m；副艏斜桁/格栅条/铭牌/支索端点 0.03–0.15 m 小间隙 | 全部按 fix_hint 改参数；另加艏驾驶台 4 根落甲板立柱、副斜桁鞍座、格栅条搭边轨、铭牌内嵌；新增连通性检查脚本 |
| R1 | **`passed=true`** | 8 类问题逐项清零（BVH/岛分析实测）；575 岛最大最小间距 0.0011 m，>0.02 m 岛数 0；无新悬空/穿模；硬指标、160 对象回归、材质哈希、GLB 结构与场景同步、快照、截图全绿 | 不再返工 |

非阻断记录（R1）：指挥塔（x=4.3）与 x=3.0 通风筒有 ≤6 cm 局部互穿、与 (5.4,0) 栏杆柱齐平相交约 3 mm；视觉上读作贴管/贴柱，不影响渲染。若后续要求严格零相交，可把该通风筒移到 x≈2.70–2.75 并外移栏杆柱。

### 9.4 结论与遗留

**本批通过。** 命名、集合、单 mesh、三角面预算、网格健康、尺寸/水线轴心、材质调色板、回归、GLB 结构与场景同步均达标；3/4、正侧、艏/艉视角下铁壳装甲带、舷侧炮列、中央炮房、双烟囱、三桅横桁、撞角艏与艉廊均可辨认。

遗留（不阻断交付）：

1. **Godot 引擎侧复核**：`.import` 已生成，仍待跑轴向/包围盒/材质/阴影复核（可复用 `tools/godot/` 思路新写只读脚本）。
2. **2.5D 舞台试装**：按 `PortStage` / `ShipyardStage` 的目标机位复核水线高度、朝向（+X 前向）与尺度。
3. **可选接入**：若要把铁甲舰作为第 5 种船体或港口战舰，需补 Core 内容 JSON、manifest 资源键、本地化与测试。
4. 过程改进：`revolved()` 忘 `translate` 这类错误不体现在 tri/包围盒上；本批新增的 `check_ironclad_connectivity.py`（BVH 拆岛）应作为大型拼装件的固定验收步骤。

### 9.5 人工反馈修复：舰艏浮空（R2）

人工在 Blender 视口验收舰艏时指出：两根斜桁上的**绑扎块与副斜桁鞍座**只挂在斜桁上，离甲板/艏柱约 1.5 m，看起来像浮在空中。处理（生成器参数级）：

- 艏斜桁绑扎块下方加**甲板楔形基座**（底 24.2–25.6 / ±0.75 / z4.6，顶 24.6–25.2 / ±0.32 / z6.0），与绑扎块搭接；
- 艏柱顶加**延伸座**（26.9–27.9 / ±0.30 / z4.95–7.05），托住副斜桁鞍座并与艏柱搭接；
- 两舷锚加**木质吊架（cathead）+ 竖直吊链**，让舷侧锚读作吊挂，而不是穿过舷墙；
- 9318 tri（+80，来自基座/艏柱座/吊架/吊链）；尺寸不变；581 岛、connectivity floating=0 / loose=0；GLB 重导（489432 B）、快照/工作台重存、4 张预览 + 舰艏近景重渲。

舰艏近景截图：`docs/design/screenshots/ironclad_bow_closeup.png`。

R2 独立 Verifier 复核：**pass** —— 绑扎块/鞍座均与新增基座三角面相交、不再悬空；两舷锚经 cathead 读作吊挂；581 岛扫描 >0.02 m 间距岛数 0；9318 tri、网格健康、160 对象回归、材质哈希、GLB 与场景同步、快照全部保持全绿。非阻断观察：吊链与锚杆同轴、整段被锚杆/舷墙/锚环包住（不可见），吊挂读感由 cathead 承担；若需露出吊链，可外偏 y≈0.12–0.15 m。


### 9.6 英雄化细节 pass（R3）

背景：固定 2.5D 正交机位下，写实炮管 Ø0.36 m 在 1440 宽、舰占画面 60% 时只有 3–4 px，炮列读不出来。原则：**世界尺度不变（1u=1m、船 60 m），只放大“叙事细节”**，细节尺寸按镜头可读性而不是现实比例。

| 元素 | 原值 | R3 英雄化 |
| --- | --- | --- |
| 舷侧炮数 | 8 门/舷、间距 4.5 m | **6 门/舷、间距 7 m** |
| 炮门 | 1.0 × 1.3 m | **1.9 × 1.9 m** |
| 炮管 | Ø0.36 m、外露 0.8 m | **Ø0.88→0.72 m、外露 1.55 m**，前外张 12° |
| 炮口箍 | Ø0.38 m | **Ø1.0 m** |
| 艏 pivot 炮 | 炮管 Ø0.34、外露 2.4 m | 炮管 Ø0.68→0.52、外露 ~3.2 m、炮座加大 |
| 装甲带 | 1.9 m 高 / 外凸 220 mm | **2.2 m 高 / 外凸 380 mm** |
| 板缝 | 60 mm | **120 mm**（上壳 100–120 mm） |

- 结果：**8830 tri**（9318 − 炮数减少 + 加粗抵消）、bbox 60.135×18.00×28.64 不变、551 岛 floating=0 / loose=0、网格健康四项全 0；GLB 467948 B / 1 节点 / 8 图元 / 8830 tri；快照/工作台重存。
- 舞台可读性验证（`ironclad_stage_ortho.png`，正交 3/4、正交视宽 100 m（约 14.4 px/m）、1440×900、带水面）：3/4 投影后炮门约 20–27 px、炮管 Ø约 10–12 px、炮口箍约 12–14 px（原约 5 / 1.5 / 1 px 量级）。近景 `ironclad_guns_closeup.png`、舰艏 `ironclad_bow_closeup.png`。

R3 独立 Verifier 复核：**pass** —— 6 门/舷、炮门 1.90×1.90、炮管 Ø0.88→0.72/外露 1.50、炮口箍 Ø1.01、前外张 12.5°、装甲带 2.20 m/外凸 0.380、板缝 0.12 均实测生效；551 岛 floating=0；原 160 对象哈希不变；GLB 467948 B 与场景位置哈希一致；判读炮列“明显改善”（炮门开口面积约 2.8×、管径约 2.4×、外露约 1.9×）。非阻断：炮门框/口板是平面件、沿 x 曲率处局部与壳面有 0.36 m 采样间隙但三角面均相交（近景无可见悬空），如需严格贴合可后续按 x 折弯。

## 10. 小型明轮蒸汽船 SN_Paddle_Steamer（R0 → 通过）

### 10.1 范围与交付物

参考澳大利亚国家博物馆的明轮蒸汽船 **PS Enterprise**（堪培拉伯利·格里芬湖，白漆双层船身 + 两舷格栅轮罩 + 前驾驶室 + 后部雨棚游步甲板 + 艏旗杆）的 24 m 级小型明轮客船，**纯展示资产**（不接 Core 内容键，不改游戏逻辑）。单集合 35 对象（32 mesh + 3 empty），轴心在船体中部水线（x=0 船中、z=0 水线、+X 船首），工作台摆位 (45, 0, 0)。用户明确要求：**烟囱蒸汽不做几何**，留给游戏内 VFX。

| 项 | 内容 |
| --- | --- |
| 工单 | `tools/modeling/briefs/sn_ship_paddle_steamer.json` |
| 生成器 | `tools/modeling/generators/sn_paddle_steamer_generator.py`（`STATIONS` / `PROFILE` / `PADDLE` / `PADDLE_BOX` / `CABIN` / `WHEELHOUSE` / `CANOPY` / `FUNNEL` / `FLAG` 参数表；纯几何 + Blender 装配 + 文字铭牌） |
| 干跑 | `dryrun_paddle_steamer.py`：35 对象 / 32 mesh / 3 empty、**11088 tri（几何部件）+ 2 个文字铭牌 676 tri = 11764 tri（Blender report）**、包围盒 **24.56 × 8.74 × 10.47 m**、z −1.32..9.15、边界/非流形/退化/孤立点全 0（Deck 与铭牌为单层双面贴片白名单）、8 材质、镜像误差 0 |
| 场景只读验收 | `verify_paddle_steamer_scene.py`：26/26 health 全 true；明轮 8 个旋转角与轮罩/船体/明轮台 0 交面（轮轴穿舱属轴承结构）；524 岛悬空 0；工作台 161 个既有对象位置零漂移 |
| 预览渲染 | `render_paddle_steamer_preview.py`：3/4、正侧、艏、艉 3/4、俯视 5 张，临时 matte 水面，渲后还原 |
| 工作台 | `.design/SN_Asset_Workbench.blend` → `SN_Paddle_Steamer_Prototype`（全场景 **196 对象** = 161 既有 + 35 新增） |
| 运行时 GLB | `assets/models/ships/SN_Paddle_Steamer.glb`（**35 节点 / 32 网格 / 8 图元 / 11764 tri / 8 材质 doubleSided / 632.7 KB / glTF Y-up**，轴心水线 z=0） |
| 源文件 | `.design/ships/SN_Paddle_Steamer.blend`（`libraries.write` 35 对象独立快照，不切换当前文件） |
| 截图 | `docs/design/screenshots/paddle_steamer_{three_quarter,broadside,bow,stern_quarter,top}.png` |

结构：16 站放样白漆船身（深色水线以下船底 + 暗红压条）；两舷 10 桨叶明轮（14 段双轮缘 / 每侧 8 辐条 / 内加强环 / 黄铜轮缘条 / 4 斜撑 / 曲柄销）+ 梯形格栅轮罩（10 道水平格栅 + 深色内衬 + 暗红顶沿 + 黄铜铭牌）+ 明轮台走台/栏杆；主甲板客舱（白墙 + 玻璃窗 + 黄铜窗台 + 木门）；游步甲板 + 白色立柱雨棚 + 前后栏杆；前驾驶室（三面窗 + 顶板 + 双侧 `ENTERPRISE` 文字铭牌 + 黄铜钟）；锅炉围罩 + 黑烟囱（黄铜箍 / 暗红顶圈）+ 黄铜蒸汽管；艏旗杆 + 澳洲旗、艏部锚/绞盘/系缆桩、艉部弧形低平台 + 栏杆 + 舵/舵柄 + 救生圈/卷缆。

### 10.2 自动质检

- 干跑 `ALL OK`；生成器 Blender 自检：合并后单 mesh 面数校验通过，`loose/degenerate/nonmanifold/boundary` 符合白名单，材质槽 3–6 个、全部 flat shading。
- GLB 自检 `verify_paddle_steamer_glb.py`：节点 35 / 网格 32 / 材质 8（全部 doubleSided）/ tri 11764 / Y-up 包围盒 24.56 × 10.47 × 8.74 / 水线 min Y = −1.32；**拒绝蒸汽节点**（`SN_PS_Steam_Pipes` 是黄铜管路，允许保留）。
- 明轮安全：只取离轴 ≥0.55 m 的桨叶/轮缘/辐条做 8 个旋转角的世界坐标 BVH 测试，与轮罩、船体、明轮台 0 交面；轮轴/轴帽穿过船体与轮罩按轴承结构放行。

### 10.3 独立 Verifier（只读）

| 轮次 | 结论 | 发现 | 处理 |
| --- | --- | --- | --- |
| R0 | **passed=true**（无阻断项） | 独立复核 35 对象命名/集合/层级/root 属性/材质槽/网格健康/双舷明轮 8 角交面/524 岛悬空/161 对象回归全部通过；仅 3 条非阻断视觉建议：① 轮罩下沿偏低，常规视角明轮露出偏少；② 后部雨棚整块大平顶偏重；③ 全白层次对比偏弱、暗红压条偏细 | ① 已由 Lead 在验收后把轮罩下沿 z 0.55→**0.90**，露出约 0.9 m 轮缘/桨叶并重跑场景验收（passed）+ 重渲 5 张截图；②③ 记录为下一轮打磨，不影响交付 |

### 10.4 结论与遗留

**本批通过。** 命名、集合、层级、tri 预算、网格健康、水线轴心、材质调色板、明轮旋转安全、连通性、工作台回归、GLB 结构与场景同步均达标；3/4、正侧、艏、艉 3/4、俯视下白双层船身 / 暗红压条 / 深色船底 / 格栅轮罩与明轮 / 前驾驶室 ENTERPRISE / 后雨棚游步甲板 / 黑烟囱 / 艏旗 / 艉平台与舵均可辨认，读作 24 m 级澳洲内河明轮客船。

遗留（不阻断交付）：

1. **Godot 导入验收**：本机当前没有可用的 Godot 可执行文件（`GODOT_BIN` 未设置），`.glb` 尚未生成 `.import` 与引擎侧轴向/包围盒/材质/阴影复核。
2. **2.5D 舞台试装**：按 `PortStage` / `ShipyardStage` 的目标机位复核水线高度与朝向；明轮可用 `SN_PS_Paddle_*_Pivot` 做旋转动画。
3. **蒸汽 VFX**：模型内不含蒸汽；建议在 Godot 侧以 `SN_PS_Funnel` 烟囱顶为发射点做粒子，不回到 Blender 补几何。
4. **可选接入**：若要作为内河客运船体 / 第 5 种船体，需要补 Core 内容 JSON、manifest 资源键、本地化、测试与资源校验。
5. **视觉打磨（非阻断）**：雨棚体量与白色层次对比可下一轮调整（缩短檐口悬挑 / 加粗暗红压条 / 加深部分甲板），当前先不改工单。

## 11. 1795 双桅纵帆船 SN_Schooner_Fame（R0 → R4 通过）

### 11.1 范围与交付物

用户 2026-10-19 反馈港口样片里的旧帆船（`SN_Ship_Prototype`）**太简陋**，给定 1795 年 Salem 名船 **Fame** 的绘画参考，要求做一艘「又帅气又好看」的 24 m 级双桅纵帆船替换旧浮船；随后明确追加 **不要星条旗**。最终只保留主桅顶红白长旒。单集合 **32 对象（29 mesh + 3 empty）**，轴心在船体中部水线（z=0、+X 船首），工作台摆位 (0, −70, 0)，纯展示资产（不接 Core 内容键）。

| 项 | 内容 |
| --- | --- |
| 工单 | `tools/modeling/briefs/sn_schooner_fame.json` |
| 生成器 | `tools/modeling/generators/sn_schooner_fame_generator.py`（`STATIONS` / `PROFILE` / `MASTS` / `FORE_SAIL` / `MAIN_SAIL` / `FORE_TOPSAIL` / `MAIN_TOPSAIL` 参数表；18 站放样 + 斜桁帆曲面 + 三角帆 + 索具 + 甲板属具 + 艉廊 + 文字铭牌） |
| 干跑 | `dryrun_schooner_fame.py`：29 mesh、12994 tri（+ FAME 铭牌 180 = 13174）、包围盒 **33.44 × 6.88 × 26.82 m**、边界边只在 6 个单层曲面白名单、非流形/退化/孤立点 0、12 材质、两桅轴距 6.4 m / 后倾断言通过 |
| 场景只读验收 | Builder R0→R4 + Verifier R0/R1：R0 抓出“两桅世界坐标完全重合、rake 未生效”的 P0（`origins` 对 FORE/MAIN 双重减原点 + Pivot 未设旋转）；R1 修复后 Verifier **passed=true**；R2 的艉廊镜像 0.020、R3 的艉柱共面黑斑、R4 的 20 mm 收进均已在最终版清零 |
| 预览渲染 | `render_schooner_fame_preview.py`：3/4、正侧、艏 3/4、艉 3/4、俯视 5 张，临时水面，渲后还原 |
| 工作台 | `.design/SN_Asset_Workbench.blend` → `SN_Schooner_Fame_Prototype`（场景 228 对象 = 196 既有 + 32 新增） |
| 运行时 GLB | `assets/models/ships/SN_Schooner_Fame.glb`（**32 节点 / 29 网格 / 13174 tri / 12 材质 doubleSided / 720.9 KB / glTF Y-up**，水线轴心 z=0；无星条旗） |
| 源文件 | `.design/ships/SN_Schooner_Fame.blend`（`libraries.write` 32 对象独立快照，不切换当前文件） |
| 截图 | `docs/design/screenshots/schooner_fame_{three_quarter,broadside,bow_quarter,stern_quarter,top}.png` |

结构：18 站放样黑船身 + 赭黄上舷带 + 黑腰板/压顶、艉楼甲板；双桅后倾（Fore −2.5° / Main −3.2°，轴距 6.4 m）；前桅斜桁帆 + 方顶帆、主桅大斜桁帆 + 三角顶帆、两面艏三角帆（jib + fore staysail）；舷侧绳梯（shrouds + ratlines）、支索/后支索、动索；艉廊 3 蓝窗 + 双灯 + FAME 铭牌；甲板属具（舱口格栅 / 绞盘 / 起锚机 / 舵轮 / 罗经柜 / 锚 / 钟 / 木桶 / 盘绳 / fife rails / 短梯 / 艏饰）；主桅顶红白长旒。帆腹统一镜像朝 −Y（Godot +Z 港口相机侧）。

### 11.2 自动质检

- 干跑 `ALL OK`：29 mesh / 12994 tri；场景 13174 tri（+铭牌 180）；bbox 33.44×6.88×26.82 m；边界边仅 `Deck 58 / Quarterdeck 32 / Sails_Fore 388 / Sails_Main 460 / Headsails 340 / Pennant 28`，其余 23 个闭合件全 0；非流形/退化/孤立点 0；12 材质全 doubleSided。
- 装配回归：两桅世界轴上距 **6.39 m**、桅顶 Fore (3.736, 23.157) / Main (−2.965, 24.077)，与 MASTS 参数严格一致；Sails×Deck/Hull = 0；Headsails×Mast_Fore = 156（帆头接上桅）；长旒→主桅轴 0.0425 m；艉廊镜像 0；FAME 后视 96/96 顶点无遮挡；196 个既有对象 missing/moved/changed 全空。
- GLB 自检 `verify_schooner_fame_glb.py`：节点 32 / 网格 29 / 12 材质全 doubleSided / 13174 tri / Y-up bbox 33.44×26.85×6.88 / 水线 min Y −2.74；**无星条旗对象**。

### 11.3 独立 Verifier（只读）

| 轮次 | 结论 | 发现 | 处理 |
| --- | --- | --- | --- |
| R0 | **passed=false** | P0：两桅世界坐标完全重合、rake 未生效，索具/艏三角帆/长旒悬空；P1：FAME 被舵头遮挡；P2：艉廊窗框镜像差 0.020、figurehead/ladders 缺失 | Lead 修生成器：`origins` 全零 + Pivot `rotation_euler.y=rake`；新增 fife rails/ladders/figurehead；艉廊窗框 dy 改 (−0.38, 0.34)；铭牌/舵头避让 |
| R1 | **passed=true**（3 项 P2 不阻断） | 独立复算 32/29/3、13174 tri、双桅轴距 6.39 m、帆脚离甲板、无星条旗、艉廊镜像 0、铭牌无遮挡；P2：艉柱与艉廊面板共面留 0.22×0.125 m 黑斑、dryrun 未施加 pivot 变换、4 处过期文档 | 修艉柱 x −12.34→−12.32、dryrun 补 pivot 世界变换 + 桅轴断言、同步文档；重跑 dryrun `ALL OK` |
| 终版 | **可归档** | R4 复测：原黑斑带 0 次命中艉柱，左右艉窗 0 遮挡；32/29/3、13174 tri、双桅、帆腹 −Y、无星条旗、回归全部保持 | 已导出 GLB / 快照并接入港口场景 |

### 11.4 结论与遗留

**本批通过。** 黑船身 + 赭黄上舷带 + 双桅后倾 + 斜桁帆/方顶帆/艏三角帆 + 完整索具 + 艉廊 FAME 铭牌 + 红白长旒的 1795 双桅纵帆船轮廓成立，3/4、正侧、艏/艉 3/4 与俯视均可辨认；用户要求的“不要星条旗”已落实；资产已替换港口样片旧浮船。

遗留（不阻断交付）：

1. **Godot 导入验收（已完成）**：`godot --headless --import` 已生成 `SN_Schooner_Fame.glb.import`；`tools/godot/verify_harbor_diorama.gd` **21/21 PASS**（新船实例 / 旧船移除 / 无星条旗 / 29 mesh / 船体随波起伏）；`tools/godot/capture_harbor_diorama.gd` 已重截 `harbor_diorama_schooner.png` 与 `harbor_diorama_schooner_detail.png`。
2. **2.5D 舞台试装**：按 `PortStage` / `ShipyardStage` 目标机位复核水线高度、朝向与桅顶裁切；桅杆 Pivot 可做后倾/摆动动画。
3. **可选打磨**：前桅方顶帆帆杠与桅面间隙可再收 0.2 m；艉廊内侧仍严格共面但不可见；索具与帆缘有贴边接触（中位 1.5–4.6 cm，非穿透）。

## 12. 可复用部件库 v1（ship_parts，2026-10-19）

### 12.1 范围与交付物

用户提出“把一些部件抽离，做可替换/可复用的部件”；本轮先做**建模期部件库**（运行时可换装 GLB 等 2.5D 舞台立项后再做）。目录 `tools/modeling/generators/ship_parts/`：

| 文件 | 内容 |
| --- | --- |
| `core.py` | `Part`、向量/基本体/放样/镜像工具、`PartSpec`、`tri_count`；纯 Python |
| `deck.py` | 舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯 |
| `bow.py` | 艏斜桁/jibboom/铁箍、雕刻艏饰 |
| `stern.py` | 艉廊/3 艉窗/檐口/双艉灯 |
| `assembly.py` | `BuildConfig`/`PivotSpec` + 集合/材质/空物体/文字铭牌/report；bpy 只在函数内 import |
| `palette.py` | 跨船共享材质名 |
| `README.md` | 分层、部件契约、新增部件步骤、输出不变验收口径 |

`sn_schooner_fame_generator.py` 现在只保留船型参数、hull/桅帆/索具/锚架等船型相关几何与 `build_config()`；甲板件/艏艉件/装配层全部委托给部件库。

### 12.2 等价性验证

- 重构前锁定两份基线：纯 Python 逐对象 verts/faces/tris/material/parent digest（`.design/schooner_baseline_geometry.json`）与 Blender 逐对象 local/world/polys digest（`.design/schooner_blender_baseline.json`）。
- 重构后纯 Python：28 部件 / 12994 tri / bbox `33.44 × 6.88 × 26.42 m`，逐对象 digest **0 差异**；dryrun `ALL OK`。
- Builder 重建后 Blender：32 对象 / 29 mesh / 3 empty / 13174 tri / bbox `33.441 × 6.88 × 26.866 m`；逐对象 `local_sha256 / world_sha256 / polys_sha256 / parent / matrix_world / materials / mesh_data / collections` **0 差异**；196 个既有对象零漂移；3/4 与右舷侧视外观与 R4 完全一致。
- 加载路径：`importlib` 加载与无 `__file__` 时 `bpy.data.filepath` 回退均能定位 `ship_parts`。

### 12.3 结论与后续

**重构通过，资产输出未变化。** 低耦合件已可跨船复用；hull/deck/bulwark/wales/keel/channels/rigging 仍留在船型生成器，避免过度抽象。

后续：① 抽 `rig_kit`（桅杆/斜桁/帆面/索具按桅距・桅高・帆装配置）；② 用第二艘船型验证复用；③ 等 2.5D 舞台立项后再导出独立 GLB + `SN_Socket_*` + `parts_manifest.json`，不维护第二套几何。

