# 穿壳炮 casemate gun 模块化 · 验收记录（2026-10-22）

> 范围：把铁甲舰舷侧 12 门“从船壳里伸出来”的炮拆成**独立可复用模块** `SN_Weapon_CasemateGun`，
> 船体侧改为 12 个 `SN_Socket_GunPort_*` 炮门安装点；**接受铁甲舰侧弦变空**（空载时报废为
> 炮门框 + 深色炮口板 + 上翻门盖）。
> 契约：[WEAPON_SOCKET_CONTRACT.md §9](../design/WEAPON_SOCKET_CONTRACT.md)；
> 资产映射：[ASSET_MAP.md](../design/ASSET_MAP.md)。

## 1. 结论

| 交付物 | 结果 |
| --- | --- |
| `SN_Weapon_CasemateGun.glb` | **7 节点 / 2 mesh / 3 图元 / 108 tri / 3 材质 / 11 612 B**；根 = 炮门平面中心，`port_pitch` 装配；外部共享贴图 |
| `SN_Ironclad.glb`（空炮门版） | **26 节点 / 1 mesh / 8 图元 / 8 158 tri / 573 336 B**；世界尺寸不变（60.1346 × 28.64 × 18.0）；4 武器 + 9 帆索 + 12 炮门 socket |
| 船体几何 | 8 830 → **8 158 tri**（−672 = 12 × 56）；顶点 5 517 → 5 133（−384）；面 5 104 → 4 624（−480）；**非流形 / 边界边 / 孤立点 / 退化面全部 0** |
| 模块与烘焙炮管 | 12 个炮门逐点重合，**误差 0.00e+00**（`dryrun_casemate_gun.py` 断言） |
| 端口位姿 | 由 `gun_port_pose()` 从同一组炮门参数推导，左/右舷镜像；`rot_z = ±77.869°`、`rot_y = −1.720°` |
| 实测净空 | 门内纵深 **4.245–8.000 m**（声明 1.10）、舷外 **8.000 m**（声明 6.00） |
| 运行时 | 运行时装配器 `ShipVisualAssembler` 仍未接入；本批交付资产 + socket 契约 + Godot 守护测试 |

## 2. 需求 → 实现

| 需求 | 实现 |
| --- | --- |
| 侧弦炮做成独立模型 | `sn_casemate_gun_generator.py` 生成独立 GLB；几何从 `sn_ironclad_generator` 的同参数推导（炮管 8 边收分 + 黄铜炮口箍 + 门内炮尾 + 双耳轴），装上去与拆炮前逐顶点一致 |
| 能模块化挂到各种船上 | 新 socket 类型 `SN_Socket_GunPort`（原点 = 炮门平面中心、`+X` = 炮膛轴线）+ `port_pitch` 装配 profile + 匹配规则（port_class / port_w/h / breech_depth / 俯仰极限） |
| 铁甲舰侧弦变空可以接受 | 船体只删炮管 + 炮口箍（按面索引精确删除），保留炮门框 / 深色炮口板 / 上翻门盖；空载读作空炮门 |
| 不改坏已有资产 | 不整船重建：现存网格先做“生成器一致性门禁”（顶点索引逐点 + 面顶点集合 / 材质），再按索引删 480 面；UV / 共享贴图 / 4 武器 socket / 9 帆索 socket 全部保留 |

## 3. 设计决策

1. **为什么按面索引删，而不是重导整船**：现存铁甲舰已经过 legacy UV 迁移 B（共享贴图 + `UVMap`）
   和两批 socket；整船重建会丢掉全部材质 / UV / 空节点。门禁证明“资产 = 生成器 full 变体”后，
   按索引只删炮管面，其余几何逐位不变（顶点最大偏差 9.4e-7，float32 量级）。
2. **为什么第二套 socket 而不是复用甲板 socket**：甲板 socket 原点在甲板面、侧舷点 `+X`
   是纯舷外；炮门 socket 原点在炮门平面中心、`+X` 是含 12.13° 外张 + 1.72° 上抬的炮膛轴线。
   两套语义混用会让 `clearance_*` 判据整体错位（见契约 §9.1）。
3. **模块不带外张角**：12.13° 外张是船型 / 固定机位可读性的产物，写进 socket 的旋转里；
   模块本体 `+X` 就是炮膛轴线，换船时由目标船的炮门朝向决定。
4. **俯仰限位 −6°…12°**：耳轴在门内 0.15 m，俯仰到极限时炮口箍（r=0.5）仍在 1.9×1.9 开口内
   （+12° 时开口内占 0.84 / 0.95），隐藏段仍在门内（`dryrun_casemate_gun.py` 逐顶点断言）。
5. **深色炮口板保留**：它既是空载读感，也是模块门内炮尾 / 耳轴的遮挡面，因此炮尾可以自由
   藏进船体、后坐不会露缝。

## 4. 验收记录

### 4.1 纯 Python（不进 Blender）

| 检查 | 结果 |
| --- | --- |
| `dryrun_ironclad.py` | ALL OK：8 158 tri / 预算 12 000；包围盒 60.13 × 18.00 × 28.64（容差 0.5）；z −4.20…24.44；8 个 `SN_Tex_*` 材质 |
| `dryrun_casemate_gun.py` | ALL OK：108 tri；包围盒 2.4907 × 1.0 × 1.0；门内隐藏段全部 `x<0` 且落在开口内；12 门装上去与烘焙炮管**误差 0.00e+00**；±俯仰极限不露隐藏段 |
| `sn_ship_gun_ports.py --check` | 12 端口、左右舷镜像、命名 / 尺寸 / 极限全部通过 |
| `verify_casemate_glb.py` | **ALL CASEMATE GLB OK**：模块 7 节点 / 2 mesh / 3 图元 / 108 tri / bbox / 3 材质 / 外部贴图字节 / UV / 节点链 / 根 extras；铁甲舰 26 节点 / 8 158 tri / 尺寸不变 / 12 端口 translation+朝向+extras / Root 三套名单 |
| `verify_ship_weapon_sockets_glb.py` | **4/4 ALL OK**（IC 26 节点 / 8 158 tri；其余 3 艘不变） |
| `verify_legacy_uv_b_glb.py` | **21 files, 0 failures**（IC 期望更新为 26 节点 / 8 158 tri） |
| `verify_ironclad_glb.py` | ALL GLB OK |
| `verify_lod1_kit_ships_glb.py` | LOD1 VERIFY OK：IC LOD0 8 158 / LOD1 1 656 = 0.203 ≤ 0.30；船组 LOD0 合计 45 296、LOD1 9 026；manifest 4/4 |
| `verify_weapon_glb.py` | 5/5 ALL OK（新模块不在旧 EXPECTED 里，不参与该表） |

### 4.2 Blender 场景（只读复核）

| 检查 | 结果 |
| --- | --- |
| 现存网格 vs 生成器 | 顶点 5 133 / 面 4 624 / tri 8 158，逐材质面数完全等于 `build_ironclad(with_barrels=False)` |
| 炮管残留 | 480 个炮管面 / 384 个炮管顶点，1 mm 容差哈希命中 **leaked = 0** |
| 网格健康 | 非流形 0 / 边界边 0 / 孤立点 0 / 退化面 0 |
| socket 复核 | 4 武器 + 9 帆索 + 12 炮门全部 `passed`；补 socket 前后几何快照不变 |
| 端口实测 | 门内纵深 4.245–8.000 m（≥ 声明 1.10）、舷外 8.000 m（≥ 声明 6.00） |

### 4.3 Godot

| 检查 | 结果 |
| --- | --- |
| `test_ship_gun_ports.gd`（新增 3 例） | 12 个炮门空节点为 Root 直接子级、无 mesh；4 个甲板 socket 未被挤掉；Root `gun_port_sockets` 名单 / 计数 / spec 与端口 extras（port_class / 尺寸 / inboard_depth / lid）；模块 GLB 的 `port_pitch` 契约与 `muzzle_protrusion` / `breech_depth` |
| `test_lod1_assets.gd` | LOD0 船组总 tri 常量 45 968 → **45 296**（−672）；LOD1 部分不变 |
| 全量 headless 套件 | **394 passed / 0 failed**（`test_runner.gd`；新增 `test_ship_gun_ports.gd` 3 例、`test_legacy_uv_assets_b.gd` 与 `test_lod1_assets.gd` 的 LOD0 总量基线同步） |
| Godot 资产探针（`tools/godot/`） | `verify_lod1_kit_ships.gd`：30 件 / 67 共享贴图实例 / 0 失败，IC L0 8158 L1 1656（0.203）；`verify_legacy_uv_materials_b.gd`：21 件 / 24 实例 / 0 失败 |

### 4.4 独立 Verifier 复核（只读子代理）

复核手段：Blender 4.4.3 活体只读查询（`bpy` / `bmesh` / `mathutils.KDTree`）+ 自写 GLB 解析（节点 TRS / 世界矩阵 / accessor / 图元 / 贴图 sha256 / UV）+ 运行本批 8 个验证脚本；未改文件、未写场景。

| 复核项 | 结果 | 证据摘要 |
| --- | --- | --- |
| 现存网格 = 生成器空炮门变体 | PASS | 5133 / 4624 / 8158 完全一致；逐索引最大偏差 9.413e-7；逐材质面数 / tri 全等 |
| 384 个烘焙炮管顶点零残留 | PASS | KDTree 最近距离 0.928 m（1 mm 内 0 个）；并用 git HEAD 旧 GLB 反证旧件 = full 变体、多出的 384 点逐点匹配炮管 |
| 网格健康 | PASS | 非流形 / 边界 / 孤立 / 退化 全 0 |
| 12 个 socket 位姿 | PASS | 活体位置偏差 3.4e-6 m、`+X` 2.6e-8；GLB translation 5.5e-7；extras 0 mismatch；左右镜像正确 |
| 装炮逐点重合 | PASS | 用 GLB 真实炮管几何经 float64 位姿：与烘焙炮管 384/384 匹配、最大 6.65e-8（源位姿 0.0）；改用 GLB/Blender float32 socket 矩阵时最大 4.29e-6 m（序列化精度，远小于契约 `LOC_TOL=1e-4`） |
| 隐藏段 / 俯仰限位 | PASS | 40 个隐藏顶点全 `x<0`，max\|y\|=max\|z\|=0.44 < 0.95；−6°/+12° 可见段 max\|z\| 0.658 / 0.809 |
| 两份 GLB 结构 / 贴图 / UV | PASS | 模块 7 节点 / 2 mesh / 3 图元 / 108 tri / 3 外部 PNG 字节一致；铁甲舰 26 节点 / 8 图元 / 8158 tri / bbox 与旧件完全相同 / 三套名单与 12 端口 extras 正确 |
| 验收脚本 | PASS | 8 个脚本全 exit 0（本表 §4.1） |
| 视觉 | PASS | 5 张预览可辨认、无穿模 / 悬空；空载深色板偏木棕属已知取舍（§7） |

复核发现并已修复的 **7 项遗留问题**（全部是 “LOD0 8830 → 8158” 之后的旧基线 / 旧口径，不是资产缺陷）：

| # | 问题 | 修复 |
| --- | --- | --- |
| 1 | `tools/godot/verify_legacy_uv_materials_b.gd` ships 45968 | → 45296（含注释口径） |
| 2 | `dryrun_lod1_kit_ships.py` `SHIP_LOD0_BASELINE = 45968` | → 45296 |
| 3 | `tools/godot/verify_lod1_kit_ships.gd` IC `lod0: 8830` | → 8158（LOD1 仍是拆炮前旧件） |
| 4 | `tools/modeling/lod1_kit_ships_plan.json` IC `lod0_tri: 8830` | 重跑 `install_lod1_kit_ships.py` 生成（8158，totals lod0=87354） |
| 5 | `ASSET_MAP.md` LOD1 总表 8830 / 45968 / 88026 | → 8158 / 45296 / 87354（20.30 % / 19.9 % / 22.7 %） |
| 6 | `ASSET_MAP.md` 工具行 + `LOD1_BASE_KIT_ACCEPTANCE.md` 旧口径 | 工具行改 26 节点 / 8158 tri；归档文件加“交付后变更”说明（保留交付时快照） |
| 7 | `ASSET_MAP.md` 铁甲舰行“外露 1.55 m” | → 1.5407 m（与模块 extras / §3 一致） |

修复后重跑：`dryrun_lod1_kit_ships.py` OK（ship LOD0 45296）、`verify_lod1_kit_ships_glb.py` LOD1 VERIFY OK、两个 Godot 探针 0 失败、`gen_rig_kit_catalog.py` 仅 IC `mesh_baseline` 8830 → 8158。

## 5. 过程发现（踩到的真问题）

1. **活体 Blender 会缓存纯 Python 模块**：`sn_weapon_materials` 在 Blender 进程里是旧版，
   新加的材质白名单键拿不到 → `KeyError: 'SN_Weapon_CasemateGun'`。修法：落盘脚本对
   材质白名单模块也做 `importlib.reload`（与 §11.13 / §11.17 的教训同源）。
2. **`mesh.materials` 不是 material slot 集合**：`for slot in mesh.materials: slot.material`
   会抛 `AttributeError: 'Material' object has no attribute 'material'`，应直接 `for mat in mesh.materials`。
3. **1 mm 量化仍会在 float32 边界翻边**：第一版几何门禁用 `round(...,3)` 比对坐标，
   Blender 的 float32 存储让 17 个面在 0.0005 附近翻到相邻格 → 误报“资产与生成器漂移”。
   最终改成**按索引比对**（顶点逐点容差 + 面顶点集合 + 材质），不依赖量化。
4. **预览近景相机用了船体局部坐标**：`CLOSEUP_TARGET`（炮门中心）是船体局部坐标，
   但船体对象在工作台摆位 (0, 90, 0)，直接拿去当世界坐标会把镜头对到 90 m 外的空气里，
   渲染出纯背景。修法：`ironclad.matrix_world @ CLOSEUP_LOCAL`。
5. **GLB 验收的 identity 矩阵下标**：4×4 单位阵的 1.0 在索引 0/5/10/15，漏写 15 会把
   “单位阵”判成失败——这是验收脚本自身缺陷，不是资产缺陷。
6. **其它 3 艘船不能直接挂穿壳炮**：它们没有炮门开口，炮管会从完整船壳板里长出来；
   必须先做「炮门舱段 / port cassette」适配件（见 §7）。
7. **批量文本替换脚本误伤两个文件（已修复）**：修 LOD1 旧基线时一次 PowerShell 批量替换
   把 `tools/godot/verify_lod1_kit_ships.gd` 的全部 `{` 换成了 `"`、把
   `docs/design/WEAPON_SOCKET_CONTRACT.md` 的全部 `铁` 换成了 `甲`（单元素数组被当成字符串，
   字符串按字符索引）。按“结构还原”修复：`""` → `{"`、`:= "}` → `:= {}`、`甲甲舰` → `铁甲舰`，
   并做花括号配平（36/36）、空引号 0、剩余 `甲` 全在 `甲板` / `铁甲舰` 里；两个文件重跑/解析
   均通过。教训：批量文本编辑必须走**成对替换 + 断言命中次数**，不要用位置参数拼数组。

## 6. 最终回归

- 全量 headless 套件：`godot --headless --path . --script res://framework/tests/test_runner.gd`
  → **394 passed / 0 failed / 394 total**（329.5 s）。新增 `test_ship_gun_ports.gd` 3 例；
  受本批影响的 `test_legacy_uv_assets_b.gd`（船组 45296）与 `test_lod1_assets.gd`
  （LOD0 45296）已同步基线。
  > 说明：Godot 进程退出码为 1 来自退出期 RID / 资源泄漏检查（`RendererDummy` 等，属于
  > 无头测试运行器的既有噪声，仓库基线日志同样如此），不是测试失败；测试运行器本身的
  > 汇总行为 `394 passed, 0 failed`。
- 独立 Verifier（只读子代理）复核：§4.4 的 7 项遗留问题全部修复后重跑；
  资产层（几何门禁、炮管清除、端口位姿、装炮重合、隐藏段、两份 GLB、8 个脚本、5 张预览）全部 PASS。
- 静态文档：`node tools/gen_static_docs.mjs` 重新生成、`--check` 通过（344 文件页 / 887 manifest 条目）。
- 其它资产探针：`verify_lod1_kit_ships.gd` 30 件 / 67 实例 / 0 失败；`verify_legacy_uv_materials_b.gd`
  21 件 / 24 实例 / 0 失败；`gen_rig_kit_catalog.py` 仅把 IC `mesh_baseline` 8830 → 8158。

## 6.1 跟进修复：炮门框 / 暗板 / 门盖贴合船壳弧面（2026-10-22）

**问题**（用户截图发现）：炮门框与深色炮口板是平面件，按炮门中心的平滑半宽 `side_y_at()` 取值，
而船壳是 17 站放样（站间线性）。沿炮门 2.3 m 宽度方向，平面件会离开壳面：实测边缘最大间隙
**0.241 m**（艏部 x=±17.5），其余炮门 0.04–0.20 m；空载近景可见框边浮起、投影悬空。

**修复**：
- 新增 `hull_surface_y(x, z)`：按 **站间线性插值** 还原放样网格实际表面（与 `build_hull()` 一致）；
- 炮门框四条边、深色炮口板、上翻炮门盖内缘全部改为**逐角取** `hull_surface_y()`（框/板为 6 面闭合薄板，
  每个角点独立取壳面 y），几何按构造贴合，间隙归零；
- `gun_port_pose()` 同步改用 `hull_surface_y()`，炮门 socket 中心随壳面下移 **0.010–0.026 m**
  （z / x 不变），保证炮管仍从暗板中心穿出；
- 三角面数不变：**8158 tri**（每个炮门仍 6 个面件），网格健康四项仍全 0，包围盒
  60.13 × 18.00 × 28.64 m 不变；
- 重跑 `rebuild_ironclad_ports.py`：船体重建 → 4 武器 + 9 帆索 + 12 炮门 socket 复挂 → 只读复核全过；
  重导 `SN_Ironclad.glb`（26 节点 / 8158 tri / 573.3 KB），模块 GLB 未变；
- 验收：`verify_casemate_glb` / `verify_ship_weapon_sockets_glb` / `verify_legacy_uv_b_glb` /
  `verify_ironclad_glb` / `verify_lod1_kit_ships_glb` / `sn_ship_gun_ports --check` 全绿；
  `dryrun_ironclad` / `dryrun_casemate_gun` 全绿（装炮重合仍为 0）；
- 预览重渲：`ironclad_casemate_{guns,empty}_closeup.png`。

**端口坐标变化**（船体局部 y，其余不变）：

| 端口 | 旧 y | 新 y |
| --- | ---: | ---: |
| `_Port_1` | 5.073 | 5.051 |
| `_Port_2` | 5.838 | 5.825 |
| `_Port_3` | 6.178 | 6.168 |
| `_Port_4` | 6.165 | 6.152 |
| `_Port_5` | 5.722 | 5.706 |
| `_Port_6` | 4.736 | 4.711 |

实测门内纵深随之变为 **4.245–8.000 m**（声明 1.10 m，仍远低于实测）。

## 7. 边界与后续

| 项 | 状态 |
| --- | --- |
| 运行时装配 `ShipVisualAssembler` | 仍未接入；本批只交付资产 / socket / 契约 / Godot 守护 |
| 其它 3 艘船的炮门 | 需要 `port cassette`（开口 + 暗腔 + 标准 port 接口）后续批次 |
| `SN_Ironclad_LOD1.glb` | 仍是拆炮前旧件（LOD 切换未接线）；重建 LOD1 列为后续项 |
| 内容镜像 `hull_data.gun_port_sockets` | 本轮未做（运行时不读，编辑器镜像后续补） |
| Core manifest 键 | 未登记（与武器批次 1/2 一致）；将来接装配时补 `model.weapon.casemate_gun` |
| 空载读感 | 炮门框 + 木制深色炮口板 + 开着的门盖；如需“暗腔”读感要做 port cassette 或改内腔材质 |
