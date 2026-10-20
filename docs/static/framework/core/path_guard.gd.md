# `framework/core/path_guard.gd`

> 作用：不可信模组路径的格式、长度、扩展名与穿越检查。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `PathGuard` | L1 |
| `MAX_PATH_LENGTH` | L8 |
| `MAX_PATH_DEPTH` | L9 |
| `FORBIDDEN_EXTENSIONS` | L11 |
| `CONTENT_EXTENSIONS` | L16 |
| `ASSET_EXTENSIONS` | L17 |
| `LOCALIZATION_EXTENSIONS` | L18 |
| `is_safe_relative(path: String) -> bool` | L21 |
| `is_forbidden_file(path: String) -> bool` | L39 |
| `is_allowed_content(path: String) -> bool` | L44 |
| `is_allowed_asset(path: String) -> bool` | L48 |
| `is_allowed_localization(path: String) -> bool` | L52 |
| `join(root: String, relative: String) -> String` | L56 |
| `strip_root(path: String, root: String) -> String` | L60 |
| `depth(path: String) -> int` | L67 |

## 契约与约束

- 拒绝绝对路径、盘符、`..`、反斜杠、`://`、空段与超过 16 层的路径。
- 脚本、动态库、场景、引擎导入文件在内容模组中一律禁止。
- 内容/资源/本地化分别使用白名单扩展名；资源允许图片、音频与单文件 GLB 模型。

模块索引：[framework/core](./README.md)
