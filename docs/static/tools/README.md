# `tools`

> PowerShell 辅助脚本与静态文档生成器。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `gen_static_docs.mjs` | 静态文档生成器：读取本文件的 FILE_DOCS/MODULES，生成镜像文档、模块 README、总计索引与带 SHA-256 的 manifest。 | [查看](./gen_static_docs.mjs.md) |
| `pack_core.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `static_docs_data.mjs` | 静态文档的策展数据：文件职责/契约/L2、模块简介与分组角色。 | [查看](./static_docs_data.mjs.md) |
| `test.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |

## 模块契约

- `test.ps1` / `pack_core.ps1` 通过 `GODOT_BIN` 定位引擎。
- `gen_static_docs.mjs` 读取 `static_docs_data.mjs` 生成 `docs/static/`。
