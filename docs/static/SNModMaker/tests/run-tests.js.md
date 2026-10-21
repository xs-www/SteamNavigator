# `SNModMaker/tests/run-tests.js`

> 作用：Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP、导入导出往返、GLB 解析与部署目标解析。

- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI` | L29 |
| `GLB` | L31 |
| `schemaFilesOnDisk()` | L34 |
| `test(name, fn)` | L53 |
| `freshProject()` | L66 |
| `errorsOf(result)` | L70 |
| `warningsOf(result)` | L74 |

## 契约与约束

- 不依赖浏览器或 Godot；直接 require 经典脚本并以 `globalThis.SN*` 访问模块。
- 覆盖 32 个用例，含实体多语言键事务、资源候选类型过滤、船体模块区、贴图/GLB 引用、GLB 解析与发布包 mods 目标解析；任何失败以退出码 1 结束。

模块索引：[SNModMaker](../README.md)
