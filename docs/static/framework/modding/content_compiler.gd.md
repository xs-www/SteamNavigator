# `framework/modding/content_compiler.gd`

> 作用：内容编译：解析内容文件、按类型 Schema 校验、注册定义、应用显式 Patch，最后冻结注册表。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentCompiler` | L1 |
| `MAX_CONTENT_FILE_BYTES` | L19 |
| `MAX_PATCHES` | L20 |
| `_init(hub: RegistryHub,, localization: LocalizationService,, assets: AssetService,, logger: AppLogger = null,, validator: SchemaValidator = null) -> void` | L35 |
| `compile(packages: Dictionary, order: Array[String]) -> Dictionary` | L49 |

- 关键依赖：`ContentTypes`、`SchemaValidator`、`RegistryHub`、`LocalizationService`、`AssetService`

## 契约与约束
- 内容版本按内容类型声明：每个内容文件的 `schema_version` 必须等于
  `ContentTypes.schema_version(content_type)`；期望版本为空时回退
  `FrameworkInfo.CONTENT_SCHEMA`。未知类型仍按 `unknown_content_type` 拒绝。
- Phase A 只把全局版本比较改为按类型比较，1.0 内容行为完全不变；Schema 2.0
  草案类型尚未提升 active，仍不会进入加载链。
- Patch 的再校验用**目标定义类型**的版本构造 envelope，避免借用全局基线版本。

模块索引：[framework/modding](./README.md)
