# `framework/modding/mod_loader.gd`

> 作用：模组生命周期总控：扫描 → 依赖解析 → 挂载 → 编译 → 交叉校验 → Core 完整性 → 冻结。

- 关键依赖：`ModScanner`、`DependencyResolver`、`ContentCompiler`、`CrossReferenceValidator`、`CoreCompletenessChecker`、`StartupReport`、`AppContext`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ModLoader` | L1 |
| `_init(log: AppLogger = null) -> void` | L11 |
| `load_mods(config: Dictionary) -> StartupReport` | L15 |
| `registry_hub() -> RegistryHub` | L121 |
| `localization_service() -> LocalizationService` | L125 |
| `asset_service() -> AssetService` | L129 |
| `bind_context(context) -> void` | L138 |

## 契约与约束

- 解析阶段 fatal 时立即返回，不编译内容；报告仍标记 registry_frozen。
- Core 内容错误/Core 完整性错误升级为 fatal；第三方模组错误保留为普通错误并禁用具体定义。
- ZIP 挂载使用 `load_resource_pack(path, false)`，禁止覆盖既有路径；挂载失败只降级资源，不阻断内容读取。
- 编译完成后关闭所有 ModSource（ZIPReader）。

## 重点逻辑

### `load_mods(config)`

- 每个阶段独立计时并写入 `report.timings_ms`（scan/resolve/mount/compile/validate/total）。
- 只有 `resolution.order` 中且未被禁用的模组进入 `packages` 与编译。
- 完成后 `registry.freeze_all()` 并关闭包；之后任何注册尝试都会返回 `registry_frozen`。

模块索引：[framework/modding](./README.md)
