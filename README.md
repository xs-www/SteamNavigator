# Steam Navigator（蒸汽航海）MVP — Framework + Core Mod

《蒸汽航海》是一款**蒸汽朋克**背景的航海贸易模拟游戏。本仓库是 MVP 的 Godot 4.x 原型：游戏本体只提供通用框架；官方内容（港口、商品、船体、模块、委托、事件等）通过 **`core` 内容模组**加载，走与第三方模组完全相同的发现、校验、注册和冻结流程。

**README 只保留入门信息。** 详细进度、内容基线、已知边界与设计契约已拆到独立文档，请按需要读取，不要通读全部文档。

## 从这里开始（按需读取）

| 你想做什么 | 先读 |
| --- | --- |
| 跑起来 / 跑测试 / 打包 | 本文件的「快速开始」「打包 Core 模组」 |
| 了解当前做到哪、最近交付了什么 | [docs/design/PROJECT_STATUS.md](docs/design/PROJECT_STATUS.md)、[todo.md](todo.md) |
| 了解版本变更 | [CHANGELOG.md](CHANGELOG.md) |
| 改代码前定位文件 / 契约 | [docs/static/README.md](docs/static/README.md)（静态代码文档） |
| 改内容、类型或 Schema | [content_types.json](content_types.json)、[ENTITY_CONTRACT_V2.md](docs/design/ENTITY_CONTRACT_V2.md)、[CONTENT_SCHEMA_V2_MIGRATION.md](docs/design/CONTENT_SCHEMA_V2_MIGRATION.md) |
| 改世界/战役运行时 | [WORLD_SCHEMA_V2_RUNTIME.md](docs/design/WORLD_SCHEMA_V2_RUNTIME.md)、[FULL_GAME_ROADMAP.md](docs/design/FULL_GAME_ROADMAP.md) |
| 改剧情 / 任务 | [STORY_TUTORIAL.md](docs/design/STORY_TUTORIAL.md)、[TASK_QUEST_SYSTEM.md](docs/design/TASK_QUEST_SYSTEM.md)、[STORY_MODE.md](docs/design/STORY_MODE.md) |
| 改 UI / 2.5D 舞台 | [UI_PROTOTYPE.md](docs/design/UI_PROTOTYPE.md)、[2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md)、[SHIP_VISUAL_ASSEMBLY.md](docs/design/SHIP_VISUAL_ASSEMBLY.md) |
| 做模组 / 校验 / 打包 | [SNModMaker/README.md](SNModMaker/README.md)、[sdk/README.md](sdk/README.md)、[dev_mods/core/content/](dev_mods/core/content/) |
| 看实现边界（别把限制当 bug） | [KNOWN_LIMITS.md](docs/design/KNOWN_LIMITS.md) |
| 看 Core 内容与数值基线 | [CORE_CONTENT.md](docs/design/CORE_CONTENT.md) |
| 找 GDD / 架构 / 迭代契约 | [docs/README.md](docs/README.md)、[docs/specs/README.md](docs/specs/README.md)、[docs/design/README.md](docs/design/README.md) |

## 当前状态摘要

- **可玩闭环**：程序生成海图、市场/补给、委托、船厂购买/打造/仓库/改装、出航与风险事件、探索线索、通关总结、主菜单与设置持久化。
- **2.5D 固定舞台**：港口全窗 3D 舞台、连续港区三站位、船厂 3D 实机舞台、航行离港/入港演出、静态合批与低配回退。
- **Content Schema 2.0 Phase C 进行中**：C1（5 类模块 → `modules` 2.0 + `hulls` 2.0）、C2（goods + materials → `items` 2.0）与 C3（`quests` 2.0 + 持久 `data.quests` + QuestService，委托/任务解耦）已完成；当前 active 21 类（7×1.0 + 13×2.0 + 显式补丁），3 类草案（`weapons` / `story_arcs` / `story_levels`）仅供编辑器与 draft 校验。
- **剧情 / 任务**：新手教学 4.5 与任务追踪 `task.view` 已落地；C3 起 `quests` 2.0 + 持久 `data.quests` + `QuestService` 已接入（委托接取生成追踪实例，剧情演出/游戏指引等抽象引导由 Quest 承载），剧情模式 S1 数据契约（`story_arcs` / `story_levels` 草案）已就绪。
- **无头测试**：`pwsh ./tools/test.ps1` 跑 Godot 全量；Node/CLI/SDK 门禁命令见下方。

## 环境要求

- Godot **4.4+**（本仓库在 **4.7.2 stable** 上验证）。
- 无需 C# / .NET；纯 GDScript。
- 无头测试与 SDK 工具不依赖编辑器 UI。

## 快速开始

1. 用 Godot 打开仓库根目录（包含 `project.godot`）。
2. 按 **F5** 运行。主场景为 `framework/ui/shell/main.tscn`。
3. 选择初始构筑和可选种子，开始新航程。

开发模式下，Core 从 `res://dev_mods/core/` 松散目录加载；同时扫描 `res://dist/mods`。发布模式不扫描 `res://dev_mods`，只扫描可执行文件旁的 `mods/` 与 `user://mods/`。

### 运行测试

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
pwsh ./tools/test.ps1

# 等价命令
godot --headless --path . --script res://framework/tests/test_runner.gd
```

### 打包 Core 模组

```powershell
pwsh ./tools/pack_core.ps1
# 或
godot --headless --path . --script res://sdk/pack_mod.gd -- --source=dev_mods/core --out=dist/mods

# 正式发布：先做 Runtime 校验，草案/错误会拒绝打包
godot --headless --path . --script res://sdk/pack_mod.gd -- --source=dev_mods/core --out=dist/mods --release
```

产物：`dist/mods/core-1.0.0.snavmod.zip`（包内路径 `mods/core/...`）。

### 开发版发布

推送 `v*` tag 会触发 [.github/workflows/release.yml](.github/workflows/release.yml)：跑测试、导出 Windows/Linux、Runtime 校验、打包 Core、生成 SHA256，并创建 GitHub Release。带 `-dev.` 的 tag 自动标记为预发布。

### 校验第三方模组

```powershell
# 默认 runtime：按内容类型独立版本加载，未激活的草案会被拒绝
godot --headless --path . --script res://sdk/validate.gd -- --mod-root=sdk/examples/example_boilers

# draft：静态 Schema 校验草案/混合模组（不能用于发布）
godot --headless --path . --script res://sdk/validate.gd -- --mod-root=sdk/templates/draft_weapons_pack --mode=draft
```

示例：`sdk/examples/example_roles_1_0`（1.0）、`example_mixed_roles_items`（1.0 + 已激活 2.0）、`sdk/templates/draft_weapons_pack`（草案，仅 draft）。模式、结构化错误与发布门禁说明见 [sdk/README.md](sdk/README.md)。

## 架构概览

```text
Presentation  framework/ui
      ↓ Query / Command
Application   framework/application（总线、用例、命令、查询）
      ↓
Domain        framework/domain（航行、市场、委托、船只、地图、事件、债务）
      ↓
Content API   framework/modding（定义、注册表、Schema、Patch）
      ↓
Mod Runtime   framework/modding（扫描、依赖、挂载、编译）
      ↓
Infrastructure framework/services（文件、存档、日志、RNG、本地化、资源）
```

启动链路（见 `framework/bootstrap/bootstrap.gd` 与 `framework/modding/mod_loader.gd`）：

```text
AppBootstrap._ready
  → Bootstrap.run
    → AppContext（服务/总线）
    → ModScanner.scan
    → DependencyResolver
    → mount resource packs
    → ContentCompiler（JSON → Schema → 注册 → Patch）
    → CrossReferenceValidator + CoreCompletenessChecker
    → RegistryHub.freeze_all
    → FrameworkApi.register
    → 主场景
```

Core 加载失败时仍可进入诊断界面，但不会开始游戏。

### 关键不变量

- **官方内容也是模组**：`framework/` 中不存在具体 `core:*` 内容 ID（有测试守护）。
- **注册表冻结后不可变**：运行态数量、库存、耐久只存在于 `GameState`。
- **命令事务 / 只读查询**：CommandBus 在深拷贝上执行成功后提交；QueryBus 给查询临时克隆。
- **命名随机流**：随机按（基础种子、流名、上下文键）派生，新增视觉随机不影响经济。
- **存档确定性**：数字量化到 1e-9，保存/加载前后状态哈希一致。
- **模组安全**：内容模组只能提交 JSON / 图片 / 音频 / 单文件 GLB；拒绝脚本、动态库、场景、路径穿越与 `res://framework/**` 覆盖。

## 目录结构

```text
project.godot                  Godot 项目入口
content_types.json             内容类型单一真源（框架 / 编辑器 / Schema / SDK 契约）
framework/                     启动、模组、应用/领域、服务、状态、UI、测试、本地化
schemas/                       Manifest 与各类内容的 JSON Schema
dev_mods/core/                 官方内容模组（内容 JSON、本地化、资产副本）
sdk/                           打包、校验、模板与 1.0/混合/草案示例
SNModMaker/                    零依赖网页端模组制作器
assets/                        框架 UI 资产；内容模型随 core 模组发布
docs/                          设计/契约文档；docs/static/ 为生成代码索引
tools/                         测试、打包、截图与建模生成器
dist/mods/                     本地 .snavmod.zip 与 core 构建产物
```

## 内容与模组

- 内容数值真源：`dev_mods/core/content/*.json`；改数值先改 JSON，不在框架写死。
- 模组最小结构：

```text
<mod_id>/
├── manifest.json
├── content/*.json
├── localization/zh_CN.json
└── assets/...
```

- 定义 ID 必须为 `<mod_id>:<type>/<local_id>`；修改其他模组定义必须用显式 `patches`。
- 可视化制作：`node SNModMaker/tools/serve.mjs` → `http://127.0.0.1:8099/`；详见 [SNModMaker/README.md](SNModMaker/README.md)。
- 模板与示例见 `sdk/templates/`、`sdk/examples/`；CLI/SDK 契约见 [sdk/README.md](sdk/README.md)。

## 本地化

- 框架 UI：`framework/localization/{zh_CN,en}.json`。
- Core 内容：`dev_mods/core/localization/{zh_CN,en}.json`。
- 默认 `zh_CN`，缺失键回退 `en`，再回退键名本身。

## 文档与协作

- 静态代码文档按“文件镜像 + 模块索引”组织：`docs/static/README.md`；源码用 `@static-doc`，sidecar 约定见 `docs/static_headers/README.md`。
- 改代码后运行 `node tools/gen_static_docs.mjs`，提交前用 `node tools/gen_static_docs.mjs --check`。
- 设计与规范：`docs/README.md`（生命周期）、`docs/specs/`（契约）、`docs/design/`（进行中设计）、`docs/archive/`（历史归档）。
- 设计问题优先回到 GDD / 架构契约确认，不用“通过测试”替代需求判断。
