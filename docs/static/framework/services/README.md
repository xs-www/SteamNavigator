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
| `save_migrations.gd` | 存档 payload 版本迁移与内容版本表（B5）：1.x → 2.0、campaign 元数据回填、 | [查看](./save_migrations.gd.md) |
| `save_service.gd` | JSON 存档槽：模组/框架头、状态克隆与内容版本快照、临时文件校验后替换、 | [查看](./save_service.gd.md) |
| `settings_service.gd` | 持久化 UI/玩家设置（语言、自动存档、游玩数据上传、自动更新），负责读取仓库默认 `config/config.json`、写用户配置并在发布版使用 exe 旁的 `config/config.json`。 | [查看](./settings_service.gd.md) |
| `ship_visual_plan.gd` | 把「当前船体 + Core 内容」解析成舞台可直接执行的视觉装配计划（hull GLB 物理路径、rig_kit 替换计划、武器 loadout 路径），让表现层只消费路径、不读注册表，也不写死任何 core 内容 ID 或资产键。 | [查看](./ship_visual_plan.gd.md) |
| `telemetry_service.gd` | 游玩数据（telemetry）会话的纯逻辑服务：记录命令/白名单事件/WARN+ 日志、按契约裁剪、生成 `sn.telemetry.session/1` 载荷并读写 `user://telemetry/pending/` 待上传队列；不依赖 SceneTree / HTTP。 | [查看](./telemetry_service.gd.md) |
| `telemetry_uploader.gd` | 把 `TelemetryService` 的 pending 会话文件串行 POST 到 telemetry_endpoint：请求成功的 200/201/204 删除该文件，其余（超时/网络错误/非 2xx）保留文件并结束本轮；Node + HTTPRequest 实现，不含记录/裁剪业务逻辑。 | [查看](./telemetry_uploader.gd.md) |
| `update_applier.gd` | 安装目录侧的更新落地。启动时（Bootstrap 扫描模组前）清理上一次自替换留下的旧 exe、应用 `user://updates/pending` 里已校验的 core 包，并重写 `config/install.json`；更新器下载完成后的 exe 自替换也复用这里的文件操作。 | [查看](./update_applier.gd.md) |
| `update_service.gd` | 游戏内自动更新：读取网站 `/api/site/update`、比较本地安装哈希、按「只换 core 包 / 换整个 exe」两种粒度下载并校验，最后交给 `UpdateApplier` 完成文件替换。契约见 `docs/design/AUTO_UPDATE.md`。 | [查看](./update_service.gd.md) |

## 模块契约

- 服务不包含具体内容 ID。
- 资源缺失/存档损坏只降级，不崩溃。
