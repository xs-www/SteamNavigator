# `framework/modding`

> 内容管线：扫描、Manifest、依赖、Schema、注册表、Patch、交叉校验与 Core 完整性。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `content_compiler.gd` | 读取模组内容 JSON，执行 Schema 校验、实体 information 资源解析、定义注册、本地化/资源登记与显式 Patch。 | [查看](./content_compiler.gd.md) |
| `content_types.gd` | 内容类型常量、Schema 路径、单数类型名与模块类型集合；由 tools/gen_content_types.mjs 从 content_types.json 生成。 | [查看](./content_types.gd.md) |
| `core_completeness_checker.gd` | 检查官方 core 包是否提供 MVP 所需的最少内容与构筑。 | [查看](./core_completeness_checker.gd.md) |
| `cross_reference_validator.gd` | Schema 之后的语义校验：材料、构筑、委托奖励、事件条件/效果、港口市场与地图配置的引用完整性。 | [查看](./cross_reference_validator.gd.md) |
| `dependency_resolver.gd` | 校验模组健康度、冲突、能力、依赖版本，并生成确定性拓扑加载顺序。 | [查看](./dependency_resolver.gd.md) |
| `dir_mod_source.gd` | 松散目录来源：递归列文件、读文本/字节、资源前缀。 | 本页 |
| `mod_loader.gd` | 模组生命周期总控：扫描 → 依赖解析 → 挂载 → 编译 → 交叉校验 → Core 完整性 → 冻结。 | [查看](./mod_loader.gd.md) |
| `mod_manifest.gd` | Manifest 语义模型：ID、SemVer、API、依赖、内容/资源/本地化路径与能力声明。 | [查看](./mod_manifest.gd.md) |
| `mod_package.gd` | 扫描期包对象：来源、Manifest、错误/警告、启用状态。 | 本页 |
| `mod_scanner.gd` | 发现松散目录与 `.snavmod.zip`，执行文件安全扫描并解析 Manifest。 | [查看](./mod_scanner.gd.md) |
| `mod_source.gd` | 模组来源抽象基类。 | 本页 |
| `registries/content_definition.gd` | 单条内容定义的通用 envelope 与只读数据视图，包含运行数据与新版展示资源信息。 | [查看](./registries/content_definition.gd.md) |
| `registries/definition_registry.gd` | 按内容类型保存定义，支持 ID/标签查询与冻结。 | [查看](./registries/definition_registry.gd.md) |
| `registries/registry_hub.gd` | 按类型持有注册表并统一冻结/计数。 | 本页 |
| `schema_validator.gd` | 项目自带的 JSON Schema 子集校验器，支持本地与同目录文件 `$ref`。 | [查看](./schema_validator.gd.md) |
| `zip_mod_source.gd` | 未挂载前通过 ZIPReader 读取包内文件，并提供挂载后的 `res://mods/<id>/` 资源前缀。 | [查看](./zip_mod_source.gd.md) |

## 模块契约

- 模组是数据，不是代码；所有路径与扩展名经过 PathGuard。
- 注册表在 UI/场景实例化前冻结。
- 官方 core 与第三方走同一注册接口。
