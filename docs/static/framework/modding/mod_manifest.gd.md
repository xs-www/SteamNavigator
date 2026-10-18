# `framework/modding/mod_manifest.gd`

> 作用：Manifest 语义模型：ID、SemVer、API、依赖、内容/资源/本地化路径与能力声明。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ModManifest` | L1 |
| `accepts_api(framework_major: int, framework_minor: int) -> bool` | L171 |
| `has_capabilities(known: PackedStringArray) -> Array[String]` | L175 |
| `to_summary() -> Dictionary` | L183 |

## 契约与约束

- ID 正则 `^[a-z][a-z0-9_]{2,31}$`；仅 core 可声明 `required=true`。
- 依赖版本范围立即解析并保存为 VersionRange；非法范围记录错误。
- 内容路径必须安全、`.json` 且数量 ≥1；资源必须是允许的图片/音频类型。
- `accepts_api()` 要求主版本相等、次版本不大于框架。

模块索引：[framework/modding](./README.md)
