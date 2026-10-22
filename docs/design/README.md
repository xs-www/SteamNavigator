# Active — 正在讨论或持续修改

> 进行中的方案、草案与长期维护的参考文档；结论确定后按生命周期迁出（定稿 → [docs/specs/](../specs/)，废弃 → [docs/archive/](../archive/)）。
> 目录索引：[docs/README.md](../README.md)

- [PROJECT_STATUS.md](PROJECT_STATUS.md) — 当前实现状态与最近交付的详细清单（从 README 拆出，按需读取）
- [CORE_CONTENT.md](CORE_CONTENT.md) — MVP Core 内容与数值概览（真源仍是 `dev_mods/core/content/`）
- [KNOWN_LIMITS.md](KNOWN_LIMITS.md) — 已知边界与暂缓项（判断需求是否已实现前先读）
- [LUA_MODDING_SDK.md](LUA_MODDING_SDK.md) — Lua 可执行模组 SDK 架构与实施规范（Draft 0.1；沙箱 / 权限 / API / 确定性 / 发布门禁；尚未实现）
- [2.5D_STAGE_PLAN.md](2.5D_STAGE_PLAN.md) — 2.5D 固定舞台升级方案（阶段 1 持续落地中）
- [NAUTICAL_CHART_SYSTEM.md](NAUTICAL_CHART_SYSTEM.md) — 正式版航海图系统设计；阶段 1–3 已实现，后续阶段仍在本文件迭代
- [EXPLORATION_SYSTEM.md](EXPLORATION_SYSTEM.md) — 海图阶段 4 探索系统实现契约（4.1/4.2 已实现；4.3 体验修正的 8 条反馈、决策与分片计划见 §10，待实现）
- [STORY_TUTORIAL.md](STORY_TUTORIAL.md) — 阶段 4.5 新手剧情 / 教学系统实现契约（全部 Implemented；Phase A 任务追踪见 TASK_QUEST_SYSTEM.md）
- [STORY_MODE.md](STORY_MODE.md) — 剧情模式设计草案（Draft 5：只加剧情的模组数据包（多关）+ 内嵌固定地图 + 任务线 + 四类能力 + 仓库根目录 SNStoryMaker 编辑器；S1 数据契约已交付，S2 起做加载链）
- [TASK_QUEST_SYSTEM.md](TASK_QUEST_SYSTEM.md) — 任务追踪与任务系统设计（Phase A `task.view` 已实现；Phase B Quest 2.0 + `data.quests` + QuestService 已实现）
- [ASSET_MAP.md](ASSET_MAP.md) — 美术 / 音频资产映射与来源（随批次持续更新）
- [MODELING_BACKLOG.md](MODELING_BACKLOG.md) — 3D 建模需求 backlog（P0/P1/P2、建议批次、统一验收口径）
- [KIT_ASSET_LIBRARY.md](KIT_ASSET_LIBRARY.md) — 模型素材库 26 件资产目录、接口契约与装配配方（批次 1–3）
- [WEAPON_SOCKET_CONTRACT.md](WEAPON_SOCKET_CONTRACT.md) — 武器装配规范 v2（安装点 / Yaw / Pitch / Recoil / Muzzle）
- [WEAPON_CONTENT_SCHEMA.md](WEAPON_CONTENT_SCHEMA.md) — 武器内容 Schema 2.0 草案（战斗 / 装配 / 经济字段、船体 socket 镜像与编辑器支持；运行时不加载）
- [RIG_KIT_CONTRACT.md](RIG_KIT_CONTRACT.md) — 船体帆索部件库 rig_kit（12 件 SN_Rig_* + 22 个 SN_Socket_Mast/Yard/Sail_*，M0-4）
- [DEV_PLAN_2026-10.md](DEV_PLAN_2026-10.md) — 近期开发计划、优先级与验收标准
- [FULL_GAME_ROADMAP.md](FULL_GAME_ROADMAP.md) — 正式版路线图（草案，随里程碑更新）
- [ENTITY_CONTRACT_V2.md](ENTITY_CONTRACT_V2.md) — 实体契约 v2（Draft 1，Schema 2.0 目标）
- [CONTENT_SCHEMA_V2_MIGRATION.md](CONTENT_SCHEMA_V2_MIGRATION.md) — Content Schema 2.0 迁移落地方案（按类型版本 + 纵向切片，Draft 1）
- [WORLD_SCHEMA_V2_RUNTIME.md](WORLD_SCHEMA_V2_RUNTIME.md) — 世界与战役内容 Schema 2.0 运行时实现契约（Phase B，Draft 2；B0–B6 已完成）
- [MODELING_WORKFLOW.md](MODELING_WORKFLOW.md) — 建模半工作流与工单 / 验收流程
- [UI_PROTOTYPE.md](UI_PROTOTYPE.md) — `.design` 美术与交互原型说明
- [UI_VISUAL_BASELINE.md](UI_VISUAL_BASELINE.md) — SN Visual Baseline V1 与非约束性的 UI Kit Concept V1
- [UI_FOUNDATION_SPEC_V1.md](UI_FOUNDATION_SPEC_V1.md) — 四类材质、基础尺寸、九宫格、安全区、字体、颜色、状态与动效生产前置规范
