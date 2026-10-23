# `framework/tests`

> 无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、委托刷新、仓库存取、打造订单/替换/在港等待、船厂改装 UI、UI 外壳接线、2.5D 舞台基础设施、总览页 3D 港口舞台接入、D0 模拟时钟、D1 自动战斗、D2 舰队、完整通关流程与坐标空间世界生成器。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `cases/test_architecture_extension_assets.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_auto_trade.gd` | Phase D4 自动贸易运行时测试：策略启动/停止/切换、规则暂停与恢复、买卖航程、 | [查看](./cases/test_auto_trade.gd.md) |
| `cases/test_base.gd` | Phase D3 基地运行时的回归测试：`data.base` 惰性结构、占领/建造/升级、 | [查看](./cases/test_base.gd.md) |
| `cases/test_base_kit_assets.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_campaign_assembly.gd` | Phase B B3-A 战役世界装配测试（WORLD_SCHEMA_V2_RUNTIME §6.2/§6.3/§6.4）：用 | [查看](./cases/test_campaign_assembly.gd.md) |
| `cases/test_campaign_start.gd` | C4 开局入口测试：`run.start` 的默认路径（无 start_profile）与显式 start_profile | [查看](./cases/test_campaign_start.gd.md) |
| `cases/test_campaign_state.gd` | CampaignState 分区测试：分区惰性补齐、探索进度只追加 id、阵营声望夹取，以及分区随存档往返。 | [查看](./cases/test_campaign_state.gd.md) |
| `cases/test_combat.gd` | Phase D1-B 战斗自动结算测试。用最小合成 RegistryHub（武器 / 伤害类型 / 能力 / | [查看](./cases/test_combat.gd.md) |
| `cases/test_combat_kit_assets.gd` | `combat_kit` 敌舰套件（M2-1，4 艘 `SN_Enemy_*.glb`）的运行时守护用例：资产必须 | [查看](./cases/test_combat_kit_assets.gd.md) |
| `cases/test_content_asset_loader.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_content_types_manifest.gd` | content_types.json 与框架 ContentTypes / 本地 Schema 文件的一致性守护，防止单一真源在过渡期漂移。 | [查看](./cases/test_content_types_manifest.gd.md) |
| `cases/test_content_versions.gd` | 按内容类型声明 Schema 版本（Phase A）与 Phase B 世界/战役家族提升 active 的 | [查看](./cases/test_content_versions.gd.md) |
| `cases/test_contract_flow.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_contract_refresh.gd` | 迭代 1 委托池测试：抵达刷新、持有上限、port.view 字段与同 seed 刷新确定性。 | [查看](./cases/test_contract_refresh.gd.md) |
| `cases/test_craft_wait.gd` | 迭代 2 打造订单测试：tier1 仅金币配方、下单不即时入库、port.wait/抵达结算与旧存档补齐。 | [查看](./cases/test_craft_wait.gd.md) |
| `cases/test_events_effects.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_expedition.gd` | Phase D5 遗迹远征运行时测试：开始/进入/事件选择/撤退/完成奖励、危险结算、 | [查看](./cases/test_expedition.gd.md) |
| `cases/test_exploration.gd` | 探索系统（阶段 4.1–4.4）领域层无头测试：线索生成 / 固定 1 级 / 逐级调查 | [查看](./cases/test_exploration.gd.md) |
| `cases/test_fleet.gd` | Phase D2 舰队运行时的回归测试：`data.fleet` 惰性结构、旗舰与当前单船衔接、 | [查看](./cases/test_fleet.gd.md) |
| `cases/test_fog_system.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_full_clear.gd` | MVP 完整通关验收：脚本化玩家完成五段主线、中期升级、大型船组装并触发通关。 | [查看](./cases/test_full_clear.gd.md) |
| `cases/test_item_categories.gd` | Phase C C2（goods + materials → `items` 2.0）的运行时合并回归：类型表 / | [查看](./cases/test_item_categories.gd.md) |
| `cases/test_legacy_uv_assets.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_legacy_uv_assets_b.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_lod1_assets.gd` | LOD1 基础套件（M0-5）的资产守护用例：30 个 `SN_*_LOD1.glb`（kit 26 + 船 4） | [查看](./cases/test_lod1_assets.gd.md) |
| `cases/test_map_constraints.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_market_memory.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_market_trade.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_mod_loading.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_module_categories.gd` | C1 统一模块类型 `modules` 的 category 运行时测试：`ModuleOps` 的查询 / 槽位映射 / | [查看](./cases/test_module_categories.gd.md) |
| `cases/test_no_core_ids.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_patches.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_quest_service.gd` | C3 抽象任务（Quest）运行时测试：`data.quests` 惰性状态 + 存档 round-trip、 | [查看](./cases/test_quest_service.gd.md) |
| `cases/test_registry.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_rig_kit.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_rng.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_run_pipeline.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_save_load.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_save_migration.gd` | 存档 Schema 2.0 迁移与内容版本表（B5）测试：v1 payload 升级、v2 往返、 | [查看](./cases/test_save_migration.gd.md) |
| `cases/test_schema_v2_drafts.gd` | Content Schema 2.0 世界/战役/剧情 Schema 测试：SchemaValidator 合法 / 非法样本， | [查看](./cases/test_schema_v2_drafts.gd.md) |
| `cases/test_schema_v2_weapons.gd` | Content Schema 2.0 运行时武器类型（`weapons`，D1 起 active）与船体安装点镜像 | [查看](./cases/test_schema_v2_weapons.gd.md) |
| `cases/test_schema_validator.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_sdk_validation.gd` | SDK Schema 2.0 兼容回归：用真实子进程跑 `sdk/validate.gd` / `sdk/pack_mod.gd`， | [查看](./cases/test_sdk_validation.gd.md) |
| `cases/test_sea_chart.gd` | 海图系统的无头测试——阶段 2 验证 `sea_chart.view` 的输出结构与陆地/港口/ | [查看](./cases/test_sea_chart.gd.md) |
| `cases/test_semver_range.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_settings.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_ship_gun_ports.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_ship_modules.gd` | 模块实例层测试：实例创建/补齐、condition 夹取与失效、安装替换重置状态、货舱对齐、damage_module 操作码、维修报价与存档往返。 | [查看](./cases/test_ship_modules.gd.md) |
| `cases/test_ship_upgrade.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_ship_visual_assembler.gd` | 守护运行时整船装配层（`ShipVisualPlan` / `ShipVisualAssembler` / `ShipRigAssembly`）与 Core 内容契约：4 艘船的 hull/rig 计划解析、rig_kit 挂接与烘焙节点替换、武器 class 门禁、缺 socket / 缺套件 / 缺 hull 的回退，以及「同一计划重复装配得到相同节点树」的确定性。 | [查看](./cases/test_ship_visual_assembler.gd.md) |
| `cases/test_ship_weapon_assembly.gd` | 守护运行时武器装配层（`ShipWeaponAssembly` / `ShipWeaponMount`）与契约 v2 / M0-3 船体安装点：socket 发现与排序、武器 Root extras 读取、class 硬门禁、`SN_Mount` 精确对齐、`mount_scale`、机制节点与多联装、瞄准 / 后坐轴、净空软判定（socket 局部实测、非 envelope / base_footprint）以及 `clear_mounted`。 | [查看](./cases/test_ship_weapon_assembly.gd.md) |
| `cases/test_ship_weapon_sockets.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_shipyard_refit.gd` | 船厂界面重构契约测试（正常态 / 改装态）：三列布局、槽位与分类记忆、授权贴图与船卡缩略图、2.5D 渲染器替换钩子、拖拽安装，以及旧整页下方面板必须消失。 | [查看](./cases/test_shipyard_refit.gd.md) |
| `cases/test_simulation.gd` | Phase D0 确定性 tick / 模拟框架的回归测试：`data.sim` 惰性状态、暂停 / | [查看](./cases/test_simulation.gd.md) |
| `cases/test_stage_host.gd` | 2.5D 舞台契约测试（30 个同步用例）：LocationStage 默认契约、SNStageHost 生命周期/回退/停更、ShipyardStage 场景、SNShipStage3D 适配器、PortStage 装配/替换/缩放/portal、场景填充访问器、港口街坊 town kit 与 size/density 分档、静态与玩家船合批、无 banner 程序化远景、连续港区三站位的相邻/聚焦/航行/重建保持，以及查询接线。 | [查看](./cases/test_stage_host.gd.md) |
| `cases/test_story.gd` | 新手剧情 / 教学系统（阶段 4.5.1 – 4.5.5）领域层无头测试：`run.start tutorial=true` | [查看](./cases/test_story.gd.md) |
| `cases/test_story_ui.gd` | 阶段 4.5.1 新手剧情 UI 冒烟测试：教程局挂出剧情卡 / 目标条、导航与海图入口 | [查看](./cases/test_story_ui.gd.md) |
| `cases/test_supply.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_task_view.gd` | 任务追踪聚合查询（`task.view`，阶段 4.6 Phase A）测试：剧情目标 / 待接主线 / | [查看](./cases/test_task_view.gd.md) |
| `cases/test_ui_shell.gd` | 迭代 2 主界面接线测试：把真实外壳场景挂进场景树，断言六条反馈在界面构建路径上真的生效，并守护通报文案的本地化；另覆盖 Bounty Train 式主界面（默认 3D 舞台 + 紧凑顶部 HUD + 资源图标 + 主题化两侧招牌 + 底部状态条 + 详细总览抽屉 + 2D 回退）、连续港区三站位的页面接线（overview/market/supply 共用同一舞台实例、镜头与船移动、右侧泊位面板），以及 960 窄布局 helper。 | [查看](./cases/test_ui_shell.gd.md) |
| `cases/test_ui_views.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_victory.gd` | 迭代 1 通关测试：门槛、幂等颁奖、summary 完整性与安装触发。 | [查看](./cases/test_victory.gd.md) |
| `cases/test_voyage_flow.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_voyage_presentation.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `cases/test_warehouse_craft.gd` | 迭代 1 船只系统测试：仓库存取、transit 重量、材料打造、免费安装、替换/卸下、合同解锁与失败原子性。 | [查看](./cases/test_warehouse_craft.gd.md) |
| `cases/test_world_completeness.gd` | Phase B Core 完整性规则（WORLD_SCHEMA_V2_RUNTIME §5.2/§5.3）测试：用最小可运行的 | [查看](./cases/test_world_completeness.gd.md) |
| `cases/test_world_generator.gd` | 坐标空间世界生成器测试：同 seed 可复现、不同 seed 不同世界、10-20 港口、锚定海岸线、最小间距、陆地多边形、覆盖率、连通性、出航角度、起点港口、必需设施位置与序列化往返（12 个测试用例）。 | 本页 |
| `cases/test_world_schema_refs.gd` | Phase B 世界/战役 9 类 + Phase D1 战斗内容的跨引用校验测试：用真实 Core 基线 | [查看](./cases/test_world_schema_refs.gd.md) |
| `cases/test_zip_pack.gd` | 按主题拆分的 635 个测试用例（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。 | 本页 |
| `smoke_load.gd` | 手动冒烟：加载 Core 并打印启动报告。 | 本页 |
| `smoke_play.gd` | 手动冒烟：开局、预览、出航、事件选择。 | 本页 |
| `test_case.gd` | 测试断言与 Core bootstrap 辅助。 | 本页 |
| `test_runner.gd` | 无头测试入口：按 `SUITE_PATHS` 声明顺序加载测试套件、逐个执行 `test_*` 方法并打印 PASS/FAIL，退出码由失败数决定（0 = 全绿）。 | [查看](./test_runner.gd.md) |

## 模块契约

- 测试入口：`godot --headless --path . --script res://framework/tests/test_runner.gd`。
- `test_case.gd` 提供断言与 Core 启动辅助；每个用例独立 bootstrap。
- 测试源码可以引用 `core:*` ID；`test_no_core_ids.gd` 只扫描非测试框架代码。
- `test_full_clear.gd` 通过公开命令/查询脚本化跑完五段主线并组装大型船，覆盖 9 个 seed。
- `test_content_types_manifest.gd` 守护 `content_types.json` 与 `ContentTypes` / Schema 文件的一致性。
- `test_save_migration.gd` 守护 save schema 1.x → 2.0 迁移、campaign 元数据/分区回填与 B5 `content_versions` 快照/推断/漂移。
- `test_campaign_state.gd` 守护 CampaignState 分区补齐、探索进度幂等与存档往返。
- `test_ship_modules.gd` 守护模块实例补齐/condition 失效/安装重置/货舱对齐/damage_module 操作码/维修报价与存档往返。
- `test_stage_host.gd` 守护 LocationStage 契约、SNStageHost 生命周期/回退/停更、ShipyardStage 场景、SNShipStage3D 适配器与 PortStage 装配/替换/缩放/portal。
- `test_schema_v2_drafts.gd` 用当前 SchemaValidator 验证 `schemas/v2` 的 Phase B 世界/战役 Schema、D1 `weapons` / D2 fleet 类型与 `map_configs`（31 键 exploration），确认 9 类 + D1/D2 active、只剩 3 类草案（剧情 2 类 + 战斗 AI 1 类）。
- `test_simulation.gd` 守护 D0：`data.sim` 惰性状态、`sim.pause|resume|set_speed|advance` 与 `sim.view`、tick 系统 priority/id 顺序、`sim.tick` 事件、同种子 hash 确定性与旧档补齐。
- `test_combat.gd` 守护 D1：`CombatOps` 纯规则（护甲/穿甲/状态/撤退/战利品）、`CombatService` 落盘与 `data.combat` 惰性记录、`combat.resolve|view|log`、同 seed 确定性与 core 内容冒烟。
- `test_fleet.gd` 守护 D2：`data.fleet` 惰性结构、旗舰与当前单船衔接、`fleet.view` 形状、captain 指派/可指挥船型/唯一性、formation slot 校验、doctrine 选择、增删舰与容量、`fleet.*` 事件、存档 round-trip 与旧档补齐。
- `test_world_schema_refs.gd` 覆盖 Phase B 9 类引用规则：硬引用缺失 error、planned 目标仅 `ref_inactive_type` warning、faction 自指、map_config archetype 数量组合规则。
- `test_world_completeness.gd` 覆盖 Core Phase B 完整性：presence gate（仅 Core 自带 world_profiles 时启用）、五项硬性数量、四项建议 warning 与 start_profile / region / map_config 组合规则。
- `test_campaign_assembly.gd` 用合成 v2 定义验证 `CampaignFactory` 世界装配：state 形状、同 seed 确定性、区域/地点/航路引用一致性、map_config 回退与结构化错误。
- `test_campaign_start.gd` 覆盖默认 / 显式 `start_profile` 都走 `CampaignFactory`、`starting_scenarios` / `map_configs` 是唯一内容来源、`map_profiles` 退役且 `ContentRefs` 不再回退、`campaign.view` 形状与存档 header 不变。
- `test_schema_v2_weapons.gd` 守护 D1 `weapons`（合法 direct / broadside 与非法必填 / 枚举 / 范围 / 颜色 / 材料 ID）、active 登记与 hull `weapon_sockets` / `rig_sockets` 镜像（含 Core 14 个武器 socket + 22 个帆索 socket）。
- `test_world_generator.gd` 守护坐标空间世界生成：同 seed 可复现、港口锚定海岸线、最小间距、连通性、出航角度、必需设施位置与序列化往返。
