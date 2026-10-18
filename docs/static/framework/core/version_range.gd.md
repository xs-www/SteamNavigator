# `framework/core/version_range.gd`

> 作用：内容模组依赖使用的版本范围求值器。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `VersionRange` | L1 |
| `matches(version: SemVer) -> bool` | L79 |

## 契约与约束

- 支持 `*`、精确版本、比较符、`^`、`~`、空格/逗号 AND、`||` OR。
- 不使用任意表达式求值；解析失败写入 `error` 并使 `matches()` 返回 false。
- Caret 对 0.x 按语义版本规则收紧上界。

模块索引：[framework/core](./README.md)
