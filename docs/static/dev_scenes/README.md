# `dev_scenes`

> 独立 3D 样片与舞台预览场景（不接入主流程）：港口水面/浮船样片与 PortStage 港口舞台预览，用于验证水面着色器、GLB 资产拼接与固定机位构图。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `harbor/README.md` | 港口样片运行方式、文件清单、水面实现要点、调参入口与已知边界。 | 本页 |
| `harbor/bobbing_boat.gd` | 浮船：采样与水面着色器同源的波浪，驱动升沉、纵摇、横摇和极缓慢系泊漂移。 | [查看](./harbor/bobbing_boat.gd.md) |
| `harbor/harbor_diorama.gd` | 港口样片根脚本：运行时给码头石墙套更暗的复制材质，压住黄昏逆光下的高光。 | [查看](./harbor/harbor_diorama.gd.md) |
| `harbor/harbor_diorama.tscn` | 独立 3D 港口样片场景：固定机位黄昏逆光，用已有 GLB 资产拼码头/吊车/货堆，前方浮一艘 1795 双桅纵帆船，水面使用自写着色器。 | [查看](./harbor/harbor_diorama.tscn.md) |
| `port_stage/port_stage_preview.gd` | PortStage 独立预览场景根（不接入主流程）：构建铺满窗口的 `SNStageHost`，挂载 `port_stage.tscn`，提供 `preview`（铁港全设施 + banner + 街道 town kit + 明轮船）与 `sparse`（香料港 small、三设施、无 banner、根层 facility_visuals/town_visuals）两份样例 ViewModel；`set_station()` 可把镜头切到 market/harbor/supply 三个相邻站位（stage 或 panel 构图）并打印站位自查。 | [查看](./port_stage/port_stage_preview.gd.md) |
| `port_stage/port_stage_preview.tscn` | PortStage 独立预览场景：全屏 Control 挂 `port_stage_preview.gd`。 | 本页 |

## 模块契约

- `dev_scenes/` 不是游戏启动链的一部分；主场景仍为 `framework/ui/shell/main.tscn`。
- 样片可以复用 `assets/` 与 `assets/models/`，但不得反向依赖 `framework/` 运行时。
- 水面材质/着色器属于表现层资产，`PortStage` 与 `dev_scenes/port_stage` 共用同一套水面材质。
- `port_stage/` 通过真实 `SNStageHost` 挂载 `port_stage.tscn`，用两份样例 ViewModel 覆盖完整/稀疏港口；截图由 `tools/godot/capture_port_stage.gd` 生成。
