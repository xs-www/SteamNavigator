# `tools`

> PowerShell 辅助脚本与静态文档生成器。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `gen_static_docs.mjs` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `pack_core.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `static_docs_data.mjs` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |
| `test.ps1` | PowerShell 测试/打包脚本与静态文档生成器。 | 本页 |

## 模块契约

- `test.ps1` / `pack_core.ps1` 通过 `GODOT_BIN` 定位引擎。
- `gen_static_docs.mjs` 读取 `static_docs_data.mjs` 生成 `docs/static/`。
