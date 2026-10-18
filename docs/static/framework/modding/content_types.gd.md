# `framework/modding/content_types.gd`

> 作用：内容类型常量、Schema 路径、单数类型名与模块类型集合。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ContentTypes` | L1 |

## 契约与约束

- `content_type` 决定注册表与 Schema，两者映射必须同步维护。
- `all()` 不包含 patches；patches 由 ContentCompiler 单独收集。
- 单数类型用于 `<mod>:<type>/<id>` 的 ID 校验。

模块索引：[framework/modding](./README.md)
