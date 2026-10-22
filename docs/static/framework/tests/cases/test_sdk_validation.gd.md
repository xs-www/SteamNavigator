# `framework/tests/cases/test_sdk_validation.gd`

> 作用：SDK Schema 2.0 兼容回归：用真实子进程跑 `sdk/validate.gd` / `sdk/pack_mod.gd`，

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VALIDATE_SCRIPT` | L17 |
| `PACK_SCRIPT` | L18 |
| `ROLES_EXAMPLE` | L19 |
| `MIXED_EXAMPLE` | L20 |
| `WEAPONS_EXAMPLE` | L21 |
| `STORY_TEMPLATE` | L22 |
| `test_default_mode_is_runtime_and_validates_core() -> void` | L207 |
| `test_mod_root_core_does_not_duplicate_the_default_scan_root() -> void` | L217 |
| `test_runtime_accepts_mixed_version_mods() -> void` | L234 |
| `test_runtime_rejects_unactivated_draft_content() -> void` | L264 |
| `test_draft_mode_validates_draft_story_and_mixed_mods() -> void` | L284 |
| `test_draft_mode_reports_schema_and_per_type_version_errors() -> void` | L309 |
| `test_patch_envelope_is_checked_against_the_patches_type_version() -> void` | L347 |
| `test_unknown_mode_is_a_usage_error() -> void` | L381 |
| `test_pack_release_rejects_draft_content_and_plain_pack_allows_it() -> void` | L391 |
| `test_pack_release_rejects_validation_errors() -> void` | L422 |
| `test_pack_release_keeps_the_snavmod_zip_layout() -> void` | L439 |

覆盖 runtime / draft 两种模式、草案拒绝、退出码与 JSON 输出形状。

## 契约与约束
- 所有断言面向真实 CLI：`OS.execute(OS.get_executable_path(), ...)` 以 `--headless` 启动
  `res://sdk/validate.gd` / `res://sdk/pack_mod.gd`，不直接调用内部实现。
- 仓库内示例 / 模板只读（`sdk/examples/**`、`sdk/templates/**`）；运行期 fixture 写在
  `user://sdk_test_*`，每个用例结束清理。
- runtime 必须：2.0 示例可加载、多类型 2.0 混合模组可加载、未激活草案被显式拒绝；`contracts` 保留唯一 1.0 定义类型
  （`inactive_content_type`，带 `mod` / `file` / `path` 字段）。
- draft 必须：草案 / 混合模组可静态校验；Schema 错误与“按类型版本”错误能被发现。
- `pack_mod --release` 必须拒绝未激活草案与校验 error；不带 `--release` 保持旧行为。

模块索引：[framework/tests](../README.md)
