# Steam Navigator（蒸汽航海）MVP — Framework + Core Mod

《蒸汽航海》是一款**蒸汽朋克**背景的航海贸易模拟游戏。本仓库是 MVP 的 Godot 4.x 原型：游戏本体只提供通用框架；官方内容（港口、商品、船体、锅炉、委托、事件等）通过 **`core` 内容模组**加载，走与第三方模组完全相同的发现、校验、注册和冻结流程。

- 设计文档：[MVP GDD v1.0](docs/蒸汽航海_MVP_GDD_V1.0.md)
- 架构文档：[框架 + 模组 v1.0](docs/蒸汽航海_项目架构方案_框架与模组_V1.0.md)
- 正式版方向：[持久模拟经营战役](docs/design/PERSISTENT_CAMPAIGN_ARCHITECTURE.md)
- 正式版路线图：[从 MVP 到持久模拟经营](docs/design/FULL_GAME_ROADMAP.md)
- 实体契约 v2：[content_types 与 Schema 2.0 契约](docs/design/ENTITY_CONTRACT_V2.md)
- 模块实例与部件损耗：[SHIP_MODULE_INSTANCES.md](docs/design/SHIP_MODULE_INSTANCES.md)
- 战斗架构采纳边界：[战斗系统架构评审](docs/design/COMBAT_ARCHITECTURE_REVIEW.md)
- 迭代 1 实现契约：[MVP 闭环](docs/design/ITERATION_1_MVP_LOOP.md)
- 迭代 2 实现契约：[MVP 反馈优化](docs/design/ITERATION_2_MVP_FEEDBACK.md)
- 静态代码文档：[docs/static/README.md](docs/static/README.md)
- 美术/音频资产映射：[docs/design/ASSET_MAP.md](docs/design/ASSET_MAP.md)
- 物品建模半工作流（派发给子代理）：[docs/design/MODELING_WORKFLOW.md](docs/design/MODELING_WORKFLOW.md)
- UI 原型与落地说明：[docs/design/UI_PROTOTYPE.md](docs/design/UI_PROTOTYPE.md)
- 船厂界面（图 2 / 图 3 布局重构）：[docs/design/SHIPYARD_UI_REFACTOR.md](docs/design/SHIPYARD_UI_REFACTOR.md)
- 2.5D 固定舞台升级方案（阶段 1 前两个切片已落地：船厂 3D + 通用舞台宿主 + 港口骨架）：[docs/design/2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md)
- 高频决策页面重构指南：[docs/design/HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md](docs/design/HIGH_FREQUENCY_UI_REFACTOR_GUIDE.md)
- 任务与路线图：[todo.md](todo.md)

## 当前状态

基础框架与首个可玩纵切片已跑通：

- 模组扫描（目录 / ZIP）、Manifest 校验、SemVer 依赖解析、冲突与循环检测、注册表冻结。
- JSON Schema 子集校验（含本地 `$ref`）、跨引用校验、Core 完整性检查、显式 Patch；新版实体 `information.texture/model` 会解析进注册表并校验资源类型。
- 命名随机流、确定性开局、市场 NPC 模拟、情报快照、借贷、声望、自动存档。
- 命令 / 查询总线（事务克隆提交、领域事件、只读 ViewModel）。
- 可玩的程序生成海图：点击已访问港口查看上次在港货价/储备、贸易、补给、维修、造船厂购买/打造/仓库/替换模块、委托接取、出航预览、风险事件、抵达结算与通关总结。
- 市场规则：任意港口都收购所有普通货物；只有本港商品表列出的品种可以直接买入。库存按加权平均成本记录并显示；玩家单笔交易只把价格推向新均衡的 35%，避免过度敏感。
- 煤炭与淡水作为补给商品进入港口市场，价格随港口库存和 NPC 商船流动浮动；在补给页按当前市场价买入。
- 5 段主线委托链（自动接第 1 段，后续以 offer 形式接取）、4 个普通委托模板。
- **迭代 1 · MVP 闭环**：船厂支持购买/打造/仓库/替换/卸下/随船运输模块；每港独立仓库，旧件入当前港仓库；普通委托池在每次抵达后整池刷新并按声誉限制持有上限；完成主线 05 后在造船厂组装「大型船体 + 锅炉 + ≥1 货舱」触发通关总结页（构筑、航次、准时率、事故、收入/支出/利润、债务、耐久）。
- 启动主菜单：开始游戏 / 加载游戏 / 模组 / 设置 / 退出游戏；右下角显示开发团队与版本。
- 设置持久化：编辑器内默认读 `config/config.json`、写入 `user://config/config.json`；发布包优先以 exe 同级的 `config/config.json` 作为可编辑配置，目录不可写时回退到 `user://config/config.json`。
- 最小 UI：开局构筑选择，以及总览、市场、委托、船厂、补给、情报、出航七个独立界面；共享蒸汽朋克 Theme、全屏主菜单背景、铁港横幅、两列委托卡、顶部导航、页面淡入淡出与抵达结算页。
- 交易反馈：买入/卖出、接取委托、购买补给成功后播放金币音效；右下角固定开发团队与版本。
- 高频决策页第一轮：补给卡（存量/可补上限/续航/补满花费）、委托固定五区卡片与可接/进行中分区、市场真实价格历史与迷你折线。
- 海图重设计：三次贝塞尔曲线航路、每港从邻居组中心计算的唯一出港方向、经纬网、洋流、罗盘、图内图例、当前港脉冲光晕与更宽的图表布局。
- **迭代 2 · MVP 反馈优化**（试玩反馈）：tier1 部件改为「仅金币」打造（不消耗材料）；打造变成带工时的**订单**，并新增 `port.wait`「在港等待」让时间流动可感知；补给比例条改用稳定物理上限，上限被另一项占用时用右端反向损失带表示；情报页合并为「商品 × 港口」对比表（未探索港口保留整列并显示「未知港口」+「？」，趋势为红降/绿升数字）；顶部信息条常显当前港口与剩余载重/剩余货舱；总览常驻通关条件清单，主线完成后提示下一步（船厂页改为组件分类入口，不再重复清单）。
- **船厂界面（图 2 / 图 3 布局）**：正常态三列——左「已有船舶」贴图船卡、中心 3D 实机舞台、右「组件」六类入口；点击分类进入改装态，三列变为——左授权贴图纵剖图（`assets/ui/shipyard/ship_section.png`，每槽位一枚可拖放贴片，不再是运行时多边形拼接）、中间所选分类的槽位 / 装配 / 购买 / 打造操作卡、右竖排分类页签（船体 / 锅炉 / 货舱 / 导航 / 安全 / 客舱 / 杂项）。旧的整页下方面板（打造订单 / 港口仓库 / 配方 / 可购买模块 / 通关清单）全部删除，命令迁入分类与「杂项」页签，通关清单只在总览；改装态与分类由 Shell 记忆，切页或命令重建后保持；3D 资产缺失时回退程序化占位。预览：[正常态](docs/design/screenshots/stage3d/shipyard_normal.png) / [改装态](docs/design/screenshots/shipyard_refit.png) / [货舱分类](docs/design/screenshots/shipyard_refit_cargo.png) / [杂项](docs/design/screenshots/shipyard_refit_misc.png)；布局、删除面板与命令迁移表见 [SHIPYARD_UI_REFACTOR.md](docs/design/SHIPYARD_UI_REFACTOR.md)。
- **船厂 3D 实机舞台（2.5D 首个切片）**：正常态中央由 [SNShipStage3D](framework/ui/components/sn_ship_stage_3d.gd) 渲染真实船体 GLB（按 `hull_tier` 选船）、固定 3/4 机位、海面与灯光；复用港口水面着色器（船体泡沫环跟随包围盒），改装态隐藏 3D 切回纵剖图。顶部导航、槽位、拖拽与所有 2D 页面不变；没有船体 GLB 时自动保留程序化占位。预览：[船厂 3D 舞台](docs/design/screenshots/stage3d/shipyard_normal.png)，方案见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md#L11)。
- **2.5D 舞台第二切片（通用宿主 + 港口骨架 + 场景填充）**：`SNShipStage3D` 重写为 [SNStageHost](framework/ui/components/sn_stage_host.gd) 适配器，宿主独占 SubViewport/World3D 并驱动 [LocationStage](framework/ui/stages/location_stage.gd) 的 `enter → bind → exit` 生命周期（隐藏即停更、缺失场景回退 2D、单舞台）；船厂环境/灯光/水面/机位/升沉迁入 [ShipyardStage](framework/ui/stages/shipyard_stage.gd)，公共构建器为 [StageKit](framework/ui/stages/stage_kit.gd)。新增 [PortStage](framework/ui/stages/port_stage.gd)：按 `port.facilities` 装配设施（有 `facility_visuals` GLB 则替换，否则程序化 billboard；缺席设施只放货堆 filler、不生成热点），L0 暖色程序化天空/L1 banner 背板（缺失不放黑盒：暖霞渐变 + 双太阳光晕的程序化 painted backdrop）/L2 双深度带确定性剪影（仅无 banner，小/中/大 7/10/13 栋 + 2/2/3 吊机，MultiMesh 批量）/L5 玩家船随波，另加 L6 左上角前景框与 L7 3 组蒸汽粒子 + 2–3 层雾带（全程序化、无新资产；目前仅铁港有 banner，其余港口走 painted backdrop）；码头为薄甲板桩基栈桥（入水木桩/桩帽/横梁），并按 `port.size` 0.9/1.0/1.15 缩放设施层；`facility_anchors()`/`facility_screen_anchor()` 供 2D 热点使用。**第五切片再接入 10 件港口街景 `SN_HT_*`（L2b town kit：5 建筑 + 围栏/工人/装饰/小船，town 存在时跳过 L2 剪影）。**独立预览场景 `dev_scenes/port_stage/` + 窗口截图脚本 `tools/godot/capture_port_stage.gd` 已跑通。预览：[完整港口](docs/design/screenshots/port_stage/port_stage_preview.png) / [稀疏港口](docs/design/screenshots/port_stage/port_stage_sparse.png)，方案见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md#L11)。
- **2.5D 舞台第三切片（总览页接入 + 2D 热点）**：总览页可在「俯瞰港口 / 返回总览」间切换：`PortStage` 作为全窗 3D 背景层挂在 `Background` 之上、UI 之下，顶部 HUD/导航不变；设施热点由 `facility_anchors()` → `facility_screen_anchor()` 相机投影生成（第五切片升级为两侧固定招牌）；舞台加载失败置本会话回退并提示 `ui.error.port_stage_unavailable`。
- **2.5D 第五切片（Bounty Train 式主界面 + 港口街景）**：总览默认进入全窗 3D 港口舞台；顶部压缩为 2 行 121 px 紧凑 chrome（header / 资源 / 导航信息全部保留），设施入口改为左右两列「招牌」按钮（按投影 x 分列、箭头指向场景，右侧底部常驻「出航」），底部 60 px 船舶/港口状态条（耐久/货舱/煤/水/受损/最新通告 + 详细总览/出航/等待 12h），「详细总览」抽屉默认关闭、打开时用原 2D 面板（含通关清单）覆盖舞台，2D 回退仍可用；港口街景 10 件 `SN_HT_*` 建筑/工人/小船经 `port.diorama.town`（16 项 `town_visuals`，旧存档按 archetype 回填）接入。预览：[主界面](docs/design/screenshots/overview_port_stage.png) / [详细总览](docs/design/screenshots/overview_detail.png)。
- **2.5D 第六切片（主界面美术收尾 + 街景密度 + 性能回收）**：HUD 资源 chip 接入可选内容图标（`icon.money/coal/water` 经 `AssetService.find_key()` 按裸键解析，缺资产自动回退纯文字）；设施招牌改为自绘木牌/铁框/黄铜铆钉 + 设施专属徽记 + 指向场景的箭头 + 悬停黄铜光晕（[sn_harbor_sign.gd](framework/ui/components/sn_harbor_sign.gd)），148×38 紧凑规格与精简 chrome 支持窄窗口；港口街景 normal 密度 29→47 件（市场摊/吊车/货堆/托盘/跳板/系缆桩/绞盘/浮标等，按 `port.size` 与 `port.diorama.density` 确定性增减，sparse 28 / busy 63）；设施与街景、玩家船体全部静态合并（按材质/共享盒体批处理，透明/Shader/骨骼动画自动回退），实测 **preview 63 / sparse 56 draw calls**（原 284 / 255；37k tris ≤60k），无 banner 港口新增 3 层程序化远景（山脊/远城塔楼/屋脊烟囱，1 个 MultiMesh）。预览：[主界面 1440](docs/design/screenshots/overview_port_stage.png) / [主界面 960×540](docs/design/screenshots/overview_port_stage_960.png) / [详细总览](docs/design/screenshots/overview_detail.png) / [完整港口](docs/design/screenshots/port_stage/port_stage_preview.png) / [无 banner 稀疏港口](docs/design/screenshots/port_stage/port_stage_sparse.png)，细节见 [2.5D_STAGE_PLAN.md](docs/design/2.5D_STAGE_PLAN.md#L11)。
- **模块实例与部件损耗**：每个已装模块有稳定实例 id 与 0–1 状态；`damage_module` 效果可损坏指定槽位（锅炉过热事件已接入），港口维修按「船体缺失 + 部件损耗」点数计价并恢复全部实例。界面可见：顶部信息条「部件 1 · 50%」chip、船卡「受损部件」行、船厂槽位卡「状态 NN%」徽标、补给页「含部件损耗」报价；旧存档缺实例表按满状态补齐。预览：[受损船卡](docs/design/screenshots/module_condition/shipyard_normal_damaged.png) / [状态徽标](docs/design/screenshots/module_condition/shipyard_refit_damaged.png) / [维修报价](docs/design/screenshots/module_condition/supply_damaged.png)，说明见 [SHIP_MODULE_INSTANCES.md](docs/design/SHIP_MODULE_INSTANCES.md)。
- 无头测试套件：**162 个测试全部通过**（含 ZIP 打包加载、30 个种子的地图硬约束、保存哈希一致性、save schema 1.x→2.0 迁移、Content Schema 2.0 草案校验、CampaignState 分区、模块实例与部件损耗、显式 Patch 冲突、港口记忆、补给与库存成本、仓库存取/打造订单/在港等待/替换、委托刷新、通报文案本地化、密集界面横向排版、通关判定、船厂界面（三列布局、纵剖图贴图契约、槽位与分类记忆、2.5D 渲染器替换钩子、拖拽安装、旧面板移除、状态徽标）、2.5D 舞台基础设施（LocationStage / SNStageHost 生命周期与回退 / ShipyardStage / PortStage 装配、替换、缩放与 portal）、PortStage 场景填充访问器、港口街景 town kit（满配 47 / 无 town 5+5 / 非法路径回退 / port.view 26 项端到端 / 密度随 size 与 `diorama.density` 缩放）、静态层与玩家船刚性合批（含动画/骨骼/透明安全回退）、无 banner 程序化远景层、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 960×540 + 底部状态条 + 详细总览抽屉与 2D 回退、主界面接线冒烟、内容类型单一真源与 v2 模块分类守护，以及 9 个 seed 的完整通关回归）。
- **3D 港口样片（独立场景）**：`dev_scenes/harbor/` 复用 `assets/models` 的 1795 双桅纵帆船 `SN_Schooner_Fame`（黑船身 + 赭黄腰线 + 双桅斜桁帆，用户要求无星条旗） / 塔吊 / 码头道具搭一个固定机位小港口，自写 Godot 水面着色器（顶点波浪 + 噪声法线 + 菲涅耳天空反射 + 太阳耀斑 + 岸线/船体泡沫 + 远水雾色），船体随与着色器同源的波浪起伏。**不接入主场景**，仅供水面观感与构图验证；说明见 [dev_scenes/harbor/README.md](dev_scenes/harbor/README.md)，预览见 [港口样片截图](docs/design/screenshots/harbor_diorama_schooner.png) 与 [纵帆船近景](docs/design/screenshots/harbor_diorama_schooner_detail.png)。
- SDK：模组打包、无头校验、模组模板与一个第三方锅炉示例。
- [SNModMaker](SNModMaker/README.md)：零依赖网页端模组制作器，可视化编辑、校验并打包 `.snavmod.zip`；实体资源使用主题化可搜索选择器，船体可在独立模块区配置槽位。

尚未完成、但已留出扩展位置的内容见 [todo.md](todo.md)。

## 环境要求

- Godot **4.4+**（本仓库在 **4.7.2 stable** 上验证）。
- 无需 C# / .NET；纯 GDScript。
- 无头测试与 SDK 工具不依赖编辑器 UI。

## 快速开始

1. 用 Godot 打开仓库根目录（包含 `project.godot`）。
2. 按 **F5** 运行。主场景为 `framework/ui/shell/main.tscn`。
3. 选择初始构筑（低耗稳健型 / 高速冒险型）和可选种子，开始新航程。

开发模式下，Core 从 `res://dev_mods/core/` 松散目录加载；同时扫描 `res://dist/mods`，方便直接放入第三方 `.snavmod.zip`。同 ID 时松散目录优先，`dist/mods` 里的 core 构建产物会被自动忽略。发布模式不扫描 `res://dev_mods`（它也不会被导出进 PCK），只扫描可执行文件旁的 `mods/` 与 `user://mods/`。

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
Tests: 100 passed, 0 failed, 100 total
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
git tag -a v0.2.0-dev.1 -m "Steam Navigator v0.2.0-dev.1"
git push origin v0.2.0-dev.1
```

发布资产：`SteamNavigator-<tag>-windows.zip`、`SteamNavigator-<tag>-linux.zip`、`core-1.0.0.snavmod.zip`、`SHA256SUMS.txt`。

发布包是标准便携布局，解压后保持同一层目录：

```text
SteamNavigator/
  SteamNavigator.exe            # Linux 为 SteamNavigator.x86_64
  mods/
    core-1.0.0.snavmod.zip      # 官方内容包，启动必需
  config/
    config.json                 # 可编辑的默认设置
```

- 发布标签会先运行 `sdk/validate.gd` 校验松散 core；manifest 声明的资产（贴图 / GLB）不完整时直接阻止发布。
- `core-1.0.0.snavmod.zip` 也作为独立资产提供，方便第三方或手动替换；直接使用发布包时无需另外下载。
- [SNModMaker](SNModMaker/README.md) 的「导出并覆盖到发布包 mods/」默认就写入 `dist/build/<platform>/mods/`，本地导出的发布包可直接接收编辑器部署的模组。
- 发布版 exe 不再内嵌 `dev_mods/`，内容只从 `mods/` 读取，因此不会再出现「核心包半导出」导致的启动失败。

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
- **模组安全**：内容模组只能提交 JSON / 图片 / 音频 / 单文件 GLB 模型；拒绝脚本、动态库、场景、路径穿越与 `res://framework/**` 覆盖。

## 目录结构

```text
project.godot                  Godot 项目入口
content_types.json             内容类型单一真源（框架 / 编辑器 / Schema / SDK 契约）
framework/
  bootstrap/                   启动、AppContext、启动报告、自动清理
  modding/                     模组扫描、Manifest、依赖、Schema、编译、注册表
  application/                 Command / Query / Event 总线，用例，命令与查询
  domain/                      voyage / economy / contracts / ship / map / events / debt / run(通关)
  services/                    RNG、时钟、日志、本地化、资源、存档
  state/                       GameState（纯数据、可克隆、可哈希）
  ui/                          最小可玩外壳（2.5D 固定舞台子系统在 framework/ui/stages/）
  tests/                       无头测试运行器与 162 个测试
  localization/                框架 UI 文案（zh_CN / en）
  assets/                      缺失资源占位符
schemas/                       Manifest 与各类内容的 JSON Schema
config/                        默认 UI 设置（config.json）
sdk/                           打包、校验、模组模板、第三方示例
.github/workflows/            GitHub Actions：tag 触发的开发版发布
SNModMaker/                    零依赖网页端模组制作器（原生 HTML/CSS/JS）
assets/                        运行时 UI、音频与字体资产；船厂纵剖图 / 船卡贴图在 assets/ui/shipyard/，水面 shader / 材质 / 噪声纹理在 assets/{shaders,materials,textures}/water
dev_scenes/harbor/             独立 3D 港口样片（不接入主流程；水面着色器与浮船试做）
dev_scenes/port_stage/         独立 PortStage 预览场景（不接入主流程；两套样例 ViewModel）
dev_mods/core/                 官方 MVP 内容（松散的开发态 mod）
dist/mods/                     本地 mod 包（.snavmod.zip）与 core 构建产物；运行时扫描
docs/                          GDD、架构方案、静态代码文档
tools/                         PowerShell 辅助脚本、UI 截图工具与建模生成器
```

## 内容与数值（Core v1.0.0）

- 5 个港口原型：铁港、香料港、自由镇、渔村、玻璃港。
- 每局生成 4–5 个港口的连通分支网络；造船厂与情报站保证在起点 2 条边内。
- 7 种普通商品（含委托货箱）+ 2 种补给商品（煤炭/淡水）+ 3 种专用造船材料。
- 4 个船体（小型/中型/大型）、3 个锅炉、3 个货舱、2 个导航、2 个安全、1 个固定客舱。
- 六类模块都带打造配方：tier1 为**仅金币**配方（`materials: []` + `craft_cost` + `craft_time_hours`，反馈 1），tier≥2 额外消耗材料与 `craft_cost`；两个造船厂港口限量出售精密齿轮。
- 经济 / 标准 / 极速三种锅炉策略；工程师 / 领航员岗位。
- 5 段主线 + 4 种普通委托；2 类事件（锅炉过热、偶遇商船）。
- 2 套初始构筑：低耗稳健型、高速冒险型。
- 15 条 Core 实体已配置新版 `information.texture/model`：船体、锅炉、商品、造船材料与铁港可直接解析对应贴图或 GLB 模型。
- 所有数值均为数据驱动，位于 `dev_mods/core/content/*.json`。

## 模组制作

除了手写 JSON 与 SDK 脚本，也可以使用 [SNModMaker](SNModMaker/README.md)（零依赖网页端）：

```powershell
node SNModMaker/tools/serve.mjs
# 打开 http://127.0.0.1:8099/
```

它从 `schemas/` 读取同一套约束，支持 15 类内容、显式补丁、本地化与资源编辑，可导入现有目录 / ZIP，并导出 `mods/<id>/` 结构的 `.snavmod.zip`。内容类型清单来自 `content_types.json`：修改后运行 `node tools/gen_content_types.mjs` 重新生成框架常量与编辑器目录（`--check` 可检查是否过期）。实体 ID 修改时只实时预览新多语言键，点击「保存条目」后才原子迁移全部语言文本；船只与模块类型可在页面子分页间直接切换。每个实体还可引用贴图与单文件 GLB 模型资源；本体解析器会将这些键归一化为 `asset://<mod>/<key>` 并拒绝缺失或格式不匹配的资源；资源页会对 GLB 生成自动取景缩略图（内置解析 + WebGL，不引入第三方库）。使用本地服务时，项目会同时写入 `SNModMaker/mods/`，普通导出写入 `SNModMaker/exports/`；「导出并覆盖到发布包 mods/」默认写入 `dist/build/<platform>/mods/<id>.snavmod.zip`（可用 `SNMODMAKER_GAME_MODS_DIR` 指向其他游戏目录或开发态 `dist/mods`）。

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

- 材料随船运输仍计入货舱容量；GDD 9.1 中“材料不占货舱容量”本轮只对未安装模块（transit）实现。
- 船厂仓库/运输 UI 为基础版：材料按固定 5 件批量存取，尚无数量步进或批量选择。
- 通关总结页为数据化总结，不含航线回放、成就与统计对比。
- 船厂改装态纵剖图是一张 2D 授权贴图；正常态已是真实 3D 船体舞台（固定机位、只做表现，不含环绕与场景热点），3D 船体资产缺失时回退程序化 2D 占位。贴图与当前可玩船型视觉也不完全一致（纵剖图 / 船卡为铁甲舰风格）。**主界面已是全窗 `PortStage` + 紧凑 HUD（含资源图标）+ 主题化两侧招牌 + 底部状态条 + 详细总览抽屉；港口街景 normal 47 件与 `port.diorama` 已接线，设施/街景/玩家船静态合批后实测 63/56 draw calls；剩余 2.5D 工作是港务/市场等独立舞台、出航/进港演出、质量档位/低配回退与 L2 LOD。**
- **内容资产全部走模组**：船体/模块/道具模型与港口横幅随 `core` 模组发布（`dev_mods/core/assets/**` + manifest `model.*`/`banner.*` 键），发布包 PCK 已排除 `assets/models/*`；运行时由 `ContentAssetLoader` 读取模组内原始 `.glb`/`.png`。本体内只保留框架资源（代码、Theme/字体、UI 外壳图、音频、水面 shader/材质/贴图）。新增内容模型请放 `dev_mods/core/assets/models/<category>/` 后重新 `pack_core`，不要放回 `res://assets/models`。
- UI 是最小可用外壳，设施名称部分为中文硬编码；海图可按已访问港口打开上次在港的市场快照。
- 存档已支持 save schema 1.x → 2.0 迁移（回填 campaign 元数据与分区，state/content schema 分离）；模块实例表 `ship.module_instances` 与 campaign 分区均由惰性 ensure 补齐；声明式 ID 别名迁移仍未实现，新字段继续通过惰性 ensure 补齐。
- 模块 condition 目前只影响失效标记与维修费用，尚未改变航速/容量等派生属性；统一 Module 迁移（definition_id 移入实例）与战斗期性能影响在后续阶段。
- Content Schema 2.0 目前只有 `schemas/v2` 草案（`common` + start/world/region/site/route/weather/faction/discovery），尚未接入运行时加载；现有内容仍使用 Schema 1.0。
- 无头退出时 Godot 会报告静态注册表/脚本的 ObjectDB 泄漏警告；测试退出码仍为 0，不影响运行。

## 文档与协作

- 静态代码文档按“文件镜像 + 模块索引”组织，生成信息见 `docs/static/README.md`。
- 每轮代码改动应先更新对应静态文档，再提交。
- 设计问题优先回到 GDD / 架构文档确认，不用“通过测试”替代需求判断。
