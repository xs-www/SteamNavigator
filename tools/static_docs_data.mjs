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
    role: "船厂用例：购买/仓库/随船运输三种来源安装模块（含替换）、卸下模块、打造模块，并在安装成功后检查通关。",
    contracts: [
      "必须在有 shipyard 设施的港口且处于港口状态；仓库命令则只要求停靠任意港口。",
      "source ∈ {purchase, warehouse, transit}：purchase 扣 purchase_price；warehouse/transit 为免费旧件重装。",
      "槽位/重量/货币/声誉/合同解锁失败原因由 `ShipOps.install_blockers()` 统一生成，避免 UI 与命令漂移。",
      "单槽模块（船体/锅炉/导航/安全/客舱）自动替换，旧件写入当前港仓库；货舱槽满时需 replace_module_id。",
      "购买船体替换后耐久为新上限；warehouse/transit 船体替换取 min(当前耐久, 新上限)。",
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
    role: "船厂独立界面 ViewModel：当前/随船运输模块、港口仓库、打造配方与所有可购买模块的限制原因。",
    contracts: [
      "与 `ship.install_module` / `ship.uninstall_module` / `ship.craft_module` 共用 ShipOps/CraftOps 的规则函数，UI 不复制规则。",
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
      "主线 1 自动装载并接取；后续主线由 VoyageService 生成 offer。",
      "普通委托初始池与抵达刷新共用 ContractOps.generate_normal_offers，初始键为 `initial:<port>`。",
      "生成失败返回结构化 Result，不写入 AppContext。"
    ],
    l2: {
      "create_run(context, build_id, requested_seed)": [
        "本地 RngService 由 seed 派生，成功后才由 run.start 写回 context，失败不污染现有随机流。",
        "地图生成依赖初始船只属性（起始补给可达性检查）。",
        "调用 WarehouseOps.ensure_structure 初始化每港仓库与 ship.transit_modules；写入 stats 默认值与 victory=null。",
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
    role: "纯数据运行态：可深克隆、可序列化、可哈希、事务替换，并提供收入/支出/利润统计与惰性结构修复。",
    contracts: [
      "只保存 ID/运行时数值，不保存 ContentDefinition 或 Node。",
      "`clone()` 深拷贝，CommandBus 的事务基础。",
      "`hash()` 对规范化 JSON 做 SHA-256；存档往返需一致。",
      "`replace_with()` 原地替换，保持外部引用。",
      "`stats()/ensure_stats()` 为旧存档与半初始化测试状态惰性补齐 voyages/on_time/accidents/income/expense/profit。",
      "`record_income()` / `record_expense()` 只累加整数并重算 profit=income-expense；贷款本金不计收入。"
    ],
    l2: {
      "hash()": [
        "使用 JsonUtils 的排序键 + 浮点量化表示，避免字典顺序/数字类型差异。",
        "HashingContext SHA-256 输出十六进制；测试用保存/加载对比验证。"
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
      "船厂页由独立 shipyard_screen.tscn 承载；Shell 查询 shipyard.view 并补充通关进度、船上材料数量、解锁来源与替换件名称，页面发出的 ship/warehouse/port 命令统一交回 Shell。",
      "委托页显示普通委托持有上限（active_count/active_limit）、每次抵达刷新提示与主线完成状态。",
      "通关页由 victory.view.achieved 触发并优先于普通页面；展示 summary，提供“再来一局”（reset_state → 新航程菜单）与“继续游玩”（仅 UI 会话 dismiss）。",
      "反馈5：顶部信息条固定显示当前港口（在航时显示“在航 → 目的港”）、剩余载重 free_weight/max_weight 与剩余货舱 free_cargo_capacity/cargo_capacity。",
      "反馈6：总览“当前目标”与船厂页顶部显示通关条件清单（主线 n/5 → 大型船体 → 锅炉 → ≥1 货舱 → 造船厂组装），主线完成后给出下一步提示；数据来自 port.view.victory.conditions 与 contracts.main_done/main_total。",
      "反馈3：情报页用 SNIntelTable 渲染 intel.view 的 columns/rows 矩阵（含未知港口列），替代旧的逐港商品表格。",
      "反馈4：船厂页新增打造订单面板与在港等待 6/12/24 小时按钮（port.wait），总览快捷入口同样提供等待按钮；打造按钮文案带工时。",
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
      "地图点击只发出 map_port_clicked；功能入口只发出 navigation_requested；等待与借款只发出 command_requested。",
      "航行记录使用 Shell 已安全填充并本地化的 notice_texts，页面不重复解释 GameState 通报参数。",
      "构筑胜利条件直接取 contracts 进度与 victory.conditions 展示，不在页面重新判断通关。",
      "目标清单等密集横向字段保持单行，避免右侧说明被压缩成逐字竖排并撑高卡片。",
      "页面可重复 bind，每次清理旧节点；海图仍由独立 map_canvas.tscn 负责绘制。"
    ]
  },

  "framework/ui/screens/port/shipyard_screen.gd": {
    role: "船厂页面场景：展示当前/运输模块、打造订单、港口仓库、配方和可购买模块，并发出船只与仓库命令。",
    dependencies: ["SNBadge", "SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 Shell 组合后的 shipyard.view、contracts、victory，以及材料/解锁/替换展示字段，不访问 AppContext、QueryBus、CommandBus 或注册表。",
      "安装、卸下、打造、模块/材料存取和在港等待均发出 command_requested(command, params)，由 Shell 统一执行、存档并反馈错误。",
      "所有 can_install/can_uninstall/can_craft 与 blockers 均来自 shipyard.view；页面只翻译原因、禁用按钮和组织布局，不复制领域规则。",
      "打造按钮明确显示工时；未完成订单显示剩余时间和所属港口，等待选项直接来自 wait_options。",
      "页面按模块类型分组购买候选，显示效果、解锁来源、替换提示、材料持有/需求和金币配方。",
      "模块行、限制原因与按钮保持横向布局，不允许智能换行把限制文案压成竖列。",
      "页面可重复 bind，每次清理旧节点；每个 PanelContainer 只有一个内容容器。"
    ]
  },

  "framework/ui/screens/flow/port_memory_screen.gd": {
    role: "港口记忆流程场景：只读展示上次到港时的市场和设施快照。",
    dependencies: ["SNSectionHeader", "steam_navigator_theme.tres"],
    contracts: [
      "bind(vm, translate) 接收 port.memory 结果及 Shell 补齐的 age_text/facility_labels，不直接查询端口记忆或注册表。",
      "市场快照不提供交易按钮；返回操作只发出 overview navigation_requested。",
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
      "阻断码只转换为展示文案，不在页面重新计算库存、重量、金钱或维修规则。"
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

  "tools/gen_static_docs.mjs": {
    role: "静态文档生成器：读取本文件的 FILE_DOCS/MODULES，生成镜像文档、模块 README、总计索引与带 SHA-256 的 manifest。",
    contracts: [
      "GDScript 符号按 `class_name/signal/const/func` 提取；`.js/.mjs` 额外提取顶层 function、常量与 `root.SN*` 导出。",
      "生成前清空 `docs/static`；`SKIP_SOURCES` 中的生成物不进入文档与 manifest。",
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

  "framework/tests/cases/test_ui_shell.gd": {
    role: "迭代 2 主界面接线测试：把真实外壳场景挂进场景树，断言六条反馈在界面构建路径上真的生效，并守护通报文案的本地化。",
    contracts: [
      "首帧运行器让 `_ready` 正常投递，因此控件树（含 SNSectionHeader 等自行构建子节点的组件）与游戏内一致。",
      "覆盖信息条（当前港口 + 剩余载重/剩余舱容，反馈 5）、通关清单与两种提示分支（反馈 6）；期望值独立复算（RegistryHub 翻译 + ShipOps 重量/舱容 + printf），不使用被测 helper 自证。",
      "覆盖船厂下单按钮 → CraftOps 订单 → 24 小时在港等待按钮 → 时间推进与成品入下单港仓库（反馈 4，经由真实按钮 pressed 信号）。",
      "场景接线断言覆盖独立总览、市场、委托、船厂、补给、情报、出航页面及四个菜单页面；船厂流程从 ShipyardScreen 的真实按钮驱动。",
      "流程场景接线覆盖港口记忆、抵达结算、航行中、航行事件与通关总结，逐一调用 Shell 构建入口并按脚本类型断言实例。",
      "覆盖设置/总览/市场/船厂密集字段禁用自动换行、市场单元格最小宽度，以及情报矩阵固定元数据列、可扩展港口列、最小列宽和深色单元格背景。",
      "覆盖补给页损失带：买煤后水的 meter.loss_value/cap_loss 与 baseline 跨度（反馈 2）、情报页 SNIntelTable 与未知港口掩码（反馈 3，列数对照 MapOps.ports）。",
      "覆盖「航行记录」：真实下单 + 等待后在 zh 与 en 两种 locale 下逐行断言通报无 `%s/%d` 残留、无裸键，并与**逐语言写死的期望句子**相等（模板槽位互换照样能渲染，只有字面期望能抓住「某一种语言的文案说反了」；en 只写错顺序时该用例会失败）。",
      "扫描 domain/application 源码里所有 `push_notice(\"…\")` 字面量：每个键在 framework 或 core 的 zh_CN/en 中恰好被一套定义，两套 locale 的键集合与**保序**槽位序列一致；槽位多于一个的键必须出现在用例的逐语言字面期望清单里。",
      "组件按路径 preload，不依赖编辑器全局类缓存。"
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
    intro: "纯领域逻辑：航行、市场、委托、船只/仓库/打造订单、地图、事件、债务与通关判定。",
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
    intro: "运行态数据模型。GameState 是唯一持久化状态，定义对象永不进入存档；含收入/支出/利润统计的惰性补齐。",
    contracts: ["GameState 可深克隆、可哈希，JSON 往返哈希一致。"]
  },
  "framework/ui": {
    intro: "展示层。固定 Shell、四个菜单场景、七个功能页、五个流程页与海图组件均已场景化；Shell 仅保留上下文解析、ViewModel 组合、导航、命令和转场。共享 Godot Theme、可复用控件与 UI Kit 展示场景保持统一视觉。",
    contracts: [
      "UI 只识别 Query/Command 与定义类型，不识别 core 内容。",
      "公共视觉状态优先进入 Theme variation；业务页面只负责布局与数据绑定。",
      "页面场景不得直接持有 AppContext；查询、命令、跨页导航、全局提示与音效属于 Shell。"
    ]
  },
  "framework/tests": {
    intro: "无头测试与冒烟脚本。覆盖加载链、确定性、经济、航行、委托刷新、仓库存取、打造订单/替换/在港等待、UI 外壳接线与完整通关流程。",
    contracts: [
      "测试入口：`godot --headless --path . --script res://framework/tests/test_runner.gd`。",
      "`test_case.gd` 提供断言与 Core 启动辅助；每个用例独立 bootstrap。",
      "测试源码可以引用 `core:*` ID；`test_no_core_ids.gd` 只扫描非测试框架代码。",
      "`test_full_clear.gd` 通过公开命令/查询脚本化跑完五段主线并组装大型船，覆盖 9 个 seed。"
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
    intro: "PowerShell 辅助脚本、Godot 验收脚本、建模工单 / 参数化生成器与静态文档生成器。",
    contracts: [
      "`test.ps1` / `pack_core.ps1` 通过 `GODOT_BIN` 定位引擎。",
      "`gen_static_docs.mjs` 读取 `static_docs_data.mjs` 生成 `docs/static/`。",
      "`modeling/briefs/*.json` 是建模子代理的自包含工单；尺寸/预算/材质只改这里，不靠口述传递。",
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
  "framework/tests/test_runner.gd": "无头测试发现、执行、汇总与退出码；首个渲染帧上运行，使 UI 套件能把外壳场景真正挂进场景树。",
  "framework/tests/cases": "按主题拆分的 97 个测试（含委托刷新、仓库/打造订单/在港等待、UI 外壳接线、密集界面横向排版、通报文案本地化与通关与多 seed 完整通关）。",
  "framework/tests/smoke_load.gd": "手动冒烟：加载 Core 并打印启动报告。",
  "framework/tests/smoke_play.gd": "手动冒烟：开局、预览、出航、事件选择。",
  "sdk/templates": "模组模板：Manifest、商品、双语本地化与说明。",
  "sdk/examples": "第三方锅炉示例，验证公共内容接口。",
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
  "tools/modeling/briefs/_template.json": "建模工单模板：字段说明与必填项。",
  "tools/modeling/briefs/sn_ship_prototype.json": "帆船原型工单（三桅六帆低模）。",
  "tools/modeling/briefs/sn_harbor_crane.json": "港口塔吊工单（锤头式，含回转枢轴与吊钩层级）。",
  "tools/modeling/briefs/sn_iron_harbor_batch1.json": "铁港第一批 6 件道具工单（岸壁/护舷/系缆桩/木箱/木桶/矿堆，y=24）。",
  "tools/modeling/briefs/sn_iron_harbor_batch2.json": "铁港第二批 6 件工单（煤气灯/跳板/抓斗/煤堆/爬梯/钢板堆，y=30）。",
  "tools/modeling/briefs/sn_iron_harbor_batch3.json": "铁港第三批 6 件工单（堆场/管线，y=36）。",
  "tools/modeling/briefs/sn_iron_harbor_batch4.json": "铁港第四批 6 件工单（机械/水上件，y=42）。",
  "tools/modeling/briefs/sn_iron_harbor_batch5.json": "铁港第五批 7 件工单（结构/标识/动力，y=48）。",
  "tools/modeling/briefs/IRON_HARBOR_PLAN.md": "铁港小部件 31 件 / 5 批的工单总表、布局、材质与已知坑。",
  "tools/modeling/dispatch.workflow.js": "批量派发脚本：串行 Builder + 独立 Verifier，脚本内不落盘（导出由 Lead 在人工验收后执行）。",
  "tools": "PowerShell 测试/打包脚本与静态文档生成器。",
  "SNModMaker/README.md": "使用说明、数据流、开发约定与已知边界。",
  "SNModMaker/mods/README.md": "磁盘工作区说明：每个模组目录的结构与 .snmodproj.json。",
  "SNModMaker/exports/README.md": "本地导出目录说明：ZIP 命名与忽略规则。",
  "SNModMaker/js/schema-bundle.js": "自动生成：嵌入 `/schemas/*.schema.json`。",
  "SNModMaker/js/core-index.js": "自动生成：Core 定义、内容与双语本地化索引。"
};
