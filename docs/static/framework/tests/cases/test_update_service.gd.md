# `framework/tests/cases/test_update_service.gd`

> 作用：自动更新纯逻辑与落地测试：清单/接口校验、内容包与本体两条决策、URL 解析、core 暂存与启动应用、exe 自替换与回滚、解压白名单。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ROOT` | L9 |
| `test_parse_payload_and_manifest_validation() -> void` | L99 |
| `test_decide_picks_core_full_none_and_blocks_downgrade() -> void` | L119 |
| `test_local_state_uses_install_then_falls_back_to_files() -> void` | L143 |
| `test_resolve_url_relative_absolute_and_fallback() -> void` | L167 |
| `test_stage_content_and_apply_on_next_start() -> void` | L179 |
| `test_apply_pending_rejects_wrong_engine_and_keeps_old_core() -> void` | L208 |
| `test_swap_engine_keeps_backup_and_startup_cleans_it() -> void` | L229 |
| `test_extract_package_only_takes_exe_and_core() -> void` | L246 |

- 契约：docs/design/AUTO_UPDATE.md §3–§6；测试只读写 `user://test_update_*` 临时目录，不联网、不碰真实安装目录。
- `UpdateService` 的 HTTP 部分不在单测范围（需要真实 socket）；这里覆盖能被下载结果影响的全部决策与文件操作。

模块索引：[framework/tests](../README.md)
