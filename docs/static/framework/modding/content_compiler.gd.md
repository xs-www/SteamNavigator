# `framework/modding/content_compiler.gd`

> 作用：读取模组内容 JSON，执行 Schema 校验、定义注册、本地化/资源登记与显式 Patch。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentCompiler` | L1 |
| `_init(hub: RegistryHub,, localization: LocalizationService,, assets: AssetService,, logger: AppLogger = null,, validator: SchemaValidator = null) -> void` | L22 |
| `compile(packages: Dictionary, order: Array[String]) -> Dictionary` | L36 |

## 契约与约束

- 定义 ID 的命名空间必须等于来源模组；ID 类型段必须与 content_type 单数一致。
- 文件级 Schema 错误拒绝整份文件；单条定义错误只拒绝该定义。
- Patch 冲突以 `target + JSON Pointer` 为键，跨模组同路径直接报错，不静默覆盖。
- Patch 后重新按目标类型 Schema 校验，失败则整条 Patch 回滚。
- 所有定义注册后才执行 Patch；注册表此时仍未冻结。

## 重点逻辑

### `_apply_patch(entry)`

- 先校验 target 存在、requires 版本匹配，并在工作副本上逐条执行操作。
- `/id` 及 `/id/*` 被禁止；操作失败、ID 改变或 Schema 失败都放弃整条 Patch。
- 成功时只更新内容字段（name/desc/tags/raw/data），保留来源模组并追加 patched_by。

模块索引：[framework/modding](./README.md)
