# `SNModMaker/tests/run-tests.js`

> 作用：Node 单元测试：Schema 校验、项目模型、全部内容类型表单、索引/克隆、ZIP 与导入导出往返。

- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `UI` | L25 |
| `test(name, fn)` | L32 |
| `freshProject()` | L45 |
| `errorsOf(result)` | L49 |
| `warningsOf(result)` | L53 |

## 契约与约束

- 不依赖浏览器或 Godot；直接 require 经典脚本并以 `globalThis.SN*` 访问模块。
- 覆盖 28 个用例；任何失败以退出码 1 结束。

模块索引：[SNModMaker](../README.md)
