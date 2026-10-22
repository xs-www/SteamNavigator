# base_kit 生产建筑 M1-2 验收（批次 5：基地生产链 5 件，2026-10-22）

> 状态：**已交付并验收**。本文档保留验收证据与决策快照；契约与目录以
> [KIT_ASSET_LIBRARY.md §13](../design/KIT_ASSET_LIBRARY.md) 为准。

## 1. 范围

backlog [M1-2](../design/MODELING_BACKLOG.md) 的 5 件基地生产建筑（用户 2026-10-22 在批次 4
交付后指示「先做 M1-2」）：

| 资产 | 角色 | 体量 / 包围盒（Blender 口径, m） | tri / 预算 |
| --- | --- | --- | ---: |
| `SN_Base_Sawmill` | 锯木厂（原木坡道 + 立式锯盘 + 木料堆 + 传动轴） | 11.30 × 7.54 × 6.05 | 2 684 / 3 800 |
| `SN_Base_Smelter` | 冶炼炉（收分高炉 + 热风炉 + 上料斜桥 + 烟囱） | 9.10 × 7.72 × 11.40 | 3 012 / 4 000 |
| `SN_Base_Foundry` | 铸造车间（厂房 + 冲天炉 + 行车/浇包 + 模具区） | 12.95 × 8.55 × 9.15 | 4 096 / 4 600 |
| `SN_Base_Stockyard` | 仓库堆场（围栏 + 分区堆垛 + 龙门吊 + 地磅 + 小亭） | 13.20 × 11.00 × 6.20 | 3 260 / 3 600 |
| `SN_Base_Defense_Tower` | 防御塔（收分塔身 + 炮位平台 + 弹药库 + 登塔梯） | 7.50 × 7.26 × 12.25 | 2 896 / 3 400 |
| **合计** | | | **15 948 / 19 000** |

工单：`tools/modeling/briefs/sn_kit_batch5_base_kit.json`。
生成器：`tools/modeling/generators/kit_batch5_generator.py`。
新类别目录：`assets/models/base/`（开发态）+ `dev_mods/core/assets/models/base/`（Core 副本），
`shared_materials.spec.json` 的 `runtime_dirs` 已追加两条。

## 2. 自动验收证据

### 2.1 纯 Python 干跑（`dryrun_kit_batch5.py`）

5/5 `ALL OK`：命名 / 父级 / tri / bbox / zmin=0 / 网格健康 / 材质白名单 / 共享贴图 / socket 契约，
以及本批专属「生产链布局断言」（锯盘高度、炉体收分、上料平台高度、斜桥落地、浇包净空、
龙门吊/堆垛关系、塔身收分、梯子落地、承托面）。

### 2.2 GLB 自检（`verify_kit_batch5_glb.py`）

```text
glb                            nodes  mesh prims   tris budget size(Y-up x,y,z)   textures flags
SN_Base_Sawmill                   15     8    27   2684   3800 11.30,6.05,7.54       8 external ok
SN_Base_Smelter                   18     9    31   3012   4000 9.10,11.40,7.72      8 external ok
SN_Base_Foundry                   18     9    38   4096   4600 12.95,9.15,8.55      9 external ok
SN_Base_Stockyard                 16     8    33   3260   3600 13.20,6.20,11.00    11 external ok
SN_Base_Defense_Tower             17     8    30   2896   3400 7.50,12.25,7.26      8 external ok
shared textures: 11 x 2 runtime dirs
verify_kit_batch5_glb: 5/5 ALL OK
```

逐件断言：节点/网格/图元非空、tri 与生成器几何一致且 ≤ 预算、世界 bbox 与工单一致、
min z ≈ 0、材质全 `SN_Tex_*`、全 doubleSided、每图元 `TEXCOORD_0`、`images[].uri` 指向
`shared_materials/<texture>.png` 且与授权 tile 逐字节一致、assets ↔ Core 双副本一致、
Root extras（含 `module_grid=4.0` / `production`）与 socket 父级/坐标正确。
GLB 合计 1 212 768 B（204 160 / 225 088 / 311 444 / 250 748 / 221 328）。

### 2.3 独立 Verifier（只读，Blender 4.4.3）

**首轮（R3 后）**：passed=false —— 3 项失败：Sawmill LogRamp −Y 端悬空 0.13 m、Stockyard 原木堆
穿小屋（354 对三角）、Tower 箭孔玻璃外浮 0.125/0.365 m。
**最终复验（R5 后）**：**passed=true / failures=[]**
- Sawmill LogRamp zmin=0.1796（≥0.17），最低点向下 gap = −0.0004 m（贴合铺台 0.18）；
- Stockyard Stacks×Hut / ×Gantry / ×Fence 三角相交 = 0；堆顶 2.76 < 横梁下沿 4.897；
- Tower 12 块箭孔玻璃 12/12 与塔身贴面、detached 扫描 0；登塔过桥底面 9.20 与炮位台面齐平，
  梯子 0→9.32 连续；`Ladder_Foot` socket (0, −3.05, 0) 与 brief 同步；
- 5 件 tri/bbox/zmin/网格健康（42 mesh 四项全 0）/UV 42/42/材质 11 张 SN_Tex_* 512²/37 socket/
  Root extras 全部通过；回归 983 对象（899 非本批 + 84 本批）、73 集合、Camera=2、Light=1、
  抽样既有 Root 坐标不变；blend 16:21:07 保存，5 件 GLB 与 Core 副本 SHA-256 逐件一致。

## 3. Godot 运行时

- 新增 `framework/tests/cases/test_base_kit_assets.gd`（2 例）：5 件 GLB 全部外链
  `shared_materials/*.png`、每面 UV、材质全 `SN_Tex_*`、tri 锁定（逐件 + 合计 15 948）、
  跨 5 件同一 `Texture2D` 实例（11 张）。
- 全量 headless：**456 passed / 0 failed**（含新用例；其中 2 例为本批）。

## 4. 预览

`docs/design/screenshots/kits/`：

- `kit_base_lineup.png`（5 件 lineup，正立面朝相机）
- `kit_base_assembly.png` / `kit_base_assembly_detail.png`（生产链基地拼装 + 近景）
- `kit_{sawmill,smelter,foundry,stockyard,defense_tower}_{three_quarter,side}.png`

## 5. 交付物

- 5 个 GLB：`assets/models/base/` + `dev_mods/core/assets/models/base/`
- 新类别共享贴图 11 张 ×2 目录（`assets/models/base/shared_materials/` 与 Core 副本）
- 生成器 / 干跑 / 导出 / GLB 验收 / 预览 5 个脚本
- `kit_catalog.json` v1.5（37 件 / 70 590 tri，+4 条生产链配方）
- Godot 用例 + [KIT_ASSET_LIBRARY §13](../design/KIT_ASSET_LIBRARY.md) /
  [MODELING_WORKFLOW §11.21](../design/MODELING_WORKFLOW.md) /
  [ASSET_MAP 批次 5](../design/ASSET_MAP.md) 文档

## 6. 过程记录（返工与决策）

| 轮次 | 触发 | 处理 |
| --- | --- | --- |
| 干跑 v1 | mesh/socket 同名 4 处（Chimney×2 / Scale / Magazine / Searchlight）、2 件 bbox 偏差、未声明材质（SkipHoist Wood_Dark）、`_gable_roof` 对小屋/弹药库屋顶错位 | 改名 Stack / Weighbridge / PowderStore / Lamp；改 bbox 目标；补材质白名单；新增 `_gable_roof_at` 支持任意 Y 中心 |
| Builder R0 | 2 个真缺陷：Foundry 浇包桶底 1.30 与模具台 1.46 互穿 38 tri、Tower 探照灯悬空 0.092 m | 生成器：浇包整组 +0.25（桶底 1.55）、探照灯加灯座、梯子加登台过桥、Stockyard Scale socket 0.18→0.30 |
| Builder R1 | 复核通过（15 612 tri） | 记录为基线 |
| Builder R2 | 视觉挑刺：Foundry 深色墙读成黑盒、看不到门 → 加石腰线/石门套/亮木门板/招牌 | 复核发现**新构件全被 +X 铁板墙（x=6.13）吞没**，且招牌铆钉 stray 落室内 |
| Builder R3 | +X 立面构件全部外移到墙面外（门板 6.15–6.25、招牌 6.37–6.43、腰线 6.13–6.24），铆钉改 axis=(1,0,0) | **BVH 射线复核**：+X 首命中门板/招牌/腰线而非墙板；passed=true |
| 独立 Verifier | Sawmill LogRamp 端部悬空、Stockyard 原木堆穿小屋、Tower 箭孔玻璃外浮 | Lead 改生成器（不手工补几何） |
| Builder R4 | 3 项修复 + 登台过桥齐平 + astragal + 拉手贴门 | 复核：Tower 箭孔 12/12 贴面、过桥齐平；但矿石堆移入小屋 footprint、煤堆撞龙门吊腿、Sawmill 端辊仍嵌 5 cm |
| Builder R5 | 矿石堆移到 +X/+Y 空角、煤堆收 Y、端辊中心 1.30−1.00f 落铺台、brief Ladder_Foot 同步 −3.05 | **相交/射线复核**：LogRamp zmin=0.1796 / gap −0.0004；Stacks×Hut=0 / ×Gantry=0 / ×Fence=0；passed=true |
| 独立 Verifier 复验 | — | **passed=true / failures=[]**；导出与副本哈希一致 |

遗留（非阻塞，记录备查）：

1. Foundry 为实心墙厂房，内部冲天炉 / 行车 / 浇包 / 模具区从外部仅透出烟囱与采光顶，
   近景或 M1-3 切面内景才看得到内部机具（设计取舍）；
2. Sawmill 大锯盘在材质布光下偏暗（造型/轴心正确），后续可在 Godot 侧加灯或材质高光；
3. Sawmill DriveShaft 下端皮带护块距上方支架 0.07 m（被红色皮带环遮挡、视觉不可见）；
4. 若干设计性贴合互嵌（同堆料碎石、装配嵌入地面/墙体）与灯柱/门柱装配嵌入，非穿模缺陷；
5. Tower 登台过桥板顶面 9.32 比炮位台面 9.20 高一个板厚（0.12 m 台阶），可接受；
6. 本批 LOD1 未做；运行时基地舞台 / PortStage 接入另立任务。
