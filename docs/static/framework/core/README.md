# `framework/core`

> 与引擎无关的小型基础设施：JSON、路径、SemVer、版本范围、稳定哈希、版本常量。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `framework_info.gd` | 框架版本、Mod API 版本与能力常量。 | 本页 |
| `json_utils.gd` | JSON 解析、规范化序列化、JSON Pointer 读写与深比较辅助。 | [查看](./json_utils.gd.md) |
| `path_guard.gd` | 不可信模组路径的格式、长度、扩展名与穿越检查。 | [查看](./path_guard.gd.md) |
| `semver.gd` | SemVer 2.0 解析、比较与格式化（含 prerelease 排序）。 | [查看](./semver.gd.md) |
| `stable_hash.gd` | FNV-1a 稳定哈希与命名流种子派生。 | 本页 |
| `version_range.gd` | 内容模组依赖使用的版本范围求值器。 | [查看](./version_range.gd.md) |

## 模块契约

- 这些工具不得依赖 AppContext、GameState 或 Godot 场景树。
- 确定性/安全性优先：不使用全局随机、平台相关排序或动态表达式。
