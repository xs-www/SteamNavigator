# `schemas`

> Manifest 与内容文件的 JSON Schema（项目校验器支持的子集）。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `boiler.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `cabin.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `cargo_module.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `common.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `contract.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `event.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `good.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `hull.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `manifest.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `map_profile.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `material.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `navigation_module.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `patch.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `port_archetype.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `role.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `safety_module.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `starting_build.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |
| `strategy.schema.json` | JSON Schema 文件（Manifest/common/15 类内容）。 | 本页 |

## 模块契约

- 每类内容一个 envelope Schema；公共字段在 `common.schema.json`。
- Schema 的 `const`/`enum` 与 `ContentTypes`/操作码注册表需同步维护。
