# Steam Navigator（蒸汽航海）MVP — Framework + Core Mod

《蒸汽航海》MVP 的 Godot 4.x 原型仓库。游戏本体只提供通用框架；官方内容（港口、商品、船体、锅炉、委托、事件等）通过 **`core` 内容模组**加载，走与第三方模组完全相同的发现、校验、注册和冻结流程。

- 设计文档：[MVP GDD v1.0](docs/蒸汽航海_MVP_GDD_V1.0.md)
- 架构文档：[框架 + 模组 v1.0](docs/蒸汽航海_项目架构方案_框架与模组_V1.0.md)
- 静态代码文档：[docs/static/README.md](docs/static/README.md)
- 美术/音频资产映射：[docs/design/ASSET_MAP.md](docs/design/ASSET_MAP.md)
- 物品建模半工作流（派发给子代理）：[docs/design/MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)
- UI 原型与落地说明：[docs/design/UI_PROTOTYPE.md](docs/design/UI_PROTOTYPE.md)
- 高频决策页面重构指南：[docs/design/HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md](docs/design/HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md)
- 任务与路线图：[todo.md](todo.md)

## 当前状态

基础框架与首个可玩纵切片已跑通：

- 模组扫描（目录 / ZIP）、Manifest 校验、SemVer 依赖解析、冲突与循环检测、注册表冻结。
- JSON Schema 子集校验（含本地 `$ref`）、跨引用校验、Core 完整性检查、显式 Patch。
- 命名随机流、确定性开局、市场 NPC 模拟、情报快照、借贷、声望、自动存档。
- 命令 / 查询总线（事务克隆提交、领域事件、只读 ViewModel）。
- 可玩的程序生成海图：点击已访问港口查看上次在港货价/储备、贸易、补给、维修、造船厂模块安装、委托接取、出航预览、风险事件、抵达结算。
- 市场规则：任意港口都收购所有普通货物；只有本港商品表列出的品种可以直接买入。库存按加权平均成本记录并显示；玩家单笔交易只把价格推向新均衡的 35%，避免过度敏感。
- 煤炭与淡水作为补给商品进入港口市场，价格随港口库存和 NPC 商船流动浮动；在补给页按当前市场价买入。
- 5 段主线委托链（自动接第 1 段，后续以 offer 形式接取）、4 个普通委托模板。
- 启动主菜单：开始游戏 / 加载游戏 / 模组 / 设置 / 退出游戏；右下角显示开发团队与版本。
- 设置持久化：语言与自动存档写入 `user://config/config.json`；仓库内的 `config/config.json` 是默认配置。
- 最小 UI：开局构筑选择，以及总览、市场、委托、船厂、补给、情报、出航七个独立界面；共享蒸汽朋克 Theme、全屏主菜单背景、铁港横幅、两列委托卡、顶部导航、页面淡入淡出与抵达结算页。
- 交易反馈：买入/卖出、接取委托、购买补给成功后播放金币音效；右下角固定开发团队与版本。
- 高频决策页第一轮：补给卡（存量/可补上限/续航/补满花费）、委托固定五区卡片与可接/进行中分区、市场真实价格历史与迷你折线。
- 海图重设计：三次贝塞尔曲线航路、经纬网、洋流、罗盘、图内图例、当前港脉冲光晕与更宽的图表布局。
- 无头测试套件：**49 个测试全部通过**（含 ZIP 打包加载、30 个种子的地图硬约束、保存哈希一致性、显式 Patch 冲突、港口记忆、补给与库存成本）。
- SDK：模组打包、无头校验、模组模板与一个第三方锅炉示例。
- [SNModMaker](SNModMaker/README.md)：零依赖网页端模组制作器，可视化编辑、校验并打包 `.snavmod.zip`。

尚未完成、但已留出扩展位置的内容见 [todo.md](todo.md)。

## 环境要求

- Godot **4.4+**（本仓库在 **4.7.2 stable** 上验证）。
- 无需 C# / .NET；纯 GDScript。
- 无头测试与 SDK 工具不依赖编辑器 UI。

## 快速开始

1. 用 Godot 打开仓库根目录（包含 `project.godot`）。
2. 按 **F5** 运行。主场景为 `framework/ui/shell/main.tscn`。
3. 选择初始构筑（低耗稳健型 / 高速冒险型）和可选种子，开始新航程。

开发模式下，Core 从 `res://dev_mods/core/` 松散目录加载；同时扫描 `res://dist/mods`，方便直接放入第三方 `.snavmod.zip`。同 ID 时松散目录优先，`dist/mods` 里的 core 构建产物会被自动忽略。发布模式扫描可执行文件旁的 `mods/` 与 `user://mods/`。

### 运行测试

```powershell
# 设置 Godot 可执行文件路径，或把 godot 加入 PATH
$env:GODOT_BIN = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
pwsh ./tools/test.ps1

# 等价命令
godot --headless --path . --script res://framework/tests/test_runner.gd
```

测试输出形如：

```text
[PASS] test_mod_loading::test_core_loads_cleanly
...
Tests: 49 passed, 0 failed, 49 total
```

### 打包 Core 模组

```powershell
pwsh ./tools/pack_core.ps1
# 或
godot --headless --path . --script res://sdk/pack_mod.gd -- --source=dev_mods/core --out=dist/mods
```

产物：`dist/mods/core-1.0.0.snavmod.zip`（包内路径为 `mods/core/...`）。

### 开发版发布

推送 `v*` tag 会触发 `.github/workflows/release.yml`：跑测试、导出 Windows/Linux、打包 Core、生成 SHA256，并创建 GitHub Release。带 `-dev.` 的 tag 自动标记为预发布。

```powershell
git tag -a v0.1.0-dev.1 -m "Steam Navigator v0.1.0-dev.1"
git push origin v0.1.0-dev.1
```

发布资产：`SteamNavigator-<tag>-windows.zip`、`SteamNavigator-<tag>-linux.zip`、`core-1.0.0.snavmod.zip`、`SHA256SUMS.txt`。

本地导出需要安装 Godot 4.7.2 导出模板；预设名为 `Windows Desktop` 和 `Linux/X11`。

### 校验第三方模组

```powershell
godot --headless --path . --script res://sdk/validate.gd -- --mod-root=sdk/examples/example_boilers
```

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
    → ModScanner.scan       扫描 dev_mods / user://mods_dev / user://mods
    → DependencyResolver    校验 API、依赖、冲突、循环，生成确定性顺序
    → mount resource packs  ProjectSettings.load_resource_pack(path, false)
    → ContentCompiler       JSON → Schema → 注册 → 显式 Patch
    → CrossReferenceValidator + CoreCompletenessChecker
    → RegistryHub.freeze_all
    → FrameworkApi.register 命令 / 查询
    → 主场景
```

Core 加载失败时，主场景仍可进入诊断界面，但不会开始游戏。

### 关键不变量

- **官方内容也是模组**：`framework/` 中不存在具体 `core:*` 内容 ID（有测试守护）。
- **注册表冻结后不可变**：运行态数量、库存、耐久只存在于 `GameState`。
- **命令事务**：`CommandBus` 在 `GameState` 深拷贝上执行，成功才提交并发布领域事件。
- **查询只读**：`QueryBus` 给查询处理器一个临时克隆，防止查询意外修改状态。
- **命名随机流**：`RngService` 按（基础种子、流名、上下文键）派生，新增视觉随机不会影响市场或事故。
- **存档确定性**：数字在规范化 JSON 中量化到 1e-9，保存/加载前后状态哈希一致。
- **模组安全**：内容模组只能提交 JSON / 图片 / 音频；拒绝脚本、动态库、路径穿越与 `res://framework/**` 覆盖。

## 目录结构

```text
project.godot                  Godot 项目入口
framework/
  bootstrap/                   启动、AppContext、启动报告、自动清理
  modding/                     模组扫描、Manifest、依赖、Schema、编译、注册表
  application/                 Command / Query / Event 总线，用例，命令与查询
  domain/                      voyage / economy / contracts / ship / map / events / debt
  services/                    RNG、时钟、日志、本地化、资源、存档
  state/                       GameState（纯数据、可克隆、可哈希）
  ui/                          最小可玩外壳
  tests/                       无头测试运行器与 49 个测试
  localization/                框架 UI 文案（zh_CN / en）
  assets/                      缺失资源占位符
schemas/                       Manifest 与各类内容的 JSON Schema
config/                        默认 UI 设置（config.json）
sdk/                           打包、校验、模组模板、第三方示例
.github/workflows/            GitHub Actions：tag 触发的开发版发布
SNModMaker/                    零依赖网页端模组制作器（原生 HTML/CSS/JS）
assets/                        运行时 UI、音频与字体资产
dev_mods/core/                 官方 MVP 内容（松散的开发态 mod）
dist/mods/                     本地 mod 包（.snavmod.zip）与 core 构建产物；运行时扫描
docs/                          GDD、架构方案、静态代码文档
tools/                         PowerShell 辅助脚本
```

## 内容与数值（Core v1.0.0）

- 5 个港口原型：铁港、香料港、自由镇、渔村、玻璃港。
- 每局生成 4–5 个港口的连通分支网络；造船厂与情报站保证在起点 2 条边内。
- 7 种普通商品（含委托货箱）+ 2 种补给商品（煤炭/淡水）+ 3 种专用造船材料。
- 4 个船体（小型/中型/大型）、3 个锅炉、3 个货舱、2 个导航、2 个安全、1 个固定客舱。
- 经济 / 标准 / 极速三种锅炉策略；工程师 / 领航员岗位。
- 5 段主线 + 4 种普通委托；2 类事件（锅炉过热、偶遇商船）。
- 2 套初始构筑：低耗稳健型、高速冒险型。
- 所有数值均为数据驱动，位于 `dev_mods/core/content/*.json`。

## 模组制作

除了手写 JSON 与 SDK 脚本，也可以使用 [SNModMaker](SNModMaker/README.md)（零依赖网页端）：

```powershell
node SNModMaker/tools/serve.mjs
# 打开 http://127.0.0.1:8099/
```

它从 `schemas/` 读取同一套约束，支持 15 类内容、显式补丁、本地化与资源编辑，可导入现有目录 / ZIP，并导出 `mods/<id>/` 结构的 `.snavmod.zip`。使用本地服务时，项目会同时写入 `SNModMaker/mods/`，导出可写入 `SNModMaker/exports/`。

最小结构：

```text
<mod_id>/
├── manifest.json
├── content/*.json
├── localization/zh_CN.json
└── assets/...
```

- ID 必须为 `<mod_id>:<type>/<local_id>`，且命名空间必须是自己的 `mod_id`。
- 内容文件外壳：

```json
{
  "schema_version": "1.0",
  "content_type": "goods",
  "definitions": [{ "id": "...", "name_key": "...", "enabled": true, "data": {} }]
}
```

- 修改其他模组的定义必须使用显式 `patches` 文件；同路径冲突会阻止启动，不会静默决定胜负。
- 详见 `sdk/templates/mod_template/`、`sdk/examples/example_boilers/` 与 `schemas/`。

## 本地化

- 框架 UI：`framework/localization/{zh_CN,en}.json`。
- Core 内容：`dev_mods/core/localization/{zh_CN,en}.json`。
- 默认 `zh_CN`，缺失键回退到 `en`，再回退到键名本身。

## 已知边界

- 主线的“模块制造 / 仓库 / 旧件重装”目前只实现了购买并安装，未实现打造、运输、独立港口仓库。
- 普通委托池在每次抵达后未自动刷新；持有上限已按声誉计算。
- 大型船已达到“可解锁并购买”，但尚未实现通关判定与结算页。
- UI 是最小可用外壳，设施名称部分为中文硬编码；海图可按已访问港口打开上次在港的市场快照。
- 存档迁移仅支持 Schema 1.x 读取，尚未实现声明式 ID 别名迁移。
- 无头退出时 Godot 会报告静态注册表/脚本的 ObjectDB 泄漏警告；测试退出码仍为 0，不影响运行。

## 文档与协作

- 静态代码文档按“文件镜像 + 模块索引”组织，生成信息见 `docs/static/README.md`。
- 每轮代码改动应先更新对应静态文档，再提交。
- 设计问题优先回到 GDD / 架构文档确认，不用“通过测试”替代需求判断。
