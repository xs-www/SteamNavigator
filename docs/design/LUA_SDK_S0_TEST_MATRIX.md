# Steam Navigator — Lua Modding SDK S0 测试矩阵（S0-4 收敛版 v0.2）

> **文档状态**：Draft 0.2（S0-4 交付：与 S0-1 API 契约、S0-2 威胁模型完成交叉接线；取代 S0-3 初版）。
> **对齐声明（2026-10-23）**：本文件已按同目录下两份 S0 文档的 Draft 0.1 对齐：
> - [LUA_SDK_S0_API_CONTRACT.md](LUA_SDK_S0_API_CONTRACT.md)（**S0-1**：Q-01…Q-19、C-01…C-42、E-01…E-53 盘点；候选 API-Q-01…07 / API-E-01…08 / API-C-01…05 共 **20** 条；OQ-01…OQ-16；§4.3 脚本错误协议与 §4.6 Manifest Schema 演进契约）。
> - [LUA_SDK_S0_THREAT_MODEL.md](LUA_SDK_S0_THREAT_MODEL.md)（**S0-2**：`TM-*` **44** 条、`INV-01…INV-28`、`GAP-01…GAP-22`、`T-OQ-01…08`，**发布阻断 9 条**）。
> - 上游：[LUA_MODDING_SDK.md](LUA_MODDING_SDK.md) §11 测试矩阵与验收条件、§11.1 PoC 门槛、§15 S0/S1/S2 拆分。
> **代码快照**：HEAD `db75204`（2026-10-23）+ 工作区未提交改动；工作区另含与本任务无关的 D2 fleet 改动，**不计入本文件基线**（见 §1.7）。
> **命名空间声明**：`TC-*` 的 `AREA` 是**测试域轴**，`TM-*` 的 `AREA` 是**威胁分类轴**，两者不是同一命名空间（`LOAD ≠ BR`、`RES ≠ LEAK`），映射见 §0.4。S0-3 初版中的 `TC-BR-*` / `TC-LEAK-*` 编号已作废，不得再被引用。
> **本文件不做什么**：不实现任何运行时能力、不改变现有契约、不把“测试通过”当安全验收（S0-2 §0.2 / §B.1 口径）。

## 0. 阅读指南、ID 与命名空间

### 0.1 ID 规范

| 类型 | 格式 | 来源 | 本文件用法 |
|---|---|---|---|
| 测试用例 | `TC-<AREA>-nnn` | 本文件 | 83 条，`AREA` 为**测试域轴**（§0.2） |
| 威胁 | `TM-<AREA>-nn` | S0-2（44 条） | 每条 TC 标注对应威胁；覆盖表见 §3.2 |
| 安全不变量 | `INV-nn` | S0-2（28 条） | 每条 TC 标注对应不变量；覆盖表见 §3.3 |
| 候选 API | `API-Q-nn` / `API-E-nn` / `API-C-nn` | S0-1（20 条） | 覆盖表见 §3.4 |
| 盘点条目 | `Q-nn` / `C-nn` / `E-nn` | S0-1 | 仅在说明 API 映射时引用 |
| 开放问题 | `OQ-nn`（S0-1）/ `T-OQ-nn`（S0-2） | 各自独立编号 | 在判定标准中引用，不重复编号 |
| 观测点 | `OBS-<AREA>-nn` | S0-2 | 与 TM 同号；本文 TC 是其可执行化落点 |
| 差距 | `GAP-nn` | S0-2 | 在 §7 待建清单中引用 |

> 说明：S0-1 §4.5 提到的 `TC-DET-*` 在本矩阵中对应 **STATE 域确定性用例**（TC-STATE-003/004/008）与 **SCHED 域顺序/跨平台用例**（TC-SCHED-002/007）。本矩阵不设 `DET` 测试域；S0-1 后续若保留该命名，需建立 `DET → STATE/SCHED` 映射或改引本文编号。

### 0.2 测试域轴（TC AREA）

| 测试域 | 含义 | 主要对应 S0-2 威胁（非一一对应） |
|---|---|---|
| `COMPAT` | 兼容回归：纯数据模组、现有 66 套件、CI 保持绿 | 无直接威胁；对应 S0-2 §6.2 门槛 5、INV-24 |
| `LOAD` | 加载链：Manifest 校验、脚本阶段挂接顺序、入口校验、发布一致性 | TM-SUPPLY-01/02/03、TM-ISO-02、TM-EXEC-06 |
| `AUTH` | 授权面：capability、路径、API 参数、只读快照、错误码稳定、代理锁定、身份 | TM-AUTH-01…05、TM-ISO-02、TM-BR-05、TM-LEAK-03 |
| `EXEC` | 脚本执行与生命周期：初始化、回调、禁用、卸载、重复加载、API 版本、预算中断、脱敏 | TM-EXEC-01/05/06、TM-BR-02/04、TM-SUPPLY-02 |
| `SCHED` | 调度与事务：事件链、双模组顺序、批次限额、回滚、快照时间点、重入、高频合并 | TM-SCHED-01…05、TM-BR-02 |
| `STATE` | 私有存储、存档往返、迁移、确定性 | TM-STATE-01…05、TM-PLATFORM-02、TM-AUTH-05 |
| `ISO` | 沙箱隔离：无限循环、内存、禁用库、路径/对象/环境逃逸、独立 state、递归 | TM-ISO-01…05、TM-BR-01/03、TM-EXEC-01/02/03 |
| `RES` | 资源与预算：VM 生命周期、订阅残留、日志限频、内存趋势 | TM-EXEC-02/03/04、TM-STATE-04、TM-LEAK-02 |
| `SUPPLY` | 运行时选型、许可、导出供应链、依赖解析、版本四方独立 | TM-SUPPLY-02/04、TM-PLATFORM-04 |
| `PLATFORM` | Windows/Linux 导出产物、双平台确定性、发布打包门禁、SHA256 | TM-PLATFORM-01…04、TM-SUPPLY-01/05 |

### 0.3 分级模型（与 S0/S1/S2 和 CI 对齐）

| 级别 | 对应阶段 | 执行位置 | 证据形式 | 门禁作用 |
|---|---|---|---|---|
| **L0** | S0（现在即可） | 仓库内只读静态检查（文档 grep / 计数脚本 / 现有 SDK 校验 CLI） | 检查命令输出、计数表、文档 diff、`validate --json` 的退出码与错误码 | S0 文档合并门禁；不证明运行时安全 |
| **L1** | S1 独立 PoC（实验分支） | PoC 分支的测试驱动 / 埋点日志；**不进主 CI** | `docs/research/LUA_HOST_POC_REPORT.md` 章节 + 原始日志 + 测量表 | 只决定是否值得晋级；不得作为正式功能验收 |
| **L2** | S2 受控集成 | `framework/tests/cases/` 新套件（由 `test_runner.gd` 注册）或 `release.yml` 新增 step | `[PASS]` 行 + `Tests: N passed, 0 failed` 汇总行；`validate/pack --json`；CI step 日志 | 集成分支必须全绿，进发布 workflow |
| **L3** | S2 之后的发布/导出 | 真实 `v*` tag 构建产物（Windows/Linux 导出），`release.yml` | 导出产物运行日志、双平台输出哈希、`pack --release` 拒绝日志、`SHA256SUMS.txt` | 发布硬门禁；L3 未通过则不得标记 Script SDK 1.0 |

规则：

1. L0 只检查“文档与静态契约一致”，不能用 L0 结论替代运行时安全判断。
2. L1 用例在 S1 通过后**原编号晋级为 L2**（证据从 PoC 报告改为 CI 日志），不另起编号；晋级前它不能作为 S2 发布验收证据。
3. 每条阻断级威胁必须有 ≥1 条 L1 证据 + ≥1 条 L2/L3 直接回归（见 §3.5）。
4. “测试通过”只表示该观测点成立；安全结论仍需对照 S0-2 威胁模型与代码审计。

### 0.4 测试域 ↔ 威胁域映射（防止同名误引）

| 测试域 | 主要落到的 TM（S0-2） | 说明 |
|---|---|---|
| `LOAD` | TM-SUPPLY-01、TM-SUPPLY-02、TM-SUPPLY-03、TM-ISO-02、TM-EXEC-06 | 加载链本身不是威胁分类；S0-2 的 `TM-BR` 是“桥接与对象泄漏”，与 LOAD 无关 |
| `RES` | TM-EXEC-02、TM-EXEC-03、TM-EXEC-04、TM-STATE-04、TM-LEAK-02 | S0-2 的 `TM-LEAK` 是“信息泄露”，与资源/预算不是同一概念；资源类用例引用 `TM-LEAK-02` 只因其日志/信息维度相关 |
| `AUTH` | TM-AUTH-01…05、TM-ISO-02、TM-BR-05、TM-LEAK-03 | — |
| `EXEC` | TM-EXEC-01…06、TM-BR-02/04 | — |
| `SCHED` | TM-SCHED-01…05 | — |
| `STATE` | TM-STATE-01…05、TM-PLATFORM-02 | — |
| `ISO` | TM-ISO-01…05、TM-BR-01/03 | — |
| `PLATFORM` | TM-PLATFORM-01…04、TM-SUPPLY-04/05 | — |

**引用规则**：任何文档引用测试用例时必须用 `TC-` 前缀 + 测试域（如 `TC-LOAD-003`）；引用威胁必须用 `TM-` 前缀（如 `TM-BR-03`）。不得用旧编号 `TC-BR-*` / `TC-LEAK-*`。

---

## 1. 现有测试基础设施盘点（事实）

### 1.1 Godot 无头测试框架

| 项 | 事实 | 证据（文件/行） |
|---|---|---|
| 入口 | `framework/tests/test_runner.gd`，`extends SceneTree`，在首帧 `_process()` 里跑而不是 `_initialize()`（便于 UI 套件真实挂载 shell） | `test_runner.gd` 1–10、92–134 |
| 套件注册 | 静态数组 `const SUITE_PATHS`，共 **66** 条 `res://framework/tests/cases/test_*.gd` | `test_runner.gd` 12–79 |
| 套件形态 | `framework/tests/cases/` 下 **66** 个 `.gd` 文件，每个 `extends TestCase` | 目录盘点（附录 A） |
| 用例发现 | `suite.get_method_list()` 中前缀为 `test_` 的方法，去重后**按名字排序**执行 | `test_runner.gd` 109–117 |
| 用例计数（静态） | 66 个用例文件中 `func test_` 共 **579** 个；最大 `test_exploration.gd` 43、`test_sea_chart.gd` 42、`test_stage_host.gd` 37；最小 1 个（`test_map_constraints` / `test_no_core_ids` / `test_settings`） | 附录 A 计数 |
| 断言 | 基类 `framework/tests/test_case.gd`（117 行）：`assert_true/false/eq/ne/almost_eq/not_null/empty/contains` + `fail`；断言计数与失败列表 | `test_case.gd` 5–79 |
| 断言语义 | `assert_eq` 对两个数值使用 `is_equal_approx` 比较 | `test_case.gd` 112–117 |
| 启动夹具 | `bootstrap_core()` / `run_core()`：真实 `Bootstrap.run()`，`scan_roots=["res://dev_mods"]`、`allow_loose=true`、`mount_packs=false`、`autosave=false`、`user://test_saves/<唯一后缀>` | `test_case.gd` 82–100 |
| 单套件过滤 | 用户参数 `-- --suite=<名字片段>`，按文件名包含匹配 | `test_runner.gd` 84–89、100–102 |
| 结果格式 | 每用例 `[PASS] suite::method (Nms)` / `[FAIL] suite::method` + 失败明细；结尾 `Tests: %d passed, %d failed, %d total in %dms`；`FrameworkRuntime.shutdown()`；退出码 0/1 | `test_runner.gd` 122–134 |
| 外壳 | `tools/test.ps1`（15 行）：要求 `$env:GODOT_BIN` 或 PATH 中的 `godot`，执行 `--headless --path <repo> --script res://framework/tests/test_runner.gd`，透传退出码 | `tools/test.ps1` 1–15 |
| 未注册脚本 | `framework/tests/smoke_load.gd`（419 B）、`smoke_play.gd`（2311 B）不在 `SUITE_PATHS`；`smoke_save_diff.gd`、`trivial.gd` 仅有 `.uid` 残留、无 `.gd` 源文件 | 目录盘点 |

**加一个 Godot 用例的固定步骤**（S2 接入 Lua 套件时照此执行）：

1. 新建 `framework/tests/cases/test_<域>.gd`，首行 `extends TestCase`，按 `@static-doc` 约定写 `作用：` 注释块。
2. 每个用例写成 `func test_<行为>_<预期>() -> void`，用 `TestCase` 的断言；需要真实启动链时调用 `bootstrap_core()`。
3. 把路径追加到 `test_runner.gd` 的 `SUITE_PATHS`（当前 66 条），顺序即执行顺序。
4. 本地 `pwsh ./tools/test.ps1`；单套件调试加 `-- --suite=<片段>`。
5. 该套件自动进入 `release.yml` 的 “Run tests” step（无需另加 CI step）。

### 1.2 SDK 校验 / 打包门禁（现有测试样板）

`framework/tests/cases/test_sdk_validation.gd`（516 行，**12 个 `func test_`**）是现有最接近“外部 CLI 黑盒测试”的样板：

| 机制 | 事实 | 证据 |
|---|---|---|
| 测试对象 | 真实子进程运行 `res://sdk/validate.gd` / `res://sdk/pack_mod.gd`（`OS.execute(OS.get_executable_path(), [...])`） | `test_sdk_validation.gd` 30–44 |
| 参数形态 | `--headless --path <repo> --script <sdk 脚本> -- <args>`；CLI 参数 `--mod-root=`、`--mode=runtime/draft`、`--json`、`--source=`、`--out=`、`--release` | 同上 32–39、230–516 |
| 输出契约 | 打印 JSON 后由 `_extract_json` 取第一个 `{` 到最后一个 `}`；断言 `mode`/`ok`/`status`/`errors`/`content_counts`/`mods`/`scanned_roots` | 47–88 |
| 错误断言 | `_error_codes` 取 `errors[].code`；`_error_with_code` 断言 `mod`/`file`/`path`/`definition_id`/`severity` | 63–76、257–281 |
| 夹具策略 | 运行期夹具写 `user://sdk_test_*`，用例末尾 `SdkValidationCore.cleanup_stage` 清理；`sdk/examples/**`、`sdk/templates/**` 只读 | 91–109 |
| 模式矩阵 | `runtime` 默认；`--mode=draft` 静态；未知 `--mode` 退出码 **2**（用法错误） | 439–442 |
| 退出码契约 | 0 = 无 error/fatal；1 = 有 error/fatal；2 = 用法错误 | `sdk/validate.gd` 18–19、41–57 |
| 发布门禁 | `pack_mod.gd --release` 先 `SdkValidationCore.run_runtime`，任何 error/fatal 都拒绝写 zip；不加 `--release` 保持旧行为 | `sdk/pack_mod.gd` 52–54、84–106 |
| 打包结构 | `.snavmod.zip` 内固定 `mods/<mod_id>/...`，跳过 `.import`/`.uid`/`.tmp` 与隐藏目录 | `sdk/pack_mod.gd` 21、55–79、109–126 |

`sdk/validation_core.gd`（449 行）提供的**结构化错误模型**（Lua 脚本校验应复用同一形状）：

- 统一字段：`code` / `message` / `severity` / `mod`（= `mod_id`）/ `file` / `path`（= `pointer`），由 `enrich_errors()` 兜底补齐（`validation_core.gd` 269–278）。
- 本文件直接读到的稳定错误码：`inactive_content_type`（215–238）、`content_file_too_large`、`content_parse_error`、`content_not_object`、`unknown_content_type`、`schema_version_unsupported`、`schema_version_mismatch`、`schema_error`（280–380）；扫描侧另有 `unsafe_path`、`forbidden_file`、`invalid_pack`（`framework/modding/mod_scanner.gd` 100–136）。
- 扫描根去重 `normalize_roots()`（100–111）；`MAX_CONTENT_FILE_BYTES = 8 MiB`（23）；`stage_mod()` 把单个第三方模组复制到 `user://` 隔离校验后再清理（257–267）。
- 这些是 **L0 静态门禁可直接复用的错误码/字段规范**；S0-1 §4.6 新增的 `unsupported_manifest_version` / `invalid_script_path` / `missing_script_entry` / `script_too_large` 必须沿用同一形状。

### 1.3 Node / SNModMaker / Content CLI 测试

| 项 | 事实 | 证据 |
|---|---|---|
| 依赖模型 | `SNModMaker/` **没有 `package.json`**，零第三方依赖，CI 直接用 `node` 调用 | 目录盘点；`release.yml` 79–84 |
| 纯逻辑套件 | `SNModMaker/tests/run-tests.js`：自写 `test(name, fn)` 零依赖 harness，`require` 各 `js/*.js` 后从 `globalThis` 取模块；**60** 个 `test(` 注册 | 文件头 1–50；附录 A |
| CLI 集成套件 | `SNModMaker/tests/content-cli.test.mjs`：`node:test` + `node:assert/strict`，每次调用都是 `spawnSync(node content.mjs ...)` 真实子进程；**64** 个顶层 `test(`；夹具在 `os.tmpdir()`，对 `dev_mods/core`、`sdk/templates` 只读并做前后哈希证明 | 文件头 1–60；附录 A |
| CLI 契约 | `SNModMaker/tools/content.mjs` 命令：`types` / `describe` / `list` / `add` / `set` / `loc` / `rm` / `clone` / `validate` / `new`；通用 `--json` / `--quiet`；退出码 0 成功、1 失败/校验未过/冲突、2 用法错误；`--test` 在真实写入后跑 `run-tests.js` | `content.mjs` 81–120（USAGE） |
| 冒烟脚本（不在发布门禁） | `browser-smoke.mjs`（CDP + Chrome 9222）、`server-smoke.mjs`（spawn `serve.mjs`，临时目录 env）、`workspace-smoke.mjs`（工作区操作）；`release.yml` 只跑 `run-tests.js` 与 `content-cli.test.mjs`，三个 smoke 未进 CI | 文件头；`release.yml` 79–84；`SNModMaker/WORKSPACE.md` 50 |
| 对 Lua 的可复用性 | “真实子进程 + JSON + 退出码 + 只读夹具哈希”模式可直接套用到未来的 `script check/test/verify` CLI | 本节结论 |

### 1.4 CI 发布门禁（`.github/workflows/release.yml`，共 **18** 个 step）

| # | step | 门禁作用 |
|---|---|---|
| 1 | Checkout | 取源码 |
| 2 | Cache Godot editor and templates | 缓存 4.7.2 二进制与导出模板 |
| 3 | Install Godot 4.7.2 | Linux 版 Godot |
| 4 | Put Godot on PATH | 后续 step 用裸 `godot` |
| 5 | Import project | `--editor --quit` 生成导入缓存 |
| 6 | Run tests | `test_runner.gd` 全量（内含 `test_sdk_validation` 的 12 个 CLI 用例） |
| 7 | Check generated content types | `node tools/gen_content_types.mjs --check` |
| 8 | Check static documentation | `node tools/gen_static_docs.mjs --check` |
| 9 | Run SNModMaker and Content CLI tests | `run-tests.js`（60）+ `content-cli.test.mjs`（64） |
| 10 | Validate core content (runtime) | `validate.gd --mode=runtime` |
| 11 | Validate SDK examples (runtime + draft) | 4 个 runtime 示例 + 2 个 draft 模板逐个跑 |
| 12 | Release packing rejects draft content | 期望 `pack --release` **失败**（exit 1）且不写 zip |
| 13 | Export Windows and Linux | 两个导出预设 |
| 14 | Pack core mod | `pack_mod.gd --source=dev_mods/core --release`（打包前真实 Bootstrap 校验） |
| 15 | Stage portable release layout | 校验恰好 1 个 core pack，布置 `mods/` + `config/` |
| 16 | Package release assets | zip 两平台产物 + `sha256sum ... > dist/release/SHA256SUMS.txt` |
| 17 | Upload workflow artifact | 归档 release + pack |
| 18 | Publish GitHub Release | `softprops/action-gh-release@v2`，`-dev.` tag 标 prerelease |

要点：step 6/7/8/9/10/11/12 是“内容与文档一致性”门禁；step 13–16 是“导出与打包供应链”门禁；step 18 之前的任何失败都会阻断发布。**Lua SDK 的 L2/L3 用例必须挂到这条链上，不能只存在于实验分支。**

### 1.5 两个生成物检查的角色（只描述，未运行）

| 检查 | 生成关系 | `--check` 语义 | 对 Lua SDK 的意义 |
|---|---|---|---|
| `node tools/gen_content_types.mjs --check` | `content_types.json`（单一真源）→ `framework/modding/content_types.gd` + `SNModMaker/js/content-types.js` | 生成物缺失或过期即 exit 1（脚本头部注释明示） | 防止脚本 API/能力表与内容类型真源分叉；S0-1 §4.6 的 `manifest-v2` 不得引入第二套类型表 |
| `node tools/gen_static_docs.mjs --check` | 源码 `@static-doc` / sidecar / 旧 `FILE_DOCS` → `docs/static/` 镜像 + SHA-256 manifest | 只比较、不写工作区；不一致 exit 1 | 新增 `framework/scripting/**`、`sdk/script/**` 后必须补静态文档头，否则发布门禁红 |

### 1.6 可复用设施与缺口

| 设施 | 现状 | 可否复用 | 缺口 |
|---|---|---|---|
| 无头 runner + `TestCase` 断言 | 66 套件 / 579 静态用例；真实 Bootstrap 夹具 | ✅ 直接复用 | 无超时/预算断言；无金样（golden JSON）比对助手；无故障注入；无 per-suite 隔离进程 |
| 确定性工具 | `GameState.hash()`、`StableHash`（种子派生）、同种子复现测试已存在（`test_rng.gd`、`test_simulation.gd`、`test_save_load.gd`） | ✅ 直接复用 | 没有“脚本 RNG 流 + 存档往返”组合断言 |
| SDK CLI 黑盒测试样板 | 真实子进程 + JSON + 结构化错误 + 退出码 | ✅ 直接复用（脚本 check/test CLI） | 尚无 `mode=script` / 脚本专用错误码实现 |
| `validate.gd` / `pack_mod.gd` 门禁 | runtime/draft、`--release` 拒绝草案与错误 | ✅ 扩展 | 不认识 `scripts` 与 `manifest_version=2`；无脚本静态检查阶段；无沙箱验收标记 |
| Manifest v1 门禁（事实核对） | `schemas/manifest.schema.json`：第 **6** 行 `"additionalProperties": false`、第 7 行 required、第 25–27 行 `api_version` 正则 `^\d+\.\d+$`、第 29–31 行 `type.const = "content"`；`mod_manifest.gd` 63–66 对非 `content` 报 `invalid_type`；`mod_scanner.gd` 119–136 文件白名单对 `.lua` 报 `forbidden_file` | ✅ 语义可复用 | 当前对 `scripts` 是**双重显式拒绝**（schema 拒绝 + 扫描器拒绝），不是静默忽略。新增脚本能力必须按 S0-1 §4.6 升 `manifest-v2.schema.json` 并同步 `ModManifest`/`ModScanner`/`PathGuard`/SDK；不能假设现有 v1 schema 会放行 |
| 路径安全 | `PathGuard.is_safe_relative`、`unsafe_path`、`forbidden_file`（扫描/解包时） | ✅ 复用 | 脚本入口需按 S0-1 §4.6 新增 `is_allowed_script`（仅 `scripts/` 下 `.lua`），并在脚本阶段前再校验一次 |
| Mock Host | 不存在 | ❌ 需新增（S1，GAP-15） | 无宿主替身/无脚本 API 桩 |
| Lua VM 测试驱动 | 不存在 | ❌ 需新增（S1，GAP-01/19） | 无法创建/执行/销毁 state，无指令预算/内存上限观测 |
| 故障注入 | 不存在 | ❌ 需新增（S1/S2） | 无法注入无限循环、错误流、半初始化 |
| 预算断言 | 不存在 | ❌ 需新增（S2） | 无指令数/内存/批次/日志速率断言助手 |
| 双平台运行测试 | 仅有导出 step，无导出后运行测试 | ⚠️ 部分 | 缺“导出产物跑纵向样例”的 L3 用例 |
| 脚本存储/存档检查 | `test_save_load`、`test_save_migration` 只覆盖现有 GameState | ⚠️ 部分 | 无 `script_states[mod_id]` 契约测试 |

### 1.7 基线口径（避免把无关改动当基线）

- `579` 是**静态 `func test_` 计数**（66 个文件），不是运行时实际执行数；运行时以 `test_runner` 汇总行 `Tests: N passed, M failed, T total` 为准。Lua SDK 兼容回归只要求 `failed = 0` 且 `N ≥ 579` 作为静态下界（新增套件只会增大 N）。
- 当前工作区含**与本任务无关的 D2 fleet 未提交改动**（`framework/domain/fleet/*`、`dev_mods/core/content/captains.json`、`test_fleet.gd` 等）；它们不属于 Lua SDK 基线，也不能作为“Lua SDK 改变了行为”的证据。
- 本文所有计数均来自**只读静态盘点**（附录 A），未运行 Godot/Node 测试。

---

## 2. 测试矩阵（主交付）

> 列说明：**级别**见 §0.3；**归属阶段** S0/S1/S2/S3。
> “对应威胁/不变量”列使用 S0-2 的真实 ID；每条判定标准均可观测，不允许“跑通即可”。
> 全部 83 条用例的威胁覆盖见 §3.2，不变量覆盖见 §3.3，API 覆盖见 §3.4。

### 2.1 兼容回归（COMPAT）——升级前后行为不变

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-COMPAT-001 | INV-24；S0-2 §6.2 门槛 5（无直接 TM） | L1 | PoC 分支有 `vm_create`/`vm_dispose` 埋点；`scan_roots=["res://dev_mods"]` | 以 Core + `sdk/examples` 三个无 `scripts` 模组各启动一次；读取埋点计数与脚本阶段日志 | `vm_create=0`、`script_host.init=0`、`StartupReport.status=ok`；任一非 0 即失败 | PoC 报告计数表 + 原始日志摘录 | S1 |
| TC-COMPAT-002 | INV-24、INV-26；TM-SUPPLY-03（旁证） | L2 | 集成分支；升级前基线：`content_counts`、`status=ok`、同种子 `GameState.hash()` | 跑 `test_runner` 全量 + `validate.gd --mode=runtime --json`，与基线逐项 diff | 66 套件汇总 `0 failed`；`content_counts` 逐类型相等；`run.start` 同种子 hash 相等；`errors=[]` | runner 汇总行 + `validate --json` diff | S2 |
| TC-COMPAT-003 | TM-SUPPLY-01、INV-25 | L2 | `sdk/examples`、`sdk/templates` 只读 | 依次对 4 个 runtime 示例、2 个 draft 模板跑 `validate`；对 mixed 示例跑 `pack --release` | 退出码与升级前一致（示例 0；draft 模板仅 draft 0）；zip 条目仍为 `mods/<id>/manifest.json` 等，不扁平化 | CI step 11/12 日志 + `ZIPReader` 断言 | S2 |
| TC-COMPAT-004 | INV-24；S0-2 §B.1 自检 | L2 | `GODOT_BIN` 指向 4.7.2 | `pwsh ./tools/test.ps1` | 汇总行 `Tests: N passed, 0 failed` 且 `N ≥ 579`（静态下界，§1.7）；基线不得混入无关 fleet 改动 | runner 汇总行 | S2 |
| TC-COMPAT-005 | TM-SUPPLY-01（规则分叉） | L2 | Node 18+ | 跑 `gen_content_types.mjs --check` 与 `gen_static_docs.mjs --check` | 两个检查均 exit 0；输出无 stale/missing 报告 | CI step 7/8 日志 | S2（现有） |
| TC-COMPAT-006 | TM-SUPPLY-02、INV-24 | L0 | 读取 v1 schema 事实：`additionalProperties:false`、`type.const="content"`、`api_version` 正则；`ModManifest.from_dict` 非 content → `invalid_type`；扫描器对 `.lua` → `forbidden_file` | 分别用 v1 schema 校验“旧 manifest”“含 `scripts` 的 manifest”；按 S0-1 §4.6 校验 v2 契约（`manifest_version:2` 必填、`type` 枚举、`scripts` 由类型条件约束） | 旧 manifest 走 v1 必须继续通过；含 `scripts` 的 manifest 在 v1 下必须是**显式失败**（schema/`invalid_type`/`forbidden_file` 之一），在 v2 下显式通过；任何“静默放行”即失败。**判定：新增 `scripts` 必须显式登记进 manifest v2 schema + scanner 白名单，不能假设现有 schema 会放行** | schema 校验 JSON + 字段差异表 | S0 |
| TC-COMPAT-007 | TM-SUPPLY-01、TM-SUPPLY-05、INV-25 | L2 | 可推 `v*` tag 的集成分支 | 推 tag，逐 step 核对 §1.4 的 18 个 step | 18 个 step 全部 success；无 `continue-on-error`；产物含 `dist/release/SHA256SUMS.txt` 与 Windows/Linux zip | GitHub Actions run 链接 + step 日志 | S2/L3 |
| TC-COMPAT-008 | 无直接 TM/INV；S0-2 §0.2、§B.1 | L0 | — | 评审本矩阵、S1 报告与发布说明的措辞与结论依据 | 全文不存在“跑通即安全 / 测试通过即验收”表述；安全结论必须引用 ISO/EXEC 的 L1 证据 + S1 报告 + 代码审计；否则评审不通过 | 评审记录（本文件 §8 自检项） | S0 |

### 2.2 加载链（LOAD）——Manifest v2 与脚本阶段挂接

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-LOAD-001 | TM-SUPPLY-02、TM-ISO-02、INV-07、INV-24 | L0 | v1 schema 与扫描器现状（§1.6） | 用 v1 校验含 `scripts` 的 manifest；用 S0-1 §4.6 的 v2 契约做静态比对；检查 `scripts.entry` 路径规则 | v1 必须显式拒绝（不得放行）；v2 必须显式声明 `manifest_version`、`scripts` 必填字段、`type` 条件与 `entry` 相对路径约束；缺少任一条 = 失败 | schema 校验输出 + 差异表 | S0 |
| TC-LOAD-002 | TM-EXEC-06、TM-AUTH-01、INV-13、INV-14 | L2 | 集成分支 host 有阶段埋点 | 用“含 `scripts` + 非法 content”的夹具启动，读取阶段序列 | 序列必须为 `content_validate → registry_freeze → capability_negotiation → vm_create`；内容非法时 `vm_create=0` 且 exit 1，错误码属于内容错误而非脚本错误 | 阶段序列日志（每阶段一行） | S2 |
| TC-LOAD-003 | TM-SUPPLY-03、INV-24 | L1 | PoC 分支可关闭/裁剪 VM 支持 | 在无 Lua 支持的构建/flag 下加载含 `scripts` 的模组 | 必须明确失败或标记“不可启用”（`script.unavailable`），不得按纯数据模组 `ok` 启动；退出码 1；纯数据模组行为不变 | PoC 日志 + 状态表 | S1 |
| TC-LOAD-004 | TM-ISO-02、TM-SUPPLY-01、INV-07、INV-25 | L2 | 夹具：`scripts.entry` 缺失 / 不存在 / 大小写不匹配 / 0 字节 / 非 `scripts/` 下 | 分别跑 `validate --mode=runtime --json` | 全部返回结构化错误（S0-1 §4.6：`missing_script_entry` / `invalid_script_path` / `script_too_large`），`mod`/`file`/`path` 齐全；`vm_create=0` | `validate --json` + 计数 | S2 |
| TC-LOAD-005 | TM-EXEC-06、INV-13 | L2 | 夹具：`on_load` 抛错 | 启动后读取脚本状态与订阅计数 | 状态 `Initialized → Faulted/Disabled`；`events 订阅数=0`、待执行命令=0；`StartupReport` 含稳定错误码；Core 仍可进入诊断界面 | 状态表 + 订阅/队列计数 | S2 |
| TC-LOAD-006 | TM-SUPPLY-01、INV-25 | L2 | 夹具：含脚本但 entry 缺失 / 扩展名非法 / capability 未知 | 执行 `pack --release` | 全部 exit 1 且**不写 zip**；错误码与 `validate` 同源（同一 manifest、同一套能力规则、同一组错误码，S0-1 §10/§4.6） | `pack` 日志 + zip 存在性断言 | S2 |

### 2.3 授权面（AUTH）——capability、路径、API 参数、只读快照、身份

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-AUTH-001 | TM-ISO-02、TM-AUTH-01、TM-SUPPLY-02/03、INV-07、INV-14、INV-24 | L0 | 现有 `validate.gd` 的 runtime/draft 模式；S0-1 §4.6 错误码 | 准备 5 个静态夹具：`entry=../x.lua`、绝对路径、未知 capability、`script_api_version=9.0`、`api_version` 与 `script_api_version` 混用；逐个跑 `validate --mode=draft --json` 与 `runtime --json` | 5 个夹具全部 exit 1；错误码稳定且自解释（`invalid_script_path` / `unsupported_capability` / `script.api_version_mismatch` / schema 错误）；不得出现“忽略后 ok” | `validate --json` 退出码 + `errors[]` | S0 |
| TC-AUTH-002 | TM-ISO-02、INV-07 | L2 | 夹具：`../`、绝对路径、zip 内 `..`、symlink 指向包外、反斜杠/盘符 | 加载并尝试读取入口；观察宿主文件读取审计计数 | 全部拒绝（`invalid_script_path` / `unsafe_path`），宿主实际读取包外文件次数 = 0；不创建 VM | 审计计数 + 错误 JSON | S2 |
| TC-AUTH-003 | TM-AUTH-01、INV-14 | L2 | Manifest 声明未登记 capability（含 `script.*` 未在 `SCRIPT_CAPABILITIES`） | `validate --json` 与启动时读取授权结果 | 明确报错（沿用 `unsupported_capability`，带 `scope: content/script`）或标记不可启用；已知 capability 精确名匹配，不做前缀模糊授权 | `validate --json` + 授权日志 | S2 |
| TC-AUTH-004 | TM-AUTH-01、INV-14 | L2 | 脚本未声明 `script.query.*` / `script.command.*` / `script.events.subscribe` | 脚本调用 `sn.query`、`sn.command`、`sn.events.on` 各一次 | 均返回 `script.permission_denied`（S0-2 附录 A）；命令队列计数 = 0；订阅数 = 0；`GameState.hash()` 不变 | API 返回快照 + 队列/订阅计数 + hash | S2 |
| TC-AUTH-005 | TM-AUTH-03、TM-BR-01、TM-EXEC-02、INV-01、INV-15 | L2 | S0-1 §3.2–3.4 的 20 条候选 API 已定稿 | 对每个 API 用非法参数调用：错误类型、超深嵌套、超大字符串、NaN/Inf、nil、多余字段、未知事件名 | 每次均返回稳定错误码（`script.invalid_args` / `script.payload_depth` / `script.payload_too_large` / `script.value_not_serializable`）；宿主不崩溃、不写入；Lua 侧错误信封形状一致 | 表驱动 API 测试日志（覆盖 20 条 API） | S2 |
| TC-AUTH-006 | TM-STATE-01、TM-BR-01、INV-21 | L2 | 查询返回深拷贝契约（S0-1 §4.4） | 脚本修改 `result.value` 后再次查询；保存前后比较 `GameState.hash()`；尝试写 `save_schema/seed/mods` | 修改不影响宿主：二次查询值不变、`GameState.hash()` 不变；无任何脚本可调用的写 state API；存档头字段不可写 | hash 前后值 + 两次查询快照 diff | S2 |
| TC-AUTH-007 | TM-LEAK-03、TM-BR-04、INV-28 | L2 | 错误码金样文件（golden JSON）；S0-1 §4.3 稳定码清单 | 对同一失败路径重复 3 次，并在 Windows/Linux 各跑一次，采集 `{ok:false,error.code}` | `code` 集合完全一致且与金样逐字相等；`message_key` 变化不影响判定；出现未登记码或与 `details` 不一致 = 失败 | `code` 金样 diff + 双平台输出 | S2 |
| TC-AUTH-008 | TM-AUTH-01、INV-14 | L2 | 脚本已初始化 | 脚本在运行中尝试请求/注册新 capability；读取 `sn.mod.info()`；篡改 `sn.capabilities` 表（若存在） | 权限集合不可扩张；`granted` 与 manifest 声明经 `requested → granted` 计算后逐项一致；越权调用返回 `script.permission_denied` | `sn.mod.info()` 快照 + 授权日志 | S2 |
| TC-AUTH-009 | TM-AUTH-04、TM-LEAK-01、INV-16 | L2 | S0-1 §3.2 查询白名单与字段裁剪已定稿 | 对每个 API-Q 断言字段白名单：允许字段存在、被裁剪字段不存在（`hull_model_path`/`visual`/`contract`/`world_seed`/`roll` 等）；跨模组查询他人私有域 | 返回字段集合 == 白名单；未授权字段不出现（而不是返回 null）；未登记 query 返回 `script.unknown_api`；未探索信息不可见 | 字段集合断言表（7 条 Query 全覆盖） | S2 |
| TC-AUTH-010 | TM-AUTH-01、INV-14 | L1 | PoC 分支 | 用未声明 capability 的模组调用命令/查询，再声明后调用 | 未声明 → `script.permission_denied` 且 `GameState.hash()` 不变；声明后调用成功；修改能力表无效 | PoC 报告表 + 原始日志 | S1 |
| TC-AUTH-011 | TM-BR-05、INV-05 | L2 | `sn` 代理已按 S0-1 §4.1 实现 | `getmetatable(sn)`、`rawget/rawset`、`setmetatable`、`pairs(sn)`、替换 `sn.query` 各尝试一次 | 取不到内部表；写操作失败/无效；`pairs(sn)` 只出现公开 API 名；篡改后宿主仍按原授权表判定 | 代理探针矩阵 + 授权日志 | S2 |
| TC-AUTH-012 | TM-AUTH-02、INV-14 | L2 | A、B 两个脚本模组；脚本可构造 `mod_id` 参数 | A 传 `mod_id="core"`、B 的 id；A 读取 B storage；A 尝试触发 B 回调；伪造事件 source | 身份由宿主绑定不可伪造（`script.identity_mismatch`）；跨模组调用/storage/回调全部拒绝；B 的存储哈希不变 | 拒绝日志 + B 存储哈希 | S2 |
| TC-AUTH-013 | TM-LEAK-03、TM-BR-04、INV-28 | L2 | 候选 API 的错误码已收敛（S0-1 §4.3） | 遍历 `ship_id/port_id` 等对象 ID，比较“不存在”与“无权限”的返回码/时延 | 敏感对象统一 `not_found_or_denied`（按资源域定义不可区分）；`details` 白名单；错误文本走 `message_key` | 枚举结果矩阵 + 错误码 diff | S2 |

### 2.4 执行与生命周期（EXEC）

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-EXEC-001 | TM-SUPPLY-01（规则单源） | L0 | S0-1 的 20 条候选 API 与 OQ-01…16 | 逐条核对每个 `API-Q/E/C-nn`：版本、参数 Schema、返回/错误码、所需 capability、可见性分级；与本文件 §3.4 一一对应 | 5 项缺一即失败；`sn.*` 入口数量与清单一致；示例代码只用清单内 API（不得再使用 `ship.get`/`boiler_condition`/`ship.apply_damage` 之外的臆造名） | 文档对照表（§3.4） | S0 |
| TC-EXEC-002 | TM-BR-04、INV-04、INV-28 | L2 | 脚本已初始化 | 对成功/业务失败/参数错误三类调用各采集返回 | 成功严格 `{ok:true, value:...}`；失败严格 `{ok:false, error:{code, message_key, details?}}`（S0-1 §4.3）；不存在第三形态；`autosave/events` 不透传 | 三类返回快照 | S2 |
| TC-EXEC-003 | TM-AUTH-03、TM-SCHED-02、INV-15、INV-18 | L2 | 已声明 `script.command.*` | 脚本提交一个允许命令与一个被业务拒绝的命令；分别读取入队回执与结果通道（OQ-05） | `sn.command()` 只返回入队回执（`accepted/request_id`，不承诺成功）；业务结果只经版本化结果通道；被拒命令有稳定码且不入队 | 队列日志 + 回执/回调时序 | S2 |
| TC-EXEC-004 | TM-EXEC-06、INV-13 | L2 | 夹具：`on_load` 返回错误/抛错 | 启动并读取状态机 | `Initialized → Active` 仅在 `on_load` 成功后发生；失败 ⇒ `Disabled/Faulted` 且不订阅事件 | 状态机日志 | S2 |
| TC-EXEC-005 | TM-SCHED-05、TM-BR-02、INV-20 | L2 | 模组 Active、有订阅与队列请求 | 执行停用/卸载；再读计数；触发同名事件 | 订阅数=0、待执行请求=0、VM 已 dispose、私有状态已保存；旧 token 失效（`script.callback_stale`）；事件不再执行该回调 | 计数表 + 存档片段 + 事件计数 | S2 |
| TC-EXEC-006 | TM-SCHED-05、TM-BR-03、INV-20 | L2 | 同一模组重复 scan/load（含重复路径与 zip+loose 同名） | 连续加载两次，读 VM 计数与事件触发次数 | VM 计数始终 ≤1；重复加载幂等或明确拒绝；同一事件回调不被触发两次；`state_count` 与已启用脚本模组数一致 | VM 计数 + 事件计数 | S2 |
| TC-EXEC-007 | TM-EXEC-06、INV-13 | L2 | 可配置错误阈值（S1 定值） | 注入连续失败回调直到越过阈值；观察状态与 Core 状态 | 达阈值自动禁用该脚本（`Disabled`）并记录 `mod_id`/脚本/回调/错误码；其他模组与 Core 的 `GameState.hash()` 不受影响 | 状态表 + hash 对比 | S2 |
| TC-EXEC-008 | TM-EXEC-06、INV-13 | L1 | PoC 分支 | 注入入口语法错误、运行期错误、加载超时三类失败各一次；观察 VM 能否销毁并重试 | 每类都给出稳定错误码与脚本/行号摘要（不泄露宿主对象）；VM dispose 后无残留，可重新初始化 | PoC 报告表格 + 原始日志 | S1 |
| TC-EXEC-009 | TM-SUPPLY-02、INV-24 | L2 | 夹具：`script_api_version` 高于/低于宿主支持范围；`api_version` 单独非法 | 启动并观察入口是否执行 | 明确拒绝（`script.api_version_mismatch`），入口不执行、`vm_create=0`；`api_version` 错误走内容 Schema 错误；两者不得互相顶替（S0-1 §4.1） | 错误 JSON + 入口执行计数 | S2 |
| TC-EXEC-010 | TM-BR-02、INV-02、INV-20 | L1 | PoC 分支已注册回调并可销毁 state | 注册回调后销毁 state，再触发事件；尝试把回调 token 传给另一模组 | 0 次回调、无宿主错误（仅有 `script.callback_stale`）；token 跨模组传递被拒；重载后同一订阅只执行一次 | PoC 日志 + 回调计数 | S1 |
| TC-EXEC-011 | TM-EXEC-01、TM-EXEC-05、INV-10 | L2 | 指令预算/中断机制已实现（S1 选型） | 执行 `while true`、`while true do pcall(...) end`、协程无限调度、回调内注册新回调各一次 | 全部在预算内返回 `script.budget_exceeded` 或 `script.coroutine_denied`；进程存活、主线程恢复；无残留协程；连续多轮累计计数 | 中断耗时表 + 错误码 | S2 |
| TC-EXEC-012 | TM-BR-04、TM-LEAK-02、INV-04、INV-27 | L2 | 脚本可触发错误并调用 `sn.log` | 触发 Lua error、非法参数、超频日志；扫描错误 JSON、诊断日志、玩家可见 UI | 错误对象只含 `{code,message_key,details?}`；不含绝对路径/`res://`/`user://`/`GDScript`/类名；日志限频（`script.log_rate_limited`）且带 `mod_id`；玩家 UI 只显示本地化文本 | 日志扫描报告 + 错误 JSON 快照 | S2 |
| TC-EXEC-013 | TM-AUTH-03、INV-15 | L2 | 命令 allowlist 已按 S0-1 §3.4 定稿 | 调用白名单外命令（`run.start`/`fleet.add_ship`/`trade.*`/`combat.resolve` 等）；伪造 `autosave/source/events` 字段；传未知字段 | 全部拒绝（`script.command_rejected`/`script.invalid_args`）；被拒命令不产生领域事件、state 哈希不变；回执明确 `accepted:true` 仅表示入队 | 命令日志 + state hash | S2 |

### 2.5 调度与事务（SCHED）

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-SCHED-001 | TM-SCHED-01、INV-18 | L2 | A/B 两模组；A 在事件回调里提交会再次触发同事件的命令 | 触发一次；观察链深、队列长度、错误码 | 命令延迟到当前批次后提交，链深达上限即拒绝后续请求并记录来源（`script.event_chain_limit`）；进程不挂起、不栈溢出 | 事件链 trace（seq/来源/深度） | S2 |
| TC-SCHED-002 | TM-SCHED-03、INV-18 | L2 | A、B 订阅同一事件且顺序可观测 | 同种子连续跑 2 次，记录回调顺序；交换订阅注册顺序再跑 | 顺序恒为 `event sequence → mod order → subscription registration index`；两次完全一致；mod order 来自 `DependencyResolver` 稳定排序（S0-2 证据） | 顺序 trace + 两次 diff | S2 |
| TC-SCHED-003 | TM-SCHED-02、INV-18 | L2 | 单轮命令限额可配置（S1 定值） | 单批提交 N+1 个命令 | 第 N+1 个被明确拒绝（`script.batch_limit`）并记录来源；已入队的 N 个仍按序提交且只提交一次 | 队列计数 + 提交日志 | S2 |
| TC-SCHED-004 | TM-SCHED-04、INV-19 | L2 | 脚本在回调中先查询、后提交命令，再抛错 | 触发回调异常；比较异常前后状态 | 该回调**尚未提交**的请求被撤销；已提交的独立命令不回滚；`GameState.hash()` 可解释（仅含已提交部分）；错误码 `script.callback_failed` | 命令日志 + hash | S2 |
| TC-SCHED-005 | TM-SCHED-03、TM-STATE-01、INV-18、INV-21；OQ-06 | L2 | 两个模组在同批内“一个提交、一个查询” | 构造同批查询与命令；校验查询值所属快照 | 同批所有查询看到**批次开始时已提交状态**（OQ-06 建议值）；不出现同批命令的中间态 | 查询值 vs 状态检查点 | S2 |
| TC-SCHED-006 | TM-SCHED-01、TM-BR-02、INV-02、INV-18 | L2 | 重入护栏/调度器已实现 | 在事件回调里同步调用命令路径；检查 reentrancy 计数与回调 token | 回调内不直接进入 CommandBus（重入计数 = 0）；命令只入队，批次末尾统一提交；不得在回调外直接触发回调 | 重入护栏日志 + 时序 | S2 |
| TC-SCHED-007 | TM-PLATFORM-03、TM-PLATFORM-01、INV-26 | L3 | 同一事件序列与种子；Windows/Linux 导出产物 | 在两端各跑同一纵向样例并导出事件/命令 trace hash | 两端 trace 顺序与 hash 一致；不同帧率/暂停恢复不改变结果（无 delta 依赖）；差异即失败 | 双平台 trace + hash | S3 |
| TC-SCHED-008 | TM-SCHED-01、TM-SCHED-02、INV-18 | L2 | 高频事件（`market.changed` / `sim.tick`）与限频/合并策略已实现 | 一帧内触发大量 `market.changed`（≥10³）与一次多 tick 的 `sim.advance`；记录回调次数、合并后事件数、批次耗时 | 回调按限频/合并策略执行（不逐条淹没主线程），丢弃/合并计数可观测且稳定；批次耗时有上界；事件顺序仍可由 `event sequence → mod order → registration index` 解释 | 回调计数 + 合并计数 + 批次耗时 | S2 |

### 2.6 存档、确定性与存储（STATE）

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-STATE-001 | TM-AUTH-05、TM-STATE-02、INV-17 | L2 | 模组 A、B 各写 `sn.storage` | A 写 key 后 B 读同名 key；再 save/load；尝试写 `<mod_id>/` 前缀之外的 key | 命名空间强制前缀：B 读不到 A 的值；往返后 A 值逐字相等；跨模组 key 返回 `script.storage_denied` | 存储快照 + 往返 diff | S2 |
| TC-STATE-002 | TM-STATE-02、TM-SCHED-05、INV-20、INV-22 | L2 | 已实现 `script_states[mod_id]` | 存档 → 检查 JSON → 载入 → 读取订阅与状态 | 存档只含 JSON-like 值 + 不透明 `rng_state`；无函数/VM 栈帧；载入后重新绑定订阅（订阅数与事件触发次数正确） | 存档 JSON schema 校验 + 订阅计数 | S2 |
| TC-STATE-003 | TM-STATE-05、TM-PLATFORM-02、INV-23 | L2 | 固定 Campaign seed + 固定事件序列 | 完整跑两遍（含脚本随机与命令）；比较 `GameState.hash()`、脚本 RNG 输出、命令序列；尝试通过 API 写 `rng_state` | 三者逐项一致；系统时钟/原生随机不可达；`rng_state` 不可由 Lua 写；同种子重放一致 | 两次运行的 hash/序列 diff | S2 |
| TC-STATE-004 | TM-STATE-05、INV-23 | L2 | 同一初始状态 | 分支 1 跑 N 步不存档；分支 2 在第 k 步存档再载入后跑完 | 两分支最终状态 hash 与脚本输出一致；存档动作本身不改变模拟 | 双分支 hash + 输出 | S2 |
| TC-STATE-005 | TM-STATE-04、TM-AUTH-05、INV-11、INV-17 | L2 | 配额可配置（键数/单值大小/总量；S1 定值） | 逐项越过配额写入；检查存档字节数 | 越界返回 `script.storage_quota`，不写盘；存档大小不随恶意写入膨胀；已合法数据不受影响 | 写入结果 + 存档字节数 | S2 |
| TC-STATE-006 | TM-STATE-02、INV-22 | L2 | 存档含模组 A 的 `script_states`，运行环境无 A | 载入并存档，检查行为与数据；再验证显式清理路径 | 保留 A 的可识别数据、不执行其行为；卸载清理必须经显式选择；不得静默删除或静默执行；Core 存档可读 | 存档 diff + 行为日志 | S2 |
| TC-STATE-007 | TM-STATE-03、INV-22 | L2 | 旧 `storage_schema` 存档 + 新脚本版本 | 触发迁移失败路径 | 标记该模组脚本不可用（`script.state_migration_failed`）、保留备份且不覆盖原数据；Core 存档可正常载入 | 迁移结果 + 备份文件 | S2 |
| TC-STATE-008 | TM-PLATFORM-01、INV-26 | L3 | Windows 生成存档，Linux 载入（反之亦然） | 两端往返并比较状态 hash | 往返后 hash 一致；int/float 量化（1e-9）与 UTF-8 文本一致 | 双平台存档 + hash | S3 |

### 2.7 沙箱隔离（ISO）

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-ISO-001 | TM-EXEC-01、INV-10 | L1 | PoC VM 支持指令预算或中断 | 回调执行 `while true do end`；记录中断耗时、错误码、VM 状态 | 必须**可靠中断**（指令预算/中断机制，不能只靠墙钟超时）；返回 `script.budget_exceeded`；主线程恢复且不退出进程；重复 10 次均中断 | PoC 报告耗时表 + 日志 | S1 |
| TC-ISO-002 | TM-ISO-01、TM-PLATFORM-02、INV-06 | L1 | PoC 环境 | 脚本探测 `io`、`os`、`debug`、`package.loadlib`、`require` 外部模块、系统时间/随机 | 全部不可用（nil 或 `script.library_unavailable`）；尝试读/写文件、读环境变量均无宿主副作用；Windows/Linux 一致 | PoC 探测矩阵表 | S1 |
| TC-ISO-003 | TM-ISO-01、INV-06 | L2 | 集成环境 | 脚本尝试 `ffi`、`loadlib`、`package.loadlib`、原生扩展加载 | 全部不可达；错误可判定；无原生符号解析 | API 探测结果 + 审计日志 | S2 |
| TC-ISO-004 | TM-BR-03、INV-03 | L2 | A、B 两个脚本模组 | A 修改全局变量/模块表/`package.loaded`；B 读取同名全局 | 每个模组独立 state；B 看不到 A 的全局；A 崩溃不影响 B 的 state；`active_script_state_count == active_script_mod_count` | 两模组探测值 + state 计数 | S2 |
| TC-ISO-005 | TM-BR-01、INV-01、INV-21 | L2 | 所有跨界 API | 对每个 API 返回值做类型审计；脚本尝试访问 userdata/Object/function/引擎值类型 | 返回值域仅 string/number/boolean/nil/受约束 array/dict；出现 Object/Callable/RID/FileAccess/Vector* 即失败；`script.value_not_serializable` | 类型审计表 + 审计日志 | S2 |
| TC-ISO-006 | TM-ISO-01、TM-ISO-02、TM-PLATFORM-01、TM-SUPPLY-04、INV-06、INV-07、INV-26 | L1 | Windows/Linux 两个 PoC 构建 | 在两端各跑路径逃逸、`os.getenv`、`io.open`、`loadlib` 探测集合；在两端导出产物中创建/执行/销毁 state | 两端拒绝结果一致（错误码/不可达状态一致）；state 可创建/执行/销毁；任一端放行即失败 | PoC 报告双平台表 | S1 |
| TC-ISO-007 | TM-EXEC-02、INV-11 | L2 | 内存上限可配置（S1 定值） | 脚本循环分配大表/超长字符串直到上限；观察错误与进程 | 达上限被中断（`script.memory_exceeded`），VM 可销毁；宿主进程不 OOM、其他模组不受影响；峰值内存有记录 | 内存曲线 + 错误码 | S2 |
| TC-ISO-008 | TM-EXEC-06、TM-BR-03、INV-13 | L2 | 三个模组：故障 A、正常 B、Core | 注入 A 的超预算/抛错/内存超限；观察 B 与 Core | A 被禁用/中断；B 继续正常触发；Core `GameState.hash()` 与错误注入前一致（除 A 的合法提交） | 三方状态/计数表 | S2 |
| TC-ISO-009 | TM-BR-01、INV-01 | L1 | PoC 分支；可注入“故意返回 Object/Resource/Node/Callable”的测试 API | 调用该 API；在 Lua 侧断言返回类型与 `getmetatable` | 宿主返回 `script.value_not_serializable`；Lua 侧 `type(v)` 只可能是 nil/boolean/number/string/table；`getmetatable` 取不到宿主元表；`GameState.hash()` 不变 | PoC 日志 + 类型断言表 | S1 |
| TC-ISO-010 | TM-BR-03、INV-03 | L1 | PoC 分支；可同时加载 A/B | A 写 `_G`、覆盖 `sn`、注入模块缓存；B 读取；销毁 A 后继续触发 B | B 不可见 A 的修改；`state_count` 与模组数一致；销毁 A 不影响 B；两 state 不共享 registry/`package.loaded` | PoC 隔离矩阵 | S1 |
| TC-ISO-011 | TM-EXEC-02、INV-11 | L1 | PoC 分支；内存上限可测 | 分配超过上限；记录峰值内存、上限、错误与进程 RSS | 返回 `script.memory_exceeded` 且进程存活；记录“可计量内存”与 RSS 差异；Windows/Linux 各一次 | PoC 测量表 | S1 |
| TC-ISO-012 | TM-ISO-03、TM-ISO-04、INV-08、INV-09 | L2 | S0-1 §4.6 的 `.lua` 白名单与 text-only 加载已实现 | 断言 `require` 默认不可用/仅包内白名单；篡改 `package.path`；提交 `.luac`/二进制 chunk/`string.dump`；在扫描、加载、打包三处各试一次 | 外部模块返回 `script.module_denied`；`package.path/cpath` 不可写；`.luac`/二进制 chunk 三处均拒绝（`script.bytecode_denied`/`invalid_script_path`）；A 的模块对 B 不可见 | 探测结果 + 三处拒绝日志 | S2 |
| TC-ISO-013 | TM-EXEC-03、INV-12 | L2 | 深度上限可配置 | 无限递归/互相递归/`__index` 递归/深嵌套参数；宿主递归序列化深表 | 达上限返回受控错误（`script.stack_overflow` / `script.payload_depth`）；宿主存活、无 GDScript 栈溢出 | 深度测试日志 + 进程状态 | S2 |
| TC-ISO-014 | TM-ISO-05、INV-05、INV-06 | L2 | 全局环境最小化已实现 | 断言 `_ENV` 修改无效、`getfenv/setfenv` 不存在、`string.dump` 不存在；执行常见 `load` 逃逸 payload | 逃逸 payload 全部失败且返回稳定错误；无库恢复；篡改不改变宿主授权 | 逃逸用例集结果 + 审计日志 | S2 |

### 2.8 资源与预算（RES）

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-RES-001 | TM-EXEC-02、TM-EXEC-04、INV-11 | L2 | 可重复创建销毁 | 创建-执行-销毁 100 次；采样宿主内存与句柄数；记录 GC 停顿 | 内存/句柄无单调增长趋势（阈值由 L1 基线给出并在用例中固定）；无残留 VM；GC 停顿峰值可测且不超过预算（S1 基准，T-OQ-02） | 采样表（次数/内存/句柄/GC） | S2 |
| TC-RES-002 | TM-SCHED-05、INV-20 | L2 | 脚本已订阅并有排队命令 | 卸载后读计数；再次触发同名事件 | 订阅=0、队列=0、定时器/回调注册=0；事件触发后 0 回调执行；重载后单次执行 | 计数表 + 事件触发计数 | S2 |
| TC-RES-003 | TM-LEAK-02、INV-27 | L2 | 日志速率上限可配置（S1 定值） | 脚本高频 `sn.log`；扫描日志内容 | 超限日志被丢弃并计数（`script.log_rate_limited`）；速率不超过上限；日志文件大小有界；日志含 `mod_id` 且无绝对路径/对象引用 | 日志采样 + 计数 | S2 |
| TC-RES-004 | TM-EXEC-02、TM-EXEC-04、INV-11 | L1 | PoC 分支 | 测量每 state 常驻内存、创建/销毁开销、典型回调峰值与 GC 时间；给出建议上限 | 报告给出可复现测量表与建议上限；不把未测数值写成承诺；区分“可计量内存”与进程 RSS | `LUA_HOST_POC_REPORT.md` 测量章节 | S1 |

### 2.9 运行时供应链与版本（SUPPLY）

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-SUPPLY-001 | TM-SUPPLY-04、INV-25 | L0 | S1 选型记录（T-OQ-01） | 核查运行时选型文档是否含：版本、许可证、Godot 4.7.2 兼容性、Windows/Linux 构建步骤、二进制来源与校验方式、ABI/架构 | 缺任一项 = 失败；未记录的实现不得进入 S2 | 选型记录清单 | S0/S1 |
| TC-SUPPLY-002 | TM-SUPPLY-04、TM-PLATFORM-04、INV-25、INV-26 | L2 | 导出产物 | 检查 Windows/Linux 导出目录是否含 VM 所需库文件与 LICENSE 清单；在产物上跑一次最小脚本 | 库齐全、LICENSE 列出全部第三方组件；产物上脚本可创建/执行/销毁；VM 版本/哈希可追溯 | 产物文件清单 + 运行日志 | S2 |
| TC-SUPPLY-003 | TM-AUTH-01、TM-SUPPLY-02、INV-24 | L2 | 现有 `DependencyResolver` / `ModLoader`；S0-1 §4.7 能力分桶 | 用缺失依赖、版本冲突、capability 不满足（含 `script.*` 未知）的脚本模组加载 | 走现有依赖解析与冲突检查；`required=true` 时 capability 失败 fatal，可选模组脚本能力失败仅禁用脚本层、内容照常；错误带 `scope` | 加载报告 | S2 |
| TC-SUPPLY-004 | TM-SUPPLY-02、INV-24 | L0 | `content_types.json` 为真源 | diff active 类型集合；运行 `gen_content_types --check`；核对四类版本（`api_version`/`script_api_version`/Content Schema/Save Schema）独立 | active 类型集合不变；`--check` exit 0；四类版本不混用（文档与 manifest 示例逐项核对） | git diff + 检查输出 | S0 |

### 2.10 平台导出与发布（PLATFORM）

| ID | 对应威胁/不变量 | 级别 | 前置条件 | 步骤 | 预期与判定标准（观测点） | 证据 | 阶段 |
|---|---|---|---|---|---|---|---|
| TC-PLATFORM-001 | TM-PLATFORM-01、TM-SUPPLY-04、INV-25、INV-26 | L3 | `v*` tag 导出的 Windows 产物 | 在导出产物上跑纵向样例：创建 state → 订阅公开事件 → 查询只读视图 → 提交允许命令 → 销毁 | 全链路成功；错误码/返回信封与开发环境一致；无缺失库错误；路径大小写/分隔符用例一致 | 导出产物运行日志 | S3 |
| TC-PLATFORM-002 | TM-PLATFORM-01、TM-SUPPLY-04、INV-25、INV-26 | L3 | Linux 导出产物 | 同 TC-PLATFORM-001 | 同 TC-PLATFORM-001 | 导出产物运行日志 | S3 |
| TC-PLATFORM-003 | TM-PLATFORM-01、TM-PLATFORM-02、TM-PLATFORM-03、INV-26、INV-23 | L3 | 两平台导出产物 + 固定种子/事件序列 | 两端跑同一序列并比较 trace hash 与状态 hash；不同帧率/暂停恢复再跑 | 两平台 hash 完全一致；帧率/暂停不影响结果；不一致即阻断发布 | 双平台 hash 对照表 | S3 |
| TC-PLATFORM-004 | TM-SUPPLY-01、TM-SUPPLY-05、INV-25 | L3 | `pack_mod.gd --release` 与脚本验收状态标记 | 对“含脚本且未通过 S1/S2 沙箱验收”的模组执行 `pack --release`；再对已验收模组执行 | 未验收必须 exit 1 且不写 zip；已验收按内容+脚本清单门禁通过；不得以脚本语法检查通过替代 | `pack` 日志 + zip 存在性断言 | S3 |
| TC-PLATFORM-005 | TM-SUPPLY-05、INV-25 | L3 | release workflow | 检查 `dist/release/*.zip` 与 `dist/mods/*.snavmod.zip` 的 `SHA256SUMS.txt` | 每个发布产物都在 sums 中且 `sha256sum -c` 通过；产物清单与 release 附件一致；篡改包可检测 | `SHA256SUMS.txt` + 校验输出 | S3 |

**矩阵规模**：**83** 条 `TC-*`（10 个测试域，分布见 §8 自检表），覆盖 S0-2 的 44 条威胁与 28 条不变量、S0-1 的 20 条候选 API。

---

## 3. 覆盖核对

### 3.1 双向覆盖规则

1. **TM → TC**：S0-2 的每条 `TM-*` 必须在 §3.2 有行；阻断项必须映射到 ≥1 条 L1 + ≥1 条 L2/L3 直接用例（§3.5）。没有直接用例的标“间接”并写明补测建议，不得留空。
2. **INV → TC**：S0-2 的每条 `INV-*` 必须在 §3.3 有行，至少一条 L1/L2 用例；未覆盖必须给理由与补测建议。
3. **API → TC**：S0-1 的每条候选 API（20 条）必须在 §3.4 有行，且成功路径 / 参数或载荷非法 / 能力缺失三类都有映射；缺口写清是“测试缺口”还是“实现缺口”。
4. **TC → 需求**：每条 TC 必须指回至少一个 TM 或 API 或 S0-2 门槛；孤儿用例删除。
5. **安全结论**：覆盖表只证明“有观测点”，不证明“已安全”。发布评审必须同时看 S1 PoC 报告、代码审计与 L2 结果（S0-2 §0.2）。

### 3.2 TM → 测试覆盖表（44/44）

| TM | 摘要 | 阻断 | 对应用例 | 状态 |
|---|---|---|---|---|
| TM-BR-01 | 桥接泄漏 Godot Object/userdata | 是 | TC-ISO-009（L1）、TC-ISO-005、TC-AUTH-005、TC-EXEC-002 | 直接 |
| TM-BR-02 | Callable/回调句柄逃逸与跨批次重入 | 是 | TC-EXEC-010（L1）、TC-EXEC-005、TC-SCHED-006 | 直接 |
| TM-BR-03 | 每模组 state 未隔离 | 是 | TC-ISO-010（L1）、TC-ISO-004、TC-EXEC-006 | 直接 |
| TM-BR-04 | 异常回溯/错误详情泄漏 | 否 | TC-EXEC-012、TC-AUTH-007 | 直接 |
| TM-BR-05 | `sn` 代理元表/rawget 越权 | 否 | TC-AUTH-011 | 直接 |
| TM-ISO-01 | 危险标准库可达 | 是 | TC-ISO-002（L1）、TC-ISO-003、TC-ISO-006 | 直接 |
| TM-ISO-02 | 脚本/内容路径穿越 | 是 | TC-ISO-006（L1）、TC-AUTH-001（L0）、TC-AUTH-002、TC-LOAD-004 | 直接 |
| TM-ISO-03 | require 外部解析/白名单绕过 | 否 | TC-ISO-012 | 直接 |
| TM-ISO-04 | Lua 字节码/预编译注入 | 否 | TC-ISO-012 | 直接 |
| TM-ISO-05 | 全局环境/_ENV/upvalue/load 逃逸 | 否 | TC-ISO-014、TC-ISO-002 | 直接 |
| TM-EXEC-01 | 无限循环不可中断 | 是 | TC-ISO-001（L1）、TC-EXEC-011 | 直接 |
| TM-EXEC-02 | 内存轰炸/超长字符串/超大表 | 是 | TC-ISO-011（L1）、TC-ISO-007、TC-RES-001、TC-AUTH-005 | 直接 |
| TM-EXEC-03 | 深递归/栈溢出 | 否 | TC-ISO-013 | 直接 |
| TM-EXEC-04 | GC 压力与分配抖动 | 否 | TC-RES-001、TC-RES-004 | 间接（无独立 GC 断言，S1 基准 T-OQ-02 补） |
| TM-EXEC-05 | 预算绕过（pcall/协程/重入） | 否 | TC-EXEC-011、TC-SCHED-006 | 直接 |
| TM-EXEC-06 | 故障隔离失败/半初始化 | 是 | TC-EXEC-008（L1）、TC-EXEC-004、TC-EXEC-007、TC-LOAD-002、TC-LOAD-005、TC-ISO-008 | 直接 |
| TM-AUTH-01 | 声明即授权/动态提权 | 是 | TC-AUTH-010（L1）、TC-AUTH-003、TC-AUTH-004、TC-AUTH-008、TC-LOAD-002 | 直接 |
| TM-AUTH-02 | 跨模组调用/mod_id 伪造 | 否 | TC-AUTH-012 | 直接 |
| TM-AUTH-03 | 命令白名单绕过/参数伪造 | 否 | TC-EXEC-013、TC-AUTH-005、TC-EXEC-003 | 直接 |
| TM-AUTH-04 | 查询权限/字段裁剪绕过 | 否 | TC-AUTH-009、TC-AUTH-005 | 直接 |
| TM-AUTH-05 | storage 命名空间/配额 | 否 | TC-STATE-001、TC-STATE-005 | 直接 |
| TM-SCHED-01 | 事件递归链/事件风暴 | 否 | TC-SCHED-001、TC-SCHED-006、TC-SCHED-008 | 直接 |
| TM-SCHED-02 | 命令风暴/批次预算绕过 | 否 | TC-SCHED-003、TC-EXEC-003、TC-SCHED-008 | 直接 |
| TM-SCHED-03 | 回调顺序不确定/跨模组重入 | 否 | TC-SCHED-002、TC-SCHED-005、TC-SCHED-007、TC-PLATFORM-003 | 直接 |
| TM-SCHED-04 | 回调异常回滚不完整 | 否 | TC-SCHED-004 | 直接 |
| TM-SCHED-05 | 卸载/重载悬挂订阅与队列残留 | 否 | TC-EXEC-005、TC-EXEC-006、TC-RES-002、TC-STATE-002 | 直接 |
| TM-STATE-01 | 绕过 CommandBus 污染 GameState | 否 | TC-AUTH-006、TC-ISO-005、TC-SCHED-005 | 直接 |
| TM-STATE-02 | 跨模组存档命名空间越权 | 否 | TC-STATE-001、TC-STATE-002、TC-STATE-006 | 直接 |
| TM-STATE-03 | 脚本状态迁移失败/半迁移 | 否 | TC-STATE-007 | 直接 |
| TM-STATE-04 | 存档膨胀/存储资源耗尽 | 否 | TC-STATE-005 | 直接 |
| TM-STATE-05 | RNG 状态篡改/重放分歧 | 否 | TC-STATE-003、TC-STATE-004、TC-PLATFORM-003 | 直接 |
| TM-SUPPLY-01 | 脚本与内容/打包产物不一致 | 否 | TC-LOAD-006、TC-PLATFORM-004、TC-COMPAT-003、TC-COMPAT-005 | 直接 |
| TM-SUPPLY-02 | script_api_version 与 api_version 混淆 | 否 | TC-EXEC-009、TC-LOAD-001、TC-COMPAT-006、TC-AUTH-001 | 直接 |
| TM-SUPPLY-03 | 无 Lua 运行时静默忽略脚本 | 否 | TC-LOAD-003（L1）、TC-COMPAT-001/002 | 直接（L1，S2 晋级 L2） |
| TM-SUPPLY-04 | 平台导出后 Lua 不可用/供应链 | 否 | TC-SUPPLY-001、TC-SUPPLY-002、TC-PLATFORM-001/002、TC-ISO-006 | 直接 |
| TM-SUPPLY-05 | 发布完整性缺失 | 否 | TC-PLATFORM-005、TC-PLATFORM-004、TC-COMPAT-007 | 直接 |
| TM-LEAK-01 | 查询返回内部字段/未探索信息 | 否 | TC-AUTH-009、TC-AUTH-006 | 直接 |
| TM-LEAK-02 | 日志泄露宿主路径/其他模组/玩家数据 | 否 | TC-EXEC-012、TC-RES-003 | 直接 |
| TM-LEAK-03 | 错误码侧信道与对象枚举 | 否 | TC-AUTH-013、TC-AUTH-007 | 直接 |
| TM-LEAK-04 | 时序/性能侧信道 | 否 | TC-ISO-002（系统计时不可达）、TC-STATE-003 | 间接（S0-2 明确接受残余风险；无稳定可利用信号属 S1 评估项） |
| TM-PLATFORM-01 | 路径/大小写/浮点/排序差异 | 否 | TC-PLATFORM-001/002/003、TC-SCHED-007、TC-STATE-008、TC-ISO-006 | 直接 |
| TM-PLATFORM-02 | 系统时钟/原生随机影响行为 | 否 | TC-ISO-002（L1）、TC-STATE-003、TC-PLATFORM-003 | 直接 |
| TM-PLATFORM-03 | 帧率/调度时机相关行为 | 否 | TC-SCHED-007、TC-PLATFORM-003、TC-SCHED-002 | 间接（缺帧率变化/暂停恢复专项，列 §3.6 补测） |
| TM-PLATFORM-04 | 导出 VM 缺失/ABI 差异 | 否 | TC-SUPPLY-002、TC-PLATFORM-001/002、TC-ISO-006 | 直接 |

**统计**：44/44 有映射；直接 **41**、间接 **3**（TM-EXEC-04、TM-LEAK-04、TM-PLATFORM-03）；未覆盖 0。

### 3.3 INV → 测试覆盖表（28/28）

| INV | 断言摘要 | 对应用例 | 状态 |
|---|---|---|---|
| INV-01 | 跨界值白名单，Object/userdata 拒绝 | TC-ISO-009（L1）、TC-ISO-005、TC-AUTH-005、TC-EXEC-002 | 直接 |
| INV-02 | 回调只以宿主句柄存在，失效返回 `script.callback_stale` | TC-EXEC-010（L1）、TC-EXEC-005、TC-SCHED-006 | 直接 |
| INV-03 | 每模组独立 state，state 数=模组数 | TC-ISO-010（L1）、TC-ISO-004、TC-EXEC-006 | 直接 |
| INV-04 | 错误对象仅 `{code,message_key,details?}`，无路径/栈 | TC-EXEC-012、TC-AUTH-007、TC-EXEC-002 | 直接 |
| INV-05 | `sn` 冻结只读代理，篡改无效 | TC-AUTH-011、TC-ISO-014 | 直接 |
| INV-06 | 危险库/系统时间/随机不可达 | TC-ISO-002（L1）、TC-ISO-003、TC-ISO-006、TC-STATE-003 | 直接（双平台在 ISO-006） |
| INV-07 | 路径规范化且限制模组根，`entry` 在 `scripts/` 下 | TC-AUTH-001（L0）、TC-AUTH-002、TC-LOAD-004、TC-ISO-006 | 直接 |
| INV-08 | `require` 默认不可用/仅包内白名单 | TC-ISO-012 | 直接 |
| INV-09 | 仅 UTF-8 `.lua`，字节码三处拒绝 | TC-ISO-012 | 直接 |
| INV-10 | 指令预算+可靠中断，pcall/协程不能绕过 | TC-ISO-001（L1）、TC-EXEC-011 | 直接 |
| INV-11 | 内存/大小上限且不落盘 | TC-ISO-011（L1）、TC-ISO-007、TC-STATE-005、TC-RES-001 | 直接 |
| INV-12 | 递归深度上限，受控错误 | TC-ISO-013 | 直接 |
| INV-13 | 状态机与故障隔离，失败不影响 Core | TC-EXEC-008（L1）、TC-EXEC-004、TC-EXEC-007、TC-LOAD-002/005 | 直接 |
| INV-14 | 逐调用授权、身份不可伪造、无副作用 | TC-AUTH-010（L1）、TC-AUTH-004、TC-AUTH-008、TC-AUTH-012 | 直接 |
| INV-15 | 命令 allowlist + 参数 schema，宿主字段不可设 | TC-EXEC-013、TC-AUTH-005、TC-EXEC-003 | 直接 |
| INV-16 | 查询公开字段白名单与迷雾裁剪 | TC-AUTH-009、TC-AUTH-005 | 直接 |
| INV-17 | storage 前缀/配额/JSON-like/跨模组拒绝 | TC-STATE-001、TC-STATE-005 | 直接 |
| INV-18 | 调度顺序/链深/批次上限/来源可追踪 | TC-SCHED-001/002/003/008、TC-PLATFORM-003 | 直接 |
| INV-19 | 异常只回滚未提交命令组 | TC-SCHED-004 | 直接 |
| INV-20 | 停用/重载/销毁后订阅与队列失效，重载幂等 | TC-EXEC-005/006/010、TC-RES-002、TC-STATE-002 | 直接 |
| INV-21 | 仅 CommandBus 可写，深拷贝只读，存档头不可写 | TC-AUTH-006、TC-ISO-005、TC-SCHED-005 | 直接 |
| INV-22 | `script_states[mod_id]` 宿主写入/结构校验/迁移降级 | TC-STATE-002/006/007 | 直接 |
| INV-23 | RNG 宿主持有、游戏时钟、重放一致 | TC-STATE-003/004、TC-PLATFORM-003 | 直接 |
| INV-24 | 四类版本独立，无 VM 必须显式失败 | TC-EXEC-009、TC-LOAD-003（L1）、TC-COMPAT-006、TC-SUPPLY-004 | 直接（无 VM 的 L2 回归待 S2 晋级） |
| INV-25 | 发布同时校验内容+脚本、哈希可复算、结构一致 | TC-LOAD-006、TC-PLATFORM-004/005、TC-COMPAT-003、TC-SUPPLY-002 | 直接 |
| INV-26 | 双平台同序列同 hash，路径/排序/浮点一致 | TC-PLATFORM-003、TC-STATE-008、TC-SCHED-007、TC-ISO-006 | 直接 |
| INV-27 | 日志带 `mod_id`、限频、限长、脱敏 | TC-RES-003、TC-EXEC-012 | 直接 |
| INV-28 | 错误码稳定收敛，未授权/不存在不可区分 | TC-AUTH-013、TC-AUTH-007、TC-EXEC-002 | 直接 |

**统计**：28/28 有映射；直接 26、间接 2（INV-24 的无 VM L2、INV-06 的系统时间双平台部分；均在各行注明补测阶段）。

### 3.4 候选 API → 测试覆盖表（20/20）

> 20 条候选 API 来自 S0-1 §3.2–3.4。当前 `framework/scripting/` 不存在，所有映射都是**已定契约的 L2 用例编号**；状态列区分“测试缺口”（用例已存在但实现未完成）与“实现缺口”（S2 需新增宿主投影/命令）。

| API | 契约要点 | 成功路径 | 参数/载荷非法 | 能力缺失 | 状态 / 缺口 |
|---|---|---|---|---|---|
| API-Q-01 `ship.get` | 旗舰船投影，不含资产路径/visual | TC-AUTH-009、TC-COMPAT-002 | TC-AUTH-005 | TC-AUTH-004/010 | 映射完整；**实现缺口**：S2 新增宿主投影 |
| API-Q-02 `ship.cargo` | 货舱字段裁剪（无 `average_cost`） | TC-AUTH-009 | TC-AUTH-005 | TC-AUTH-004/010 | 映射完整；实现缺口：宿主投影 |
| API-Q-03 `market.snapshot` | 仅当前港市场字段 | TC-AUTH-009 | TC-AUTH-005 | TC-AUTH-004/010 | 映射完整；实现缺口：宿主投影 |
| API-Q-04 `voyage.preview` | 复用 Q-04，裁 `contract`/`risk_sources` | TC-AUTH-009 | TC-AUTH-005 | TC-AUTH-004/010 | 映射完整；现有 Query 可复用（裁剪层需实现） |
| API-Q-05 `sim.clock` | 复用 Q-16，删 `systems[]` | TC-AUTH-009 | TC-AUTH-005 | TC-AUTH-004/010 | 映射完整；现有 Query 可复用 |
| API-Q-06 `fleet.get` | 只保留稳定 ID/数值 | TC-AUTH-009 | TC-AUTH-005 | TC-AUTH-004/010 | 映射完整；实现缺口：宿主投影 |
| API-Q-07 `campaign.status` | 不含 `world_seed`/codex/探索规则 | TC-AUTH-009 | TC-AUTH-005 | TC-AUTH-004/010 | 映射完整；实现缺口：宿主投影 |
| API-E-01 `voyage.completed` | payload `{destination, arrival_time, chosen_option?}` | TC-EXEC-004、TC-SCHED-002 | TC-AUTH-005、TC-EXEC-002 | TC-AUTH-004 | 映射完整；PoC 首选事件（§11.1-2） |
| API-E-02 `port.arrived` | 与 E-46 同批，注意去重 | TC-EXEC-004、TC-SCHED-002 | TC-AUTH-005、TC-EXEC-002 | TC-AUTH-004 | 映射完整 |
| API-E-03 `market.changed` | 高频事件需限频/合并 | TC-EXEC-004、TC-SCHED-008 | TC-AUTH-005 | TC-AUTH-004 | 映射完整（限频/合并由 TC-SCHED-008 覆盖） |
| API-E-04 `contract.completed` | 裁剪到 `instance_id/template_id/on_time/payout/arrival_time` | TC-EXEC-004 | TC-AUTH-005、TC-EXEC-002 | TC-AUTH-004 | 映射完整 |
| API-E-05 `combat.resolved` | 不暴露 `settlement_key` | TC-EXEC-004 | TC-AUTH-005 | TC-AUTH-004 | 映射完整 |
| API-E-06 `ship.module_crafted` | 与 C-28 `ship.craft_ordered` 区分 | TC-EXEC-004 | TC-AUTH-005 | TC-AUTH-004 | 映射完整 |
| API-E-07 `run.victory_achieved` | 不含 `seed` | TC-EXEC-004、TC-AUTH-009 | TC-AUTH-005 | TC-AUTH-004 | 映射完整（payload 裁剪含在 AUTH-009 字段断言） |
| API-E-08 `clue.acquired` | 目标港/可信度不在 payload | TC-EXEC-004 | TC-AUTH-005 | TC-AUTH-004 | 映射完整 |
| API-C-01 `sim.set_speed` | 复用 C-35，有界 | TC-EXEC-003 | TC-AUTH-005、TC-EXEC-013 | TC-AUTH-004 | 映射完整；现有命令可复用 |
| API-C-02 `notice.emit` | 新宿主用例，包装 `emit_notice` | TC-EXEC-003 | TC-AUTH-005、TC-EXEC-013 | TC-AUTH-004 | **实现缺口**：S2 新增宿主命令，用例在实现前不可运行 |
| API-C-03 `ship.apply_damage` | 新宿主用例，包装 `damage_ship` | TC-EXEC-003 | TC-AUTH-005、TC-EXEC-013 | TC-AUTH-004 | 实现缺口：S2 新增宿主命令 |
| API-C-04 `quest.start` | 复用 C-22，需脚本侧错误映射 | TC-EXEC-003 | TC-AUTH-005、TC-EXEC-013 | TC-AUTH-004 | 映射完整；实现缺口：Quest 前置/重复校验错误映射 |
| API-C-05 `supply.repair` | 复用 C-06，仅玩家船 | TC-EXEC-003 | TC-AUTH-005、TC-EXEC-013 | TC-AUTH-004 | 映射完整；现有命令可复用 |

**统计**：20/20 有映射，三类断言（成功/非法/能力缺失）均覆盖；0 条无映射。**测试缺口 0 条**；**实现缺口 7 条**（API-Q-01/02/03/06/07 共 5 个宿主投影、API-C-02/03 共 2 个新宿主命令），另有 API-C-04 的脚本侧错误映射 1 项小缺口；均为 S2 任务，不阻塞本矩阵。错误码字符串以 S0-1 §4.3 的点分形式为准。

### 3.5 阻断项覆盖核对（9/9 全绿）

| 阻断 TM | 依据（S0-2 §6.3） | L1 证据用例 | L2/L3 回归用例 | 状态 |
|---|---|---|---|---|
| TM-BR-01 | §14 第 2 条 | TC-ISO-009 | TC-ISO-005、TC-AUTH-005 | 全绿 |
| TM-BR-02 | §14 第 2 条 / §11.1-1 | TC-EXEC-010 | TC-EXEC-005、TC-SCHED-006 | 全绿 |
| TM-BR-03 | §11.1-1 | TC-ISO-010 | TC-ISO-004、TC-EXEC-006 | 全绿 |
| TM-EXEC-01 | §11.1-3 / §14 第 1 条 | TC-ISO-001 | TC-EXEC-011 | 全绿 |
| TM-EXEC-02 | §11.1-3 | TC-ISO-011 | TC-ISO-007、TC-RES-001 | 全绿 |
| TM-EXEC-06 | §11.1-4 | TC-EXEC-008 | TC-EXEC-004/007、TC-LOAD-002/005 | 全绿 |
| TM-ISO-01 | §11.1-3 | TC-ISO-002 | TC-ISO-003、TC-ISO-006 | 全绿 |
| TM-ISO-02 | §11.1-3 | TC-ISO-006 | TC-AUTH-002、TC-LOAD-004 | 全绿 |
| TM-AUTH-01 | §11.1-2 / §6.2 / §16 | TC-AUTH-010 | TC-AUTH-003/004/008 | 全绿 |

### 3.6 未覆盖/间接项与补测建议

| 项 | 类型 | 现状 | 补测建议 | 归属 |
|---|---|---|---|---|
| TM-EXEC-04（GC 压力） | 间接 | TC-RES-001/004 只测内存趋势与基线，无独立 GC 停顿断言 | S1 基准记录 GC 时间（T-OQ-02）；S2 增加“单回调 GC 峰值 ≤ 预算”断言 | S1→S2 |
| TM-LEAK-04（时序侧信道） | 间接 | 仅验证系统计时 API 不可达；S0-2 明确接受低危残余 | S1 报告给出“无可稳定利用信号”的评估结论；不承诺恒定时间 | S1（书面接受） |
| TM-PLATFORM-03（帧率/暂停） | 间接 | 只有跨平台一致性与调度顺序；无不同帧率/暂停恢复专项 | S2 在 TC-SCHED-007/PLATFORM-003 增加帧率与暂停恢复变体 | S2 |
| API-Q-01/02/03/06/07 | 实现缺口 | 宿主投影不存在 | S2 实现投影后执行 TC-AUTH-009/005/004 | S2 |
| API-C-02/03 | 实现缺口 | 新宿主命令不存在 | S2 新增宿主用例后执行 TC-EXEC-003/013 | S2 |
| API-C-04 | 实现缺口 | 脚本侧 Quest 错误映射未定 | S2 补错误映射后执行 TC-AUTH-005/EXEC-013 | S2 |
| INV-24 无 VM 的 L2 | 待晋级 | LOAD-003 目前 L1 | S1 通过后原编号晋级 L2 并进 CI | S1→S2 |
| INV-06 系统时间双平台 | 部分 | 双平台在 ISO-006（L1） | S2 在 TC-PLATFORM-003 增“系统时间不可达”双平台断言 | S2 |

---

## 4. S1 / S2 / S3 退出判定清单

**S1（PoC）退出**（对应 LUA_MODDING_SDK.md §11.1 与 S0-2 §6.2）：

- [ ] 双平台创建/执行/销毁独立 state → TC-ISO-006、TC-RES-004 证据齐。
- [ ] 订阅事件 + 查询只读视图 + 提交允许命令的纵向样例 → TC-AUTH-010、TC-EXEC-010 前身观察 + PoC 报告。
- [ ] 无限循环可靠中断、内存上限可验证、OS/IO/原生/require/FFI 不可达 → TC-ISO-001/002/011、TC-EXEC-011。
- [ ] 连续失败可禁用脚本且不影响 Core/GameState → TC-EXEC-008、TC-EXEC-007 前身观察。
- [ ] 不新增 active 内容类型；无脚本模组行为不变 → TC-COMPAT-001、TC-SUPPLY-004。
- [ ] 9 条阻断项全部有 L1 观测（§3.5）并写入 `docs/research/LUA_HOST_POC_REPORT.md`；报告含测量表与原始日志，明确标注“可信内部原型/非沙箱”若适用。

**S2（集成）退出**：

- [ ] 全部 L2 用例在 CI 绿；12 条 L1 已完成晋级或保持 S1 证据并列入发布阻断。
- [ ] `release.yml` 新增“Lua SDK 测试”step 并接入既有 18 step 链（不破坏 step 6–12）。
- [ ] 纯数据 Core / SDK 示例行为与升级前一致（TC-COMPAT-002/003/004），基线按 §1.7 口径。
- [ ] 含脚本模组在“无 VM 构建”下明确失败（TC-LOAD-003 晋级 L2）。
- [ ] §3.2/§3.3/§3.4 无未覆盖阻断项；§3.6 缺口全部关闭或书面接受。
- [ ] 发布门禁能拒绝未验收脚本模组（TC-PLATFORM-004 前置条件在 CI 实现）。
- [ ] S0-1 的 `manifest-v2` 契约已落地，且 TC-LOAD-001/COMPAT-006 的静态判定通过。

**S3（发布）退出**：L3 七条用例全绿；`pack --release`、SHA256、双平台 trace 一致；9 条阻断威胁仍有有效 L2 回归且未被新改动绕过。

---

## 5. S0 阶段可执行的 L0 门禁

| 门禁 | 检查内容 | 判定标准 | 证据 | 落点 | 状态 |
|---|---|---|---|---|---|
| G0-1 文档交叉引用 | 本矩阵、S0-1、S0-2 是否被 `docs/design/README.md` 索引；三份文档互相引用 | 缺任一条引用 = 失败 | `grep` 输出 | `docs/design/README.md` | ✅ 已完成（README 已登记三份 S0 文档） |
| G0-2 TC ID 唯一性与格式 | `TC-<AREA>-nnn` 符合 10 个测试域枚举、编号唯一、级别 ∈ {L0,L1,L2,L3}、每行 8 列 | 重复 0、非法 AREA 0、非法级别 0、表格列数异常 0 | 计数脚本输出 | `tools/check_lua_s0_docs.mjs`（建议后续新建）或人工 grep | ✅ 本版可执行 |
| G0-3 占位清零 | 威胁/不变量/API 引用中是否仍有 `xx` 形式占位 | 本版必须 = 0；所有引用指向真实 ID | `grep` 计数 | 本文件 | ✅ 已完成（0 占位） |
| G0-4 非法示例 manifest 静态拒绝 | 5 类夹具（路径逃逸/绝对路径/未知 capability/非法 `script_api_version`/版本混用） | 每个夹具 `validate --json` exit 1 且错误码稳定、字段 `mod/file/path` 齐全；出现 exit 0 即失败 | `validate --json` | 夹具目录 + S2 测试套件 | ⏳ 需脚本校验实现后执行（设计已冻结） |
| G0-5 能力命名一致性 | `api_version`（内容 API）与 `script_api_version`（脚本 API）、四类版本不混用；capability 命名符合 `^[a-z][a-z0-9_.-]*$` 且 `script.*` 前缀分流 | 混用 0 处；capability 命名违规 0 处；`script.*` 未混入 `FrameworkInfo.CAPABILITIES` | 文档 grep + S0-1 §4.7 对照 | S0-1、本文件 | ✅ 本版可执行 |
| G0-6 覆盖自检 | TM 44/44、INV 28/28、API 20/20；10 个测试域各 ≥3 条；L0/L1/L2/L3 各 ≥5 条；兼容回归独立行 ≥2 | 任一不满足 = 失败 | 本文件 §8 | 本文件 + 计数脚本 | ✅ 本版满足 |
| G0-7 生成物不漂移 | `gen_content_types.mjs --check`、`gen_static_docs.mjs --check` | 均 exit 0 | CI step 7/8 日志 | 现有 CI | ✅ 现有门禁 |
| G0-8 安全表述自检 | 全文不得出现“跑通即安全 / 测试通过即验收”类表述 | 命中 0 处 | 人工评审 + grep | 本文件与 S1 报告 | ✅ 本版通过 |

---

## 6. 证据形式规范

| 级别 | 最小证据 | 存放位置 | 不合格示例 |
|---|---|---|---|
| L0 | 命令 + 退出码 + 命中计数（或结构化 JSON） | 任务报告 / PR 评论 | “目测文档一致” |
| L1 | PoC 报告章节（含测量表）+ 原始日志文件 + 复现命令 | 实验分支 `docs/research/LUA_HOST_POC_REPORT.md`（S1 产出） | 只有截图、无原始日志 |
| L2 | Godot runner 的 `[PASS]/[FAIL]` 行、汇总行、失败明细；或 CLI `--json` 与退出码；或 CI step 日志 | CI run / 测试输出归档 | “本地跑过” |
| L3 | 导出产物内的运行日志 + 双平台 trace/hash + 发布产物清单 + `SHA256SUMS.txt` 校验输出 | release workflow artifact | 只用开发环境结果冒充导出产物结果 |

所有证据必须写明：**被测版本（commit/tag）、平台、命令、阈值/金样来源**。阈值不能写死为“看起来差不多”，必须来自 S1 基线（T-OQ-02/03）或明确配置。

---

## 7. 待建项（S1/S2 实现清单）

TM/INV/API 接线、三份文档索引、占位清零已完成；以下仅剩实现与实验项：

| # | 待建项 | 现状 | 动作 | 阻塞对象 |
|---|---|---|---|---|
| 1 | S1 PoC 技术报告 | 不存在 | 按 §4 S1 清单产出 `docs/research/LUA_HOST_POC_REPORT.md` | S1 |
| 2 | Lua VM 选型与嵌入（GAP-01） | 未选型 | 记录版本/许可证/构建/供应链（T-OQ-01） | S1 |
| 3 | Mock Host 与 VM 测试驱动（GAP-15） | 不存在 | S1 最小驱动；S2 接入 `TestCase` | S1/S2 |
| 4 | 故障注入与预算断言助手（GAP-19） | 不存在 | 注入器 + 指令/内存/批次/日志预算断言 | S2 |
| 5 | `framework/tests/cases/test_script_*.gd` | 不存在 | 按 §2 的 57 条 L2 落地并追加 `SUITE_PATHS`（当前 66 条） | S2 |
| 6 | CI 新 step “Lua SDK tests” | 不存在 | 插在 `release.yml` step 6 之后，保持既有 step 语义 | S2 |
| 7 | L3 导出运行测试 | 不存在（只有导出，无导出后运行） | 新增 step：导出后对产物跑纵向样例；接 TC-PLATFORM-001/002/003 | S3 |
| 8 | `pack --release` 脚本验收标记 | 不存在 | 未过沙箱验收的脚本模组必须拒绝；接 TC-PLATFORM-004 | S3 |
| 9 | `script_states[mod_id]` 存档契约 | S0-1/S0-2 已给目标格式，未实现 | 落为 Save Schema 迁移 + TC-STATE-001…008 | S2 |
| 10 | manifest-v2 Schema 与扫描器 `.lua` 通道（GAP-02/03/04） | v1 显式拒绝（事实） | 按 S0-1 §4.6 实现 v2 + `is_allowed_script` | S2 |
| 11 | 脚本错误码金样（S0-1 §4.3 + S0-2 附录 A） | 契约已定，未实现 | 冻结码表并落 golden JSON；接 TC-AUTH-007/013 | S2 |
| 12 | L0 检查脚本（G0-2/G0-6） | 不存在 | 新建只读检查，不运行生成器 | S0 之后 |

---

## 8. 矩阵自检（本版）

| 检查项 | 结果 |
|---|---|
| TC 行总数 | **83**（≥40） |
| 测试域分布 | COMPAT 8、LOAD 6、AUTH 13、EXEC 13、SCHED 8、STATE 8、ISO 14、RES 4、SUPPLY 4、PLATFORM 5 |
| 级别分布（主级别） | L0 **7**、L1 **12**、L2 **57**、L3 **7** |
| TM 覆盖 | 44/44（直接 41、间接 3、未覆盖 0） |
| INV 覆盖 | 28/28（直接 26、间接 2、未覆盖 0） |
| API 覆盖 | 20/20（三类断言均映射；测试缺口 0、实现缺口 7 + 1 项错误映射小缺口，均不阻塞矩阵） |
| 阻断项覆盖 | 9/9 全绿（每条 L1 + L2/L3，见 §3.5） |
| 兼容回归独立行 | 是（TC-COMPAT-001…008，含“纯数据模组不创建 VM”与“行为不变”） |
| 每行判定标准与证据 | 是（8 列全部填写；无“跑通即可”） |
| 占位引用 | 0（§0.1 ID 全部指向 S0-1/S0-2 真实编号） |
| 旧编号残留 | 0（无 `TC-BR-*` / `TC-LEAK-*` 引用） |
| 未运行项声明 | 未运行 Godot、未运行 Node 测试、未运行 `gen_static_docs.mjs`（避免写 `docs/static/`） |

---

## 附录 A：盘点证据

本文件所有数量均为**只读静态盘点**（`Get-ChildItem` / `Select-String` / `[IO.File]::ReadAllLines`）所得，未执行任何测试或生成器：

| 证据 | 命令/方法（2026-10-23） | 结果 |
|---|---|---|
| 用例文件数 | `(Get-ChildItem framework/tests/cases -Filter *.gd).Count` | **66** |
| 注册套件数 | `Select-String framework/tests/test_runner.gd -Pattern '^\s*"res://framework/tests/cases/'` | **66** |
| 用例函数数（静态） | 66 个文件 `Select-String '^func test_'` 求和 | **579**（运行时以 runner 汇总行为准，§1.7） |
| Node 纯逻辑用例 | `Select-String SNModMaker/tests/run-tests.js '^\s+(?:await )?test\('` | **60** |
| Content CLI 用例 | `Select-String SNModMaker/tests/content-cli.test.mjs '^test\('` | **64** |
| CI step 数 | 数 `release.yml` 的 `- name:` | **18** |
| S0-1 候选 API | S0-1 §3.2–3.4 | 20（Q 7 / E 8 / C 5） |
| S0-2 威胁/不变量 | S0-2 §3.0、§5 | 44 TM / 28 INV / 22 GAP / 9 阻断 |
| Manifest v1 事实 | `schemas/manifest.schema.json` 第 6 行 `additionalProperties:false`、第 25–27 行 `api_version` 正则、第 29–31 行 `type.const="content"`；`mod_manifest.gd` 63–66 `invalid_type`；`mod_scanner.gd` 119–136 对 `.lua` 报 `forbidden_file` | 对 `scripts` 是**双重显式拒绝**（不是静默忽略） |
| 关键文件行数 | `[IO.File]::ReadAllLines(...).Count` | `test_runner.gd` 135；`test_case.gd` 117；`test_sdk_validation.gd` 516；`validate.gd` 57；`pack_mod.gd` 131；`validation_core.gd` 449；`release.yml` 199；S0-1 518；S0-2 1121；本文件 605（S0-4） |
| 其他事实 | 目录盘点 | `SNModMaker/` 无 `package.json`；三个 smoke 脚本未进 `release.yml`；工作区含无关 D2 fleet 未提交改动（不计入基线） |

---

**结论**：本版把 S0-3 初版的占位结构收敛为与 S0-1/S0-2 可直接引用的矩阵：83 条可判定用例、44/44 威胁、28/28 不变量、20/20 候选 API 覆盖，9 条发布阻断项全部具备 L1 + L2/L3 证据路径。测试通过不等于安全验收；Lua SDK 晋级的依据是 S1 PoC 报告、阻断项证据与 S2 全量门禁共同成立。
