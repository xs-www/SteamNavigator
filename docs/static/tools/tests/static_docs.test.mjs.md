# `tools/tests/static_docs.test.mjs`

> 作用：静态文档生成器的 Node 单元测试，守护源码注释解析与符号提取。

- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `INFERRED` | L49 |
| `TYPED` | L50 |
| `from_dict(data: Dictionary) -> Example` | L51 |
| `value() -> int` | L53 |

## 契约与约束
- 注释块必须提取作用和 Markdown 正文，并拒绝缺少结束标记的块。
- GDScript 的 `static func`、普通函数、`const X :=` 与显式类型常量都必须进入符号表。

模块索引：[tools](../README.md)
