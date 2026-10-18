# Steam Navigator — 静态代码文档

> 面向阅读者与 AI 的代码索引：先看模块，再看文件，最后按需查看重点函数。

## 项目入口

- 启动：[project.godot](project.godot.md)、[Bootstrap](framework/bootstrap/bootstrap.gd.md)、[AppBootstrap](framework/bootstrap/app_bootstrap.gd.md)
- 内容管线：[ModLoader](framework/modding/mod_loader.gd.md)、[ContentCompiler](framework/modding/content_compiler.gd.md)、[SchemaValidator](framework/modding/schema_validator.gd.md)
- 运行时：[AppContext](framework/bootstrap/app_context.gd.md)、[GameState](framework/state/game_state.gd.md)
- 主界面：[main.gd](framework/ui/shell/main.gd.md)
- 官方内容：[Core 内容包](dev_mods/core/README.md)
- SDK：[打包/校验/模板](sdk/README.md)

## 模块索引

| 模块 | 内容 |
| --- | --- |
| [`framework/bootstrap`](framework/bootstrap/README.md) | 启动与组合根。负责在场景加载前完成内容加载，并向 UI/用例暴露 AppContext。 |
| [`framework/core`](framework/core/README.md) | 与引擎无关的小型基础设施：JSON、路径、SemVer、版本范围、稳定哈希、版本常量。 |
| [`framework/modding`](framework/modding/README.md) | 内容管线：扫描、Manifest、依赖、Schema、注册表、Patch、交叉校验与 Core 完整性。 |
| [`framework/application`](framework/application/README.md) | 应用层：命令/查询总线、公共 API 注册、领域事件与用例。 |
| [`framework/domain`](framework/domain/README.md) | 纯领域逻辑：航行、市场、委托、船只、地图、事件与债务。 |
| [`framework/services`](framework/services/README.md) | 基础设施服务：日志、RNG、时钟、本地化、资源、存档。 |
| [`framework/state`](framework/state/README.md) | 运行态数据模型。GameState 是唯一持久化状态，定义对象永不进入存档。 |
| [`framework/ui`](framework/ui/README.md) | 展示层。当前只有一个最小可玩外壳，后续可拆分为海图/面板/出航等场景。 |
| [`framework/tests`](framework/tests/README.md) | 无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、存档、ZIP 与框架约束。 |
| [`sdk`](sdk/README.md) | 模组开发工具：打包、校验、模板与示例。 |
| [`schemas`](schemas/README.md) | Manifest 与内容文件的 JSON Schema（项目校验器支持的子集）。 |
| [`dev_mods/core`](dev_mods/core/README.md) | 官方 MVP 内容包：港口、商品、船只、模块、策略、岗位、委托、事件、地图与本地化。 |
| [`tools`](tools/README.md) | PowerShell 辅助脚本与静态文档生成器。 |

## 主要数据流

```text
启动：AppBootstrap → Bootstrap → ModScanner → DependencyResolver
      → ContentCompiler（Schema/注册/Patch）→ CrossReferenceValidator
      → CoreCompletenessChecker → RegistryHub.freeze → FrameworkApi

新局：CommandBus(run.start) → RunFactory → MapGenerator + MarketOps + NPC
      → ContractOps(主线 1) → GameState 提交 → autosave

航行：voyage.preview → VoyageCalculator → voyage.start → VoyageService
      → 风险事件/EffectExecutor → _complete_arrival → ContractOps + NPC + Debt

UI：QueryBus → ViewModel → CommandBus → 事务克隆提交 → DomainEventBus
```

## 架构不变量

- 框架不硬编码具体 `core:*` ID；官方内容通过普通模组注册表进入。
- 注册表加载完成后冻结；运行态数值只在 `GameState`。
- 命令在状态深拷贝上执行，成功才提交；查询使用临时克隆。
- 所有随机来自命名流；同 seed + 模组清单 + 命令序列结果一致。
- 存档头记录模组版本；缺失关键模组的存档拒绝加载。

## 生成信息

- 生成时间：2026-10-18T11:35:10.734Z
- 生成 commit：`b4ab302`
- 模式：`compact`；规则版本：`2.0`
- 更新方式：修改代码后同步维护 `tools/static_docs_data.mjs`，运行 `node tools/gen_static_docs.mjs`。
- 增量依据：[manifest.json](manifest.json) 记录每个源文件的 SHA-256、文档位置与分组。
