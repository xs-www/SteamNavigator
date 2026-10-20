# `framework/modding/content_compiler.gd`

> 作用：读取模组内容 JSON，执行 Schema 校验、实体 information 资源解析、定义注册、本地化/资源登记与显式 Patch。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentCompiler` | L1 |
| `MAX_CONTENT_FILE_BYTES` | L6 |
| `MAX_PATCHES` | L7 |
| `_init(hub: RegistryHub,, localization: LocalizationService,, assets: AssetService,, logger: AppLogger = null,, validator: SchemaValidator = null) -> void` | L22 |
| `compile(packages: Dictionary, order: Array[String]) -> Dictionary` | L36 |

## 契约与约束

- 定义 ID 的命名空间必须等于来源模组；ID 类型段必须与 content_type 单数一致。
- 文件级 Schema 错误拒绝整份文件；单条定义错误只拒绝该定义。
- information.texture/model 可使用本模组裸资源键或完整 asset:// URI；贴图只接受 png/webp/svg，模型只接受 GLB，缺失或类型错误拒绝该定义。
- Patch 冲突以 `target + JSON Pointer` 为键，跨模组同路径直接报错，不静默覆盖。
- Patch 后重新按目标类型 Schema 校验，失败则整条 Patch 回滚。
- 所有定义注册后才执行 Patch；注册表此时仍未冻结。

## 重点逻辑

### `_apply_patch(entry)`

- 先校验 target 存在、requires 版本匹配，并在工作副本上逐条执行操作。
- `/id` 及 `/id/*` 被禁止；操作失败、ID 改变或 Schema 失败都放弃整条 Patch。
- 成功时同步更新 name/desc/tags/information/raw/data，保留来源模组并追加 patched_by；Patch 后的资源引用重新校验。

### `_validate_definition_assets(default_mod_id, raw_definition, reporting_mod_id, file, pointer)`

- 裸资源键按定义来源模组解析；完整 asset://<mod>/<key> 可显式引用已加载模组资源。
- 资源必须出现在目标模组 manifest.assets；错误带定义内 /information/texture 或 /information/model 指针。

模块索引：[framework/modding](./README.md)
