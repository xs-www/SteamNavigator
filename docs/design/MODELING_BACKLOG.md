# 建模需求 Backlog（3D 资产）

> 状态：Active（2026-10-22）
> 盘点基线：模型素材库 kit 26 件（批次 1–3，42,058 tri）、舰载武器 8 件（16,996 tri，装配规范 v2）、船 4 艘 + 原型、铁港建筑 16 栋（8 LOD0 + 8 LOD1）、起重机 4 台、旧道具 31 / 港口设施 6 / 船模块 11 / 旧小镇 10。
> 相关：[KIT_ASSET_LIBRARY.md](KIT_ASSET_LIBRARY.md) · [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md) · [ASSET_MAP.md](ASSET_MAP.md) · [MODELING_WORKFLOW.md](MODELING_WORKFLOW.md)

本文件只列**建模/资产侧**待办，不包含玩法、UI、运行时装配代码；接入类任务见 [todo.md](../../todo.md)。

## 1. 已完成基线（不再重复）

- kit 批次 1–3：weapon_kit / ship_parts / machinery / cargo / dock / architecture / environment，共 26 件，42,058 tri，`kit_catalog.json` 含 13 条装配配方；
- 舰载武器 8 件 + kit 武器部件 + 甲板 socket，已统一为武器装配规范 v2（`SN_Socket_Weapon` / `SN_Mount` / `SN_Pivot_Yaw` / `SN_Pivot_Pitch` / `SN_Recoil` / `SN_Muzzle`）；
- 共享贴图 11 张（`SN_Tex_*`），GLB 全部外部 URI，BLEND 工作台 Solid 统一灰模；
- 旧铁港建筑 16 栋已带 `SN_TEX_*` 图集贴图；旧道具 / 设施 / 模块 / 船仍是纯色 `SN_*`。

## 2. P0：接入前的硬缺口

| ID | 任务 | 内容 | 量 / 预算 | 依赖与说明 |
| --- | --- | --- | --- | --- |
| M0-1 | 旧资产 UV 迁移 A | 31 件铁港道具 + 6 件港口设施：补 UV、切 `SN_Tex_*`、重导 GLB | 37 件，tri 基本不变 | 纯材质/UV 改造，不改几何；完成后旧纯色 `SN_*` 从港区退场 |
| M0-2 | 旧资产 UV 迁移 B | 11 件船模块 + 4 艘船 + 旧小镇 10 件 | 25 件 | 船体 UV 工作量大，单独一批；含舷侧、甲板、帆面分区 |
| M0-3 | 船侧武器安装点 | 4 艘船各加 2–4 个 `SN_Socket_Weapon*` 空节点 + `socket_class / clearance_r / clearance_h` extras | 4 件，无几何 | 配合武器 v2；不要求整块甲板，空节点即可 |
| M0-4 | `rig_kit` 船体部件库 | 桅杆 / 斜桁 / 帆面 / 索具参数化，接口 `SN_Socket_Mast/Yard/Sail` | 8–12 件，约 6–8k tri | 替换现有船体上焊死的帆索；接 `ShipVisualAssembler` |
| M0-5 | LOD1 基础套件 | kit 26 件 + 船 4 艘 + 铁港建筑 16 栋的远景低模 | 约 40 件 | 2.5D 舞台远景与低配档必需；LOD2 billboard 后续 |

## 3. P1：2.5D 舞台 / 基地 / 事件内容

| ID | 任务 | 内容 | 说明 |
| --- | --- | --- | --- |
| M1-1 | architecture_kit 扩展 | 围墙 / 大门 / 道路 / 装卸平台 / 仓库变体 / 工坊扩建 | 阶段 3 基地需要“可围合”模块；当前只有 4 栋独立建筑 |
| M1-2 | `base_kit` 生产建筑 | 锯木厂 / 冶炼炉 / 铸造车间 / 仓库堆场 / 防御塔 | 与 machinery_kit（齿轮/动力/卷扬）拼装，支撑生产链 |
| M1-3 | `interior_kit` 切面内景 | 酒馆 / 船长室 / 仓库 / 办公室固定机位内景 | 委托 / 情报页舞台化；低模切面，不做可走室内 |
| M1-4 | environment_kit v2 | 悬崖 / 沙滩 / 小岛 / 植被 / 残骸变体 / 浮标变体 / 冰山 / 漩涡 | 事件化海洋与探索；需新增贴图（草 / 苔 / 沙 / 冰） |
| M1-5 | 港口变体 | 第二港口建筑组、市场摊、信号塔、干船坞 | 旧 `SN_Port_Facilities` 先迁移，再补新设施 |
| M1-6 | 战斗残骸 / 损伤状态 | 断桅 / 破帆 / 船体破洞 / 燃烧残骸 | 可替换 mesh；战斗结算与事件舞台使用 |

## 4. P2：探索 / 敌人 / 内容量

| ID | 任务 | 内容 | 说明 |
| --- | --- | --- | --- |
| M2-1 | `combat_kit` 敌舰 | 海盗单桅 / 武装商船 / 铁甲舰变体 / 小型炮艇 | 阶段 2 需要 3 类敌人；复用现有船体骨架与武器 socket |
| M2-2 | `sea_monster` | 海蛇 / 巨型触手 / 浮上海面的背脊 | 阶段 5 事件与航行危险；低模 + 分段动画节点 |
| M2-3 | `ruins_kit` | 程序化遗迹房间：墙 / 门 / 柱 / 楼梯 / 祭坛 / 机关 / 宝箱 | 阶段 5 遗迹探索；按房间模块拼装 |
| M2-4 | expedition props | 营地 / 火把 / 绳索 / 脚手架 / 探险道具 | 遗迹与海岛事件点缀 |
| M2-5 | LOD2 / impostor | 远景船长距离 billboard、港口远景 LOD | 质量档位与低配回退 |

## 5. 建议批次顺序

1. **批次 4**：M0-1 旧资产 UV 迁移 A（37 件道具/设施）——收益最大、风险最低。
2. **批次 5**：M0-3 船侧武器 socket + M0-4 `rig_kit`——把武器 v2 与船体部件接起来。
3. **批次 6**：M0-5 LOD1 + M2-1 `combat_kit` 敌舰。
4. **批次 7**：M1-1 architecture_kit 扩展 + M1-2 `base_kit` + M1-3 `interior_kit`。
5. **批次 8**：M1-4 environment_kit v2 + M2-3 `ruins_kit` + M2-2 `sea_monster`。

## 6. 跨批次统一要求

- 材质：只用 `SN_Tex_*` 共享贴图 + 世界空间盒式 UV；新增贴图先扩 `docs/design/textures/shared_materials/shared_materials.spec.json` 与 `tools/art/gen_shared_material_textures.py`，禁止单件资产自带贴图；
- 接口：Root + `SN_Mount` / 语义 socket + Root extras；武器继续按 v2（可选 Yaw/Pitch/Recoil/Muzzle）；建筑按 4 m 网格 `Module_Next/Prev`；遗迹按房间模块；
- 质量：闭合壳体，边界边 / 非流形边 / 退化面 / 孤立点全 0；无浮空（支撑面测量，不只看 bbox）；
- 交付：GLB 外部贴图 URI + Core 副本；`dryrun_*.py`、`verify_*_glb.py`、预览图、独立 Verifier 只读验收；
- 预算：按批次在工单里给 tri 预算与 bbox 目标，超预算先减细节而不是破契约。

## 7. 待决

1. 第二港口风格：同铁港图集换色，还是新建一套材质/图集？
2. `rig_kit` 帆面是布面网格还是 Godot 侧布料/顶点动画？模型侧只交付参数化挂点与低模帆面。
3. 敌舰是否复用玩家船体骨架（省预算）还是独立轮廓（可读性更好）？
4. 内景切面是否统一 1 m 墙厚 / 固定机位套装，还是按场景单独构图？
