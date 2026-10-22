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

  "docker-compose.yml": {
    role: "SNModMaker 的 Docker Compose 部署：构建零依赖镜像，数据持久化到命名卷 `snmodmaker-data`，只发布到宿主机 loopback。",
    contracts: [
      "`ports` 固定 `127.0.0.1:${SNMODMAKER_PORT:-8099}:8099`；远程访问由宿主机 `tailscale serve --bg 8099` 提供 HTTPS，不要用 tailscale funnel。",
      "`snmodmaker-data` → `/app/data`：容器内保存项目、导出、部署包与空的工作区根，不挂载宿主机仓库，因此不会改 `dev_mods/core`。",
      "healthcheck 用 Node 内置 fetch 探测 `/api/status`；静态文件变更后需重新 build 镜像。"
    ]
  },

  ".github/workflows/release.yml": {
    role: "`v*` tag 触发的发布流水线：测试 → core 校验 → 导出 Windows/Linux → 打包标准便携目录 → GitHub Release。",
    contracts: [
      "发布前运行 `sdk/validate.gd`；core manifest 声明的内容 / 本地化 / 资产缺失时直接失败。",
      "发布前运行 `gen_content_types.mjs --check`，防止框架常量或编辑器类型目录落后于 `content_types.json`。",
      "发布前运行 `gen_static_docs.mjs --check`，防止源码注释、sidecar 或符号位置变化后漏提交 `docs/static`。",
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
      "stats 来自 GameState.stats()（收入/支出/利润惰性初始化），不返回 ContentDefinition 或 GameState 内部引用。",
      "`current_port` 额外给出 `archetype_id` 与 `size`（默认 medium），供 2D/2.5D 舞台选择港口构图与设施尺度。",
      "`ship.hull_model_key` 取船体定义的 `information.model`；`ship.hull_model_path` 经 `context.assets.resolve()`（`_asset_path`）转成物理路径，供 PortStage 直接加载内容模组 GLB；缺资产时为空串。",
      "`current_port.diorama` 读取 world 里持久化的 `diorama` 块；旧存档/world 快照没有该块时按 `archetype_id` 从 `core:port_archetype/*` 的 `data.diorama` 回填（`kit/town/facility_visuals/palette/landmark`）。",
      "`current_port.town_visuals` 由 `_resolved_town_visuals(context, source_mod, diorama)` 解析：把 `diorama.town` 的 slot → `model.prop.*` 资产键转成 `asset://<mod>/<key>` 并 `assets.resolve()` 成物理路径；缺键省略，PortStage 对缺失 slot 回退 blockout。"
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
      "所有随机来自 `map_generation` 命名流；不使用全局 randf/shuffle。",
      "生成的每个港口把所选原型的 `diorama` 深拷贝进 world 港口数据（与 `archetype_id/source_mod/banner_asset/facilities/size` 一起持久化），供 PortStage 的 town kit 使用；旧存档缺少该字段时由 port.view 按原型回填。"
    ],
    l2: {
      "_try_generate(profile, profile_data, hub, rng, ship, attempt)": [
        "港口数与边数从 profile 范围抽样；起点原型按 start_archetype_tags 选择。",
        "先分配起点，再为每个必需设施标签选择最近未分配节点；剩余节点随机补原型。",
        "写港口数据时复制原型 `data.diorama`（含 `kit/town/facility_visuals/palette/landmark`），之后由 port.view 解析成舞台可用的 `town_visuals` 路径。",
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
      "`find_key(asset_key)` 按裸键（如 `icon.money`）在已注册资产中按排序确定性扫描，返回首个 `asset://<pack>/<key>`；框架 UI 用它解析可选图标，不硬编码 mod 命名空间，未命中返回空串。",
      "`load_texture()/load_model()`：框架资源走 `ResourceLoader`，模组内原始 `.png/.glb`（挂载包或松散目录）走 `ContentAssetLoader`；失败返回 null，调用方保留 2D 回退。"
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
    role: "可玩 UI 组合根：解析上下文、查询 ViewModel、执行命令、处理导航/转场，并把已迁移页面挂载到场景宿主；主界面采用「全窗 3D 港口舞台 + 紧凑顶部 chrome + 两侧设施招牌 + 底部状态条 + 详细总览抽屉」的 Bounty Train 式分层，2D 总览保留为回退/可访问性开关。自第七切片起总览/市场/补给三页共用同一座连续 3D 港区：页面切换只是平移镜头、把玩家的船开到对应泊位并换上右侧泊位面板，不重挂舞台、不过黑场；市场/补给页改为右侧 640 px 泊位面板，左侧保留舞台。",
    contracts: [
      "所有数据经 QueryBus 获取，所有修改经 CommandBus；UI 不保存规则状态。",
      "主界面默认 `_overview_stage_mode=true`：全窗 3D 港口舞台是主视图，2D 详细总览收进 `_overview_detail` 抽屉（默认关闭）；两者都只是 UI 会话状态，不写存档。",
      "紧凑顶部 chrome（`_top_chrome`）用两行替代旧 header + stats bar + navigation：第 1 行品牌/状态/版本 + 港口·时间·金钱·声望 + 阶段切换/诊断/刷新，第 2 行剩余载重·货舱·煤·水·耐久·受损 chip + 6 个导航按钮 + 海图切换按钮；半透明面板，实测最小高度 ≤130 px（`TOP_CHROME_MAX_HEIGHT`）。",
      "HUD 图标：`_stat_chip(..., icon_key)` 在标签左侧挂 22 px `TextureRect`；`_hud_icon()` 经 `AssetService.find_key()` 把 `icon.money/coal/water` 解析到任一内容包并缓存 `Texture2D`，缺 key/缺文件时退回纯文字 chip。金币在顶部 chrome，煤炭/淡水同时在顶部与底部状态条。",
      "窗口适配：工程为 `canvas_items` 拉伸（1440×900 基准）+ `expand` 宽高比，真实窗口的逻辑宽度恒 ≥1440（960×540 → 1600×900），因此 HUD 与招牌按同一份完整布局整体缩放，不设删信息/缩控件的 compact 分支；960×540 截图验证缩放后不裁切。",
      "设施招牌由 `SNHarborSign`（`sn_harbor_sign.gd`）承载：`_port_sign()` 调 `configure(text, primary, facility, arrow)` 写木板/铁框/黄铜铆钉/徽记/箭头/悬停光晕，`Button` 语义与 `text`/tooltip 保留；招牌固定 172×42、边距 20。",
      "main.tscn 静态声明背景、菜单遮罩、滚动内容根、页脚、音频与 TransitionLayer；main.gd 通过 @onready 绑定，不再在运行时创建固定外壳。",
      "已迁移页面由 PackedScene 实例化：Shell 负责查询并调用 bind，页面只发 command_requested/navigation_requested/action_requested 意图，不接触 AppContext。",
      "每个功能有独立界面，通过顶部导航切换；面板分别构建完整 ViewModel，不把所有信息挤在同一滚动页。",
      "每轮命令后整页重建；选项/目的地/构筑选择保存在 UI 成员。",
      "每个 PanelContainer 只允许一个 VBoxContainer 内容容器；面板子节点必须经 `_panel_add()` 添加，避免多子节点互相重叠。",
      "海图是独立的切换页（`M` 键 / 顶栏「海图」/ 状态条「海图 ▶」/ 港口招牌），不占用导航按钮；4.3.4 起出航准备页已删除，面板「启航」与线索「循线索出航」统一打开页内确认弹窗（预估 + 锅炉策略切换 + 取消/启航），确认后才执行 `voyage.start` / `explore.start`。",
      "确认弹窗状态 `_chart_departure = {kind, target_id, strategy_id}` 只存在于 Shell 会话；`_chart_departure_strategy()` 依次取弹窗选择 → 上次确认的策略 → `strategy.standard` tag，策略切换后重新查询 `sea_chart.view` 并重开弹窗。",
      "连续消耗（4.3.5 / U8）：出航确认后领域只扣工资；演出期间 `_presentation_voyage` 的 `departure_coal/water` 与 `coal_rate/water_rate` 驱动顶栏煤 / 水 chip 逐帧插值（`_update_presentation_resources()`，只改 Label 文本、不写 state），抵达 / 漂流 / 掉头时领域按实际航行小时一次性落账，重建后的 chrome 回到真实读数。",
      "总览页由独立 overview_screen.tscn 承载；Shell 解析横幅资产、委托摘要与通报文本，页面组合港口/目标/船只/快捷操作/财务面板并发出导航或命令意图；4.3/U6 起详细总览不再挂旧线稿海图。",
      "启动主菜单使用全屏港口背景；进入游戏后保留顶部导航，并用共享 Theme 的徽标/章节标题/资源条构建信息层级。",
      "总览港口横幅通过 Core manifest 的 `banner.port.*` 资产键与 `banner_asset` 字段解析；无横幅港口退回普通面板。",
      "市场页由独立 market_screen.tscn 承载；Shell 组合 port.view 市场数据与 intel.view 趋势，页面发出 trade.buy/trade.sell 意图。",
      "委托页由独立 contracts_screen.tscn 承载；Shell 补充直达性、解锁名称和已完成名称，页面发出 contract.accept 或打开海图（预选目的港）的导航意图。",
      "补给页由独立 supply_screen.tscn 承载；Shell 查询 supply.view、注入本地化回调并统一执行页面发出的 supply.* 命令。",
      "情报页由独立 intel_screen.tscn 承载；Shell 查询 intel.view，页面组合 SNIntelTable 并发出 intel.refresh 意图。",
      "海图出航确认：`_chart_departure_model()` 在 Shell 侧组装目标名、策略列表（已翻译）、`voyage.preview` / 线索预估与 blockers；`SNVoyageConfirm` 只渲染并发出 confirmed/cancelled/strategy_changed，Shell 随后直接执行 `voyage.start` / `explore.start`（4.3.4 / U7）。",
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
      "反馈5：紧凑 chrome 固定显示当前港口（在航时显示“在航 → 目的港”）、剩余载重 free_weight/max_weight 与剩余货舱 free_cargo_capacity/cargo_capacity；总览底部状态条再显示耐久/货舱/煤/水/受损/最新通告，避免信息只存在于详细抽屉。",
      "反馈6：总览“当前目标”显示通关条件清单（主线 n/5 → 大型船体 → 锅炉 → ≥1 货舱 → 造船厂组装），主线完成后给出下一步提示；数据来自 port.view.victory.conditions 与 contracts.main_done/main_total。船厂页不再重复通关清单，只做组件分类入口。",
      "反馈3：情报页用 SNIntelTable 渲染 intel.view 的 columns/rows 矩阵（含未知港口列），替代旧的逐港商品表格。",
      "反馈4：打造订单与在港等待迁入船厂改装态「杂项」页签：等待按钮按 wait_options 生成 6/12/24 小时 `port.wait`，总览快捷入口同样提供等待按钮；模块类分类内保留「按配方打造」，打造按钮文案带工时。",
      "反馈2：补给卡绑定 SNSupplyCard 时传入 _tr 回调，显示“上限损失/剩余可装”本地化文案。",
      "`_notice_text(notice)` 用 `_format_slots(template)`（`%[sd]` 正则、保序）取槽位：字符串参数先按本地化键解析，再按 push 顺序 `template % args`；槽位数与参数数不符、或 `%d` 槽位对应参数不是 int/float 时原样返回模板而不报格式错误；缺键时返回键名。空模板 / 无参数 / 无槽位直接返回模板本身，「航行记录」由此渲染成句。通知文案本地化由 test_ui_shell 的两个用例守护（真实渲染 + 源码 `push_notice` 键扫描，中英槽位序列保序一致）。",
      "总览 3D 港口舞台由 Shell 持有：`PORT_STAGE_SCENE_PATH`（`port_stage.tscn`）懒加载，`PORT_STAGE_FACILITY_SCREENS` 映射设施→页面（exchange→market / contracts / supply / intel / shipyard）；`_overview_stage_mode` 默认 true（3D 是主视图），`_overview_detail` 默认 false。",
      "连续港区：`STAGE_SCREENS = {overview→harbor, market→market, supply→supply}` 把页面映射到同一港区的三个相邻站位；`_stage_station` / `_stage_framing` 记录当前镜头站，overview 用 `stage` 构图，market/supply 用 `panel` 构图（右侧 640 px `DOCK_PANEL_WIDTH` 面板）。",
      "`_focus_stage_station(station, framing, immediate)` 只在舞台已挂载后调 `PortStage.focus_station()`；重设当前站位是 no-op，所以整页重建不会重启动画。`_stage_backed_page()` 判断当前页是否该用泊位面板（舞台场景可用时）。",
      "市场/补给页的泊位面板：`_mount_dock_panel(screen)` 建 `DockPanelRow`（左 expanding `StageWindow` + 右 `PanelContainer(DockPanel, SNPanel, ≥640 px)`），页面放进面板；舞台不可用时退回原来的全宽页面。",
      "站位间导航不播放全屏淡出：`_on_nav()` 在 `from` 与目标都属于 `STAGE_SCREENS` 且场景可用时 `_refresh(false)`，让镜头平移与船体航行可见；离开到 contracts/intel/shipyard 等非舞台页仍走 `_refresh(true)` 淡入淡出。",
      "舞台宿主 `_port_stage_host` 为全窗 `SNStageHost`，放在 `Background` 之上、所有 UI 之下；两侧招牌层 `_port_hotspot_layer` 放在 `PageMargin` 之后，层本身 `MOUSE_FILTER_IGNORE`，只有招牌按钮吃点击；详细抽屉打开时另有一个 `_overview_detail_backdrop` 盖住舞台。",
      "`_sync_port_stage(data)` 在 `has_run && !at_sea && 当前页属于 STAGE_SCREENS && （非 overview 或 _overview_stage_mode） && 场景可用` 时显示；overview 额外要求 3D 总览模式，market/supply 不受该开关影响。菜单/无 run/通关/在航/错误/非舞台页分支在 `_rebuild_ui()` 里由 `_hide_port_stage()` 隐藏并清空招牌。",
      "`_port_stage_payload(data)` 从 `current_port` 组装 `port.{id,size,facilities,banner_path}`，可选透传 `facility_visuals/town_visuals/diorama/palette/landmark_path` 与 `diorama.density`，ship 只传 `hull_model_path/hull_tier`；`_port_banner_path()` 统一解析 `asset://<mod>/<banner_asset>`。",
      "两侧招牌用 `facility_screen_anchor()` 的投影 x 分列（<0.5 左、否则右），同列按投影 y 排序；规格 172×42 / margin 20，左列文字「设施 ▶」、右列「◀ 设施」指向场景；右侧底部固定一条「海图 ▶」招牌（`Hotspot_sea_chart`，4.3.4 起替代旧出航招牌）。",
      "招牌控件是 `SNHarborSign`（自绘木板/铁框/黄铜铆钉/设施徽记/箭头/悬停光晕），`text` 与 `Button` 语义保留；`_port_sign()` 兼容组件缺失时回退普通 Ghost Button。",
      "招牌布局避让紧凑 chrome 与底部状态条：`_port_hud_top_safe()` 取 `_top_chrome` 底边、`_port_hud_bottom_safe()` 取状态条顶边；`_refresh_port_hotspots_soon()` 做两次 deferred（等容器重排与 SubViewport 尺寸），视口 size_changed 时重排。",
      "底部状态条（`_port_status_bar`，`PORT_STATUS_BAR_HEIGHT=60`）只在 overview 显示：耐久/货舱/煤/水/受损模块 + 最新通告（沿用 `_notice_text` 模板填充）+「详细总览/返回主界面」+「海图 ▶」+ 等待 12 小时（`port.wait`）；显示时隐藏 footer 并增大 `PageMargin` 底部预留。",
      "详细总览抽屉：`_on_overview_detail_toggle()` 切换 `_overview_detail`，抽屉用原 2D 面板（含 `_victory_plan`）覆盖在舞台上方；舞台宿主不销毁，招牌层隐藏，关闭后回到裸舞台；离开 stage、切到非 overview、重开/继续游戏与加载失败都会复位抽屉。",
      "2D 回退：chrome 上的「2D 总览」按钮切换 `_overview_stage_mode`；舞台加载失败 `_on_port_stage_fallback(reason)` 置 `_port_stage_load_failed`（本会话不再重试）、退出 stage 与抽屉、回退 2D、提示 `ui.error.port_stage_unavailable` 并 deferred refresh。",
    ],
    l2: {
      "_build_top_chrome(app, data, show_nav)": [
        "一个半透明 `PanelContainer`（`_chrome_style()`：深青 0.84 + 黄铜底边）内放两行 `HBoxContainer`：第一行品牌/状态徽标/版本 + 港口·时间·金钱·声望 chip（金币带可选图标）+ 阶段切换（overview 且场景可用时才出现，「2D 总览/俯瞰港口」）+ 诊断/刷新；第二行剩余载重/货舱/煤/水/耐久/受损 chip（煤/水带图标）+ 6 个导航按钮 + 海图切换按钮。",
        "`show_nav=false`（在航）时不挂导航；最小高度由 chip 字号与 panel margin 决定，`test_ui_shell` 断言 ≤130 px。每个页面共用同一份 chrome，960×540 窗口由 canvas 拉伸整体缩放。"
      ],
      "_stat_chip() / _hud_icon()": [
        "`_stat_chip(label, value, accent, label_size, value_size, icon_key, chip_key)`：有图标时在文字列左侧加 22 px `TextureRect`（KEEP_ASPECT_CENTERED、不吃鼠标），否则只输出两行 Label；`chip_key` 非空时 chip 与数值 Label 分别命名为该 key / `Value`，供演出逐帧改读数（4.3.5 / U8 的煤 / 水 chip）。",
        "`_hud_icon(key)`：`AssetService.find_key(key)` → `has()` 校验 → `load_texture()`，结果（含 null）按 key 缓存；资产冻结后无需失效。"
      ],
      "_set_port_status_bar_visible(visible, data) / _refresh_port_status_bar(data)": [
        "状态条懒创建为全窗底部锚定的 `PanelContainer`（高 60、左右 20 边距、位于 fade 之下），只在 overview 显示；显示时隐藏 footer，并把 `PageMargin` 底部 margin 从 56 提到 84，避免遮住页面最后一行。",
        "内容每次刷新重建：耐久/货舱/煤/水/受损 chip + 最新通告（`_latest_notice_text` → `_notice_text`）+「详细总览/返回主界面」（仅 stage 模式）+「海图 ▶」+「等待 12 小时」（`port.wait`）。"
      ],
      "_layout_port_hotspots() / _layout_sign_column() / _port_sign()": [
        "清空旧招牌后按 `facility_screen_anchor()` 把 present 设施分左右两列（x<0.5 / ≥0.5），同列按投影 y 排序，在两列各自的 safe 区内垂直居中均匀排布（172×42、gap 10）。",
        "safe 区来自真实 HUD 高度：顶部 = `_top_chrome` 底边 + 8，底部 = 状态条顶边（未建时回退 48 px）；右列底部预留「海图」招牌位，`Hotspot_sea_chart` 固定在右下。",
        "点击招牌走 `_on_port_hotspot`：sea_chart 切到海图页，其余查 `PORT_STAGE_FACILITY_SCREENS` 后与顶部导航同一路径；抽屉打开或舞台不活跃时整层不生成招牌。"
      ],
      "_sync_overview_detail_backdrop() / _place_overview_detail_backdrop()": [
        "抽屉用不透明 `ColorRect(COLOR_BG)` 盖住舞台（不盖 chrome/状态条），`mouse_filter=IGNORE` 不抢滚动；只通过 sibling index 调整保证它在 `PageMargin` 之下。",
        "`_sync_overview_detail_backdrop()` 仅在 `_overview_detail && _port_stage_active()` 时显示；隐藏舞台、离开 overview 或加载失败时同步关闭，招牌层同时隐藏。"
      ],
      "_sync_port_stage(data) / _ensure_port_stage_host()": [
        "显示条件 = `has_run && !at_sea && 当前页在 STAGE_SCREENS && （非 overview 或 _overview_stage_mode） && 场景存在`；宿主首次懒创建（全窗锚定、先隐藏），随后 `load_stage(PORT_STAGE_SCENE_PATH)` → `bind_view_model(_port_stage_payload(data))` → `set_stage_visible(true)`，再 `_focus_stage_station(station, framing, just_mounted)`、同步抽屉 backdrop 与招牌层。站位切换只调 `PortStage.focus_station()`，舞台实例与 3D 世界都不重建。",
        "`_focus_stage_station(station, framing, immediate)`：overview 用 `stage` 构图，market/supply 用 `panel` 构图（右侧 640 px 面板，镜头右移 3 m 让站位设施留在可见左半屏）；`immediate` 只在首次挂载时传 true，其余走 0.6 s 镜头平移 + 船体沿岸航行。",
        "宿主/招牌层/抽屉 backdrop 的层级用 `move_child(..., $Background.get_index() + 1)`、`(..., $PageMargin.get_index() + 1)` 与 `_place_overview_detail_backdrop()` 固定：3D 在背景之上、2D UI 之下，抽屉 backdrop 在页面之下。"
      ],
      "_mount_dock_panel(screen)": [
        "market / supply 页的布局：`DockPanelRow`（HBox）第一个子节点是 `StageWindow`（expanding、不吃鼠标、露出舞台），第二个是 `DockPanel`（SNPanel、`custom_minimum_size.x = 640`、纵向 expand），页面本体挂在面板下。",
        "舞台不可用（场景缺失或本会话加载失败）时 `_stage_backed_page()` 为 false，页面按原样全宽挂到 `_root_box`，功能不受影响。"
      ]
    }
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
    role: "港口总览页面场景：组合港口横幅、主线目标、通关清单、船只摘要、快捷操作、财务与航行记录；三种呈现由 Shell 控制——裸 3D 舞台（页面只留 spacer）、详细总览抽屉（原 2D 面板覆盖舞台）与 2D 回退总览。阶段 4.3 / U6 起不再渲染旧线稿海图。",
    dependencies: ["SNResourceMeter", "SNBadge", "SNSectionHeader", "ClockService", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 Shell 组合后的 banner_path、current_port、contracts、victory、ship、debt 与 notice_texts，不访问 AppContext、QueryBus、注册表或资产服务。",
      "港口横幅来自内容模组：页面优先用 `ContentAssetLoader.load_texture(banner_path)` 读原始 PNG，`ResourceLoader.exists` 为真时退回 `load()`；两种路径都失败则不渲染横幅。",
      "功能入口只发出 navigation_requested（快捷入口用 `sea_chart` 打开海图）；等待与借款只发出 command_requested。",
      "航行记录使用 Shell 已安全填充并本地化的 notice_texts，页面不重复解释 GameState 通报参数。",
      "构筑胜利条件直接取 contracts 进度与 victory.conditions 展示，不在页面重新判断通关。",
      "目标清单等密集横向字段保持单行，避免右侧说明被压缩成逐字竖排并撑高卡片。",
      "页面可重复 bind，每次清理旧节点；不持有任何海图控件（4.3 / U6 删除旧总览海图，全屏海图页是唯一入口）。",
      "有两个意图信号：`stage_toggle_requested`（2D/3D 总览切换）与 `detail_toggle_requested`（详细总览抽屉开关）；舞台宿主、抽屉 backdrop、状态条与回退都在 Shell，页面不持有 SNStageHost。",
      "`bind(vm, translate)` 读 `stage_available/stage_mode/overview_detail`；当 `overview_detail && stage_available` 时先加 `_detail_header()`（「返回主界面」按钮 + `ui.hint.overview_detail` 提示），再 `_build_detail(vm)` 渲染原 2D 面板（含 victory plan），该路径是抽屉内容。",
      "stage_mode 且未开抽屉：只加 expanding spacer 后直接返回，让 Shell 的全窗 3D 舞台露出；2D 回退模式在 hero 前加 `_stage_control_row(false)`（`ui.button.port_stage`「俯瞰港口」，发 stage_toggle_requested），同时渲染完整 `_build_detail(vm)`。",
      "`_build_detail(vm)` 只是原总览面板的入口重构，横幅/左右面板/通告布局与数据契约不变（旧海图块已删除）；页面仍不访问 AppContext、QueryBus 或资产服务。"
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
    role: "补给与维修页面场景：绑定 SupplyView，组合煤水决策卡、资源摘要与维修操作；作为泊位侧栏时按 620 px 窄列设计（卡片单列堆叠、badge 可换行），外层 PageScroll 负责竖向滚动。",
    dependencies: ["SNSupplyCard", "SNBadge", "SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(view_model, translate) 是唯一数据入口；页面不查询 AppContext、不访问 QueryBus/CommandBus，也不保存领域状态。",
      "煤水购买与维修统一发出 command_requested(command, params)，由 Shell 执行并决定刷新、音效和错误反馈。",
      "页面可重复 bind；每次先清理旧展示节点，页面实例复用时不会叠加卡片或信号。",
      "阻断码只转换为展示文案，不在页面重新计算库存、重量、金钱或维修规则。",
      "维修卡把报价拆成「缺失耐久 X（船体 A · 部件 B）」，module_points>0 时追加「含部件损耗」徽标；数值全部来自 supply.view 的 repair 字段。",
      "窄列布局：煤/水卡放 `VBoxContainer` 单列堆叠（`custom_minimum_size=(0,0)` + EXPAND_FILL），摘要与维修 badge 用 `HFlowContainer` 自动换行；页面自身不加 ScrollContainer，宽度交给 Shell 的 `DockPanel`（620-640 px）约束。"
    ]
  },

  "framework/ui/screens/port/market_screen.gd": {
    role: "港口市场页面场景：展示行情、真实价格历史、持仓成本及买卖操作；作为泊位侧栏时按 620 px 窄列设计（纵向商品条目列表，替代旧九列表格），外层 PageScroll 负责竖向滚动。",
    dependencies: ["SNSparkline", "SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(view_model, translate) 接收 Shell 组合后的 current_port/money/ship/market/trends，不访问 AppContext 或任何总线。",
      "买卖按钮只发出 trade.buy/trade.sell command_requested；可买性、港存和可售数量只决定展示与按钮禁用。",
      "折线只使用 recent_prices 真实样本；少于两个样本显示缺省状态，趋势颜色为红降绿升。",
      "窄列布局：每件商品是 `SNInsetPanel` + 三行（名称/仅收购标记 + 趋势 sparkline 与百分比；单价/库存/持有/可售/均价/单位重量；买入 1/5/10 与卖出 1/5），行内 HBox 不允许横向裁切；`_grid_label(text, size, color)` 保留 72 px 最小宽（现有 UI 测试依赖）。",
      "摘要（金币/重量、货舱/库存成本）与市场提示单独成段，长提示用 `_paragraph()`（AUTOWRAP_WORD_SMART），密集字段标签仍保持单行。",
      "仅收购商品隐藏买入数量组并明确显示 sell-only；平均成本缺失时显示破折号；点击发出 {item_id, amount}。"
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

  "framework/ui/components/sn_button.gd": {
    role: "可复用语义按钮：在 Inspector 中选择主操作、次操作、危险或幽灵样式。",
    dependencies: ["steam_navigator_theme.tres"],
    contracts: [
      "只通过 `theme_type_variation` 选择视觉状态，不在业务页面复制 StyleBox。",
      "默认保留键盘焦点并使用指针光标；compact 只调整高度和字号。"
    ]
  },

  "framework/ui/components/sn_harbor_sign.gd": {
    role: "2.5D 港口主界面的主题化边缘招牌：`Button` 子类，用自绘木板/木纹/铁框/黄铜铆钉/四角包边/设施徽记/指向场景的箭头替代主题 StyleBox，悬停/按下/焦点用黄铜光晕与明暗反馈；点击、焦点、tooltip、`text` 语义仍由 Button 提供。",
    dependencies: ["steam_navigator_theme.tres"],
    contracts: [
      "`configure(text, primary, facility, arrow)` 一次性写入标签/主次/徽记/箭头方向（-1 左列指向场景右侧、1 右列指向左侧、0 无箭头）；Shell 在把控件加入树前调用。",
      "`_ready()` 把 normal/hover/pressed/focus/disabled StyleBox 全部换成 `StyleBoxEmpty` 并把内建字体颜色设为透明，避免 Button 自带绘制与本组件重复；标签、箭头与徽记全部由 `_draw()` 绘制。",
      "木纹/缝线以 `text.hash()` 取确定性相位，不使用随机数；悬停/焦点/按下只触发 `queue_redraw()`，没有每帧处理。",
      "`text` 保留完整标签（含「▶/◀」字形）供测试、tooltip 与无障碍；绘制时剥离箭头字形后在朝向场景的一侧画真实三角形。",
      "徽记按设施 id 区分（exchange 硬币 / contracts 告示行 / supply 水滴 / intel 灯塔 / shipyard 船坞 / voyage 菱形），不依赖贴图资产。"
    ],
    l2: {
      "_draw()": [
        "先画投影与木板底、确定性木纹与两条板缝，再画铁框（2 px）、黄铜内线、四角包边、两列黄铜铆钉；悬停/焦点加外圈黄铜光晕，按下加深底色。",
        "文字用主题 font/font_size 居中绘制在徽记与箭头之间的可读区；颜色随 primary/悬停/按下切换。"
      ]
    }
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
    role: "船厂正常态的 3D 舞台适配器：把通用 `SNStageHost` 接入既有 `SNShipView.set_renderer()` 协议，加载 `ShipyardStage` 承载船体、环境、灯光与水面；节点本身只做 ViewModel/模式转发与显隐。",
    dependencies: ["SNStageHost", "ShipyardStage", "SNShipView"],
    contracts: [
      "`SNShipStage3D` 现在是 `SNStageHost` 的薄适配器：视口、World3D 与舞台生命周期由宿主拥有，相机/灯光/水面/船体由 `ShipyardStage` 拥有。",
      "实现 `ship_view_update(model)` / `ship_view_set_mode(mode)` / `ship_view_highlight(slot_ids)`；`_ready` 时自动加载 `res://framework/ui/stages/shipyard_stage.tscn`。",
      "`ship_view_update` 把 `{\"ship\": model}` 转发给舞台并缓存；`ship_view_set_mode` 用 `set_stage_visible(mode == EXTERIOR)` 控制 3D 显隐，CUTAWAY 隐藏视口但保留 2D 纵剖图。",
      "`ship_view_highlight()` 记录槽位并转发给舞台（舞台侧高亮属下一片）；`has_ship()` / `model_path()` 代理到当前舞台。",
      "`is_supported()` 只判断本地是否有 `hull_tier` 旧路径可回退；正式发布由页面用 `hull_model_path` 非空来挂载舞台，PCK 不含 `assets/models` 也能显示 3D。",
      "只做表现层：不读 GameState / QueryBus / CommandBus；渲染器方法在 `_ready` 之前被调用时先缓存 model/mode，`_ready` 后统一应用。"
    ]
  },

  "framework/ui/components/sn_stage_host.gd": {
    role: "通用 3D 舞台宿主（SubViewportContainer）：持有独占 SubViewport/World3D，加载并挂载一个 `LocationStage`，驱动 enter→bind 生命周期、舞台显隐与渲染停更，并转发 `portal_requested` / `fallback_requested`；同时是船厂 `SNShipView` 的渲染器后端。",
    dependencies: ["LocationStage", "SNShipStage3D"],
    contracts: [
      "一个宿主同一时间只承载一个舞台；`mount_stage()` 先卸载旧舞台再挂新的。",
      "`load_stage(path, payload)` 在未进树（`_ready` 前）调用时只缓存 path/payload 并返回 false，由 `_ready` 补加载；场景缺失 / 非 PackedScene / 根不是 `LocationStage` 时发 `fallback_requested(reason)` 并返回 false。",
      "挂载顺序固定 `enter(payload)` → `bind(_view_model)`；`stage_id` 取 `LocationStage.stage_id`，为空时回退节点名。",
      "`bind_view_model()` 深拷贝缓存最新 ViewModel 并转发；之后挂载的舞台会自动收到最近一次 ViewModel。",
      "`set_stage_visible(false)` 同时隐藏宿主、把 SubViewport 置 `UPDATE_DISABLED`、舞台 `process_mode=DISABLED`；显示时恢复 `UPDATE_WHEN_VISIBLE` / `PROCESS_MODE_INHERIT`。",
      "`unmount_stage()` 先 `exit()` 再移出并 `free()` 舞台，发 `stage_unmounted(old_id)`。",
      "`_ready` 设 `clip_contents`、`MOUSE_FILTER_IGNORE`、`PRESET_FULL_RECT` 与 `stretch_shrink=max(1, render_shrink)`；`auto_load` 且有 `stage_scene_path` 时立即加载。",
      "`_exit_tree()` 对已挂舞台调用 `exit()`，避免离开树后舞台动画继续。"
    ],
    l2: {
      "_build_host()": [
        "SubViewport（`own_world_3d=true`、`gui_disable_input=true`、默认 1440×900、初始 `UPDATE_DISABLED`）+ `StageWorld` 根；宿主不持有相机/灯光/水面，它们属于舞台场景。"
      ],
      "_apply_render_state()": [
        "active = `_stage_visible and is_inside_tree() and is_visible_in_tree()`；隐藏时停 viewport 更新与舞台 process，符合「同一时间只渲染一个 3D 舞台」。"
      ]
    }
  },

  "framework/ui/stages/location_stage.gd": {
    role: "2.5D 固定机位舞台契约基类：舞台自持相机/灯光/环境/水面/道具与 idle 动画，由 `SNStageHost` 驱动 enter→bind→exit 生命周期；只读已解析 ViewModel，不访问 GameState / QueryBus / CommandBus。",
    dependencies: ["SNStageHost", "SNShipStage3D"],
    contracts: [
      "信号 `portal_requested(target_id)` 只表达玩家意图；host 重新发出，由 UI Shell / 未来的 StageDirector 决定跳转。",
      "`stage_id` 由具体舞台场景覆盖（`shipyard` / `port`）；为空时 host 回退到节点名。",
      "`enter(payload)` 进入时启用局部动画并应用 payload；`bind(view_model)` 可重复调用做数据刷新；`exit()` 停止动画并丢弃局部状态。",
      "`has_visual()` 默认 true：程序化舞台在内容资产缺失时仍可绘制，页面据此决定是否回退 2D banner。",
      "`hotspot_anchors()` 返回设施/入口 id → 世界坐标；2D Control 热点用舞台相机投影这些点，不做 3D RayCast。"
    ]
  },

  "framework/ui/stages/stage_kit.gd": {
    role: "固定机位 2.5D 舞台的公共构建器：程序化天空/颜色环境、无阴影方向光、近/远水面材质、船体泡沫环、世界空间 AABB 与长焦取景。",
    dependencies: ["assets/materials/water/harbor_water.tres", "assets/materials/water/harbor_water_far.tres"],
    contracts: [
      "纯表现层：不读 GameState / 服务 / 内容 ID；相机取景只读 `visual_aabb()` 结果，不缩放模型。",
      "`load_water_material()` 对共享 `harbor_water.tres` 做 `duplicate(true)` 再写 shader 参数，避免污染其他场景使用的同一资源。",
      "`add_water()` 在材质缺失或路径非法时回退 `StandardMaterial3D`（`WATER_FALLBACK_COLOR`），舞台不会因框架材质缺失而失去水面。",
      "`add_environment()` 支持 `mode=\"sky\"`（`ProceduralSkyMaterial` 调色板）与 `mode=\"color\"`（仅 BG_COLOR）；两种都开线性雾、FILMIC tonemap 与颜色环境光。",
      "`add_directional_light()` 生成的灯 `shadow_enabled=false`：固定舞台只付一个 key + 一个 fill 的开销。",
      "`configure_boat_foam()` 把泡沫椭圆贴到船体世界包围盒（`boat_center` / `boat_half_size`，`boat_yaw` 置 0）；换船后调用方需按实际船艏向覆盖 yaw。"
    ],
    l2: {
      "visual_aabb(root) / transform_aabb(xform, box)": [
        "遍历 Node3D 层级（显式栈 + 累积变换），对每个 MeshInstance3D 的 mesh AABB 做 8 角点变换后 merge；无网格时返回 12×5×12 的兜底盒。",
        "只反映静态网格包围盒；骨骼蒙皮、粒子或运行时改 mesh 不在计算内。"
      ],
      "frame_camera(camera, bounds, direction, fov, margin)": [
        "距离 = 包围盒半径 / tan(fov/2) × margin，再沿固定方向摆放并 `look_at` 包围盒中心；船体尺寸变化只改相机，不缩放模型。"
      ]
    }
  },

  "framework/ui/stages/shipyard_stage.gd": {
    role: "船厂 EXTERIOR 固定 3/4 机位船体舞台（首个切片的迁移目标）：自建环境/灯光/水面/相机，按 ViewModel 的 `hull_model_path`（旧 `hull_tier` 路径仅 dev 回退）挂载船体 GLB，并在 `_process` 做升沉/横摇。",
    dependencies: ["LocationStage", "StageKit", "ContentAssetLoader"],
    contracts: [
      "`stage_id` 默认 `shipyard`（舞台场景再显式覆盖）。",
      "`bind()` 接受完整 ViewModel 或直接以 ship 字典作为根；内部深拷贝 `ship`，重复 bind 同一模型不重建船体。",
      "船体路径优先 `hull_model_path`；为空才按 `hull_tier` 回退 `assets/models/ships/*.glb`，该文件不存在再退 `SN_Ship_Prototype.glb`；加载失败时舞台保持空场景，船厂继续用 `SNShipView` 程序化占位。",
      "相机取景用 `StageKit.visual_aabb()` + 30° 长焦 FOV；水面泡沫环绑到当前船体包围盒（shore 推远、隐藏岸线泡沫）。",
      "`enter()` 恢复 `_process`，`exit()` 停止；不可见时不写升沉，避免隐藏舞台继续运动。"
    ],
    l2: {
      "_apply_model() / _rebuild_ship(path)": [
        "`hull_model_path` 为空时用 `_fallback_path_for_tier(hull_tier)`；路径相同时直接复用现有 Ship 根，否则释放旧节点并新建 `Ship` 节点。",
        "GLB 优先 `ContentAssetLoader.instantiate_model()` 读模组原始文件，`ResourceLoader` 作为已导入场景兜底；挂载成功后重新取景并更新泡沫环。"
      ],
      "_process(delta)": [
        "`sin(t*0.9)*0.12` 升沉 + `sin(t*0.675)*0.004` 横摇；不做航行/物理。"
      ]
    }
  },

  "framework/ui/stages/port_stage.gd": {
    role: "固定 3/4 长焦港口舞台，也是一座连续港区：`_ready` 一次建静态层（L0 暖色 sky + 双层水面 + 160 m 桩基码头 + L1 兜底 painted backdrop + L6 前景框 + L7 3 组蒸汽粒子 + 相机），`bind()` 只重建 `_content` 下的数据层：L1 banner 背板、L2 双深度带剪影（仅无 banner 且无 town kit）、L2b 港口街坊 town kit（按 size/density 28/47/63 件）、站前道具（每站 5/8/11 件）、L3 设施、L5 玩家船、L7 雾带；随后把设施 + 街坊 + 站前道具 + 玩家船静态合批。市场 / 港务 / 补给是同一港区里从左到右的三个相邻站位，切换页面只平移镜头并把玩家船开到对应泊位（`focus_station()`），世界不重建。全程序化 + 内容模组 GLB，无外部框架贴图。",
    dependencies: ["LocationStage", "StageKit", "ContentAssetLoader"],
    contracts: [
      "bind ViewModel 字段全部可选：`port.{id,size,facilities,banner_path,palette,facility_visuals,town_visuals,landmark_path}` 与 `ship.{hull_model_path,hull_tier}`；`facility_visuals` / `town_visuals` 也可放在根层。",
      "`bind()` 幂等：先按 `str(port) + str(ship) + str(root facility_visuals) + str(root town_visuals)` 计算签名，相同则直接返回；`enter(payload)` 的 payload 仅在 bind 收到不含 port/ship/facility_visuals/town_visuals 的数据时兜底。",
      "设施顺序固定 `FACILITY_ORDER`（exchange/contracts/supply/intel/shipyard）；present 的设施才有锚点与热点，缺席只放程序化货堆 filler（`filler_count()`），`facility_visual_kind()` 返回 model/billboard/missing。",
      "`facility_visuals` 值可为 String 或 Array[String]：能 `ResourceLoader` 加载的按 PackedScene 实例化，否则走 `ContentAssetLoader.instantiate_model()`；路径缺失/实例化失败回退程序化 billboard。",
      "L1：有 `banner_path` 且贴图可加载时挂 banner 背板（albedo tint 黄昏化）并隐藏兜底层；无 banner 时 `has_backdrop()` 仍为 false，由 `FallbackBackdrop` 接管——暖霞渐变 `SkyCard` + 2 个 additive 太阳光晕，共 3 层程序化 painted backdrop，无黑盒、无外部贴图。",
      "L2（仅无 banner）：双深度带（近带深蓝灰 / 远带暖雾）各 2 簇 + 低矮仓房连接排 + 远岸低雾带 + 灯塔剪影；MultiMesh 批量（box / 塔身 / 塔冠 3 draw），严格站 `SHORE_TOP`、unshaded、无阴影、无发光窗；建筑数 small 7 / medium 10 / large 13、吊机 2 / 2 / 3，`skyline_building_count()` / `skyline_crane_count()` 报告实际数量（有 banner 时均为 0）。",
      "L2 实例总数 small 14 / medium 17 / large 20（建筑 + 吊机 + 仓房排/雾带/灯塔），仍在方案 L2 ≤20 预算内；small 的 7 栋低于任务描述的 8 下界，以源码为准。",
      "L2b 港口街景：`port.town_visuals`（slot → 已解析 GLB 路径）存在时在码头后方的抬升石广场（`TOWN_GROUND_Y=1.9`、`TOWN_PLAZA` 250×2.2×34）上装配建筑/围栏/工人/广场装饰/小船 + 码头工业件；密度由 `port.density` → `port.diorama.density` → `port.size` 推导（small→sparse、medium→normal、large→busy），每组按 tier 取前缀，`port.id.hash()` 只给自由摆放件加确定性 yaw 抖动（无全局 RNG）。normal = 5 建筑 + 7 围栏 + 7 工人 + 8 装饰 + 3 船 + 17 码头工业件 = **47 props**（sparse 28 / busy 63）。建筑缺失 GLB 时回退程序化 blockout，围栏/工人/船/装饰缺失则直接省略。",
      "town kit 存在时跳过 L2 程序化 skyline（`if _town_visuals.is_empty(): _rebuild_shoreline()`），因为街区已有近景轮廓；town 与 banner 相互独立（有 banner 也可有 town）。",
      "连续港区与相邻站位：`STATION_ORDER = [market, harbor, supply]`（世界 X 从左到右），`STATIONS` 定义每个站位的 `center`、`camera`/`target`（同一 30° 长焦）、`ship` 泊位与 `ship_yaw`；码头甲板/木桩/系缆桩/煤气灯沿 160 m 连续铺开，`exchange` 与 `supply` 设施分别落在 -30 / +30 的站位上（contracts/intel/shipyard 仍集中在中心港务段）。",
      "`focus_station(station, framing, immediate)` 只重定向镜头与泊位，港口、街坊、设施、水面与合批层都不重建；`framing` = `stage`（全窗总览）或 `panel`（右侧 640 px 泊位面板，镜头整体右移 `PANEL_FRAMING_SHIFT_X=3 m`，让站位落在可见左半屏）。重复聚焦当前站位是 no-op，整页重建不会重启动画；`immediate` 只用于舞台首次挂载。",
      "站位切换演出：镜头在 `CAMERA_PAN_SECONDS=0.6 s` 内平滑 pan；玩家船先转艏向沿岸方向，再以 `SHIP_TRANSIT_SPEED=24 m/s` 驶到新泊位并转回 `ship_yaw`，泡沫环 `boat_center` 随船移动。`advance_station(delta)` 以 50 ms 切片推进整段过渡（`_process` 每帧调用；测试/截图工具可直接步进，无需真实帧）；`is_station_transitioning()` 报告过渡是否结束。",
      "镜头平移时的画幅层：`_apply_camera_shift()` 把相机朝向层（sky card/太阳光晕、painted backdrop、banner 背板、L6 前景框、雾带）按 `camera_shift_x` 平移保持构图，L2 剪影只平移一半保留视差；码头/街坊/设施/水面/船体是世界几何，随镜头真正移动。",
      "站前道具：`STATION_PROPS`（每个站位一条有序列表）按密度 tier 取前缀（sparse/normal/busy = 每站 5/8/11 件），全部复用官方 town kit 已解析路径（`port.town_visuals`），缺失 GLB 直接省略；`station_prop_count()` 与 town kit 的 `town_prop_count()` 分开计数。",
      "静态合批：`_batch_static_meshes()` 在 town/facilities 重建后、玩家船之前，把两棵静态根按材质折叠——BoxMesh 共享单位立方体走 MultiMeshInstance3D（每材质 1 batch），其余 static mesh 按材质签名烘焙成每材质 1 个 ArrayMesh；透明/ShaderMaterial/`material_overlay`/非三角面/带法线贴图材质安全跳过。玩家船在泡沫 AABB 计算后按 `_ship_root` 局部空间刚性合批（`_batch_ship_visual()`），带 AnimationPlayer/Skeleton/粒子/透明/法线贴图的船体整船回退保留原 GLB。",
      "`_apply_fallback_visibility()` 以 `use_fallback = not _has_backdrop` 统一控制 `FallbackBackdrop`、`ShoreShelf` 与 `ShoreSteam`：banner 自带天空/城市，兜底层必须整体隐藏；L2 剪影也只在无 banner 时生成。",
      "只读访问器：`foreground_frame()`、`atmosphere_particle_systems()`（1..3，当前固定 3）、`atmosphere_layers()`（有 banner 2 / 无 banner 3）、`skyline_building_count()`（无 banner 7/10/13，有 banner 0）、`skyline_crane_count()`（2/2/3）、`town_prop_count()`（按 density 28/47/63，无 town 时为 0）、`town_blockout_count()`、`town_density()`、`painted_backdrop_layer_count()`（无 banner 3 / 有 banner 0）、`batch_stats()`（facilities/town 与 ship 的 batches、mesh/surface 前后计数、`ship_fallback`）、`ship_foam_bounds()`（批处理前捕获的船体 AABB）；`has_backdrop()` 语义仍只表示 banner。站位查询：`station_ids()`、`current_station()`、`current_station_framing()`、`station_camera_pose(id, framing)`、`station_ship_position(id)`、`station_ship_yaw(id)`、`is_station_transitioning()`、`camera_position()`、`camera_target()`、`camera_shift_x()`、`ship_x()`、`station_ship_mooring_x()`、`station_prop_count()`。",
      "L6 `foreground_frame()` 始终存在：3 根深色 unshaded 梁（吊臂 0.30 / 钢缆 0.12 / 桅杆 0.18 m）从左上角入镜，用 `_screen_point(u, v, depth)` 钉在固定 16:9 画幅；限定 u<0.24 / v<0.45，不遮挡 HUD、设施招牌与热点标签，不投阴影。",
      "L7 大气：常驻 3 个 `GPUParticles3D`（ShipSteam / QuaySteam / ShoreSteam，16–22 粒、3.4–4.6 s、低 alpha 暖灰 + 程序化 radial `GradientTexture2D`）；雾带 billboard 有 banner 2 层 / 无 banner 3 层，`port.id` hash 决定正弦漂移相位；宿主 `process_mode` 停更时粒子与雾带一起停。",
      "预算目标 ≤120 draws / ≤60k tris；窗口实测（`tools/godot/measure_port_stage.gd`，含已合并玩家船）preview **63 draws / 47,604 tris**、sparse **56 / 38,150**、market **57 / 47,604**、harbor **63 / 47,604**、supply **61 / 47,604**（三站位均 ≤120 / ≤60k）。`batch_stats()` 报告批处理前后 mesh/surface 计数。官方内容目前只有铁港一张 banner，其余港口走 painted backdrop。",
      "码头是薄甲板桩基栈桥（不是实心箱体）：160 m 连续甲板（`DOCK_SIZE` 160×0.6×12）+ 19 根入水木桩 + 桩帽、纵向横梁与甲板边梁，系缆桩每 12 m 一组、煤气灯沿前景 7 根；远景岸线底座 500×1.3×110 把镜头内的水面切边藏起来。",
      "`port.size` ∈ small/medium/large → 设施组整体 0.9/1.0/1.15（`SIZE_SCALE`），只缩放设施层，不缩放船与码头。",
      "`facility_anchors()` 返回设施 id → 世界坐标；`facility_screen_anchor()` 用舞台相机投影并按 viewport 尺寸归一化到 0..1（缺席或未投影时返回 ZERO）；`hotspot_anchors()` 同 `facility_anchors()`。",
      "玩家船：`ship.hull_model_path` 优先，`hull_tier` 只作 dev 回退；船体在 `SHIP_SPAWN` 真尺度摆放，水面泡沫环按包围盒绑定并在 `_process` 做升沉/横摇。",
      "`request_portal(facility)` 只发 `portal_requested`；`has_visual()` 恒 true（程序化舞台无资产也可绘制）。",
      "表现层：不读 GameState / QueryBus / CommandBus；所有资产路径已在 ViewModel 中解析。"
    ],
    l2: {
      "_ensure_static() / _build_environment()": [
        "静态层只建一次，顺序：材质 → 环境 → L1 兜底 → 双层水面 → 桩基码头 → 相机 → L6 前景框 → L7 粒子。环境为 sky 模式黄昏调色 + 深度雾 70–450 m + 环境光 0.6 + 暖 key(1.7)/冷 fill(0.5) 无阴影；`ProceduralSkyMaterial` 调 `sky_energy_multiplier=1.12`、`sun_angle_max=18`、`sun_curve=0.22`，让程序化天空与兜底 painted sky 同属一个暖色 grade。"
      ],
      "_apply_view_model(port, ship, root_data)": [
        "解析 size/scale/palette/visuals/town_visuals/banner 后 `_clear_dynamic()`，按 backdrop → shoreline（仅 `_town_visuals` 为空且无 banner 才建）→ `_apply_fallback_visibility()` → `_rebuild_fog_layers()` → `_rebuild_town()` → facilities → landmark → `_batch_static_meshes()` → ship 的顺序重建；静态层与 L7 粒子跨 bind 复用。"
      ],
      "_add_fallback_backdrop() / _add_sky_glow() / _add_painted_backdrop_layers()": [
        "`FallbackBackdrop` 在 `_ready` 建一次：8×256 `GradientTexture2D` 暖霞 SkyCard（`SKY_CARD_SIZE` 340×100）+ `SunHalo`（90 m，alpha 0.12）+ `SunCore`（18 m，alpha 0.62）；太阳位置由 `_screen_point(0.70, 0.10, 118)` 钉在画幅右上。SkyCard 现改为固定 260 m 深度的 camera-facing quad，避免旧斜置 quad 在右侧近处遮断远景。",
        "光晕是 additive、camera-facing quad；radial 纹理只用到 72% UV 半径（fill_to 0.86），四边始终透明。有 banner 时整组 `visible=false`；无 banner 时再叠加 3 层低对比 unshaded 剪影（山脊 / 远城塔楼 / 港口屋脊+烟囱），合并为 1 个 MultiMesh（vertex color），`painted_backdrop_layer_count()` 报告 3。"
      ],
      "_rebuild_backdrop()": [
        "只有 banner 贴图加载成功才建 `BACKDROP_SIZE`（260×76）的 unshaded quad 放到 `BACKDROP_POSITION`（-70, 12, -70），albedo tint（0.72, 0.68, 0.64）成黄昏色调；失败直接返回，绝不创建黑色占位面。"
      ],
      "_rebuild_shoreline()": [
        "有 banner 时首行 return。无 banner 时 `port.id.hash()` 作种子、`_hash01` 生成双深度带：约 55% 近带（深蓝灰、2 簇、仓房/屋顶/烟囱）+ 45% 远带（暖雾色、2 簇）+ 2 条低矮仓房连接排 + 2–3 条远岸低雾带 + 1–2 座灯塔。所有 box 追加到 3 个 MultiMesh（`SkylineBoxes` / `SkylineLighthouseBodies` / `SkylineLighthouseCaps`，vertex color + custom AABB），整层 3 draw、unshaded、无阴影、无发光窗；实例总数 small 14 / medium 17 / large 20（≤20 方案预算）。"
      ],
      "_rebuild_fog_layers()": [
        "`FogBands` 为 bind 时重建：有 banner 2 条（u 0.50/0.72、v 0.76/0.86），无 banner 追加 1 条远景地平线雾带（u 0.50、v 0.44、depth 135）；每条是 radial alpha 的 camera-facing quad，`port.id` hash 决定漂移相位；`_process` 用 `sin(t*0.055+phase)*5 m` 缓慢横移，`_fog_layer_count` 递增。"
      ],
      "_add_foreground_frame()": [
        "`ForegroundFrame` 在 `_ready` 建一次：`_add_beam()` 生成吊臂（0.30 m）/钢缆（0.12 m）/桅杆（0.18 m）3 根细构件，两端由 `_screen_point()` 的 u/v/depth 定位；材质 unshaded + 0.45 emission 暖轮廓，无阴影；位置限制在左上角（u<0.24 / v<0.45），不遮 HUD 与热点。"
      ],
      "_add_atmosphere() / _add_particle_system()": [
        "3 个 GPUParticles3D 固定一次：ShipSteam（22 粒 / 4.2 s）、QuaySteam（16 / 3.4 s）、ShoreSteam（18 / 4.6 s，跟随无 banner 显隐）；ParticleProcessMaterial 球形发射、向上初速、轻重力；材质为 unshaded + billboard particles + 程序化 radial puff 贴图。"
      ],
      "_add_quay()": [
        "码头/系缆桩/煤气灯等重复件全部走 MultiMesh（`DockPlatform`、`DockDeck`、`DockWood`、`DockPiles`、`Bollards`、`BollardCaps`、`LampPoles`、`LampGlow`、`LampCaps`）：薄甲板 `DOCK_SIZE` 160×0.6×12 + 19 根木桩（含桩帽）+ 横梁/护舷，岸线底座 `SHORE_SIZE` 500×1.3×110 放 `SHORE_CENTER`（0, -0.55, -65）。"
      ],
      "_add_camera()": [
        "相机固定在当前站位的 `STATIONS[station].camera` 看向 `target`（三站位共用 30° 长焦、near/far 0.5/1200）；`_add_camera()` 用 `_station`/`_station_framing` 取初始 pose（默认 harbor/stage），并立即 `_apply_camera_shift()`。换构图只改站位常量，不在运行时缩放模型。"
      ],
      "_focus_station(station_id, framing, immediate) / advance_station(delta) / _advance_camera() / _advance_ship()": [
        "`focus_station()` 校验站位与 framing（非法 framing 回退 stage），记录 `_station`/`_station_framing`，把 `_ship_moor_x/_ship_moor_z/_ship_moor_yaw` 指向该泊位；`immediate` 时把 `_camera_from/_camera_to` 都设为目标并同步 `_camera`/`_ship_x`/`_ship_yaw`，否则从当前 pose 起调，`_camera_t=0`（重复聚焦当前站位直接返回，不重启动画）。",
        "`advance_station(delta)` 把 delta 切成 ≤50 ms 的步进（`_process` 每帧调用；测试/工具可直接步进整段）；过渡中再次 `focus_station()` 会以*当前相机位姿*为新起点续 pan（不瞬跳回旧目标）：`_advance_camera()` 用 `smoothstep` 在 `CAMERA_PAN_SECONDS` 内插值 position/target/fov 并 `_apply_camera_shift()`；`_advance_ship()` 先 `rotate_toward` 把艏向转到沿岸方向（目标方位 0 或 π），再按 `SHIP_TRANSIT_SPEED*对齐度` `move_toward` 泊位 X，到泊位后转回 `_ship_moor_yaw`，每步更新 `_apply_ship_pose()`（升沉、横摇、蒸汽跟随、泡沫）。"
      ],
      "_apply_camera_shift() / _sync_boat_foam() / _rebuild_station_dressing()": [
        "`_apply_camera_shift()`：`_camera_shift_x = _camera_target.x - CAMERA_TARGET.x`，据此平移 `FallbackBackdrop`（天空/光晕/painted layers）、`ForegroundFrame`、banner `Backdrop`（`BACKDROP_POSITION.x + shift`）与 `Shoreline`（×0.5 视差）；雾带在 `_process` 里把 shift 加到基准位置，保证镜头平移时画幅层不跑出构图。",
        "`_sync_boat_foam()`：用 `_ship_bounds_offset`（船体本地 AABB 中心，在泊位重建时捕获）+ `_ship_x`/`_ship_moor_z` 重算 `boat_center`，并写 `boat_yaw`，让泡沫环跟着船在站位间移动，而不是留在旧泊位。",
        "`_rebuild_station_dressing()`：按 `_station_prop_count_for_density()`（sparse/normal/busy = 每站 5/8/11）遍历 `STATION_ORDER`，把 `STATION_PROPS[station]` 前缀挂进 `_town_root`（`station=true`）；缺失 visual 的槽直接跳过，不生成占位盒。"
      ],
      "_rebuild_facilities() / _build_facility_visual()": [
        "按 `FACILITY_ORDER` 建锚点组（`_facilities_root` 放在码头顶面 `DOCK_TOP`，局部位置 `SLOT_POSITIONS`）；船厂可挂两件（干船坞 + 龙门吊，`SHIPYARD_PIECE_OFFSETS`）。",
        "有 facility_visuals 时逐路径实例化，至少成功一件即返回 `model`；否则走五种程序化 billboard 原型，失败/缺席由 kind 报告。"
      ],
      "_build_filler()": [
        "用 `port.id` 与设施序号派生 2–4 个木箱 + 木桶 + 可选麻袋，只做货堆，不建锚点/热点，也不参与 `facility_anchors()`。"
      ],
      "_rebuild_ship(ship)": [
        "船体按当前站位泊位（`_ship_moor_x/_ship_moor_z`）与 `ship_yaw` 20° 真尺度摆放；重绑（货舱/船体变化）时新船直接建在玩家当前站位，不会瞬移回港务参考位。成功时先按 `StageKit.visual_aabb()` 配泡沫环（覆盖 `boat_yaw` / `boat_foam_width`）并保存 `ship_foam_bounds()` 与本地 AABB 偏移，随后 `_batch_ship_visual()` 把船体按 `_ship_root` 局部空间刚性合批（`ShipBatches` 挂在船下，站位航行/升沉/摇摆仍作用于整船）；最后 `_sync_boat_foam()` 把泡沫对齐到泊位。失败时 `_disable_boat_foam()` 把泡沫环推到不可见处。"
      ],
      "_rebuild_town() / _resolve_town_density() / _add_town_prop() / _build_town_blockout()": [
        "`_rebuild_town()` 在 `_content` 下建 `HarborTown`：抬升广场 `TOWN_PLAZA_SIZE` 250×2.2×34（`plaza` 调色板材质）+ MultiMesh 铺装线（31 条，覆盖 -120..120）+ 广场边梁；随后按 `DENSITY_BY_SIZE` / `port.diorama.density` 解析 `_town_density`，依次装配建筑（固定 5 座）、`TOWN_FENCE_X` 前缀、`TOWN_WORKER_SLOTS` 前缀、`TOWN_DECOR_SLOTS` 前缀、`TOWN_BOAT_SLOTS` 前缀，以及 `TOWN_QUAY_ORDER` + `TOWN_QUAY_SLOTS` 的工业件（市场摊/吊车/麻袋堆/钢板堆/矿堆/托盘/跳板/系缆桩/绞盘/浮标），最后 `_rebuild_station_dressing()`。",
        "`_add_town_prop(slot, pos, yaw, scale, blockout_fallback, station = false)`：从 `_town_visuals[slot]` 取已解析路径并 `_instantiate_visual()`；建筑槽（blockout_fallback=true）失败时用 `_build_town_blockout()` 生成 box 体 + 双坡屋顶 + 窗/门节奏并计入 `_town_blockout_count`，其余槽失败直接跳过。每个 prop 包在带 yaw/scale 的 holder 下；`station=true` 的站前道具计入 `_station_prop_count`（节点名 `Station_*`），其余计入 `_town_prop_count`（`Town_*`）；`_town_jitter_yaw()` 只对自由摆放件加确定性抖动。"
      ],
      "_batch_static_meshes() / _batch_into() / _batch_ship_visual() / ship_visual_is_rigid()": [
        "`_batch_into(container, candidates, space_inverse, prefix)` 是共享合批实现：BoxMesh 用共享单位立方体 + 每实例 scale 生成每材质 MultiMeshInstance3D；其它 static mesh 把顶点/法线/UV/Color 按 `space_inverse` 烘焙到目标空间、按材质签名分组生成每材质 1 个 ArrayMesh，索引按 base_index 偏移；custom AABB 防裁剪。",
        "`_batch_static_meshes()` 依次批 `_facilities_root` 与 `_town_root`（139→34 mesh / 238→34 surfaces，33 batches），再 `_recount` 写 `_batch_meshes_before/after`、`_batch_surfaces_before/after`。",
        "`_batch_ship_visual()` 用 `_ship_root` 的全局逆变换烘焙船体，32→9 mesh / 90→9 surfaces；`ship_visual_is_rigid()` 在出现 AnimationPlayer/AnimationTree、Skeleton/Bone、GPU/CPU 粒子、MultiMesh、Skin/BlendShape、透明/ShaderMaterial/overlay、非三角面或 normal map 时返回 false，整船保留原 GLB 并置 `ship_fallback=true`。"
      ],
      "_screen_point(u, v, depth) / _screen_units(...)": [
        "用固定 FOV 与 16:9（1440/900）把归一化屏幕坐标换算成沿相机前向 `depth` 米处的世界点，供 SunHalo/SunCore、L6 前景框与 L7 雾带共用；换机位或窗口比例时这三层随画幅一起重算。"
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
    role: "从 content_types.json 生成框架 ContentTypes 与 SNModMaker 的类型目录（active `TYPES` + Schema 2.0 草案 `DRAFT_TYPES`）；提供 `--check` 过期检查。",
    contracts: [
      "单一真源是 `content_types.json`；生成物 `framework/modding/content_types.gd` 与 `SNModMaker/js/content-types.js` 禁止手改。",
      "生成前校验格式版本、key/singular/schema 唯一、分组与 v2 模块分类引用、Schema 文件存在、Patch 数量、planned 不覆盖 active、draft_schemas 只指向 planned 类型。",
      "`draft_types` 必须与 `draft_schemas` 键集合完全一致，且不得自带 schema 路径；生成器校验 singular/abbr/color/default_file 唯一、group 已声明、`schema_version` 等于对应 Schema 的 const、capability 等于该类型所属 planned system 的 capability。",
      "`framework/modding/content_types.gd` 只输出可加载的 active 类型；草案仅进入编辑器与 CLI 的 `DRAFT_TYPES`，运行时类型清单不变。",
      "`--check` 不写文件，生成物缺失或过期时以退出码 1 结束，供 CI/发布门禁使用。"
    ]
  },

  "tools/static_docs_data.mjs": {
    role: "静态文档的兼容策展数据：保留尚未迁移文件的职责/契约，并维护模块简介与分组角色。",
    contracts: [
      "新源码优先写 `@static-doc` 文件头；不能写注释的格式使用 `docs/static_headers/<源码路径>.md`，不再新增 FILE_DOCS 条目。",
      "FILE_DOCS 只服务尚未迁移的旧文件；MODULES 与 GROUPED_ROLES 继续维护模块级说明和无独立页文件的兜底职责。",
      "只描述源码可证实的职责与约束；符号位置由生成器扫描，不手写行号。"
    ]
  },

  "tools/godot/verify_port_facilities.gd": {
    role: "港口设施锚点 GLB 导入验收（只读）：加载 `assets/models/port/SN_*.glb` 6 件，量测 Godot 侧包围盒 / 三角面 / 材质名，对照工单尺寸与调色板判定。",
    contracts: [
      "glTF 由 Blender Z-up 转 Y-up，故期望尺寸 = (Blender X, Blender Z, Blender Y)；`EXPECTED` 表必须按此口径维护。",
      "尺寸容差 0.1 m（龙门吊 Y 含爬梯外凸，期望值 4.014）；三角面必须与 `EXPECTED` 精确相等，抓\"改了 .blend 忘了重导 GLB\"与旧缓存。",
      "包围盒最低点必须在 y=0（原点在底面中心）；材质名必须全部在调色板内；只读，失败退出码 1。",
      "改 GLB 后先 `godot --headless --import` 刷新缓存再跑本脚本。"
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
      "断点 1240 / 1000 / 800 / 760 / 560：编辑区单列、侧栏图标化、顶栏换行与操作压缩。",
      "Schema 2.0 草案分区与徽标（`side-group-draft` / `side-draft-tag` / `draft-badge` / `draft-notice` / `mini-badge.draft`）复用既有暗色变量，不引入新字体或配色体系。"
    ]
  },

  "SNModMaker/js/catalog.js": {
    role: "字段标签、默认值、标签建议、条件/效果词汇与新建模板（含「舰载武器包」5 件武器预设）；内容类型列表来自生成的 content-types.js（`TYPES` + `DRAFT_TYPES`）。",
    dependencies: ["JSON Schema（结构约束）", "content-types.js（由 content_types.json 生成）"],
    contracts: [
      "`BY_KEY` / `BY_SINGULAR` / `KEY_PREFIX` 覆盖运行时类型与 Schema 2.0 草案类型；`schemaVersionFor()` 返回类型期望版本（草案 2.0，其余 1.0）。",
      "`TYPES` 仍只含可加载的 Content Schema 1.0 类型，`DRAFT_TYPES` 与 `ALL_TYPES` 供编辑器侧栏、默认值与校验使用。",
      "`DEFAULTS` 生成的定义必须能通过对应 Schema；9 个草案类型的默认值必须补齐 `schemas/v2/*` 的必需字段。",
      "`weapons` 草案的字段标签 / 提示与 `DEFAULTS.weapons`（取 SNBattleSim「甲板速射炮」数值）就位；船体 `weapon_sockets` / `rig_sockets` 及 `clearance_*` / `rig_*` 字段有标签与提示。",
      "`WEAPON_PRESETS` 是「舰载武器包」模板的 5 件成品数据（deck_gun / heavy_cannon / mortar / repeater / broadside）：战斗数值对齐 SNBattleSim，装配字段对齐 GLB Root extras，经济字段项目补齐，`model` 为 `model.weapon.*`；`TEMPLATES` 的 `weapons` 条目（显示名「舰载武器包」）驱动新建模组对话框与 CLI `new --template weapons`。",
      "`keyPrefix` 决定本地化键前缀；船只模块共用 `module`，因此跨模块类型的 local ID 必须唯一。",
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
    role: "JSON Schema 子集校验器与 Steam Navigator 项目语义校验：Schema 版本、ID、引用、本地化、补丁与清单一致性。",
    dependencies: ["schema-bundle.js", "catalog.js", "core-index.js（可选外部引用检查）"],
    contracts: [
      "Schema 能力与 Godot `SchemaValidator` 的常用子集对齐；不支持远程 ref、if/then/else、format 断言。",
      "`resolveRef` 以基准 Schema 文件所在目录解析相对 `$ref`，使 `schemas/v2/*` 能引用 `v2/common.schema.json`；顶层 basename 基准行为不变。",
      "`schemaVersionFor(fileOrType)` 优先显式 `schema_version`，其次类型期望版本（草案 2.0），最后回退 1.0。",
      "内容文件的 `schema_version` 只接受 1.0 / 2.0；与类型期望版本不符报 `schema_version_mismatch`，其他值报 `schema_version_unsupported`。",
      "草案内容文件每文件一条 `draft_content` 警告；草案 capability 未写入 `manifest.capabilities` 时按 capability 去重报 `capability_undeclared`；草案跨引用跳过 `ref_core_unknown`。",
      "`LOCAL_IDENTIFIER_FIELDS`（当前含 `flow_id`）里的字段是本地标识符，不做跨定义引用检查，修复 story `flow_id` 的假阳性 `ref_missing`；Core 导入保持 0 error。",
      "武器语义校验码：`weapon_range_order`（min_range ≥ range）、`weapon_assembly_pivot`（profile 与 has_yaw/has_pitch 不一致）、`weapon_muzzle_count`、`weapon_class_modular`（warning）；船体 socket 语义码：`socket_name_duplicate` / `socket_index_duplicate` / `socket_name_prefix` / `socket_class_unknown` / `socket_kind_unknown` / `rig_socket_mast_id`（后四者为 warning）。",
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
        "先跑 Manifest Schema 与内容文件 Schema，再检查 schema_version、命名空间/类型段、重复 ID、本地化覆盖、跨引用与补丁目标。",
        "草案实例缺省版本按类型取 2.0，避免 v2 Schema 的 `schema_version` const 误报。",
        "资源裸键按当前模组 manifest.assets 解析；asset://core/<key> 使用嵌入 Core 索引校验，其他外部模组 URI 在无法读取其清单时给出未验证提示。",
        "引用本模组缺失为 error；Core 缺失为 warning（草案文件跳过）；其他命名空间只提示外部引用。",
        "结果包含 counts 与 stats（定义/文件/语言/资源数量）。"
      ]
    }
  },

  "SNModMaker/js/store.js": {
    role: "项目模型与纯数据操作：模板、定义增删改复制、Manifest 同步、导入导出映射与 Core 克隆。",
    dependencies: ["catalog.js", "core-index.js"],
    contracts: [
      "项目以 `contentFiles/localization/assets` 为真源，`manifest.content/localization/assets` 每次由 `syncManifest()` 重建。",
      "`schema_version` 由内容类型推导（运行时类型 1.0、Schema 2.0 草案 2.0）：新建文件、归一化、导出都写类型版本，导出/重新导入保留草案 2.0。",
      "所有定义 ID 必须使用本模组命名空间；local ID 在共享 `keyPrefix` 的类型间也保持唯一，避免本地化键碰撞。",
      "`keyBaseOf()` 优先信任 `name_key` 去掉 `.name` 的前缀，兼容 Core 中 ID local 与键前缀不一致的情况。",
      "导出固定加 `mods/<id>/` 前缀；导入接受带/不带前缀的目录与 ZIP，并保留缺失文件为占位以便报错。",
      "资产以 data URL 存项目；导出时解码为字节；`checksum` 不在网页端计算。"
    ],
    l2: {
      "createProject(options)": [
        "创建 Manifest + zh_CN/en 两个语言文件，再按模板写入定义；模板包含 goods / boiler / event / weapons / starter_kit / blank。",
        "`template: null` 时不写 1.0 模板；`drafts` 数组里的每个 Schema 2.0 草案类型由 `addDraftStarter()` 生成一个 contentType/2.0 内容文件与起始定义，并把该类型的 capability 去重写入 `manifest.capabilities`（纯 2.0 项目不附带 1.0 商品起始定义）。",
        "模板只使用默认值与 Core 引用，生成后立即由 `syncManifest()` 对齐清单。",
        "`applyTemplate(project, 'weapons')` 从 `catalog.WEAPON_PRESETS` 生成 5 条 weapons 草案定义（`content/weapons.json`、`schema_version` 2.0），`information.model` 写 `asset://core/model.weapon.<local_id>`，并把 `content.combat.v1` 去重加入 `manifest.capabilities`；只写编辑器项目，不触碰 Core。",
        "`applyTemplate(project, '<draft_type>')` 与 `new --draft <type>` 的单条起始定义不同：前者是成品包（weapons 5 件），后者走 `addDraftStarter()` 的单条默认值。"
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
        "内容 envelope 保留 `schema_version/content_type/definitions`，`schema_version` 按类型推导。"
      ],
      "fromFiles(entries)": [
        "定位最短路径的 `manifest.json`，剥离根目录；按清单读取内容/本地化/资产。",
        "内容文件保留显式 payload 版本（缺失时回退类型版本），让 1.0↔2.0 误配被校验器报出。",
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
      "Schema 2.0 草案类型复用同一套 Schema 驱动表单；`schema-bundle` 缺少该 Schema 时给出提示并退回原始 JSON 编辑，而不是整页报错。",
      "标准实体表单额外呈现所有语言的名称/描述暂存输入，以及 information.texture/model 资源键配置。",
      "贴图与模型不用浏览器原生 datalist：图片候选仅含 png/webp/svg，模型候选仅含 GLB，并保留直接输入资源键能力。",
      "船体把 cargo_slots/cabin_slots 移入专属模块区，并展示运行时固定的锅炉、导航、安全各一槽；普通数据区不重复渲染。",
      "船体安装点子面板：`weapon_sockets` / `rig_sockets` 表格行可增删，按 `socket_class` / `socket_kind` 着色徽标，重复 name / 索引就地提示；武器草案复用通用 Schema 渲染并显示中文枚举标签。",
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
      "「新建模组」对话框的模板卡片来自 `Catalog.TEMPLATES`（goods / boiler / event / weapons / starter_kit / blank）；选 `weapons` 即「舰载武器包」，仅创建编辑器项目内容、不写 Core。",
      "侧栏在运行时类型分组之后渲染「Schema 2.0 草案 / 运行时不加载」分区（`DRAFT_TYPES` 为空则隐藏）；草案内容页显示 2.0 徽标与提示，并隐藏「从 Core 复制」。",
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
        "船体安装点的 `array-add` 走 `nextSocketItem` 生成默认 socket 行（weapon / rig 两套默认值），写回仍走 `data-field` 路径与既有撤销 / 校验流程。",
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
    role: "把 `schemas/` 下全部 `*.schema.json`（含 `v2/` 草案）递归打包为可直接 `<script>` 引入的 `js/schema-bundle.js`。",
    contracts: [
      "bundle key 是相对 `schemas/` 的 posix 路径：顶层仍是 basename，草案为 `v2/...`，与磁盘文件一一对应（当前 28 个：18 顶层 + 10 个 v2）。",
      "生成文件头带 AUTO-GENERATED 标记；修改任何 Schema 后必须重跑。",
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
      "默认只监听 `127.0.0.1`；`SNMODMAKER_HOST` 可改绑定地址（容器设 `0.0.0.0`），默认端口 8099。支持 `SNMODMAKER_MODS_DIR` / `SNMODMAKER_EXPORTS_DIR` / `SNMODMAKER_GAME_MODS_DIR` / `SNMODMAKER_WORKSPACE_ROOT` 覆盖目录；工作区根默认是仓库 `dev_mods/`。",
      "默认部署目标由 `game_mods_dir.mjs` 解析为 `dist/build/<platform>/mods/`（优先已有的导出平台目录）。",
      "API：status、projects、workspace、exports 与 game-mods；请求体上限 128 MB。",
      "`/api/workspace/<id>` 直接读写 `dev_mods/<id>`：打开时返回 manifest/content/localization 与资产键占位（不含二进制），保存时只写文本文件并删掉 manifest 不再声明的 content/localization 文件；资产目录永远不动。",
      "工作区内容文件缺失 `schema_version` 时按 `content_type` 推导（Schema 2.0 草案 2.0，未知类型回退 1.0）。",
      "工作区保存允许删除/新增定义与内容文件；`/api/workspace/<id>` DELETE 被拒绝，避免误删整个原生模组。",
      "游戏部署使用稳定文件名 `<id>.snavmod.zip`，临时文件写完后替换目标，并清理同 ID 的旧版本号包，避免重复模组。",
      "项目先写临时目录再替换，文件路径拒绝绝对路径、`..`、盘符与超过 16 层。",
      "静态文件带 `Cache-Control: no-store`，路径解析后必须位于 SNModMaker 目录内。"
    ]
  },

  "SNModMaker/Dockerfile": {
    role: "零依赖容器镜像：Node 22 Alpine 打包静态编辑器与 tools/，以 node 用户运行，所有可写目录重定向到 /app/data 命名卷。",
    contracts: [
      "构建上下文是 `SNModMaker/`（`.dockerignore` 排除本地 `mods/`、`exports/`），支持 `docker build -t snmodmaker:local SNModMaker`。",
      "设置 `SNMODMAKER_HOST=0.0.0.0` 仅用于容器端口映射；宿主机 compose 仍只发布到 `127.0.0.1`，远程访问交给 tailscale serve。",
      "`SNMODMAKER_MODS_DIR` / `EXPORTS_DIR` / `GAME_MODS_DIR` / `WORKSPACE_ROOT` 全部指向 `/app/data/*`，镜像层保持只读；工作区根在容器内，不写回宿主机 `dev_mods/core`。",
      "镜像内预创建 `/app/data/*` 并 `chown node:node`，配合命名卷首挂载继承属主。"
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
    role: "SNModMaker 内容 CLI（零依赖 Node ESM）：types / describe / list / add / set / loc / rm / clone / validate / new 十个无头命令，按 Schema 增删改定义、补本地化并校验；类型清单含 16 个运行时类型与 9 个 Schema 2.0 草案类型（含舰载武器 `weapons`）；`new --draft` 可直接创建纯 2.0 草案项目。",
    dependencies: ["SNStore", "SNValidate", "SNCatalog", "content_json.mjs", "Node 内置模块"],
    contracts: [
      "十个命令由 `COMMANDS` 分发表进入；`parseArgv` 支持 `--flag value` / `--flag=value`、重复 flag 收集为数组与 `--` 之后的按位置参数，`--help` 退出 0。",
      "复用网页端引擎而非另写规则：经典脚本按 schema-bundle → core-index → content-types → catalog → validate → store 的顺序 require 到 `globalThis`，校验、注册与本地化都走 `SNStore` / `SNValidate` / `SNCatalog`。",
      "`types` 同时列出运行时类型与 Schema 2.0 草案（`draft: true`、`schema_version`、`capability`；JSON 附 `activeTypes` / `draftTypes`）；`describe` 标草案并提示运行时不加载；`add` / `set` / `new` 写出的 `schema_version` 按类型推导（草案恒 2.0）。",
      "`new --draft <content_type>`（可重复）创建纯 2.0 草案项目：每类一个内容文件 + 起始定义，capability 自动写入 manifest；未知草案类型按用法错误退出 2；与 `--template` 同时给出时叠加 1.0 模板与草案内容。",
      "`new --template` 的模板清单来自 `Catalog.TEMPLATES`（goods / boiler / event / weapons / starter_kit / blank）；`weapons` 即「舰载武器包」，一次生成 5 条 weapons 草案定义（`asset://core/...` 模型 + `content.combat.v1`），未知模板按用法错误退出 2。",
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
        "`--draft <content_type>` 可重复，交给 `createProject({ drafts })` 生成 2.0 草案项目；只给 `--draft` 时 template 传 null（不附带 1.0 商品起始定义），`--template` 与 `--draft` 同时给出则叠加。",
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
    role: "Content CLI 集成测试：用 node:test 子进程调用真实 CLI，在临时模组目录覆盖十个命令、保源写回、校验闸门与 JSON 输出；含 `weapons` 草案类型与「舰载武器包」模板。",
    contracts: [
      "每个用例在 `fs.mkdtempSync(os.tmpdir())` 建临时模组；仓库 `dev_mods/core` 只读（部分用例比对前后 SHA-256），任何写操作都不落在仓库内。",
      "覆盖 types / describe / list / new / add / set / loc / clone / rm / validate 的正常路径与用法错误、`--dry-run` 不写盘、最小 diff 与 add → rm 逐字节还原（含 BOM）、本地化专属键清理、`--json` 单一对象与退出码 0 / 1 / 2；`describe weapons` 与 `add --type weapons`（写 `schema_version: \"2.0\"`）在列。",
      "`new --template weapons` 生成 5 条 weapons 草案定义与 `content.combat.v1` capability、不生成 1.0 商品；未知模板拒绝时错误信息列出 weapons 在内的可用模板。",
      "运行：`node --test SNModMaker/tests/content-cli.test.mjs`（从仓库根执行），只用 Node 内置模块，不引入第三方依赖。"
    ]
  },

  "SNModMaker/tests/run-tests.js": {
    role: "Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP、导入导出往返、GLB 解析与部署目标解析；含 `weapons` 草案、船体 socket 镜像与「舰载武器包」模板用例。",
    contracts: [
      "不依赖浏览器或 Godot；直接 require 经典脚本并以 `globalThis.SN*` 访问模块。",
      "覆盖实体多语言键事务、资源候选类型过滤、船体模块区、武器表单字段、船体安装点编辑、贴图/GLB 引用、GLB 解析与发布包 mods 目标解析；任何失败以退出码 1 结束。",
      "「舰载武器包」模板断言 5 件预设（`WEAPON_PRESETS`）、生成一个 `content/weapons.json`、每条 `information.model` 为 `asset://core/model.weapon.*` 且 manifest 声明 `content.combat.v1`。"
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
    role: "Chrome DevTools Protocol 冒烟测试：新建项目、实体键事务、模块子分页与船体模块区 / 安装点面板、本地化、自定义资源选择器、ZIP、导入与撤销。",
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
    role: "迭代 2 主界面接线测试：把真实外壳场景挂进场景树，断言六条反馈在界面构建路径上真的生效，并守护通报文案的本地化；另覆盖 Bounty Train 式主界面（默认 3D 舞台 + 紧凑顶部 HUD + 资源图标 + 主题化两侧招牌 + 底部状态条 + 详细总览抽屉 + 2D 回退）、连续港区三站位的页面接线（overview/market/supply 共用同一舞台实例、镜头与船移动、右侧泊位面板），以及 960 窄布局 helper。",
    contracts: [
      "首帧运行器让 `_ready` 正常投递，因此控件树（含 SNSectionHeader 等自行构建子节点的组件）与游戏内一致。",
      "覆盖信息条（当前港口 + 剩余载重/剩余舱容，反馈 5）、通关清单与两种提示分支（反馈 6）；期望值独立复算（RegistryHub 翻译 + ShipOps 重量/舱容 + printf），不使用被测 helper 自证。通关清单只在总览页渲染：船厂页断言不再出现 `ui.victory.plan_title`，改为出现「组件」分类入口。",
      "模块损耗可见性：健康船信息条不出现「部件」chip；对锅炉实例造成 50% 损耗后刷新，信息条出现「部件」chip 与「1 · 50%」，船厂船卡出现「受损部件」行与同一数值（期望文案来自 shell._tr 与实例状态，不用 UI helper 自证）。",
      "覆盖船厂下单按钮 → CraftOps 订单 → 在港等待按钮 → 时间推进与成品入下单港仓库（反馈 4，经由真实按钮 pressed 信号）；打造入口在改装态模块分类内，下单后重建的页面必须保持改装态与分类，24 小时等待按钮在「杂项」页签。",
      "场景接线断言覆盖独立总览、市场、委托、船厂、补给、情报、海图页面及四个菜单页面；船厂流程从 ShipyardScreen 的真实按钮驱动。",
      "流程场景接线覆盖港口记忆、抵达结算、航行中、航行事件与通关总结，逐一调用 Shell 构建入口并按脚本类型断言实例。",
      "依赖详细总览面板的旧用例（信息条、通关清单、航行记录）先在 `_overview_detail = true` 下 `_refresh()`，因为默认主视图是裸 3D 舞台；其余断言不改。",
      "覆盖设置/总览/市场/船厂/港口记忆密集字段禁用自动换行、市场与快照单元格最小宽度，以及情报矩阵固定元数据列、可扩展港口列、最小列宽和深色单元格背景。",
      "覆盖补给页损失带：买煤后水的 meter.loss_value/cap_loss 与 baseline 跨度（反馈 2）、情报页 SNIntelTable 与未知港口掩码（反馈 3，列数对照 MapOps.ports）。",
      "覆盖「航行记录」：真实下单 + 等待后在 zh 与 en 两种 locale 下逐行断言通报无 `%s/%d` 残留、无裸键，并与**逐语言写死的期望句子**相等（模板槽位互换照样能渲染，只有字面期望能抓住「某一种语言的文案说反了」；en 只写错顺序时该用例会失败）。",
      "扫描 domain/application 源码里所有 `push_notice(\"…\")` 字面量：每个键在 framework 或 core 的 zh_CN/en 中恰好被一套定义，两套 locale 的键集合与**保序**槽位序列一致；槽位多于一个的键必须出现在用例的逐语言字面期望清单里。",
      "组件按路径 preload，不依赖编辑器全局类缓存。",
      "`test_overview_defaults_to_the_3d_port_stage_with_compact_chrome`：seed 5205 切总览后断言 `_overview_stage_mode` 默认 true、`PortStage` 已挂载且设施数 = port.view；`_top_chrome` 最小高度 ≤130 px，且港口/金钱/声望/剩余载重/货舱/耐久/煤/水 chip 与 6 个导航按钮 + 海图切换、诊断/刷新按钮全部保留（4.3.4/U7 删除出航导航页）。",
      "HUD 图标：`AssetService.find_key(\"icon.money\")` / coal / water 均能解析且 `has()` 为真；chrome 里至少 3 个 `TextureRect` 且每个都有已加载纹理（缺资产时页面应退化为纯文字，不产生空纹理节点）。",
      "窗口缩放说明：`canvas_items + expand` 把 960×540 窗口映射为缩放后的 1600×900 逻辑画布，因此 chrome 保留全部 chip（含剩余载重/货舱），不设 compact 分支；960×540 验收截图是这条布局的证据。",
      "招牌组件：present 设施的 Button 必须 `has_method(\"configure\")`（SNHarborSign）、`custom_minimum_size == 172×42`，`arrow_direction` 与投影左右列一致（左列 -1、右列 1）；文字仍以 `设施 ▶` / `◀ 设施` 结尾/开头。",
      "同一用例断言两侧招牌：投影 x<0.5 进左列（文字 `设施 ▶`）、≥0.5 进右列（`◀ 设施`），数量 = 设施数 + 1（`Hotspot_sea_chart` 固定在右下，4.3.4 起替代出航招牌）；1280×720 重排后数量不丢不重；点 exchange 招牌进入 market。",
      "连续港区页面接线：切到 market 后宿主的 `PortStage` 实例不变（`host.current_stage()` 与切页前同一节点）、舞台保持可见、`_stage_station==market`/`_stage_framing==panel`、`PortStage.current_station()==market`；`_root_box` 下出现 `DockPanelRow` 与 ≥640 px 的 `DockPanel`，页面脚本仍恰好一个实例。headless 不推进帧，用例直接 `port_stage.advance_station()` 断言镜头落到 `station_camera_pose(market, panel)`、船落到 market 泊位。",
      "切到 supply 后仍是同一舞台实例，船从 market 泊位沿岸向东航行到 supply 泊位（两泊位相距 >40 m）；切到 contracts 等非舞台页时宿主隐藏；回到 overview 时舞台恢复并回到 harbor 站位。",
      "`test_overview_stage_falls_back_to_the_usable_2d_overview`：调 `_on_port_stage_fallback` 后 `_port_stage_load_failed` 记忆、stage 模式关闭、2D 地图挂载、显示 `ui.error.port_stage_unavailable`、导航仍可用。",
      "`test_overview_status_strip_and_detail_drawer`：底部状态条可见且最小高度 ≤72，含耐久/货舱/受损/最新通告与「详细总览/出航/等待 12 小时」；打开抽屉后地图与 `ui.victory.plan_title` 出现、舞台未销毁、backdrop 显示、招牌隐藏；返回主界面后抽屉关闭；点等待按钮让 `GameState.now()` +12 h；切到 intel 时状态条隐藏、返回总览恢复、点出航进入 voyage 页。"
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
      "渲染器替换：正常态在 `ship.hull_model_path` 非空（或本地有旧路径回退）时挂载 `SNShipStage3D`，断言 `has_ship()`、`has_stage()`、`stage_id()==\"shipyard\"`；改装态 `is_stage_visible()` 为 false、回 EXTERIOR 重新为 true；无模型时断言保留程序化占位。`set_renderer(provider)` 后节点挂到舞台下，`set_renderer(null)` 恢复内置占位。",
      "拖放端到端：`WarehouseOps.add_module` 在仓库放一个导航模块 → 操作列恰好一行可拖拽；`_on_slot_drop` 发 `ship.install_module`，参数含 module_id / source 与槽位 `replace_module_id`，命令后模块离开仓库并装到船上；异类型部件与 purchase 候选被 `_accepts` 拒绝。",
      "分类导航：每个分类的中间面板标题取 `ui.category.<type>`，货舱按槽位数逐个列出「货舱槽 n」；杂项承载打造订单/在港等待/仓库材料/仓库模块，且不再出现「按配方打造」「槽位」；打造入口留在对应模块分类内。",
      "旧面板守护：`LEGACY_SECTION_KEYS`（parts_hud / warehouse / available_modules / craft / recipes / victory plan 等本地化键）的译文不得出现在页面任意 Label 中；这些键必须仍被本地化，键被删时用例应失败而不是静默通过。`_body` 子节点数恒为 3。",
      "模块状态徽标：健康船不出现「状态 NN%」；对锅炉实例造成 50% 损耗后重建船厂页，锅炉槽位卡出现 `ui.label.status` 50% 徽标（条件值来自 shipyard.view 的 condition，不在页面计算）。"
    ]
  },

  "framework/tests/cases/test_stage_host.gd": {
    role: "2.5D 舞台契约测试（30 个同步用例）：LocationStage 默认契约、SNStageHost 生命周期/回退/停更、ShipyardStage 场景、SNShipStage3D 适配器、PortStage 装配/替换/缩放/portal、场景填充访问器、港口街坊 town kit 与 size/density 分档、静态与玩家船合批、无 banner 程序化远景、连续港区三站位的相邻/聚焦/航行/重建保持，以及查询接线。",
    contracts: [
      "全部是同步函数（无 await）：节点在同一步内加入 SceneTree 即同步派发 `_ready` 与 `add_child` 通知，挂载/卸载可在一步内断言；每个用例自建节点并在结尾 free，避免残留节点影响其他套件。",
      "LocationStage：裸节点 `stage_id` 为空、`has_visual()` true、`hotspot_anchors()` 空、`portal_requested` 可发。",
      "SNStageHost：`stage_mounted` / `stage_unmounted` / `portal_requested` 转发；`enter` 先于 `bind` 且 payload 到达 enter；`bind_view_model` 重绑并缓存；隐藏 → 舞台 `PROCESS_MODE_DISABLED` + viewport `UPDATE_DISABLED`，显示恢复；卸载后 stage_id 清空且可挂新舞台（空 id 回退节点名）。",
      "回退：缺失场景发 `stage_scene_missing:*`；根不是 LocationStage 的 `sn_badge.tscn` 发 `stage_not_location_stage:*` 且不挂载。",
      "ShipyardStage：真实场景可加载、根类型与 stage_id 正确；`hull_tier=1` 绑定后 `has_ship()` 且 `model_path()` 含 `SN_Paddle_Steamer`。",
      "SNShipStage3D 适配器：`_ready` 自动挂船厂舞台；`ship_view_update` 转发 `hull_model_path`；`ship_view_set_mode(1/0)` 隐藏/显示；`ship_view_highlight` 可调用。",
      "PortStage 四组：present 设施才有锚点/热点且缺席只 filler（缺省 billboard / missing）；`facility_visuals` GLB 替换与非法路径回退 billboard；`size` 0.9/1.15 缩放锚点；`hull_model_path` 挂玩家船 + `request_portal` 经 host 转发。",
      "PortStage 投影锚点断言有限值，缺席设施投影返回 `Vector2.ZERO`；`has_backdrop()` 在无 banner 时为 false。",
      "场景填充访问器（无 banner、medium）：`foreground_frame()` 非空、`atmosphere_particle_systems()` ∈ 1..3、`atmosphere_layers()>=1`、`skyline_building_count()==10`、`skyline_crane_count()` ∈ 2..3、`has_backdrop()==false`。",
      "size 缩放：small/medium/large 三次 bind 分别断言 `skyline_building_count()` 为 7/10/13，large 吊机 ≤3；铁港 banner 绑定后 `has_backdrop()==true`、L2 建筑/吊机归零，L6/L7 仍存在；去掉 banner 后 L2 恢复为 10。",
      "隐藏/显示宿主：`set_stage_visible(false/true)` 往返后访问器返回同一前景框节点，粒子/雾带/建筑/吊机计数保持稳定。",
      "town kit 装配（`test_port_stage_town_kit_mounts_full_streetscape`）：`TOWN_VISUALS`（10 个 SN_HT_* + 16 个复用道具/设施路径）经 `port.town_visuals` 绑定后 normal 密度 `town_prop_count()==47`（5 建筑 + 7 围栏 + 7 工人 + 8 装饰 + 3 船 + 17 码头工业件）、`town_blockout_count()==0`、`skyline_building_count()==0`；有 banner 时 town 仍为 47（town 与 banner 独立）。",
      "密度分档（`test_port_stage_town_density_scales_with_size_and_override`）：small/medium/large 默认 sparse/normal/busy = 28/47/63 props；`port.density` 与 `port.diorama.density` 都能覆盖 size 推导，非法值回退 size 推导。",
      "可选 town slot：缺少新工业件 slot 时只是少挂 props（不报错、不产生 blockout），核心建筑/围栏/工人仍在。",
      "静态合批（`test_port_stage_batches_static_layers_into_few_draws`）：`batch_stats()` 的 `meshes_after < meshes_before`、`batches > 0`、`surfaces_after < surfaces_before`，town_prop_count 不变；无 town 时设施 billboard 仍被合批（`test_port_stage_without_town_still_batches_facilities`）。",
      "玩家船刚性合批（`test_port_stage_batches_player_hull_rigidly_and_keeps_foam_bounds`）：`has_ship()`、`ShipBatches` 挂在 `PlayerShip` 下、船体 mesh/surface 从 32/90 降到 9/9、`ship_fallback=false`；`ship_foam_bounds()` 与重新实例化原 GLB + 同 ship root 变换逐项一致（0.01 容差）。",
      "非刚性回退（`test_port_stage_ship_batching_falls_back_for_non_rigid_hulls`）：动画/Skeleton/粒子/透明材质任一出现 → 整船不批、`ship_fallback=true`；普通 opaque 刚体 → 接受；默认可玩船型 fallback=false。",
      "无 banner 远景（`test_port_stage_painted_backdrop_has_depth_layers_without_banner`）：`painted_backdrop_layer_count()==3`；绑定 banner 后归零（整组隐藏）。",
      "无 town kit：`town_prop_count()==5`、`town_blockout_count()==5`（5 座建筑 blockout），且 L2 skyline 计数仍按无 banner 规则生成（town 缺失才建 L2）。",
      "非法 town 路径：单个建筑路径改成不存在文件 → 该建筑回退 blockout（blockout=1、prop 仍 47）；全部路径非法 → 5 个 blockout、围栏/工人/船/装饰/工业件缺失（prop=5）。",
      "`port.view` 端到端：`bootstrap_core()` + `run.start` 后执行 port.view，`current_port.diorama.kit` 非空、`town_visuals` 26 项且路径以 `res://` 开头；用该 payload bind PortStage 后 normal 密度 town 仍为 47/0（旧存档按 archetype 回填）。",
      "连续港区站位（`test_port_stage_stations_are_adjacent_along_one_quay`）：`station_ids()==[market,harbor,supply]`；三个泊位 X 严格递增且 market→supply ≥50 m；三站位 FOV 相同、market 相机 X < harbor；`panel` framing 恰为 `stage` framing 平移 `PANEL_FRAMING_SHIFT_X`；未知站位被拒绝且不移动当前镜头。",
      "聚焦与航行（`test_port_stage_focus_station_pans_camera_and_sails_the_hull`）：`focus_station(market)` 后 `is_station_transitioning()` 为 true，`advance_station()` 分步推进后镜头落到 market pose、船 X 到 market 泊位；`PlayerShip` 节点、`town_prop_count`、`station_prop_count`、`facility_count` 全部不变（没有重建）；再聚焦 supply 时船先向东航行再落到 supply 泊位。",
      "过渡中重定向（`test_port_stage_redirect_mid_transition_continues_from_current_pose`）：market→0.2 s→supply 时相机从当前位置续 pan，不瞬跳回旧目标；0.05 s 位移 <8 m，最终仍落到 supply pose。",
      "立即聚焦与幂等（`test_port_stage_focus_station_immediate_and_idempotent`）：`immediate=true` 直接 snap 镜头/泊位且不进入过渡；重复 focus 当前站位不重启动画、镜头位姿不变。",
      "重绑保持站位（`test_port_stage_bind_keeps_the_current_station_and_berth`）：supply/panel 下换船（bind 签名变化 → 真重建）后 `current_station`/framing/相机不变，新船体挂在 supply 泊位而不是参考 spawn。",
      "站前道具密度（`test_port_stage_station_dressing_scales_with_density`）：small/medium/large → 15/24/33 件（每站 5/8/11 × 3），`diorama.density=busy` 覆盖；无 town kit 时 0 件且不生成占位盒。"
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

  "tools/godot/capture_port_stage.gd": {
    role: "PortStage 真实渲染截图（窗口模式 1440×900）：加载 `port_stage_preview.tscn`，依次抓 `preview`（harbor/stage）、`sparse`、`market` 站位、`supply` 站位与 `harbor` 的 panel 构图共 5 张，输出到 `docs/design/screenshots/port_stage/`。",
    dependencies: ["dev_scenes/port_stage/port_stage_preview.tscn"],
    contracts: [
      "必须窗口模式：`DisplayServer.get_name() == \"headless\"` 时直接失败（视口纹理为空）。",
      "稳定窗口：首次 90 帧 + 1 s，切换 variant/站位后 30 帧 + 0.5 s；每张额外轮询 `is_station_transitioning()==false` 且 `StageCamera` 位置接近 `station_camera_pose()`（≤0.75 m、朝向 dot>0.999）再截，空图/保存失败计为 failures。",
      "成功条件：5 张图都保存且 failures=0，否则退出码 1；文件名 `port_stage_preview/sparse/market/supply/harbor_page.png`。",
      "先写 `res://tmp_*`，全部成功后才搬进 docs 并删除 tmp；120 s watchdog 防止协程挂住窗口；只写截图，不修改场景/源码。"
    ]
  },

  "tools/ui_snapshot.gd": {
    role: "真实渲染 UI 截图验收：以与框架测试一致的 bootstrap 启动 Core，挂载 main.tscn，截取船厂正常态/改装态/分类/受损状态，并可选截取主界面（全窗 3D 港口舞台 + 紧凑 HUD + 两侧招牌 + 底部状态条）、详细总览抽屉，以及市场/补给页的泊位侧栏（舞台 + 右侧面板）及其 960×540 版本。",
    contracts: [
      "必须窗口模式运行：`--headless` 时视口纹理为空，脚本直接判失败。",
      "参数走 `--` 之后：`--seed` / `--out-dir` / `--window` / `--category` / `--damage` / `--skip-refit` / `--overview-stage` / `--overview-detail` / `--station-shots`。",
      "`--damage=slot[:index]:ratio` 在 run.start 后用 `ShipModules.damage()` 损坏模块实例，额外截取 `shipyard_normal_damaged` / `shipyard_refit_damaged` / `supply_damaged`；只影响截图进程，不进入游戏逻辑。",
      "`--overview-stage`：切到总览（默认即 3D 舞台，若处于 2D 回退才调 `_on_overview_stage_toggle()`）→ 断言 `_overview_stage_mode`、`PortStage` 宿主可见、设施数 > 0、`has_ship()`、招牌数 = 设施数 + 1、`_top_chrome` 高度 ≤130、底部状态条可见 → 保存 `overview_port_stage.png`。",
      "`--overview-detail`：在 `--overview-stage` 基础上点底部「详细总览」按钮（兜底直接置 `_overview_detail=true` 并 refresh），断言抽屉打开、总览页仍挂载 → 保存 `overview_detail.png`。",
      "`--station-shots`：分别切到 market / supply 页，轮询 `_port_stage_host` 的 `has_stage()+is_stage_visible()`、`PortStage.current_station()==目标` 且 `is_station_transitioning()==false` 后截图，保存 `market_station.png` / `supply_station.png`，并在同一进程内把窗口缩到 960×540 补拍 `market_station_960.png`，用于验证缩放下舞台与侧栏都不裁切。",
      "进入改装态优先点页面真实「改装」按钮，其次调 `_on_toggle_refit()`，最后按按钮文案兜底，页面小改版后工具仍可用。",
      "纯色画面判定为失败；120 s watchdog 防止协程中断挂住窗口；成功退出码 0，失败 1。",
      "只写 `docs/design/screenshots/`（或 `--out-dir` 临时目录），不修改游戏状态或源码。"
    ]
  },

  "tools/capture_ui.ps1": {
    role: "`tools/ui_snapshot.gd` 的 PowerShell 包装：窗口 1440×900 跑真实渲染截图，并校验产物新鲜度。",
    contracts: [
      "引擎解析顺序：`-GodotBin` > `$env:GODOT_BIN` > 本机默认路径；找不到直接抛错。",
      "默认 seed 5201、输出 `res://docs/design/screenshots`、额外分类 `cargo_modules,misc`；`-SkipRefit` 只截正常态；`-Damage boiler:0.5` 额外生成受损状态截图并要求它们新鲜；`-OverviewStage` 透传 `--overview-stage` 并把 `overview_port_stage.png` 加入期望截图；`-OverviewDetail` 再透传 `--overview-detail` 并追加 `overview_detail.png`（隐含 `-OverviewStage`，同样校验新鲜度）。",
      "检查每张期望截图存在且比本次运行新，旧图/缺图把退出码改为 1；完整日志写入 `.godot-ui-snapshot.log`。",
      "脚本保持 ASCII，兼容 Windows PowerShell 5.1 解析。"
    ]
  },

  "tools/modeling/briefs/sn_harbor_town_batch1.json": {
    role: "港口街景建筑/人物/小船第一批 10 件建模工单：集合 `SN_Harbor_Town`、前缀 `SN_HT_`、工作台 y=110 一排；定义 10 件尺寸/单件 tri 预算（合计 ≤11500）/调色板（含新增 SN_Brick/SN_Plaster/SN_Glass_Dark）/轴心与验收规则。",
    contracts: [
      "物件：长仓库 20×9×11 / 短仓库 11×9×9.5 / 港务楼 9×8×14（钟楼地标）/ 货棚 8×6×4.5 / 酒馆 10×8×8 / 围栏 6×0.3×1.5 / 工人 A 0.7×0.45×1.8 / 工人 B 0.8×0.5×1.8 / 划艇 4.2×1.5×0.8 / 驳船 8×3×1.6。",
      "轴心统一底面中心（z=0）、+X 前向；窗/门只是 0.05–0.1 m 深暗色板，招牌/钟盘/门牌禁止文字，不做室内/碰撞/可进入门；单写者、只创建、不保存 .blend、不导出 .glb。",
      "验收：10 件命名 100% 匹配、总 tri ≤11500 且单件 ≤1.2×预算、包围盒误差 ≤0.15 m、网格健康（无孤立点/退化面/材质槽越界，闭合件非流形边 0）、既有对象数量/名称/位置回归不变。",
      "导出产物在 `dev_mods/core/assets/models/props/SN_HT_*.glb`（内容资产随 core 模组发布，不放 `assets/models/*`），由 Lead 验收后统一执行 `export_town_glb.py`。"
    ]
  },

  "tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json": {
    role: "铁港近中景城镇建筑视觉升级工单：以模块化中等精度建筑替换 PortStage 白盒，定义 8 类建筑、共享材质与纹理、LOD 和固定机位门禁。",
    contracts: [
      "现有 SN_HT_Warehouse_Long / Warehouse_Short / Harbor_Office / Cargo_Shed / Tavern 保持资产名和近似占地尺寸，可原位替换；另新增 Boiler_House / Workshop_Row / Brick_Tenement。",
      "几何必须提供真实窗门深度、墙顶厚度和受控倒角；长度超过 6 m 的可见墙面至少用两种结构方式打断，不允许退回纯盒子或共面窗门。",
      "典型 PortStage 同屏建筑目标 <=60000 tri；LOD1 <= LOD0 的 35%；每栋材质槽 <=6，并共享 2K trim sheet 与 1K 污渍遮罩。",
      "Builder 只写 SN_Iron_Harbor_Architecture 集合并交付生成器/LOD/预览；运行时接线、manifest、打包和旧 GLB 替换由 Lead 在人工验收后执行。"
    ]
  },

  "tools/modeling/generators/sn_iron_harbor_architecture_kit_generator.py": {
    role: "铁港建筑套件样板：`SN_HT_Warehouse_Long` LOD0 的几何唯一真源（纯 Python 几何 + Blender 内 `build_all()/report()`），建单 mesh 对象 `SN_HT_Warehouse_Long_LOD0` 并把材质/UV 交给共享材质模块；几何已在 R1 冻结。",
    contracts: [
      "R1 实测：**7 436 tri / 4 486 顶点**、20.000×9.000×11.000 m、轴心底面中心、`object.location=(-48,110,0)`，与旧占位资产同名同址；重跑只删除本集合内 `SN_HT_` 对象，`SN_Harbor_Town` 的旧 `SN_HT_Warehouse_Long` 原样保留（report 用全场景 digest 回归）。",
      "主立面在本地 **+Y**、背面 −Y、山墙吊梁在 +X：PortStage town 槽位 yaw=−90° 时固定机位（world +X/+Z 一侧）只能看到本地 +X 山墙与 +Y 长墙，旧资产把门窗放 −Y 在该机位不可见，故样板按可见面重排主立面。",
      "R1 细化：双高门双道滑轨 + 3 吊架 + 每扇 2 滚轮 + 石/铁门槛 + 3.10×0.30 m 铁短平台；山墙吊梁加铁牛腿/双滑轮组/梁端板/斜拉杆；**4 段檐沟**接 4 落水管雨水斗；侧墙改 4 窗 + 3 壁柱；石基压到 **0.58 m** 并收窄到 19.56×8.56；檐口顶面抬到 7.53（与屋面底皮只留 0.02 阴影缝，消除檐口黑边）。",
      "`panel()` 生成带矩形凹口的闭合厚墙板：凹口侧壁/凹底按同一组网格线切分保证流形，窗凹 0.16 m、装卸门 0.28 m、人门/服务门 0.26 m（门扇面再退 0.16/0.20 m），墙体厚 0.46 m，不是共面深色板。",
      "倒角不用全局 Bevel 修改器（会把砌块共面接缝切出沟槽），改显式倒角：主要轮廓 2 段（屋面檐口上棱 0.06 双段、石基压顶 0.015×2），次要构件 1 段（檐口 8 点型材最大出挑 0.30 m、吊货梁与壁柱/竖梃八边形截面、通风帽锥形帽、石窗台斜面）；主墙毛角由转角壁柱遮挡未单独倒角。",
      "资产是多个互不相连的闭合实体拼装（非焊接单壳体），为保边界边=0 保留墙板内皮与石基底面；独立 Verifier 共面审计 477 对 / 5.74 m²，**0 对位于最外层 AABB 平面、0 对位于墙外表面**（最大外露为檐沟转角同材质 0.0112 m²，不可见；门槛挡铁 2 处跨材质 0.0088 m² 已内收 0.05 m 修掉），实机与六视图均无 z-fighting。",
      "材质槽固定 6 个 `SN_Town_*`；`build_all(textured=True)` 建完对象后调用 `sn_iron_harbor_materials.apply_to_object()` 写 UV + 绑 trim sheet 贴图（模块按文件路径 importlib 加载，不依赖 sys.path；贴图缺失自动退回灰阶占位），`report()` 的 `textures` 段输出 uv 范围/loop 数/绑定贴图/校验，几何 `checks` 增加 `uv_loops_complete / geometry_unchanged_by_uv / all_images_bound / texture_slots_6` 四项，`checks.all_pass` 必须为 true。"
    ]
  },

  "tools/modeling/generators/sn_iron_harbor_warehouse_short_generator.py": {
    role: "铁港建筑套件第二批：`SN_HT_Warehouse_Short` LOD0 的几何唯一真源（纯 Python，无 bpy），Part 交给 `sn_iron_harbor_kit_batch2.py` 装配/上材质/导出。",
    contracts: [
      "实测 **3 788 tri / 2 294 顶点**、11.000×9.000×9.500 m、轴心底面中心、zmin 0、材质槽 6、边界边/非流形边/孤立点/退化面全 0；`dryrun_props.py` 干跑 ALL OK。",
      "主立面在本地 **+X** 端面（槽位 yaw −90° 时正对固定机位，偏轴 ≈11°）；+Y 侧是单坡侧棚所在的次可见面（掠射 ≈78°），−X/−Y 放服务门、后勤窗、落水管。",
      "该栋特征：3 级收分石基 0.55 m、不对称单坡侧棚（3 木柱 + 斜撑 + 4.60→3.35 屋面）、1 个内凹 0.26 m 的 3.0×4.3 装卸门（含滑轨）、2 扇 1.15×1.45 真凹窗（凹 0.14）、山墙灰泥三角 + 0.8×0.8 山墙窗、2.0×0.55 空白木招牌、1 根偏置铁通风管（Ø0.24）、屋脊沿 X 的双坡铁屋面 0.22 厚（3 道立缝/坡）。",
      "与参考实现 `sn_iron_harbor_architecture_kit_generator.py` 同一套 `panel()` 真凹口墙板 + 显式倒角写法，辅助函数逐字复制，保证套件语言一致。"
    ]
  },

  "tools/modeling/generators/sn_iron_harbor_harbor_office_generator.py": {
    role: "铁港建筑套件第二批：`SN_HT_Harbor_Office` LOD0 的几何唯一真源（纯 Python，无 bpy）；镇里最高的钟楼地标。",
    contracts: [
      "实测 **10 336 tri / 6 292 顶点**、9.000×8.000×14.000 m、轴心底面中心、zmin 0、材质槽 6、网格健康全 0；`dryrun_props.py` 干跑 ALL OK。14.00 m 是包围盒最高点（八棱尖顶 + 铁尖），旗杆只在 13.60。",
      "主立面在本地 **+X** 端面（槽位 yaw −80° 时偏轴仅 ≈7°）；+Y 侧 9 扇窗 + 2 根落水管，−X/−Y 只保证水密与开窗节奏。",
      "该栋特征：3 层立面（腰线 4.62 / 7.77）+ 拱形入口（2.10 m 宽、拱顶 3.65、凹 0.28、10 段石拱券 + 拱心石 + 2 级石阶）、27 扇带石窗台/窗楣的窗（凹 0.16）、2 个铁阳台（2.48×0.46 挑板 + 3 横杆 + 4 立柱 + 2 回栏）、四面空白钟盘（⌀1.24 铁圈 + 灰泥盘面 + 铁指针，无数字）×4、3.0×3.0 钟楼塔身到 12.98、檐口 0.40 出挑 2 段折线 + 檐下齿饰、平屋面 + 女儿墙。",
      "窗木/石构件约占 4 200 tri（41%），是 LOD0 预算里最贵的一族；日后压 LOD1 先砍窗棂。"
    ]
  },

  "tools/modeling/generators/sn_iron_harbor_cargo_shed_generator.py": {
    role: "铁港建筑套件第二批：`SN_HT_Cargo_Shed` LOD0 的几何唯一真源（纯 Python，无 bpy）；低矮**开敞**货棚。",
    contracts: [
      "实测 **3 356 tri / 2 112 顶点**、8.000×6.000×4.500 m、轴心底面中心、zmin 0、材质槽 5（木/铁/石/灰泥/玻璃，无砖）、网格健康全 0；`dryrun_props.py` 干跑 ALL OK。",
      "开敞柱廊在本地 **+X**（槽位 yaw −90° 偏轴 ≈28°）：4 根 0.22 八边形木柱 + 檐梁 4.02–4.30 + 系梁 3.26–3.48 + 端开间斜撑，净宽 4.98 × 净高 3.98 m；+X 正面 0.6 m 以上实体面只占 28.9%（71% 透空），因此不会读成封闭小屋。",
      "单坡棚顶 5.57°（4.500 → 3.726）、板厚 0.22、前檐 2 段倒角、出挑 0.37/0.28/0.24、12 道立缝 + 10 道露明椽；后墙 0.28 木拼板 + 后挡板 + 高位真凹小窗，±Y 只 0.98 m 女墙（上部全开）。",
      "内部：工作台（1.84×0.70×0.85）+ 吊钩（5 节链 + J 钩）+ 5 木箱 / 2 托盘 / 2 木桶 / 2 麻袋 / 木梯 / 吊灯，全部是闭合实体；额外硬门禁「不同材质同向共面重叠面 = 0」。"
    ]
  },

  "tools/modeling/generators/sn_iron_harbor_tavern_generator.py": {
    role: "铁港建筑套件第二批：`SN_HT_Tavern` LOD0 的几何唯一真源（纯 Python，无 bpy）；两层门廊酒馆。",
    contracts: [
      "实测 **5 116 tri / 3 064 顶点**、10.000×8.000×8.000 m、轴心底面中心、zmin 0、材质槽 6、网格健康全 0；`dryrun_props.py` 干跑 ALL OK。",
      "主立面在本地 **+X** 山墙端（槽位 yaw −100° 偏轴 ≈43°，仍清晰可见）；+Y 侧次可见（窗 + 铁灯 + 落水管），−X 放服务门。",
      "两层：首层砖 0.43–3.90 / 二层灰泥 3.90–6.60 + 层间石腰带；屋脊沿 X（檐 6.60 / 脊 7.60）、铁屋面板厚 0.22、出挑 0.30、脊瓦 + 3 道立缝/坡；**门廊** 3.90→5.00（= 包围盒 +X）2 木柱 + 斜撑 + 单坡廊顶 + 矮栏；**悬挂空白招牌**（铁托架 + 卷叶 + 0.86×0.58 木牌，无文字）；−X 端砖烟囱顶面正好 **8.00 m**（轮廓最高点）。",
      "16 扇窗全部真凹（0.14）+ 木窗框 + 石窗台/窗楣，其中二层 3 扇带木百叶；入口双开门凹 0.28、后服务门凹 0.20；3 个木桶（12 边形 + 铁箍）放在 +X 立面石基台沿上；主立面两角石砌错缝（quoins）打断 6.6 m 高墙。"
    ]
  },

  "tools/modeling/generators/sn_iron_harbor_kit_batch2.py": {
    role: "铁港建筑套件第二批的 Blender 装配/自检/导出 harness：把 4 个纯 Python 生成器的 Part 变成单 mesh 对象、按栋写共享 trim sheet 材质与 UV、逐栋自检、导出内容 GLB、出预览图。",
    contracts: [
      "`BUILDINGS` 是唯一配置表：生成器文件、资产名、工作台摆放（y=150 一排）、目标尺寸、三角面上下限，以及**本栋采样哪一档 trim sheet cell**（同 6 材质槽、不同 cell = 同一套共享贴图下的建筑差异，不增贴图）。",
      "`build_all()` 只删除本集合内这 4 个 `SN_HT_*_LOD0` 对象，旧 `SN_Harbor_Town` 占位资产原样保留；`report_all()` 逐栋校验 tri 预算/尺寸/落地/轴心/材质槽/调色板/网格健康/UV/贴图，并用全场景 digest 回归证明没有动其它对象。",
      "`export_all()` 逐栋把 object.location 临时归零后单对象导出到 `dev_mods/core/assets/models/props/SN_HT_<Name>.glb`（内嵌贴图）；**旧 GLB 只在备份不存在时复制一次**，绝不覆盖；`restore_legacy()` 一次还原 4 个旧资产。",
      "`render_previews()` 每栋 3 张（3/4 街道 / +X 正交正视 / 屋顶）到 `docs/design/screenshots/iron_harbor_architecture/`；渲染前必须 `view_layer.update()`（新建对象的 `matrix_world` 在 depsgraph 求值前是单位矩阵，会导致取景跑到原点、渲出纯背景），并且只保留当前一栋可见，临时相机/太阳/世界背景在 `finally` 里还原。"
    ]
  },

  "tools/modeling/generators/sn_iron_harbor_materials.py": {
    role: "铁港建筑套件的**共享材质库**：6 个调色板材质槽 → trim sheet 的 6 个 cell（一张 512² 平铺贴图）+ 盒投影 UV + 自检；所有 SN 铁港建筑生成器都调用它，不各自建材质。",
    contracts: [
      "`MATERIAL_SURFACES` 是材质↔cell↔tile_m↔roughness/metallic 的唯一表：Brick→brick_wall、Plaster→plaster_light、Wood→wood_plank_weathered、Iron→iron_dark、Stone→stone_base_dirty、Glass→glass_dark；tile_m 一律 2.0 m（= 256 px/m，与 spec 的 `px_per_m` 一致）。",
      "贴图源：`docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.spec.json`（16 cell 4×4×512 px，无 gutter）+ `tiles/<cell>.png`；图集 `iron_harbor_trim_sheet_2048.png` 只做评审，**不**被 UV 直接采样。",
      "为什么不直接采图集：墙/屋面/石基是单个 20 m 级四边形，UV 限在 cell 内必须切面（实测 +5 416 tri @2 m cell、+1 484 tri @4 m cell，超 7 436+564 的预算），故每材质各取一张 REPEAT 平铺贴图，UV = world/tile_m 无上限，0 tri 增加。",
      "UV 规则：按面法线主轴盒投影（±Y→(x,z)、±X→(y,z)、±Z→(x,y)），不做每部件偏移 ⇒ 砖缝/石缝绕整栋连续、屋面立缝沿坡、门板竖直。",
      "`apply_to_object(obj)` 只改 UV 层与材质槽内容，不动几何（`geometry_unchanged` 自证）；`mesh.materials.clear()` 会把多边形 material_index 归零，因此**必须**先快照每面材质名再清槽（曾因此把整栋刷成 Stone）。",
      "`apply_to_object(obj, cells={material: cell})` 支持**每栋换 cell**（同一套 6 槽/6 贴图，砖石木铁玻璃各选一档；未知材质或未知 cell 直接抛错，不静默回退）；`verify_object(obj)` 校验调色板、槽位 ≤6、UV 完整、每槽贴图绑定 512²、无塌陷 UV 面、palette_spread（至少 5 个材质被用），以及 **`uv_projection_ok`**（按面主轴重算期望 `world/tile_m` 并与存盘 UV 逐 loop 比对，容差 1e-4——这是防下一栋建筑错投影的门禁）；贴图缺失时退回 R=G=B 灰阶占位让几何轮次仍可跑。"
    ]
  },

  "tools/modeling/generators/render_iron_harbor_architecture_preview.py": {
    role: "铁港建筑套件验收截图：临时相机 + 三盏太阳 + 地面 + 世界背景，只对 `SN_HT_Warehouse_Long_LOD0` 出图，渲染后还原可见性/相机/引擎/分辨率/世界并删除临时对象，不保存 .blend、不导出 GLB。",
    contracts: [
      "固定机位由 `framework/ui/stages/port_stage.gd` 换算：Godot eye(46,28,64)/look_at(0,12,-8)/vfov 30°/keep_height + town 槽位 pos(-30,1.9,-33)/**yaw -106°** → Blender eye(24.30,209.79,26.1)/target(-32.24,145.73,10.1)；960×540 用同一垂直 FOV 的横向展开焦距。换算公式：`g = R_yaw⁻¹(p - slot_pos)`，`blender = (-48,110,0) + (g.x, -g.z, g.y)`。",
      "输出 8 张到 `docs/design/screenshots/iron_harbor_architecture/`：固定机位 1440×900 与 960×540、同视角居中复查、街道低机位（1.7 m 眼高）、正交正视（+Y 主立面）、屋顶视图，以及材质近景 `*_detail_door_*`（装卸门一带：砖/木/铁/玻璃/石）与 `*_detail_base_*`（墙脚：石基/砖转角/落水管/檐沟）。",
      "近景只为判读 trim sheet，不是验收机位：`DETAIL_DOOR` / `DETAIL_BASE` 的眼点与目标写在常量表里，改布局槽位不影响它们（它们用工作台坐标）。",
      "渲染期间临时隐藏其它 mesh（含旧占位资产），结束后逐项恢复；不修改任何模型数据与运行时代码。"
    ]
  },

  "tools/modeling/generators/export_iron_harbor_architecture_glb.py": {
    role: "把 `SN_HT_Warehouse_Long_LOD0` 装配进 PortStage 的导出/还原工具：备份旧内容 GLB → 单对象导出（带内嵌 trim sheet 贴图）到内容路径 → 保留候选副本；`restore_legacy_glb()` 还原。",
    contracts: [
      "内容路径 `dev_mods/core/assets/models/props/SN_HT_Warehouse_Long.glb`；备份与候选在 `.design/buildings/iron_harbor/`（`_legacy.glb` / `_R1.glb`），备份只在缺失时复制，绝不覆盖。",
      "导出前把 object.location 临时归零（几何为局部坐标、轴心=底面中心），导出后还原；glTF Y-up、单对象、无相机灯光，与 `export_town_glb.py` 同参数。材质用默认实现：6 个材质各带一张 512² baseColor 贴图，贴图**内嵌**进 GLB（因此单文件 1.4 MB 级；Godot 会把内嵌图**解包**成 GLB 同级的 `<glb>_<image>.png`，那是构建产物，已在 `.gitignore`）。",
      "PortStage 经 `ResourceLoader.load()` 读取已导入场景，替换 GLB 后必须 `godot --headless --path . --import` 刷新缓存，否则仍渲旧模型；M1 起内容路径已装带贴图版本，回滚用 `restore_legacy_glb()` + 再 import（旧备份 sha256 `2576e3db…`）。"
    ]
  },

  "tools/modeling/generators/sn_harbor_town_generator.py": {
    role: "港口街景第一批 10 件的参数化几何唯一真源：顶部 `ITEMS` 参数表（名称/布局/tri 预算/目标包围盒）+ 各 `build_*` 纯几何函数，负责在 Blender 集合 `SN_Harbor_Town` 重建 10 件 `SN_HT_*` 单 mesh 对象。",
    contracts: [
      "`ITEMS` 与工单一一对应；`COLLECTION=\"SN_Harbor_Town\"`、`PREFIX=\"SN_HT_\"`、`ROW_Y=110`；重跑只删除/重建本集合内 `SN_HT_` 对象，不碰其他集合与既有对象。",
      "几何函数（box/prism/roof_slab/sweep/loft 等）为纯 Python、不 import bpy，可 `dryrun_props.py` 离线干跑；`build_all()`/`report()` 才在 Blender 内执行。",
      "`PALETTE` 限 12 个材质；`NEW_MATERIALS`（SN_Brick/SN_Plaster/SN_Glass_Dark）已存在则复用；`_make_object()` 按材质槽顺序写入面索引、`use_smooth=false`，轴心=底面中心。",
      "`report()` 输出逐件 tri/尺寸误差/zmin/材质/网格健康、集合布局与 234 对象基线回归 digest（`BASELINE_DIGEST=4fe3f250…`）；Builder 只读自检、不保存/不导出。",
      "质检记录：Builder 6204 tri；Verifier R1 修复 Rowboat 压条悬空、Tavern 挂灯脱开、Office 塔身暗板过厚后复验 passed=true；场景 244 objects / 223 mesh。"
    ]
  },

  "tools/modeling/generators/export_town_glb.py": {
    role: "把 Blender 工作台 `SN_Harbor_Town` 集合的 10 件 `SN_HT_*` 逐件导出为单对象 GLB，写入 `dev_mods/core/assets/models/props/`（内容资产随 core 模组发布）。",
    contracts: [
      "在 Blender 内经 `execute_blender_code` 执行；调用 `export_harbor_town()`；Builder 从不保存/导出，因此工作台保持干净，由 Lead 验收后运行。",
      "逐件临时把 `object.location` 归零（几何已是局部坐标、轴心在底面中心）→ `export_scene.gltf`（GLB、Y-up、只导出选中、应用变换、不含相机/灯光/附加数据）→ `finally` 还原位置与选择。",
      "输出 `dev_mods/core/assets/models/props/SN_HT_<Name>.glb`；返回 `{ok, collection, out_dir, items[], total_tris}`，逐件含 tri 与字节数；缺文件时 `ok=false`。"
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
  },

  "tools/art/gen_iron_harbor_trim_sheet.py": {
    role: "铁港建筑套件**共享 trim sheet 的确定性画图器**：按 `docs/design/textures/iron_harbor/iron_harbor_trim_sheet_2048.spec.json` 画出 4×4×512 px 图集（评审件）与 16 张 512² 独立平铺贴图（运行时采样件），并写 stats。",
    contracts: [
      "唯一输入是 spec JSON（含 16 个 cell 的 id/col/row/kind/palette/mean_rgb/detail），不读代码；`--out-root` 默认仓库根，`--spec/--stats` 可覆盖；两跑必须字节一致（cell 级种子由 cell id 派生，不依赖遍历顺序）。",
      "每 cell 内容自身 U/V 无缝（512 内容按 mod 坐标生成，无 gutter），砖层 512/26 px、石层 120 px、屋面肋 36 px、木板 53 px 等尺度常量由 `px_per_m=256` 与 `tile_m=2.0` 推得。",
      "自检：每 cell 实测 mean 与目标差 ≤±14（实测 ≤±0.5）、接缝率（自身边界差/内部差）<2.5（实测 0.26–1.18）、cell 完整/索引不撞、PNG 尺寸、确定性；任一失败非 0 退出。",
      "产出：`iron_harbor_trim_sheet_2048.png`（2048²，行 0 在顶部）+ `tiles/<cell>.png`（PNG-8 ≤96 色，单张 145–187 KB）+ `.stats.json`（每 cell mean/seam/bytes 与图集 sha256）。",
      "只画图不建材质：材质↔cell 的映射在 `sn_iron_harbor_materials.MATERIAL_SURFACES`，改 cell 语义要两边一起改。重跑：`python tools/art/gen_iron_harbor_trim_sheet.py`。"
    ]
  },

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
    intro: "纯领域逻辑：航行、市场、委托、船只/模块实例/仓库/打造订单、地图、世界生成（坐标空间+程序化陆地+贝塞尔航线）、事件、债务与通关判定。",
    contracts: [
      "领域函数尽量输入确定、输出确定；随机必须来自 RngService 命名流。",
      "不读写文件、不创建 UI、不直接访问场景树。",
      "仓库/运输/打造只操作 GameState 纯数据；通关判定读取注册表合同与船只派生属性。",
      "世界生成器使用坐标空间模型（替代 MVP 时期的抽象图），港口锚定在程序生成的陆地海岸线上。"
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
    intro: "展示层。固定 Shell、四个菜单场景、七个功能页、五个流程页与海图组件均已场景化；Shell 仅保留上下文解析、ViewModel 组合、导航、命令和转场。共享 Godot Theme、可复用控件与 UI Kit 展示场景保持统一视觉。船厂中央改装台（SNShipView）与部件 HUD（SNSlotTarget/SNPartRow）是独立可复用组件，2.5D 渲染器经 set_renderer 接入。2.5D 固定舞台位于 `framework/ui/stages/`：`SNStageHost` 持有 SubViewport 与生命周期，`LocationStage` 是舞台契约，`ShipyardStage` 承载船厂 3D 船体，`PortStage` 是港口舞台骨架，`StageKit` 提供环境/水面/AABB 取景构建器；总览页已把 `PortStage` 作为全窗背景层接入，并生成 2D 设施热点（点击与顶部导航同一路径）。",
    contracts: [
      "UI 只识别 Query/Command 与定义类型，不识别 core 内容。",
      "公共视觉状态优先进入 Theme variation；业务页面只负责布局与数据绑定。",
      "页面场景不得直接持有 AppContext；查询、命令、跨页导航、全局提示与音效属于 Shell。",
      "2.5D 舞台只做表现层：资产路径由 ViewModel 解析后传入，舞台不读 GameState/QueryBus/CommandBus；同一时间只渲染一个 3D 舞台，隐藏即停更。"
    ]
  },
  "framework/tests": {
    intro: "无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、委托刷新、仓库存取、打造订单/替换/在港等待、船厂改装 UI、UI 外壳接线、2.5D 舞台基础设施、总览页 3D 港口舞台接入、完整通关流程与坐标空间世界生成器。",
    contracts: [
      "测试入口：`godot --headless --path . --script res://framework/tests/test_runner.gd`。",
      "`test_case.gd` 提供断言与 Core 启动辅助；每个用例独立 bootstrap。",
      "测试源码可以引用 `core:*` ID；`test_no_core_ids.gd` 只扫描非测试框架代码。",
      "`test_full_clear.gd` 通过公开命令/查询脚本化跑完五段主线并组装大型船，覆盖 9 个 seed。",
      "`test_content_types_manifest.gd` 守护 `content_types.json` 与 `ContentTypes` / Schema 文件的一致性。",
      "`test_save_migration.gd` 守护 save schema 1.x → 2.0 迁移、campaign 元数据与分区回填。",
      "`test_campaign_state.gd` 守护 CampaignState 分区补齐、探索进度幂等与存档往返。",
      "`test_ship_modules.gd` 守护模块实例补齐/condition 失效/安装重置/货舱对齐/damage_module 操作码/维修报价与存档往返。",
      "`test_stage_host.gd` 守护 LocationStage 契约、SNStageHost 生命周期/回退/停更、ShipyardStage 场景、SNShipStage3D 适配器与 PortStage 装配/替换/缩放/portal。",
      "`test_schema_v2_drafts.gd` 用当前 SchemaValidator 验证 `schemas/v2` 草案，并确认草案类型仍为 planned、不在 active 注册表。",
      "`test_schema_v2_weapons.gd` 守护 `weapons` 草案（合法 direct / broadside 与非法必填 / 枚举 / 范围 / 颜色 / 材料 ID）、草案登记与 hull `weapon_sockets` / `rig_sockets` 镜像（含 Core 14 个武器 socket + 22 个帆索 socket）。",
      "`test_world_generator.gd` 守护坐标空间世界生成：同 seed 可复现、港口锚定海岸线、最小间距、连通性、出航角度、必需设施位置与序列化往返。"
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
      "当前 2.0 草案：`common`、`start_profile`、`world_profile`、`region`、`site`、`route_template`、`weather_profile`、`faction`、`discovery`、`weapon`；对应类型仍为 planned。",
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
      "`gen_static_docs.mjs` 优先读取源码 `@static-doc` 与 `docs/static_headers/` sidecar，旧 `static_docs_data.mjs` 仅作兼容；默认原子生成，`--check` 只读检查过期。",
      "`ui_snapshot.gd` 必须窗口模式运行（`--headless` 时视口纹理为空），bootstrap 顺序与 `framework/tests/test_case.gd` 一致；只写 `docs/design/screenshots/`，失败退出码 1。",
      "`capture_ui.ps1` 是 `ui_snapshot.gd` 的包装入口：默认 1440×900、seed 5201、输出 `res://docs/design/screenshots`，并检查产物比本次运行更新（防旧图冒充验收）；`-OverviewStage` 额外要求 `overview_port_stage.png` 新鲜，`-OverviewDetail` 再要求 `overview_detail.png`。",
      "`godot/capture_port_stage.gd` 是 PortStage 预览截图入口：窗口模式 1440×900，依次抓 `port_stage_preview.png` / `port_stage_sparse.png` / `port_stage_market.png` / `port_stage_supply.png` / `port_stage_harbor_page.png` 五张到 `docs/design/screenshots/port_stage/`；`--headless` 直接失败，失败退出码 1。",
      "`art/gen_shipyard_textures.py` 是船厂两张贴图的唯一真源：`python tools/art/gen_shipyard_textures.py` 可重建；纵剖图构图比例需与 `sn_ship_view.gd` 的 `_chip_anchor` 同步。",
      "`modeling/briefs/*.json` 是建模子代理的自包含工单；尺寸/预算/材质只改这里，不靠口述传递。",
      "港口街景第一批工单在 `modeling/briefs/sn_harbor_town_batch1.json`：10 件 `SN_HT_*`、集合 `SN_Harbor_Town`、工作台 y=110、总预算 11500 tri；`sn_harbor_town_generator.py` 是几何唯一真源（纯 Python 可干跑、`build_all()/report()` 在 Blender 内执行），`export_town_glb.py` 验收后逐件归零导出到 `dev_mods/core/assets/models/props/`。Verifier R1 复验 passed=true，场景 244 objects / 223 mesh、既有对象 digest 不变。",
      "`modeling/briefs/sn_iron_harbor_architecture_kit_v1.json` 是铁港近中景建筑升级契约：现有 5 个 `SN_HT_*` 资产原名原位升级，并新增 3 类建筑；要求真实窗门深度、共享 2K trim sheet、LOD1 <= LOD0 的 35%，典型 PortStage 同屏建筑 <=60000 tri。",
      "港口设施锚点工单见 `modeling/briefs/sn_port_facilities_batch1.json` 与 `PORT_FACILITIES_PLAN.md`：6 件设施锚点，总预算 10500 tri，轴心统一在底面中心；工作台暂存排原定 y=60，因与 `SN_Ship_Modules`（y 58.6–69.2）冲突改为 y=75（见工单 layout_revision）。",
      "`modeling/generators/sn_port_facilities_generator.py` 是港口设施 6 件的几何唯一真源；`export_port_glb.py` 逐件归零导出 + 写 `.design/port/SN_<Name>.blend` 快照，`verify_port_glb.py` 纯 Python 复核单节点 / 调色板 / 尺寸 / 轴心 / doubleSided，`render_port_preview.py` 出逐件 3/4 预览。",
      "`modeling/generators/*.py` 是几何唯一真源：改了参数重跑即可重建，禁止手工摆点；`.blend` 只是产物。",
      "`modeling/generators/dryrun_props.py` 必须在进 Blender 前跑通（tri 预算 / 包围盒 / 边界边 / 退化面）。",
      "`modeling/dispatch.workflow.js` 必须串行派发：Blender 单实例，禁止 `parallel`/`pipeline` 并发建模。",
      "`godot/verify_props.gd` 是道具 GLB 导入的回归闸门，`godot/verify_port_facilities.gd` 是港口设施 6 件锚点的导入闸门；改动资产后先 `godot --headless --import` 再重跑对应脚本。"
    ]
  },
  "SNBattleSim": {
    intro: "独立 2D 舰队战斗规则试验台：验证固定船体、多武器、视野/战争迷雾、直射/炮击/侧弦齐射、货船护航与用户自定义武器。",
    contracts: [
      "不接入 Godot 主流程或战役存档；装配配置与战斗运行时严格分离。",
      "船体固定为 small / medium / large 三种；武器与视野组件数据驱动，新增武器不得修改模拟核心。",
      "相同 seed、装配和 tick 序列产生相同结果；浏览器界面只通过 BattleSimulation 公共接口驱动战斗。战斗世界无边界，镜头按全部在场船只包围盒独立取景。",
      "greybox.html 保留为压力与冲撞专项旧灰盒；新版入口为 index.html，使用零依赖本地服务器加载 ES 模块。"
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
      "`weapons` 草案（战斗 / 装配 / 经济三组）与船体 `weapon_sockets` / `rig_sockets` 镜像走同一套 v2 / 1.0 Schema；安装点重复 name / 索引与非法 class/kind 由编辑器语义校验拦截。",
      "「舰载武器包」模板（`TEMPLATES.weapons` / `new --template weapons`）一次生成 5 件模拟器武器草案定义与 `asset://core/model.weapon.*` 模型引用，capability 自动声明；草案与模板只写编辑器项目，不写 Core（Core 出现 2.0/未注册类型会被运行时按 mod error 拒绝）。",
      "所有导入内容都经过 HTML 转义、路径检查与 ZIP 体积/条目/CRC 限制。",
      "浏览器存储始终可用；`tools/serve.mjs` 运行时额外镜像到 `mods/`，导出可写入 `exports/`。",
      "`tools/content.mjs` 是无头 CLI，与网页端共用 `js/store.js` / `js/validate.js`；写回用 `tools/content_json.mjs` 保源编辑，写前按 SHA-256 检测并发修改。"
    ]
  },
  "dev_scenes": {
    intro: "独立 3D 样片与舞台预览场景（不接入主流程）：港口水面/浮船样片与 PortStage 港口舞台预览，用于验证水面着色器、GLB 资产拼接与固定机位构图。",
    contracts: [
      "`dev_scenes/` 不是游戏启动链的一部分；主场景仍为 `framework/ui/shell/main.tscn`。",
      "样片可以复用 `assets/` 与 `assets/models/`，但不得反向依赖 `framework/` 运行时。",
      "水面材质/着色器属于表现层资产，`PortStage` 与 `dev_scenes/port_stage` 共用同一套水面材质。",
      "`port_stage/` 通过真实 `SNStageHost` 挂载 `port_stage.tscn`，用两份样例 ViewModel 覆盖完整/稀疏港口；截图由 `tools/godot/capture_port_stage.gd` 生成。"
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
  "framework/tests/test_runner.gd": "无头测试发现、执行、汇总与退出码；首个渲染帧上运行，使 UI 套件能把外壳场景真正挂进场景树（含 test_shipyard_refit 改装 UI、test_stage_host 2.5D 舞台套件与 test_schema_v2_weapons 武器草案 / 船体 socket 镜像）。",
  "framework/tests/cases/test_world_generator.gd": "坐标空间世界生成器测试：同 seed 可复现、不同 seed 不同世界、10-20 港口、锚定海岸线、最小间距、陆地多边形、覆盖率、连通性、出航角度、起点港口、必需设施位置与序列化往返（12 个测试用例）。",
  "framework/tests/cases": "按主题拆分的 168 个测试（含委托刷新、仓库/打造订单/在港等待、船厂改装 UI、模块实例与部件损耗可见性、UI 外壳接线、密集界面横向排版、通报文案本地化、2.5D 舞台基础设施（LocationStage/SNStageHost/ShipyardStage/PortStage）与场景填充访问器、港口街景 town kit 装配/blockout/port.view 接线与 size/density 分档、静态层与玩家船合批、无 banner 程序化远景、主界面紧凑 HUD + 资源图标 + 主题化招牌 + 状态条 + 详细抽屉、存档迁移、CampaignState 分区、Schema 2.0 草案与通关与多 seed 完整通关）。",
  "framework/ui/stages/shipyard_stage.tscn": "船厂舞台场景：挂 `ShipyardStage` 脚本并显式设置 `stage_id=\"shipyard\"`。",
  "framework/ui/stages/port_stage.tscn": "港口舞台场景：挂 `PortStage` 脚本并显式设置 `stage_id=\"port\"`。",
  "dev_scenes/port_stage/port_stage_preview.tscn": "PortStage 独立预览场景：全屏 Control 挂 `port_stage_preview.gd`。",
  "framework/tests/smoke_load.gd": "手动冒烟：加载 Core 并打印启动报告。",
  "framework/tests/smoke_play.gd": "手动冒烟：开局、预览、出航、事件选择。",
  "sdk/templates": "模组模板：Manifest、商品、双语本地化与说明。",
  "sdk/examples": "第三方锅炉示例，验证公共内容接口。",
  "schemas/v2": "Content Schema 2.0 草案：common 与 start_profile / world_profile / region / site / route_template / weather_profile / faction / discovery / weapon；仍为 planned，暂不接入运行时加载。",
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
  "tools/modeling/generators/sn_port_facilities_generator.py": "港口设施锚点第一批 6 件生成器（市场棚 / 告示板 / 水箱 / 信号塔 / 龙门吊 / 干船坞）：纯几何函数可离线干跑，单件一个 mesh、原点在底面中心，集合 SN_Port_Facilities，合计 4996 tri；本批新增 SN_Iron。",
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
  "tools/modeling/briefs/sn_iron_harbor_architecture_kit_v1.json": "铁港城镇视觉升级工单：中等精度模块化建筑、共享 trim sheet、LOD0/LOD1、8 类建筑原型与固定 PortStage 机位验收标准。",
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
  "SNModMaker/.dockerignore": "Docker 构建上下文过滤：排除本地 mods/、exports/ 与 Docker 自身文件。",
  "SNModMaker/js/schema-bundle.js": "自动生成：嵌入 `/schemas/*.schema.json`。",
  "SNModMaker/js/core-index.js": "自动生成：Core 定义、内容与双语本地化索引。"

};
