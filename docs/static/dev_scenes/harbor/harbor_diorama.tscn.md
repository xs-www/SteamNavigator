# `dev_scenes/harbor/harbor_diorama.tscn`

> 作用：独立 3D 港口样片场景：固定机位黄昏逆光，用已有 GLB 资产拼码头/吊车/货堆，前方浮一艘 1795 双桅纵帆船，水面使用自写着色器。

- 关键依赖：`assets/models/ships/SN_Schooner_Fame.glb`、`assets/materials/water/harbor_water.tres`、`dev_scenes/harbor/bobbing_boat.gd`、`dev_scenes/harbor/harbor_diorama.gd`
- 类型：Godot 场景

## 契约与约束

- 不接入主场景：`project.godot` 的 `run/main_scene` 仍指向 `framework/ui/shell/main.tscn`。
- 水面分两层：`Water` 为 500×400 细分网格（波动/泡沫/反射），`FarWater` 是下沉 3 m 的大平面，只输出地平线雾色，遮住主水面网格边缘。
- 码头岸壁、护舷、爬梯、系缆桩、煤气灯、吊车、货堆与船体全部来自 `assets/models/`；仓库/烟囱/窗灯是场景内 BoxMesh 剪影，只做尺度参照。
- 固定机位：`Camera3D`（fov 35）与 `Sun`/`Fill`/`WorldEnvironment` 都是场景内预置，不在运行时改。
- `ShipBob` 只控制姿态，船体 GLB 作为其子节点实例；水面泡沫环参数 `boat_*` 要与 `ShipBob` 的位置/朝向及新船长一致（half_size 13.2×3.9）。
- 改 `Sun` 朝向时必须同步 `assets/materials/water/harbor_water.tres` 的 `sun_direction`，否则水面耀斑与光照方向不一致。
- 船体当前实例 `SN_Schooner_Fame`（29 mesh / 13174 tri / 无星条旗），旧 `SN_Ship_Prototype` 仅保留为历史原型资产，不再出现在本场景。

模块索引：[dev_scenes](../README.md)
