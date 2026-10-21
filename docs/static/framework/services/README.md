# `framework/services`

> 基础设施服务：日志、RNG、时钟、本地化、资源、存档。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `asset_service.gd` | 把 `asset://<mod>/<key>` 解析为已挂载物理路径，缺失时回退占位；并统一加载模组内原始 PNG/GLB 内容资源。 | [查看](./asset_service.gd.md) |
| `clock_service.gd` | 游戏时间格式化、天数/小时与时长工具。 | 本页 |
| `content_asset_loader.gd` | 运行时读取模组内容资产（原始 PNG / 原始 GLB），并把 GLB 内嵌贴图之外的外部共享贴图按 URI 归一到同一个 `Texture2D` 实例，让多栋建筑在 Godot 里真正共享材质资源。 | [查看](./content_asset_loader.gd.md) |
| `localization_service.gd` | 合并框架与模组本地化表，提供活动语言回退与缺失检测。 | [查看](./localization_service.gd.md) |
| `logger.gd` | 有界结构化日志（DEBUG–FATAL），带模组/文件上下文字段。 | [查看](./logger.gd.md) |
| `rng_service.gd` | 命名随机流：按（种子、流名、上下文）派生独立 RNG。 | [查看](./rng_service.gd.md) |
| `save_migrations.gd` | 存档 payload 版本迁移：当前 save schema 2.0，支持 1.x → 2.0 并回填持久战役元数据。 | [查看](./save_migrations.gd.md) |
| `save_service.gd` | JSON 存档槽：模组头、状态、临时文件校验后替换、兼容性检查与旧档迁移入口。 | [查看](./save_service.gd.md) |
| `settings_service.gd` | 持久化 UI 设置：编辑器读 `res://config/config.json`；发布版优先读写 exe 同级 `config/config.json`，不可写时回退 `user://config/config.json`。 | [查看](./settings_service.gd.md) |
| `ship_visual_plan.gd` | 把「当前船体 + Core 内容」解析成舞台可直接执行的视觉装配计划（hull GLB 物理路径、rig_kit 替换计划、武器 loadout 路径），让表现层只消费路径、不读注册表，也不写死任何 core 内容 ID 或资产键。 | [查看](./ship_visual_plan.gd.md) |

## 模块契约

- 服务不包含具体内容 ID。
- 资源缺失/存档损坏只降级，不崩溃。
