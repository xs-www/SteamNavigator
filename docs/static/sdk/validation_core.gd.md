# `sdk/validation_core.gd`

> 作用：SDK 共享校验核心：提供 runtime（真实 Bootstrap 加载）与 draft（静态 Schema）两种校验，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SdkValidationCore` | L1 |
| `CONTENT_TYPES_MANIFEST` | L21 |
| `SUPPORTED_SCHEMA_VERSIONS` | L22 |
| `MAX_CONTENT_FILE_BYTES` | L23 |
| `MODE_RUNTIME` | L24 |
| `MODE_DRAFT` | L25 |
| `VALIDATION_SAVE_DIR` | L26 |
| `STAGE_PREFIX` | L27 |
| `STAGE_SKIP_SUFFIXES` | L28 |
| `modes() -> PackedStringArray` | L36 |
| `is_mode(value: String) -> bool` | L40 |
| `draft_type_table() -> Dictionary` | L45 |
| `describe_type(content_type: StringName) -> Dictionary` | L75 |
| `is_draft_type(content_type: StringName) -> bool` | L96 |
| `normalize_roots(roots: PackedStringArray) -> PackedStringArray` | L103 |
| `run_runtime(roots: PackedStringArray, overrides: Dictionary = {}) -> StartupReport` | L115 |
| `run_draft(roots: PackedStringArray) -> StartupReport` | L158 |
| `find_inactive_draft_content(roots: PackedStringArray) -> Array[Dictionary]` | L215 |
| `read_envelope(source: ModSource, relative_path: String) -> Dictionary` | L242 |
| `stage_mod(source_path: String, mod_id: String) -> String` | L257 |
| `cleanup_stage(stage_root: String) -> void` | L264 |
| `enrich_errors(report: StartupReport) -> void` | L270 |

并把结果统一成可直接用于 CI 的 `StartupReport` + 结构化错误。

## 契约与约束
- 类型 / 版本 / Schema 路径的唯一真源是 `content_types.json`：active 类型读生成物
  `ContentTypes`（`SCHEMA_PATHS` / `SCHEMA_VERSIONS`），草案类型读该 JSON 的
  `draft_schemas` + `draft_types`。本文件不维护第二套类型或版本表。
- runtime 模式：先做一次只读预扫描，发现草案内容就产出 `inactive_content_type`
  结构化错误（`code` / `message` / `severity` / `mod` / `file` / `path`），再跑真实
  `Bootstrap`，保留 `StartupReport` 的既有 JSON 形状；core 内的草案内容按 fatal 处理。
- draft 模式：不启动运行时，按同一张类型表做静态 Schema 校验；草案 / 混合模组都可校验。
  `forbidden_file` 等打包期文件白名单错误只在 runtime / release 判定，避免模板里的
  README 之类文档文件挡住草案 Schema 校验。
- 只读模组目录；不执行模组内容、不写 `dev_mods`。`stage_mod` 只在 `pack_mod --release`
  需要隔离校验单个第三方模组时把文件复制到 `user://` 临时目录，校验后立即清理。

模块索引：[sdk](./README.md)
