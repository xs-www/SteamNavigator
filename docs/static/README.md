# Steam Navigator — 静态代码文档

> 面向阅读者与 AI 的代码索引：先看模块，再看文件，最后按需查看重点函数。

## 项目入口

- 启动：[project.godot](project.godot.md)、[Bootstrap](framework/bootstrap/bootstrap.gd.md)、[AppBootstrap](framework/bootstrap/app_bootstrap.gd.md)
- 内容契约：[content_types.json](content_types.json.md)、[Entity Contract v2](../design/ENTITY_CONTRACT_V2.md)
- 内容管线：[ModLoader](framework/modding/mod_loader.gd.md)、[ContentCompiler](framework/modding/content_compiler.gd.md)、[SchemaValidator](framework/modding/schema_validator.gd.md)
- 运行时：[AppContext](framework/bootstrap/app_context.gd.md)、[GameState](framework/state/game_state.gd.md)
- 主界面：[main.gd](framework/ui/shell/main.gd.md)
- 3D 港口样片：[dev_scenes](dev_scenes/README.md)
- 官方内容：[Core 内容包](dev_mods/core/README.md)
- 迭代 1 契约：[MVP 闭环](../specs/ITERATION_1_MVP_LOOP.md)
- SDK：[打包/校验/模板](sdk/README.md)
- 释放与导出：[export_presets.cfg](export_presets.cfg.md)、[release.yml](.github/workflows/release.yml.md)
- 模组制作器：[SNModMaker](SNModMaker/README.md)
- 战斗规则试验台：[SNBattleSim](SNBattleSim/README.md)
- 内容 CLI：[content.mjs](SNModMaker/tools/content.mjs.md)（agent 无头增删改内容）
- 容器部署：[docker-compose.yml](docker-compose.yml.md)、[Dockerfile](SNModMaker/Dockerfile.md)（数据在容器卷，配合 tailscale serve）
- 本地美术原型：[`.design` 美术与交互原型](design-prototype.md)

## 模块索引

| 模块 | 内容 |
| --- | --- |
| [`framework/bootstrap`](framework/bootstrap/README.md) | 启动与组合根。负责在场景加载前完成内容加载，并向 UI/用例暴露 AppContext。 |
| [`framework/core`](framework/core/README.md) | 与引擎无关的小型基础设施：JSON、路径、SemVer、版本范围、稳定哈希、版本常量。 |
| [`framework/modding`](framework/modding/README.md) | 内容管线：扫描、Manifest、依赖、Schema、注册表、Patch、交叉校验与 Core 完整性。 |
| [`framework/application`](framework/application/README.md) | 应用层：命令/查询总线、公共 API 注册、领域事件与用例（交易、委托、出航、船厂/仓库/打造订单、在港等待、通关）。 |
| [`framework/domain`](framework/domain/README.md) | 纯领域逻辑：航行、市场、委托、船只/模块实例/仓库/打造订单、地图、世界生成（坐标空间+程序化陆地+贝塞尔航线）、事件、债务与通关判定。 |
| [`framework/services`](framework/services/README.md) | 基础设施服务：日志、RNG、时钟、本地化、资源、存档。 |
| [`framework/state`](framework/state/README.md) | 运行态数据模型。GameState 是唯一持久化状态，定义对象永不进入存档；含 campaign 分区（world/codex/factions）、探索进度、收入/支出/利润统计的惰性补齐。 |
| [`framework/ui`](framework/ui/README.md) | 展示层。固定 Shell、四个菜单场景、七个功能页、五个流程页与海图组件均已场景化；Shell 仅保留上下文解析、ViewModel 组合、导航、命令和转场。共享 Godot Theme、可复用控件与 UI Kit 展示场景保持统一视觉。船厂中央改装台（SNShipView）与部件 HUD（SNSlotTarget/SNPartRow）是独立可复用组件，2.5D 渲染器经 set_renderer 接入。2.5D 固定舞台位于 `framework/ui/stages/`：`SNStageHost` 持有 SubViewport 与生命周期，`LocationStage` 是舞台契约，`ShipyardStage` 承载船厂 3D 船体，`PortStage` 是港口舞台骨架，`StageKit` 提供环境/水面/AABB 取景构建器；总览页已把 `PortStage` 作为全窗背景层接入，并生成 2D 设施热点（点击与顶部导航同一路径）。 |
| [`framework/tests`](framework/tests/README.md) | 无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、委托刷新、仓库存取、打造订单/替换/在港等待、船厂改装 UI、UI 外壳接线、2.5D 舞台基础设施、总览页 3D 港口舞台接入、完整通关流程与坐标空间世界生成器。 |
| [`sdk`](sdk/README.md) | 模组开发工具：打包、校验、模板与示例。 |
| [`schemas`](schemas/README.md) | Manifest 与内容文件的 JSON Schema（项目校验器支持的子集）；`schemas/v2/` 存放 Content Schema 2.0 草案。 |
| [`dev_mods/core`](dev_mods/core/README.md) | 官方 MVP 内容包：港口、商品、船只、模块、策略、岗位、委托、事件、地图与本地化；模块含打造配方/工时/费用，tier1 为仅金币配方（materials 为空）。 |
| [`dev_scenes`](dev_scenes/README.md) | 独立 3D 样片与舞台预览场景（不接入主流程）：港口水面/浮船样片与 PortStage 港口舞台预览，用于验证水面着色器、GLB 资产拼接与固定机位构图。 |
| [`tools`](tools/README.md) | PowerShell 辅助脚本、Godot 验收 / 截图脚本、建模工单 / 参数化生成器与静态文档生成器。 |
| [`SNBattleSim`](SNBattleSim/README.md) | 独立 2D 舰队战斗规则试验台：验证固定船体、多武器、视野/战争迷雾、直射/炮击/侧弦齐射、货船护航与用户自定义武器。 |
| [`SNModMaker`](SNModMaker/README.md) | 零依赖网页端模组制作器：原生 HTML/CSS/JS，从仓库 Schema 与 Core 索引生成表单、校验并打包模组。 |

## 主要数据流

```text
启动：AppBootstrap → Bootstrap → ModScanner → DependencyResolver
      → ContentCompiler（Schema/注册/Patch）→ CrossReferenceValidator
      → CoreCompletenessChecker → RegistryHub.freeze → FrameworkApi

新局：CommandBus(run.start) → RunFactory → MapGenerator + MarketOps + NPC
      → ContractOps(主线 1) → GameState 提交 → autosave

航行：voyage.preview → VoyageCalculator → voyage.start → VoyageService
      → 风险事件/EffectExecutor → _complete_arrival → ContractOps + NPC + Debt
      → 普通委托池刷新（ContractOps.refresh_normal_offers）

建造：ship.install_module(source=purchase|warehouse|transit) / ship.craft_module
      → ShipOps/CraftOps/WarehouseOps（旧件入当前港仓库、transit 计重不占货舱）
      → VictoryService.check（主线完成 + 大型船体/锅炉/货舱 → 通关）

UI：QueryBus → ViewModel → CommandBus → 事务克隆提交 → DomainEventBus
```

## 架构不变量

- 框架不硬编码具体 `core:*` ID；官方内容通过普通模组注册表进入。
- 注册表加载完成后冻结；运行态数值只在 `GameState`。
- 命令在状态深拷贝上执行，成功才提交；查询使用临时克隆。
- 所有随机来自命名流；同 seed + 模组清单 + 命令序列结果一致。
- 港口仓库/随船运输/通关标记只存在于 GameState；注册表冻结后仍可自由存取。
- 存档头记录模组版本；缺失关键模组的存档拒绝加载。

## 生成信息

- 生成时间：2026-10-21T00:55:27.789Z
- 生成 commit：`eec3fe7`
- 模式：`compact`；规则版本：`3.0`
- 更新方式：在源码头部维护 `@static-doc` 注释，运行 `node tools/gen_static_docs.mjs`；无注释格式使用 `docs/static_headers/<源码路径>.md` sidecar。
- 检查方式：`node tools/gen_static_docs.mjs --check`；旧的 `tools/static_docs_data.mjs` 仅作为尚未迁移文件的兼容层。
- 变更依据：[manifest.json](manifest.json) 记录每个源文件的 SHA-256、文档位置与分组。
