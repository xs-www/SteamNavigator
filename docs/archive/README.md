# 开发已完成的设计文档（归档）

> 作用：这里存放**已经完成并验收**的设计 / 实施契约 / 验收报告，保留历史决策与证据；不再作为后续开发的现行方案。
> 现行设计与规划仍在 [docs/design](../design/)：`2.5D_STAGE_PLAN`、`NAUTICAL_CHART_SYSTEM`、`ASSET_MAP`、`ENTITY_CONTRACT_V2`、`PERSISTENT_CAMPAIGN_ARCHITECTURE`、`FULL_GAME_ROADMAP`、`DEV_PLAN_2026-10`、`MODELING_WORKFLOW`、`COMBAT_ARCHITECTURE_REVIEW`、`UI_PROTOTYPE`。
> 截图仍是本地生成物，保留在 [docs/design/screenshots](../design/screenshots/)（已忽略、不入库）；静态代码文档 [docs/static](../static/) 由生成器维护，不在归档范围内。

## MVP 设计基线

- [MVP GDD v1.0](蒸汽航海_MVP_GDD_V1.0.md) — MVP 游戏设计文档
- [项目架构方案：框架 + 模组 v1.0](蒸汽航海_项目架构方案_框架与模组_V1.0.md) — 框架/模组分层与启动链路
- [模组实体与约束规范](Steam_Navigator_Mod_Entity_Constraints_Spec.md) — Schema 1.0 实体与约束（已由 `ENTITY_CONTRACT_V2` 接续）

## 试玩反馈与迭代契约

- [MVP 试玩反馈](MVP反馈.md) — 玩家 6 条反馈原文
- [迭代 1 · MVP 闭环实现契约](ITERATION_1_MVP_LOOP.md)
- [迭代 2 · MVP 反馈优化实现契约](ITERATION_2_MVP_FEEDBACK.md)
- [船舶模块实例化](SHIP_MODULE_INSTANCES.md) — 模块实例 id / 部件损耗（已落地）

## 界面重构

- [船厂界面重构（图 2 / 图 3 布局）](SHIPYARD_UI_REFACTOR.md)
- [高频决策页面重构指南](HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md)

## 铁港建筑套件（阶段 1 → 批次 A / B）

- [阶段 1：Warehouse_Long LOD0 灰模 + R1](IRON_HARBOR_ARCHITECTURE_PHASE1.md)
- [M1：朝向调整 + 共享材质 / trim sheet](IRON_HARBOR_ARCHITECTURE_M1.md)
- [第二批：其余 4 栋 drop-in（M2）](IRON_HARBOR_ARCHITECTURE_BATCH2.md)
- [批次 A 技术样板：共享外部贴图](IRON_HARBOR_ARCHITECTURE_SHARED_TEXTURES.md)
- [批次 A：5 栋 LOD1 生成 + 檐口修复](IRON_HARBOR_ARCHITECTURE_LOD1_BUILD.md)
- [批次 A：LOD1 独立验收](IRON_HARBOR_ARCHITECTURE_LOD1_VERIFY.md)
- [批次 A 验收（LOD1 + 共享贴图 + 檐口修复）](IRON_HARBOR_ARCHITECTURE_BATCH_A.md)
- [批次 A 最终独立终验](IRON_HARBOR_ARCHITECTURE_BATCH_A_VERIFY.md)
- [批次 B：三栋新原型 LOD0 + LOD1](IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_BUILD.md)
- [批次 B 第一阶段：三栋原型 LOD0 独立验收](IRON_HARBOR_ARCHITECTURE_PROTOTYPES_LOD0_VERIFY.md)
- [批次 B 验收（三栋新原型 + 两港组合接线）](IRON_HARBOR_ARCHITECTURE_BATCH_B.md)
- [批次 B 最终独立终验](IRON_HARBOR_ARCHITECTURE_BATCH_B_VERIFY.md)

## 建模资产

- [建模资产第一轮验收报告（2026-10-19）](MODELING_ACCEPTANCE_2026-10-19.md)
- [下一批 3D 建模与资产优化需求 v1（A/B/C 三批已完成）](MODELING_REQUIREMENTS_NEXT_BATCH.md)

## SN_Paddle_Steamer 批次 C

- [批次 C 验收：视觉精修](PADDLE_STEAMER_BATCH_C.md)
- [批次 C：雨棚减重 / 明度层次 / 暗红压条](PADDLE_STEAMER_VISUAL_POLISH_C.md)
- [批次 C 独立只读终验](PADDLE_STEAMER_VISUAL_POLISH_C_VERIFY.md)
