# `framework/services`

> 基础设施服务：日志、RNG、时钟、本地化、资源、存档。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `asset_service.gd` | 把 `asset://<mod>/<key>` 解析为已挂载物理路径，缺失时回退占位图。 | [查看](./asset_service.gd.md) |
| `clock_service.gd` | 游戏时间格式化、天数/小时与时长工具。 | 本页 |
| `localization_service.gd` | 合并框架与模组本地化表，提供活动语言回退与缺失检测。 | [查看](./localization_service.gd.md) |
| `logger.gd` | 有界结构化日志（DEBUG–FATAL），带模组/文件上下文字段。 | [查看](./logger.gd.md) |
| `rng_service.gd` | 命名随机流：按（种子、流名、上下文）派生独立 RNG。 | [查看](./rng_service.gd.md) |
| `save_service.gd` | JSON 存档槽：模组头、状态、临时文件校验后替换、兼容性检查。 | [查看](./save_service.gd.md) |

## 模块契约

- 服务不包含具体内容 ID。
- 资源缺失/存档损坏只降级，不崩溃。
