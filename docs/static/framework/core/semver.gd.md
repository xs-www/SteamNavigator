# `framework/core/semver.gd`

> 作用：SemVer 2.0 解析、比较与格式化（含 prerelease 排序）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SemVer` | L1 |
| `parse(text: String) -> SemVer` | L12 |
| `is_valid(text: String) -> bool` | L31 |
| `compare_to(other: SemVer) -> int` | L35 |
| `as_text() -> String` | L76 |

## 契约与约束

- 拒绝前导零与两段式版本；build 元数据不参与比较。
- prerelease 低于同核心版本；数字段按数值比较，字母段按字典序。
- 方法名为 `as_text()`，避免覆盖 Object.to_string。

模块索引：[framework/core](./README.md)
