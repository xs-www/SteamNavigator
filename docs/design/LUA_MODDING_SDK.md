# Steam Navigator — Lua Modding SDK 架构与实施规范

> **文档状态**：Draft 0.1（设计提案，尚未实现）  
> **适用项目**：Steam Navigator（SN）  
> **建议实施窗口**：Phase D D2 验收收口后，与 D3 Base 独立并行开展 PoC；正式 ModLoader 集成须单独验收。  
> **当前上下文**：Phase D D2 Fleet 已提交，独立验收收尾中；`combat_ai_profiles` 已作为 **draft Schema 2.0** 先落地（运行时不加载），Lua 是后续 L2 可执行模组层。本文不假设 D3 或 Lua SDK 已经合并。  
> **参考现状**：`framework/application/command_bus.gd`、`domain_event_bus.gd`、`framework_api.gd`、`framework/modding/mod_loader.gd`、`sdk/validate.gd`、`sdk/pack_mod.gd`、`content_types.json`、`SNModMaker/`。

## 1. 执行摘要

SN 保持 **Framework + Core Mod + Third-party Mods** 的结构。在现有纯数据 Content SDK 之上新增 Lua Script SDK，提供有限、版本化、能力控制的事件、查询、命令和私有存储接口，使第三方模组可以编写动态行为，但不能直接访问 Godot 对象、文件系统、网络、原生库或 `GameState`。

关键决策：

1. **分层而非替换**：Content Schema 继续负责声明式内容，Lua 负责行为扩展。纯数据包不要求 Lua VM。
2. **Lua 是执行语言，不是内部 API**：脚本只持有 `sn` 能力代理；所有跨界调用走结构化值协议和宿主校验。
3. **复用公共总线**：查询走 QueryBus，状态改变走 CommandBus，监听通过 DomainEventBus 的公开、版本化事件契约。不能把三个总线对象直接交给脚本。
4. **默认不可信**：第三方 Lua 在无原生库、无 OS/IO/调试能力的受限运行时执行。未证明可限制无限循环、内存占用及逃逸风险前，不开放第三方脚本发行。
5. **先 PoC、后 MVP**：PoC 在独立实验分支验证引擎、预算、导出兼容性；通过技术门禁后才在正式加载器中加入脚本阶段。
6. **确定性优先**：模拟时间、随机数、事件顺序、错误处理与存档对齐可重放语义；不使用 Lua 进程级随机源决定游戏行为。

### 1.1 非目标

首版不支持：任意 GDScript、C#、DLL/原生插件、Lua 网络访问、操作系统文件访问、编辑 Godot SceneTree、运行时创建未注册内容类型、直接覆写核心注册表、脚本驱动自定义 UI、自定义着色器、Lua 热重载、任意多线程并行执行及跨模组共享可变对象。

## 2. 与 SN 当前架构的对接

```text
┌───────────────────────────────────────────────┐
│ SN Framework                                  │
│ GameState / RegistryHub / Content Compiler    │
│ QueryBus / CommandBus / DomainEventBus        │
└──────────────────────┬────────────────────────┘
                       │ 受控宿主桥接
┌──────────────────────▼────────────────────────┐
│ Script SDK Host                               │
│ API Registry / Capability Guard / Scheduler   │
│ Event Adapter / Command Queue / Storage       │
│ Lua VM Adapter / Budget / Fault Isolation     │
└──────────────────────┬────────────────────────┘
                       │ 仅限安全的 JSON-like 值
┌──────────────────────▼────────────────────────┐
│ Third-party Mod Scripts                       │
│ scripts/main.lua + content/*.json + assets    │
└───────────────────────────────────────────────┘
```

### 2.1 不直接暴露内部对象

Lua 只能获取 string、number、boolean、nil、受约束的数组/字典及稳定 ID；禁止传入 Node、Resource、Object、Callable、RID、文件句柄或 Framework 上下文。查询结果为深拷贝的只读快照（在 Lua 侧禁止对其更改产生游戏效果）；所有参数进入宿主前验证大小、深度、字段和类型。

### 2.2 CommandBus 适配

现有 CommandBus 使用 clone-and-commit；成功结果发布领域事件。Script Host 应通过显式白名单转发命令，保持参数校验和事务语义。**事件回调期间不直接同步执行会触发事件的新命令**：先放入队列，当前事件批次完成后按稳定顺序执行，防止无限递归。

### 2.3 EventBus 适配

公开事件须先登记 `event_type`、payload 结构、版本、数据可见性、允许订阅能力。DomainEventBus 的内部历史容量与实现不是第三方兼容契约；SDK 不应向模组承诺直接读取内部历史。监听事件必须在宿主层做 payload 裁剪与权限检查。

### 2.4 与 Schema 2.0 的关系

- Content Schema 版本、Script API 版本、Framework 版本、Save Schema 版本彼此独立。
- 当前 D2/D3 实体迁移不应为 Script SDK 增加 active 内容类型。
- 脚本查询通过公开语义 API，不能绑定 `goods_registry`、`module_registry` 等内部结构。
- 对 Item/Module/Quest 的旧 ID 采用 Framework 的统一 alias 解析；Script Host 不维护另一套 alias 表。
- 冻结后注册表只读。脚本不能绕过 Schema、跨引用或 Core 完整性校验。

## 3. 模组 Manifest 扩展（提案）

建议在现有 manifest 契约上**增量增加可选** `scripts` 字段，避免为脚本系统新建第二份 manifest：

```json
{
  "id": "example_engine",
  "name": "Engine Events",
  "version": "1.0.0",
  "api_version": "1.0",
  "type": "hybrid",
  "dependencies": [{"id": "core", "version": ">=1.0.0 <2.0.0"}],
  "content": ["content/boilers.json"],
  "localization": ["localization/zh_CN.json"],
  "scripts": {
    "language": "lua",
    "script_api_version": "1.0",
    "entry": "scripts/main.lua"
  },
  "capabilities": [
    "script.events.subscribe",
    "script.query.ship",
    "script.command.ship",
    "script.storage"
  ]
}
```

> 上述 `type=hybrid`、`scripts` 及权限名均为**待设计和实现的新字段**；不能直接交给当前 SN 运行时。现有 `api_version` 与新 `script_api_version` 不应混淆。正式落地前确定统一的能力命名、版本比较与向后兼容策略。

- 缺省 `scripts` 即纯数据 Mod/Datapack，不启动 Lua VM。
- 所有脚本路径必须规范化并限定在模组根内，拒绝 `..`、绝对路径与路径别名逃逸。
- 脚本能力集合默认空集；不允许脚本动态扩大权限。
- 依赖解析、模组启停、冲突检查沿用现有 ModLoader/DependencyResolver。
- 如果运行时没有 Lua 支持，含脚本的 Mod 必须明确失败或标记为不可启用，不得默默忽略脚本后把它当正常模组加载。

## 4. Script SDK 1.0 公共 API

### 4.1 命名原则

使用少量稳定入口，参数/返回值以结构化值形式传输。下列都是**目标 API 草案**，不是现有接口：

| 分类 | Lua API | 语义 |
|---|---|---|
| 元信息 | `sn.mod.info()` | 返回本模组 ID、版本、能力快照 |
| 查询 | `sn.query(name, params)` | 查询公开只读视图 |
| 命令 | `sn.command(name, params)` | 向宿主提交**延迟执行**的命令请求 |
| 事件 | `sn.events.on(event_type, callback)` | 注册公共事件回调 |
| 事件 | `sn.events.off(token)` | 取消订阅 |
| 存储 | `sn.storage.get(key)` / `set(key, value)` | 本模组私有命名空间存储 |
| 随机 | `sn.random()` / `sn.random_int(min,max)` | 宿主提供确定性随机序列 |
| 日志 | `sn.log(level, message)` | 带模组 ID 的限频日志 |
| 版本 | `sn.api.version()` | 返回脚本 API 版本和支持能力 |

### 4.2 返回值与错误协议

所有易失败调用建议统一：

```lua
local result = sn.query("ship.get", { ship_id = "ship-001" })
if not result.ok then
    sn.log("warn", result.error.code)
    return
end
local ship = result.value
```

宿主返回 `{ok: true, value: ...}` 或 `{ok: false, error: {code, message, details?}}`。错误码应稳定；面向用户的本地化文本与机器错误码分离。参数异常、无权限、对象不存在、API 版本不兼容均属于正常错误，不得导致进程崩溃。

命令调用返回的是**请求入队回执**，不承诺立即提交；执行结果通过定义好的 `script.command_result` 回调/任务句柄通道返回。不得复用 `sn.command()` 的同步返回值表示业务成功。

### 4.3 最小示例

```lua
local token = sn.events.on("voyage.completed", function(event)
    local ship_id = event.payload.ship_id
    local result = sn.query("ship.get", {ship_id = ship_id})
    if not result.ok then return end
    local ship = result.value
    if (ship.boiler_condition or 1.0) < 0.3 and sn.random() < 0.15 then
        local accepted = sn.command("ship.apply_damage", {
            ship_id = ship_id,
            amount = 5,
            reason = "example_engine:boiler_fault"
        })
        if not accepted.ok then sn.log("warn", accepted.error.code) end
    end
end)
```

> 示例里的 `voyage.completed`、`ship.get`、`ship.apply_damage`、`boiler_condition` 均是**示意契约**，必须以实际注册、版本化的公开 API 为准，不应把示例当作当前 Framework 已实现能力。

## 5. 生命周期与加载流程

建议的新阶段（正式实施前先验证现有加载器挂接点）：

```text
scan manifest
  → dependency resolve / capability precheck
  → content parse / schema validate / cross-reference
  → registry freeze
  → script runtime capability negotiation
  → VM create / entry load / API registration
  → mod.on_load
  → gameplay event dispatch
  → mod.on_unload / VM dispose
```

**失败原则：**必须在内容已通过正式校验后才执行 Lua；脚本初始化失败应禁用对应脚本能力并记录错误，不能导致半初始化脚本继续接收事件。对 `required` 模组是否阻止游戏启动采用现有严重度模型，并另行制定脚本失败级别；不允许静默成功。

| 事件 | 宿主动作 | 脚本状态 |
|---|---|---|
| 发现无脚本模组 | 按当前内容流程执行 | 不创建 VM |
| Lua 脚本载入成功 | 注册公开 API，运行入口 | Initialized |
| `on_load` 成功 | 启用事件订阅 | Active |
| 单次回调超限 | 中断、记错、撤销该回调未提交请求 | Faulted / Disabled（策略可配置） |
| 模组停用 | 移除订阅，清空待执行请求，保存私有状态 | Unloaded |
| 存档载入 | 校验存储 Schema 并恢复私有快照 | Active 或安全禁用 |

不提供任意 `on_tick` 无限高频回调；若未来开放固定步进更新，需要频率上限、执行预算及暂停/恢复语义。

## 6. 安全模型（MVP 发布硬门槛）

### 6.1 Lua VM 策略

- 优先评估可嵌入 Godot 4.7.2、可打包 Windows/Linux 的 Lua 实现；运行时选择应记录许可证、维护状况、平台构建步骤与二进制供应链。
- **每模组独立 Lua state/环境**，无跨模组共享可变全局状态。
- 关闭或不绑定 `io`、`os`、`debug`、`package.loadlib`、`require` 外部解析、FFI 和原生调用；若允许模块导入，仅允许模组包内白名单 Lua 模块。
- 宿主传值采用拷贝与序列化边界；Lua 不接触 Godot Object userdata。
- 针对无限循环采用 VM 指令预算或可靠的中断机制，针对内存采用可计量的分配器/上限。**墙钟超时检测不能替代真正中断。**
- VM 不支持上述硬约束时，PoC 只能标记为受信任开发模式，不得宣称第三方安全沙箱。

### 6.2 最小权限

| Capability（提案） | 默认 | 约束 |
|---|---|---|
| `script.events.subscribe` | 按公开事件授予 | payload 过滤 |
| `script.query.*` | 按资源域授予 | 只读、字段裁剪 |
| `script.command.*` | 需显式声明 | 逐命令白名单及参数校验 |
| `script.storage` | 可选 | 每模组配额与数据版本 |
| 文件 / 网络 / OS / 原生库 | 不开放 | 首版没有相关 capability |

能力声明不等于权限执行；每一次 Lua → Host 调用都需要宿主侧授权。细粒度许可策略和用户授权 UI 在 PoC 通过后确定；在此之前，不允许未经验证的模组使用脚本发行。

### 6.3 预算与故障隔离

建议先作为可配置预算（具体值通过 PoC 基准测试确认，而不是写死为承诺）：

- 每回调指令数、总 VM 内存、每轮回调次数。
- 单事件链最大深度、每轮待执行命令数量。
- 存储键数、序列化值大小、日志输出速率。
- 高错误率时自动禁用该 Mod 脚本，记录稳定错误码、mod_id、script 文件、回调和堆栈摘要（不泄露宿主内部对象）。

## 7. 调度、事务与确定性

### 7.1 脚本调度器

在主线程建立可重复的调度顺序：`event sequence → mod order → subscription registration index`。事件回调只产生请求，不直接重新进入 CommandBus。处理完当前事件批次，再按队列次序提交命令，并把提交产生的新领域事件排入下一批。

- 对同一轮事件/命令设总预算，超限后明确拒绝后续请求并记录来源。
- 必须决定脚本回调内查询的快照时间点（建议为该批次开始的已提交 GameState）。
- 回调异常时撤销该回调产生的**尚未提交**请求；已提交的独立命令不做跨命令隐式回滚。
- 多模组对同一游戏对象操作时依次经过业务验证，不允许直接并发写状态。

### 7.2 RNG、时间与重放

- 各模组有独立 PRNG stream，种子由 Campaign seed + Mod ID + 固定协议版本派生。
- RNG 状态作为存档中脚本状态的一部分；不使用系统时钟或原生随机函数推进模拟。
- 脚本时间只能获取游戏内时钟，不提供系统 wall-clock 作为游戏分支判断依据。
- 对随机事件、指令队列顺序、脚本错误和宿主版本记录可重放测试。

## 8. 存档与兼容性

建议建立 `script_states[mod_id]` 的命名空间，数据为只允许 JSON-like 值的有限大小快照：

```json
{
  "script_states": {
    "example_engine": {
      "storage_schema": "1.0",
      "data": {"faults_triggered": 2},
      "rng_state": "opaque-host-owned-state"
    }
  }
}
```

这是**目标格式示例**，不是现有 Save Schema。须通过现有存档版本控制和迁移系统接入，不能直接在当前 `GameState` 字段里随意添加未受保护的数据。

- 模组不存在时：保留其可识别数据但不执行行为；卸载后是否清理状态必须由用户显式选择。
- 脚本版本升级时：通过受限数据迁移 API 转换其私有状态，失败则标记为不可用并保留备份。
- 不允许脚本直接修改其他模组的存储空间或 Core 的存档版本信息。
- 存档恢复后重新绑定事件订阅，不序列化函数或 VM 栈帧。

## 9. Script SDK 目录与对外交付

近期以**不搬迁**既有 `sdk/validate.gd`、`sdk/pack_mod.gd` 为原则，新增：

```text
sdk/
├── validate.gd                     # 既有：保留调用兼容
├── pack_mod.gd                     # 既有：保留打包格式
└── script/                         # 新增；PoC 可先单独实验
    ├── README.md
    ├── api/                         # API 契约、事件/命令白名单
    ├── examples/example_engine/
    ├── tests/
    └── tools/                       # 静态检查/签出版本/打包辅助

framework/scripting/                 # 建议运行时实现位置
├── script_host.gd
├── script_scheduler.gd
├── script_api_registry.gd
├── script_capability_guard.gd
├── script_storage.gd
└── lua_vm_adapter.gd                 # 名称示意，最终按集成方式调整
```

**注意**：宿主运行时代码应属于 Framework，而不是把游戏核心调度逻辑放在可随游戏导出排除的 `sdk/` 目录。SDK 包含面向作者的契约、模板、验证工具和测试。

## 10. CLI 与发布流程

优先复用现有无头工具。下面是**建议接口**（未实现）：

```text
sn-sdk script check --mod <directory>       # Manifest/路径/脚本语法/声明能力
sn-sdk script test --mod <directory>        # Mock Host 单元测试
sn-sdk script verify --mod <directory>      # 真正 Lua Host 与框架集成验证
sn-sdk script pack --mod <directory>        # 格式与发布门禁后打包
```

为避免引入第二套复杂 CLI，实际可以扩展现有 `sdk/validate.gd`、`sdk/pack_mod.gd` 的参数，也可以让 `SNModMaker/tools/content.mjs` 作为统一外层入口。选择原则：**同一个 manifest、同一套能力规则、同一组发布错误码**。

发布层级：

| 输出 | 允许草案/不可信脚本？ | 规则 |
|---|---|---|
| 本地开发测试包 | 草案允许；脚本仅在开发模式 | 必须明显标记不可发行 |
| 正式数据模组包 | 不允许未激活 Schema 草案 | 现有验证门禁 |
| 正式脚本模组包 | 仅在沙箱能力通过验收后开放 | 内容 + 脚本静态 + 宿主行为 + 导出平台校验 |

不要以 Lua 语法检查通过替代安全性、权限和实际平台验证。

## 11. 测试矩阵与验收条件

| 范围 | 最低测试 |
|---|---|
| 兼容 | 现有纯数据 Core、第三方 1.0/2.0 模组不创建 VM、行为不变 |
| Manifest | 版本不匹配、非法路径、未知 capability、无脚本运行时均可明确报错 |
| API | 查询参数合法性、只读快照、命令权限、返回错误码稳定 |
| 生命周期 | 初始化失败、禁用模组、重复加载、卸载清理、存档恢复 |
| 调度 | 递归事件链、双模组顺序、单批命令限额、错误回滚 |
| 隔离 | Lua 无限循环、内存耗尽、禁用库访问、试图逃逸路径 |
| 确定性 | 同一种子同事件序列同结果；存档后续运行与不存档一致 |
| 包装 | Windows / Linux 开发与导出产物行为一致 |
| CI | 原有 Godot 测试、生成物检查、Core 校验、发行构建全部保持通过 |

### 11.1 PoC 通过门槛（S1）

1. 在 Godot 4.7.2 的 Windows/Linux 构建中能创建、执行、销毁独立 Lua state。
2. 能订阅一个公开事件，查询一个只读视图并提交一个允许的命令请求。
3. 无限循环可**可靠中断**，内存上限可验证，OS/IO/原生模块不可达。
4. 连续失败可禁用对应脚本，不影响 Core/GameState。
5. 不改 active Content Schema 类型；不影响无脚本模组的启动行为。

任何一项不满足，**停止将 PoC 晋级为可装载第三方脚本的正式功能**；可以继续用于可信内部原型，但必须明确标识非沙箱环境。

## 12. 与 D3、战斗系统的并行计划

| 阶段 | 时机 | 产出 | 合入政策 |
|---|---|---|---|
| S0 契约设计 | 现在，D2 验收收尾/D3 开始前后 | 本文、版本/能力/API 契约、威胁模型 | 可单独合并文档 |
| S1 Lua Host PoC | 与 D3 独立并行 | 原型 VM、桥接、预算与平台实验、报告 | 实验分支，不改正式加载器 |
| S2 Script SDK MVP | D3 与 PoC 验收后 | `framework/scripting/`、SDK 示例/CLI、存档与测试 | 独立集成工作包，完整 CI 绿 |
| S3 战斗扩展点 | 战斗状态机与行为接口稳定后 | 战术决策/技能触发等**预定义**扩展点 | 由战斗系统明确契约后开放 |
| S4 作者工具 | 稳定发布后 | SNModMaker 脚本编辑、诊断、模板 | 不能替代 SDK 真实验证 |

并行隔离策略：D3 修改 Content Schema 和对应运行时；Lua PoC 独立 worktree，禁止修改 `content_types.json`、Core 内容、主分支发布 workflow。PoC 验收后重新基于最新 D3 分支做集成，防止用旧 Framework 的通过结果冒充最终兼容性。

## 13. 技术选型决策记录（待验证）

| 议题 | 当前建议 | 决策前证据 |
|---|---|---|
| 第一语言 | Lua | Godot 4.7.2 支持、可中断、内存预算、许可证与跨平台构建 |
| VM 隔离 | 每 Mod 独立 state | 资源占用与逃逸测试 |
| API 桥接 | 宿主白名单代理 | 无 Object/userdata 暴露的验证 |
| 执行顺序 | 单线程确定性事件批次 | 性能和重放测试 |
| 第三方原生扩展 | 首版禁止 | 若未来开放需独立信任级别和警告 |
| 数据扩展 | Schema/ContentCompiler 唯一真源 | C2–C4 和 D2/D3 兼容验收 |
| 未来 WASM/JS | 不承诺 | 先证明 Lua 方案可维护且安全 |

## 14. 风险清单

| 风险 | 等级 | 控制措施 |
|---|---|---|
| Lua 插件没有可靠执行中断 | 阻断 | PoC 不晋级正式第三方脚本功能 |
| 原生桥接泄露 Godot 对象 | 阻断 | 参数/返回值仅深拷贝结构化值；代码审计 |
| 事件引发递归调用/无限命令链 | 高 | 队列分批、总预算、可追踪的来源 |
| Schema 迁移破坏脚本 API | 高 | 语义 API + alias 服务 + 契约测试 |
| 模组状态污染存档 | 高 | 命名空间、限额、迁移和恢复测试 |
| 平台打包后 Lua 不可用 | 高 | Windows/Linux 发布产物测试 |
| SDK 与 SNModMaker 规则分叉 | 中 | 单一 Manifest/Schema/能力配置源 |
| 脚本调试成本过高 | 中 | 稳定错误码、mod_id、事件链和命令回执 |

## 15. Agent 实施任务拆分

### Work Package S0 — 契约与威胁模型（文档）

- 将本文放入 `docs/design/LUA_MODDING_SDK.md`，保留 Draft 标记。
- 盘点现有 Query/Command/Event 注册名称及数据结构，输出可公开的首批候选 API；不能把内部对象当 API。
- 明确 `api_version` 与 `script_api_version` 语义、capability 命名方式、返回错误协议。
- 输出 Lua 运行时威胁模型及验收测试案例。

### Work Package S1 — 独立 PoC（禁止碰正式加载器）

- 对比可嵌入 Lua VM 实现，记录版本、构建条件、许可证、性能、安全能力。
- 做事件 → Lua → 查询 → 命令队列的纵向小样例。
- 验证无限循环中断、内存耗尽、文件/网络访问阻止和导出平台表现。
- 产出技术报告：`docs/research/LUA_HOST_POC_REPORT.md`。

### Work Package S2 — 受控集成（必须经过门禁）

- 在 Framework 新增 Script Host、调度器、能力检查与脚本状态存储。
- 给 ModLoader 增加可选脚本加载步骤，对无脚本 Mod 保持严格兼容。
- 在 SDK 加入脚本模板、运行时验证、CLI 文档与自动化测试。
- 确保 CI 使用最终集成分支运行全套发行测试，不以 PoC 的局部测试代替。

## 16. 最终验收定义

当以下条件全部成立，才能将 Lua Script SDK 标记为 `1.0`：

- 第三方模组只能通过受控 SDK 调用公开查询、命令和事件。
- 纯数据 Core/Datapack 的读取、验证、打包和游戏运行行为与升级前一致。
- 不可信脚本无限循环、内存耗尽和越权访问有可复现的防护测试。
- 每个脚本有明确权限、错误码、预算、加载状态与禁用机制。
- 脚本不能绕过 Content Schema 校验与 Registry Freeze。
- 事件和命令时序确定性可测，持久状态可保存、恢复与迁移。
- Windows/Linux 导出产物通过运行测试；正式发布门禁可阻止不符合要求的脚本模组。
- Script API 有版本与兼容政策，SDK 示例和文档与实际运行时完全一致。

---

**结论**：SN 现在适合启动 **S0 契约设计 + S1 Lua Host PoC**，不适合在 D3 Base 开发期间直接把不成熟的 Lua Runtime 接入正式 ModLoader。先把安全和确定性证明做实，再将 Script SDK 作为独立纵向切片正式上线。
