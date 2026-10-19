# `dev_scenes`

> 独立 3D 样片场景（不接入主流程）：用于验证水面着色器、已有 GLB 资产拼接与固定机位构图。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `harbor/README.md` | 港口样片运行方式、文件清单、水面实现要点、调参入口与已知边界。 | 本页 |
| `harbor/bobbing_boat.gd` | 浮船：采样与水面着色器同源的波浪，驱动升沉、纵摇、横摇和极缓慢系泊漂移。 | [查看](./harbor/bobbing_boat.gd.md) |
| `harbor/harbor_diorama.gd` | 港口样片根脚本：运行时给码头石墙套更暗的复制材质，压住黄昏逆光下的高光。 | [查看](./harbor/harbor_diorama.gd.md) |
| `harbor/harbor_diorama.tscn` | 独立 3D 港口样片场景：固定机位黄昏逆光，用已有 GLB 资产拼码头/吊车/货堆，前方浮一艘船，水面使用自写着色器。 | [查看](./harbor/harbor_diorama.tscn.md) |

## 模块契约

- `dev_scenes/` 不是游戏启动链的一部分；主场景仍为 `framework/ui/shell/main.tscn`。
- 样片可以复用 `assets/` 与 `assets/models/`，但不得反向依赖 `framework/` 运行时。
- 水面材质/着色器属于表现层资产，后续 `PortStage` 可以直接复用。
