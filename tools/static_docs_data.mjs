// Static documentation metadata. Kept next to the generator so docs can be
// regenerated deterministically after code changes.
//
// Each FILE_DOCS entry becomes docs/static/<source path>.md. Symbol lines are
// extracted from source; roles/contracts/L2 notes are curated here.

export const FILE_DOCS = {
  "project.godot": {
    role: "Godot 项目入口：主场景、Autoload、窗口、渲染与框架扫描配置。",
    contracts: [
      "`run/main_scene` 指向 `framework/ui/shell/main.tscn`。",
      "`AppBootstrap` Autoload 在场景加载前启动内容加载；`--script` 测试模式下自行跳过。",
      "`framework/mods/scan_roots` 默认依次为 `res://dev_mods`、`res://dist/mods`、`user://mods_dev`、`user://mods`；模板构建会忽略所有 `res://` 根并追加 exe 同级 `mods/`。",
      "`config/features` 声明 4.4 兼容；实际验证引擎为 4.7.2。"
    ]
  },

  "export_presets.cfg": {
    role: "Godot 导出预设：Windows / Linux 发布预设、PCK 内嵌与导出过滤规则。",
    contracts: [
      "`binary_format/embed_pck=true`：发布产物是单个 exe，资源随 PCK 内嵌。",
      "`exclude_filter` 额外排除 `dev_mods`、`dev_scenes`、`framework/tests`，避免把开发态松散 core 半导出进发布版。",
      "`exclude_filter` 还排除 `assets/models/*`：内容模型随 core 模组发布，本体 PCK 只保留框架资源；新增内容模型不要放回 `res://assets/models`。",
      "发布包的标准目录（exe + `mods/` + `config/`）由 `.github/workflows/release.yml` 在导出后组装。"
    ]
  },

  "content_types.json": {
    role: "内容类型单一真源：键、单数、Schema 路径、注册表/patch 类型、编辑器展示元数据、v2 模块分类与正式版路线图规划。",
    contracts: [
      "`tools/gen_content_types.mjs` 生成 `framework/modding/content_types.gd` 与 `SNModMaker/js/content-types.js`；`--check` 用于门禁。",
      "Godot 的 `test_content_types_manifest.gd` 与 Node 用例分别守护生成物与 manifest 一致。",
      "`types` 只列可加载的 active 类型；`planned` 只用于路线图，禁止注册或加载。",
      "`v2_target` / `aliases` 是迁移提示，不代表当前运行时支持合并后的实体。",
      "`v2_module_categories` 记录目标分类：导航/安全归入 `utility`，不再单独设内容类型或编辑器分组。",
      "`draft_schemas` 登记 Schema 2.0 草案：类型必须仍在 planned 中、不得 active，Schema 文件由 `test_schema_v2_drafts.gd` 校验；当前包含 start_profiles / world_profiles / regions / sites / route_templates / weather_profiles / factions / discoveries。"
    ]
  },

  ".github/workflows/release.yml": {
    role: "`v*` tag 触发的发布流水线：测试 → core 校验 → 导出 Windows/Linux → 打包标准便携目录 → GitHub Release。",
    contracts: [
      "发布前运行 `sdk/validate.gd`；core manifest 声明的内容 / 本地化 / 资产缺失时直接失败。",
      "发布前运行 `gen_content_types.mjs --check`，防止框架常量或编辑器类型目录落后于 `content_types.json`。",
      "Windows/Linux 压缩包统一为顶层 `SteamNavigator/`，内含 exe、`mods/core-*.snavmod.zip` 与 `config/config.json`。",
      "`core-*.snavmod.zip` 同时作为独立 Release 资产，并参与 `SHA256SUMS.txt`。"
    ]
  },

  "framework/bootstrap/bootstrap.gd": {
    role: "组合根启动编排：创建 AppContext、调用 ModLoader、注册公共 API 并把结果汇总为 StartupReport。",
    dependencies: ["AppContext", "ModLoader", "FrameworkApi", "StartupReport", "ProjectSettings"],
    contracts: [
      "加载失败不抛异常：所有可预期错误进入 StartupReport，UI 据此进入诊断界面。",
      "即使 fatal，也会注册命令/查询并冻结空注册表，保证后续调用返回结构化错误。",
      "默认扫描 `res://dev_mods`、`res://dist/mods`、`user://mods_dev`、`user://mods`；模板构建跳过所有 `res://` 根并追加可执行文件旁 `mods/`，避免把 PCK 里半导出的松散模组当成有效内容。",
      "测试可通过 `run(overrides)` 覆盖扫描根、存档目录、日志开关与自动存档。"
    ],
    l2: {
      "run(overrides)": [
        "创建 AppContext 后立即加载框架基础本地化，再交给 ModLoader 完成扫描、解析、编译、校验与冻结。",
        "最终调用 `FrameworkApi.register(context)`；命令/查询在内容加载失败时仍可用，便于诊断。",
        "`AppContext.set_active(context)` 是进程级单例入口，测试每次启动都会覆盖。"
      ]
    }
  },

  "framework/bootstrap/app_bootstrap.gd": {
    role: "SceneTree Autoload：在首场景加载前执行 Bootstrap，并保存 context/report 供 UI 读取。",
    contracts: [
      "检测到 `--script` 或用户参数 `--run-tests` 时直接返回，避免测试同时触发 Autoload 加载。",
      "主场景通过 `AppContext.get_active()` 取组合根；若 Autoload 尚未完成则短暂等待重试。"
    ]
  },

  "framework/bootstrap/app_context.gd": {
    role: "组合根对象：持有服务、注册表、总线、当前 GameState 与启动报告。",
    dependencies: ["Logger/AppLogger", "LocalizationService", "AssetService", "RegistryHub", "DomainEventBus", "CommandBus", "QueryBus", "SaveService", "RngService", "GameState"],
    contracts: [
      "UI 与用例共享同一个 AppContext；状态修改只能经 CommandBus。",
      "`translate()` 是 UI 取本地化文本的唯一入口，缺失键回退到 fallback 或键名。",
      "`save_meta()` 把模组清单、当前港与种子写入存档头，供兼容性检查。",
      "`pre_voyage_state` 仅用于同一进程内的出航失败回滚；跨会话回滚依赖 `pre_voyage` 存档槽。"
    ]
  },

  "framework/bootstrap/startup_report.gd": {
    role: "启动结果 DTO：分级错误/警告、启用模组摘要、内容计数、耗时与注册表状态。",
    contracts: [
      "状态分级：任一 `severity=fatal` → FATAL；否则有错误/警告/禁用模组 → DEGRADED；否则 OK。",
      "`to_dict()` 输出可直接给 UI/JSON 诊断；`format_text()` 用于控制台与无头测试。",
      "Core 加载失败必须体现为 fatal，而不是仅记录普通错误。"
    ]
  },

  "framework/core/json_utils.gd": {
    role: "JSON 解析、规范化序列化、JSON Pointer 读写与深比较辅助。",
    contracts: [
      "`canonical_stringify()` 排序键并把浮点量化到 1e-9，保证存档/加载指纹一致。",
      "`pointer_apply()` 支持 add/replace/remove；数组 `-` 仅用于末尾 add。",
      "JSON Pointer 对 `~` 与 `/` 做 RFC 6901 转义。"
    ],
    l2: {
      "canonical_stringify(value, indent)": [
        "递归转换字典键为 String、StringName 为 String、PackedStringArray 为 Array。",
        "整数值的浮点（含 JSON 往返产生的 1.0）归一化为 int；其余浮点四舍五入到 1e-9。",
        "使用 `JSON.stringify(..., sort_keys=true, full_precision=true)`；这是状态哈希与存档共用的确定性表示。"
      ],
      "pointer_apply(root, pointer, mode, value)": [
        "禁止替换根指针；逐段下钻并在最后一层执行操作。",
        "对象 replace 要求键已存在；remove 要求目标存在；数组 add 允许 index == size。",
        "失败返回 `{ok:false,error}`，成功原地修改容器并返回 `{ok:true}`。"
      ]
    }
  },

  "framework/core/path_guard.gd": {
    role: "不可信模组路径的格式、长度、扩展名与穿越检查。",
    contracts: [
      "拒绝绝对路径、盘符、`..`、反斜杠、`://`、空段与超过 16 层的路径。",
      "脚本、动态库、场景、引擎导入文件在内容模组中一律禁止。",
      "内容/资源/本地化分别使用白名单扩展名；资源允许图片、音频与单文件 GLB 模型。"
    ]
  },

  "framework/core/semver.gd": {
    role: "SemVer 2.0 解析、比较与格式化（含 prerelease 排序）。",
    contracts: [
      "拒绝前导零与两段式版本；build 元数据不参与比较。",
      "prerelease 低于同核心版本；数字段按数值比较，字母段按字典序。",
      "方法名为 `as_text()`，避免覆盖 Object.to_string。"
    ]
  },

  "framework/core/version_range.gd": {
    role: "内容模组依赖使用的版本范围求值器。",
    contracts: [
      "支持 `*`、精确版本、比较符、`^`、`~`、空格/逗号 AND、`||` OR。",
      "不使用任意表达式求值；解析失败写入 `error` 并使 `matches()` 返回 false。",
      "Caret 对 0.x 按语义版本规则收紧上界。"
    ]
  },

  "framework/modding/mod_loader.gd": {
    role: "模组生命周期总控：扫描 → 依赖解析 → 挂载 → 编译 → 交叉校验 → Core 完整性 → 冻结。",
    dependencies: ["ModScanner", "DependencyResolver", "ContentCompiler", "CrossReferenceValidator", "CoreCompletenessChecker", "StartupReport", "AppContext"],
    contracts: [
      "解析阶段 fatal 时立即返回，不编译内容；报告仍标记 registry_frozen。",
      "Core 内容错误/Core 完整性错误升级为 fatal；第三方模组错误保留为普通错误并禁用具体定义。",
      "ZIP 挂载使用 `load_resource_pack(path, false)`，禁止覆盖既有路径；挂载失败只降级资源，不阻断内容读取。",
      "编译完成后关闭所有 ModSource（ZIPReader）。"
    ],
    l2: {
      "load_mods(config)": [
        "每个阶段独立计时并写入 `report.timings_ms`（scan/resolve/mount/compile/validate/total）。",
        "只有 `resolution.order` 中且未被禁用的模组进入 `packages` 与编译。",
        "完成后 `registry.freeze_all()` 并关闭包；之后任何注册尝试都会返回 `registry_frozen`。"
      ]
    }
  },

  "framework/modding/mod_scanner.gd": {
    role: "发现松散目录与 `.snavmod.zip`，执行文件安全扫描并解析 Manifest。",
    contracts: [
      "ZIP 必须只有一个 manifest，且路径为 `mods/<id>/manifest.json`。",
      "松散目录允许 Godot 生成的 `.import`/`.uid` 元数据；ZIP 不允许。",
      "未知扩展名、脚本/动态库、路径穿越、超大包/文件数量均拒绝。",
      "Manifest 同时经过 JSON Schema 与 `ModManifest` 语义检查。",
      "同名松散目录优先于 ZIP；core 的 ZIP 构建产物被松散 core 静默忽略，其他重复 ID 产生 warning。"
    ]
  },

  "framework/modding/mod_manifest.gd": {
    role: "Manifest 语义模型：ID、SemVer、API、依赖、内容/资源/本地化路径与能力声明。",
    contracts: [
      "ID 正则 `^[a-z][a-z0-9_]{2,31}$`；仅 core 可声明 `required=true`。",
      "依赖版本范围立即解析并保存为 VersionRange；非法范围记录错误。",
      "内容路径必须安全、`.json` 且数量 ≥1；资源必须是允许的图片/音频类型。",
      "`accepts_api()` 要求主版本相等、次版本不大于框架。"
    ]
  },

  "framework/modding/dependency_resolver.gd": {
    role: "校验模组健康度、冲突、能力、依赖版本，并生成确定性拓扑加载顺序。",
    contracts: [
      "错误分级：Core 问题或其他 fatal 阻断启动；其余模组问题禁用模组并继续。",
      "冲突显式声明时按 load_priority、再按 ID 决定保留者，并记录禁用原因。",
      "依赖缺失/被禁用/版本不匹配会递归禁用依赖者。",
      "同一依赖层按 (load_priority, id) 排序；循环/被循环阻塞的节点全部禁用并报告。"
    ],
    l2: {
      "_build_order()": [
        "反复执行 Kahn 排序；未进入结果的节点即循环或被循环阻塞。",
        "禁用剩余节点后重建 active 集合，最多 8 轮；保证终止。",
        "Core 在任何阶段被禁用都会设置 fatal。"
      ]
    }
  },

  "framework/modding/content_compiler.gd": {
    role: "读取模组内容 JSON，执行 Schema 校验、实体 information 资源解析、定义注册、本地化/资源登记与显式 Patch。",
    contracts: [
      "定义 ID 的命名空间必须等于来源模组；ID 类型段必须与 content_type 单数一致。",
      "文件级 Schema 错误拒绝整份文件；单条定义错误只拒绝该定义。",
      "information.texture/model 可使用本模组裸资源键或完整 asset:// URI；贴图只接受 png/webp/svg，模型只接受 GLB，缺失或类型错误拒绝该定义。",
      "Patch 冲突以 `target + JSON Pointer` 为键，跨模组同路径直接报错，不静默覆盖。",
      "Patch 后重新按目标类型 Schema 校验，失败则整条 Patch 回滚。",
      "所有定义注册后才执行 Patch；注册表此时仍未冻结。"
    ],
    l2: {
      "_apply_patch(entry)": [
        "先校验 target 存在、requires 版本匹配，并在工作副本上逐条执行操作。",
        "`/id` 及 `/id/*` 被禁止；操作失败、ID 改变或 Schema 失败都放弃整条 Patch。",
        "成功时同步更新 name/desc/tags/information/raw/data，保留来源模组并追加 patched_by；Patch 后的资源引用重新校验。"
      ],
      "_validate_definition_assets(default_mod_id, raw_definition, reporting_mod_id, file, pointer)": [
        "裸资源键按定义来源模组解析；完整 asset://<mod>/<key> 可显式引用已加载模组资源。",
        "资源必须出现在目标模组 manifest.assets；错误带定义内 /information/texture 或 /information/model 指针。"
      ]
    }
  },

  "framework/modding/schema_validator.gd": {
    role: "项目自带的 JSON Schema 子集校验器，支持本地与同目录文件 `$ref`。",
    contracts: [
      "支持 type/properties/required/additionalProperties/patternProperties、数组/字符串/数字约束、组合器与 `$ref`。",
      "不支持远程 HTTP ref、if/then/else、dependencies、contains、format 断言。",
      "错误统一为 `{path, keyword, message}`；最多 200 条，嵌套深度上限 64。",
      "Schema 文件必须位于 `res://schemas/` 或被其相对引用，加载结果按路径缓存。"
    ],
    l2: {
      "_validate(value, schema, pointer, context)": [
        "先处理 `$ref` 并切换 root/base_dir；同一 schema 的递归结构依赖深度上限防环。",
        "组合器使用临时错误缓冲区：anyOf/oneOf/not 的成功分支不会污染最终错误。",
        "错误路径使用 JSON Pointer 转义，直接对应内容文件中的位置。"
      ]
    }
  },

  "framework/modding/cross_reference_validator.gd": {
    role: "Schema 之后的语义校验：材料、构筑、委托奖励、事件条件/效果、港口市场与地图配置的引用完整性。",
    contracts: [
      "所有可引用 ID 必须在已注册定义中存在；未知条件/效果操作码直接报错。",
      "主线序列必须覆盖 1–5；普通委托至少一个模板；最终委托应同时包含货物与旅客。",
      "港口原型必须提供 exchange 与 contracts；市场引用商品/材料必须存在。",
      "地图配置的港口数、名称键数量、必需设施标签与默认构筑均被检查。"
    ]
  },

  "framework/modding/core_completeness_checker.gd": {
    role: "检查官方 core 包是否提供 MVP 所需的最少内容与构筑。",
    contracts: [
      "要求 core 存在、required=true 且进入加载顺序。",
      "最低数量：3 船体、2 锅炉、3 策略、4 港口原型、5 主线、2 事件、2 岗位等。",
      "要求存在 `strategy.economy/standard/fast`、大型船体、工程师/领航员与风险事件标签。",
      "至少一套初始构筑可解析为 hull + boiler + cargo。"
    ]
  },

  "framework/modding/content_types.gd": {
    role: "内容类型常量、Schema 路径、单数类型名与模块类型集合；由 tools/gen_content_types.mjs 从 content_types.json 生成。",
    contracts: [
      "禁止手改；修改 `content_types.json` 后运行 `node tools/gen_content_types.mjs`。",
      "`content_type` 决定注册表与 Schema；`all()` 不包含 patches，patches 由 ContentCompiler 单独收集。",
      "`MODULE_TYPES` 由 manifest 的 `module: true` 派生；单数类型用于 `<mod>:<type>/<id>` 的 ID 校验。"
    ]
  },

  "framework/modding/zip_mod_source.gd": {
    role: "未挂载前通过 ZIPReader 读取包内文件，并提供挂载后的 `res://mods/<id>/` 资源前缀。",
    contracts: [
      "构造时推断唯一 manifest 前缀；路径不合规时写入 `error`，扫描器据此拒绝。",
      "内容读取使用 `mods/<id>/...` 前缀；资源前缀为挂载后的 `res://mods/<id>/`。",
      "挂载 ZIP 后即可用 FileAccess 访问资源路径；ZIPReader 可在编译结束后关闭。"
    ]
  },

  "framework/modding/registries/content_definition.gd": {
    role: "单条内容定义的通用 envelope 与只读数据视图，包含运行数据与新版展示资源信息。",
    contracts: [
      "包含 ID、类型、本地化键、标签、enabled、information、data、来源模组/文件与 patch 记录。",
      "`information` 和 `data` 与 `raw` 保持同步；注册表冻结后按约定禁止修改。",
      "`to_raw()` 返回深拷贝，供 Patch 与二次 Schema 校验使用。",
      "`asset_uri(field)` 保留完整 asset:// URI；裸键自动补成 asset://<source_mod>/<key>。"
    ],
    l2: {
      "from_raw(raw_definition, type, mod_id, file)": [
        "深拷贝 information/data，缺失 information 归一化为空字典且不向序列化结果添加空对象。"
      ],
      "asset_uri(field)": [
        "空字段返回空字符串，完整逻辑 URI 原样返回，裸资源键使用定义来源模组作为命名空间。"
      ]
    }
  },

  "framework/modding/registries/definition_registry.gd": {
    role: "按内容类型保存定义，支持 ID/标签查询与冻结。",
    contracts: [
      "重复 ID 返回 `duplicate_id`，不覆盖。",
      "冻结后注册返回 `registry_frozen`。",
      "提供 contains/get_by_id/get_all/query/source_of/size/ids。"
    ]
  },

  "framework/application/command_bus.gd": {
    role: "命令执行器：在 GameState 深拷贝上运行用例，成功才提交并发布领域事件。",
    contracts: [
      "处理器签名 `(params: Dictionary, context) -> Result envelope`。",
      "失败时丢弃工作副本，原始 GameState 与哈希保持不变。",
      "提交后按顺序发布 `{type, payload}` 事件；结果可请求自动存档。",
      "保留最近 200 条执行日志（命令、成功、错误码、耗时）。"
    ],
    l2: {
      "execute(command_name, params)": [
        "克隆 `context.state` 并临时替换，处理器对工作副本的修改不会泄漏到事务外。",
        "成功时用 `replace_with()` 写回原对象，保持外部引用有效；随后发布事件并可选 autosave。",
        "未知命令、无 context、非法返回值都转换为统一 Result.fail。"
      ]
    }
  },

  "framework/application/query_bus.gd": {
    role: "只读查询执行器：给处理器临时克隆的 GameState，返回 ViewModel。",
    contracts: [
      "查询失败返回结构化 Result，不用 null 混淆“无数据”和“错误”。",
      "处理器返回普通 Dictionary；若没有 `ok` 字段则自动包装为成功。",
      "查询不得依赖副作用；克隆是隔离意外写入的兜底。"
    ]
  },

  "framework/application/domain_event_bus.gd": {
    role: "已提交领域事件的 envelope、历史与订阅信号。",
    contracts: [
      "事件 envelope 包含 event_id/event_type/game_time/source/payload/schema_version。",
      "只发布已提交事实；历史最多 500 条，按需截取。",
      "订阅者用于 UI 刷新/表现，不承担规则计算。"
    ]
  },

  "framework/application/commands/ship_commands.gd": {
    role: "船厂用例：购买/仓库/随船运输三种来源安装模块（含替换）、卸下模块、打造模块，并在安装成功后检查通关。",
    contracts: [
      "必须在有 shipyard 设施的港口且处于港口状态；仓库命令则只要求停靠任意港口。",
      "source ∈ {purchase, warehouse, transit}：purchase 扣 purchase_price；warehouse/transit 为免费旧件重装。",
      "槽位/重量/货币/声誉/合同解锁失败原因由 `ShipOps.install_blockers()` 统一生成，避免 UI 与命令漂移。",
      "单槽模块（船体/锅炉/导航/安全/客舱）自动替换，旧件写入当前港仓库；货舱槽满时需 replace_module_id。",
      "购买船体替换后耐久为新上限；warehouse/transit 船体替换取 min(当前耐久, 新上限)。",
      "安装/卸下同一步维护 `ship.module_instances`：单槽替换用 `ShipModules.install_slot()` 生成全新实例（满状态、新 id），货舱追加用 `append_cargo()`、按位置删除用 `remove_cargo()`，避免旧条件串到新模块。",
      "`ship.uninstall_module` 只允许卸下导航/安全/客舱/货舱，船体与锅炉返回 required_module。",
      "`ship.craft_module` 复用 CraftOps：仓库材料优先、再扣船上普通货物，扣 craft_cost 后生成打造订单（不再即时推进时间/入库），发布事件 ship.craft_ordered；成品等 ready_at 后由 CraftOps.settle_orders 写入下单港仓库。",
      "install 成功后调用 `VictoryService.check()`，结果放入 data.victory，新通关时追加 run.victory_achieved 事件。",
      "所有修改在命令事务内完成，失败自动回滚。"
    ],
    l2: {
      "install_module(params, context)": [
        "先由 install_blockers 生成完整 blocker 列表；失败时返回第一个 blocker 作为 error_code。",
        "替换逻辑只移除当前槽位的旧模块（货舱按 replace_module_id），旧件进当前港仓库后再装新件。",
        "购买价与打造费通过 `state.record_expense()` 计入统计支出。"
      ],
      "uninstall_module(params, context)": [
        "从船只配置移除模块并写入当前港仓库；船体/锅炉由 uninstall_blockers 拒绝。"
      ],
      "craft_module(params, context)": [
        "CraftOps.craft 返回材料来源明细（warehouse/cargo）、order_id/ready_at/remaining_hours 与当前订单列表；命令层只负责设施检查、事件与结果包装。"
      ]
    }
  },

  "framework/application/commands/port_commands.gd": {
    role: "港口停留用例：在本港消耗时间，让打造订单、NPC 市场与债务期限一起推进。",
    contracts: [
      "`port.wait` 参数 hours ∈ [1,240]（否则 invalid_hours），必须在停靠状态（否则 not_at_port）且已开局（否则 no_run）。",
      "顺序固定：advance_time → CraftOps.settle_orders → NpcTraderSimulator.advance → DebtService.check_overdue → push_notice(ui.notice.waited)。",
      "data 返回 hours/game_time/time_label/completed_orders/npc_events/debt_events；事件为 port.waited + 每个完成订单的 ship.module_crafted（外加 NPC 市场/债务事件）。",
      "全部修改在命令事务内完成，失败自动回滚；WAIT_OPTIONS=[6,12,24] 由船厂 ViewModel 暴露给 UI。"
    ]
  },

  "framework/application/queries/port_view.gd": {
    role: "主界面 ViewModel：当前港、市场、目的地、船只、委托、策略、情报、通知、统计与通关状态。",
    contracts: [
      "所有数值只读复制；市场行同时给出库存、单价、持有、可售、buyable、持仓均价与价格历史。",
      "市场行的 recent_prices 与 trend_percent 只来自真实 price_history；样本不足时 sparkline 不绘制折线。",
      "目的地只列当前港的相邻航线，标记未知设施与风险。",
      "委托 ViewModel 提供目的港名称键、剩余期限、预计航程、风险和说明键；风险/航程由查询层计算，卡片不调用航行公式。",
      "委托区额外暴露 active_limit/active_count/normal_holds（普通委托持有上限）与 main_chain_complete（主线全完成）。",
      "船只 ViewModel 的 cargo_cost_basis 与 average_cost 来自 ShipOps 的成本口径；额外暴露 transit_modules/transit_weight。",
      "顶层 victory 字段给出 achieved/achieved_at 与 conditions（VictoryService.conditions），供总览目标、通关清单与通关页判断。",
      "委托区给出 main_done/main_total（主线完成度），总览据此提示「主线完成后如何通关」。",
      "船只 ViewModel 额外给出 free_weight 与 free_cargo_capacity（剩余载重/剩余货舱），顶部信息条直接显示，避免只显示已用载重。",
      "船只 ViewModel 给出模块实例摘要 worst_module_condition / damaged_modules / disabled_modules / module_damage_points，顶部信息条据此显示「部件 N · NN%」，健康时不占位。",
      "stats 来自 GameState.stats()（收入/支出/利润惰性初始化），不返回 ContentDefinition 或 GameState 内部引用。"
    ]
  },

  "framework/application/queries/intel_view.gd": {
    role: "情报独立界面 ViewModel：快照时间/年龄、商品 × 港口对比矩阵（含未探索港口列）与 NPC 预计动向。",
    contracts: [
      "矩阵 columns 顺序 = 当前港 → 已发现港 → 未发现港（各按 port_id 升序）；未发现港整列保留：name_key=ui.label.unknown_port、masked=true，单元格 known=false。",
      "rows 为商品全集（当前港实时普通商品 ∪ 快照普通商品，按 item_id 升序），cells 与 columns 同序等长；行含 item_id/name_key/unit_weight/ref_price。",
      "价格口径与 MarketOps 一致：buy_price=floor(price*DEFAULT_TRADE_MARGIN)（港口收购价/玩家卖出），sell_price=round(price) 仅 buyable 否则 -1（港口出售价/玩家买入）；-1 由 UI 显示为 `-`，known=false 显示 `？`。",
      "当前港列读实时市场（age_hours=0），其它港只读快照并给出 age_hours（快照未覆盖 = -1）。",
      "旧字段 ports/npcs/has_report 保留；has_report=false 时仍返回可用矩阵（当前港实时列有价，其余 `？`）。",
      "快照 market 行新增 trend_percent（见 intel_service）；每个市场行附带 item_name_key，NPC 行附带货物名和动作本地化键。",
      "`can_refresh` 由当前港情报站、港口状态和金币共同决定。"
    ]
  },

  "framework/application/queries/shipyard_view.gd": {
    role: "船厂独立界面 ViewModel：当前/随船运输模块、已装模块效果、港口仓库、打造配方与所有可购买模块的限制原因。",
    contracts: [
      "与 `ship.install_module` / `ship.uninstall_module` / `ship.craft_module` 共用 ShipOps/CraftOps 的规则函数，UI 不复制规则。",
      "`ship.modules[]` 每行含 `effect`：模块 `data` 的深拷贝（模块缺失时 `{}`），供船厂页渲染效果行与槽位卡；can_uninstall/uninstall_blockers/weight/tier 仍由本查询给出。",
      "`ship.modules[]` 同时给出模块实例的 `slot/index/condition/disabled`；`ship.worst_module_condition`、`ship.disabled_modules`、`ship.module_damage_points` 供界面显示与维修预览。",
      "`ship.hull_model_key` 取船体定义的 `information.model`，`ship.hull_model_path` 通过 `context.assets` 解析成物理路径（松散模组或挂载 zip 内均可），供 3D 船厂舞台加载内容模组的原始 GLB。",
      "`candidates[].blockers` 给出全部失败码；`can_install` 为 false 时 UI 禁用按钮。",
      "已安装模块标记 installed；will_replace 返回会被移入当前港仓库的旧模块 ID（空串=无替换）。",
      "`unlock_template_id` 给出合同解锁来源（用于 UI 文案），实际锁定判断在 ShipOps.locked_by_contract。",
      "`craft` 行给出材料 plan（仓库/船上/合计/是否足够）、craft_cost、craft_time_hours、money_only（materials 为空且 craft_cost>0）与 blockers。",
      "顶层 `orders` 列出全部未完成打造订单（含 port_id/port_name_key/remaining_hours/at_current_port，最旧在前）；`wait_options` = [6,12,24] 小时，供船厂页在港等待按钮使用。",
      "`warehouse` 给出当前港仓库的模块与材料；`ship.transit_modules/transit_weight` 给出随船运输模块。",
      "没有存档时也返回完整空结构（warehouse/craft/orders 均为空数组），避免 UI 空引用。",
      "查询在只读克隆上调用 CraftOps.ensure_orders，不会写回真实存档。"
    ],
    l2: {
      "_craft_rows(hub, state, at_port, has_shipyard)": [
        "只为 CraftOps.craftable 的模块生成配方行，非造船厂港口前置 no_shipyard blocker。",
        "material_plan 的 owned = 当前港仓库 + 船上非委托货物，打造消耗顺序与之一致。"
      ]
    }
  },

  "framework/application/queries/supply_view.gd": {
    role: "补给界面 ViewModel：煤水价/库存、载重余量、可补上限、预计续航与维修报价。",
    contracts: [
      "煤水单价与港口库存来自 `MarketOps.supply_entry_for()`，不再使用固定价格。",
      "可买上限同时受 capacity（= max_weight − 非补给重量 − 另一项补给重量，按单位重量取整）、金币和港口库存限制，因此买一种补给只会压低另一种的上限，不会让比例条上涨。",
      "`coal_view`/`water_view` 额外给出 capacity/baseline_capacity/cap_loss/headroom/maximum_baseline；cap_loss 供 UI 绘制右端反向损失带，maximum=max(current, capacity) 为当前可达物理上限。",
      "fill_to、safe_level、estimated_days、fill_cost、blocker 代码与顶层 max_coal/max_water 语义保持兼容。",
      "维修报价与 supply.repair 共用 `MarketOps.repair_cost()`，UI 不复制耐久/改装修正。",
      "当前港没有 supply 设施时 has_supply=false，界面禁用补给与维修。"
    ]
  },

  "framework/application/queries/port_memory_view.gd": {
    role: "点击已访问港口时的只读市场记忆 ViewModel：上次在港的价格、储备与可买标记。",
    contracts: [
      "数据来自 `MarketMemoryService`，不是实时市场；时间流逝不会自动刷新。",
      "包含港口名、上次到港时间/年龄、设施与全部普通商品行。",
      "未访问港口或旧存档缺少快照时返回 has_memory=false，不伪造价格。"
    ]
  },

  "framework/domain/voyage/voyage_service.gd": {
    role: "航行执行：校验预览、扣补给/工资、抽取事件、事件选择、抵达结算与失败回滚。",
    dependencies: ["VoyageCalculator", "ShipOps", "MapOps", "ConditionEvaluator", "EffectExecutor", "ContractOps", "NpcTraderSimulator", "DebtService", "SaveService"],
    contracts: [
      "出航前把当前状态存入 `context.pre_voyage_state` 和 `pre_voyage` 存档槽。",
      "风险事件概率对玩家隐藏；预览只暴露风险来源。事件最多提供 2 个加权抽样选项。",
      "耐久归零或 `fail_voyage` 效果会把工作副本替换回出航前快照，并发布 voyage.failed。",
      "抵达时统一推进时间、发现港口、结算打造订单（CraftOps.settle_orders，成品进下单港仓库并写入 summary.completed_orders）、结算主线/普通委托、推进 NPC、检查逾期、刷新普通委托池并自动存档。",
      "工资通过 `state.record_expense()` 计入统计支出；委托收入在 ContractOps 结算时计入收入。",
      "行动顺序固定：扣费/补给 → 生成 voyage → 选事件 → 若无事件立即抵达。"
    ],
    l2: {
      "start(context, destination_id, strategy_id)": [
        "先调用 VoyageCalculator 生成可复现预览；feasible=false 时不修改状态。",
        "工资、煤、水全部扣除后写入 `voyage` 快照；事件基础延误已计入 arrival_time。",
        "事件选项仅保存 ID；选择时重新从注册表读取效果，避免存档注入效果对象。"
      ],
      "choose_option(context, option_id)": [
        "再次校验选项在本次抽样池中且条件成立，然后顺序执行效果。",
        "effect flags.voyage_failed 为真时恢复出航前状态，返回 ok + failed，以便 UI 展示而非命令错误。",
        "成功后调用 `_complete_arrival()`；autosave 只在成功抵达后发生。"
      ],
      "_complete_arrival(context)": [
        "以 arrival_time 推进游戏时间并标记目的港 visited/discovered。",
        "主线完成后 next_main_sequence+1，并生成下一段 main_offer；不自动接取。",
        "普通 active 委托中目的港匹配者一起结算；其余保留。",
        "调用 `ContractOps.refresh_normal_offers()` 整池刷新普通委托（键含港口/抵达时间/航次），summary.offers_refreshed=true 并发布 contract.offers_refreshed。",
        "NPC 市场推进、债务逾期、统计与通知都在此统一处理。"
      ]
    }
  },

  "framework/domain/voyage/voyage_calculator.gd": {
    role: "纯计算航行预览：速度、耗时、煤水、准点、风险来源与可行性阻断。",
    contracts: [
      "有效航速 = 船体基础 × 锅炉系数 × 策略 × 重量系数 × 导航/岗位修正。",
      "重量系数在 50% 载重内为 1.0，100% 为 0.65，超载继续线性下降并触发阻断。",
      "煤/水需求基于耗时与单位时间消耗；旅客额外耗水。",
      "预览返回 risk_score（内部）与 risk_sources（公开），不返回事故概率。",
      "工资不足、补给不足、超重、无耐久都会进入 blockers。"
    ],
    l2: {
      "preview(context, destination_id, strategy_id)": [
        "读取 strategy ContentDefinition，缺失或船只无效直接返回 Result.fail。",
        "主线目的港匹配时附加 deadline/on_time/revenue_estimate。",
        "所有计算只读；查询总线会额外克隆状态，保证无副作用。"
      ],
      "weight_speed_factor(load_ratio)": [
        "分段线性且连续：≤0.5 → 1.0；0.5–1.0 线性降至 0.65；>1.0 继续下降，最低 0.45。"
      ]
    }
  },

  "framework/domain/ship/ship_ops.gd": {
    role: "船只组合的纯函数：模块/货物/煤水/旅客/随船运输重量、容量、槽位、安装/卸下规则与派生属性。",
    contracts: [
      "总重量包含已装模块、随船运输模块（transit）、货物、煤、水、旅客；合同货箱同样计入。",
      "随船运输模块计入总重量但不占货舱容量；仓库中的模块不随船。",
      "货舱容量是重量容量；合同货物不可出售/抛弃。",
      "每个 cargo stack 保存 total_cost；买入累加，卖出/抛弃按数量比例扣减。",
      "`cargo_total_cost()` 与 `cargo_average_cost()` 是 UI 显示库存成本的唯一口径。",
      "派生属性计算船体基础、锅炉、导航、安全、模块 modifiers 与岗位 modifiers。",
      "`validate_configuration()` 检查必需船体/锅炉、货舱/客舱槽位与耐久上限。",
      "`module_damage_points(hub, ship)` 按「模块重量 × 缺失耐久比例」把部件损耗换算成维修点数；`has_disabled_module()` 判断是否存在 0 状态的模块实例。模块性能影响留到战斗阶段。",
      "`install_blockers(hub,state,module_id,source,replace_module_id)` 是 ship.install_module 与船厂 ViewModel 共用的校验源：来源库存、合同解锁、声誉、货币、槽位与最终配置重量差量。",
      "合同解锁：模块出现在任一 contract.rewards.unlock_ids 且不在 player.unlocks 时返回 locked_by_contract；unlock_contract_id 给出解锁它的合同模板。",
      "单槽模块自动替换（不再返回 slot_occupied）；货舱槽满且未指定 replace_module_id 时返回 cargo_slots_full；同 ID 货舱在有空槽时允许重复购买。",
      "`uninstall_blockers()` 只允许卸下货舱/导航/安全/客舱，船体与锅炉返回 required_module。"
    ],
    l2: {
      "stats(hub, ship)": [
        "先取 hull.base_speed * boiler.speed_mul，再乘导航 speed_mul。",
        "风险汇总 hull.base_risk + nav.risk_add + safety.risk_add + 模块/岗位 risk modifiers。",
        "员工/安全设备的 damage/repair 修正以乘算累积；最终 clamp 到合理范围。"
      ],
      "install_blockers(...)": [
        "重量按最终配置计算：current_weight + 新件 - 被替换旧件 - transit 来源已在船上的重量。",
        "单槽替换的 replaced_weight 取自当前槽位；船体替换同时把 max_weight 切换为新船体上限并校验货舱/客舱槽位。"
      ]
    }
  },

  "framework/domain/ship/ship_modules.gd": {
    role: "船舶模块实例层：为每个已装模块维护稳定 instance_id 与 0..1 condition，对齐扁平槽位键，并作为损伤/维修/存档的唯一写入口。",
    contracts: [
      "`ship.module_instances` 存单槽（boiler/navigation/safety/cabin）实例与有序 cargo 实例数组；`ship.module_serial` 是实例编号计数器；condition 0 表示失效。",
      "扁平槽位键（boiler_id 等）仍是「装了哪个定义」的权威投影；实例层只拥有身份与状态。统一 Module 迁移后再把 definition_id 移入实例。",
      "`ensure()` 只增补/裁剪到与扁平键一致，保留已有 condition 与 id；新实例按槽位顺序分配 module_N，满状态。",
      "写入点只有 install_slot/append_cargo/remove_cargo/remove_slot/damage/repair_all；读接口在旧船上按满状态兜底，不抛异常。",
      "`installed_rows()` 是维修、UI 与未来战斗定位的统一行视图（slot/index/module_id/instance_id/condition/disabled）。"
    ],
    l2: {
      "ensure(ship)": [
        "先清掉扁平键已空的单槽实例，再为缺失槽位创建新实例；货舱按扁平列表长度逐位复用既有实例，不足的补满状态新实例。",
        "幂等：布局不变时 serial、instance_id 与 condition 都不变，因此存档哈希稳定。"
      ],
      "damage(ship, slot, index, amount)": [
        "只在 has_slot 为真时生效；结果 clamp 到 [0,1]，newly_disabled 只在跨越 0 的那一次为真。",
        "返回 instance_id 供领域事件引用具体实例。"
      ]
    }
  },

  "framework/domain/economy/market_ops.gd": {
    role: "市场价格、买卖、补给商品与维修结算；煤/水价格随港口库存浮动。",
    contracts: [
      "本地品种价格 = base_price × bias × (base_stock / stock)^elasticity，限制在 0.55–2.2。",
      "非本地品种以 `buyable=false` 进入市场：只收购、不卖给你；价格按 base_price × 0.9 × 库存折减。",
      "煤/水以 `is_supply=true` 的补给商品进入每个港口市场，初始库存 90–180，价格与普通商品同一供需公式。",
      "买入检查 buyable、货币、库存、总重量与货舱容量；卖出允许所有非合同货物；补给商品只能走补给码头。",
      "玩家买卖只把价格向新均衡推进 `player_trade_impact`（默认 0.35）；NPC 交易仍完整重算。",
      "每个可买入市场条目维护最多 8 个真实价格样本 `price_history`；非本地收购项不写历史，避免伪造趋势。",
      "买入把成交总额写入 cargo stack 的 total_cost，卖出按数量比例扣减成本。",
      "补给只检查设施、库存、重量与货币；维修费用乘安全设备/工程师的 repair_cost 修正。",
      "维修报价 = (船体缺失点数 + `ShipOps.module_damage_points()` 部件损耗点数) × repair_per_point × repair_cost_mul；`repair()` 同时把船体耐久与所有模块实例恢复到满状态，返回 modules_repaired。",
      "成功的买入/补给/维修调用 `state.record_expense()`，卖出调用 `record_income()`，形成通关总结的收入/支出/利润口径。",
      "`ensure_sell_only_entries()` 为旧存档补齐非本地收购项与补给商品。"
    ],
    l2: {
      "buy(state, hub, port_id, item_id, amount, trade_margin, price_impact)": [
        "所有前置条件通过后才扣款、减库存、按 price_impact 平滑重算价格、写入 cargo stack 和成本。",
        "失败返回带 message_key 的 Result；命令总线因此不会提交工作副本。"
      ],
      "buy_supply(state, hub, port_id, kind, amount, price_impact)": [
        "按 `supply_entry_for()` 找到煤/水市场条目，使用当前价格和库存；购买后按玩家冲击平滑更新价格。"
      ],
      "compute_price(entry)": [
        "buyable=true 走本地市场供需公式；buyable=false 使用单向收购价，库存越多价格越低。"
      ],
      "repair_cost(hub, state, repair_per_point)": [
        "返回缺失耐久、费用、耐久上限与维修修正；supply.view 和 supply.repair 共用。"
      ]
    }
  },

  "framework/domain/economy/market_memory_service.gd": {
    role: "每港“上次在港时”的市场快照：价格、储备、可买标记与时间戳。",
    contracts: [
      "只在开局、抵达港口、在该港完成买卖时刷新；时间流逝和 NPC 变化不会改写快照。",
      "与情报快照互相独立：情报可远程刷新，港口记忆只记录亲历市场。",
      "快照包含普通商品与补给商品（煤/水），并记录 is_supply 标记。",
      "快照存放在 GameState.port_memory，使用普通 Dictionary，可直接存档。"
    ]
  },

  "framework/domain/economy/npc_trader_simulator.gd": {
    role: "后台 NPC 商船：在港口间运输/采购商品，推动库存与价格。",
    contracts: [
      "NPC 不显示为海上实体，只保存当前位置、目的地、货类、数量、动作与 ETA。",
      "抵达时 deliver 增加库存、buy 减少库存，随后重算价格并重新分配路线。",
      "NPC 只在 `buyable=true` 的本地商品中选货，不会为仅收购港口创造买侧市场。",
      "单次推进每个 NPC 最多追赶 4 个周期，避免长时间跳跃导致无限循环。",
      "随机流按 NPC ID 分离；市场事件返回 `{type:\"market.changed\"}`。"
    ]
  },

  "framework/domain/economy/intel_service.gd": {
    role: "生成不可变的市场/NPC 情报快照，并保留生成时间。",
    contracts: [
      "只覆盖已发现港口；NPC 只显示大致 ETA 区间，不暴露精确抵达时刻。",
      "快照不会自动更新；刷新由 `intel.refresh` 命令显式触发。",
      "趋势由库存相对 base_stock 判断：up/down/stable；快照 market 行另给 trend_percent（最近 8 条 price_history 首尾变化率，样本不足或非 buyable 恒 0.0），供对比表显示红降/绿升数字。"
    ]
  },

  "framework/domain/map/map_generator.gd": {
    role: "程序生成 4–5 港口连通分支网络，并验证 MVP 硬约束。",
    contracts: [
      "先建随机生成树，再补边直到目标边数；要求存在环（非纯链）且起点度数 ≥2。",
      "必需设施标签（造船厂/情报站）必须在起点 max_edges 内；否则重试最多 60 次。",
      "起始煤水必须能抵达至少一个相邻港口，否则重试。",
      "所有随机来自 `map_generation` 命名流；不使用全局 randf/shuffle。"
    ],
    l2: {
      "_try_generate(profile, profile_data, hub, rng, ship, attempt)": [
        "港口数与边数从 profile 范围抽样；起点原型按 start_archetype_tags 选择。",
        "先分配起点，再为每个必需设施标签选择最近未分配节点；剩余节点随机补原型。",
        "最后校验连通性、分支、必需设施距离与起始补给可达性，任一失败返回重试。"
      ]
    }
  },

  "framework/domain/map/map_ops.gd": {
    role: "GameState.world 上的港口/航线查询、设施可见性、发现与 BFS。",
    contracts: [
      "航线按无向边存储，`route_between()` 双向匹配。",
      "`facilities_known` = 已访问 OR 导航设备揭示 OR 港口自身标记。",
      "`discover()` 同时更新港口布尔与 discovered_ports 数组。",
      "BFS 用于委托目的地与地图约束检查。"
    ]
  },

  "framework/domain/contracts/contract_ops.gd": {
    role: "委托实例生成、装载、交付结算、接取规则、普通委托池生成与抵达刷新。",
    contracts: [
      "实例 ID 由模板 ID + 单调 serial 构成；奖励数额在生成时锁定。",
      "货物载荷必须声明 cargo_item_id；载重与旅客数来自 payload 范围。",
      "装载前检查客舱容量、总重量与货舱容量；合同货物以 contract_id 绑定到实例。",
      "交付时按准时、伤病赔偿、奖金、声誉与解锁结算；收入优先偿还债务，并记录 gross payout 为统计收入。",
      "主线 offer 与普通 offer 分开存储；主线同时只能有一个 active。",
      "普通委托持有上限 `active_limit = max(1, 1 + reputation/2)`；主线槽位不计入。",
      "`generate_normal_offers()` 从 normal 模板加权抽 3 个实例；`refresh_normal_offers()` 在每次抵达时以 <port>:<arrival>:<voyages> 为命名流键整池刷新，不动主线状态。"
    ],
    l2: {
      "create_instance(...)": [
        "遍历 payload 汇总 cargo_weight/passengers；期限使用 FormulaRegistry 的安全公式 ID。",
        "奖励使用同一命名随机流抽取范围；所有数据写入纯 Dictionary，便于存档。"
      ],
      "complete(state, hub, instance, arrival_time)": [
        "准时判定 arrival_time <= deadline；伤病每人扣 50 赔偿并降低声誉。",
        "`DebtService.receive_income()` 先还债再把余额入账；`record_income(payout)` 记录毛收入；解锁 ID 写入 player.unlocks。",
        "交付后移除对应 contract_id 的货物；实例标记 completed。"
      ],
      "generate_normal_offers(state, hub, rng_service, key)": [
        "候选按模板权重抽样，最多生成 3 个实例；随机流为 STREAM_CONTRACT_GENERATION 的 `normal_offers::<key>`。",
        "初始池键为 `initial:<port>`；抵达刷新键包含港口、到达时间与航次数，保证同 seed+命令序列可复现。"
      ]
    }
  },

  "framework/domain/contracts/run_factory.gd": {
    role: "新局工厂：选构筑/地图配置、生成船只与市场、NPC、仓库/运输/统计/通关结构、初始主线与普通委托。",
    contracts: [
      "框架不引用具体 core ID：默认构筑/地图配置取该类型第一个注册定义。",
      "创建顺序：船 → 地图 → 玩家/状态 → 仓库/运输/统计/通关字段 → 市场 → NPC → 主线 1 → 普通 offer。",
      "状态写入后调用 `GameState.ensure_campaign()` 建立 campaign 分区，并把 `campaign.world.generated` 置为 true、起始港记入 `visited_port_ids`。",
      "主线 1 自动装载并接取；后续主线由 VoyageService 生成 offer。",
      "普通委托初始池与抵达刷新共用 ContractOps.generate_normal_offers，初始键为 `initial:<port>`。",
      "生成失败返回结构化 Result，不写入 AppContext。"
    ],
    l2: {
      "create_run(context, build_id, requested_seed)": [
        "本地 RngService 由 seed 派生，成功后才由 run.start 写回 context，失败不污染现有随机流。",
        "地图生成依赖初始船只属性（起始补给可达性检查）。",
        "调用 WarehouseOps.ensure_structure 初始化每港仓库与 ship.transit_modules；写入 stats 默认值与 victory=null。",
        "初始债务按 build.loan 写入 player.debt，之后由收入自动偿还。",
        "`create_ship()` 在返回前调用 `ShipModules.ensure()`：按槽位顺序分配 module_1..N 实例 id 与满状态 condition，保证同 seed 同构筑的存档哈希一致。",
        "战役分区（world/codex/factions）通过 `ensure_campaign_sections` 惰性补齐，探索进度只追加 id。"
      ]
    }
  },

  "framework/domain/contracts/formula_registry.gd": {
    role: "框架拥有的安全期限公式注册表，供委托数据引用。",
    contracts: [
      "内容只能引用 ID，不能提供表达式源码。",
      "公式参数：distance / cargo_weight / passengers；返回小时数，未知 ID 返回 -1。",
      "默认公式覆盖 tutorial_first/trade/craft、passenger、finale 与 normal 两类。"
    ]
  },

  "framework/domain/events/effect_op_registry.gd": {
    role: "白名单效果操作码及其纯实现（货币、补给、货物、船只与模块、委托、情报、通知）。",
    contracts: [
      "每个 handler 接收 `(node, execution_context)`，返回 `{ok,error_code,message_key}`。",
      "失败表示整个命令事务回滚；效果按数组顺序执行。",
      "`damage_ship` 应用安全设备 damage_mul；耐久归零设置 voyage_failed。",
      "`damage_module` 按 `slot`（boiler/navigation/safety/cabin/cargo）+ 可选 `index` 扣减模块实例 condition，发布 ship.module_damaged；hull 不是模块槽位，非法槽位返回 unknown_module_slot。",
      "`update_intelligence` 生成并存储快照；`emit_notice` 写入 GameState 通知。",
      "未知操作码永远不会执行。"
    ]
  },

  "framework/domain/events/condition_op_registry.gd": {
    role: "白名单条件操作码及其只读判定实现。",
    contracts: [
      "覆盖货币、声誉、债务、港口标签、货物/模块/岗位、完成契约、发现、船体 tier 与耐久。",
      "handler 只读 state/registries，不得产生副作用。",
      "未知操作码由 ConditionEvaluator 报错，不默认放行。"
    ]
  },

  "framework/domain/events/condition_evaluator.gd": {
    role: "解析 all/any/not 组合器并调用条件操作码，限制条件节点数。",
    contracts: [
      "单次求值最多 16 个节点；超限返回结构化错误。",
      "组合器短路：all 遇 false、any 遇 true 立即返回。",
      "空条件视为 true；非对象条件报错。"
    ]
  },

  "framework/domain/events/effect_executor.gd": {
    role: "顺序执行效果列表，失败即中止并返回带索引的错误。",
    contracts: [
      "单次最多 16 个效果；未知/非法效果拒绝。",
      "自身不克隆状态；回滚依赖 CommandBus 的事务副本。",
      "成功返回执行数量、通知列表与 flags。"
    ]
  },

  "framework/domain/debt/debt_service.gd": {
    role: "固定利率贷款：借款、收入优先还款、逾期扣声誉。",
    contracts: [
      "同时只允许一笔贷款；总额 = 本金 × (1+利率)。",
      "`receive_income()` 先抵扣 remaining，余额才进入玩家货币。",
      "逾期检查只触发一次（overdue 标记），剩余债务继续自动偿还。"
    ]
  },

  "framework/services/save_service.gd": {
    role: "JSON 存档槽：模组头、状态、临时文件校验后替换、兼容性检查与旧档迁移入口。",
    contracts: [
      "新存档写 save_schema 2.0、state_schema 2.0 与 content_schema 1.0；写入前克隆状态并补齐 campaign，不修改实时状态。",
      "写入快照与加载结果都会调用 `ShipModules.ensure()` 对齐模块实例表；旧档缺表时按满状态补齐，实例 id 与 condition 随存档往返。",
      "写入 `.tmp` 并重新解析校验；旧文件先改名为 `.bak`，最终替换失败会回滚。",
      "槽位名限制 `^[a-z][a-z0-9_]{1,31}$`；自动存档与出航前快照为独立槽。",
      "缺失存档所需模组拒绝加载；版本/哈希漂移只警告。",
      "加载时统一交给 `SaveMigrations.migrate()`；1.x 归档迁移为 2.0 并回填 campaign 元数据。"
    ],
    l2: {
      "load_slot(slot)": [
        "解析后先迁移 save payload，再校验 state；不支持的 save_schema 返回结构化错误。",
        "返回 GameState、header、meta、migrated 与 migration_warnings；调用方负责模组兼容性校验。"
      ]
    }
  },

  "framework/services/save_migrations.gd": {
    role: "存档 payload 版本迁移：当前 save schema 2.0，支持 1.x → 2.0 并回填持久战役元数据。",
    contracts: [
      "`save_schema` 描述 payload 包装，`state_schema` 描述 GameState 数据；2.0 之前旧档的 content_schema 实际存放 state schema。",
      "1.x → 2.0 只做兼容增量：保留既有 run/world/ship 字段，补 campaign、schema_version、state_schema 与 content_schema。",
      "campaign id 从 seed 确定性生成；created_at 优先沿用 payload/run 时间；playtime 取 game_time。",
      "缺失的 campaign 分区（world/codex/factions）由 `GameState.ensure_campaign_sections` 回填，并逐段写入 warnings。",
      "未知主版本直接拒绝；迁移结果携带 warnings 供 UI/日志显示。"
    ]
  },

  "framework/services/settings_service.gd": {
    role: "持久化 UI 设置：编辑器读 `res://config/config.json`；发布版优先读写 exe 同级 `config/config.json`，不可写时回退 `user://config/config.json`。",
    contracts: [
      "只接受 zh_CN / en 两种语言；非法值回退 zh_CN。",
      "自动存档为布尔值；首次启动会把默认配置写入可用的配置路径。",
      "模板构建优先使用 exe 同级 `config/config.json`；若已存在 `user://config/config.json` 则以用户配置优先。",
      "安装目录不可写时 `save()` 自动切换到 `user://config/config.json`，不丢失本次修改。",
      "保存失败返回结构化 Result，不抛异常；调用方负责提示。",
      "测试可覆盖 user/default 路径，避免污染真实用户配置。"
    ]
  },

  "framework/services/localization_service.gd": {
    role: "合并框架与模组本地化表，提供活动语言回退与缺失检测。",
    contracts: [
      "同名键后加载模组覆盖先加载者，并记录 duplicates 警告。",
      "查询顺序：活动语言 → en → 调用方 fallback → 键名。",
      "CSV 本地化不支持，必须在打包前转换为 JSON。"
    ]
  },

  "framework/services/rng_service.gd": {
    role: "命名随机流：按（种子、流名、上下文）派生独立 RNG。",
    contracts: [
      "流首次访问时创建并缓存；同 key 多次获取共享状态。",
      "新增流/上下文不会改变已有流序列（有测试覆盖）。",
      "提供加权抽样与不重复抽样辅助。"
    ]
  },

  "framework/services/logger.gd": {
    role: "有界结构化日志（DEBUG–FATAL），带模组/文件上下文字段。",
    contracts: [
      "最多保留 1000 条，超出丢弃最旧。",
      "默认 INFO 以上输出到控制台；测试可关闭 echo。",
      "条目包含 seq、UTC 时间、级别、消息与 fields。"
    ]
  },

  "framework/services/asset_service.gd": {
    role: "把 `asset://<mod>/<key>` 解析为已挂载物理路径，缺失时回退占位；并统一加载模组内原始 PNG/GLB 内容资源。",
    contracts: [
      "资源缺失只警告并回退，不导致崩溃或存档损坏。",
      "支持直接传入 `res://` 框架资源路径。",
      "注册发生在编译阶段，解析发生在 mount 之后。",
      "`load_texture()/load_model()`：框架资源走 `ResourceLoader`，模组内原始 `.png/.glb`（挂载包或松散目录）走 `ContentAssetLoader`；失败返回 null，调用方保留 2D 回退。"
    ]
  },

  "framework/services/content_asset_loader.gd": {
    role: "运行时读取模组内容资产：用 `Image.load_from_file` 读原始 PNG、用 `GLTFDocument.append_from_file` 读原始 GLB，并按路径缓存。",
    contracts: [
      "模组是挂载的普通资源包（含原始文件），`ResourceLoader` 无法直接 load 其中的 .png/.glb，因此必须走本项目加载器。",
      "`load_texture(path)` 返回 ImageTexture；`load_scene(path)` 返回 GLTF 场景根；`instantiate_model()` 返回可挂到舞台的副本（缓存节点不被父级占用）。",
      "解析失败按路径记入 failures 缓存，重复调用不反复尝试；`clear_cache()` 在 FrameworkRuntime.shutdown 中调用。",
      "只负责表现资源，不读写 GameState、注册表或存档。"
    ]
  },

  "framework/state/game_state.gd": {
    role: "纯数据运行态：可深克隆、可序列化、可哈希、事务替换，并提供战役元数据与分区（world/codex/factions）、探索进度记录、收入/支出/利润统计与惰性结构修复。",
    contracts: [
      "Schema 2.0 只保存 ID/运行时数值，不保存 ContentDefinition 或 Node；新增 campaign 块承载持久战役身份、生命周期与逐步加入的子分区。",
      "`clone()` 深拷贝，CommandBus 的事务基础。",
      "`hash()` 对规范化 JSON 做 SHA-256；存档往返需一致。",
      "`replace_with()` 原地替换，保持外部引用。",
      "`campaign()/ensure_campaign()` 为旧状态或测试状态补齐 campaign 默认字段；id 从 seed 派生。",
      "`CAMPAIGN_SECTION_DEFAULTS` + `ensure_campaign_sections()` 按系统逐步加入分区：`world`（生成标记与已访问区域/港口/已发现地点 id）、`codex`（发现条目 id）、`factions`（id → 运行态字典）。顶层 `world` 仍是已生成地图布局，`campaign.world` 只记探索进度。",
      "进度写入全部幂等并只追加 id：`mark_region_visited` / `mark_port_visited` / `discover_site` / `discover_codex` 返回是否新增；`set_faction_reputation` 夹取到 [-100,100]。",
      "`stats()/ensure_stats()` 为旧存档与半初始化测试状态惰性补齐 voyages/on_time/accidents/income/expense/profit。",
      "`record_income()` / `record_expense()` 只累加整数并重算 profit=income-expense；贷款本金不计收入。"
    ],
    l2: {
      "hash()": [
        "使用 JsonUtils 的排序键 + 浮点量化表示，避免字典顺序/数字类型差异。",
        "HashingContext SHA-256 输出十六进制；测试用保存/加载对比验证。"
      ],
      "ensure_campaign_sections(campaign, warnings)": [
        "逐分区补默认值；分区或分区字段缺失时复制默认容器（数组/字典深拷贝），并可选记录 `campaign.<section>.<field> backfilled` 警告。",
        "只增补不覆盖：已有进度数组原样保留，重复调用幂等。"
      ],
      "record_income(amount) / record_expense(amount)": [
        "只有 amount>0 才生效；先 ensure_stats 再累加，避免旧存档缺字段。",
        "所有货币变化点（市场、委托、工资、维修、情报、船厂/打造）分别调用且只调用一次，防止重复计账。"
      ]
    }
  },

  "framework/ui/shell/main.gd": {
    role: "可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并把已迁移页面挂载到场景宿主。",
    contracts: [
      "所有数据经 QueryBus 获取，所有修改经 CommandBus；UI 不保存规则状态。",
      "顶部信息条在船只存在受损部件时追加「部件 N · NN%」chip（来自 port.view.ship 的 damaged_modules / worst_module_condition），健康时不占位；chip 颜色在失效时为红。",
      "main.tscn 静态声明背景、菜单遮罩、滚动内容根、页脚、音频与 TransitionLayer；main.gd 通过 @onready 绑定，不再在运行时创建固定外壳。",
      "已迁移页面由 PackedScene 实例化：Shell 负责查询并调用 bind，页面只发 command_requested/navigation_requested/action_requested 意图，不接触 AppContext。",
      "每个功能有独立界面，通过顶部导航切换；面板分别构建完整 ViewModel，不把所有信息挤在同一滚动页。",
      "每轮命令后整页重建；选项/目的地/构筑选择保存在 UI 成员。",
      "每个 PanelContainer 只允许一个 VBoxContainer 内容容器；面板子节点必须经 `_panel_add()` 添加，避免多子节点互相重叠。",
      "海图点击已访问港口：当前港跳转市场，远程港打开只读港口记忆。",
      "海图由独立 map_canvas.tscn 组件承载；Shell 只绑定 ports/routes/labels 并处理 port_clicked。",
      "总览页由独立 overview_screen.tscn 承载；Shell 解析横幅资产、海图标签、委托摘要与通报文本，页面组合港口/目标/船只/快捷操作/财务面板并发出导航、海图点击或命令意图。",
      "启动主菜单使用全屏港口背景；进入游戏后保留顶部导航，并用共享 Theme 的徽标/章节标题/资源条构建信息层级。",
      "总览港口横幅通过 Core manifest 的 `banner.port.*` 资产键与 `banner_asset` 字段解析；无横幅港口退回普通面板。",
      "市场页由独立 market_screen.tscn 承载；Shell 组合 port.view 市场数据与 intel.view 趋势，页面发出 trade.buy/trade.sell 意图。",
      "委托页由独立 contracts_screen.tscn 承载；Shell 补充直达性、解锁名称和已完成名称，页面发出 contract.accept 或 voyage 导航意图。",
      "补给页由独立 supply_screen.tscn 承载；Shell 查询 supply.view、注入本地化回调并统一执行页面发出的 supply.* 命令。",
      "情报页由独立 intel_screen.tscn 承载；Shell 查询 intel.view，页面组合 SNIntelTable 并发出 intel.refresh 意图。",
      "出航页由独立 voyage_screen.tscn 承载；Shell 保存目的港/策略选择并查询 voyage.preview，页面只展示预览并发出 selection_changed 或 voyage.start 意图。",
      "主菜单、新航程、模组列表与设置分别由 menu 目录下四个独立场景承载；Shell 组合启动 ViewModel，并统一处理导航、续玩、诊断、退出、新局与设置持久化意图。",
      "港口记忆、抵达结算、航行中、航行事件与通关总结均由 flow 目录独立场景承载；Shell 负责查询/名称解析与流程控制，场景只展示并发出导航、命令或流程意图。",
      "交易、委托接取和补给购买成功后播放 pickup_gold_00.wav。",
      "无存档时进入主菜单：开始游戏进入新航程配置，加载游戏读取 autosave，模组页只读展示本次加载结果，设置可切换语言与自动存档，退出直接关闭。",
      "设置写入 `user://config/config.json`，默认值来自 `config/config.json`；首次加载会创建用户配置。",
      "右下角固定显示开发团队与游戏版本；版本来自 `application/config/version`。",
      "页面切换使用全屏 TransitionLayer：旧页淡出、重建、新页淡入；数据刷新不播放转场。",
      "新航程主操作使用 `SNPrimaryButton`，返回使用 ghost；章节标题控件只声明语义标签（SNEyebrowLabel/SNTitleLabel/SNDetailLabel）。",
      "加载游戏读取 autosave 并做模组兼容性校验。",
      "根控件加载共享 `steam_navigator_theme.tres`；页面可继续局部覆写，但不再在运行时拼装全局 Theme。",
      "船厂页由独立 shipyard_screen.tscn 承载；Shell 查询 shipyard.view 并补充 `contracts`/`victory`（历史合并字段，当前船厂页不渲染通关清单）、船上材料数量 `ship_amount`、解锁来源 `unlock_name`、替换件名 `replacement_name` 与 `ship.hull_name`；页面发出的 ship/warehouse/port 命令统一交回 Shell。",
      "船厂页正常态三列（已有船舶 / 实机渲染 / 组件分类），点击分类由页面 `set_category()` 进入改装态并渲染所选分类的槽位操作；Shell 只做状态记忆与 ViewModel 组装，不决定布局。",
      "船厂改装态与分类由 Shell 保存：`refit_mode_changed` 写入 `_shipyard_refit`，`refit_category_changed` 写入 `_shipyard_category`（默认 `hulls`）；`_shipyard_model()` 把 `refit` 与 `category` 并入 shipyard.view；整页重建/切页后页面据此恢复纵剖图与选中分类。",
      "委托页显示普通委托持有上限（active_count/active_limit）、每次抵达刷新提示与主线完成状态。",
      "通关页由 victory.view.achieved 触发并优先于普通页面；展示 summary，提供“再来一局”（reset_state → 新航程菜单）与“继续游玩”（仅 UI 会话 dismiss）。",
      "反馈5：顶部信息条固定显示当前港口（在航时显示“在航 → 目的港”）、剩余载重 free_weight/max_weight 与剩余货舱 free_cargo_capacity/cargo_capacity。",
      "反馈6：总览“当前目标”显示通关条件清单（主线 n/5 → 大型船体 → 锅炉 → ≥1 货舱 → 造船厂组装），主线完成后给出下一步提示；数据来自 port.view.victory.conditions 与 contracts.main_done/main_total。船厂页不再重复通关清单，只做组件分类入口。",
      "反馈3：情报页用 SNIntelTable 渲染 intel.view 的 columns/rows 矩阵（含未知港口列），替代旧的逐港商品表格。",
      "反馈4：打造订单与在港等待迁入船厂改装态「杂项」页签：等待按钮按 wait_options 生成 6/12/24 小时 `port.wait`，总览快捷入口同样提供等待按钮；模块类分类内保留「按配方打造」，打造按钮文案带工时。",
      "反馈2：补给卡绑定 SNSupplyCard 时传入 _tr 回调，显示“上限损失/剩余可装”本地化文案。",
      "`_notice_text(notice)` 用 `_format_slots(template)`（`%[sd]` 正则、保序）取槽位：字符串参数先按本地化键解析，再按 push 顺序 `template % args`；槽位数与参数数不符、或 `%d` 槽位对应参数不是 int/float 时原样返回模板而不报格式错误；缺键时返回键名。空模板 / 无参数 / 无槽位直接返回模板本身，「航行记录」由此渲染成句。通知文案本地化由 test_ui_shell 的两个用例守护（真实渲染 + 源码 `push_notice` 键扫描，中英槽位序列保序一致）。"
    ]
  },

  "framework/ui/screens/menu/main_menu_screen.gd": {
    role: "启动主菜单页面场景：展示启动状态与主入口，并把用户操作转成 Shell 意图。",
    dependencies: ["SNBadge", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收状态、本地化和 autosave_available，不访问 AppContext、存档服务或场景树退出 API。",
      "开始、加载、模组、设置、诊断与退出均发出 action_requested(action, params)，由 Shell 执行。",
      "加载按钮的禁用状态只由 autosave_available 决定；页面不自行探测文件。",
      "页面可重复 bind，每次清理旧节点。"
    ]
  },

  "framework/ui/screens/menu/new_game_screen.gd": {
    role: "新航程配置页面场景：选择初始构筑和随机种子，展示启动内容摘要与警告。",
    dependencies: ["SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 builds、selected_build、seed_text、mods、内容计数和 warnings，不访问注册表或命令总线。",
      "构筑与种子是页面局部表单状态；只有点击开始时才通过 start_run 意图一并交给 Shell。",
      "构筑选择变化只更新本页描述，不触发整页重建。",
      "返回只发出 back 意图；run.start 的参数解析与执行仍由 Shell 负责。"
    ]
  },

  "framework/ui/screens/menu/mods_screen.gd": {
    role: "已加载模组列表页面场景：只读展示本次启动实际载入的模组及依赖。",
    dependencies: ["SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 只消费 app.view 的 mods 摘要，不扫描文件系统、不改变加载顺序。",
      "返回与重新扫描分别发出 back/retry 意图，Bootstrap 重试由 Shell 执行。",
      "每个模组显示名称、ID、版本、来源、依赖与 required 标记。"
    ]
  },

  "framework/ui/screens/menu/settings_screen.gd": {
    role: "设置页面场景：展示语言、自动存档与配置位置，并发出设置修改意图。",
    dependencies: ["SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 locale、autosave_enabled 与 show_settings_path，不直接读写 SettingsService。",
      "语言与自动存档操作发出 set_locale/toggle_autosave；Shell 更新运行时上下文并持久化。",
      "设置项标签保留固定字段宽度，横向选项和状态文案禁止智能折成逐字竖排。",
      "返回主菜单只发出 back 意图；配置保存结果由 Shell 状态条反馈。"
    ]
  },

  "framework/ui/screens/port/overview_screen.gd": {
    role: "港口总览页面场景：组合港口横幅、海图、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录。",
    dependencies: ["MapCanvas", "SNResourceMeter", "SNBadge", "SNSectionHeader", "ClockService", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 Shell 组合后的 banner_path、map、current_port、contracts、victory、ship、debt 与 notice_texts，不访问 AppContext、QueryBus、注册表或资产服务。",
      "港口横幅来自内容模组：页面优先用 `ContentAssetLoader.load_texture(banner_path)` 读原始 PNG，`ResourceLoader.exists` 为真时退回 `load()`；两种路径都失败则不渲染横幅。",
      "地图点击只发出 map_port_clicked；功能入口只发出 navigation_requested；等待与借款只发出 command_requested。",
      "航行记录使用 Shell 已安全填充并本地化的 notice_texts，页面不重复解释 GameState 通报参数。",
      "构筑胜利条件直接取 contracts 进度与 victory.conditions 展示，不在页面重新判断通关。",
      "目标清单等密集横向字段保持单行，避免右侧说明被压缩成逐字竖排并撑高卡片。",
      "页面可重复 bind，每次清理旧节点；海图仍由独立 map_canvas.tscn 负责绘制。"
    ]
  },

  "framework/ui/screens/port/shipyard_screen.gd": {
    role: "船厂页两种布局共用一页：正常态为「已有船舶卡片 / 实机渲染舞台 / 组件分类入口」，改装态为「贴图纵剖图 / 所选分类的槽位与操作 / 竖排分类页签（含杂项）」。规则仍来自 `shipyard.view`，页面不写 `GameState`。",
    dependencies: ["SNShipView", "SNPartRow", "SNBadge", "SNButton", "SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "`bind(vm, translate)` 接收 Shell 组合后的 shipyard.view（含 refit/category/ship.hull_name/warehouse/candidates/craft/orders/wait_options），不访问 AppContext、QueryBus、CommandBus 或注册表；可重复 bind，每次 `_clear()` 后重建。",
      "`CATEGORY_ORDER` = 船体/锅炉/货舱/导航/安全/客舱 + `misc`；`MODULE_TYPES` 不含 misc。`set_category` 只接受这七个值，非法值直接 return；切换分类会同时进入改装态并发 `refit_category_changed`。",
      "`_body` 固定三列：正常态 `_ship_list_panel / _render_panel / _components_panel`；改装态 `_section_panel / _operations_panel / _category_tabs_panel`。`_rebuild_layout()` 只重建 `_body`，标题与摘要行保留。",
      "正常态中央舞台由 `_make_stage(EXTERIOR, ...)` 创建；`ship.hull_model_path` 非空（内容模组提供船体 GLB）或本地有旧路径回退时，通过 `set_renderer(SNShipStage3D.new())` 挂载 3D 船体舞台；改装态仍用纵剖图贴图，无模型时保留程序化占位。",
      "正常态：船卡用 `SHIP_THUMB_PATH`（存在才加载，210×118 cover；缺失回退占位面板），船名取 Shell 注入的 `ship.hull_name`，缺失回退 `hull_id` 的本地化键；组件列每类一行入口并显示槽位计数，「0 可拖」徽标统计仓库/随船可装行。",
      "改装态：纵剖图 `SNShipView(CUTAWAY)` + 槽位贴片；中间操作列按分类渲染槽位卡、仓库/随船行、购买卡与打造卡。操作列自带 ScrollContainer（`horizontal_scroll_mode=DISABLED`），全页只有中列纵向滚动。",
      "槽位卡：标题 + 固定槽徽标 + 已装名；效果行与重量/tier/卸下按钮取自 `ship.modules[]` 行的 `effect/can_uninstall/uninstall_blockers`（`shipyard.view._current_modules` 输出 `effect`）。",
      "槽位卡按 `ship.modules[]` 行的 `condition` 显示「状态 NN%」徽标（满状态不显示；0 为失效红色），条件值来自模块实例层，页面不自行计算。",
      "槽位反推（`_build_slots`）：船体/锅炉/导航/安全各 1，`cabin_slots≥1` 时加客舱 1，`cargo_slots` 个货舱槽（至少覆盖已装货舱数）；槽位 id `<content_type>_<index>`，fixed 仅船体/锅炉。",
      "拖放 `_on_slot_drop`：类型一致且 source ∈ {warehouse, transit} 才发 `ship.install_module{module_id, source}`；槽位已有且不同件时补 `replace_module_id`。点击购买行 `_on_part_activated` 发 `ship.install_module{module_id}`；点击贴片只切到同类分类并高亮兼容行。",
      "杂项页签 `_build_misc_body`：打造订单 + 在港等待 6/12/24 h + 仓库材料（固定 5 件存/取）+ 仓库模块（免费安装 / 取出）；模块类分类内仍各自保留「按配方打造」与「购买并安装」。",
      "旧整页下方面板已删除：`_stage_row/_parts_hud/_victory_plan/_orders_panel/_warehouse_panel/_craft_panel/_build_purchase_panels` 不再存在；通关条件清单只在总览页。",
      "所有 can_install/can_uninstall/can_craft、blockers、价格与工时来自 shipyard.view；页面只翻译原因、禁用按钮与组织布局。",
      "密集字段（模块行、限制原因、按钮）用 AUTOWRAP_OFF 单行；操作列描述/效果行用 `_wrap_label` 允许换行，避免固定宽度列被撑开。",
      "摘要行的「改装 / 完成改装」按钮直接连 `_on_toggle_refit`（按钮在 `_body` 外，可同步重建）；`_body` 内的分类按钮走 `_ui_set_category` → `set_category.call_deferred`，避免按钮在自身信号里被 `free()`。"
    ],
    l2: {
      "_rebuild_layout()": [
        "清空 `_body` 子节点并重建当前布局；同时重置 `_stage/_stage_title/_stage_hint/_hud_rows`，最后 `_sync_refit_ui()` 同步改装按钮文案与 stage mode。",
        "正常态与改装态互斥，仅靠 `_refit` 分支决定三列内容，不保留隐藏面板。"
      ],
      "set_category(category)": [
        "测试与 Shell 可直接调用；当前不在改装态时先置 `_refit=true` 并发 `refit_mode_changed(true)`，再记录分类、发 `refit_category_changed`、重建布局。",
        "页面从 `vm.category` 恢复同一分类；非法值回退 `hulls`，Shell 只需保存字符串。"
      ],
      "_build_misc_body(box)": [
        "在港等待按钮按 `wait_options`（默认 6/12/24 h）动态生成 `port.wait`；订单行显示剩余工时，不在当前港时追加港口名。",
        "仓库材料行按 `min(5, ship_amount/amount)` 生成存/取命令参数；仓库模块行在 can_install 时给免费安装，始终给取出。"
      ]
    }
  },

  "framework/ui/screens/flow/port_memory_screen.gd": {
    role: "港口记忆流程场景：只读展示上次到港时的市场和设施快照。",
    dependencies: ["SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 port.memory 结果及 Shell 补齐的 age_text/facility_labels，不直接查询端口记忆或注册表。",
      "市场快照不提供交易按钮；返回操作只发出 overview navigation_requested。",
      "快照表四列使用明确最小宽度与横向间距，所有密集字段禁用自动换行，避免中文被压成逐字竖排。",
      "查询失败时展示 error_text，并仍保留返回总览入口。"
    ]
  },

  "framework/ui/screens/flow/settlement_screen.gd": {
    role: "抵达结算流程场景：展示航次收入、准时率、延误、剩余资源、交付明细与伤员。",
    dependencies: ["SNBadge", "SNSectionHeader", "ClockService", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 Shell 保存的 settlement summary、当前 ship/money 与已解析目的港/委托名称。",
      "页面只读展示结算结果；进入港口仅发出 overview navigation_requested。",
      "准时、赔付、延误和资源数值不在页面重算领域结果，只做汇总与格式化。"
    ]
  },

  "framework/ui/screens/flow/at_sea_screen.gd": {
    role: "航行中流程场景：显示起终港、预计抵达时间或等待结算状态。",
    dependencies: ["ClockService", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 只消费 Shell 解析后的 origin_name/destination_name/arrival_time。",
      "页面没有命令入口，不修改航程或时间；抵达刷新由 Shell 与命令结果驱动。"
    ]
  },

  "framework/ui/screens/flow/event_screen.gd": {
    role: "航行事件流程场景：展示事件说明、当前资源和本次抽取的处理选项。",
    dependencies: ["steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 event、ship 与 money，不访问事件注册表或 GameState。",
      "每个选项仅发出 event.choose_option command_requested，并使用独立绑定的 option_id。",
      "结果应用、失败回滚、抵达结算和转场全部由 Shell/CommandBus 负责。"
    ]
  },

  "framework/ui/screens/flow/victory_screen.gd": {
    role: "通关总结流程场景：展示种子、构筑、航次、准时率、事故、财务、债务、耐久和最终模块。",
    dependencies: ["SNSectionHeader", "ClockService", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 只消费 victory.view，不查询通关条件或修改存档。",
      "再来一局与继续游玩分别发出 play_again/keep_playing action_requested；reset_state 与会话 dismiss 由 Shell 执行。",
      "on_time_rate 缺失时仅按 summary 的 on_time/voyages 做展示回退，超过 1 的旧百分比值兼容除以 100。"
    ]
  },

  "framework/ui/screens/port/supply_screen.gd": {
    role: "补给与维修页面场景：绑定 SupplyView，组合煤水决策卡、资源摘要与维修操作。",
    dependencies: ["SNSupplyCard", "SNBadge", "SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(view_model, translate) 是唯一数据入口；页面不查询 AppContext、不访问 QueryBus/CommandBus，也不保存领域状态。",
      "煤水购买与维修统一发出 command_requested(command, params)，由 Shell 执行并决定刷新、音效和错误反馈。",
      "页面可重复 bind；每次先清理旧展示节点，页面实例复用时不会叠加卡片或信号。",
      "阻断码只转换为展示文案，不在页面重新计算库存、重量、金钱或维修规则。",
      "维修卡把报价拆成「缺失耐久 X（船体 A · 部件 B）」，module_points>0 时追加「含部件损耗」徽标；数值全部来自 supply.view 的 repair 字段。"
    ]
  },

  "framework/ui/screens/port/market_screen.gd": {
    role: "港口市场页面场景：展示行情、真实价格历史、持仓成本及买卖操作。",
    dependencies: ["SNSparkline", "SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(view_model, translate) 接收 Shell 组合后的 current_port/money/ship/market/trends，不访问 AppContext 或任何总线。",
      "买卖按钮只发出 trade.buy/trade.sell command_requested；可买性、港存和可售数量只决定展示与按钮禁用。",
      "折线只使用 recent_prices 真实样本；少于两个样本显示缺省状态，趋势颜色为红降绿升。",
      "九列市场表的字段文字保持单行，单元格、趋势和买卖按钮组保留可读最小宽度。",
      "仅收购商品隐藏买入数量组并明确显示 sell-only；平均成本缺失时显示破折号。"
    ]
  },

  "framework/ui/screens/port/contracts_screen.gd": {
    role: "委托页面场景：按可接/进行中分组渲染主线与普通委托卡，并发出接取或规划出航意图。",
    dependencies: ["SNBadge", "SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(view_model, translate) 接收 Shell 已补齐 destination_reachable、unlock_names、completed_names 的展示模型，不自行查询航行或定义注册表。",
      "接取操作发出 contract.accept；规划操作发出 navigation_requested(voyage, destination)，由 Shell 保存目的港并切页。",
      "卡片固定显示主线/普通、风险、目的地、剩余期限、载重、预计航程、说明、报酬与声誉；不足 24 小时使用危险色。",
      "非直达目的港禁用规划按钮并显示中转提示；普通委托持有上限与主线完成状态来自 ViewModel。"
    ]
  },

  "framework/ui/screens/port/intel_screen.gd": {
    role: "航路情报页面场景：展示情报摘要、商品×港口矩阵与 NPC 商船动向。",
    dependencies: ["SNIntelTable", "SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 只消费 intel.view 数据，不访问 AppContext、QueryBus 或 CommandBus。",
      "有报告时展示生成时间、年龄、覆盖统计与快照提示；无报告和空矩阵均有明确空状态。",
      "刷新按钮只发出 intel.refresh command_requested；价格矩阵继续委托 SNIntelTable 渲染。",
      "NPC 预计到达时间只做 ClockService 格式化，不改变游戏时钟或情报快照。"
    ]
  },

  "framework/ui/screens/port/voyage_screen.gd": {
    role: "出航规划页面场景：选择目的港与锅炉策略，展示完整 voyage.preview 并发出出航意图。",
    dependencies: ["SNSectionHeader", "ClockService", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 Shell 已查询的 preview；页面不调用 voyage.preview，不自行计算速度、消耗、风险或可行性。",
      "选择变化发出 selection_changed(destination_id, strategy_id)，由 Shell 保存选择、重新查询并刷新预览。",
      "出航按钮只在 preview.feasible 时可用，并发出 voyage.start command_requested，参数取当前绑定的目的港和策略。",
      "阻断原因、风险来源、委托准时性与目的港设施均来自预览/组合模型，页面只格式化展示。"
    ]
  },

  "framework/ui/components/map_canvas.gd": {
    role: "海图绘制与港口点击组件：显示航路、经纬网、洋流、罗盘、图例及港口状态。",
    contracts: [
      "输入仅为 ports/routes/labels；点击已访问港口时发出 port_clicked(port_id)，不执行导航或查询。",
      "航路使用三次贝塞尔曲线；每港以邻接港口位置平均方向作为唯一出港方向，并沿目的港出港切线入港。",
      "当前港显示脉冲光晕，已访问/可航行/未知港使用不同但带文字图例的状态，不只依赖颜色。",
      "布局按输入坐标缩放到控件尺寸；重绘和 hover 不修改世界或地图 ViewModel。"
    ]
  },

  "framework/ui/components/sn_button.gd": {
    role: "可复用语义按钮：在 Inspector 中选择主操作、次操作、危险或幽灵样式。",
    dependencies: ["steam_navigator_theme.tres"],
    contracts: [
      "只通过 `theme_type_variation` 选择视觉状态，不在业务页面复制 StyleBox。",
      "默认保留键盘焦点并使用指针光标；compact 只调整高度和字号。"
    ]
  },

  "framework/ui/components/sn_panel.gd": {
    role: "可复用界面表面：基础、高架与内嵌三种层级。",
    dependencies: ["steam_navigator_theme.tres"],
    contracts: ["变体只表达视觉层级；内容布局仍由调用页面负责。"]
  },

  "framework/ui/components/sn_badge.gd": {
    role: "紧凑状态徽标：中性、成功、警告和危险四种语义色。",
    dependencies: ["steam_navigator_theme.tres"],
    contracts: ["颜色必须配合明确文字使用，不能作为状态的唯一表达。"]
  },

  "framework/ui/components/sn_section_header.gd": {
    role: "章节标题组合控件：眉题、标题和可选右侧说明。",
    contracts: [
      "内部子节点只创建一次，运行时和 `@tool` 编辑器预览共享同一同步路径。",
      "子标签使用 SNEyebrowLabel/SNTitleLabel/SNDetailLabel 变体，颜色与字号由 Theme 决定。",
      "detail 为空时隐藏右侧标签，标题区自动占满剩余宽度。"
    ]
  },

  "framework/ui/components/sn_resource_meter.gd": {
    role: "煤水、耐久与载重共用的标签化资源存量条。",
    dependencies: ["steam_navigator_theme.tres"],
    contracts: [
      "当前值在 0 到最大值之间显示；最大值最低为 0.1，避免无效 ProgressBar 范围。",
      "色调只切换 Theme variation，名称、数值、单位与安全提示保持同一信息结构。",
      "loss_value<=0 时仍用主题 ProgressBar（耐久/载重路径不变）；loss_value>0 时改用三分段自绘条：填充 [0,current]、空余 [current,maximum]、贴右边缘的损失带 [maximum,maximum+loss]。",
      "条的总跨度为 maximum+loss，因此上限缩水（maximum 降、loss 升）时填充比例恒定不上升；几何由静态纯函数 loss_bar_segments() 计算，绘制与测试共用。",
      "不修改 assets/ui/theme/*.tres，自绘颜色常量镜像主题黄铜/水色/危险色。"
    ]
  },

  "framework/ui/components/sn_supply_card.gd": {
    role: "单种补给品的决策卡：存量、可补上限、价格、港存、预计续航和购买操作。",
    dependencies: ["SNResourceMeter", "SNBadge", "steam_navigator_theme.tres"],
    contracts: [
      "只渲染传入的 ViewModel 并发出 `command_requested(command, params)`；不访问 CommandBus。",
      "最大购买量由查询层计算；卡片禁用 +5/+10/补满时必须已有明确的 blocker 文本。",
      "`maximum` 为当前可达物理上限 capacity（不再是补给后可达上限）；上限被另一项补给占用时用 cap_loss 驱动 meter 的右端损失带，文案使用“可补至/上限损失/剩余可装”。",
      "bind() 第 4 参 tr: Callable 可省略；缺省或缺键时回退内置中文，UI Kit 展示场景无需改动。"
    ]
  },

  "framework/ui/components/sn_intel_table.gd": {
    role: "商品 × 港口对比表控件：一次渲染情报矩阵的列头、价格/趋势单元格与图例。",
    dependencies: ["steam_navigator_theme.tres"],
    contracts: [
      "bind(columns, rows, current_port_id, tr) 为纯数据入口，可在 headless 下实例化；重复 bind 会清空旧内容后重建。",
      "known=false 显示 `？`；buy_price/sell_price 为 -1 表示该侧不经营，显示 `-`（两侧都缺则整格 `-`）。",
      "趋势只显示红降/绿升的百分比数字（trend_percent×100），不使用文字；当前港口列用黄铜高亮。",
      "商品/单位重量/参考价列保持紧凑固定宽度，仅港口列均分剩余空间并保留 120 像素最小宽度；普通单元格显式使用深青背景，禁止回退到 StyleBoxFlat 默认灰色。",
      "全部文案经 tr: Callable 取本地化键（含 ui.intel.col_age 格式串），缺键回退键名，不硬编码中文。"
    ]
  },

  "framework/ui/components/sn_sparkline.gd": {
    role: "市场价格历史迷你折线；只有两个以上真实样本才绘制。",
    contracts: [
      "样本不足时显示“样本不足”，不根据 up/down 状态伪造折线。",
      "输入为真实价格历史数组；颜色由调用页面按趋势传入。"
    ]
  },

  "framework/ui/components/sn_ship_view.gd": {
    role: "船厂中央改装台：`EXTERIOR` 画程序化侧视占位；`CUTAWAY` 画授权纵剖图贴图（`assets/ui/shipyard/ship_section.png`）+ 每槽位一个 `SNSlotTarget` 贴片，贴图缺失时回退程序化剖面；预留可替换的 2.5D 渲染器接口。",
    dependencies: ["SNSlotTarget"],
    contracts: [
      "`SECTION_TEXTURE_PATH` = `res://assets/ui/shipyard/ship_section.png`；`_ready()` 调用 `_load_section_texture()`，仅在 `ResourceLoader.exists` 为真时加载。`has_section_texture()` 判定是否用上授权贴图，`section_texture_size()` 返回像素尺寸（无贴图返回 `Vector2.ZERO`），供测试与调试确认贴图已导入。",
      "`_draw_cutaway()` 优先 `_draw_section_texture()`（cover 裁切贴图）并始终叠加 `_draw_slot_leaders()`；仅贴图缺失/未导入时才用 `_draw_cutaway_placeholder()` 程序化剖面。`Mode.EXTERIOR` 保持程序化侧视、不读贴图。",
      "`_draw_section_texture()` 为 cover 裁切：`cover_scale = max(dst.w/tex.w, dst.h/tex.h)`，取居中源矩形 `draw_texture_rect_region`，再叠 0.18 暗青蒙版；不改变纵横比、不移动控件。",
      "槽位仍按两行排布（非货舱槽 `top = h*0.60`，货舱槽 `top = h*0.82`）；贴片宽 84–148 px（按可用跨度均分），控件宽 < 80 px 时跳过布局。",
      "`_chip_anchor()` 的舱室锚点（船体/锅炉/货舱/导航/安全/客舱）必须与 `tools/art/gen_shipyard_textures.py` 的 `ANCHORS` 保持同一构图比例；换图时两侧一起改。",
      "`Mode.EXTERIOR` 仍是程序化侧视（水面/烟/明轮动画），不读贴图；正常态与改装态共用同一套 `set_slots` 数据。",
      "`set_slots(slots)` 为每个描述重建一个 `SNSlotTarget`；字段：id、content_type、index、title、module、replace_module_id、fixed、hint、tooltip。贴片只在 CUTAWAY 可见；点击发 `slot_activated(slot)`，同类型部件拖到贴片发 `slot_drop_requested(payload, slot)`，本控件不发命令。",
      "2.5D 接入协议不变：`set_renderer(node)` 把节点作为铺满本控件的子节点挂入并立即下发 `ship_view_update(model)` / `ship_view_set_mode(mode)`；`has_renderer()` 判定是否已替换；传 `null` 恢复内置占位。",
      "渲染器实现 `ship_view_update(model)`、`ship_view_set_mode(mode)`、`ship_view_highlight(slot_ids)` 即可；缺方法时用 `has_method` 跳过，不报错。槽位贴片、拖放与命中布局都留在本控件，未来 2.5D 场景只画船体即可。",
      "无渲染器或 EXTERIOR 时每帧 `queue_redraw` 驱动动画；接入渲染器后的 CUTAWAY 只在数据/尺寸变化时重绘，贴图本身不参与动画。"
    ],
    l2: {
      "_draw_section_texture()": [
        "只处理正尺寸贴图；`destination` 恒为整个控件，`source` 按 cover 居中，保证 1792×1008 图在任意舞台尺寸下铺满且不变形。",
        "绘制后统一加半透明暗色压住贴图亮度，保持与 Theme 暗青底一致；槽位引线在贴图之上。"
      ],
      "_layout_slots() / _place_row()": [
        "把货舱槽与非货舱槽拆成两行分别 `_place_row`；`_place_row` 计算 chip 宽高、水平居中、直接写 `position/size`（不用容器排布，便于引线定位）。",
        "贴片可见性每次布局都按 `mode == CUTAWAY` 重算，避免模式切换后残留。"
      ],
      "_draw_slot_leaders()": [
        "从每枚贴片顶部中心画线到 `_chip_anchor` 对应舱室点；货舱按数量决定步长（≤1 时 0.055，否则 0.09）。"
      ],
      "set_renderer(node)": [
        "先移除并 `queue_free` 旧渲染器，再 `add_child` + `move_child(..., 0)` 压到绘制底层。",
        "Control 渲染器铺满本控件并设为 `MOUSE_FILTER_IGNORE`，避免抢走槽位贴片的拖放。",
        "挂载后立即下发当前 model 与 mode，渲染器不必等待下一次刷新。"
      ]
    }
  },

  "framework/ui/components/sn_ship_stage_3d.gd": {
    role: "船厂正常态的真实 3D 船体舞台（2.5D 首个切片）：SubViewport 渲染固定 3/4 机位的船体、海面与灯光；2D 槽位、拖拽与 HUD 仍由 SNShipView 和页面负责。",
    contracts: [
      "通过既有 `SNShipView.set_renderer()` 协议接入：实现 `ship_view_update(model)` / `ship_view_set_mode(mode)` / `ship_view_highlight(ids)`。",
      "船体模型来自内容模组：优先用 `model.hull_model_path`（船体定义 `information.model` 解析结果）经 `ContentAssetLoader.instantiate_model()` 读原始 GLB；路径为空时才回退旧的 `hull_tier -> assets/models/ships` 映射（dev/PCK）。",
      "取模型网格包围盒动态计算机位距离与目标点，让 24 m 明轮船与 60 m 铁甲舰保持同一构图。",
      "EXTERIOR 显示 3D 视口；CUTAWAY 隐藏视口，让纵剖图贴图与槽位贴片接管，不改页面布局。",
      "复用 `assets/materials/water/harbor_water.tres`（duplicate 后把 shore 参数推远、boat 泡沫环绑到当前船体包围盒、调整水平线淡出）；材质缺失时退回 StandardMaterial。",
      "`is_supported()` 只判断本地是否有旧路径可回退；正式发布由页面用 `hull_model_path` 非空来挂载舞台，PCK 不含 `assets/models` 也能显示 3D。",
      "只做表现层：不读 GameState / QueryBus / CommandBus；渲染器方法在 `_ready` 之前被调用时先缓存 model/mode，`_ready` 后统一应用。"
    ],
    l2: {
      "_build_stage()": [
        "SubViewportContainer(stretch) + SubViewport(own_world_3d, transparent_bg=false) + 独立 World3D；一个页面同一时间只存在这一个 3D 视口。",
        "环境为 BG_COLOR + 环境光 + 线性雾，灯光只用一个主光一个补光且关闭实时阴影，保证 1440×900 下的静态舞台开销可控。"
      ],
      "_frame_camera(visual)": [
        "遍历 MeshInstance3D 累积世界包围盒（8 角点变换），半径 × 长焦 FOV 求距离，再沿固定 3/4 方向摆放相机并 look_at 包围盒中心。",
        "船体尺寸变化只改相机，不缩放模型，避免材质/噪声随缩放变形。"
      ]
    }
  },

  "framework/ui/components/sn_slot_target.gd": {
    role: "纵剖图上的单个槽位贴片：显示槽位与已装模块，接收 `ship_parts` 拖放载荷，只校验来源与槽位类型。",
    contracts: [
      "`configure(slot)` 接收 id/content_type/index/title/module/hint/tooltip/fixed；`fixed` 槽位（船体/锅炉）用更亮的黄铜描边。",
      "只接受 `kind == \"ship_parts\"`、`part.source` ∈ {warehouse, transit}、`content_type` 与槽位一致、`can_install` 未显式为 false 的载荷；购买候选不能拖入。",
      "接收后发 `part_dropped(part, slot)`；左键点击发 `slot_activated(slot)`。命令构造与领域规则属于 ShipyardScreen。",
      "悬停/拖入（`_can_drop_data` 通过）用 DROP_HINT 描边；`set_compatible_hint(true)` 用 TEAL 描边，由 SNShipView.highlight_slots 驱动。",
      "`_ready` 之后重复 configure 只刷新文本与样式，不重建子节点；空槽显示“空槽位”。"
    ]
  },

  "framework/ui/components/sn_part_row.gd": {
    role: "船厂右侧部件 HUD 的单行条目：用标签区分已装 / 仓库 / 随船 / 可购买，持有且可装的行是拖拽来源。",
    contracts: [
      "`configure(part, tag_text, tag_color, meta_text, hint_text, can_drag)` 之后重复调用只刷新内容，不重建子节点。",
      "`draggable` 行实现 `_get_drag_data`：返回 `{\"kind\": \"ship_parts\", \"part\": part}` 并调用 `set_drag_preview`，由 SNSlotTarget 消费。",
      "不可拖拽行（已装 / 购买候选）左键点击发 `activated(part)`；只有 ShipyardScreen 会把购买行转成安装命令。",
      "标签文字与颜色由调用方本地化后传入；控件不读 _tr、不访问总线。"
    ]
  },

  "framework/ui/showcase/ui_kit_showcase.gd": {
    role: "独立 UI Kit 展示与视觉冒烟场景，集中实例化全部可复用控件和状态。",
    dependencies: ["SNButton", "SNPanel", "SNBadge", "SNSectionHeader", "SNResourceMeter", "SNSupplyCard", "SNSparkline"],
    contracts: [
      "不依赖 AppContext 或 Core 内容，可在编辑器中单独运行。",
      "展示按钮、徽标、资源条、补给卡、价格折线、输入框、选项框与复选框的默认/禁用/焦点样式。"
    ]
  },

  "assets/ui/theme/steam_navigator_theme.tres": {
    role: "全局 Godot Theme：把深青、黄铜、纸色令牌映射为基础控件与语义变体。",
    contracts: [
      "基础类型覆盖 Button、PanelContainer、LineEdit、OptionButton、ProgressBar 与容器间距。",
      "自定义 variation 包含按钮/面板/徽标/标签/进度条；删除或改名时必须同步控件脚本。",
      "字体使用 SystemFont 回退链，不把本机字体文件写入资源。"
    ]
  },

  "sdk/pack_mod.gd": {
    role: "把松散模组目录打包为 `mods/<id>/...` 的 `.snavmod.zip`。",
    contracts: [
      "跳过 Godot `.import`/`.uid`/`.tmp` 与隐藏目录。",
      "输出文件名固定 `<mod_id>-<version>.snavmod.zip`。",
      "仅打包，不修改 manifest checksum；发布签名/哈希是后续工作。"
    ]
  },

  "sdk/validate.gd": {
    role: "无头校验 Core + 可选第三方模组，输出文本或 JSON 报告。",
    contracts: [
      "若 `--mod-root` 指向单个模组目录（含 manifest.json），自动改用其父目录作为扫描根。",
      "任何 fatal 或普通错误均以退出码 1 结束；纯警告退出码 0。",
      "使用 `dev_mods` 中的 Core，便于第三方内容依赖官方内容。"
    ]
  },

  "tools/gen_content_types.mjs": {
    role: "从 content_types.json 生成框架 ContentTypes 与 SNModMaker 的类型目录；提供 `--check` 过期检查。",
    contracts: [
      "单一真源是 `content_types.json`；生成物 `framework/modding/content_types.gd` 与 `SNModMaker/js/content-types.js` 禁止手改。",
      "生成前校验格式版本、key/singular/schema 唯一、分组与 v2 模块分类引用、Schema 文件存在、Patch 数量、planned 不覆盖 active、draft_schemas 只指向 planned 类型。",
      "`--check` 不写文件，生成物缺失或过期时以退出码 1 结束，供 CI/发布门禁使用。"
    ]
  },

  "tools/gen_static_docs.mjs": {
    role: "静态文档生成器：读取本文件的 FILE_DOCS/MODULES，生成镜像文档、模块 README、总计索引与带 SHA-256 的 manifest。",
    contracts: [
      "GDScript 符号按 `class_name/signal/const/func` 提取；`.js/.mjs` 额外提取顶层 function、常量与 `root.SN*` 导出。",
      "生成前清空 `docs/static`；`SKIP_SOURCES` 中的生成物不进入文档与 manifest。",
      "遍历时跳过 `.git/.godot/node_modules/__pycache__` 目录与 `.import/.uid/.tmp/.pyc` 文件，缓存和编译产物不进入文档。",
      "`STATIC_COPY_PAGES` 把策展型设计文档复制进静态索引，避免清理时丢失非源码页面。",
      "修改规则或分类后重新运行；`commit` 取当前 HEAD 短哈希。"
    ]
  },

  "tools/static_docs_data.mjs": {
    role: "静态文档的策展数据：文件职责/契约/L2、模块简介与分组角色。",
    contracts: [
      "只描述源码可证实的职责与约束；符号位置由生成器扫描，不手写行号。",
      "新增源文件或模块时同步 FILE_DOCS、MODULES、GROUPED_ROLES 与 MODULE_PATHS。"
    ]
  },

  "tools/godot/verify_props.gd": {
    role: "道具 GLB 导入验收（只读）：加载 `assets/models/props/*.glb`，量测 Godot 侧包围盒、三角面与材质名，对照 brief 尺寸判定尺度与轴向。",
    contracts: [
      "glTF 由 Blender Z-up 转 Y-up，故期望尺寸 = (Blender X, Blender Z, Blender Y)；`EXPECTED` 表必须按此口径维护。",
      "尺寸容差 0.05 m；三角面必须与 `EXPECTED` 精确相等——这条专门抓\"改了 .blend 忘了重导 GLB\"与\"读到旧导入缓存\"。",
      "只读，不写场景也不改导入设置；失败退出码 1。",
      "改了 GLB 之后必须先 `godot --headless --import` 刷新缓存，否则量到的是 `.godot/imported` 里的旧产物。"
    ]
  },

  "SNModMaker/index.html": {
    role: "模组制作器的静态外壳：顶栏、导航/工作区/检视器布局，以及模态框、Toast、拖放与忙碌层宿主。",
    contracts: [
      "脚本按 `schema-bundle → core-index → catalog → zip → validate → store → io → ui → app` 顺序加载，全部为经典 script，支持 file://。",
      "不引用外部字体、CDN、图片或模块；图标为内联 SVG / CSS。",
      "`#datalists` 必须保持可被表单引用，不能使用 `display:none` 以外的移除方式。"
    ]
  },

  "SNModMaker/css/app.css": {
    role: "暗色工业主题与响应式布局：顶栏、侧栏、模块子分页、自定义资源选择器、船体模块区、内容/多语言编辑器、模态框与 Toast。",
    contracts: [
      "颜色、间距、字体通过 `:root` 变量统一；不引入外部字体。",
      "`[hidden] { display: none !important; }` 支撑视图与过滤逻辑。",
      "资源候选菜单使用编辑器主题、绝对定位和滚动上限；船体模块卡在窄屏断点退化为单列。",
      "断点 1240 / 1000 / 800 / 760 / 560：编辑区单列、侧栏图标化、顶栏换行与操作压缩。"
    ]
  },

  "SNModMaker/js/catalog.js": {
    role: "字段标签、默认值、标签建议、条件/效果词汇与新建模板；内容类型列表来自生成的 content-types.js。",
    dependencies: ["JSON Schema（结构约束）", "content-types.js（由 content_types.json 生成）"],
    contracts: [
      "`TYPES` 来自 `SNContentTypes.TYPES`；manifest 的顺序决定侧栏分组与表单类型，每项的 `schema` 对应仓库 `schemas/` 文件。",
      "`keyPrefix` 决定本地化键前缀；船只模块共用 `module`，因此跨模块类型的 local ID 必须唯一。",
      "`DEFAULTS` 生成的定义必须能通过对应 Schema；新增字段时同步更新这里与 `store.js`。",
      "操作码、公式、设施等词汇与框架注册表保持同源；页面只做候选与提示，不自行执行。"
    ]
  },

  "SNModMaker/js/zip.js": {
    role: "零依赖 ZIP 读写：中央目录解析、CRC32、store / deflate-raw 压缩，以及 ZIP 体积与路径限制。",
    contracts: [
      "写包使用 UTF-8 文件名标志；不支持 Zip64，读取时拒绝 0xFFFFFFFF 尺寸。",
      "解压限制：最多 2000 条目、总解压体积 64 MB；每条校验 CRC。",
      "压缩优先 `CompressionStream('deflate-raw')`，不可用或收益为负时退化为 store。",
      "`build()` 只接收逻辑路径；`mods/<id>/` 前缀由 `store.toExportFiles()` 添加。"
    ],
    l2: {
      "build(entries)": [
        "先写本地文件头与数据，再写中央目录与 EOCD；偏移量按实际字节累计。",
        "压缩失败不抛错，直接使用原始字节和 method=0。"
      ],
      "read(input)": [
        "从尾部扫描 EOCD，按中央目录读取路径与偏移，再定位本地头数据起点。",
        "method=8 使用 `DecompressionStream('deflate-raw')`；method=0 直接切片。"
      ]
    }
  },

  "SNModMaker/js/validate.js": {
    role: "JSON Schema 子集校验器与 Steam Navigator 项目语义校验：ID、引用、本地化、补丁与清单一致性。",
    dependencies: ["schema-bundle.js", "catalog.js", "core-index.js（可选外部引用检查）"],
    contracts: [
      "Schema 能力与 Godot `SchemaValidator` 的常用子集对齐；不支持远程 ref、if/then/else、format 断言。",
      "错误路径使用 JSON Pointer；项目问题附带 `view` 提示供 UI 跳转。",
      "语义规则不替代 Godot 领域校验与 Core 完整性检查；网页端只做静态内容检查。",
      "实体 information.texture/model 支持当前模组裸资源键与完整 asset:// URI；当前模组和 Core 引用必须存在且格式匹配。",
      "同一问题按 severity/code/message/view 去重，最多收集 300 条 Schema 错误。"
    ],
    l2: {
      "validateSchema(instance, schema, file)": [
        "递归处理 `$ref`、allOf、anyOf/oneOf/not 探测、类型/枚举/范围/数组/对象约束。",
        "`additionalProperties: false` 报告未知字段；组合器探测使用独立 context，避免文件基准污染。"
      ],
      "flattenObject(schema, file)": [
        "合并 `$ref` 与 allOf 的 properties/required，仅用于表单渲染，不用于替代校验。"
      ],
      "validateProject(project)": [
        "先跑 Manifest Schema 与内容文件 Schema，再检查命名空间/类型段、重复 ID、本地化覆盖、跨引用与补丁目标。",
        "资源裸键按当前模组 manifest.assets 解析；asset://core/<key> 使用嵌入 Core 索引校验，其他外部模组 URI 在无法读取其清单时给出未验证提示。",
        "引用本模组缺失为 error；Core 缺失为 warning；其他命名空间只提示外部引用。",
        "结果包含 counts 与 stats（定义/文件/语言/资源数量）。"
      ]
    }
  },

  "SNModMaker/js/store.js": {
    role: "项目模型与纯数据操作：模板、定义增删改复制、Manifest 同步、导入导出映射与 Core 克隆。",
    dependencies: ["catalog.js", "core-index.js"],
    contracts: [
      "项目以 `contentFiles/localization/assets` 为真源，`manifest.content/localization/assets` 每次由 `syncManifest()` 重建。",
      "所有定义 ID 必须使用本模组命名空间；local ID 在共享 `keyPrefix` 的类型间也保持唯一，避免本地化键碰撞。",
      "`keyBaseOf()` 优先信任 `name_key` 去掉 `.name` 的前缀，兼容 Core 中 ID local 与键前缀不一致的情况。",
      "导出固定加 `mods/<id>/` 前缀；导入接受带/不带前缀的目录与 ZIP，并保留缺失文件为占位以便报错。",
      "资产以 data URL 存项目；导出时解码为字节；`checksum` 不在网页端计算。"
    ],
    l2: {
      "createProject(options)": [
        "创建 Manifest + zh_CN/en 两个语言文件，再按模板写入定义；模板包含 goods / boiler / event / starter_kit / blank。",
        "模板只使用默认值与 Core 引用，生成后立即由 `syncManifest()` 对齐清单。"
      ],
      "addDefinition(project, typeKey, options)": [
        "生成唯一 local ID、完整 ID、名称/描述键，填充嵌套选项键，并同步创建/更新双语翻译。",
        "`localeExtras` 用于模板中的公告文本；`optionNamesZh/En` 用于事件选项的可读名。"
      ],
      "cloneCoreDefinition(project, coreDefinitionId)": [
        "深拷贝 Core 定义，按 `name_key` 推导旧键基，改写全部 `_key` 字符串与本地化条目。",
        "Core 定义中的贴图/模型裸键改写为 `asset://core/<key>`，使派生条目继续引用官方资源而不冒充当前模组资产。",
        "新 ID 与键基使用当前模组命名空间，并在名称后追加“副本”。"
      ],
      "commitDefinitionLocalization(project, definition, typeKey, oldBase, newBase, translations)": [
        "保存条目时才把定义内全部 `_key` 与所有语言文件从旧键基原子迁移到新键基。",
        "迁移前检查目标键冲突；成功后删除旧键并覆盖用户在条目内暂存的多语言文本。"
      ],
      "toExportFiles(project, options)": [
        "产出 manifest、内容、本地化与二进制资产；`prefix:false` 用于文件夹导出。",
        "内容 envelope 只保留 `schema_version/content_type/definitions`。"
      ],
      "fromFiles(entries)": [
        "定位最短路径的 `manifest.json`，剥离根目录；按清单读取内容/本地化/资产。",
        "缺失声明文件生成占位并返回 warnings；未知 content_type 跳过。"
      ]
    }
  },

  "SNModMaker/js/glb.js": {
    role: "最小 GLB（glTF 2.0 二进制）解析器，为资源卡片提供场景节点、三角形网格、法线与材质基色。",
    dependencies: ["WebGL 渲染层 model_thumb.js"],
    contracts: [
      "只解析 JSON/BIN chunk、bufferView/accessor、node TRS/矩阵、TRIANGLES primitive 与 baseColorFactor；不支持贴图、Draco/KTX2、骨骼、变形目标与稀疏 accessor。",
      "结果预变换到世界坐标并汇总 bbox、三角形数、节点数与材质数；无法预览的 primitive 跳过而不是整体失败。",
      "纯函数、不依赖 DOM/WebGL，可在 Node 中直接测试。"
    ]
  },

  "SNModMaker/js/model_thumb.js": {
    role: "用共享 WebGL 上下文把 GLB 渲染成自动取景的 PNG 缩略图，并按键缓存结果。",
    dependencies: ["glb.js", "store.js（dataUrlToBytes）"],
    contracts: [
      "固定 480×360、透明背景、单方向光 + 环境光；相机按 bbox 自动取景，不提供旋转交互。",
      "单例 canvas/context 复用，每张图渲染后立即 `toDataURL` 并缓存，避免资源卡片重绘时重复解析与绘制。",
      "没有 WebGL 或解析失败时返回 null，调用方保留 GLB 占位，不影响编辑/导出。"
    ]
  },

  "SNModMaker/js/io.js": {
    role: "浏览器 I/O：IndexedDB 项目库、文件/文件夹/ZIP 导入、下载、目录导出与本地游戏模组部署 API。",
    contracts: [
      "IndexedDB 数据库 `snmodmaker`、对象仓库 `projects`（keyPath=uid）；打开超过 3 秒视为不可用，由 app 回退 localStorage。",
      "文件夹/拖放导入递归读取 `webkitGetAsEntry`；ZIP 交给 `SNZip.read()`。",
      "目录导出需要 Chromium 的 `showDirectoryPicker`，在所选父目录下创建 `<mod_id>/`。",
      "检测到 `tools/serve.mjs` 时使用同源 `/api` 读写项目、普通导出与游戏模组目录；`detectBackend` 1.5s 超时后静默退化。",
      "`getWorkspaceProject/putWorkspaceProject` 走 `/api/workspace/<id>`，把 `dev_mods/<id>` 作为原生工作区直接读写；普通磁盘项目仍走 `/api/projects/<id>`，两者按 id 不会互相遮蔽。",
      "deployGameMod(id, bytes) 把已构建 ZIP 交给本地服务覆盖部署；纯静态/file:// 模式不暴露该操作。",
      "下载使用 Blob URL；不向外部网络上传任何内容。"
    ]
  },

  "SNModMaker/js/ui.js": {
    role: "Schema 驱动的表单渲染与通用 UI 组件：字段控件、数组/条件/效果编辑器、自定义资源选择器、船体模块区、模态框与 Toast。",
    dependencies: ["validate.flattenObject/deref", "store", "catalog"],
    contracts: [
      "渲染层只输出 HTML；所有编辑通过 `data-field` / `data-action` 交给 app.js，不直接修改项目。",
      "表单字段类型、枚举、范围与必填来自 Schema；专用控件只针对 modifier/material/payload/condition/effect/option 等结构。",
      "标准实体表单额外呈现所有语言的名称/描述暂存输入，以及 information.texture/model 资源键配置。",
      "贴图与模型不用浏览器原生 datalist：图片候选仅含 png/webp/svg，模型候选仅含 GLB，并保留直接输入资源键能力。",
      "船体把 cargo_slots/cabin_slots 移入专属模块区，并展示运行时固定的锅炉、导航、安全各一槽；普通数据区不重复渲染。",
      "所有用户文本与属性值经过 `esc/attr` 转义；引用候选来自当前项目 + Core 索引。",
      "表单生成的路径是相对定义的属性路径（manifest 除外），与 app.setByPath 的约定一致。"
    ],
    l2: {
      "renderField(field, schema, value, path, ctx, options, schemaFile)": [
        "先解引用；按 `id_ref/range2/modifier/craft_material/payload/option_data/effect/condition_node` 分派专用控件，再按 type/enum 分派通用控件。",
        "递归传入当前 schema 文件，保证 common.schema.json 内的本地 `$ref` 能正确解析。"
      ],
      "renderDefinitionForm(ctx)": [
        "普通定义渲染身份区、条目内多语言值、视觉资源与数据区；补丁定义渲染目标、来源约束与操作列表。",
        "ID 输入只显示 local 部分，前缀由 app 在写回时补齐；名称/描述键显示只读的待提交预览。",
        "hulls 额外渲染模块配置区，并从通用数据字段中跳过 cargo_slots/cabin_slots。"
      ],
      "assetPicker(path, value, kind, project)": [
        "输出可编辑输入、展开按钮和主题化候选菜单；候选同时显示资源键与项目内路径。",
        "kind=image 仅接受图片 MIME/扩展名，kind=model 仅接受 model/gltf-binary 或 .glb。"
      ],
      "renderCondition(value, path, ctx)": [
        "支持 leaf、all、any、not 递归；操作码切换只保留适用字段。",
        "空条件显示“始终满足”，由 app 添加首个节点。"
      ]
    }
  },

  "SNModMaker/js/app.js": {
    role: "应用控制器：视图状态、事件委托、表单写回、撤销/重做、自动保存、导入导出与 Modal 流程。",
    dependencies: ["store", "validate", "ui", "io", "catalog", "zip（经 io）"],
    contracts: [
      "`state.project` 是唯一项目源；视图与选择状态不写入导出 JSON。",
      "文本输入只更新模型并调度校验/保存，不整页重绘；结构操作才重绘并保留滚动位置。",
      "历史快照最多 40 个；一次焦点内的连续输入只压入一个快照。",
      "自动保存有 800ms 防抖，并用 revision 防止旧保存清除新改动；IDB 失败回退 localStorage。",
      "ID 修改与条目内翻译先进入 localizationDrafts；自动保存不写多语言键，只有“保存条目”提交键迁移。",
      "船只与模块相关类型共享页面子分页，可直接切换而无需返回侧栏重新选择。",
      "自定义资源选择器支持点击展开、输入搜索、清空和选择写回；点击外部或 Escape 关闭菜单。",
      "检测到本地服务时，同一项目再经 1.6s 防抖镜像到 `mods/<id>/`；磁盘失败只降低提示，不阻断浏览器保存。",
      "项目库的「磁盘」区同时列出 `mods/` 项目与 `dev_mods/` 工作区：工作区行标「工作区」且不提供删除；`state.workspace` 为真时保存改走 `putWorkspaceProject`，直接写回原生模组目录。",
      "导出菜单在本地服务可用时提供发布包部署入口：先保存项目、构建 ZIP，再覆盖 `dist/build/<platform>/mods/<id>.snavmod.zip` 并报告旧包清理数量。",
      "没有本地服务时，发布包部署入口以禁用项 + 启动服务指引呈现，而不是完全隐藏。",
      "资源页对带 dataUrl 的 GLB 卡片异步生成缩略图；渲染队列逐张执行，失败时保留 GLB 占位。",
      "Ctrl+S/Z/Shift+Z/N/O/E 为全局快捷键；文本输入中不拦截撤销。"
    ],
    l2: {
      "applyField(element, fromChange)": [
        "区分 manifest 与当前定义；数字/整数/布尔/JSON 各有解析，解析失败不写回。",
        "ID 输入按前缀重建完整 ID，只更新多语言键预览，不直接改定义 `_key` 或语言文件。",
        "空描述键、空 checksum 与空 information 资源字段会删除，避免违反可选字段的 pattern/minLength。"
      ],
      "saveDefinitionAction()": [
        "把当前实体暂存的所有语言值映射到最终预览键，并调用 store 原子迁移旧键。",
        "提交成功后清理草稿、重新校验并立即保存项目；冲突时保留草稿并提示错误。"
      ],
      "saveNow()": [
        "写入 IndexedDB；失败时写 localStorage 并标记存储模式。",
        "保存完成后比较 revision：有更新则保持 dirty 并排队下一次保存。"
      ],
      "importEntries(entries)": [
        "识别单个 `.zip`、单个 `.snmodproj.json` 或目录文件集；导入后立即保存并展示 warnings。",
        "所有解析错误转换为 Toast，不改变当前项目。"
      ]
    }
  },

  "SNModMaker/tools/sync-schemas.mjs": {
    role: "把 `schemas/*.schema.json` 打包为可直接 `<script>` 引入的 `js/schema-bundle.js`。",
    contracts: [
      "生成文件头带 AUTO-GENERATED 标记；修改 Schema 后必须重跑。",
      "只做 JSON 解析与嵌入，不校验 Schema 自身。"
    ]
  },

  "SNModMaker/tools/sync-core-index.mjs": {
    role: "从 `dev_mods/core` 生成 `js/core-index.js`：Manifest、内容文件、双语本地化与定义索引。",
    contracts: [
      "索引用于引用候选、中文名、外部引用检查与从 Core 复制。",
      "修改 Core 内容或本地化后必须重跑。"
    ]
  },

  "SNModMaker/tools/serve.mjs": {
    role: "零依赖本地静态服务器 + 磁盘 API：项目工作区、原生模组工作区（dev_mods 原地编辑）、普通导出与发布包模组覆盖部署。",
    contracts: [
      "仅监听 127.0.0.1；默认端口 8099。支持 `SNMODMAKER_MODS_DIR` / `SNMODMAKER_EXPORTS_DIR` / `SNMODMAKER_GAME_MODS_DIR` / `SNMODMAKER_WORKSPACE_ROOT` 覆盖目录；工作区根默认是仓库 `dev_mods/`。",
      "默认部署目标由 `game_mods_dir.mjs` 解析为 `dist/build/<platform>/mods/`（优先已有的导出平台目录）。",
      "API：status、projects、workspace、exports 与 game-mods；请求体上限 128 MB。",
      "`/api/workspace/<id>` 直接读写 `dev_mods/<id>`：打开时返回 manifest/content/localization 与资产键占位（不含二进制），保存时只写文本文件并删掉 manifest 不再声明的 content/localization 文件；资产目录永远不动。",
      "工作区保存允许删除/新增定义与内容文件；`/api/workspace/<id>` DELETE 被拒绝，避免误删整个原生模组。",
      "游戏部署使用稳定文件名 `<id>.snavmod.zip`，临时文件写完后替换目标，并清理同 ID 的旧版本号包，避免重复模组。",
      "项目先写临时目录再替换，文件路径拒绝绝对路径、`..`、盘符与超过 16 层。",
      "静态文件带 `Cache-Control: no-store`，路径解析后必须位于 SNModMaker 目录内。"
    ]
  },

  "SNModMaker/tools/game_mods_dir.mjs": {
    role: "解析编辑器「导出并覆盖到发布包 mods/」的默认目标目录。",
    contracts: [
      "优先级：`SNMODMAKER_GAME_MODS_DIR` > 当前平台已有的 `dist/build/<target>/` > 任意已有导出平台 > 当前平台 `dist/build/<platform>/mods`。",
      "平台映射：win32→windows、darwin→macos，其余→linux。",
      "纯函数可注入 env/platform/exists，供 Node 单元测试覆盖，不直接读真实目录。"
    ]
  },

  "SNModMaker/tools/content.mjs": {
    role: "SNModMaker 内容 CLI（零依赖 Node ESM）：types / describe / list / add / set / loc / rm / clone / validate / new 十个无头命令，按 Schema 增删改定义、补本地化并校验。",
    dependencies: ["SNStore", "SNValidate", "SNCatalog", "content_json.mjs", "Node 内置模块"],
    contracts: [
      "十个命令由 `COMMANDS` 分发表进入；`parseArgv` 支持 `--flag value` / `--flag=value`、重复 flag 收集为数组与 `--` 之后的按位置参数，`--help` 退出 0。",
      "复用网页端引擎而非另写规则：经典脚本按 schema-bundle → core-index → content-types → catalog → validate → store 的顺序 require 到 `globalThis`，校验、注册与本地化都走 `SNStore` / `SNValidate` / `SNCatalog`。",
      "`--mod` 必须是含 `manifest.json` 的目录；所有写入经 `resolveInside` 限制在目录内，拒绝绝对路径、盘符与 `..`。",
      "输出契约：`--json` 时 stdout 只有一个 JSON 对象（成功 / 失败 / 用法错误都是），人读日志写 stderr；退出码 0 成功、1 执行失败 / 校验未通过 / 冲突、2 用法错误。",
      "写命令统一预检：改动前后各跑 `Validate.validateProject`，按 `severity|code|message|view` 求新增问题；new error 默认整批不写并退出 1，`--force` 只解除拦截、结果仍 `ok:false`。",
      "外部命令只在真实写入后执行：`--sync` 仅在 `manifest.id === 'core'` 时跑 `sync-core-index.mjs`，`--test` 跑 `SNModMaker/tests/run-tests.js`；`validate --godot` 需 `GODOT_BIN`，未设置只记 notes 不算失败。"
    ],
    l2: {
      "loadMod(ctx, modArg)": [
        "递归排序读取模组目录得到 `{path, data}` 条目，交 `Store.fromFiles` 生成 project / warnings；每个文件保存 buffer 与加载时的 SHA-256 供冲突检测。",
        "文本按需 UTF-8 解码并缓存；`resolveInside` 对相对路径做前缀校验，越界抛 `path` 错误。"
      ],
      "collectChanges / verifyBaseline / commitChanges": [
        "`collectChanges` 只保留与加载缓冲不同的文件，输出 create / update / delete（`--dry-run` 时加 `would-` 前缀）、bytes 与行级 LCS unified diff；内容相同的写入项直接丢弃。",
        "`verifyBaseline` 写前重新读取每个待写 / 待删文件并与加载时 SHA-256 比对，不一致抛 `conflict`；`commitChanges` 先整体校验再逐个写入，因此冲突时零写入。",
        "单文件写入用同目录 `.tmp-<pid>-<rand>` 写完 `fs.renameSync` 覆盖，失败清理临时文件。"
      ],
      "finalizeWrite(ctx, options)": [
        "所有写命令的公共收尾：计算 newIssues、决定是否写盘、组装 `changes / issues / stats / notes` 与统一摘要。",
        "`--dry-run` 或被 new error 拦截时只产出 `would-*` 变更；`--force` 只放开拦截，不改变失败状态与退出码。",
        "真实写入成功后才执行 `--sync` / `--test`；无真实写入或非 core 时只往 notes 记录跳过原因。"
      ],
      "planAppendDefinition / planLocaleChanges / planManifest": [
        "内容文件：解析源文本后定位 `definitions` 数组，用 `insertArrayItem` 在尾部插入；只有新建内容文件才整份序列化写出。",
        "本地化：只写有实际变化的 locale 文件；纯新增键用 `insertLocaleEntries` 插到最后一个成员之前以保留既有字节，增删改混合时才整份 `JSON.stringify(entries, null, 2)`。",
        "manifest：只对 `content` / `localization` 数组做元素级增删（`insertArrayItem` / `removeArrayItem` / 缺字段时 `insertObjectMember`），不重写其他字段。"
      ],
      "editDefinitionText / applyAssignmentToText": [
        "`set` 先在内存定义上执行赋值，再在源文本上改写目标节点：标量 `replaceNodeValue`、数组插删、缺失路径插到最深的已存在父节点。",
        "改写后用 `JSON.parse` 与内存期望值全等校验；不一致时兜底为只替换该 definition 节点并再次校验，仍不一致报 internal 且不写盘。"
      ],
      "commandRm": [
        "删除前收集定义的全部键；删除后以所有剩余定义的键与任意字符串值作为保留集合，只删除未被保留的本地化键（`--keep-loc` 跳过）。",
        "内容文件仍有定义时精确删除数组项；变空时改为删除该内容文件，并同步移除 manifest 声明。"
      ],
      "describeFields / describePayload": [
        "字段表来自 `SN_SCHEMAS`：envelope `definitions.items` 的 allOf 用 `Validate.deref` 合并并保留属性所属 Schema 文件（跨文件 `$ref` 才正确），`data` 再展开一层；object 与数组元素递归到深度 4，路径写成 `data.market[].stock_range`。",
        "每行只带实际存在的约束键；`defaults` 来自 `SNCatalog.DEFAULTS[type]?.()`，patches 的 defaults 为 null 并给出 target / operations 骨架。"
      ],
      "commandNew": [
        "`Store.createProject` + `toExportFiles(prefix:false)` 写出模板文件树，内容文件用 `formatStyled` 统一风格；目标目录非空且无 `--force` 时退出 1。",
        "真实写入后重新 `loadMod` 再校验；`--dry-run` 只列 `would-create`，不落盘。"
      ]
    }
  },

  "SNModMaker/tools/content_json.mjs": {
    role: "保源 JSON 源文本编辑器（纯函数、无 fs）：解析带 start / end 的节点树，只替换目标节点附近的文本切片，让 CLI 增删改内容时既有字节、缩进与 BOM 保持不变。",
    dependencies: ["content.mjs（唯一调用方）"],
    contracts: [
      "节点 `start / end` 是半开区间（`end` 指向最后一个字符之后），`open / close` 是括号下标；object 带 `members[{key, keyStart, value}]`（`findNode` 取同名键最后一个），array 带 `items[]`。",
      "`parseSource` 是严格 JSON 解析：尾随内容、悬空逗号、前导零、未转义控制字符与嵌套超过 256 层都抛 `SyntaxError`（附源偏移）；字符串值交 `JSON.parse` 校验转义。",
      "BOM 容忍：开头 U+FEFF 跳过但游标起点同步前移，节点偏移仍以原文为准，因此插入 / 删除切片会原样保留 BOM；`add` 后再 `rm` 仍可逐字节还原。",
      "函数不重新定位节点：调用方传入的 node 必须与 text 来自同一次 `parseSource`，文本变化后需重新解析。",
      "插入 / 删除只动目标节点附近的字节：是否多行、缩进与逗号都取自源文本；对象插入与数组插入使用同一套策略。",
      "`formatStyled`：2 空格缩进（缩进基准可传列号或字符串），对象恒多行，纯标量数组在缩进基准加行内长度不超过 `inlineLimit`（默认 100）时单行，空容器为 `[]` / `{}`，返回值首行不带缩进。"
    ],
    l2: {
      "parseSource(text)": [
        "手写递归下降：skipWhitespace / parseString / parseNumber / parseLiteral / parseObject / parseArray 组成节点树并记录偏移。",
        "数字用 JSON 数字正则后 `Number(...)`，字符串 value 由切片交 `JSON.parse`；解析结束要求恰好消费完整文本。"
      ],
      "insertArrayItem(text, arrayNode, value, formatter)": [
        "空数组展开为三行（换行、缩进两格的新项、原关闭缩进）；单行数组在 `]` 前内联插入 `, <inline>`；多行数组在最后一项之后追加逗号、换行与新项，并复用最后一项的缩进。",
        "插入前用 `assertInsertable` 拒绝 undefined 与不可序列化值；`formatter(value, indent)` 返回首行不带缩进的文本。"
      ],
      "removeArrayItem(text, arrayNode, index)": [
        "唯一项 → `[]`；首项 → 删除到第二项 start（带走尾随逗号与缩进）；中间 / 末项 → 从前一项 end 删除到目标 end。",
        "这正是 `add` → `rm` 逐字节还原与首 / 中 / 末 / 唯一项四种边界的关键不变量。"
      ],
      "replaceNodeValue / insertObjectMember": [
        "标量直接切片替换 token；对象 / 数组用 `formatStyled(value, columnAt(node.start))` 按起始列重写。",
        "`insertObjectMember` 与数组插入同策略：空对象展开、单行对象内联、多行对象插在最后成员之后。"
      ],
      "formatStyled / formatInline": [
        "`formatStyled` 递归输出多行文本，首行不带缩进、后续行按基准逐层加两格；`formatInline` 生成永不换行的一行表示，供单行数组 / 对象与内联插入使用。",
        "非有限数字或不可序列化值抛 `TypeError`；缩进参数传 number 时按列数生成空格。"
      ]
    }
  },

  "SNModMaker/tests/content-cli.test.mjs": {
    role: "Content CLI 集成测试：用 node:test 子进程调用真实 CLI，在临时模组目录覆盖十个命令、保源写回、校验闸门与 JSON 输出。",
    contracts: [
      "每个用例在 `fs.mkdtempSync(os.tmpdir())` 建临时模组；仓库 `dev_mods/core` 只读（部分用例比对前后 SHA-256），任何写操作都不落在仓库内。",
      "覆盖 types / describe / list / new / add / set / loc / clone / rm / validate 的正常路径与用法错误、`--dry-run` 不写盘、最小 diff 与 add → rm 逐字节还原（含 BOM）、本地化专属键清理、`--json` 单一对象与退出码 0 / 1 / 2。",
      "运行：`node --test SNModMaker/tests/content-cli.test.mjs`（从仓库根执行），只用 Node 内置模块，不引入第三方依赖。"
    ]
  },

  "SNModMaker/tests/run-tests.js": {
    role: "Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP、导入导出往返、GLB 解析与部署目标解析。",
    contracts: [
      "不依赖浏览器或 Godot；直接 require 经典脚本并以 `globalThis.SN*` 访问模块。",
      "覆盖 32 个用例，含实体多语言键事务、资源候选类型过滤、船体模块区、贴图/GLB 引用、GLB 解析与发布包 mods 目标解析；任何失败以退出码 1 结束。"
    ]
  },

  "SNModMaker/tests/server-smoke.mjs": {
    role: "本地服务磁盘 API 冒烟测试：在隔离临时目录验证游戏模组部署、覆盖、枚举、删除与旧版本清理。",
    contracts: [
      "启动真实 tools/serve.mjs 子进程，并通过三个环境变量把所有写入限制在临时目录。",
      "测试结束终止服务并删除临时目录；任何断言失败以非零退出码结束。"
    ]
  },

  "SNModMaker/tests/workspace-smoke.mjs": {
    role: "原生工作区冒烟测试：用 `/api/workspace/<id>` 打开 dev_mods/<id>，验证删除定义、新增内容文件、删除本地化、资产不被改写与禁止整体删除。",
    contracts: [
      "在临时目录构造一个 workspace 根与 core 模组，并用 SNMODMAKER_WORKSPACE_ROOT 指向它，不触碰仓库 dev_mods。",
      "保存使用与浏览器相同的 `{project, files}` 载荷；断言磁盘上定义集合、内容文件与本地化删除结果。",
      "断言 `assets/models/*.glb` 字节不变，且 DELETE `/api/workspace/<id>` 返回 400。"
    ]
  },

  "SNModMaker/tests/browser-smoke.mjs": {
    role: "Chrome DevTools Protocol 冒烟测试：新建项目、实体键事务、模块子分页与船体模块区、本地化、自定义资源选择器、ZIP、导入与撤销。",
    contracts: [
      "需要 Chrome 以 `--remote-debugging-port=9222` 启动，并已有静态服务。",
      "测试开始前清空该 origin 的存储；直接调用页面内 `SN*` 模块做导出/导入断言。",
      "收集 `Runtime.exceptionThrown` 与 console error，任何一条都会导致非零退出。"
    ]
  },

  "framework/domain/ship/warehouse_ops.gd": {
    role: "港口仓库与随船运输：每港独立保存模块/材料，transit 模块计入重量但不占货舱。",
    contracts: [
      "仓库数据位于 `world.warehouses[port_id] = {modules:{id:qty}, materials:{id:amount}}`；`ensure_structure()` 幂等补齐所有港口与 ship.transit_modules，兼容旧存档。",
      "store/take 模块在 transit 与当前港仓库之间移动；take 检查船体 max_weight，store 只要求停靠。",
      "store 材料把船上非委托货物移入仓库；take 材料检查重量与货舱容量。",
      "仓库操作只处理纯数据与结果码，不删除安装态；安装/替换由 ShipOps/ShipCommands 负责。",
      "所有失败返回 Result.fail，命令总线因此回滚工作副本。"
    ],
    l2: {
      "ensure_structure(state)": [
        "对每个 world.ports 键确保 warehouses 条目存在并含 modules/materials；缺失 ship 时也补齐。",
        "对已有条目只补缺失 section，不清空已有库存。"
      ],
      "take_module(...)": [
        "重量校验使用 ShipOps.total_weight + qty*module.weight；通过后才从仓库移除并写入 transit。",
        "返回 transit_qty/warehouse_qty/transit_weight 供 ViewModel 直接使用。"
      ]
    }
  },

  "framework/domain/ship/craft_ops.gd": {
    role: "模块打造：读取模块 JSON 配方、规划材料来源、仓库优先消耗、扣费并生成带工时的打造订单，时间到位后把成品写入下单港仓库。",
    contracts: [
      "配方来自 module.data.materials / craft_time_hours / craft_cost；可打造 = 类型在 CRAFTABLE_TYPES 且（materials 非空 或 craft_cost>0），所以 tier1「仅金币」配方不需要材料。",
      "材料来源顺序：当前港仓库优先，再从船上非委托货物扣除；不足返回 missing_materials。",
      "craft() 不再推进时间、不再立即入库：扣材料与 craft_cost（记支出）后写入 state.data.shipyard_orders（order_id=order_N，ready_at=now+craft_time_hours），并发布 ship.craft_ordered。",
      "订单字段由 ensure_orders 幂等补齐（旧存档兼容、float serial 归一化为 int）：state.data.shipyard_orders / order_serial，全部为纯 JSON。",
      "settle_orders(state, hub) 在 now>=ready_at 时把成品写入订单所属港口仓库、推 notice ui.notice.craft_completed（参数按模板顺序：模块 → 港口）并返回完成明细；结算时机：craft() 开头、VoyageService 抵达、port.wait。",
      "成品进入下单港仓库而不是直接安装；随后由 ship.install_module(source=warehouse) 免费安装。",
      "craft_blockers 与船厂 ViewModel 共用：unknown_module/not_craftable/locked_by_contract/missing_materials/insufficient_money。"
    ],
    l2: {
      "craft(state, hub, module_id)": [
        "先 ensure_orders + settle_orders，再复用 craft_blockers 做整体校验，避免部分扣材料后失败。",
        "逐个材料先扣仓库再扣 cargo，返回 consumed 明细（from_warehouse/from_cargo）。",
        "add_money(-craft_cost) 时同步 record_expense；随后只写订单，不推进时间。"
      ],
      "settle_orders(state, hub)": [
        "只处理 now>=ready_at 的订单，按 port_id 写 WarehouseOps 仓库；返回行含 order_id/module_id/content_type/name_key/port_id/warehouse_qty 供命令层发事件。"
      ]
    }
  },

  "framework/domain/run/victory_service.gd": {
    role: "通关判定与服务：主线全部完成 + 造船厂内组装最低可运行大型船（大型船体 + 锅炉 + ≥1 货舱）。",
    contracts: [
      "通关只由船厂安装成功后的 `check()` 触发；检查本身幂等，只在首次满足时写入 state.data.victory 并返回 newly_achieved=true。",
      "main_chain_complete 遍历注册表中 kind==main 的模板，全部出现在 contracts.completed 才为真；无主线模板返回 false。",
      "conditions 暴露 shipyard/main_complete/large_hull/boiler/cargo/ready 六个门槛供 UI/测试使用；large_hull 以 hull tier>=3 判断。",
      "summary 为纯 JSON：seed、构筑、航次、准时率、事故、收入/支出/利润、货币、债务、耐久、船体与已安装模块。",
      "框架不引用具体 core ID；门槛全部来自注册表数据与 ShipOps 派生属性。"
    ],
    l2: {
      "check(state, hub)": [
        "已通关时立即返回 achieved=true、newly_achieved=false，不覆盖 achieved_at/summary。",
        "未满足门槛返回 achieved=false 与 conditions，不写入任何状态。",
        "满足时先 summary() 再写入 victory，返回 summary 供命令层写入 data.victory 与领域事件。"
      ]
    }
  },

  "framework/application/commands/warehouse_commands.gd": {
    role: "仓库命令包装：ship.transit 与当前港仓库之间的模块/材料存取。",
    contracts: [
      "四个命令分别为 warehouse.store_module / take_module / store_materials / take_materials。",
      "命令只做参数解析、WarehouseOps 调用与领域事件发布；规则全部在 WarehouseOps。",
      "事件类型：warehouse.module_stored / module_taken / materials_stored / materials_taken。"
    ]
  },

  "framework/application/queries/victory_view.gd": {
    role: "通关页 ViewModel：是否通关、通关时间与完整 run summary。",
    contracts: [
      "没有 run 时返回 has_run=false / achieved=false，UI 可安全渲染。",
      "achieved/achieved_at 来自 state.data.victory；summary 直接透传 VictoryService 写入的纯数据。",
      "achieved_at_label 由 ClockService 格式化，供页面标题使用。"
    ]
  },

  "framework/tests/cases/test_warehouse_craft.gd": {
    role: "迭代 1 船只系统测试：仓库存取、transit 重量、材料打造、免费安装、替换/卸下、合同解锁与失败原子性。",
    contracts: [
      "每个用例独立 bootstrap Core 并清空初始主线载荷，保证重量/容量可预测。",
      "覆盖仓库模块/材料 store+take、transit 计入总重量但不占货舱、打造仓库优先且计支出（下单不推进时间，等待后入仓）、旧件替换入仓、hull/boiler 不可卸下、重量上限拒绝、失败命令 state.hash 不变。",
      "合同解锁覆盖 medium/large 船体与打造锁定；重复货舱模块允许有空槽时购买。"
    ]
  },

  "framework/tests/cases/test_craft_wait.gd": {
    role: "迭代 2 打造订单测试：tier1 仅金币配方、下单不即时入库、port.wait/抵达结算与旧存档补齐。",
    contracts: [
      "覆盖 tier1 免材料可打造、金币不足 insufficient_money、订单 ready_at/remaining_hours 与 shipyard.view.orders。",
      "覆盖 port.wait 边界（hours 非法、不在港口、失败时 state.hash 不变）与等待后成品入下单港仓库。",
      "覆盖出航抵达时结算订单，以及 state.data 缺 shipyard_orders/order_serial 的旧存档补齐（含 float serial 归一化）。",
      "覆盖 shipyard_orders/order_serial 的 save→load hash 一致性。"
    ]
  },

  "framework/tests/cases/test_content_types_manifest.gd": {
    role: "content_types.json 与框架 ContentTypes / 本地 Schema 文件的一致性守护，防止单一真源在过渡期漂移。",
    contracts: [
      "校验 key 集合、singular、schema 路径、definition/patch 分类与 registry 标志。",
      "校验类型 key / singular / schema 唯一，分组、capability、aliases、default_file 字段完整，planned 类型不覆盖 active。",
      "校验 `v2_module_categories` 唯一且被类型引用；导航/安全必须同属 `utility`，且不存在独立的 active utility 类型。",
      "过渡期测试替代生成器；生成器接入后保留为回归测试。"
    ]
  },

  "framework/tests/cases/test_save_migration.gd": {
    role: "存档 Schema 2.0 迁移测试：v1 payload 加载为持久战役状态，v2 往返不迁移，缺失 campaign 回填，未知版本拒绝。",
    contracts: [
      "手写 1.0 payload 验证 save_schema → 2.0、state schema → 2.0、campaign/id/created_at/playtime 回填与 migrated_from 记录。",
      "验证 v2 写入/读取的 save_schema、state_schema、content_schema 与 state hash 往返一致。",
      "验证缺 campaign 的 2.0 payload 惰性补齐并产生 warning；3.0 等未知版本返回结构化错误。"
    ]
  },

  "framework/tests/cases/test_schema_v2_drafts.gd": {
    role: "Content Schema 2.0 草案测试：用现有 SchemaValidator 验证 start/world/region/site/route/weather/faction/discovery 草案，并守护草案类型不进入 active 注册表。",
    contracts: [
      "合法 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery envelope 必须零错误；缺字段、非法 ID、非法 difficulty、非法 cargo、越界概率、非法稀有度/权重必须报错。",
      "`draft_schemas` 中的类型必须出现在 planned、不得出现在 ContentTypes.all()，对应 Schema 文件必须存在。",
      "草案 Schema 只使用项目校验器支持的 JSON Schema 子集；正式接入运行时前保持 planned。"
    ]
  },

  "framework/tests/cases/test_campaign_state.gd": {
    role: "CampaignState 分区测试：分区惰性补齐、探索进度只追加 id、阵营声望夹取，以及分区随存档往返。",
    contracts: [
      "`ensure_campaign_sections()` 为 world/codex/factions 补齐默认结构；空状态也能安全读取，不抛异常。",
      "`mark_region_visited` / `mark_port_visited` / `discover_site` / `discover_codex` 幂等，返回是否新增；空 id 忽略。",
      "`set_faction_reputation` 夹取到 [-100,100]，未知阵营返回 0；空 faction id 不建条目。",
      "新局 `campaign.world.generated=true` 且起始港记入 visited_port_ids；save→load 后 state.hash 与进度一致。"
    ]
  },

  "framework/tests/cases/test_ui_shell.gd": {
    role: "迭代 2 主界面接线测试：把真实外壳场景挂进场景树，断言六条反馈在界面构建路径上真的生效，并守护通报文案的本地化。",
    contracts: [
      "首帧运行器让 `_ready` 正常投递，因此控件树（含 SNSectionHeader 等自行构建子节点的组件）与游戏内一致。",
      "覆盖信息条（当前港口 + 剩余载重/剩余舱容，反馈 5）、通关清单与两种提示分支（反馈 6）；期望值独立复算（RegistryHub 翻译 + ShipOps 重量/舱容 + printf），不使用被测 helper 自证。通关清单只在总览页渲染：船厂页断言不再出现 `ui.victory.plan_title`，改为出现「组件」分类入口。",
      "模块损耗可见性：健康船信息条不出现「部件」chip；对锅炉实例造成 50% 损耗后刷新，信息条出现「部件」chip 与「1 · 50%」，船厂船卡出现「受损部件」行与同一数值（期望文案来自 shell._tr 与实例状态，不用 UI helper 自证）。",
      "覆盖船厂下单按钮 → CraftOps 订单 → 在港等待按钮 → 时间推进与成品入下单港仓库（反馈 4，经由真实按钮 pressed 信号）；打造入口在改装态模块分类内，下单后重建的页面必须保持改装态与分类，24 小时等待按钮在「杂项」页签。",
      "场景接线断言覆盖独立总览、市场、委托、船厂、补给、情报、出航页面及四个菜单页面；船厂流程从 ShipyardScreen 的真实按钮驱动。",
      "流程场景接线覆盖港口记忆、抵达结算、航行中、航行事件与通关总结，逐一调用 Shell 构建入口并按脚本类型断言实例。",
      "覆盖设置/总览/市场/船厂/港口记忆密集字段禁用自动换行、市场与快照单元格最小宽度，以及情报矩阵固定元数据列、可扩展港口列、最小列宽和深色单元格背景。",
      "覆盖补给页损失带：买煤后水的 meter.loss_value/cap_loss 与 baseline 跨度（反馈 2）、情报页 SNIntelTable 与未知港口掩码（反馈 3，列数对照 MapOps.ports）。",
      "覆盖「航行记录」：真实下单 + 等待后在 zh 与 en 两种 locale 下逐行断言通报无 `%s/%d` 残留、无裸键，并与**逐语言写死的期望句子**相等（模板槽位互换照样能渲染，只有字面期望能抓住「某一种语言的文案说反了」；en 只写错顺序时该用例会失败）。",
      "扫描 domain/application 源码里所有 `push_notice(\"…\")` 字面量：每个键在 framework 或 core 的 zh_CN/en 中恰好被一套定义，两套 locale 的键集合与**保序**槽位序列一致；槽位多于一个的键必须出现在用例的逐语言字面期望清单里。",
      "组件按路径 preload，不依赖编辑器全局类缓存。"
    ]
  },

  "framework/tests/cases/test_shipyard_refit.gd": {
    role: "船厂界面重构契约测试（正常态 / 改装态）：三列布局、槽位与分类记忆、授权贴图与船卡缩略图、2.5D 渲染器替换钩子、拖拽安装，以及旧整页下方面板必须消失。",
    contracts: [
      "与 test_ui_shell 同一夹具：真实挂载 main.tscn 外壳并先 run.start，main.gd / 船厂页接线错误会在此失败；用例按脚本类型在 `_root_box` 里定位 ShipyardScreen。",
      "槽位数 = 4 + cargo_slots +（cabin_slots > 0 时 +1），与 `SNShipView._slot_targets` 数量一致；改装开启前贴片全部隐藏。",
      "正常态断言：stage 为 `EXTERIOR`、左列标题「已有船舶」、「组件」列提供六类入口、船卡显示当前船体名并预留缩略图区域（`SHIP_THUMB_SIZE` = 210×118），且页面恰好一个 ShipyardScreen。",
      "改装态断言：按本地化键 `ui.label.refit` 点真实按钮 → `_category == \"hulls\"`、stage 为 `CUTAWAY`、全部贴片可见、按钮改为「完成改装」；竖排 tab 含「杂项」。`shell._shipyard_refit` / `_shipyard_category` 让整页重建后仍恢复改装态与所选分类。",
      "贴图契约：`SHIP_VIEW_SCRIPT.SECTION_TEXTURE_PATH` 必须等于 `res://assets/ui/shipyard/ship_section.png` 且 `ResourceLoader.exists`；进入改装后 `has_section_texture()` 为真、`section_texture_size()` 两个分量 > 0。船卡缩略图断言 `_ship_thumb` 非空、页面仅有一个 TextureRect 使用它、占位文案不再出现。",
      "渲染器替换：正常态在 `ship.hull_model_path` 非空（或本地有旧路径回退）时挂载 `SNShipStage3D`（断言 `has_ship()`、改装态隐藏视口、回到 EXTERIOR 重新显示）；无模型时断言保留程序化占位。`set_renderer(provider)` 后节点挂到舞台下，`set_renderer(null)` 恢复内置占位。",
      "拖放端到端：`WarehouseOps.add_module` 在仓库放一个导航模块 → 操作列恰好一行可拖拽；`_on_slot_drop` 发 `ship.install_module`，参数含 module_id / source 与槽位 `replace_module_id`，命令后模块离开仓库并装到船上；异类型部件与 purchase 候选被 `_accepts` 拒绝。",
      "分类导航：每个分类的中间面板标题取 `ui.category.<type>`，货舱按槽位数逐个列出「货舱槽 n」；杂项承载打造订单/在港等待/仓库材料/仓库模块，且不再出现「按配方打造」「槽位」；打造入口留在对应模块分类内。",
      "旧面板守护：`LEGACY_SECTION_KEYS`（parts_hud / warehouse / available_modules / craft / recipes / victory plan 等本地化键）的译文不得出现在页面任意 Label 中；这些键必须仍被本地化，键被删时用例应失败而不是静默通过。`_body` 子节点数恒为 3。",
      "模块状态徽标：健康船不出现「状态 NN%」；对锅炉实例造成 50% 损耗后重建船厂页，锅炉槽位卡出现 `ui.label.status` 50% 徽标（条件值来自 shipyard.view 的 condition，不在页面计算）。"
    ]
  },

  "framework/tests/cases/test_ship_modules.gd": {
    role: "模块实例层测试：实例创建/补齐、condition 夹取与失效、安装替换重置状态、货舱对齐、damage_module 操作码、维修报价与存档往返。",
    contracts: [
      "新局每个已装模块都有唯一 instance_id 与满 condition；serial 覆盖全部实例。",
      "旧版 ship（只有扁平槽位键）调用 ensure 后补齐实例，重复 ensure 不改变 id 与 serial。",
      "damage 按比例扣减、0 处夹取并只在首次归零报告 newly_disabled；repair_all 恢复满状态并返回修复数；空/非法槽位返回结构化错误。",
      "货舱实例与扁平列表逐位对齐：追加补新实例、按位置删除保留幸存实例 id。",
      "单槽替换生成满状态新实例；damage_module 效果发布 ship.module_damaged，hull 不是合法槽位。",
      "维修报价把模块损耗折算成点数并抬高 cost，不伪造船体缺失；save/load 后 condition 与 instance_id 哈希一致。"
    ]
  },

  "framework/tests/cases/test_contract_refresh.gd": {
    role: "迭代 1 委托池测试：抵达刷新、持有上限、port.view 字段与同 seed 刷新确定性。",
    contracts: [
      "抵达后 offers 整池替换（instance_id 变化），main/main_offer/next_main_sequence 不受影响。",
      "active_limit = max(1, 1+reputation/2)，超限接取返回 too_many_contracts。",
      "port.view 暴露 active_limit/active_count/normal_holds/main_chain_complete。",
      "同 seed+命令序列重复抵达得到相同刷新池。"
    ]
  },

  "framework/tests/cases/test_victory.gd": {
    role: "迭代 1 通关测试：门槛、幂等颁奖、summary 完整性与安装触发。",
    contracts: [
      "主线未全完成或缺少大型船体/锅炉/货舱/造船厂时 check 不颁奖。",
      "满足时写入 victory 且再次 check 不重复颁奖；summary 含 §3.4 全字段。",
      "真实流程覆盖合同收入、工资、交易、情报与借款不计收入的统计口径。",
      "ship.install_module 成功安装大型船体时触发一次 run.victory_achieved。"
    ]
  },

  "framework/tests/cases/test_full_clear.gd": {
    role: "MVP 完整通关验收：脚本化玩家完成五段主线、中期升级、大型船组装并触发通关。",
    contracts: [
      "只经 CommandBus/QueryBus 操作，等价于 UI 可用操作；不直接写规则状态。",
      "覆盖 seed 4242 的详细总结断言，以及 111/222/333/444/555/666/777/888 的多 seed 通关回归。",
      "断言航次 ≤ 16、summary 字段完整、victory.view 与 state.victory 一致。",
      "导航按 BFS 逐段航行；缺钱时用普通委托/贷款兜底，缺补给时按预览购买煤水。"
    ]
  },

  "dev_scenes/harbor/harbor_diorama.tscn": {
    role: "独立 3D 港口样片场景：固定机位黄昏逆光，用已有 GLB 资产拼码头/吊车/货堆，前方浮一艘 1795 双桅纵帆船，水面使用自写着色器。",
    dependencies: ["assets/models/ships/SN_Schooner_Fame.glb", "assets/materials/water/harbor_water.tres", "dev_scenes/harbor/bobbing_boat.gd", "dev_scenes/harbor/harbor_diorama.gd"],
    contracts: [
      "不接入主场景：`project.godot` 的 `run/main_scene` 仍指向 `framework/ui/shell/main.tscn`。",
      "水面分两层：`Water` 为 500×400 细分网格（波动/泡沫/反射），`FarWater` 是下沉 3 m 的大平面，只输出地平线雾色，遮住主水面网格边缘。",
      "码头岸壁、护舷、爬梯、系缆桩、煤气灯、吊车、货堆与船体全部来自 `assets/models/`；仓库/烟囱/窗灯是场景内 BoxMesh 剪影，只做尺度参照。",
      "固定机位：`Camera3D`（fov 35）与 `Sun`/`Fill`/`WorldEnvironment` 都是场景内预置，不在运行时改。",
      "`ShipBob` 只控制姿态，船体 GLB 作为其子节点实例；水面泡沫环参数 `boat_*` 要与 `ShipBob` 的位置/朝向及新船长一致（half_size 13.2×3.9）。",
      "改 `Sun` 朝向时必须同步 `assets/materials/water/harbor_water.tres` 的 `sun_direction`，否则水面耀斑与光照方向不一致。",
      "船体当前实例 `SN_Schooner_Fame`（29 mesh / 13174 tri / 无星条旗），旧 `SN_Ship_Prototype` 仅保留为历史原型资产，不再出现在本场景。"
    ]
  },

  "dev_scenes/harbor/harbor_diorama.gd": {
    role: "港口样片根脚本：运行时给码头石墙套更暗的复制材质，压住黄昏逆光下的高光。",
    contracts: [
      "只改本场景实例的 `surface_material_override`，不改 GLB 导入材质。",
      "依赖 `SN_Dock_Wall` 的表面顺序：surface 0 = `SN_Stone`；改 GLB 材质顺序时需同步 `STONE_SURFACE`。"
    ]
  },

  "dev_scenes/harbor/bobbing_boat.gd": {
    role: "浮船：采样与水面着色器同源的波浪，驱动升沉、纵摇、横摇和极缓慢系泊漂移。",
    contracts: [
      "`SWELL_HEIGHT` / `WAVE_SPEED` 必须与 `harbor_water.gdshader` 的 `swell_height` / `wave_speed` 保持一致。",
      "只在 `_process` 写 `position` / `rotation`；`_base_position` / `_base_rotation` 在 `_ready` 缓存，改初始位姿请改场景里的 `ShipBob`。",
      "模型 +X 为船首、+Z 为右舷；横摇取负号，避免波面抬升一侧时船向反方向倾斜。",
      "不做航行/碰撞/物理，仅表现层。"
    ]
  },

  "assets/shaders/water/harbor_water.gdshader": {
    role: "港口水面空间着色器：顶点正弦波位移、噪声法线、菲涅耳天空反射、太阳耀斑路径、岸线与船体泡沫，以及远处雾色淡出。",
    dependencies: ["assets/textures/water/water_normal.png", "assets/textures/water/water_foam.png"],
    contracts: [
      "GL Compatibility 安全：不使用深度纹理/屏幕纹理，也不依赖光照 shadow map（`shadows_disabled`）；水面自身发光项负责主要观感。",
      "`swell_height` / `wave_speed` 与 `bobbing_boat.gd` 的常量同源；两边必须一起改。",
      "使用 `world_vertex_coords`，水面节点的世界变换应只有 XZ 平移，不要旋转或缩放。",
      "岸边泡沫只在水侧（世界 z > `shore_z`）生成；船体泡沫用椭圆近似，参数 `boat_center` / `boat_half_size` / `boat_yaw` 由场景材质维护。",
      "远处淡出到 `horizon_color`；`harbor_water_far.tres` 用同一 shader 并关掉波浪/细节/泡沫，保证两层水面在网格边缘颜色一致。"
    ],
    l2: {
      "swell(p, t) / swell_gradient(p, t)": [
        "三条方向、波数、相速不同的正弦叠加，返回约 [-1, 1] 的无量纲波高。",
        "顶点位移与片元坡度共用这一函数；改公式等于同时改船的采样。",
        "坡度用 ±0.8 m 的有限差分求得，用于构造世界空间法线，避免与顶点法线不一致。"
      ],
      "fragment()": [
        "先用法线计算菲涅耳反射与太阳耀斑，再用 `shore_z` / `boat_*` 生成泡沫，最后按相机距离淡出到地平线色。",
        "`ALBEDO` 只承担少量环境光，主要颜色放在 `EMISSION`；这样不受黄昏暖环境光和阴影质量影响。",
        "`light()` 只叠加太阳高光/宽高光，不重复对齐天空反射。"
      ]
    }
  },

  "assets/materials/water/harbor_water.tres": {
    role: "近处水面材质：港口样片的主水面参数（波浪、反射、岸线与船体泡沫、太阳方向）。",
    contracts: [
      "参数必须与 `harbor_water.gdshader` 的默认值同步；材质才是场景实际生效值。",
      "`sun_direction` 与场景 `Sun` 的朝向对应；`boat_*` 与 `World/ShipBob` 的位置/朝向对应。",
      "浮船为 SN_Schooner_Fame 时 `boat_half_size` 取 (13.2, 3.9)（船体 LOA 24.4 m），换船或改船体比例时同步。",
      "`shore_z` 是码头前沿水线（世界 z），`shore_span` 覆盖码头宽度。"
    ]
  },

  "assets/materials/water/harbor_water_far.tres": {
    role: "远处水面材质：同一 shader，关闭波浪/细节/泡沫与反射，只输出地平线雾色。",
    contracts: [
      "`horizon_fade_start` / `horizon_fade_end` 设为 0 / 0.001，让整层水面恒为 `horizon_color`。",
      "`horizon_color` 必须与 `harbor_water.tres` 一致，否则主水面网格边缘会出现色差。"
    ]
  },

  "tools/godot/verify_harbor_diorama.gd": {
    role: "港口样片验收（只读）：场景可加载、新浮船 SN_Schooner_Fame 在场景且旧船已移除、无星条旗、水面使用自定义着色器、浮船随波运动、未接入主场景。",
    contracts: [
      "先 `await process_frame` 再实例化并检查，保证 `_ready` 已执行、船的基础位姿已缓存。",
      "手动以 1/30 s 推进 `bobbing_boat._process` 60 次，避免依赖真实帧率与帧数。",
      "检查 `SN_Schooner_Fame` 实例存在、旧 `SN_Ship_Prototype` 不存在、纵帆船网格实例 >= 20 且名称不含 Flag。",
      "失败退出码 1；只读，不写场景/资源。"
    ]
  },

  "tools/godot/capture_harbor_diorama.gd": {
    role: "港口样片真实渲染截图（窗口模式）：加载 harbor_diorama.tscn，等水面/浮船稳定后抓固定 3/4 机位与纵帆船近景两张 1440×900 截图。",
    dependencies: ["dev_scenes/harbor/harbor_diorama.tscn"],
    contracts: [
      "必须窗口模式运行：`--headless` 时视口纹理为空，脚本直接判失败。",
      "等待 90 帧 + 1 s 后再抓第一张；近景把 Camera3D 移到 (30, 11, 34) 并对准船体中部。",
      "输出 `docs/design/screenshots/harbor_diorama_schooner.png` 与 `harbor_diorama_schooner_detail.png`；120 s watchdog；失败退出码 1。",
      "只写截图，不修改场景/源码。"
    ]
  },

  "tools/ui_snapshot.gd": {
    role: "船厂 UI 截图验收（真实渲染）：以与框架测试一致的 bootstrap 启动 Core，挂载 main.tscn，截取正常态 / 改装态 / 每个分类并断言模式与分类记忆。",
    contracts: [
      "必须窗口模式运行：`--headless` 时视口纹理为空，脚本直接判失败。",
      "参数走 `--` 之后：`--seed` / `--out-dir` / `--window` / `--category` / `--damage` / `--skip-refit`。",
      "`--damage=slot[:index]:ratio` 在 run.start 后用 `ShipModules.damage()` 损坏模块实例，额外截取 `shipyard_normal_damaged` / `shipyard_refit_damaged` / `supply_damaged`；只影响截图进程，不进入游戏逻辑。",
      "进入改装态优先点页面真实「改装」按钮，其次调 `_on_toggle_refit()`，最后按按钮文案兜底，页面小改版后工具仍可用。",
      "纯色画面判定为失败；120 s watchdog 防止协程中断挂住窗口；成功退出码 0，失败 1。",
      "只写 `docs/design/screenshots/`，不修改游戏状态或源码。"
    ]
  },

  "tools/capture_ui.ps1": {
    role: "`tools/ui_snapshot.gd` 的 PowerShell 包装：窗口 1440×900 跑真实渲染截图，并校验产物新鲜度。",
    contracts: [
      "引擎解析顺序：`-GodotBin` > `$env:GODOT_BIN` > 本机默认路径；找不到直接抛错。",
      "默认 seed 5201、输出 `res://docs/design/screenshots`、额外分类 `cargo_modules,misc`；`-SkipRefit` 只截正常态；`-Damage boiler:0.5` 额外生成受损状态截图并要求它们新鲜。",
      "检查每张期望截图存在且比本次运行新，旧图/缺图把退出码改为 1；完整日志写入 `.godot-ui-snapshot.log`。",
      "脚本保持 ASCII，兼容 Windows PowerShell 5.1 解析。"
    ]
  },

  "tools/art/gen_shipyard_textures.py": {
    role: "船厂两张授权贴图的确定性生成器：纵剖图 `ship_section.png`（1792×1008）与船卡缩略图 `ship_thumb_ironclad.png`（640×360）。",
    contracts: [
      "只依赖 Pillow + numpy；同一版本环境像素确定，几何/配色/构图锚点集中在文件顶部常量表。",
      "输出路径相对 `--out-root`（默认仓库根）：`assets/ui/shipyard/`；`--section-only` / `--thumb-only` 可单独重建。",
      "纵剖图不烘焙文字与 UI 边框；`ANCHORS` 必须与 `sn_ship_view.gd._chip_anchor()` 的舱室比例同步。",
      "缩略图从 `docs/design/screenshots/ironclad_broadside.png` 裁切并替换为 UI 调色板背景。",
      "重跑命令：`python tools/art/gen_shipyard_textures.py`；改完图不需要改页面代码。"
    ]
  }
};

export const MODULES = {
  "framework/bootstrap": {
    intro: "启动与组合根。负责在场景加载前完成内容加载，并向 UI/用例暴露 AppContext。",
    contracts: [
      "Autoload 与主场景的边界：Autoload 只做一次 Bootstrap，UI 只读 AppContext/Query。",
      "启动失败仍进入诊断界面，不允许开始游戏。"
    ]
  },
  "framework/core": {
    intro: "与引擎无关的小型基础设施：JSON、路径、SemVer、版本范围、稳定哈希、版本常量。",
    contracts: [
      "这些工具不得依赖 AppContext、GameState 或 Godot 场景树。",
      "确定性/安全性优先：不使用全局随机、平台相关排序或动态表达式。"
    ]
  },
  "framework/modding": {
    intro: "内容管线：扫描、Manifest、依赖、Schema、注册表、Patch、交叉校验与 Core 完整性。",
    contracts: [
      "模组是数据，不是代码；所有路径与扩展名经过 PathGuard。",
      "注册表在 UI/场景实例化前冻结。",
      "官方 core 与第三方走同一注册接口。"
    ]
  },
  "framework/application": {
    intro: "应用层：命令/查询总线、公共 API 注册、领域事件与用例（交易、委托、出航、船厂/仓库/打造订单、在港等待、通关）。",
    contracts: [
      "UI 与测试使用同一命令/查询入口。",
      "命令事务克隆提交；查询只读 ViewModel。",
      "船厂新增命令 ship.uninstall_module / ship.craft_module 与 warehouse.* 四个存取命令，均经 CommandRegistry 注册。",
      "迭代 2 新增 port.wait：在本港消耗时间并结算打造订单、推进 NPC 市场与债务期限。"
    ]
  },
  "framework/domain": {
    intro: "纯领域逻辑：航行、市场、委托、船只/模块实例/仓库/打造订单、地图、事件、债务与通关判定。",
    contracts: [
      "领域函数尽量输入确定、输出确定；随机必须来自 RngService 命名流。",
      "不读写文件、不创建 UI、不直接访问场景树。",
      "仓库/运输/打造只操作 GameState 纯数据；通关判定读取注册表合同与船只派生属性。"
    ]
  },
  "framework/services": {
    intro: "基础设施服务：日志、RNG、时钟、本地化、资源、存档。",
    contracts: [
      "服务不包含具体内容 ID。",
      "资源缺失/存档损坏只降级，不崩溃。"
    ]
  },
  "framework/state": {
    intro: "运行态数据模型。GameState 是唯一持久化状态，定义对象永不进入存档；含 campaign 分区（world/codex/factions）、探索进度、收入/支出/利润统计的惰性补齐。",
    contracts: ["GameState 可深克隆、可哈希，JSON 往返哈希一致。"]
  },
  "framework/ui": {
    intro: "展示层。固定 Shell、四个菜单场景、七个功能页、五个流程页与海图组件均已场景化；Shell 仅保留上下文解析、ViewModel 组合、导航、命令和转场。共享 Godot Theme、可复用控件与 UI Kit 展示场景保持统一视觉。船厂中央改装台（SNShipView）与部件 HUD（SNSlotTarget/SNPartRow）是独立可复用组件，未来 2.5D 渲染器经 set_renderer 接入。",
    contracts: [
      "UI 只识别 Query/Command 与定义类型，不识别 core 内容。",
      "公共视觉状态优先进入 Theme variation；业务页面只负责布局与数据绑定。",
      "页面场景不得直接持有 AppContext；查询、命令、跨页导航、全局提示与音效属于 Shell。"
    ]
  },
  "framework/tests": {
    intro: "无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、委托刷新、仓库存取、打造订单/替换/在港等待、船厂改装 UI、UI 外壳接线与完整通关流程。",
    contracts: [
      "测试入口：`godot --headless --path . --script res://framework/tests/test_runner.gd`。",
      "`test_case.gd` 提供断言与 Core 启动辅助；每个用例独立 bootstrap。",
      "测试源码可以引用 `core:*` ID；`test_no_core_ids.gd` 只扫描非测试框架代码。",
      "`test_full_clear.gd` 通过公开命令/查询脚本化跑完五段主线并组装大型船，覆盖 9 个 seed。",
      "`test_content_types_manifest.gd` 守护 `content_types.json` 与 `ContentTypes` / Schema 文件的一致性。",
      "`test_save_migration.gd` 守护 save schema 1.x → 2.0 迁移、campaign 元数据与分区回填。",
      "`test_campaign_state.gd` 守护 CampaignState 分区补齐、探索进度幂等与存档往返。",
      "`test_ship_modules.gd` 守护模块实例补齐/condition 失效/安装重置/货舱对齐/damage_module 操作码/维修报价与存档往返。",
      "`test_schema_v2_drafts.gd` 用当前 SchemaValidator 验证 `schemas/v2` 草案，并确认草案类型仍为 planned、不在 active 注册表。"
    ]
  },
  "sdk": {
    intro: "模组开发工具：打包、校验、模板与示例。",
    contracts: [
      "SDK 只使用公开框架接口，不依赖 core 私有路径。",
      "示例 `example_boilers` 通过普通注册表进入游戏。"
    ]
  },
  "schemas": {
    intro: "Manifest 与内容文件的 JSON Schema（项目校验器支持的子集）；`schemas/v2/` 存放 Content Schema 2.0 草案。",
    contracts: [
      "每类内容一个 envelope Schema；公共字段在 `common.schema.json`。",
      "1.x 类型继续使用根目录 Schema；2.0 草案在 `schemas/v2/`，由 `content_types.json.draft_schemas` 登记，尚未接入运行时加载。",
      "当前 2.0 草案：`common`、`start_profile`、`world_profile`、`region`、`site`、`route_template`、`weather_profile`、`faction`、`discovery`；对应类型仍为 planned。",
      "标准实体可选 `information.texture/model` 资源键；贴图与 GLB 模型属于展示信息，不替代 data 权威字段。",
      "Schema 的 `const`/`enum` 与 `ContentTypes`/操作码注册表需同步维护；效果操作码枚举（如 `damage_module`）必须与 `EffectOpRegistry` 同时增改，否则 core 校验会 fatal。"
    ]
  },
  "dev_mods/core": {
    intro: "官方 MVP 内容包：港口、商品、船只、模块、策略、岗位、委托、事件、地图与本地化；模块含打造配方/工时/费用，tier1 为仅金币配方（materials 为空）。",
    contracts: [
      "`manifest.json` 声明 required=true，内容文件 15 个，本地化 zh_CN/en。",
      "tier≥2 模块带 `craft_cost`；所有模块可带 `materials`/`craft_time_hours` 供 CraftOps 读取。",
      "两个造船厂港口（iron_harbor/free_town）市场限量出售精密齿轮，保证大型船材料在当局地图可获得。",
      "框架不得引用这里的具体 ID；所有引用由 Schema/交叉校验保证。",
      "修改数值只改 JSON，不改框架。"
    ]
  },
  "tools": {
    intro: "PowerShell 辅助脚本、Godot 验收 / 截图脚本、建模工单 / 参数化生成器与静态文档生成器。",
    contracts: [
      "`test.ps1` / `pack_core.ps1` / `capture_ui.ps1` 通过 `-GodotBin` / `GODOT_BIN` 定位引擎。",
      "`gen_static_docs.mjs` 读取 `static_docs_data.mjs` 生成 `docs/static/`。",
      "`ui_snapshot.gd` 必须窗口模式运行（`--headless` 时视口纹理为空），bootstrap 顺序与 `framework/tests/test_case.gd` 一致；只写 `docs/design/screenshots/`，失败退出码 1。",
      "`capture_ui.ps1` 是 `ui_snapshot.gd` 的包装入口：默认 1440×900、seed 5201、输出 `res://docs/design/screenshots`，并检查产物比本次运行更新（防旧图冒充验收）。",
      "`art/gen_shipyard_textures.py` 是船厂两张贴图的唯一真源：`python tools/art/gen_shipyard_textures.py` 可重建；纵剖图构图比例需与 `sn_ship_view.gd` 的 `_chip_anchor` 同步。",
      "`modeling/briefs/*.json` 是建模子代理的自包含工单；尺寸/预算/材质只改这里，不靠口述传递。",
      "港口设施锚点工单见 `modeling/briefs/sn_port_facilities_batch1.json` 与 `PORT_FACILITIES_PLAN.md`：6 件设施锚点，总预算 10500 tri，轴心统一在底面中心；工作台暂存排原定 y=60，因与 `SN_Ship_Modules`（y 58.6–69.2）冲突改为 y=75（见工单 layout_revision）。",
      "`modeling/generators/sn_port_facilities_generator.py` 是港口设施 6 件的几何唯一真源；`export_port_glb.py` 逐件归零导出 + 写 `.design/port/SN_<Name>.blend` 快照，`verify_port_glb.py` 纯 Python 复核单节点 / 调色板 / 尺寸 / 轴心 / doubleSided，`render_port_preview.py` 出逐件 3/4 预览。",
      "`modeling/generators/*.py` 是几何唯一真源：改了参数重跑即可重建，禁止手工摆点；`.blend` 只是产物。",
      "`modeling/generators/dryrun_props.py` 必须在进 Blender 前跑通（tri 预算 / 包围盒 / 边界边 / 退化面）。",
      "`modeling/dispatch.workflow.js` 必须串行派发：Blender 单实例，禁止 `parallel`/`pipeline` 并发建模。",
      "`godot/verify_props.gd` 是 GLB 导入的回归闸门，改动资产后必须重跑。"
    ]
  },
  "SNModMaker": {
    intro: "零依赖网页端模组制作器：原生 HTML/CSS/JS，从仓库 Schema 与 Core 索引生成表单、校验并打包模组。",
    contracts: [
      "运行时无第三方依赖、无构建步骤、无 CDN；经典 script 以支持 file://。",
      "Schema 与 Core 数据以仓库为唯一来源；`schema-bundle.js` / `core-index.js` 只由生成脚本产出。",
      "导出 JSON 与 Godot 加载链共享同一套 Schema；网页端不运行领域逻辑、注册表或 Core 完整性检查。",
      "实体 ID 修改只实时预览新多语言键，点击保存条目才原子迁移所有语言；模块类通过子分页切换。",
      "标准实体可配置贴图与 GLB 模型资源键，编辑器校验资源存在性与格式。",
      "所有导入内容都经过 HTML 转义、路径检查与 ZIP 体积/条目/CRC 限制。",
      "浏览器存储始终可用；`tools/serve.mjs` 运行时额外镜像到 `mods/`，导出可写入 `exports/`。",
      "`tools/content.mjs` 是无头 CLI，与网页端共用 `js/store.js` / `js/validate.js`；写回用 `tools/content_json.mjs` 保源编辑，写前按 SHA-256 检测并发修改。"
    ]
  },
  "dev_scenes": {
    intro: "独立 3D 样片场景（不接入主流程）：用于验证水面着色器、已有 GLB 资产拼接与固定机位构图。",
    contracts: [
      "`dev_scenes/` 不是游戏启动链的一部分；主场景仍为 `framework/ui/shell/main.tscn`。",
      "样片可以复用 `assets/` 与 `assets/models/`，但不得反向依赖 `framework/` 运行时。",
      "水面材质/着色器属于表现层资产，后续 `PortStage` 可以直接复用。"
    ]
  },
  "root": {
    intro: "仓库根：Godot 项目配置、README、路线图。",
    contracts: ["README 是开发入口；todo.md 维护阶段与验收状态。"]
  }
};

// Files that are intentionally documented only in their module README.
export const GROUPED_ROLES = {
  "dev_scenes/harbor/README.md": "港口样片运行方式、文件清单、水面实现要点、调参入口与已知边界。",
  "framework/core/stable_hash.gd": "FNV-1a 稳定哈希与命名流种子派生。",
  "framework/core/framework_info.gd": "框架版本、Mod API 版本与能力常量。",
  "framework/bootstrap/framework_runtime.gd": "进程退出前清理静态操作码/公式注册表。",
  "framework/services/clock_service.gd": "游戏时间格式化、天数/小时与时长工具。",
  "framework/application/result.gd": "统一 `{ok,error_code,message_key,data,events}` 结果构造。",
  "framework/application/framework_api.gd": "注册全部命令与查询。",
  "framework/modding/mod_source.gd": "模组来源抽象基类。",
  "framework/modding/dir_mod_source.gd": "松散目录来源：递归列文件、读文本/字节、资源前缀。",
  "framework/modding/mod_package.gd": "扫描期包对象：来源、Manifest、错误/警告、启用状态。",
  "framework/modding/registries/registry_hub.gd": "按类型持有注册表并统一冻结/计数。",
  "framework/application/commands/command_registry.gd": "命令名到静态用例的绑定表（含船厂/仓库/打造/在港等待命令）。",
  "framework/application/queries/query_registry.gd": "查询名到 ViewModel 构造器的绑定表（含 shipyard/victory）。",
  "framework/application/commands/run_start.gd": "run.start 命令：调用 RunFactory 并写回状态/随机流。",
  "framework/application/commands/trade_commands.gd": "trade.buy / trade.sell 命令包装与市场事件。",
  "framework/application/commands/supply_commands.gd": "按市场价购买煤水与维修命令包装。",
  "framework/application/commands/intel_commands.gd": "情报刷新命令：设施、费用、快照。",
  "framework/application/commands/debt_commands.gd": "借款命令包装。",
  "framework/application/commands/contract_commands.gd": "委托接取命令包装。",
  "framework/application/commands/voyage_commands.gd": "预览/出航/事件选择命令包装。",
  "framework/application/queries/app_view.gd": "启动与菜单 ViewModel：状态、模组、计数、构筑、命令列表。",
  "framework/application/queries/map_view.gd": "海图 ViewModel：港口坐标、发现/访问、设施与航线。",
  "framework/application/queries/voyage_preview.gd": "出航预览查询包装。",
  "framework/tests/test_case.gd": "测试断言与 Core bootstrap 辅助。",
  "framework/tests/test_runner.gd": "无头测试发现、执行、汇总与退出码；首个渲染帧上运行，使 UI 套件能把外壳场景真正挂进场景树（含 test_shipyard_refit 改装 UI 套件）。",
  "framework/tests/cases": "按主题拆分的 135 个测试（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。",
  "framework/tests/smoke_load.gd": "手动冒烟：加载 Core 并打印启动报告。",
  "framework/tests/smoke_play.gd": "手动冒烟：开局、预览、出航、事件选择。",
  "sdk/templates": "模组模板：Manifest、商品、双语本地化与说明。",
  "sdk/examples": "第三方锅炉示例，验证公共内容接口。",
  "schemas/v2": "Content Schema 2.0 草案：common 与 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery；仍为 planned，暂不接入运行时加载。",
  "schemas": "JSON Schema 文件（Manifest/common/15 类内容）。",
  "dev_mods/core": "官方 Core 内容文件（manifest/content/localization/assets）。",
  "tools/modeling/generators": "铁港道具参数化生成器与流水线工具：每批一个自包含生成器（纯几何函数，可离线干跑），配套干跑校验、GLB 导出、P0 整改与归档脚本。全部入库，改参数即可重建全部几何。",
  "tools/modeling/generators/sn_iron_harbor_batch2_generator.py": "铁港第二批 6 件生成器（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆）。",
  "tools/modeling/generators/sn_iron_harbor_batch3_generator.py": "铁港第三批 6 件生成器（木料堆/麻袋堆/蒸汽管/缆绳卷/吊货网/托盘）。",
  "tools/modeling/generators/sn_iron_harbor_batch4_generator.py": "铁港第四批 6 件生成器（浮标/锚链堆/绞盘/手推车/碰垫/齿轮箱）。",
  "tools/modeling/generators/sn_iron_harbor_batch5_generator.py": "铁港第五批 7 件生成器（石阶/港口牌/钟/旗杆/煤溜槽/锅炉/龙骨墩）。",
  "tools/modeling/generators/sn_mooring_bollard_generator.py": "系缆桩生成器（十字桩头 + 方形法兰板 + 四螺栓 + 喇叭脚柱身）；单件 API，不走 dryrun_props。",
  "tools/modeling/generators/dryrun_props.py": "通用纯 Python 干跑：把 bpy/bmesh 换成空壳加载生成器，离线校验 tri 预算、包围盒、边界边/非流形边/退化面。",
  "tools/modeling/generators/dryrun_batch2.py": "第二批专用干跑（dryrun_props.py 的前身，保留兼容）。",
  "tools/modeling/generators/export_props_glb.py": "道具 GLB 导出：逐件把 location 临时归零、只导出选中对象、导出后还原；按批次分组避免无谓重导。",
  "tools/modeling/generators/p0_rework_2026-10-19.py": "第一批 P0 整改：重建系缆桩 → SN_Ore 改锈红 → 三段岸壁拼接测试。",
  "tools/modeling/generators/p0_finalize.py": "P0 归档：备份旧 GLB → 清临时对象 → 导出 → 保存工作台。",
  "tools/modeling/generators/sn_port_facilities_generator.py": "港口设施锚点第一批 6 件生成器（市场棚 / 告示板 / 水箱 / 信号塔 / 龙门吊 / 干船坞）：纯几何函数可离线干跑，单件一个 mesh、原点在底面中心，集合 SN_Port_Facilities，合计 5044 tri；本批新增 SN_Iron。",
  "tools/modeling/generators/export_port_glb.py": "港口设施 GLB 归档：备份旧 GLB → 保存工作台 → 逐件 location 归零导出 `assets/models/port/SN_<Name>.glb` → `libraries.write` 单件 `.blend` 快照 → 还原摆位；人工验收后由 Lead 运行。",
  "tools/modeling/generators/verify_port_glb.py": "港口设施 GLB 结构自检（纯 Python）：单节点/无相机灯光贴图、三角面 ≤1.2× 预算、glTF Y-up 包围盒换算与 items.size 误差 ≤0.1 m、轴心在底面中心、材质在调色板且 doubleSided。",
  "tools/modeling/generators/render_port_preview.py": "港口设施预览渲染：临时相机/双太阳/深色世界，逐件 3/4 与正视 + 一排总览 + 船厂组总览，干船坞单独抬高机位看坞内台阶；渲染后还原场景并删除临时对象。",
  "tools/modeling/generators/sn_paddle_freighter_generator.py": "明轮货轮参数化生成器：铁壳船身 + 两舷明轮（14 桨叶/8 辐条/双轮缘/内加强环/斜撑）+ 半包轮罩箱板（观察窗/端封让开轮扫掠）+ 双烟囱 + 三岛甲板 + 艏艉楼侧封板 + 货舱吊杆，全部几何由顶部参数表重建（预算 ≤14000 tri）。",
  "tools/modeling/generators/sn_paddle_steamer_generator.py": "小型明轮蒸汽船（PS Enterprise 参考）参数化生成器：24 m 白漆内河船身 + 两舷 10 桨叶明轮 + 梯形格栅轮罩 + 前驾驶室（ENTERPRISE 文字铭牌）+ 后部雨棚游步甲板 + 黑烟囱 + 艏旗杆澳洲旗 + 艉部弧形平台/舵；蒸汽不建模（留给游戏内 VFX），预算 ≤12000 tri，几何全部由顶部参数表重建。",
  "tools/modeling/generators/sn_schooner_fame_generator.py": "1795 年 Salem 双桅纵帆船 SN_Schooner_Fame 参数化生成器：18 站放样黑船身 + 赭黄上舷带 + 双桅后倾（Fore -2.5° / Main -3.2°）+ 斜桁帆/方顶帆/三角顶帆 + 两面艏三角帆 + 舷侧绳梯/支索/动索 + 甲板属具（舱口/绞盘/舵轮/罗经柜/锚/木桶/盘绳/fife rails/短梯）+ 艉廊/3 窗/FAME 铭牌 + 红白长旒；帆腹镜像到 -Y（Godot +Z 相机侧），预算 ≤18000 tri。",
  "tools/modeling/generators/ship_parts": "可复用船体部件库 v1：core（Part/基本体/PartSpec）/ deck（甲板属具）/ bow（艏斜桁/艏饰）/ stern（艉廊）/ assembly（Blender 装配与 report）；生成器只保留船型布局，重构后纵帆船输出逐对象 digest 不变。",
  "tools/modeling/generators/ship_parts/core.py": "部件库核心：Part 数据容器、向量/基本体/放样/镜像工具、PartSpec 装配契约、tri_count；纯 Python，不 import bpy。",
  "tools/modeling/generators/ship_parts/deck.py": "可复用甲板属具构建器：舱口/天窗/绞盘/起锚机/舵轮/罗经柜/钟/木桶/盘绳/缆柱/水桶/fife rail/短梯；位置与甲板高度由调用方传入。",
  "tools/modeling/generators/ship_parts/bow.py": "可复用艏部构件：艏斜桁/jibboom 铁箍、雕刻艏饰（黄铜卷饰+赭黄胸像）；船体主色由调用方传入。",
  "tools/modeling/generators/ship_parts/stern.py": "可复用艉部构件：艉廊/3 艉窗/檐口/双艉灯；x0/x1/窗位/灯位/主色由调用方传入。",
  "tools/modeling/generators/ship_parts/assembly.py": "可复用 Blender 装配层：BuildConfig/PivotSpec、清理/集合/材质/空物体/文字铭牌/report；bpy 只在函数内 import，干跑可安全加载生成器。",
  "tools/modeling/generators/ship_parts/palette.py": "跨船共享材质名常量（木/深木/甲板木/帆布/金属/黄铜/旗帜色）；船体主色由各船生成器定义。",
  "tools/modeling/generators/ship_parts/README.md": "可复用部件库使用说明与部件契约：分层、新增部件步骤、坐标/材质约定、输出不变的验收口径。",
  "tools/modeling/generators/ship_parts/__init__.py": "部件库入口：导出 Part/PartSpec/tri_count 与 assembly/deck/bow/stern 子模块；约定纯几何不依赖 bpy。",
  "tools/modeling/generators/dryrun_schooner_fame.py": "纵帆船纯 Python 干跑：对 FORE/MAIN 子件施加 pivot 世界变换后核对 tri/bbox/边界边/非流形/退化/孤立点/材质/命名/父级，并断言两桅轴距 6.4 m、双桅后倾与主桅更高（R1 P0 回归护栏）。",
  "tools/modeling/generators/export_schooner_fame_glb.py": "纵帆船 GLB 归档：备份旧 GLB → 保存工作台 → 根节点临时归零导出 → `bpy.data.libraries.write` 船体快照（不切文件）→ 还原 (0,-70,0) 并重存工作台。",
  "tools/modeling/generators/verify_schooner_fame_glb.py": "纵帆船 GLB 结构自检（纯 Python）：32 节点/29 网格/12 doubleSided 材质/13174 tri/glTF Y-up 包围盒 33.44×26.85×6.88/水线轴心 −2.74。",
  "tools/modeling/generators/render_schooner_fame_preview.py": "纵帆船预览渲染：临时相机/双太阳/深色世界/临时水面，输出 3/4、正侧、艏 3/4、艉 3/4、俯视 5 张入库截图，渲染后还原场景并删除临时对象。",
  "tools/modeling/generators/dryrun_paddle_steamer.py": "明轮蒸汽船纯 Python 干跑：空壳替换 bpy/bmesh 后核对 tri 预算、包围盒/Z 范围、边界/非流形边、退化面、孤立点、材质名单、父级键与左右镜像误差。",
  "tools/modeling/generators/render_paddle_steamer_preview.py": "明轮蒸汽船预览渲染：临时相机/双太阳/深色世界/临时 matte 水面，输出 3/4、正侧、艏、艉 3/4、俯视 5 张入库截图，渲染后还原场景并删除临时对象。",
  "tools/modeling/generators/verify_paddle_steamer_scene.py": "明轮蒸汽船场景只读验收：集合/命名/层级/Pivot/包围盒/tri/材质槽/网格健康/明轮 8 旋转角与轮罩·船体·明轮台世界坐标 BVH 交面/左右镜像/连通岛悬空/工作台回归，输出 JSON。",
  "tools/modeling/generators/export_paddle_steamer_glb.py": "明轮蒸汽船 GLB 归档：备份旧 GLB → 保存工作台 → 根节点临时归零导出 → libraries.write 船体快照（不切文件）→ 还原 (45,0,0) 并重存工作台。",
  "tools/modeling/generators/verify_paddle_steamer_glb.py": "明轮蒸汽船 GLB 结构自检（纯 Python）：节点/网格数、8 材质 doubleSided、tris=11764、glTF Y-up 包围盒与 −1.32 m 水线轴心，并拒绝蒸汽几何泄漏。",
  "tools/modeling/generators/dryrun_ship.py": "船只生成器纯 Python 干跑：空壳替换 bpy/bmesh 后加载生成器，核对 tri 预算、包围盒、边界/非流形边、退化面、材质名与父级。",
  "tools/modeling/generators/export_ship_glb.py": "船只 GLB 归档：备份旧 GLB → 保存工作台 → 导出（临时归零 SN_PF_Root）→ 写船体快照；人工验收后由 Lead 运行。",
  "tools/modeling/generators/verify_ship_glb.py": "船只 GLB 结构自检（纯 Python，不进 Blender/Godot）：读 GLB 头 + JSON chunk 核对节点/网格/材质 doubleSided/三角面/包围盒与轴心。",
  "tools/modeling/briefs/sn_ship_paddle_steamer.json": "小型明轮蒸汽船工单：24.4 × 8.7 × 10.5 m、≤12000 tri、8 材质、明轮 10 桨叶/轮罩 10 道格栅、驾驶室 ENTERPRISE 铭牌；明确蒸汽不建模（游戏内 VFX）、明轮 8 旋转角零穿模与水线轴心验收。",
  "tools/modeling/briefs/sn_schooner_fame.json": "1795 Salem 双桅纵帆船工单：船体 LOA 24.4 m / 总长 33.44 m / 总高 26.82 m、≤18000 tri、12 材质、双桅后倾/斜桁帆/方顶帆/艏三角帆/完整索具/艉廊 FAME 铭牌；用户 2026-10-19 明确不要星条旗，只保留红白长旒；帆腹朝 -Y。",
  "tools/modeling/briefs/_template.json": "建模工单模板：字段说明与必填项。",
  "tools/modeling/briefs/sn_ship_prototype.json": "帆船原型工单（三桅六帆低模）。",
  "tools/modeling/briefs/sn_paddle_freighter.json": "明轮蒸汽货轮工单：59.5 × 14.1 × 19.5 m、≤14000 tri、33 个必做部件的尺寸 / 材质 / 命名约定；含明轮轮系、半包轮罩、艏艉楼侧封板与 15 对零交面验收。",
  "tools/modeling/briefs/sn_harbor_crane.json": "港口塔吊工单（锤头式，含回转枢轴与吊钩层级）。",
  "tools/modeling/briefs/sn_iron_harbor_batch1.json": "铁港第一批 6 件道具工单（岸壁/护舷/系缆桩/木箱/木桶/矿堆，y=24）。",
  "tools/modeling/briefs/sn_iron_harbor_batch2.json": "铁港第二批 6 件工单（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆，y=30）。",
  "tools/modeling/briefs/sn_iron_harbor_batch3.json": "铁港第三批 6 件工单（堆场/管线，y=36）。",
  "tools/modeling/briefs/sn_iron_harbor_batch4.json": "铁港第四批 6 件工单（机械/水上件，y=42）。",
  "tools/modeling/briefs/sn_iron_harbor_batch5.json": "铁港第五批 7 件工单（结构/标识/动力，y=48）。",
  "tools/modeling/briefs/sn_port_facilities_batch1.json": "港口设施锚点第一批工单：市场棚 / 告示板 / 水箱 / 信号塔 / 龙门吊 / 干船坞，总预算 10500 tri；工作台暂存排原定 y=60，因与 SN_Ship_Modules 冲突改为 y=75（layout_revision）。",
  "tools/modeling/briefs/PORT_FACILITIES_PLAN.md": "港口设施锚点建模总表：设施→锚点映射、尺寸/tri/材质、已有道具复用、PortStage 装配与验收约定。",
  "tools/modeling/briefs/IRON_HARBOR_PLAN.md": "铁港小部件 31 件 / 5 批的工单总表、布局、材质与已知坑。",
  "tools/modeling/dispatch.workflow.js": "批量派发脚本：串行 Builder + 独立 Verifier，脚本内不落盘（导出由 Lead 在人工验收后执行）。",
  "tools": "PowerShell 测试/打包脚本与静态文档生成器。",
  "SNModMaker/README.md": "使用说明、数据流、开发约定与已知边界。",
  "SNModMaker/WORKSPACE.md": "原生工作区使用说明：启动本地服务、在编辑器里直接编辑 dev_mods/core、保存边界与发布前校验。",
  "SNModMaker/mods/README.md": "磁盘工作区说明：每个模组目录的结构与 .snmodproj.json。",
  "SNModMaker/exports/README.md": "本地导出目录说明：ZIP 命名与忽略规则。",
  "SNModMaker/js/schema-bundle.js": "自动生成：嵌入 `/schemas/*.schema.json`。",
  "SNModMaker/js/core-index.js": "自动生成：Core 定义、内容与双语本地化索引。"
};
