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
      "`framework/mods/scan_roots` 默认依次为 `res://dev_mods`、`user://mods_dev`、`user://mods`。",
      "`config/features` 声明 4.4 兼容；实际验证引擎为 4.7.2。"
    ]
  },

  "framework/bootstrap/bootstrap.gd": {
    role: "组合根启动编排：创建 AppContext、调用 ModLoader、注册公共 API 并把结果汇总为 StartupReport。",
    dependencies: ["AppContext", "ModLoader", "FrameworkApi", "StartupReport", "ProjectSettings"],
    contracts: [
      "加载失败不抛异常：所有可预期错误进入 StartupReport，UI 据此进入诊断界面。",
      "即使 fatal，也会注册命令/查询并冻结空注册表，保证后续调用返回结构化错误。",
      "默认扫描 `res://dev_mods`、`res://dist/mods`、`user://mods_dev`、`user://mods`；发布版追加可执行文件旁 `mods/`。",
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
      "内容/资源/本地化分别使用白名单扩展名。"
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
    role: "读取模组内容 JSON，执行 Schema 校验、定义注册、本地化/资源登记与显式 Patch。",
    contracts: [
      "定义 ID 的命名空间必须等于来源模组；ID 类型段必须与 content_type 单数一致。",
      "文件级 Schema 错误拒绝整份文件；单条定义错误只拒绝该定义。",
      "Patch 冲突以 `target + JSON Pointer` 为键，跨模组同路径直接报错，不静默覆盖。",
      "Patch 后重新按目标类型 Schema 校验，失败则整条 Patch 回滚。",
      "所有定义注册后才执行 Patch；注册表此时仍未冻结。"
    ],
    l2: {
      "_apply_patch(entry)": [
        "先校验 target 存在、requires 版本匹配，并在工作副本上逐条执行操作。",
        "`/id` 及 `/id/*` 被禁止；操作失败、ID 改变或 Schema 失败都放弃整条 Patch。",
        "成功时只更新内容字段（name/desc/tags/raw/data），保留来源模组并追加 patched_by。"
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
    role: "内容类型常量、Schema 路径、单数类型名与模块类型集合。",
    contracts: [
      "`content_type` 决定注册表与 Schema，两者映射必须同步维护。",
      "`all()` 不包含 patches；patches 由 ContentCompiler 单独收集。",
      "单数类型用于 `<mod>:<type>/<id>` 的 ID 校验。"
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
    role: "单条内容定义的通用 envelope 与只读数据视图。",
    contracts: [
      "包含 ID、类型、本地化键、标签、enabled、data、来源模组/文件与 patch 记录。",
      "`data` 与 `raw` 共享运行期引用；注册表冻结后按约定禁止修改。",
      "`to_raw()` 返回深拷贝，供 Patch 与二次 Schema 校验使用。"
    ]
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
    role: "船厂流程：购买并安装船体/锅炉/货舱/导航/安全/客舱。",
    contracts: [
      "必须在有 shipyard 设施的港口且处于港口状态。",
      "槽位/重量/货币/声誉失败原因由 `ShipOps.install_blockers()` 统一生成，避免 UI 与命令漂移。",
      "替换船体时重新校验货舱/客舱槽位并把耐久设为新船体上限。",
      "所有修改在命令事务内完成，失败自动回滚。"
    ]
  },

  "framework/application/queries/port_view.gd": {
    role: "主界面 ViewModel：当前港、市场、目的地、船只、委托、策略、情报、通知与统计。",
    contracts: [
      "所有数值只读复制；市场行同时给出库存、单价、持有、可售、buyable 与持仓均价。",
      "目的地只列当前港的相邻航线，标记未知设施与风险。",
      "委托 ViewModel 额外提供目的港名称键与期限显示文本。",
      "船只 ViewModel 的 cargo_cost_basis 与 average_cost 来自 ShipOps 的成本口径。",
      "不返回 ContentDefinition 或 GameState 内部引用。"
    ]
  },

  "framework/application/queries/intel_view.gd": {
    role: "情报独立界面 ViewModel：快照时间/年龄、已发现港口市场表和 NPC 预计动向。",
    contracts: [
      "只返回已发现港口；未发现港口不会出现在快照中。",
      "每个市场行附带 item_name_key；每个 NPC 行附带货物名和动作本地化键。",
      "`can_refresh` 由当前港情报站、港口状态和金币共同决定。"
    ]
  },

  "framework/application/queries/shipyard_view.gd": {
    role: "船厂独立界面 ViewModel：当前模块、槽位占用和所有可购买模块的限制原因。",
    contracts: [
      "与 `ship.install_module` 共用 `ShipOps.install_blockers()`，UI 不复制规则。",
      "`candidates[].blockers` 给出全部失败码；`can_install` 为 false 时 UI 禁用按钮。",
      "已安装模块标记 installed，并附加 already_installed 限制。"
    ]
  },

  "framework/application/queries/supply_view.gd": {
    role: "补给界面 ViewModel：市场煤水价/库存、载重余量与维修报价。",
    contracts: [
      "煤水单价与港口库存来自 `MarketOps.supply_entry_for()`，不再使用固定价格。",
      "可买上限同时受剩余载重、金币和港口库存限制。",
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
      "抵达时统一推进时间、发现港口、结算主线/普通委托、推进 NPC、检查逾期并自动存档。",
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
    role: "船只组合的纯函数：模块/货物/煤水/旅客重量、容量、槽位、持续时间与派生属性。",
    contracts: [
      "总重量包含已装模块、货物、煤、水、旅客；合同货箱同样计入。",
      "货舱容量是重量容量；合同货物不可出售/抛弃。",
      "每个 cargo stack 保存 total_cost；买入累加，卖出/抛弃按数量比例扣减。",
      "`cargo_total_cost()` 与 `cargo_average_cost()` 是 UI 显示库存成本的唯一口径。",
      "派生属性计算船体基础、锅炉、导航、安全、模块 modifiers 与岗位 modifiers。",
      "`validate_configuration()` 检查必需船体/锅炉、货舱/客舱槽位与耐久上限。",
      "`install_blockers()` 是 ship.install_module 命令与船厂 ViewModel 共用的校验源：声誉、货币、槽位、重量替换差量。"
    ],
    l2: {
      "stats(hub, ship)": [
        "先取 hull.base_speed * boiler.speed_mul，再乘导航 speed_mul。",
        "风险汇总 hull.base_risk + nav.risk_add + safety.risk_add + 模块/岗位 risk modifiers。",
        "员工/安全设备的 damage/repair 修正以乘算累积；最终 clamp 到合理范围。"
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
      "买入把成交总额写入 cargo stack 的 total_cost，卖出按数量比例扣减成本。",
      "补给只检查设施、库存、重量与货币；维修费用乘安全设备/工程师的 repair_cost 修正。",
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
      "趋势由库存相对 base_stock 判断：up/down/stable。"
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
    role: "委托实例生成、装载、交付结算与接取规则。",
    contracts: [
      "实例 ID 由模板 ID + 单调 serial 构成；奖励数额在生成时锁定。",
      "货物载荷必须声明 cargo_item_id；载重与旅客数来自 payload 范围。",
      "装载前检查客舱容量、总重量与货舱容量；合同货物以 contract_id 绑定到实例。",
      "交付时按准时、伤病赔偿、奖金、声誉与解锁结算；收入优先偿还债务。",
      "主线 offer 与普通 offer 分开存储；主线同时只能有一个 active。"
    ],
    l2: {
      "create_instance(...)": [
        "遍历 payload 汇总 cargo_weight/passengers；期限使用 FormulaRegistry 的安全公式 ID。",
        "奖励使用同一命名随机流抽取范围；所有数据写入纯 Dictionary，便于存档。"
      ],
      "complete(state, hub, instance, arrival_time)": [
        "准时判定 arrival_time <= deadline；伤病每人扣 50 赔偿并降低声誉。",
        "`DebtService.receive_income()` 先还债再把余额入账；解锁 ID 写入 player.unlocks。",
        "交付后移除对应 contract_id 的货物；实例标记 completed。"
      ]
    }
  },

  "framework/domain/contracts/run_factory.gd": {
    role: "新局工厂：选构筑/地图配置、生成船只与市场、NPC、初始主线与普通委托。",
    contracts: [
      "框架不引用具体 core ID：默认构筑/地图配置取该类型第一个注册定义。",
      "创建顺序：船 → 地图 → 玩家/状态 → 市场 → NPC → 主线 1 → 普通 offer。",
      "主线 1 自动装载并接取；后续主线由 VoyageService 生成 offer。",
      "生成失败返回结构化 Result，不写入 AppContext。"
    ],
    l2: {
      "create_run(context, build_id, requested_seed)": [
        "本地 RngService 由 seed 派生，成功后才由 run.start 写回 context，失败不污染现有随机流。",
        "地图生成依赖初始船只属性（起始补给可达性检查）。",
        "初始债务按 build.loan 写入 player.debt，之后由收入自动偿还。"
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
    role: "白名单效果操作码及其纯实现（货币、补给、货物、船只、委托、情报、通知）。",
    contracts: [
      "每个 handler 接收 `(node, execution_context)`，返回 `{ok,error_code,message_key}`。",
      "失败表示整个命令事务回滚；效果按数组顺序执行。",
      "`damage_ship` 应用安全设备 damage_mul；耐久归零设置 voyage_failed。",
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
    role: "JSON 存档槽：模组头、状态、临时文件校验后替换、兼容性检查。",
    contracts: [
      "存档头记录 save_schema/framework_version/mod_api_version/seed/mods/meta。",
      "写入 `.tmp` 并重新解析校验；旧文件先改名为 `.bak`，最终替换失败会回滚。",
      "槽位名限制 `^[a-z][a-z0-9_]{1,31}$`；自动存档与出航前快照为独立槽。",
      "缺失存档所需模组拒绝加载；版本/哈希漂移只警告。"
    ],
    l2: {
      "load_slot(slot)": [
        "拒绝非 1.x save_schema、非对象根与缺失 state 的文件。",
        "返回 GameState、header 与 meta；调用方负责模组兼容性校验。"
      ]
    }
  },

  "framework/services/settings_service.gd": {
    role: "持久化 UI 设置：默认读取 `res://config/config.json`，运行时写入 `user://config/config.json`。",
    contracts: [
      "只接受 zh_CN / en 两种语言；非法值回退 zh_CN。",
      "自动存档为布尔值；首次启动会把默认配置写入 user://。",
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
    role: "把 `asset://<mod>/<key>` 解析为已挂载物理路径，缺失时回退占位图。",
    contracts: [
      "资源缺失只警告并回退，不导致崩溃或存档损坏。",
      "支持直接传入 `res://` 框架资源路径。",
      "注册发生在编译阶段，解析发生在 mount 之后。"
    ]
  },

  "framework/state/game_state.gd": {
    role: "纯数据运行态：可深克隆、可序列化、可哈希、事务替换。",
    contracts: [
      "只保存 ID/运行时数值，不保存 ContentDefinition 或 Node。",
      "`clone()` 深拷贝，CommandBus 的事务基础。",
      "`hash()` 对规范化 JSON 做 SHA-256；存档往返需一致。",
      "`replace_with()` 原地替换，保持外部引用。"
    ],
    l2: {
      "hash()": [
        "使用 JsonUtils 的排序键 + 浮点量化表示，避免字典顺序/数字类型差异。",
        "HashingContext SHA-256 输出十六进制；测试用保存/加载对比验证。"
      ]
    }
  },

  "framework/ui/shell/main.gd": {
    role: "可玩 UI 外壳：启动主菜单、总览/市场/委托/船厂/补给/情报/出航七个界面，以及海图、事件选择与诊断。",
    contracts: [
      "所有数据经 QueryBus 获取，所有修改经 CommandBus；UI 不保存规则状态。",
      "每个功能有独立界面，通过顶部导航切换；面板分别构建完整 ViewModel，不把所有信息挤在同一滚动页。",
      "每轮命令后整页重建；选项/目的地/构筑选择保存在 UI 成员。",
      "每个 PanelContainer 只允许一个 VBoxContainer 内容容器；面板子节点必须经 `_panel_add()` 添加，避免多子节点互相重叠。",
      "海图点击已访问港口：当前港跳转市场，远程港打开只读港口记忆。",
      "市场页显示 buyable 与持仓均价；仅收购品种的买入按钮禁用。",
      "补给页显示市场煤水价、港口库存、载重余量、可买上限和维修报价，按钮直接派发 supply.* 命令。",
      "事件面板只展示本次抽样出的 2 个选项。",
      "无存档时进入主菜单：开始游戏进入新航程配置，加载游戏读取 autosave，模组页只读展示本次加载结果，设置可切换语言与自动存档，退出直接关闭。",
      "设置写入 `user://config/config.json`，默认值来自 `config/config.json`；首次加载会创建用户配置。",
      "右下角固定显示开发团队与游戏版本；版本来自 `application/config/version`。",
      "加载游戏读取 autosave 并做模组兼容性校验。"
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

  "tools/gen_static_docs.mjs": {
    role: "静态文档生成器：读取本文件的 FILE_DOCS/MODULES，生成镜像文档、模块 README、总计索引与带 SHA-256 的 manifest。",
    contracts: [
      "GDScript 符号按 `class_name/signal/const/func` 提取；`.js/.mjs` 额外提取顶层 function、常量与 `root.SN*` 导出。",
      "生成前清空 `docs/static`；`SKIP_SOURCES` 中的生成物不进入文档与 manifest。",
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

  "SNModMaker/index.html": {
    role: "模组制作器的静态外壳：顶栏、导航/工作区/检视器布局，以及模态框、Toast、拖放与忙碌层宿主。",
    contracts: [
      "脚本按 `schema-bundle → core-index → catalog → zip → validate → store → io → ui → app` 顺序加载，全部为经典 script，支持 file://。",
      "不引用外部字体、CDN、图片或模块；图标为内联 SVG / CSS。",
      "`#datalists` 必须保持可被表单引用，不能使用 `display:none` 以外的移除方式。"
    ]
  },

  "SNModMaker/css/app.css": {
    role: "暗色工业主题与响应式布局：顶栏、侧栏、内容编辑器、表单控件、条件/效果编辑器、模态框与 Toast。",
    contracts: [
      "颜色、间距、字体通过 `:root` 变量统一；不引入外部字体。",
      "`[hidden] { display: none !important; }` 支撑视图与过滤逻辑。",
      "断点 1240 / 1000 / 800 / 760 / 560：编辑区单列、侧栏图标化、顶栏换行与操作压缩。"
    ]
  },

  "SNModMaker/js/catalog.js": {
    role: "内容类型展示元数据、字段标签、默认值、标签建议、条件/效果词汇与新建模板。",
    dependencies: ["JSON Schema（结构约束）", "ContentTypes（类型/singular 映射）"],
    contracts: [
      "`TYPES` 的顺序决定侧栏分组与表单类型；每项的 `schema` 必须对应仓库 `schemas/` 文件。",
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
        "新 ID 与键基使用当前模组命名空间，并在名称后追加“副本”。"
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

  "SNModMaker/js/io.js": {
    role: "浏览器 I/O：IndexedDB 项目库、文件/文件夹/ZIP 导入、下载、File System Access 目录导出。",
    contracts: [
      "IndexedDB 数据库 `snmodmaker`、对象仓库 `projects`（keyPath=uid）；打开超过 3 秒视为不可用，由 app 回退 localStorage。",
      "文件夹/拖放导入递归读取 `webkitGetAsEntry`；ZIP 交给 `SNZip.read()`。",
      "目录导出需要 Chromium 的 `showDirectoryPicker`，在所选父目录下创建 `<mod_id>/`。",
      "检测到 `tools/serve.mjs` 时使用同源 `/api` 读写 `mods/` 与 `exports/`；`detectBackend` 1.5s 超时后静默退化。",
      "下载使用 Blob URL；不向外部网络上传任何内容。"
    ]
  },

  "SNModMaker/js/ui.js": {
    role: "Schema 驱动的表单渲染与通用 UI 组件：字段控件、数组/条件/效果编辑器、模态框、Toast、Datalist。",
    dependencies: ["validate.flattenObject/deref", "store", "catalog"],
    contracts: [
      "渲染层只输出 HTML；所有编辑通过 `data-field` / `data-action` 交给 app.js，不直接修改项目。",
      "表单字段类型、枚举、范围与必填来自 Schema；专用控件只针对 modifier/material/payload/condition/effect/option 等结构。",
      "所有用户文本与属性值经过 `esc/attr` 转义；引用候选来自当前项目 + Core 索引。",
      "表单生成的路径是相对定义的属性路径（manifest 除外），与 app.setByPath 的约定一致。"
    ],
    l2: {
      "renderField(field, schema, value, path, ctx, options, schemaFile)": [
        "先解引用；按 `id_ref/range2/modifier/craft_material/payload/option_data/effect/condition_node` 分派专用控件，再按 type/enum 分派通用控件。",
        "递归传入当前 schema 文件，保证 common.schema.json 内的本地 `$ref` 能正确解析。"
      ],
      "renderDefinitionForm(ctx)": [
        "普通定义渲染身份区（ID/名称键/描述键/标签/启用）与数据区；补丁定义渲染目标、来源约束与操作列表。",
        "ID 输入只显示 local 部分，前缀由 app 在写回时补齐。"
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
      "检测到本地服务时，同一项目再经 1.6s 防抖镜像到 `mods/<id>/`；磁盘失败只降低提示，不阻断浏览器保存。",
      "Ctrl+S/Z/Shift+Z/N/O/E 为全局快捷键；文本输入中不拦截撤销。"
    ],
    l2: {
      "applyField(element, fromChange)": [
        "区分 manifest 与当前定义；数字/整数/布尔/JSON 各有解析，解析失败不写回。",
        "ID 输入按前缀重建完整 ID，并同步重命名以旧 `name_key` 为基的 `_key` 与翻译。",
        "空描述键与空 checksum 会删除字段，避免违反可选字段的 pattern/minLength。"
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
    role: "零依赖本地静态服务器 + 磁盘 API：项目写入 `mods/<id>/`，ZIP 写入 `exports/`。",
    contracts: [
      "仅监听 127.0.0.1；默认端口 8099。支持 `SNMODMAKER_MODS_DIR` / `SNMODMAKER_EXPORTS_DIR` 覆盖数据目录。",
      "API：status、projects 的 GET/PUT/DELETE、exports 的 GET/POST/DELETE；请求体上限 128 MB。",
      "项目先写临时目录再替换，文件路径拒绝绝对路径、`..`、盘符与超过 16 层。",
      "静态文件带 `Cache-Control: no-store`，路径解析后必须位于 SNModMaker 目录内。"
    ]
  },

  "SNModMaker/tests/run-tests.js": {
    role: "Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP 与导入导出往返。",
    contracts: [
      "不依赖浏览器或 Godot；直接 require 经典脚本并以 `globalThis.SN*` 访问模块。",
      "覆盖 28 个用例；任何失败以退出码 1 结束。"
    ]
  },

  "SNModMaker/tests/browser-smoke.mjs": {
    role: "Chrome DevTools Protocol 冒烟测试：新建项目、编辑、本地化、检视、自动保存、ZIP、导入与撤销。",
    contracts: [
      "需要 Chrome 以 `--remote-debugging-port=9222` 启动，并已有静态服务。",
      "测试开始前清空该 origin 的存储；直接调用页面内 `SN*` 模块做导出/导入断言。",
      "收集 `Runtime.exceptionThrown` 与 console error，任何一条都会导致非零退出。"
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
    intro: "应用层：命令/查询总线、公共 API 注册、领域事件与用例。",
    contracts: [
      "UI 与测试使用同一命令/查询入口。",
      "命令事务克隆提交；查询只读 ViewModel。"
    ]
  },
  "framework/domain": {
    intro: "纯领域逻辑：航行、市场、委托、船只、地图、事件与债务。",
    contracts: [
      "领域函数尽量输入确定、输出确定；随机必须来自 RngService 命名流。",
      "不读写文件、不创建 UI、不直接访问场景树。"
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
    intro: "运行态数据模型。GameState 是唯一持久化状态，定义对象永不进入存档。",
    contracts: ["GameState 可深克隆、可哈希，JSON 往返哈希一致。"]
  },
  "framework/ui": {
    intro: "展示层。当前只有一个最小可玩外壳，后续可拆分为海图/面板/出航等场景。",
    contracts: ["UI 只识别 Query/Command 与定义类型，不识别 core 内容。"]
  },
  "framework/tests": {
    intro: "无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、存档、ZIP 与框架约束。",
    contracts: [
      "测试入口：`godot --headless --path . --script res://framework/tests/test_runner.gd`。",
      "`test_case.gd` 提供断言与 Core 启动辅助；每个用例独立 bootstrap。",
      "测试源码可以引用 `core:*` ID；`test_no_core_ids.gd` 只扫描非测试框架代码。"
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
    intro: "Manifest 与内容文件的 JSON Schema（项目校验器支持的子集）。",
    contracts: [
      "每类内容一个 envelope Schema；公共字段在 `common.schema.json`。",
      "Schema 的 `const`/`enum` 与 `ContentTypes`/操作码注册表需同步维护。"
    ]
  },
  "dev_mods/core": {
    intro: "官方 MVP 内容包：港口、商品、船只、模块、策略、岗位、委托、事件、地图与本地化。",
    contracts: [
      "`manifest.json` 声明 required=true，内容文件 15 个，本地化 zh_CN/en。",
      "框架不得引用这里的具体 ID；所有引用由 Schema/交叉校验保证。",
      "修改数值只改 JSON，不改框架。"
    ]
  },
  "tools": {
    intro: "PowerShell 辅助脚本与静态文档生成器。",
    contracts: [
      "`test.ps1` / `pack_core.ps1` 通过 `GODOT_BIN` 定位引擎。",
      "`gen_static_docs.mjs` 读取 `static_docs_data.mjs` 生成 `docs/static/`。"
    ]
  },
  "SNModMaker": {
    intro: "零依赖网页端模组制作器：原生 HTML/CSS/JS，从仓库 Schema 与 Core 索引生成表单、校验并打包模组。",
    contracts: [
      "运行时无第三方依赖、无构建步骤、无 CDN；经典 script 以支持 file://。",
      "Schema 与 Core 数据以仓库为唯一来源；`schema-bundle.js` / `core-index.js` 只由生成脚本产出。",
      "导出 JSON 与 Godot 加载链共享同一套 Schema；网页端不运行领域逻辑、注册表或 Core 完整性检查。",
      "所有导入内容都经过 HTML 转义、路径检查与 ZIP 体积/条目/CRC 限制。",
      "浏览器存储始终可用；`tools/serve.mjs` 运行时额外镜像到 `mods/`，导出可写入 `exports/`。"
    ]
  },
  "root": {
    intro: "仓库根：Godot 项目配置、README、路线图。",
    contracts: ["README 是开发入口；todo.md 维护阶段与验收状态。"]
  }
};

// Files that are intentionally documented only in their module README.
export const GROUPED_ROLES = {
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
  "framework/application/commands/command_registry.gd": "命令名到静态用例的绑定表。",
  "framework/application/queries/query_registry.gd": "查询名到 ViewModel 构造器的绑定表。",
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
  "framework/tests/test_runner.gd": "无头测试发现、执行、汇总与退出码。",
  "framework/tests/cases": "按主题拆分的 49 个测试。",
  "framework/tests/smoke_load.gd": "手动冒烟：加载 Core 并打印启动报告。",
  "framework/tests/smoke_play.gd": "手动冒烟：开局、预览、出航、事件选择。",
  "sdk/templates": "模组模板：Manifest、商品、双语本地化与说明。",
  "sdk/examples": "第三方锅炉示例，验证公共内容接口。",
  "schemas": "JSON Schema 文件（Manifest/common/15 类内容）。",
  "dev_mods/core": "官方 Core 内容文件（manifest/content/localization/assets）。",
  "tools": "PowerShell 测试/打包脚本与静态文档生成器。",
  "SNModMaker/README.md": "使用说明、数据流、开发约定与已知边界。",
  "SNModMaker/mods/README.md": "磁盘工作区说明：每个模组目录的结构与 .snmodproj.json。",
  "SNModMaker/exports/README.md": "本地导出目录说明：ZIP 命名与忽略规则。",
  "SNModMaker/js/schema-bundle.js": "自动生成：嵌入 `/schemas/*.schema.json`。",
  "SNModMaker/js/core-index.js": "自动生成：Core 定义、内容与双语本地化索引。"
};
