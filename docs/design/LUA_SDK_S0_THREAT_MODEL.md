# Steam Navigator — Lua Script SDK S0 威胁模型

> **文档状态**：Draft 0.1（S0-2 交付：Lua Script SDK 运行时威胁模型；随 S1 PoC 证据与 S2 实现更新）
> **适用项目**：Steam Navigator（SN），Godot 4.7.2 + 纯 GDScript
> **上游依据**：[LUA_MODDING_SDK.md](LUA_MODDING_SDK.md) §6（安全模型）、§7（调度/确定性）、§8（存档）、§10（发布）、§11（测试矩阵与 §11.1 PoC 门槛）、§14（风险清单）、§15（S0 任务）
> **当前事实基线**：SN 目前**完全没有脚本层**。`framework/scripting/` 不存在，Manifest 不接受 `scripts` 字段，扫描器会拒绝 `.lua` 文件，Lua VM 未选型。本文所有"缓解措施"分为两类：可复用的现状机制（给出源码路径）与**当前缺失、需 S1/S2 建立**的机制（标注 `GAP-nn`）。
> **本文不做什么**：不替代测试矩阵（本文只写"验收观测点"，不写测试步骤）；不替代 S1 PoC 技术报告（`docs/research/LUA_HOST_POC_REPORT.md`）；不把"测试通过"当作安全结论。
> **阅读顺序**：第 0 章判定口径 → 第 1 章资产与威胁主体 → 第 2 章信任边界 → 第 3 章威胁清单 → 第 4–6 章攻击面/不变量/PoC 证据 → 第 7 章差距 → 第 8 章待决问题。

## 0. 阅读约定与判定口径

### 0.1 文档定位

本文是 Work Package S0 的四个交付物之一（见上游 §15）：把"Lua 脚本可以做什么、不能做什么、做错什么会怎样"固化为**可验收的威胁模型**。它的直接消费者是：

1. **S1 PoC 报告**：每类威胁的"最小证据"是 PoC 必须给出的实验观测，不允许用"代码看起来安全"替代。
2. **测试矩阵（独立文档）**：每条威胁的 `OBS-*` 观测点可直接变成断言；本文不写测试步骤。
3. **S2 Script Host 实现**：安全不变量 `INV-*` 是实现的验收契约，差距 `GAP-*` 是实施清单。
4. **发布门禁**：第 6 章把威胁与上游 §11.1 / §14 对齐，明确"哪些没证明就不能发"。

### 0.2 严重度与"发布阻断"判定（硬口径，不得放宽）

本文只使用两档阻断口径，且**与上游完全对齐，不自行扩大也不缩小**：

- **发布阻断＝是**，当且仅当该威胁一旦成立，会直接使上游 §11.1 PoC 五项门槛之一失败，或直接命中上游 §14 中等级为**阻断**的风险行。每条阻断威胁都标注具体依据（`§11.1-n` 或 `§14 第 n 条`）。
- **发布阻断＝否**，即使严重度为"高"，也只在 §6.4 列为"S2 发布前必须闭合"的工程项，不计入阻断计数。理由：上游把"安全能力"与"工程完备度"分开授予，本文不替上游加码；但会在每条的残余风险中写明"若 S1 出现该失败，按 §11.1 升级为阻断"。

严重度定义：

| 严重度 | 含义 | 判定提示 |
| --- | --- | --- |
| 严重 | 沙箱整体失效、宿主进程崩溃、存档不可恢复、发布门禁被绕过 | 通常对应阻断项 |
| 高 | 越权/跨模组污染/确定性破坏，需要后续批次修复但不立刻使沙箱失效 | 非阻断，S2 必须闭合 |
| 中 | 信息泄露、资源浪费、可恢复的功能异常 | 非阻断，排期修复 |
| 低 | 影响有限或需要额外前提 | 记录并接受 |

阻断项映射（9 条，完整论证见 §6.3）：

| 上游门槛 | 对应威胁 |
| --- | --- |
| §11.1-1 独立 Lua state 可创建/执行/销毁 | TM-BR-03 |
| §11.1-2 订阅事件、查询只读视图、提交允许的命令 | TM-AUTH-01 |
| §11.1-3 无限循环可可靠中断、内存上限可验证、OS/IO/原生不可达 | TM-EXEC-01、TM-EXEC-02、TM-ISO-01、TM-ISO-02 |
| §11.1-4 连续失败可禁用脚本且不影响 Core/GameState | TM-EXEC-06 |
| §14 第 1 条「Lua 插件没有可靠执行中断」 | TM-EXEC-01 |
| §14 第 2 条「原生桥接泄露 Godot 对象」 | TM-BR-01、TM-BR-02 |
| §11.1-5 不改 active Content Schema、不影响无脚本模组 | 无直接威胁（架构/回归约束，由 GAP-02、GAP-17 与 CI 回归覆盖） |

### 0.3 三层缓解定义（不允许混写）

| 层 | 阶段 | 产出形态 | 判定方式 |
| --- | --- | --- | --- |
| **S0 契约** | 现在（本文） | Manifest/API/错误码/能力/预算的**文字契约**与不变量 | 评审通过、进入 SDK 契约与 schema |
| **S1 PoC 证据** | 独立实验分支 | 可复现实验的**观测结论**（不是实现承诺） | 在 Windows/Linux 上观测到预期结果；报告可复核 |
| **S2 运行时实现** | PoC 通过后 | `framework/scripting/` 中的**真实机制** + 测试 | 每个不变量有自动化断言；发布门禁可执行 |

写每一条威胁时，三层分别回答："契约要求什么"、"PoC 必须看到什么"、"代码用什么机制保证"。任何一层写不出来，就明确标注"当前缺失（GAP-nn）"，不臆造。

### 0.4 事实基线（本文引用的现状机制）

| 机制 | 源码事实 | 对本文的意义 |
| --- | --- | --- |
| 命令事务 | `framework/application/command_bus.gd:42-57`：handler 在 `GameState.clone()` 上执行，成功才 `original_state.replace_with(working_state)` 并发布事件；失败不提交 | 可复用为脚本命令的唯一写路径 |
| 查询快照 | `framework/application/query_bus.gd:38-41`：查询执行前 `original_state.clone()`，执行后恢复 | 可复用为脚本只读查询的隔离基础 |
| 领域事件 | `framework/application/domain_event_bus.gd:7-9,16-30`：`MAX_HISTORY=500`，事件 envelope 含 `event_id/game_time/source/payload/schema_version`；`payload.duplicate(true)` | **内部实现不是第三方契约**，脚本事件必须另建公开契约 |
| 注册表冻结 | `framework/modding/registry_hub.gd:52-56`：`freeze_all()` 后 `_frozen=true`；`mod_loader.gd:108-111`：校验通过后冻结再关闭包 | 脚本必须在冻结之后才能启动 |
| 模组发现/校验 | `framework/modding/mod_scanner.gd` 的 `unsafe_path`/`forbidden_file`/`unsupported_capability` 等结构化错误；`framework/core/path_guard.gd` 的 `is_safe_relative` | 路径与文件类型门禁可复用，但需扩脚本通道 |
| 能力白名单 | `framework/core/framework_info.gd:14-32`：`CAPABILITIES` 仅 `content.*`；`dependency_resolver.gd:112-127` 未知能力直接禁用模组 | 无 `script.*` 能力命名空间 |
| Manifest | `framework/modding/mod_manifest.gd:34-67`：只接受 `type=content`，解析 content/localization/assets/capabilities/checksum；`schemas/manifest.schema.json` `additionalProperties=false` | **`scripts` 字段当前会被 schema 拒绝** |
| 存档 | `framework/services/save_service.gd`：槽名正则、`.tmp` 写后复解析、`.bak` 回滚、`validate_mods()` 缺模组硬失败/版本与 checksum 漂移仅警告；`save_migrations.gd` 只迁移 `save_schema/state_schema/content_versions` | 无 `script_states`；脚本状态接入点为空 |
| RNG/时钟 | `framework/services/rng_service.gd:47-65`：按 `base_seed + stream + context` 派生 `RandomNumberGenerator`；`framework/services/clock_service.gd` 只做游戏时间格式化；`GameState.now()` 在状态内 | 确定性基础设施可复用，但无每模组 PRNG 与脚本时钟 API |
| 日志 | `framework/services/logger.gd`：`MAX_ENTRIES=1000`，`echo_to_console` 默认开，`_log()` 把 `fields` 深拷贝后打印 | 无速率/长度限制、无脱敏通道 |
| SDK 门禁 | `sdk/validate.gd` 仅 `runtime`/`draft` 内容校验；`sdk/pack_mod.gd --release` 只跑内容 runtime 校验，注释明确"发布签名/哈希不在本脚本内处理"；`.github/workflows/release.yml` 无双平台 Lua 运行验证 | 无脚本检查、无脚本打包门禁、无签名 |

### 0.5 ID 规范

- 威胁：`TM-<AREA>-nn`，AREA ∈ `BR / ISO / EXEC / AUTH / SCHED / STATE / SUPPLY / LEAK / PLATFORM`，共 44 条。
- 安全不变量：`INV-nn`，共 28 条，均为可测试断言。
- 差距：`GAP-nn`，共 22 条，描述"当前 SN 缺什么 / 可复用现有什么"。
- 观测点：`OBS-<AREA>-nn`，与威胁同号，供测试矩阵直接引用。
- 开放问题：**本文独立编号 `T-OQ-nn`**，与 API 契约文档的 `OQ-nn` 不共享编号空间，避免引用歧义。

---

## 1. 范围与假设

### 1.1 范围内

本文覆盖**第三方 Lua 脚本模组从打包、分发、加载、执行、存档到卸载的完整生命周期**，前提是上游设计中允许的可执行模组层。具体包括：

- Manifest 中 `scripts` 声明、脚本入口、脚本 API 版本与能力声明；
- 脚本包内的 Lua 源码与（若允许）白名单模块；
- 宿主桥接（值协议、查询、命令、事件、存储、RNG、日志）；
- 调度器、预算、故障隔离与生命周期；
- 脚本状态进入存档、迁移、恢复；
- 发布打包、导出平台与完整性校验；
- 脚本对 Core、其他模组、玩家机器与游戏确定性的影响。

### 1.2 威胁主体

| 编号 | 主体 | 能力前提 | 动机 | 是否本次覆盖 |
| --- | --- | --- | --- | --- |
| TA-1 | 恶意第三方模组作者 | 完全控制 manifest、内容、Lua 源码、打包产物；能构造任意脚本 | 作弊、破坏、窃取信息、扩大权限 | 是（核心） |
| TA-2 | 有 bug 的模组作者 | 无恶意，但写出无限循环、深递归、错误调度、错误存档迁移 | 无 | 是（与恶意同等破坏力） |
| TA-3 | 供应链/分发篡改者 | 可替换下载包、镜像、更新包、导出产物中的脚本或二进制 | 植入后门、篡改行为 | 是 |
| TA-4 | 本地存档篡改者/玩家 | 可读写 `user://saves`、可编辑 JSON 存档与配置 | 作弊、解锁未探索内容、伪造进度 | 是 |
| TA-5 | 跨模组干扰者（恶意模组 A 对模组 B） | 能加载并与 B 共存；控制 A 的脚本 | 读取/污染 B 的状态、抢占 B 的回调 | 是 |
| TA-6 | 本机其他进程/恶意软件 | 可读写用户目录、替换可执行文件、注入进程 | 窃取存档、篡改游戏 | 部分覆盖（只覆盖"影响游戏内沙箱边界"的部分） |
| TA-7 | 内部集成缺陷（非攻击者） | 框架实现的疏漏 | 无 | 是（以"实现缺陷"而非"攻击者"方式进入威胁路径） |

### 1.3 受保护资产

| 编号 | 资产 | 损害形态 | 主要不变量 |
| --- | --- | --- | --- |
| A-1 | `GameState` 与存档（进度、seed、世界状态、任务、船队） | 被脚本直接改写、被伪造存档污染、迁移失败导致不可读 | INV-21、INV-22 |
| A-2 | 注册表冻结不变式（`RegistryHub._frozen`） | 冻结后仍被写入，内容定义被运行时篡改 | INV-03、INV-21 |
| A-3 | 玩家账号/机器文件 | 读取安装路径、用户名、配置、任意本地文件；写入用户目录 | INV-06、INV-07 |
| A-4 | 性能与可用性（主线程、帧预算、内存、启动时间） | 无限循环、内存轰炸、命令/事件风暴导致卡死或 OOM | INV-10、INV-11、INV-13、INV-18 |
| A-5 | 其他模组数据与回调 | 跨模组 storage、跨模组回调、事件顺序干扰 | INV-14、INV-17、INV-18 |
| A-6 | 发布完整性（源码、包、导出产物、哈希/签名） | 脚本被替换、包内容与校验内容不一致、错误平台产物 | INV-24、INV-25 |
| A-7 | 玩法公平与确定性（未探索信息、RNG、重放） | 透视、随机数操纵、跨平台/跨帧率结果分歧 | INV-16、INV-23、INV-26 |
| A-8 | 宿主内部实现细节（路径、类名、内部 API、事件历史） | 通过错误、日志、查询、调试信息泄露 | INV-04、INV-27、INV-28 |

### 1.4 前提假设

1. **单线程**：Lua 与所有游戏逻辑在主线程执行；不假设脚本可并行。任何"用线程做超时"的方案都不满足上游 §6.1 的"真正中断"要求。
2. **无网络**：首版脚本无网络与文件能力；跨机通信不在范围内。
3. **每个模组独立 VM**：至少一个独立 Lua state/环境；共享 state 直接违反上游 §6.1。
4. **Capability 声明不可信**：Manifest 中的 `capabilities` 只是"申请"，授权由宿主在**每次调用**执行（上游 §6.2 明文）。
5. **内容先校验、后执行**：只有通过 Manifest/内容/交叉引用/冻结的模组才允许创建 VM（上游 §5）。
6. **脚本是数据 + 可执行代码的混合体**：不能把"内容校验通过"当成"脚本安全"。
7. **VM 选型未定**：本文不假设具体 Lua 实现；三处硬约束（可中断、可计量内存、无原生库）必须由 S1 报告给出证据（`T-OQ-01`）。
8. **上游文档仍是 Draft**：当上游 §3/§4/§6 的提案落地时，本文对应契约同步更新，不把草案字段当成已实现。

### 1.5 非目标

以下内容**明确不在**本文覆盖范围（引用上游 §1.1，并补充安全视角）：

- 已取得本机管理员/内核权限的攻击者：可替换二进制、读写任意内存，宿主内沙箱无法防御；
- Godot 引擎、Lua VM、操作系统、显卡驱动的 0day 或实现级内存安全漏洞——只要求 S1/S2 记录选型风险与缓解，不作安全证明；
- 反作弊 / DRM / 玩家间对抗（首版无联网）；
- 脚本作者自有资产（美术、音频、文本）的版权与内容合规；
- S3 战斗扩展点、S4 作者工具的完整威胁模型（届时另立文档）；
- 不承诺脚本性能 SLA，只承诺预算上限与可观测拒绝；
- 不替代代码审计、渗透测试与 S1 PoC 报告；
- 不把"沙箱能跑"当作"沙箱安全"——所有结论必须有可复现证据。

---

## 2. 信任边界与数据流

### 2.1 信任域

| 信任域 | 组成 | 默认信任级别 | 说明 |
| --- | --- | --- | --- |
| T0 发布/供应链 | CI、`release.yml`、`pack_mod.gd`、发布产物 | 可信（受仓库权限保护） | 一旦被篡改，沙箱仍应限制其后果，但发布完整性另属 A-6 |
| T1 平台/OS/引擎 | Windows/Linux、Godot 4.7.2、Lua VM 二进制 | 半可信 | 假定无恶意，但行为有平台差异；VM 二进制供应链需单独验证 |
| T2 宿主 Framework | GameState、RegistryHub、三个总线、Script Host、SaveService | 可信 | 安全边界内的最终裁决者 |
| T3 SDK/打包工具 | `sdk/validate.gd`、`sdk/pack_mod.gd`、SNModMaker、未来 `script check/pack` | 可信但需与运行时同源 | 规则分叉是上游 §14 的中风险，必须单一 Manifest/能力源 |
| T4 模组数据 | manifest、content JSON、localization、assets、脚本源码 | **不可信** | 即使通过扫描也只代表"结构合规"，不代表安全 |
| T5 脚本运行时 | 每模组 Lua state、全局环境、`sn` 代理、回调 | **不可信** | 假定脚本作者可构造任意 Lua 代码 |
| T6 本地文件 | `user://saves`、`user://config`、可执行目录、存档备份 | 半可信 | 本机玩家/进程可改，但游戏内脚本不得触达 |

关键判断：**T4 与 T5 永远不可信；T2 是唯一有权修改 A-1/A-2 的域；T0/T3 的可信不传递给 T4/T5。** 打包工具通过校验，不代表脚本可信；脚本通过语法检查，不代表运行安全（上游 §10 最后一句）。

### 2.2 数据流与信任边界

```text
┌────────────────────── T0 发布/供应链（CI、GitHub Release、本地打包）──────────────────────┐
│ release.yml · sdk/pack_mod.gd · sdk/validate.gd · 未来 script check/pack                  │
│ 产物：*.snavmod.zip · Windows/Linux 导出包 · SHA256SUMS（签名待建）                        │
└───────────────────────────────────────┬───────────────────────────────────────────────────┘
                                        │ B1 分发/安装（网络可被替换、镜像可被劫持）
                                        ▼
┌────────────────────── T4 第三方模组包（数据不可信）────────────────────────────────────────┐
│ manifest.json（含 scripts 提案字段） · content/*.json · assets/* · scripts/*.lua           │
│ ModScanner(PathGuard + schema + 文件白名单) → ModManifest → DependencyResolver             │
│ → ContentCompiler → CrossReferenceValidator → RegistryHub.freeze_all()                     │
└───────────────────────────────────────┬───────────────────────────────────────────────────┘
                                        │ B2 校验后的声明值（JSON-like、路径已规范化）
                                        ▼
┌────────────────────── T2 宿主 Framework（可信）────────────────────────────────────────────┐
│ Script Host：CapabilityGuard · ApiRegistry · Scheduler · CommandQueue · ScriptStorage      │
│              · LuaVmAdapter · FaultMapper · Budget                                           │
│ 现状：全部缺失（GAP-01/06/07/08/09/10/11/12/14/17/19）                                       │
└──────┬───────────────────────────────┬────────────────────────────────────┬────────────────┘
       │ B3 值协议（只传 JSON-like）   │ B4 控制请求                          │ B5 存档状态
       ▼                               ▼                                      ▼
┌────────────────────┐     ┌────────────────────────────────────┐     ┌──────────────────────┐
│ T5 每模组 Lua VM   │     │ QueryBus（临时深拷贝）              │     │ SaveService           │
│ 仅 sn 代理 +       │     │ CommandBus（clone-and-commit）      │     │ SaveMigrations        │
│ 白名单库           │     │ DomainEventBus（公开事件适配）       │     │ script_states[mod_id] │
└────────────────────┘     └──────────────────┬─────────────────┘     └──────────┬───────────┘
                                              │ B6 唯一写路径                     │ B7 原子写
                                              ▼                                   ▼
                                   ┌─────────────────────┐              ┌──────────────────────┐
                                   │ T2 GameState（live）│              │ T6 user:// 存档/配置 │
                                   └─────────────────────┘              └──────────────────────┘
```

### 2.3 边界契约

| 边界 | 跨界内容 | **不可跨界内容** | 强制机制（现状 / 待建） |
| --- | --- | --- | --- |
| B1 分发→安装 | zip 包、导出产物、哈希清单 | 未签名/未校验的脚本、与清单不一致的包 | 现状：`pack_mod.gd` 固定 `mods/<id>/...`、`release.yml` 生成 SHA256SUMS；待建：签名/清单（GAP-21） |
| B2 包→扫描/校验 | manifest 字段、内容/本地化/资产字节 | 未规范化路径、`.lua` 以外脚本、可执行文件、`.gd/.dll/.pck/.tscn` | 现状：`path_guard.gd` 拒绝 `..`/绝对路径/反斜杠/NUL/盘符与危险扩展名；`mod_scanner.gd` 只允许 `.json`/本地化 `.csv`/`assets/` 白名单；待建：受控 `.lua` 通道（GAP-03/04） |
| B3 Host↔Lua 值协议 | `nil/boolean/number/string`、受约束 array/dict、稳定 ID | `Object/Node/Resource/Callable/RID/FileAccess/RefCounted` 引用、GDScript 实例、函数/线程/userdata、`Vector*`/`Transform*` 等引擎类型 | 待建：`ScriptValueCodec` + 返回 schema（GAP-06）；现状无桥接 |
| B4 Lua→Host 控制请求 | `sn.query/command/events/storage/random/log` 调用与参数 | 任意命令名字符串、Lua 函数当回调、其他模组的 `mod_id`、内部事件历史 | 待建：CapabilityGuard / ApiRegistry / Scheduler（GAP-06/07/08/09）；现状总线无调用者身份 |
| B5 Host→存档 | `script_states[mod_id]`（JSON-like、有版本、有配额） | 函数、VM 栈帧、userdata、其他模组命名空间、未知 schema | 现状：`SaveMigrations` 可迁移内容/状态版本；待建：脚本状态段与迁移（GAP-10） |
| B6 总线→GameState | 已授权、已校验、已入队并按序执行的命令 | 同步重入、未提交事务、绕过 CommandBus 的写 | 现状：`command_bus.gd` clone-and-commit + 成功才发布事件；待建：队列/预算/来源归因（GAP-07） |
| B7 SaveService→文件 | 完整 JSON payload + header | 未验证的 JSON、半写入文件、路径逃逸 | 现状：槽名正则、`.tmp` 复解析、`.bak` 回滚；`validate_mods()` 缺模组硬失败（但 checksum 漂移仅 warning） |

### 2.4 禁止跨界的值类型（硬清单）

以下类型**任何情况下都不得**从宿主进入 Lua，也不得从 Lua 回到宿主（上游 §2.1）：

- Godot 对象与引用：`Object`、`Node`、`Resource`、`RefCounted` 实例、`Callable`、`RID`、`FileAccess`、`DirAccess`、`SceneTree`、`PackedScene`；
- 引擎值类型：`Vector2/3/4`、`Transform2D/3D`、`Quaternion`、`Color`、`Rect*`、`Basis`、`Plane`、`AABB`——脚本需要坐标时由宿主转换为 number 字段或稳定 ID；
- 可执行/Lua 侧对象：`function`、`thread`（协程）、`userdata`、`lightuserdata`、完整 `_G`/`debug` 表、VM registry；
- 宿主内部结构：`GameState` 引用、`RegistryHub`、`DefinitionRegistry`、`CommandBus/QueryBus/DomainEventBus` 实例、`AppContext`、`StartupReport`；
- 敏感元数据：绝对路径、`res://`/`user://` 真实路径、宿主类名、GDScript 堆栈、其他模组的 manifest/checksum。

允许跨界的只有：`nil`、`boolean`、`number`、UTF-8 `string`、由上述标量构成的 array/dict、以及宿主定义的不可伪造稳定 ID（字符串）。**"allowlist 之外一律拒绝"是默认行为，不是可配置项**（S0 契约）。

### 2.5 边界失效模式（本文威胁的结构化来源）

| 失效模式 | 说明 | 对应威胁 |
| --- | --- | --- |
| 值协议混入对象 | 桥接为了"方便"直接传 Variant | TM-BR-01/02/03/05 |
| 运行时能力不足 | VM 无法中断/计数内存/关闭库 | TM-EXEC-01/02、TM-ISO-01 |
| 路径/模块解析信任字符串 | 宿主用拼接路径打开文件 | TM-ISO-02/03 |
| 版本/发布规则分叉 | SDK 与运行时两套规则 | TM-SUPPLY-01/02 |
| 状态所有权不清 | 脚本能碰 state 或存档 | TM-STATE-01/02 |
| 调度顺序不稳定 | 依赖 Dictionary 遍历或真实时间 | TM-SCHED-03、TM-PLATFORM-01/02/03 |
| 故障处理不完整 | 失败后继续收事件/残留队列 | TM-EXEC-06、TM-SCHED-04/05 |
| 输出未脱敏 | 日志/错误/查询带内部信息 | TM-BR-04、TM-LEAK-01/02/03 |

## 3. 威胁清单

### 3.0 汇总表

| ID | 威胁 | 严重度 | 阻断 | 主要不变量 |
| --- | --- | --- | --- | --- |
| TM-BR-01 | 桥接返回值/参数泄漏 Godot Object 或 userdata | 严重 | 是 | INV-01 |
| TM-BR-02 | Callable/回调句柄逃逸与跨批次重入 | 严重 | 是 | INV-02、INV-20 |
| TM-BR-03 | 每模组 Lua state 未隔离（共享全局/注册表） | 严重 | 是 | INV-03 |
| TM-BR-04 | 异常回溯与错误详情泄漏宿主路径/内部实现 | 中 | 否 | INV-04、INV-27 |
| TM-BR-05 | `sn` 代理对象元表/rawget 越权 | 高 | 否 | INV-05 |
| TM-ISO-01 | 危险标准库可达（io/os/debug/package.loadlib/FFI） | 严重 | 是 | INV-06 |
| TM-ISO-02 | 脚本/内容路径穿越与宿主任意文件访问 | 严重 | 是 | INV-07 |
| TM-ISO-03 | `require` 外部解析/包内模块白名单绕过 | 高 | 否 | INV-08 |
| TM-ISO-04 | Lua 字节码/预编译注入 | 高 | 否 | INV-09 |
| TM-ISO-05 | 全局环境/`_ENV`/upvalue/load 逃逸 | 高 | 否 | INV-05、INV-06 |
| TM-EXEC-01 | 无限循环/超长回调不可中断 | 严重 | 是 | INV-10 |
| TM-EXEC-02 | 内存轰炸/超长字符串/超大表 | 严重 | 是 | INV-11 |
| TM-EXEC-03 | 深递归/栈溢出导致宿主崩溃 | 严重 | 否 | INV-12 |
| TM-EXEC-04 | GC 压力与分配抖动 | 中 | 否 | INV-11 |
| TM-EXEC-05 | 预算绕过（pcall/协程/回调重入） | 高 | 否 | INV-10 |
| TM-EXEC-06 | 故障隔离失败/半初始化脚本继续收事件 | 严重 | 是 | INV-13 |
| TM-AUTH-01 | capability 声明即授权/动态提权 | 严重 | 是 | INV-14 |
| TM-AUTH-02 | 跨模组调用与 mod_id 身份伪造 | 高 | 否 | INV-14 |
| TM-AUTH-03 | 命令白名单绕过与参数伪造 | 高 | 否 | INV-15 |
| TM-AUTH-04 | 查询权限/字段裁剪绕过（未探索信息） | 高 | 否 | INV-16 |
| TM-AUTH-05 | storage 命名空间越权与配额缺失 | 高 | 否 | INV-17 |
| TM-SCHED-01 | 事件递归链/无限事件风暴 | 高 | 否 | INV-18 |
| TM-SCHED-02 | 命令风暴/批次预算绕过 | 高 | 否 | INV-18 |
| TM-SCHED-03 | 回调顺序不确定/跨模组重入 | 高 | 否 | INV-18 |
| TM-SCHED-04 | 回调异常回滚不完整/未提交请求泄漏 | 高 | 否 | INV-19 |
| TM-SCHED-05 | 卸载/重载后悬挂订阅与队列残留 | 高 | 否 | INV-20 |
| TM-STATE-01 | 绕过 CommandBus 直接污染 GameState | 高 | 否 | INV-21 |
| TM-STATE-02 | 跨模组存档命名空间越权 | 高 | 否 | INV-17、INV-22 |
| TM-STATE-03 | 脚本状态 Schema 迁移失败/半迁移 | 高 | 否 | INV-22 |
| TM-STATE-04 | 存档膨胀/存储资源耗尽 | 中 | 否 | INV-11、INV-17 |
| TM-STATE-05 | RNG 状态篡改/重放分歧 | 高 | 否 | INV-23 |
| TM-SUPPLY-01 | 脚本与内容/打包产物不一致 | 高 | 否 | INV-25 |
| TM-SUPPLY-02 | script_api_version 与 api_version 混淆 | 高 | 否 | INV-24 |
| TM-SUPPLY-03 | 无 Lua 运行时静默忽略脚本 | 高 | 否 | INV-24 |
| TM-SUPPLY-04 | 平台导出后 Lua 不可用/原生二进制供应链 | 高 | 否 | INV-25、INV-26 |
| TM-SUPPLY-05 | 发布完整性缺失（签名/哈希/包篡改） | 中 | 否 | INV-25 |
| TM-LEAK-01 | 查询返回内部字段/未探索信息 | 高 | 否 | INV-16 |
| TM-LEAK-02 | 日志泄露宿主路径/其他模组/玩家数据 | 中 | 否 | INV-27 |
| TM-LEAK-03 | 错误码侧信道与对象枚举 | 中 | 否 | INV-28 |
| TM-LEAK-04 | 时序/性能侧信道 | 低 | 否 | INV-23 |
| TM-PLATFORM-01 | Windows/Linux 路径、大小写、浮点、排序差异 | 高 | 否 | INV-26 |
| TM-PLATFORM-02 | 系统时钟/原生随机影响行为 | 高 | 否 | INV-23 |
| TM-PLATFORM-03 | 帧率/调度时机相关行为 | 中 | 否 | INV-18、INV-23 |
| TM-PLATFORM-04 | 导出产物 VM 缺失/ABI 架构差异 | 高 | 否 | INV-25、INV-26 |

统计：44 条；严重 10、高 26、中 7、低 1；发布阻断 9 条（与 §6.3 一致）。

### 3.1 TM-BR — 桥接与对象泄漏

#### TM-BR-01 桥接返回值/参数泄漏 Godot Object 或 userdata

- **类别**：桥接与对象泄漏（TM-BR）｜**严重度**：严重｜**发布阻断**：是（§14 第 2 条「原生桥接泄露 Godot 对象」；同时使 §11.1-3 失去意义）
- **攻击者能力前提**：脚本作者控制查询参数与对返回值的读取；桥接实现存在"原样透传 Variant"的路径，或某个 API 返回 `Object`/`Resource`。
- **攻击路径**：调用 `sn.query()` 拿到一个 Godot 对象（例如未来某查询把 `Ship` 实例塞进 ViewModel），在 Lua 侧调用其方法或持有引用；或事件 payload 携带 `Node`；或 `sn.command()` 参数被宿主直接转成 Variant 交给 handler。
- **影响**：绕过 `CommandBus` 的 clone-and-commit 直接修改 live `GameState`（`framework/application/command_bus.gd:42-57`），读取/调用任意 GDScript 方法，沙箱整体失效；可进一步篡改存档、读取文件、执行引擎能力。
- **可能性**：中高（实现期最常见、最容易被"为了性能"放行）。
- **S0 契约**：`LUA_MODDING_SDK.md` §2.1 的值类型白名单升级为**穷尽式 allowlist**：只允许 `nil/boolean/number/string` 与受约束 array/dict；任何 API 的返回值必须在 API Registry 中声明返回 schema；"未知类型＝拒绝"，不允许 fallback 透传。错误码固定 `script.value_not_serializable`。
- **S1 PoC 证据**：PoC 必须构造一个"故意返回 `Object`"的测试 API，观测宿主返回 `script.value_not_serializable` 而不是把对象交给 Lua；在 Lua 侧断言 `type(v)` 只可能是 `nil/boolean/number/string/table`；对任意返回值调用 `getmetatable` 不得得到宿主元表。
- **S2 运行时实现**：新增 `framework/scripting/script_value_codec.gd`（当前缺失，GAP-06），对所有跨界值做递归白名单转换与深度/大小限制；"出方向"在 API handler 返回后强制过 codec，"入方向"在参数进入 handler 前强制过 codec；桥接层不提供任何 `Variant` 直通分支；API Registry 注册时校验返回 schema 声明齐全。
- **残余风险**：宿主 API 实现者未来新增字段时可能误塞对象；需 API Registry 的 schema 覆盖测试与代码审计持续兜底。
- **观测点**：`OBS-BR-01` — 故意返回 `Object/Resource/Node/Callable` 的测试 API 必须返回稳定错误，进程不崩溃，`GameState.hash()`（`framework/state/game_state.gd:130-134`）不变。

#### TM-BR-02 Callable/回调句柄逃逸与跨批次重入

- **类别**：桥接与对象泄漏（TM-BR）｜**严重度**：严重｜**发布阻断**：是（§14 第 2 条；`Callable` 属于被 §2.1 明令禁止的宿主对象，且 §11.1-1 要求 state 销毁后不再被调用）
- **攻击者能力前提**：宿主把 Lua function 包装成 `Callable` 交给调度器/信号系统，或把订阅 token 暴露为可伪造的整数/字符串；或脚本可保存回调并在任意时刻触发。
- **攻击路径**：`sn.events.on()` 后宿主持有 `Callable`，在事件批次之外（如 UI 更新、存档加载、VM 已经 dispose 之后）仍被调用；脚本通过重复注册/不注销制造悬挂回调；脚本把回调传给另一个模组。
- **影响**：宿主异常/崩溃；在错误生命周期执行代码（例如存档恢复期间）；跨模组回调注入；与 TM-EXEC-06 叠加形成"半初始化脚本继续收事件"。
- **可能性**：中。
- **S0 契约**：回调**只以不可伪造句柄**存在：宿主内部持有 `(mod_id, subscription_id, state_generation)`，Lua 侧只拿到 token；任何第三方 API 不接收/不返回 `Callable`；回调只在 Scheduler 的批次内执行；state 销毁即令 token 失效（错误码 `script.callback_stale`）。
- **S1 PoC 证据**：PoC 注册回调后销毁 state，再触发事件，观测"无回调执行、无宿主错误、无日志崩溃"；尝试把回调 token 传给另一个模组的方法必须被拒绝；尝试在事件回调外直接调用宿主回调 API 必须不存在。
- **S2 运行时实现**：`framework/scripting/script_scheduler.gd` 持有订阅表；`script_host.gd` 在 VM dispose 时清空订阅与待执行队列；`LuaVmAdapter` 不向 GDScript 暴露 Lua function；所有回调执行统一经 scheduler 的 `dispatch_event()`。
- **残余风险**：Godot 信号系统或 UI 层可能绕过 scheduler 直接 `emit`；需代码审计禁止脚本回调接入 `signal`。
- **观测点**：`OBS-BR-02` — 销毁后触发事件：0 次回调、0 条 `script.callback_stale` 以外的宿主错误；重载后同一订阅只执行一次。

#### TM-BR-03 每模组 Lua state 未隔离（共享全局/注册表）

- **类别**：桥接与对象泄漏（TM-BR）｜**严重度**：严重｜**发布阻断**：是（§11.1-1 独立 state 可创建/执行/销毁；§6.1「无跨模组共享可变全局状态」）
- **攻击者能力前提**：实现为了省内存/省启动时间共用 state，或把 `_G`/registry/模块缓存跨模组共享；或"宿主 API 表"是同一个 table 实例。
- **攻击路径**：模组 A 写 `_G.shared = ...`，模组 B 读取；A 修改 `sn` 表/metatable 影响 B；A 通过 `package.loaded` 注入 B 的模块；A 留下全局状态让 B 的行为改变。
- **影响**：跨模组干扰、权限提升、确定性破坏；§11.1-1 直接失败；与 TM-AUTH-02/STATE-02 叠加。
- **可能性**：低（设计上已要求独立，但实现偷懒风险真实）。
- **S0 契约**：§6.1 写死"每模组独立 Lua state/环境"；禁止共享 registry、`package.loaded`、全局表；宿主 API 以**每 state 独立构建的只读代理**注册；每个 state 的创建/销毁由 ScriptHost 记账。
- **S1 PoC 证据**：同时加载 A/B 两个模组，A 写全局、覆盖 `sn`、注入模块缓存，B 均不可见；销毁 A 后 B 继续正常；观测 `active_script_state_count == active_script_mod_count`。
- **S2 运行时实现**：`lua_vm_adapter.gd` 每模组一个 VM 实例（GAP-06/19）；`script_host.gd` 维护 state 生命周期；禁止任何跨 state 的 table 引用；模块缓存按 state 隔离（若开放 `require`，见 TM-ISO-03）。
- **残余风险**：VM 实现内部若共享全局 registry（如同进程单例），需 S1 证据排除；VM 选型报告必须给出该证据（`T-OQ-01`）。
- **观测点**：`OBS-BR-03` — 两个模组互相写全局后读取不到；`state_count` 与已启用脚本模组数一致；销毁一个 state 不影响另一个的事件处理。

#### TM-BR-04 异常回溯与错误详情泄漏宿主路径/内部实现

- **类别**：桥接与对象泄漏（TM-BR）｜**严重度**：中｜**发布阻断**：否（§11.1 未列；S2 发布前必须闭合）
- **攻击者能力前提**：脚本能读取宿主返回的错误对象/日志，或错误被展示给玩家；宿主把 Lua traceback、GDScript 栈、绝对路径直接拼接。
- **攻击路径**：脚本故意触发错误（如调用不存在的 API、传非法参数），读取 `result.error.message/details` 或 `sn.log` 输出；宿主把 `res://`、`user://`、`OS.get_executable_path()`、内部类名写进错误。
- **影响**：泄露安装路径、用户名、存档路径、内部 API 名称与调用栈，为后续越权/供应链攻击提供情报。
- **可能性**：高（实现期容易直接 `str(exception)`）。
- **S0 契约**：错误对象固定为 `{code, message_key, details?}`；`code` 是稳定枚举；`message_key` 走本地化（与上游 §4.2 "本地化文本与机器错误码分离"一致）；`details` 只允许白名单字段；宿主堆栈只进宿主诊断日志且带模组归属，**不进 API 返回、不进玩家可见 UI**。
- **S1 PoC 证据**：PoC 触发 Lua error 与非法参数，检查所有返回/日志不含 `res://`、`user://`、盘符、用户名、`GDScript` 字样；玩家可见文案来自本地化表。
- **S2 运行时实现**：`script_fault_mapper.gd`（新，GAP-14）把 VM 异常映射为 `script.runtime_error/script.budget_exceeded/...`；`AppLogger` 增加脚本专用脱敏通道；错误对象构造点唯一。
- **残余风险**：Godot 自身在某些错误下会打印引擎路径；需在导出构建验证日志不落玩家可见文件。
- **观测点**：`OBS-BR-04` — 错误 JSON 不含绝对路径/内部类名；日志扫描无 `res://`/`user://` 泄露；玩家 UI 只显示本地化文本。

#### TM-BR-05 `sn` 代理对象元表/rawget 越权

- **类别**：桥接与对象泄漏（TM-BR）｜**严重度**：高｜**发布阻断**：否（若是 TM-AUTH-01 的实现路径则随其升级）
- **攻击者能力前提**：`sn` 用普通 table + metatable 实现，`__index` 可被 `getmetatable`/`rawget` 访问，或 `__metatable` 未锁定。
- **攻击路径**：`getmetatable(sn)` 取得代理表；`rawset(sn, "query", ...)` 改写；`sn.__index.__call` 或 `setmetatable` 把未授权函数接到 `sn`；通过 `pairs(sn)` 枚举未公开 API 名。
- **影响**：绕过 CapabilityGuard 与字段裁剪，枚举隐藏 API；与 TM-AUTH-01 叠加形成越权。
- **可能性**：中。
- **S0 契约**：`sn` 是**冻结的只读代理**：`__metatable` 锁定（`getmetatable` 返回固定字符串或 nil）、不暴露 `setmetatable/rawset/rawget`、API 名在 state 创建时确定且不可增删；每次调用仍由宿主授权，不信任 Lua 侧缓存。
- **S1 PoC 证据**：PoC 断言 `getmetatable(sn)` 不可用于取得内部表；`rawset(sn, ...)` 失败；`pairs(sn)` 只能看到公开 API 名；替换 `sn.query` 不改变宿主行为。
- **S2 运行时实现**：`lua_vm_adapter.gd` 构建受保护代理；或使用宿主侧 userdata/metatable 技巧（取决于 VM 能力）；CapabilityGuard 在调用点独立校验，不依赖代理表的写法。
- **残余风险**：Lua 版本差异导致 `__metatable` 语义不同；S1 报告必须记录所用 VM 的行为。
- **观测点**：`OBS-BR-05` — 未公开 API 名不出现在 `pairs(sn)`；篡改代理后宿主仍按原 authorization 表判定。

### 3.2 TM-ISO — 沙箱隔离

#### TM-ISO-01 危险标准库可达（io/os/debug/package.loadlib/FFI）

- **类别**：沙箱隔离（TM-ISO）｜**严重度**：严重｜**发布阻断**：是（§11.1-3「OS/IO/原生模块不可达」；§6.1 硬约束）
- **攻击者能力前提**：VM 初始化时加载全部标准库，或宿主额外暴露 `require/package/loadlib/ffi`；或某平台构建默认带上这些库。
- **攻击路径**：脚本调用 `io.open`/`os.execute`/`os.remove`/`os.getenv`/`debug.getregistry`/`package.loadlib` 读写文件、执行命令、加载原生库；通过 `debug` 修改沙箱表。
- **影响**：完全逃逸沙箱，可读写本机文件、执行命令、加载任意原生代码；§11.1-3 直接失败，第三方脚本发行必须停止。
- **可能性**：中（取决于 VM 默认行为与实现者是否"顺手打开"）。
- **S0 契约**：§6.1 写死"关闭或不绑定 `io`、`os`、`debug`、`package.loadlib`、`require` 外部解析、FFI 和原生调用"；能力表中**不存在** file/network/os/native capability；启动时使用**显式白名单库集合**（例如仅 base/table/string/math/utf8 的安全子集），而不是"默认全开再删"。
- **S1 PoC 证据**：PoC 在 Windows 与 Linux 上逐个断言 `io/os/debug/package/ffi` 相关符号不可达（`nil` 或调用返回 `script.library_unavailable`）；`debug.getregistry` 不存在；`package.loadlib` 不存在；无 `require`（或仅包内白名单，见 TM-ISO-03）。
- **S2 运行时实现**：`lua_vm_adapter.gd` 暴露白名单库；`script_host.gd` 启动时执行库探测并写入 `StartupReport`；CI 增加"危险符号不可达"套件与目标平台导出验证。
- **残余风险**：VM 升级可能重新引入库或改变默认；需固定 VM 版本并在构建时做符号扫描（`T-OQ-01`）。
- **观测点**：`OBS-ISO-01` — 危险符号探针全部失败，错误码稳定；宿主进程存活；`GameState.hash()` 不变。

#### TM-ISO-02 脚本/内容路径穿越与宿主任意文件访问

- **类别**：沙箱隔离（TM-ISO）｜**严重度**：严重｜**发布阻断**：是（§11.1-3「文件访问阻止」；§3「所有脚本路径必须规范化并限定在模组根内」）
- **攻击者能力前提**：`scripts.entry`、模块名、content/asset 引用由 manifest 或脚本提供；宿主用字符串拼接 + `FileAccess` 打开。
- **攻击路径**：`scripts.entry: "../../config/config.json"` 或 `scripts/../../user/saves/...`；zip entry 含 `../`；Windows 盘符/UNC/反斜杠；Linux 符号链接；大小写差异绕过；路径别名（`res://`、`user://`）。
- **影响**：宿主读取任意本地文件（配置、存档、系统文件），或把包外文件当脚本执行；导出包中可越界读取；与 TM-ISO-01 叠加。
- **可能性**：中高（路径拼接是最常见的实现错误）。
- **S0 契约**：§3 路径硬规则：规范化（reject `..`、绝对路径、`://`、反斜杠、NUL、盘符）并限制在模组根；新增脚本扩展名白名单（`.lua`）与 `scripts/` 根约束；`entry` 必须位于 `scripts/` 下；禁止从 manifest 直接接受任意路径打开文件。
- **S1 PoC 证据**：PoC 使用恶意 manifest（`../`、绝对路径、盘符、反斜杠、空段、超长）断言 `invalid_script_path`；zip 内 `..` entry 断言 `unsafe_path`；在 Windows/Linux 各跑一遍。
- **S2 运行时实现**：`ModManifest` 新增 `scripts` 解析（GAP-02）；复用 `PathGuard.is_safe_relative`（`framework/core/path_guard.gd:21-36`）并新增 `is_allowed_script`；`ModScanner` 增加 `.lua` 受控白名单（GAP-03）；ScriptHost 只接受已解析的 `ModSource` 句柄，不把路径字符串交给 Lua。
- **残余风险**：Godot `res://`/`user://` 虚拟路径与 OS 路径映射在导出构建中可能不同；需双平台导出测试。
- **观测点**：`OBS-ISO-02` — 路径穿越 payload 全部返回 `invalid_script_path`/`unsafe_path`；无文件读取副作用；打包门禁同样拒绝。

#### TM-ISO-03 `require` 外部解析/包内模块白名单绕过

- **类别**：沙箱隔离（TM-ISO）｜**严重度**：高｜**发布阻断**：否（若 VM 无法关闭 `require`，按 §11.1-3 升级为阻断）
- **攻击者能力前提**：宿主开放 `require`，且 `package.path`/`package.cpath` 可配；或包内模块加载未限制。
- **攻击路径**：`require("socket")` 加载系统 Lua 库；`package.path` 指向宿主目录；同名模块覆盖；模块缓存跨模组共享；通过模块的 `upvalue` 共享宿主表。
- **影响**：加载外部 Lua/原生模块、跨模组代码注入、绕过沙箱白名单。
- **可能性**：中。
- **S0 契约**：§6.1 默认**不开放 `require`**；若未来开放，只允许模组包内白名单 Lua 模块，由宿主解析相对路径 + 模块清单，模块间不共享 upvalue；`package.path/cpath` 不可修改，`package.loadlib` 不存在（与 TM-ISO-01 一致）。
- **S1 PoC 证据**：PoC 断言默认 `require == nil`；若启用白名单模式，越界模块名返回 `script.module_denied`，篡改 `package.path` 无效，模块缓存不跨模组。
- **S2 运行时实现**：`LuaVmAdapter` 的模块加载器按 state 隔离；`ScriptHost` 维护包内模块清单；禁止任何 `package.*` 写操作。
- **残余风险**：模块加载器本身是 C 代码，需 VM 级证据；若使用 VM 内建 `require`，必须锁定版本并做逃逸测试。
- **观测点**：`OBS-ISO-03` — 外部模块名/路径被拒绝；同包白名单模块可加载；A 的模块对 B 不可见。

#### TM-ISO-04 Lua 字节码/预编译注入

- **类别**：沙箱隔离（TM-ISO）｜**严重度**：高｜**发布阻断**：否（默认只接受源码；若发布包接受 bytecode 则重估为阻断）
- **攻击者能力前提**：VM 接受二进制 chunk（`load`/`loadstring` 的二进制模式），或打包允许 `.luac`。
- **攻击路径**：提交构造的 bytecode 绕过源码静态检查、隐藏逻辑、触发 VM 解析/内存安全问题；`string.dump` 导出函数再加载；发布包内混入 `.luac`。
- **影响**：绕过 S0/S1 的源码审查与发布门禁；不可审计；VM 内存安全风险。
- **可能性**：低到中（取决于 VM 与加载策略）。
- **S0 契约**：发布包只接受 UTF-8 源码 `.lua`；禁止 `.luac` 与二进制 chunk；若暴露 `load`，只接受 string 且限制为文本模式；`string.dump` 禁用。
- **S1 PoC 证据**：PoC 提交 bytecode 断言 `script.bytecode_denied`；`string.dump` 不可用；`load` 只能在宿主包装下、文本模式使用；发布打包拒绝 `.luac`。
- **S2 运行时实现**：`ModScanner` 扩展名白名单不含 `.luac`（GAP-03）；`LuaVmAdapter` 以 text-only 模式加载；`pack_mod.gd` 增加脚本文件扩展名门禁（GAP-15/16）。
- **残余风险**：VM 可能内部把源码编译成 bytecode 缓存；需确保缓存不落盘、不复用外部文件。
- **观测点**：`OBS-ISO-04` — `.luac`/二进制 chunk 在扫描、加载、打包三处都被拒绝。

#### TM-ISO-05 全局环境/`_ENV`/upvalue/load 逃逸

- **类别**：沙箱隔离（TM-ISO）｜**严重度**：高｜**发布阻断**：否（与 TM-ISO-01 共享证据；若逃逸成功则升级）
- **攻击者能力前提**：全局环境暴露、`setfenv/getfenv` 可用、`load` 可执行任意 chunk、`string.dump` 可用。
- **攻击路径**：替换 `_ENV` 或 `getfenv` 取回被删的库；用 `load("return io")` 恢复危险能力；通过 `debug.upvaluejoin` 改写 closures；通过 `string.dump` + `load` 绕过源码检查。
- **影响**：恢复被禁库、绕过 capability 代理、逃逸沙箱。
- **可能性**：中（Lua 5.1/5.2+ 语义不同，易漏）。
- **S0 契约**：全局环境只读；不提供 `setfenv/getfenv/debug`；`load` 禁用或只接受宿主包装的受控 chunk；`string.dump` 禁用；脚本只能看到 `sn` 与安全标准库。
- **S1 PoC 证据**：PoC 断言 `_ENV` 修改无效、`getfenv/setfenv` 不存在、`string.dump` 不存在；用 `load` 构造的常见逃逸 payload 全部失败。
- **S2 运行时实现**：`LuaVmAdapter` 构建最小全局表；针对所选 VM 版本的逃逸用例集；双版本（如支持）行为记录。
- **残余风险**：VM 版本差异与未公开 API；需持续维护逃逸用例库。
- **观测点**：`OBS-ISO-05` — 逃逸 payload 全部失败且返回稳定错误；无库恢复。

### 3.3 TM-EXEC — 执行预算 DoS

#### TM-EXEC-01 无限循环/超长回调不可中断

- **类别**：执行预算 DoS（TM-EXEC）｜**严重度**：严重｜**发布阻断**：是（§11.1-3「无限循环可可靠中断」；§14 第 1 条「Lua 插件没有可靠执行中断」）
- **攻击者能力前提**：VM 没有指令计数/中断钩子，宿主只能靠墙钟超时或 `OS.kill`；或脚本用 `pcall`/协程规避最外层超时。
- **攻击路径**：`while true do end`；超长循环；在循环里调用宿主 API 保持"活着的调用"；用 `pcall` 吞掉中断错误；协程里无限执行。
- **影响**：主线程永久冻结、游戏无响应、无法自动恢复；上游 §14 明确该风险为**阻断**，PoC 不晋级正式第三方脚本功能。
- **可能性**：高（恶意或 bug 都极易触发）。
- **S0 契约**：§6.1 要求"VM 指令预算或可靠中断机制"；**墙钟超时不能替代真正中断**；预算值在 S1 基准测试后写入配置，不在本文写死为承诺；超限行为固定为"中断回调 → 撤销该回调未提交请求 → 记稳定错误码 `script.budget_exceeded`"。
- **S1 PoC 证据**：PoC 注入 `while true do end`，必须在预算上限内返回 `script.budget_exceeded`，**进程保持存活**，随后其他模组/回调仍能执行；Windows/Linux 各验证一次；协程与 `pcall` 变体同样被中断。
- **S2 运行时实现**：`lua_vm_adapter.gd` 提供 count hook 或等价可中断机制；`script_scheduler.gd` 每次回调设置预算并捕获中断；`script_host.gd` 在超限后按策略 Faulted/Disabled（GAP-06/13/19）。
- **残余风险**：中断只在 VM 的 hook 点生效，C 函数或极长单条指令仍可能拖延；需选择支持可靠中断的 VM 并记录最坏延迟（`T-OQ-02`）。
- **观测点**：`OBS-EXEC-01` — 无限循环在可测时间内返回 `script.budget_exceeded`；宿主存活；后续事件照常；无 `kill`/超时兜底生效。

#### TM-EXEC-02 内存轰炸/超长字符串/超大表

- **类别**：执行预算 DoS（TM-EXEC）｜**严重度**：严重｜**发布阻断**：是（§11.1-3「内存上限可验证」；§6.1「可计量的分配器/上限」）
- **攻击者能力前提**：VM 无分配器计量/上限，或上限不可观测；宿主侧序列化入口无大小上限。
- **攻击路径**：`string.rep("x", 1e9)`；构造超大 table；闭包/元表链持有大量对象；通过宿主 API 反复放大返回值；把超大表作为命令参数传入。
- **影响**：OOM 崩溃、长时间 GC 停顿、影响 Core 与其他模组；§11.1-3 无法验证。
- **可能性**：中高。
- **S0 契约**：§6.3 总 VM 内存上限 + 可计量分配器；对字符串/表/参数/存储值设大小上限；超限返回 `script.memory_exceeded` 且不写入任何状态。
- **S1 PoC 证据**：PoC 分配超过上限时稳定返回 `script.memory_exceeded`，宿主不崩溃；记录峰值内存与上限；Windows/Linux 各一次；同时验证宿主侧输入参数超限被拒。
- **S2 运行时实现**：`LuaVmAdapter` 配置分配器上限；`ScriptValueCodec` 对入/出值做字节数、深度、数组长度限制；`ScriptStorage` 对值大小限制（GAP-06/19）。
- **残余风险**：VM 内部分配（如 C 栈）可能不受 Lua 分配器统计；S1 报告需区分"可计量内存"与"进程 RSS"。
- **观测点**：`OBS-EXEC-02` — 超限分配返回 `script.memory_exceeded`；进程 RSS 峰值可控；`GameState` 未变。

#### TM-EXEC-03 深递归/栈溢出导致宿主崩溃

- **类别**：执行预算 DoS（TM-EXEC）｜**严重度**：严重｜**发布阻断**：否（若深度上限不能阻止崩溃则按 §11.1-4 升级为阻断）
- **攻击者能力前提**：VM 递归深度无上限；宿主参数/返回值递归无上限；Lua 尾调用/元表递归可突破简单计数。
- **攻击路径**：无限递归、互相递归、`__index` 递归、深嵌套表参数；宿主递归序列化深表导致 GDScript 栈溢出。
- **影响**：进程崩溃（可能无法被 `pcall` 捕获），玩家进度丢失。
- **可能性**：中。
- **S0 契约**：VM 递归深度上限 + 宿主侧参数/返回值深度上限；超限返回稳定错误（`script.stack_overflow` / `script.payload_depth`）；宿主侧序列化必须迭代或带深度检查。
- **S1 PoC 证据**：PoC 递归到上限返回受控错误，宿主存活；深嵌套参数被拒；元表递归同样被限制。
- **S2 运行时实现**：`LuaVmAdapter` 设置 max stack；`ScriptValueCodec` 深度上限；`GameState` 无关（脚本不直接序列化 state）。
- **残余风险**：GDScript 自身递归限制与 Lua 不同；需双平台验证。
- **观测点**：`OBS-EXEC-03` — 深递归/深参数返回受控错误，无进程崩溃。

#### TM-EXEC-04 GC 压力与分配抖动

- **类别**：执行预算 DoS（TM-EXEC）｜**严重度**：中｜**发布阻断**：否
- **攻击者能力前提**：脚本在每次事件中大量分配短命对象/拼接字符串，制造 GC 停顿。
- **攻击路径**：每个事件创建大临时表；循环字符串拼接；频繁闭包分配；触发宿主 GC 与 Lua GC 叠加。
- **影响**：帧时间尖峰、卡顿，影响 Core 与其他模组体验；不必然崩溃。
- **可能性**：中（bug 模组常见）。
- **S0 契约**：指令/分配预算覆盖单回调；S1 基准给出"单回调 GC 时间"上限；超预算按 `script.budget_exceeded` 中断。
- **S1 PoC 证据**：PoC 压测记录单回调 GC 时间与预算关系；超预算回调被中断；不同帧率下无累积抖动。
- **S2 运行时实现**：`ScriptScheduler` 的分配速率/总预算；性能回归测试纳入 CI；必要时限频回调（不提供任意 `on_tick`）。
- **残余风险**：GC 行为依赖 VM 实现；只能约束上界，不能完全消除抖动。
- **观测点**：`OBS-EXEC-04` — 压测下帧时间峰值可测且不超过预算；超限被中断并记录。

#### TM-EXEC-05 预算绕过（pcall/协程/回调重入）

- **类别**：执行预算 DoS（TM-EXEC）｜**严重度**：高｜**发布阻断**：否（若绕过成功则按 §11.1-3 升级为阻断）
- **攻击者能力前提**：预算只包最外层调用；中断错误可被 `pcall` 吞掉；协程让出后预算重置；回调内注册新回调/提交新命令绕过批次预算。
- **攻击路径**：`while true do pcall(function() ... end) end`；`coroutine.resume` 无限调度；回调内 `sn.events.on` 再注册；利用宿主回调再次进入 Lua。
- **影响**：中断失效、预算计数不累计、DoS 与递归事件；与 TM-SCHED-01/02 叠加。
- **可能性**：中。
- **S0 契约**：预算按 **VM/回调累计**，不因 `pcall` 重置；协程首版**禁用**或纳入同一预算；回调注册/命令提交在批次末生效，不能在当前批次内扩展预算；中断后不得残留可执行协程。
- **S1 PoC 证据**：PoC 验证 `pcall`、协程、回调内注册都不能绕过；中断后无残留执行；连续多轮回调累计计数。
- **S2 运行时实现**：`LuaVmAdapter` 在 hook 层计数（不受 Lua 控制流影响）；`ScriptScheduler` 延迟注册与队列；协程 API 默认不暴露。
- **残余风险**：VM hook 在 `pcall` 下的行为需实测；不同 VM 语义不同。
- **观测点**：`OBS-EXEC-05` — 上述绕过 payload 均返回 `script.budget_exceeded` 或 `script.coroutine_denied`，无残留执行。

#### TM-EXEC-06 故障隔离失败/半初始化脚本继续收事件

- **类别**：执行预算 DoS（TM-EXEC）｜**严重度**：严重｜**发布阻断**：是（§11.1-4「连续失败可禁用对应脚本，不影响 Core/GameState」；§5 失败原则）
- **攻击者能力前提**：脚本 `on_load` 失败后仍注册订阅/API；单次超限只记日志不禁用；宿主异常导致整个批次中断；重载不清理失败状态。
- **攻击路径**：故意在 `on_load` 中半初始化并抛错；回调反复超时/报错；利用宿主异常让其他模组回调也中断；通过反复失败触发错误风暴。
- **影响**：脚本永久处于半可用状态、错误风暴、卡顿；可能连带影响 Core/其他模组；§11.1-4 直接失败。
- **可能性**：中。
- **S0 契约**：§5 失败原则写成硬契约：初始化失败禁用对应脚本能力并记录错误，**不允许半初始化脚本继续接收事件**；单回调超限中断+记错+撤销未提交请求；连续错误达到阈值自动 Disabled；不允许静默成功；错误级别与 `required` 模组的启动策略由现有严重度模型扩展。
- **S1 PoC 证据**：PoC 连续失败 N 次后脚本进入 Disabled，Core 与 `GameState.hash()` 不变，其他模组继续工作；恢复需要重新加载；`StartupReport` 记录脚本状态与稳定错误码。
- **S2 运行时实现**：`script_host.gd` 状态机 `Initialized/Active/Faulted/Disabled/Unloaded`；失败计数与阈值；`ModLoader` 增加脚本阶段并在 report 中记录（GAP-17/22）；宿主异常在批次边界捕获。
- **残余风险**：错误阈值策略可能误伤慢脚本；需配置化并可观测。
- **观测点**：`OBS-EXEC-06` — 失败脚本被禁用；其余模组与 Core 状态哈希不变；无事件继续投递到该脚本。

### 3.4 TM-AUTH — 权限与越权

#### TM-AUTH-01 capability 声明即授权/动态提权

- **类别**：权限与越权（TM-AUTH）｜**严重度**：严重｜**发布阻断**：是（§11.1-2「提交一个**允许的**命令请求」；§6.2「能力声明不等于权限执行；每一次 Lua → Host 调用都需要宿主侧授权」；§16 第一条）
- **攻击者能力前提**：宿主把 manifest `capabilities` 当作最终授权；或只在初始化时检查一次；或信任 `sn.mod.info()` 返回的能力快照；或脚本可修改自身能力集合。
- **攻击路径**：未声明 `script.command.*` 的模组调用命令；声明 `script.query.ship` 后查询其他域；脚本修改 `sn.capabilities` 表；先声明低权限再调用高权限 API。
- **影响**：越权改状态/读数据、最小权限模型失效、沙箱名存实亡。
- **可能性**：中（"声明即授权"是常见设计错误）。
- **S0 契约**：§6.2 写死：能力集合默认空；**每次 Lua→Host 调用宿主侧授权**；不允许动态扩大权限；manifest 声明只用于加载期预检与用户展示；授权判定与 API Registry 的 `required_capability` 绑定；错误码 `script.permission_denied`，且**拒绝时不得产生任何副作用**。
- **S1 PoC 证据**：PoC 使用未声明能力的模组调用命令/查询，观测 `script.permission_denied` 且 `GameState.hash()` 不变；声明后调用成功；脚本尝试修改自身能力表无效。
- **S2 运行时实现**：`script_capability_guard.gd` 在每次调用点校验；`script_api_registry.gd` 为每个 API 登记 capability 与参数 schema；授权结果不缓存到 Lua 侧；审计日志记录拒绝（GAP-06）。
- **残余风险**：新 API 忘记登记 capability 会默认放行或默认拒绝；必须默认拒绝并加注册校验测试。
- **观测点**：`OBS-AUTH-01` — 未授权调用被拒且状态哈希不变；拒绝日志含 `mod_id/capability/api`；修改能力表无效。

#### TM-AUTH-02 跨模组调用与 mod_id 身份伪造

- **类别**：权限与越权（TM-AUTH）｜**严重度**：高｜**发布阻断**：否（S2 发布前必须闭合；若与 AUTH-01 叠加则升级）
- **攻击者能力前提**：宿主用脚本参数里的 `mod_id` 做授权/存储；或允许 A 调用 B 的脚本 API/回调；或 `sn.mod.info()` 可伪造。
- **攻击路径**：A 传 `mod_id="core"` 或 B 的 id；A 读取 B 的 storage；A 触发 B 的回调；A 伪造事件 `source`。
- **影响**：跨模组干扰、权限提升、存档污染；§8「不允许脚本直接修改其他模组的存储空间」。
- **可能性**：中。
- **S0 契约**：脚本身份由宿主在 VM 创建时绑定，**不可由脚本提供**；首版**禁止跨模组调用**（无显式双向 capability 就不开放）；`sn.mod.info()` 返回宿主注入的只读快照；事件 `source` 由宿主填写。
- **S1 PoC 证据**：PoC 伪造 `mod_id` 失败（`script.identity_mismatch`）；A 读 B storage 返回 denied；A 无法触发 B 的回调；B 的脚本状态不被 A 修改。
- **S2 运行时实现**：`ScriptHost` 每 state 携带不可变 `mod_id` 闭包；所有 API 不接受 `mod_id` 参数；`ScriptStorage` 强制使用宿主绑定身份（GAP-06/10）。
- **残余风险**：未来若开放模组间 API，需要独立信任模型；届时重开威胁。
- **观测点**：`OBS-AUTH-02` — 身份伪造/跨模组访问全部被拒；B 的存储哈希不变。

#### TM-AUTH-03 命令白名单绕过与参数伪造

- **类别**：权限与越权（TM-AUTH）｜**严重度**：高｜**发布阻断**：否（若白名单缺失则等同 TM-AUTH-01 阻断）
- **攻击者能力前提**：宿主转发任意字符串命令名；参数未按 schema 校验；脚本可设置 `autosave/source` 等宿主字段；未知命令落到 bus 的 `unknown_command` 之外。
- **攻击路径**：调用未公开/内部命令（如 `run.start`、`fleet.add_ship`）；传超大/深嵌套/额外字段参数；伪造 `reason`/`autosave`；利用类型混淆让 handler 误判。
- **影响**：越权改变游戏状态、强制自动存档、DoS、绕过业务校验。
- **可能性**：中高。
- **S0 契约**：§2.2 显式白名单转发；每个脚本命令有参数 schema（字段白名单、类型、范围、长度、深度）；脚本不能设置 `autosave/source/events`；拒绝未知字段；错误码 `script.command_rejected` / `script.invalid_args`；命令仍是"入队回执"，不同步返回业务成功（上游 §4.2）。
- **S1 PoC 证据**：PoC 未知命令返回 denied；额外字段/超限参数返回 invalid；被拒命令不产生领域事件、不改变状态；允许命令只返回入队回执。
- **S2 运行时实现**：`script_api_registry.gd` 维护命令 allowlist + 参数 schema；`script_scheduler.gd` 入队前校验；`CommandBus` 增加来源参数（当前 `command_bus.gd:53` 固定 `source="framework"`，需扩展，GAP-07）。
- **残余风险**：业务 handler 自身参数校验不足；脚本 API 必须做独立校验而不能只依赖 handler。
- **观测点**：`OBS-AUTH-03` — 白名单外命令/非法参数被拒；无事件、state 哈希不变；回执明确 `queued:true`。

#### TM-AUTH-04 查询权限/字段裁剪绕过（未探索信息）

- **类别**：权限与越权（TM-AUTH）｜**严重度**：高｜**发布阻断**：否（S2 发布前必须闭合；玩法公平性）
- **攻击者能力前提**：QueryBus 的现有 ViewModel 直接给脚本；脚本可猜 query 名或传任意参数；字段裁剪缺失。
- **攻击路径**：调用 `map.view`/`sea_chart.view` 获取全图与未探索区域；尝试内部 query 名；通过参数变化推断隐藏对象；读取其他模组不应见的运行数据。
- **影响**：透视/跳过探索、玩法破坏、信息泄露；与 TM-LEAK-01 叠加。
- **可能性**：中。
- **S0 契约**：脚本查询只暴露**登记过的脚本 API 子集**，与 UI 查询解耦；每个查询定义公开字段白名单与参数 schema；探索/迷雾规则在裁剪层执行；不暴露内部 registry 结构；未登记 query 一律 denied。
- **S1 PoC 证据**：PoC 断言脚本可见字段集合与公开契约一致；未探索坐标/隐藏字段不出现；内部 query 名调用失败；不同参数不能区分未探索对象。
- **S2 运行时实现**：`script_query_adapter.gd`（新，GAP-08）建立在 `QueryBus` 深拷贝之上（`query_bus.gd:38-41`）；字段裁剪 schema；公开契约测试。
- **残余风险**：业务查询未来新增字段可能默认透出；需要 schema 白名单（默认不暴露）而非黑名单。
- **观测点**：`OBS-AUTH-04` — 脚本查询输出严格等于公开契约字段；未探索信息不可见；未登记 query 返回 denied。

#### TM-AUTH-05 storage 命名空间越权与配额缺失

- **类别**：权限与越权（TM-AUTH）｜**严重度**：高｜**发布阻断**：否（S2 发布前必须闭合）
- **攻击者能力前提**：storage 用全局 key 空间；无键前缀/配额；加载时不校验归属。
- **攻击路径**：A 写 `core/...` 或 B 的 key；无限写大值导致存档膨胀；用特殊 key（空、超长、路径样式）探测。
- **影响**：跨模组数据污染、存档膨胀、存档不可读；与 TM-STATE-02/04 叠加。
- **可能性**：中高。
- **S0 契约**：§6.2/§8 每模组私有命名空间（宿主强制前缀 `<mod_id>/`）；配额（键数、单值大小、总大小）；只允许 JSON-like 值；拒绝空/超长/非法字符 key；错误码 `script.storage_denied` / `script.storage_quota`。
- **S1 PoC 证据**：PoC 跨模组键访问 denied；超配额返回 quota 错误且不落盘；合法键可读写；重载后仍隔离。
- **S2 运行时实现**：`script_storage.gd`（新，GAP-10）强制前缀、配额、值校验；存档只由宿主写入。
- **残余风险**：配额值需 S1 基准（`T-OQ-03`）；过小会影响正常模组。
- **观测点**：`OBS-AUTH-05` — 跨模组 key 被拒；配额错误稳定；存档大小与键数受控。

### 3.5 TM-SCHED — 调度与重入

#### TM-SCHED-01 事件递归链/无限事件风暴

- **类别**：调度与重入（TM-SCHED）｜**严重度**：高｜**发布阻断**：否（§14 列为"高"；若导致主线程冻结则按 §11.1-3 升级为阻断）
- **攻击者能力前提**：事件回调内可直接触发新事件；事件链深度无上限；新事件在旧回调内同步派发。
- **攻击路径**：监听 `voyage.completed`，在回调中提交产生新 `voyage.completed` 的命令；或直接通过宿主 API 发布事件；多模组互相触发；每条事件都注册新订阅。
- **影响**：主线程长时间/永久忙、日志与内存暴涨；其他模组饥饿；确定性破坏。
- **可能性**：中高（业务事件链天然容易递归）。
- **S0 契约**：§2.2/§7.1 回调**只产生请求**，不直接重新进入 CommandBus；当前事件批次处理完，再按队列次序提交命令；提交产生的新领域事件进入下一批；设"单事件链最大深度 + 总预算"；超限拒绝并记录来源（错误码 `script.event_chain_limit`）。
- **S1 PoC 证据**：PoC 构造自触发事件链，观测到深度上限时停止、返回稳定错误、宿主继续运行；事件历史不无限增长；无重复回调风暴。
- **S2 运行时实现**：`script_scheduler.gd` 的批次队列 + 深度计数 + 来源追踪；命令统一入队；事件适配器不允许回调内同步 `publish`；`DomainEventBus` 的内部 history（`domain_event_bus.gd:7,26-29`）**不作为脚本可见契约**。
- **残余风险**：链深度值需调优；合法长链可能被误伤，需要可观测日志。
- **观测点**：`OBS-SCHED-01` — 递归链在深度上限停止；错误码稳定；宿主帧循环继续；无事件历史无限增长。

#### TM-SCHED-02 命令风暴/批次预算绕过

- **类别**：调度与重入（TM-SCHED）｜**严重度**：高｜**发布阻断**：否
- **攻击者能力前提**：每轮回调次数/待执行命令数无上限；批量循环提交不受预算约束；多模组叠加。
- **攻击路径**：一个回调内循环 `sn.command()` 10^6 次；每轮事件都提交大量命令；利用"命令回执"不阻塞继续提交。
- **影响**：批次耗时过长、帧卡顿、其他模组饥饿；与 TM-EXEC-01 叠加。
- **可能性**：中。
- **S0 契约**：§6.3/§7.1 每轮待执行命令数上限 + 单轮总预算；超限拒绝后续请求并记录来源（`script.batch_limit`）；已入队命令仍按稳定顺序执行；不承诺同步成功（上游 §4.2）。
- **S1 PoC 证据**：PoC 提交超限命令，观测到超出部分被拒、已入队部分按序执行、状态一致；拒绝日志含 `mod_id` 来源。
- **S2 运行时实现**：`ScriptScheduler` 队列长度/批次预算硬上限；按模组归因；拒绝日志限频；`CommandBus` 执行前统一经队列（GAP-07）。
- **残余风险**：上限值与性能基准相关（`T-OQ-02`）。
- **观测点**：`OBS-SCHED-02` — 超限命令被拒且可追踪来源；批次耗时有上界。

#### TM-SCHED-03 回调顺序不确定/跨模组重入

- **类别**：调度与重入（TM-SCHED）｜**严重度**：高｜**发布阻断**：否（§11 确定性验收必须；S2 发布前闭合）
- **攻击者能力前提**：订阅表用无序 Dictionary 遍历；按真实到达顺序派发；回调内直接调用其他模组；同一事件多订阅无稳定排序。
- **攻击路径**：同一事件在不同运行中回调顺序不同，导致命令顺序/状态分歧；A 的回调内触发 B；重载后注册序号变化。
- **影响**：确定性/重放失败、跨模组干扰、存档后行为不一致；上游 §7.1 要求固定顺序。
- **可能性**：中高（Godot Dictionary 遍历顺序是常见坑）。
- **S0 契约**：§7.1 固定顺序 `event sequence → mod order → subscription registration index`；批次内不允许重入；跨模组无直接调用；mod order 来自 `DependencyResolver` 的稳定 Kahn 排序（`dependency_resolver.gd:208-263`，按 `load_priority` 和 id 排序）。
- **S1 PoC 证据**：PoC 同种子同事件序列两次运行产生相同的命令序列与 `GameState.hash()`；交换订阅注册顺序后，命令顺序按 `mod order → registration index` 可预测；事件回调内不能直接进入另一回调。
- **S2 运行时实现**：`ScriptScheduler` 显式排序键；订阅注册序号；重入检测；测试断言顺序稳定（GAP-06）。
- **残余风险**：多模组同优先级时依赖 id 排序，已由 resolver 保证；脚本层需复用同一 order，不能另建排序。
- **观测点**：`OBS-SCHED-03` — 重复运行命令序列/状态哈希一致；回调顺序可由 `mod order + registration index` 解释。

#### TM-SCHED-04 回调异常回滚不完整/未提交请求泄漏

- **类别**：调度与重入（TM-SCHED）｜**严重度**：高｜**发布阻断**：否（S2 发布前闭合；与 TM-EXEC-06 联动）
- **攻击者能力前提**：异常时只清 Lua 栈不清该回调已入队命令；或部分命令已提交；回执与实际执行不一致。
- **攻击路径**：回调先提交命令再抛错，利用错误让应撤销的命令继续执行；或让部分命令执行、部分不执行形成不一致状态。
- **影响**：状态污染、越权命令通过、重放不一致；§7.1「回调异常时撤销该回调产生的尚未提交请求」失败。
- **可能性**：中。
- **S0 契约**：§7.1 契约：回调异常撤销该回调产生的**尚未提交**请求；**已提交的独立命令不做跨命令隐式回滚**；回执与最终执行结果分离且可追踪；错误码 `script.callback_failed`。
- **S1 PoC 证据**：PoC 回调中途抛错，验证该回调未提交命令全部不执行、其他回调命令不受影响、已提交命令保持提交；状态与预期哈希一致。
- **S2 运行时实现**：每回调一个事务边界（待执行队列按回调归组）；失败丢弃该组；审计日志；`CommandBus` 仍是提交点（`command_bus.gd:48-57`）。
- **残余风险**：跨回调/跨批次的业务一致性不在范围内，需业务事务设计。
- **观测点**：`OBS-SCHED-04` — 失败回调的命令组 0 执行；其他组正常；状态哈希可预测。

#### TM-SCHED-05 卸载/重载后悬挂订阅与队列残留

- **类别**：调度与重入（TM-SCHED）｜**严重度**：高｜**发布阻断**：否（S2 发布前闭合；§5 生命周期）
- **攻击者能力前提**：卸载只 dispose VM，不清订阅/队列；重载重复注册；异步队列持有已销毁 state 的回调。
- **攻击路径**：停用模组后触发事件 → 回调已销毁 state → 宿主崩溃；重载后同一事件执行两次；停用后待执行命令仍提交。
- **影响**：崩溃、重复执行、存档污染；§5「模组停用：移除订阅，清空待执行请求，保存私有状态」失败。
- **可能性**：中。
- **S0 契约**：§5 生命周期硬契约：停用即移除订阅、清空待执行请求、保存私有状态；token 失效；重载幂等；不序列化函数/VM 栈帧。
- **S1 PoC 证据**：PoC 停用后触发事件无回调、无宿主错误；待执行命令不提交；重载后同一订阅只执行一次；`state_count` 与模组数一致。
- **S2 运行时实现**：`ScriptHost` 生命周期状态机；订阅表按 state 归属；dispose 清队列；重复加载检测；`ModLoader` 脚本阶段（GAP-17）。
- **残余风险**：UI/信号可能持有旧回调；需审计所有宿主回调入口。
- **观测点**：`OBS-SCHED-05` — 卸载后 0 回调/0 提交；重载后单次执行；无崩溃。

### 3.6 TM-STATE — 存档与状态

#### TM-STATE-01 绕过 CommandBus 直接污染 GameState

- **类别**：存档与状态（TM-STATE）｜**严重度**：高｜**发布阻断**：否（若出现直接对象引用则按 TM-BR-01 阻断）
- **攻击者能力前提**：脚本 API 暴露 state 引用或写入接口；查询返回值可写回 state；storage 注入 state；host 直接把可变字典交给脚本。
- **攻击路径**：脚本直接改 `state.data`；修改查询返回的深拷贝并期望生效；通过 storage 写 `save_schema/seed`；利用回调参数持有可变引用。
- **影响**：绕过 clone-and-commit 事务与业务校验，破坏存档一致性/公平性；可能导致存档不可读。
- **可能性**：低到中（取决于桥接实现）。
- **S0 契约**：脚本只能通过 command 改状态；查询只读深拷贝；不暴露 `GameState`、不暴露 `RegistryHub`；存储独立命名空间；脚本不能写存档头字段。
- **S1 PoC 证据**：PoC 修改查询返回值后 `GameState.hash()` 不变；不存在任何脚本可调用的"写 state"API；`save_schema/seed/mods` 不可由脚本改。
- **S2 运行时实现**：`ScriptValueCodec` 拒绝对象；`CommandBus` 仍是唯一写路径；`SaveService` 只由宿主调用（`save_service.gd:46-76`）。
- **残余风险**：未来若开放"脚本可写自定义内容类型"，需要新的事务边界设计。
- **观测点**：`OBS-STATE-01` — 修改查询结果/存储值后 state 哈希不变；无写 state API 可达。

#### TM-STATE-02 跨模组存档命名空间越权

- **类别**：存档与状态（TM-STATE）｜**严重度**：高｜**发布阻断**：否（S2 发布前闭合）
- **攻击者能力前提**：`script_states` 按脚本可控 key 写入；加载时未校验归属；存档可被本地篡改。
- **攻击路径**：A 写 `script_states.b`；手动编辑存档插入伪造状态；加载时未知 mod 状态被当作有效；重命名 mod_id 复用旧状态。
- **影响**：跨模组数据污染、伪造进度、状态串味；§8「不允许脚本直接修改其他模组的存储空间」失败。
- **可能性**：中。
- **S0 契约**：§8 固定 `script_states[mod_id]`，`mod_id` 来自 manifest；加载时按当前模组集合校验归属；未知模组状态**保留但不执行**（上游 §8 语义）；脚本不能选择写入键；手动篡改只影响该 mod 自身并被校验。
- **S1 PoC 证据**：PoC 跨命名空间写被拒；篡改存档后加载：结构非法/归属不符时警告或禁用脚本，Core 存档仍可读；其他模组状态不被污染。
- **S2 运行时实现**：`ScriptStorage` 强制命名空间；`SaveMigrations` 增加 `script_states` 结构校验（GAP-10）；`validate_mods()`（`save_service.gd:177-207`）扩展脚本状态检查。
- **残余风险**：本地存档可被完全重写，只能保证"结构校验+不扩散"，不能防作弊。
- **观测点**：`OBS-STATE-02` — 跨模组写被拒；篡改存档不导致其他模组数据错误；Core 可读。

#### TM-STATE-03 脚本状态 Schema 迁移失败/半迁移

- **类别**：存档与状态（TM-STATE）｜**严重度**：高｜**发布阻断**：否（S2 发布前闭合；§8 明确要求）
- **攻击者能力前提**：脚本升级后 storage schema 变化；缺乏迁移或失败处理；迁移写出半成品。
- **攻击路径**：旧档加载新脚本，字段缺失/类型变化 → 脚本报错或错误数据写回；迁移中途失败留下部分状态；`storage_schema` 未记录。
- **影响**：存档不可用/数据丢失；脚本永远无法恢复；可能污染 Core 存档读取路径。
- **可能性**：中高（版本迭代必然发生）。
- **S0 契约**：§8 受限迁移 API + `storage_schema` 版本；迁移失败标记脚本不可用并保留备份；**不阻塞 Core 存档读取**；迁移只能转换本模组数据。
- **S1 PoC 证据**：PoC 用旧 schema 档加载：成功迁移或失败禁用脚本，两种情况 Core 存档都可读、备份存在、错误码稳定（`script.state_migration_failed`）。
- **S2 运行时实现**：`ScriptStorage` 迁移器 + 版本表 + 备份；接入 `SaveMigrations`（GAP-10）；迁移前后校验；失败降级不抛宿主异常。
- **残余风险**：作者迁移逻辑本身可能有 bug；只能保证隔离与备份。
- **观测点**：`OBS-STATE-03` — 旧档可读/可降级；Core 状态哈希不变；备份存在；错误码稳定。

#### TM-STATE-04 存档膨胀/存储资源耗尽

- **类别**：存档与状态（TM-STATE）｜**严重度**：中｜**发布阻断**：否
- **攻击者能力前提**：storage 无配额；脚本每次事件写大值；存档序列化无上限。
- **攻击路径**：循环 `set` 大字符串/大表；键爆炸；每 tick 写；利用嵌套结构放大。
- **影响**：存档巨大、加载/保存慢、磁盘耗尽；影响所有存档操作。
- **可能性**：中。
- **S0 契约**：§6.3/§8 键数、单值大小、总值上限；超限拒绝且不落盘；不序列化函数/VM 栈；存档大小有硬上限断言。
- **S1 PoC 证据**：PoC 写入超配额被拒；存档大小与键数可测且有上界；Core 存档时间不受影响。
- **S2 运行时实现**：`ScriptStorage` 配额执行；`SaveService` 序列化前校验（`save_service.gd:46-76`）；告警。
- **残余风险**：配额与正常模组需求需平衡（`T-OQ-03`）。
- **观测点**：`OBS-STATE-04` — 超配额被拒；存档大小/键数有硬上限。

#### TM-STATE-05 RNG 状态篡改/重放分歧

- **类别**：存档与状态（TM-STATE）｜**严重度**：高｜**发布阻断**：否（§7.2 确定性要求；S2 发布前闭合）
- **攻击者能力前提**：RNG 状态可由脚本读写；脚本可调用系统随机/时钟；宿主 RNG 与其他系统共享流。
- **攻击路径**：脚本改写 `rng_state` 让自己抽到好结果；用 `os.time`/`os.clock` 分支；跨模组共享同一 stream 导致行为耦合；存档恢复后 RNG 状态不一致。
- **影响**：确定性/公平性破坏、重放失败、存档后续运行不一致；§7.2 失败。
- **可能性**：中。
- **S0 契约**：§7.2 每模组独立 PRNG stream，种子 = Campaign seed + Mod ID + 固定协议版本；RNG 状态由宿主拥有并在存档中序列化；**Lua 不能直接写 RNG 状态**；脚本只能取游戏内时钟，不提供系统 wall-clock；不使用系统随机推进模拟。
- **S1 PoC 证据**：PoC 同种子/同事件序列两次运行结果一致；存档后继续运行与不存档一致；脚本无法修改 `rng_state`；无系统时间 API。
- **S2 运行时实现**：`script_rng.gd`（新，GAP-11）由宿主持有 `RandomNumberGenerator`；复用 `rng_service.gd:47-65` 的 `StableHash` 派生思路；状态序列化仅宿主；系统时间 API 不可达（TM-ISO-01）。
- **残余风险**：浮点/排序差异仍可能影响结果（见 TM-PLATFORM-01）。
- **观测点**：`OBS-STATE-05` — 同种子重放状态哈希一致；存档续跑一致；`rng_state` 不可由 Lua 写。

### 3.7 TM-SUPPLY — 打包与版本

#### TM-SUPPLY-01 脚本与内容/打包产物不一致

- **类别**：打包与版本（TM-SUPPLY）｜**严重度**：高｜**发布阻断**：否（§10/§16 发布完整性；S2 发布前必须闭合）
- **攻击者能力前提**：打包工具只校验内容不校验脚本；manifest `scripts` 与包内文件不一致；发布后包可被替换；SDK 与运行时规则分叉。
- **攻击路径**：包内替换 `scripts/main.lua` 但 manifest/哈希未变；声明 `entry` 指向不存在或未审核文件；打包遗漏脚本导致运行时静默降级；本地开发包被当正式包分发。
- **影响**：绕过发布门禁、玩家加载未审核脚本、行为不一致；违反 §10「同一 manifest、同一套能力规则、同一组发布错误码」。
- **可能性**：中高。
- **S0 契约**：§10 发布层级：本地开发包明确标记不可发行；正式脚本包必须同时通过"内容 + 脚本静态 + 宿主行为 + 导出平台"校验；脚本文件必须与 manifest 声明一致；包结构固定 `mods/<mod_id>/...`；发布错误码统一。
- **S1 PoC 证据**：PoC 用 release 模式打包含脚本的测试模组：entry 缺失/扩展名非法/能力未知/脚本清单缺失均拒绝；篡改包内脚本后哈希校验失败；包内容与清单一致。
- **S2 运行时实现**：`pack_mod.gd` 增加脚本阶段（GAP-15/16）；`sdk/script/` 工具产出清单；`.github/workflows/release.yml` 增加脚本校验步骤；复用现有 `pack_mod.gd --release` 的"失败不写 zip"语义（`sdk/pack_mod.gd:84-106`）。
- **残余风险**：签名方案未定（`T-OQ-06`）；哈希只能证明一致性，不能证明作者身份。
- **观测点**：`OBS-SUPPLY-01` — release 打包对脚本/内容不一致返回非零并拒绝写包；包内清单与实际文件逐项匹配。

#### TM-SUPPLY-02 script_api_version 与 api_version 混淆

- **类别**：打包与版本（TM-SUPPLY）｜**严重度**：高｜**发布阻断**：否（S2 发布前闭合）
- **攻击者能力前提**：实现复用 `api_version` 表示脚本 API；未知 `script_api_version` 被忽略；缺省被当作 1.0。
- **攻击路径**：manifest 声明高版本 script API，运行时按旧版加载导致 API 缺失/行为错误；或未声明版本被默认放行；版本比较只比较字符串。
- **影响**：API 不兼容导致错误行为、崩溃或权限判定错误；版本政策失效；§2.4/§3 四类版本独立要求失败。
- **可能性**：中。
- **S0 契约**：§2.4/§3：Content Schema / Script API / Framework / Save Schema **四类版本彼此独立**；含 `scripts` 时 `script_api_version` 必填且单独校验；不兼容明确拒绝脚本（`script.api_version_mismatch`），纯数据仍可用；错误协议稳定。
- **S1 PoC 证据**：PoC 版本不匹配时脚本不加载、纯数据模组正常、错误码稳定；低版本兼容策略可预测；未知版本不被默认放行。
- **S2 运行时实现**：`ModManifest` 新增 `scripts.script_api_version` 解析（GAP-02）；`ScriptHost` 做版本协商；版本比较单点；测试矩阵覆盖。
- **残余风险**：兼容窗口策略（`T-OQ-04`）未定；弃用 API 需要治理。
- **观测点**：`OBS-SUPPLY-02` — 版本不匹配被拒且不影响纯数据；`api_version` 与 `script_api_version` 独立出现在诊断中。

#### TM-SUPPLY-03 无 Lua 运行时静默忽略脚本

- **类别**：打包与版本（TM-SUPPLY）｜**严重度**：高｜**发布阻断**：否（§11.1-5 是回归约束；§3/§11 Manifest 行是硬要求，S2 发布门禁必须断言）
- **攻击者能力前提**：构建未集成 VM 或平台禁用，加载器跳过 `scripts` 继续当内容模组；错误只记 warning。
- **攻击路径**：含脚本的模组在无 VM 构建中"加载成功"但行为缺失；玩家以为模组生效；存档状态与预期不一致。
- **影响**：静默降级、玩家误解、存档不一致；违反 §3「必须明确失败或标记为不可启用，不得默默忽略脚本后把它当正常模组加载」。
- **可能性**：中（平台/构建差异常见）。
- **S0 契约**：§3/§5/§11 写死：无脚本运行时的含脚本模组必须**明确失败或标记不可启用**；`StartupReport` 记录原因；不影响无脚本模组的启动行为。
- **S1 PoC 证据**：PoC 用无 VM 构建加载含 `scripts` 模组，观测 `script.unavailable` 且该模组不被启用；同构建下纯数据模组正常启动；行为与改动前一致。
- **S2 运行时实现**：`ModLoader` 增加脚本阶段与能力探测（GAP-17）；`StartupReport` 增加脚本状态字段（GAP-22）；CI 双平台构建验证。
- **残余风险**：显式失败可能影响依赖该模组的其他模组；需既有严重度模型处理（`required` vs optional，上游 §5）。
- **观测点**：`OBS-SUPPLY-03` — 无 VM 构建中脚本模组被明确禁用/报错；纯数据模组行为不变；报告含稳定错误码。

#### TM-SUPPLY-04 平台导出后 Lua 不可用/原生二进制供应链

- **类别**：打包与版本（TM-SUPPLY）｜**严重度**：高｜**发布阻断**：否（§14 列为"高"；S2 发布前闭合）
- **攻击者能力前提**：VM 是原生扩展/第三方二进制；导出模板不含；二进制来源不可信；平台构建步骤不可复现。
- **攻击路径**：Windows 可用/Linux 不可用；动态库依赖缺失；导出 strip 后崩溃；下载的 VM 二进制被替换（供应链）；许可证不合规。
- **影响**：发布产物不可用或行为不一致；后门/供应链风险；§14「平台打包后 Lua 不可用」。
- **可能性**：中高。
- **S0 契约**：§6.1 记录 VM 许可证、维护状况、平台构建步骤与**二进制供应链**；§10 正式脚本包需导出平台校验；S1 报告必须记录 ABI/架构/版本。
- **S1 PoC 证据**：PoC 在 Windows 与 Linux 导出产物中创建/执行/销毁独立 state；记录 VM 版本、哈希、来源、依赖；两平台行为一致。
- **S2 运行时实现**：CI 双平台导出测试；构建可复现/哈希锁定；启动自检（VM 可用性探测）并在失败时明确降级；`release.yml` 增加脚本阶段。
- **残余风险**：第三方 VM 维护状况不可控（`T-OQ-01`）；需要升级/替换预案。
- **观测点**：`OBS-SUPPLY-04` — 双平台导出产物可运行最小脚本；VM 版本/哈希可追溯；缺失时明确失败。

#### TM-SUPPLY-05 发布完整性缺失（签名/哈希/包篡改）

- **类别**：打包与版本（TM-SUPPLY）｜**严重度**：中｜**发布阻断**：否（非 §11.1 门槛；S2 发布前评估）
- **攻击者能力前提**：只有 `SHA256SUMS` 无签名；用户从非官方渠道获取包；存档头 checksum 漂移仅 warning。
- **攻击路径**：替换 zip/包内脚本；镜像劫持；分发渠道投毒；本地替换 mod 但存档仍加载（`save_service.gd:203-206` 只 warning）。
- **影响**：供应链攻击；玩家执行恶意脚本（仍受沙箱限制，但沙箱未通过前风险叠加）。
- **可能性**：中。
- **S0 契约**：§10 发布层级与完整性策略；至少保证"发布产物哈希可复算 + 加载面与发布面一致"；签名策略在 `T-OQ-06` 决定；存档 mod checksum 漂移的升级策略需明确（当前仅 warning 是事实）。
- **S1 PoC 证据**：PoC 复算产物哈希并与发布清单比对；篡改后被检测；`pack_mod --release` 的产物与校验脚本同源。
- **S2 运行时实现**：发布清单/签名（可选）；加载时校验（可配置信任级别）；`SaveService.validate_mods()` 的 checksum 漂移策略至少提供严格模式。
- **残余风险**：首版若不做签名，只能依赖 HTTPS/官方渠道；沙箱仍是最终防线。
- **观测点**：`OBS-SUPPLY-05` — 产物哈希可复算；篡改包被拒绝或告警；严格模式下 checksum 漂移可阻断加载。

### 3.8 TM-LEAK — 信息泄露

#### TM-LEAK-01 查询返回内部字段/未探索信息

- **类别**：信息泄露（TM-LEAK）｜**严重度**：高｜**发布阻断**：否（S2 发布前闭合；与 TM-AUTH-04 互补）
- **攻击者能力前提**：查询直接复用 UI ViewModel；字段未裁剪；内部 ID/完整世界状态/未探索信息进入返回值。
- **攻击路径**：脚本遍历查询结果获取全图/未发现港口/隐藏任务；读取内部对象字段；通过分页/差异推断。
- **影响**：玩法破坏（透视）、情报泄露、竞争不公平。
- **可能性**：中高。
- **S0 契约**：公开脚本查询只返回稳定 ID 与 JSON-like 字段；字段白名单；探索/迷雾规则在查询层执行；不返回内部 registry 结构、不返回事件历史、不返回宿主对象。
- **S1 PoC 证据**：PoC 对比脚本可见字段与公开契约，完全一致；未探索区域/隐藏对象不可见；查询结果不含 `_` 前缀内部字段。
- **S2 运行时实现**：`script_query_adapter.gd` 字段裁剪（GAP-08）；契约测试；查询实现与 UI ViewModel 解耦。
- **残余风险**：业务查询新增字段可能默认透出；用白名单而非黑名单。
- **观测点**：`OBS-LEAK-01` — 字段集合等于公开契约；未探索信息不可见；无内部结构泄露。

#### TM-LEAK-02 日志泄露宿主路径/其他模组/玩家数据

- **类别**：信息泄露（TM-LEAK）｜**严重度**：中｜**发布阻断**：否
- **攻击者能力前提**：`sn.log` 直接写 `AppLogger`（默认 echo 控制台）；无长度/频率/内容限制；脚本可打印宿主提供的错误/参数。
- **攻击路径**：脚本打印 `debug.traceback` 或含路径的错误；日志被玩家上传/分享；高频日志淹没诊断信息。
- **影响**：安装路径/用户名/存档路径泄露；日志洪水；其他模组信息串扰。
- **可能性**：中。
- **S0 契约**：日志固定级别 + 宿主注入 `mod_id`；消息长度/速率限制（`script.log_rate_limited`）；不记录参数原值；玩家可见日志与诊断日志分离；不输出绝对路径/对象引用。
- **S1 PoC 证据**：PoC 超频日志被限流；日志扫描不含绝对路径/`res://`/`user://`；`mod_id` 正确归属；玩家可见输出不含内部信息。
- **S2 运行时实现**：`AppLogger` 增加脚本专用限频/脱敏通道（GAP-13）；日志字段白名单；导出构建关闭 echo。
- **残余风险**：诊断日志文件仍可能含敏感信息，需要发布前检查与用户知情。
- **观测点**：`OBS-LEAK-02` — 日志无路径泄露；超频被限流；`mod_id` 归属正确。

#### TM-LEAK-03 错误码侧信道与对象枚举

- **类别**：信息泄露（TM-LEAK）｜**严重度**：中｜**发布阻断**：否
- **攻击者能力前提**：错误码区分"存在/不存在/无权限"；`details` 含对象信息；脚本可高频探测。
- **攻击路径**：遍历 `ship_id/port_id`，用不同错误码判断存在性/权限；探测能力集合；枚举内部 API。
- **影响**：信息收集，辅助越权/作弊；跨模组隐私泄露。
- **可能性**：中。
- **S0 契约**：错误码稳定但对外收敛：敏感对象统一 `not_found_or_denied`；`details` 白名单；未授权与不存在不可区分（按资源域定义）；错误文本本地化。
- **S1 PoC 证据**：PoC 枚举测试确认无法通过错误码区分未授权对象存在性；无 `details` 泄露；拒绝路径时延无明显差异（与 LEAK-04 联合）。
- **S2 运行时实现**：`script_fault_mapper.gd` 统一映射（GAP-14）；审计高频失败；限频。
- **残余风险**：业务语义需要区分错误时可能泄露；需资源域策略。
- **观测点**：`OBS-LEAK-03` — 枚举不可区分；`details` 字段白名单；错误码稳定。

#### TM-LEAK-04 时序/性能侧信道

- **类别**：信息泄露（TM-LEAK）｜**严重度**：低｜**发布阻断**：否
- **攻击者能力前提**：脚本可测量宿主调用耗时；VM 提供高精度计时；查询耗时随隐藏数据变化。
- **攻击路径**：用 `os.clock`/`os.time` 测耗时推断隐藏信息（如未探索对象数量）；结合错误码做统计推断。
- **影响**：低危信息泄露；可辅助其它攻击。
- **可能性**：低。
- **S0 契约**：不提供 wall-clock/高精度系统计时（系统时间库不可达，见 TM-ISO-01）；查询返回预算内固定行为；不承诺时序恒定（明确非目标）。
- **S1 PoC 证据**：PoC 断言无 `os.clock/os.time`；对同一公开查询的耗时差异不构成稳定可利用信号（记录评估结论）。
- **S2 运行时实现**：VM 库白名单；如需要可加去相关噪声，但**不承诺**作为安全边界。
- **残余风险**：时序侧信道在本地单机游戏中价值有限，接受。
- **观测点**：`OBS-LEAK-04` — 系统计时 API 不可达；无稳定可利用时序差异。

### 3.9 TM-PLATFORM — 平台与确定性

#### TM-PLATFORM-01 Windows/Linux 路径、大小写、浮点、排序差异

- **类别**：平台与确定性（TM-PLATFORM）｜**严重度**：高｜**发布阻断**：否（§11「包装」验收；S2 发布前闭合）
- **攻击者能力前提**：脚本/宿主路径处理依赖大小写或分隔符；浮点序列化/排序跨平台不同；资源加载顺序不同。
- **攻击路径**：`A.lua` 与 `a.lua` 在 Windows 可读、Linux 不可读；反斜杠路径；`table.sort` 不稳定；浮点打印/解析差异；换行符。
- **影响**：加载失败/确定性失败；§11.1-1 双平台创建/执行/销毁失败；重放分歧。
- **可能性**：中。
- **S0 契约**：路径统一用 `/`、拒绝反斜杠/盘符（`path_guard.gd:21-36` 已做）；脚本排序显式 key；数值只用 double 且用 `JsonUtils.canonical_stringify`（现有）；测试矩阵覆盖双平台。
- **S1 PoC 证据**：PoC 在 Windows/Linux 同脚本同事件序列产生相同命令序列与 `GameState.hash()`；大小写/分隔符/排序用例通过；导出产物一致。
- **S2 运行时实现**：CI 双平台；canonical JSON；脚本 API 的排序/时间/随机全部宿主提供；跨平台测试套件。
- **残余风险**：浮点边界行为仍可能有微小差异；需固定 VM 与序列化格式。
- **观测点**：`OBS-PLATFORM-01` — 双平台状态哈希一致；大小写路径用例结果一致。

#### TM-PLATFORM-02 系统时钟/原生随机影响行为

- **类别**：平台与确定性（TM-PLATFORM）｜**严重度**：高｜**发布阻断**：否（§11 确定性验收；S2 发布前闭合）
- **攻击者能力前提**：脚本可访问 `os.time/os.clock` 或宿主提供 wall clock；使用系统随机。
- **攻击路径**：按真实时间分支（夜间/白天、限时活动）；用系统随机决定游戏行为；存档后时间变化导致行为变化。
- **影响**：重放不一致、存档前后行为不同、测试不稳定；§7.2 失败。
- **可能性**：中。
- **S0 契约**：§7.2 只用游戏内时钟；宿主 PRNG；不提供系统 wall-clock；脚本时间 API 只返回游戏时间。
- **S1 PoC 证据**：PoC 断言系统时间 API 不可达；同种子/同事件序列结果一致；暂停/恢复不改变结果。
- **S2 运行时实现**：VM 库白名单；`script_rng.gd`；`GameState.now()` 作为唯一时间源（`game_state.gd:411-418`）。
- **残余风险**：宿主内部若使用系统时间生成存档 `created_at` 不影响游戏行为（`save_service.gd:65`），需与脚本可见时间分离。
- **观测点**：`OBS-PLATFORM-02` — 系统时间/随机不可达；重放一致。

#### TM-PLATFORM-03 帧率/调度时机相关行为

- **类别**：平台与确定性（TM-PLATFORM）｜**严重度**：中｜**发布阻断**：否
- **攻击者能力前提**：脚本回调依赖帧数/真实 delta；宿主按帧触发；低帧率丢事件。
- **攻击路径**：高帧率多次触发、低帧率合并/丢事件；脚本按 delta 自行推进模拟；暂停恢复后行为不同。
- **影响**：行为不确定、重放失败、性能相关 bug。
- **可能性**：中。
- **S0 契约**：§5 不提供任意 `on_tick` 高频回调；事件驱动 + 固定批次；若未来开放固定步进，需频率上限、执行预算与暂停/恢复语义。
- **S1 PoC 证据**：PoC 在不同帧率/暂停恢复下事件序列与结果一致；无真实 delta 输入；调度不依赖帧数。
- **S2 运行时实现**：`ScriptScheduler` 以游戏时间/事件为准；不暴露 delta；固定批次。
- **残余风险**：玩家机器性能差异影响批次耗时但不影响结果；需要预算防止卡顿。
- **观测点**：`OBS-PLATFORM-03` — 不同帧率下结果一致；无 delta 依赖。

#### TM-PLATFORM-04 导出产物 VM 缺失/ABI 架构差异

- **类别**：平台与确定性（TM-PLATFORM）｜**严重度**：高｜**发布阻断**：否（§11「包装」验收；S2 发布前闭合）
- **攻击者能力前提**：VM 依赖库未随导出、架构不匹配、strip 后崩溃、符号缺失。
- **攻击路径**：Windows x86_64 可用、Linux arm64 不可用；动态库缺失；导出模板版本不一致。
- **影响**：发布不可用/启动崩溃；平台行为不一致。
- **可能性**：中高。
- **S0 契约**：§6.1/§10 平台构建步骤与导出验证；S1 报告记录 ABI/架构/依赖；启动自检。
- **S1 PoC 证据**：PoC 在目标平台导出产物运行最小脚本；记录依赖库、架构、VM 版本；失败时明确错误而非静默。
- **S2 运行时实现**：CI 双平台导出测试；启动自检；明确降级；`release.yml` 增加脚本验证。
- **残余风险**：第三方 VM 的导出兼容性需持续跟踪（`T-OQ-01`）。
- **观测点**：`OBS-PLATFORM-04` — 双平台导出可执行最小脚本；缺失时明确失败；依赖可追溯。

---

## 4. 攻击面清单

| 编号 | 攻击面 | 形态与入口 | 信任域 | 现有控制 | 缺口 | 关联威胁 |
| --- | --- | --- | --- | --- | --- | --- |
| AS-01 | Manifest `scripts` 字段 | `{language, script_api_version, entry}`，新提案 | T4 不可信 | 现状 schema `additionalProperties=false` **直接拒绝**；无脚本支持 | GAP-02 | TM-SUPPLY-02、TM-ISO-02 |
| AS-02 | `scripts.entry` 路径 | 字符串路径 | T4 | `PathGuard.is_safe_relative` 可复用 | 无 `scripts/` 根约束与 `.lua` 白名单（GAP-03/04） | TM-ISO-02 |
| AS-03 | Lua 源码/字节码 | `.lua` 文本；潜在 `.luac`/二进制 chunk | T4 | `mod_scanner.gd` 当前把 `.lua` 判为 `forbidden_file` | 受控源码通道、text-only 加载（GAP-03） | TM-ISO-04、TM-ISO-05 |
| AS-04 | 包内模块 | 未来 `require` 白名单 | T4 | 无 | 模块解析/隔离（GAP-06） | TM-ISO-03、TM-BR-03 |
| AS-05 | `capabilities` 声明 | 字符串数组 | T4 | `DependencyResolver._check_capabilities` 只做加载期预检（`dependency_resolver.gd:112-127`） | 无 `script.*` 命名；无逐调用授权（GAP-05/06） | TM-AUTH-01/02 |
| AS-06 | `content` 引用 | JSON 文件数组 | T4 | `ModManifest`/`PathGuard`/`SchemaValidator`/交叉引用 | 脚本可影响内容解析路径（需隔离） | TM-STATE-01、TM-ISO-02 |
| AS-07 | Query 参数 | `sn.query(name, params)` | T5 | `QueryBus` 临时深拷贝（`query_bus.gd:38-41`） | 参数 schema/字段裁剪/权限（GAP-08） | TM-AUTH-04、TM-LEAK-01 |
| AS-08 | Command 参数与回执 | `sn.command(name, params)` | T5 | `CommandBus` clone-and-commit（`command_bus.gd:42-57`） | 白名单/参数 schema/队列/来源（GAP-07） | TM-AUTH-03、TM-SCHED-02 |
| AS-09 | 事件 payload/订阅 | `sn.events.on/off` | T5 | `DomainEventBus` envelope 与 history（`domain_event_bus.gd:16-30`） | 公开事件登记/裁剪/ACL（GAP-09） | TM-SCHED-01/03、TM-LEAK-01 |
| AS-10 | Storage 键值 | `sn.storage.get/set` | T5 | 无 | 命名空间/配额/JSON-like 校验（GAP-10） | TM-AUTH-05、TM-STATE-02/04 |
| AS-11 | 日志接口 | `sn.log(level, message)` | T5 | `AppLogger` 有模组归属字段、容量 1000 | 限频/长度/脱敏（GAP-13） | TM-LEAK-02、TM-BR-04 |
| AS-12 | 存档 `script_states` | JSON 段 | T4/T6 | `SaveService` 原子写、`SaveMigrations` 内容/状态迁移 | 脚本状态结构/迁移/配额（GAP-10） | TM-STATE-02/03/04/05 |
| AS-13 | 打包产物 | `.snavmod.zip`、导出包 | T0/T3 | `pack_mod.gd` 固定结构、`release.yml` 双平台导出与 SHA256SUMS | 脚本清单/签名/VM 验证（GAP-16/21） | TM-SUPPLY-01/04/05 |
| AS-14 | 错误对象/诊断输出 | `{ok:false,error}`、日志、traceback | T2 | `Result` envelope（`result.gd`） | 脚本层错误映射/脱敏（GAP-14） | TM-BR-04、TM-LEAK-02/03 |
| AS-15 | API 名称/版本信息 | `sn.api.version()`、`sn.mod.info()` | T5 | 无 | 公开版本策略/枚举收敛（GAP-05、T-OQ-04） | TM-LEAK-03、TM-SUPPLY-02 |
| AS-16 | 生命周期控制 | 启用/停用/重载/存档恢复 | T2/T6 | `ModLoader` 有 scan→freeze 生命周期 | 脚本状态机/订阅清理（GAP-17） | TM-SCHED-05、TM-EXEC-06 |

**攻击面判定原则**：凡是"字符串/JSON/字节流从 T4/T6 进入 T2"的位置都算攻击面；凡是"T2 的值进入 T5"的位置也必须列出。脚本层新增的攻击面主要是 AS-01～AS-05、AS-10、AS-11、AS-15。

---

## 5. 安全不变量（可测试断言）

| 编号 | 不变量（断言形式） | 验收证据 | 关联威胁 |
| --- | --- | --- | --- |
| INV-01 | 任何跨 Host/Lua 边界的值都必须经 `ScriptValueCodec` 白名单转换；`Object/Node/Resource/Callable/RID/FileAccess/function/thread/userdata/引擎值类型` 一律拒绝并返回 `script.value_not_serializable` | 注入探针 API + 深度/大小/类型断言 | TM-BR-01 |
| INV-02 | Lua 回调只以宿主内部句柄 `(mod_id, subscription_id, state_generation)` 存在；任何第三方 API 不接收/返回 `Callable`；句柄失效后调用返回 `script.callback_stale` | 句柄失效测试 | TM-BR-02 |
| INV-03 | 每个已启用脚本模组拥有独立 Lua state/环境；`active_script_state_count == active_script_mod_count`；跨 state 不共享 table/registry/模块缓存 | 双模组隔离测试 | TM-BR-03 |
| INV-04 | 脚本可读错误对象只含 `{code, message_key, details?}`，`details` 白名单；不含绝对路径/`res://`/`user://`/宿主类名/GDScript 栈 | 错误输出扫描 | TM-BR-04、TM-LEAK-03 |
| INV-05 | `sn` 是冻结只读代理：`getmetatable` 不可取得内部表，`rawset/rawget/setmetatable` 不可用，API 名不可增删，篡改不改变宿主授权 | 代理篡改测试 | TM-BR-05、TM-ISO-05 |
| INV-06 | `io/os/debug/package.loadlib/ffi` 及系统时间/随机 API 不可达；危险符号探针全部失败并返回稳定错误 | 危险符号套件（双平台） | TM-ISO-01、TM-ISO-05、TM-PLATFORM-02 |
| INV-07 | 所有脚本/内容/资产路径经 `PathGuard.is_safe_relative` 且限制在模组根；`scripts.entry` 必须在 `scripts/` 下；拒绝 `..`/绝对路径/`://`/反斜杠/NUL/盘符 | 路径穿越 payload 套件 | TM-ISO-02 |
| INV-08 | `require` 默认不可用；若开放，只解析包内白名单模块，`package.path/cpath` 不可改，模块缓存按 state 隔离 | 模块隔离测试 | TM-ISO-03 |
| INV-09 | 发布包只接受 UTF-8 `.lua` 源码；`.luac`/二进制 chunk 在扫描、加载、打包三处均被拒绝 | bytecode 拒绝测试 | TM-ISO-04 |
| INV-10 | 每个回调有指令预算与可靠中断；超限返回 `script.budget_exceeded`、撤销未提交请求；`pcall`/协程/回调重入不能绕过或重置预算 | 无限循环 + 绕过 payload（双平台） | TM-EXEC-01、TM-EXEC-05 |
| INV-11 | VM 有可计量内存上限；字符串/表/参数/存储值有大小上限；超限返回 `script.memory_exceeded` 且不落盘 | 内存轰炸测试 | TM-EXEC-02、TM-EXEC-04、TM-STATE-04 |
| INV-12 | VM 递归深度与宿主参数/返回值深度有上限；超限返回受控错误，宿主不崩溃 | 深递归测试 | TM-EXEC-03 |
| INV-13 | 脚本状态机至少 `Initialized/Active/Faulted/Disabled/Unloaded`；初始化失败不得进入 Active；连续失败达阈值自动 Disabled；失败不影响 Core/其他模组 | 连续失败测试 + 状态哈希 | TM-EXEC-06 |
| INV-14 | 每次 Lua→Host 调用都在宿主侧校验 capability 与脚本身份；身份由宿主绑定不可伪造；未授权调用返回 `script.permission_denied` 且无副作用；拒绝跨模组调用 | 越权/伪造测试 | TM-AUTH-01、TM-AUTH-02 |
| INV-15 | 脚本命令必须在 allowlist 内且参数满足字段/类型/范围/长度/深度 schema；脚本不能设置 `autosave/source/events`；未知命令/字段一律拒绝 | 命令 fuzz 测试 | TM-AUTH-03 |
| INV-16 | 脚本查询只暴露登记过的 API 子集与公开字段白名单；迷雾/未探索规则在裁剪层执行；未登记 query 拒绝 | 字段契约测试 | TM-AUTH-04、TM-LEAK-01 |
| INV-17 | Storage 键强制前缀 `<mod_id>/`；键数/单值/总值配额；只允许 JSON-like；跨模组访问拒绝 | 配额/跨模组测试 | TM-AUTH-05、TM-STATE-02、TM-STATE-04 |
| INV-18 | 调度顺序固定为 `event sequence → mod order → subscription registration index`；单事件链最大深度、每轮命令数/回调数有上限；超限拒绝并记录来源 | 顺序/预算/递归测试 | TM-SCHED-01/02/03、TM-PLATFORM-03 |
| INV-19 | 回调异常只撤销该回调未提交命令组；已提交命令不回滚；回执与实际执行可追踪 | 异常回滚测试 | TM-SCHED-04 |
| INV-20 | 停用/重载/销毁后订阅、token、待执行队列全部失效；重载幂等；不序列化函数/VM 栈帧 | 生命周期测试 | TM-SCHED-05、TM-BR-02 |
| INV-21 | 脚本只能通过 CommandBus 改状态；查询返回深拷贝；不暴露 `GameState/RegistryHub/总线`；`save_schema/seed/mods` 不可由脚本写 | 写路径审计 + 状态哈希 | TM-STATE-01 |
| INV-22 | `script_states[mod_id]` 由宿主写入并带 `storage_schema`；加载校验结构；迁移失败禁用脚本并保留备份，不阻塞 Core 存档 | 旧档迁移/篡改存档测试 | TM-STATE-02/03 |
| INV-23 | 脚本 RNG 由宿主持有并按 `Campaign seed + Mod ID + 协议版本` 派生；Lua 不能写 RNG 状态；时间只取游戏内时钟；不使用系统随机/时间决定行为 | 重放/存档续跑测试 | TM-STATE-05、TM-PLATFORM-02、TM-LEAK-04 |
| INV-24 | `api_version`、`script_api_version`、Content Schema、Save Schema 四类版本独立校验；含 `scripts` 但运行时无 VM 必须明确失败/禁用；不静默忽略 | 版本矩阵 + 无 VM 构建测试 | TM-SUPPLY-02/03 |
| INV-25 | 发布包同时校验内容与脚本清单；release 模式拒绝 draft/未知 capability/缺失或非法脚本；产物哈希可复算；包内结构与 manifest 一致 | release 打包负向测试 | TM-SUPPLY-01/04/05 |
| INV-26 | Windows/Linux 同脚本、同种子、同事件序列产生相同命令序列与 `GameState.hash()`；路径/排序/浮点/换行处理一致 | 双平台确定性测试 | TM-PLATFORM-01/04 |
| INV-27 | 脚本日志带 `mod_id`、限频、限长、脱敏；玩家可见日志与诊断日志分离；不输出绝对路径/对象引用 | 日志扫描/限流测试 | TM-LEAK-02、TM-BR-04 |
| INV-28 | 脚本层错误码稳定且收敛；未授权与不存在按资源域不可区分；`details` 白名单；错误文本走本地化 | 枚举/错误码契约测试 | TM-LEAK-03、TM-BR-04 |

补充说明：INV 是"实现必须满足的断言"，不是"测试用例清单"。测试矩阵应把每条 INV 拆成正常/边界/恶意三类用例；本文只提供观测方向与证据要求。

---

## 6. S1 PoC 证据与发布阻断

### 6.1 每类威胁的最小证据

| 类别 | S1 必须给出的最小证据（观测结论） | 不允许的替代 |
| --- | --- | --- |
| TM-BR | 注入探针证明跨界值只有 `nil/boolean/number/string/array/dict`；`Object/Callable` 被拒；两个 state 不共享全局；销毁后旧 token 失效；错误/日志不含宿主路径 | "桥接代码看起来只传了 string" |
| TM-ISO | 危险库/require/FFI 不可达；路径穿越在 Windows/Linux 都被拒；bytecode 在扫描/加载/打包三处被拒；`_ENV/load/string.dump` 逃逸 payload 失败 | "VM 文档说可以关闭" |
| TM-EXEC | 无限循环在预算内可靠中断且进程存活；内存上限可测且超限被拒；深递归受控；`pcall`/协程不能绕过；连续失败后脚本 Disabled 且 Core 状态哈希不变 | "墙钟超时"、"进程被 kill 后重启" |
| TM-AUTH | 未声明能力调用被拒且状态哈希不变；身份不可伪造；白名单外命令/非法参数被拒；未登记查询/跨模组存储被拒 | "manifest 里写了所以可以调用" |
| TM-SCHED | 递归事件在深度上限停止；命令风暴被拒且来源可追踪；双模组顺序由 `mod order + registration index` 可预测；异常只回滚该回调未提交组；卸载后无回调 | "顺序由 Dictionary 遍历自然稳定" |
| TM-STATE | 修改查询返回值不影响 state；跨命名空间写被拒；旧 schema 档可迁移或安全降级且 Core 可读；配额有效；同种子重放与存档续跑一致 | "存档结构看起来加了字段" |
| TM-SUPPLY | 含脚本包 release 校验；版本不匹配拒绝；无 VM 构建明确失败；Windows/Linux 导出产物可运行最小脚本；篡改可检测 | "Lua 语法检查通过即可发布" |
| TM-LEAK | 脚本可见字段等于公开契约；未探索信息不可见；日志无路径泄露；枚举不可区分；无系统计时 | "UI 上没显示" |
| TM-PLATFORM | 双平台状态哈希一致；系统时间/随机不可达；不同帧率/暂停恢复结果一致；导出产物依赖可追溯 | "Windows 上跑通了" |

### 6.2 与上游 §11.1 PoC 门槛的映射

| §11.1 门槛 | 本文对应威胁 | S1 必须观测到 | 不满足的后果 |
| --- | --- | --- | --- |
| 1. 可在 Windows/Linux 创建/执行/销毁独立 Lua state | TM-BR-03、TM-PLATFORM-01、TM-PLATFORM-04 | 双平台 state 创建/销毁成功；state 数=模组数；销毁后无回调 | 停止晋级正式第三方脚本功能 |
| 2. 订阅公开事件、查询只读视图、提交允许的命令请求 | TM-AUTH-01（阻断）；TM-BR-01、TM-STATE-01 为支撑证据 | 全链路纵向样例跑通；未授权调用被拒且无副作用；查询返回值修改不影响 state | 停止晋级 |
| 3. 无限循环可靠中断、内存上限可验证、OS/IO/原生不可达 | TM-EXEC-01、TM-EXEC-02、TM-ISO-01、TM-ISO-02 | 三项分别有可复现观测；不是"软超时"或"文档声明" | 停止晋级（§14 第 1 条） |
| 4. 连续失败可禁用脚本且不影响 Core/GameState | TM-EXEC-06 | 失败脚本 Disabled；Core 与状态哈希不变；其他模组继续 | 停止晋级 |
| 5. 不改 active Content Schema 类型、不影响无脚本模组启动 | 无直接威胁；由 GAP-02、GAP-17 与 CI 回归覆盖 | 纯数据 Core/第三方 1.0/2.0 模组不创建 VM、行为不变 | 停止晋级 |

### 6.3 阻断判定与"必须 S1 先证明"的前三项

**阻断判定规则**（与 §0.2 一致，不自行放宽）：阻断项 = 使 §11.1 五条门槛之一失败，或命中 §14 两条"阻断"风险的威胁。共 9 条：

1. TM-BR-01（对象泄漏，§14 第 2 条）
2. TM-BR-02（Callable/回调逃逸，§14 第 2 条）
3. TM-BR-03（state 不独立，§11.1-1）
4. TM-EXEC-01（不可中断，§11.1-3 / §14 第 1 条）
5. TM-EXEC-02（内存上限不可验证，§11.1-3）
6. TM-EXEC-06（故障隔离失败，§11.1-4）
7. TM-ISO-01（OS/IO/原生可达，§11.1-3）
8. TM-ISO-02（路径穿越/文件访问，§11.1-3）
9. TM-AUTH-01（声明即授权，§11.1-2 / §6.2 / §16）

**必须由 S1 先证明、否则阻断的前三项**（按"失败后无法用策略补偿"排序）：

1. **TM-EXEC-01 无限循环可可靠中断**——它决定 Lua 能否作为第三方可执行层存在；墙钟超时/杀进程都不满足上游 §6.1，失败即 §14 阻断。
2. **TM-BR-01 桥接不泄漏 Godot Object/userdata**——它决定沙箱是否只是"语法上的沙箱"；一旦泄漏，其余所有权限/存档/隔离契约同时失效，且无法用后续策略补救。
3. **TM-EXEC-02 内存上限可验证**——它决定恶意/低质脚本能否拖垮整个进程；上游 §11.1-3 明确要求"可验证"，不是"通常够用"。

紧随其后、同样属于 S1 硬门槛的是 TM-ISO-01（OS/IO/原生不可达）、TM-AUTH-01（逐调用授权）、TM-BR-03（独立 state）、TM-EXEC-06（故障隔离）。它们可以并行验证，但任一失败都不得进入 S2。

### 6.4 非 S1 阻断、但 S2 发布前必须闭合的清单

以下项目不在 §11.1 的 PoC 门槛内，但属于上游 §11 测试矩阵/§16 最终验收或安全工程完备度。它们不参与"阻断计数"，但**S2 发布前必须逐项关闭或书面接受残余风险**：

- TM-BR-04 错误脱敏、TM-BR-05 代理锁定；
- TM-ISO-03/04/05 模块、bytecode、环境逃逸；
- TM-EXEC-03/04/05 栈、GC、预算绕过；
- TM-AUTH-02/03/04/05 身份、命令、查询、存储；
- TM-SCHED-01～05 全部调度与生命周期项；
- TM-STATE-01、TM-STATE-02～05 存档写路径、命名空间、迁移、配额、RNG；
- TM-SUPPLY-01/02/03/04/05 发布与平台项；
- TM-LEAK-01～04、TM-PLATFORM-01～04。

若上述任一项在 S2 集成测试中表现为"可导致 §11.1 门槛失败"，则按 §0.2 升级为阻断，不因本文将其列为"非阻断"而豁免。

---

## 7. 与现有实现的差距（GAP）

原则：**能复用的机制不重写，能前置到 S0 契约的不拖到 S2。** 每条标注现状证据、可复用部分、缺失部分、建议关闭阶段。

| 编号 | 现状（源码证据） | 可复用 | 缺失 / 需要建立 | 关闭阶段 |
| --- | --- | --- | --- | --- |
| GAP-01 | `framework/scripting/` 不存在；`project.godot` 无 Lua 依赖；无 VM 适配层 | 无 | Lua VM 选型与嵌入、生命周期、平台构建；本文所有 S2 项的前提 | S1 选型，S2 落地 |
| GAP-02 | `schemas/manifest.schema.json` `additionalProperties:false`、`type.const="content"`；`framework/modding/mod_manifest.gd:63-66` 对非 content 报 `invalid_type` | `ModManifest` 的字段解析/错误结构可扩展 | `scripts` 字段、`type=hybrid`、`script_api_version` 解析与校验 | S0 契约，S2 实现 |
| GAP-03 | `framework/modding/mod_scanner.gd:119-136` 仅允许 `.json`、`localization/*.csv`、`assets/` 白名单扩展名；其余 `forbidden_file`。`.lua` 当前会被拒绝 | 文件白名单框架、`PathGuard` | 受控 `.lua` 扩展名通道、脚本文件清单、`.luac` 拒绝 | S0 契约，S2 实现 |
| GAP-04 | `framework/core/path_guard.gd:21-53` 已有 `is_safe_relative`/扩展名策略/长度深度限制 | 路径规范化与危险扩展名检查 | `scripts/` 根约束、`entry` 规则、`is_allowed_script` | S2 |
| GAP-05 | `framework/core/framework_info.gd:14-32` `CAPABILITIES` 仅 `content.*`；`dependency_resolver.gd:112-127` 未知 capability → `unsupported_capability` 并禁用模组 | 能力预检与错误结构 | `script.events/query/command/storage` 命名空间、版本化能力表、声明与授权的分离 | S0 契约，S2 |
| GAP-06 | 无 `script_host/script_scheduler/script_api_registry/script_capability_guard/script_storage/lua_vm_adapter`（上游 §9 仅为建议路径） | `Result` 形状、错误码习惯 | 全部 Script Host 组件、预算、状态机、值协议 | S2 |
| GAP-07 | `framework/application/command_bus.gd:34-69` 同步执行；无队列、无预算、无调用来源；`source` 固定 `"framework"`（:53） | clone-and-commit 事务语义、失败不提交、成功才发布事件（:42-57）、`_execution_log` 容量 200 | 命令队列、批次预算、调用者归因、脚本白名单转发 | S1 PoC，S2 |
| GAP-08 | `framework/application/query_bus.gd:38-41` 临时深拷贝可复用；`query_registry.gd` 的查询是 UI ViewModel 契约 | 深拷贝隔离、`ok/error` 形状 | 脚本查询公开契约、字段裁剪、权限、稳定 API 名称 | S0 契约，S2 |
| GAP-09 | `framework/application/domain_event_bus.gd:7-9` `MAX_HISTORY=500`；`:16-30` envelope 与 `payload.duplicate(true)`；无事件登记/ACL；`publish_many` 只校验 Dictionary（:33-43） | envelope/序号/深拷贝 | 公开事件类型登记、payload schema、订阅权限、裁剪、历史不作为契约的说明 | S0 契约，S2 |
| GAP-10 | `framework/services/save_service.gd:59-70` payload 固定；`save_migrations.gd` 只处理 `save_schema/state_schema/content_versions`；无 `script_states` | 原子写 + `.tmp` 复解析 + `.bak` 回滚；迁移框架 | `script_states[mod_id]`、脚本存储 schema/迁移/配额/备份 | S0 契约，S2 |
| GAP-11 | `framework/services/rng_service.gd:47-65` 按 `base_seed + stream + context` 派生；`StableHash.seed_from` | 命名 stream、稳定派生 | 每模组从 `Campaign seed + Mod ID + 协议版本` 派生；RNG 状态序列化/恢复；脚本 API | S1 证据，S2 |
| GAP-12 | `framework/state/game_state.gd:411-418` `now()/set_now()`；`framework/services/clock_service.gd` 静态格式化 | 游戏内时间真源 | 脚本时间 API、暂停/恢复语义、固定步进（首版不开放） | S0 契约，S2 |
| GAP-13 | `framework/services/logger.gd`：`MAX_ENTRIES=1000`、`echo_to_console` 默认开、`fields.duplicate(true)`；无脚本归属/限频/脱敏 | 结构化日志、模组归属字段 | 脚本专用通道、限频/限长、脱敏、玩家可见/诊断分离 | S2 |
| GAP-14 | `framework/application/result.gd` 提供 `ok/error_code/message_key/data/events` 形状 | 错误 envelope 形状 | 脚本层稳定错误码枚举、VM 异常映射、`details` 白名单 | S0 契约，S2 |
| GAP-15 | `sdk/validate.gd` 仅 `runtime/draft`；`sdk/validation_core.gd` 只做内容校验；`sdk/pack_mod.gd --release` 只跑内容 runtime 校验 | 校验核心、结构化错误、退出码语义 | `script check/test/verify/pack`、脚本静态检查、Mock Host | S1 原型，S2 |
| GAP-16 | `.github/workflows/release.yml` 无脚本阶段、无双平台 Lua 运行验证；`sdk/pack_mod.gd:22` 注释明确"发布签名/哈希不在本脚本内处理" | 双平台导出、SHA256SUMS、release 失败不写包 | 脚本发布门禁、VM 二进制验证、签名/清单 | S1 证据，S2 |
| GAP-17 | `framework/modding/mod_loader.gd:15-120` 流程 `scan → resolve → mount → compile → validate → freeze`，freeze 后直接 `close()`（:108-111）；无脚本阶段 | 生命周期顺序与 `StartupReport` | 脚本能力协商、VM 创建/入口/on_load/on_unload、失败策略 | S2 |
| GAP-18 | `framework/modding/registries/registry_hub.gd:52-56` `freeze_all()` 可复用；但 `mod_loader.gd:59-62` 在 fatal 分支直接设 `registry_frozen=true` 而未实际 `freeze_all()` | 冻结语义 | "脚本必须在真正 frozen 后启动"的断言与状态暴露 | S0 契约，S2 |
| GAP-19 | 无每模组资源核算：无 state 计数、内存/指令配额、Faulted/Disabled 状态机 | 无 | VM 资源台账、预算执行、故障状态机、平台基准 | S1 证据，S2 |
| GAP-20 | 无第三方脚本发行信任级别/用户授权 UI（上游 §10 分层未实现） | `SettingsService` 可扩展 | 开发模式/正式包区分、信任级别、用户显式启用 | S2 之后 |
| GAP-21 | 发布产物只有 `release.yml` 的 `SHA256SUMS`；`save_service.gd:203-206` mod checksum 漂移只 warning | 哈希生成、存档头字段 | 签名/清单、加载时校验、严格模式 | S0 决策（`T-OQ-06`），S2 |
| GAP-22 | `StartupReport` 无脚本状态字段；无脚本重放/诊断工具；`GameState.hash()`（`game_state.gd:130-134`）可复用 | 状态哈希、report 结构 | 脚本状态/错误码进 report、事件序列/命令队列重放记录、诊断包 | S2 |

**差距结论**：SN 的"数据模组安全"基础较好（路径白名单、schema、冻结、事务、存档原子写），但"可执行模组安全"所需的**运行时**几乎为零。因此 S1 的风险不是"改坏现有系统"，而是"证明 VM 能做到上游 §6.1 的三条硬约束"；S2 的风险才是"把桥接/调度/权限/存档做错"。

---

## 8. Open questions（独立编号 T-OQ）

| 编号 | 问题 | 为什么是安全问题 | 建议决策点 |
| --- | --- | --- | --- |
| T-OQ-01 | 选哪个可嵌入 Godot 4.7.2 的 Lua 实现？其许可证、维护状态、Windows/Linux 构建与二进制供应链是否可接受？ | 决定能否可靠中断/计量内存/关闭库；选错则 §11.1-3 无法证明 | S1 报告，S0 评审 |
| T-OQ-02 | 中断与预算采用何种机制（指令 hook、分配器、专用线程）？预算默认值是多少？ | 墙钟超时不算证据；预算过低误伤、过高 DoS | S1 基准，S2 配置化 |
| T-OQ-03 | storage/参数/日志的配额默认值（键数、单值字节、总字节、深度、日志速率） | 直接决定存档膨胀与 DoS 防护强度 | S1 基准 + S2 配置 |
| T-OQ-04 | `script_api_version` 兼容策略（major/minor、弃用窗口、能力增删规则） | 版本混淆会导致权限/行为错误（TM-SUPPLY-02） | S0 契约，随后冻结 |
| T-OQ-05 | 首版是否提供用户授权 UI/信任级别？无 UI 时的默认策略是什么？ | 决定"未验证脚本"能否被普通玩家加载 | S0/S2 之间决策 |
| T-OQ-06 | 发布完整性用签名还是仅哈希？密钥如何管理？ | 供应链篡改（TM-SUPPLY-05）；沙箱是最后防线但不是发布完整性替代 | S0 决策，S2 实现 |
| T-OQ-07 | 是否开放包内 `require` 模块？若开放，模块图是否允许跨文件共享 upvalue？ | 模块解析是常见逃逸面（TM-ISO-03） | S0 契约，S1 验证 |
| T-OQ-08 | 是否开放固定步进 `on_tick`？若开放，频率上限与暂停语义如何定义？ | 帧率相关行为与确定性（TM-PLATFORM-03） | S2 之后，默认不开放 |

命名说明：上述编号 `T-OQ-*` 与 API 契约文档的 `OQ-*` **独立**，避免同一仓库内出现编号歧义；若后续归并，需在 API 契约文档中显式建立映射表。

---

## 附录 A：脚本层稳定错误码草案

以下错误码是 S0 契约建议值，**尚未实现**。命名已在 S0-4 收敛时统一为 S0-1 [LUA_SDK_S0_API_CONTRACT.md](LUA_SDK_S0_API_CONTRACT.md) §4.3 的 `script.<snake_case>` 点分形式（早期草稿的下划线命名不再使用）；若两者仍有出入，**以 S0-1 §4.3 为准**。要求：错误码稳定、可本地化分离、不得随平台/版本变化；面向玩家的文本走 `message_key` + 本地化表（与上游 §4.2 一致）。

| 错误码 | 触发场景 | 关联威胁 |
| --- | --- | --- |
| `script.unavailable` | 构建无 Lua 运行时却加载含脚本模组 | TM-SUPPLY-03 |
| `script.api_version_mismatch` | `script_api_version` 不匹配 | TM-SUPPLY-02 |
| `script.permission_denied` | 未声明/未授权能力调用 | TM-AUTH-01 |
| `script.identity_mismatch` | 伪造 mod_id/跨模组调用 | TM-AUTH-02 |
| `script.command_rejected` | 命令不在 allowlist | TM-AUTH-03 |
| `script.invalid_args` | 参数类型/字段/范围/大小非法 | TM-AUTH-03 |
| `script.unknown_api` | 未登记查询/无查询权限 | TM-AUTH-04 |
| `script.value_not_serializable` | 跨界值类型不允许（Object/userdata 等） | TM-BR-01 |
| `script.payload_depth` | 值嵌套过深 | TM-EXEC-03 |
| `script.bytecode_denied` | 提交 `.luac`/二进制 chunk | TM-ISO-04 |
| `script.module_denied` | `require` 越界/非白名单模块 | TM-ISO-03 |
| `script.library_unavailable` | 访问被禁标准库 | TM-ISO-01 |
| `script.coroutine_denied` | 协程能力未开放 | TM-EXEC-05 |
| `script.budget_exceeded` | 指令预算超限 | TM-EXEC-01 |
| `script.memory_exceeded` | 内存上限超限 | TM-EXEC-02 |
| `script.stack_overflow` | 递归深度超限 | TM-EXEC-03 |
| `script.storage_denied` | 跨模组/非法 key | TM-AUTH-05 |
| `script.storage_quota` | 存储配额超限 | TM-STATE-04 |
| `script.state_migration_failed` | 脚本状态迁移失败 | TM-STATE-03 |
| `script.callback_stale` | 旧 token/已销毁 state 的回调 | TM-SCHED-05、TM-BR-02 |
| `script.callback_failed` | 回调异常且已回滚未提交请求 | TM-SCHED-04 |
| `script.event_chain_limit` | 事件链深度超限 | TM-SCHED-01 |
| `script.batch_limit` | 单轮命令/回调数超限 | TM-SCHED-02 |
| `script.runtime_error` | 未分类 VM 运行时错误（已脱敏） | TM-BR-04 |
| `script.log_rate_limited` | 日志超频被限流 | TM-LEAK-02 |
| `script.schema_error` | 脚本 API 返回/参数 schema 不符 | TM-BR-01、TM-AUTH-03 |

---

## 附录 B：自检清单与维护

### B.1 发布阻断自检（S1 → S2 晋级前必须全绿）

- [ ] §11.1 五项门槛全部有**可复现实验报告**，不是代码审查结论；
- [ ] 9 条阻断威胁（§6.3）全部有对应观测点通过；
- [ ] 阻断项与上游 §14 两条"阻断"风险完全对应，未新增/放宽口径；
- [ ] 纯数据 Core/第三方 1.0/2.0 模组行为未变（不创建 VM、无新错误）；
- [ ] 所有 `INV-*` 至少有一条自动化断言或明确的 S1 证据；
- [ ] 所有 `GAP-*` 有归属阶段，不允许"待定"。

### B.2 S0 更新规则

- 上游 `LUA_MODDING_SDK.md` 的 §3/§4/§6 契约变化时，本文对应威胁与 INV 同步更新；
- 新增威胁必须补 ID/类别/前提/路径/影响/可能性/三层缓解/残余/阻断/观测点，缺一不可；
- 阻断判定只能按 §0.2 规则扩展，不得因进度压力放宽；
- 本文不写测试步骤；测试矩阵引用 `OBS-*` 与 `INV-*` 即可。

### B.3 变更记录

| 版本 | 日期 | 变更 |
| --- | --- | --- |
| Draft 0.1 | 2026-10-23 | 初版：44 条威胁、28 条不变量、22 条差距、9 条阻断项；对齐上游 Draft 0.1 §6/§7/§8/§10/§11.1/§14 |

---

**结论**：在 S1 证明"可中断 + 可计量 + 无对象泄漏 + 无 OS/IO/原生可达 + 独立 state + 故障隔离"之前，任何第三方 Lua 脚本都只能停留在**受信任开发模式**，不得按可发行脚本模组宣传（与上游 §6.1/§11.1/§14 一致）。本文的 9 条阻断项是晋级 S2 的最低安全门槛，其余高/中风险项按 §6.4 在 S2 发布前闭合。
