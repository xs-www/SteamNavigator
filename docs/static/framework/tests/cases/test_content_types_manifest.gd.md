# `framework/tests/cases/test_content_types_manifest.gd`

> 作用：content_types.json 与框架 ContentTypes / 本地 Schema 文件的一致性守护，防止单一真源在过渡期漂移。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `test_manifest_matches_content_types() -> void` | L20 |
| `test_manifest_entries_are_unique_and_complete() -> void` | L63 |
| `test_minor_modules_share_one_utility_category() -> void` | L108 |
| `test_planned_types_do_not_shadow_active_types() -> void` | L124 |

## 契约与约束

- 校验 key 集合、singular、schema 路径、definition/patch 分类与 registry 标志。
- 校验类型 key / singular / schema 唯一，分组、capability、aliases、default_file 字段完整，planned 类型不覆盖 active。
- 校验 `v2_module_categories` 唯一且被类型引用；导航/安全必须同属 `utility`，且不存在独立的 active utility 类型。
- 过渡期测试替代生成器；生成器接入后保留为回归测试。

模块索引：[framework/tests](../README.md)
