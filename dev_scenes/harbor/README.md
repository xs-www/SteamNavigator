# 港口样片（独立场景）

一个**不接入主流程**的 3D 港口试做场景：用 `assets/models` 里已有的低模资产搭一个小港口，
用自写着色器渲染水面，港口前浮着一艘会随波起伏的船。用于验证水面观感、资产拼接与
固定机位构图，不参与 `framework/` 的启动与玩法流程。

## 运行

```powershell
# 直接在 Godot 中右键 harbor_diorama.tscn → 运行场景，
# 或用命令行指定场景：
godot --path . res://dev_scenes/harbor/harbor_diorama.tscn
```

`project.godot` 的 `run/main_scene` 仍然是 `framework/ui/shell/main.tscn`，按 F5 不会进入本场景。

```powershell
# 无头验收：场景可加载、水面使用自定义 shader、船体会随波移动
godot --headless --path . --script res://tools/godot/verify_harbor_diorama.gd
```

## 文件

| 文件 | 作用 |
| --- | --- |
| `harbor_diorama.tscn` | 独立场景：天空/雾/黄昏逆光、码头、仓库剪影、吊车、货堆、浮船、相机 |
| `harbor_diorama.gd` | 场景根脚本：运行时把码头石墙压暗（GLB 材质是共享资源，不能逐个改内部节点） |
| `bobbing_boat.gd` | 浮船：采样与水面着色器同源的波浪，驱动升沉/纵摇/横摇 |

水面资源在 `assets/` 下，方便后续 `PortStage` 复用：

| 文件 | 作用 |
| --- | --- |
| `assets/shaders/water/harbor_water.gdshader` | 水面着色器 |
| `assets/materials/water/harbor_water.tres` | 近处水面材质（主场景使用） |
| `assets/materials/water/harbor_water_far.tres` | 远处水面材质（只保留地平线雾色，盖住水面网格边缘） |
| `assets/textures/water/water_normal.png` | 烘焙好的无缝水面法线噪声（512²） |
| `assets/textures/water/water_foam.png` | 烘焙好的无缝泡沫噪声（512²） |

## 水面实现要点

- 顶点位移：三条方向/速度不同的正弦波叠加，振幅 `swell_height`（默认 0.14 m），
  港内水面刻意保持平静。
- 片元法线：解析波面梯度 + 两层滚动噪声法线（`water_normal.png`），按相机距离衰减，
  避免远处闪烁。
- 菲涅耳天空反射 + 太阳高光/耀斑路径：太阳方向由 `sun_direction` 统一控制，
  和场景 `Sun` 的朝向保持一致。
- 岸边泡沫（`shore_z` / `shore_span`）与船体椭圆泡沫环（`boat_center` / `boat_half_size` /
  `boat_yaw`），泡沫噪声来自 `water_foam.png`。
- 远处水面单独一层低模平面，只输出雾色，遮住 500×400 主水面的网格边缘。
- 兼容 Godot 的 GL Compatibility 渲染器；不使用深度纹理/屏幕纹理。

## 调参入口

- 水面颜色/反射/泡沫：`assets/materials/water/harbor_water.tres` 的 shader 参数。
- 波浪振幅/速度：着色器 `swell_height`、`wave_speed`；**船体 `bobbing_boat.gd` 顶部的同名常量
  必须同步修改**，否则船和水会各动各的。
- 构图：`HarborDiorama/Camera3D` 固定机位（位置、`rotation_degrees`、`fov`）。
- 船体泡沫环：`boat_center`、`boat_half_size`、`boat_yaw` 与 `World/ShipBob` 的位置/朝向对应。

## 已知边界

- 场景是固定机位的表现样片，没有交互、碰撞、导航点，也没有接入 `StageDirector`。
- 码头仓房、烟囱、窗灯是场景内程序化 BoxMesh，用作剪影与尺度参照；其余均为 `assets/models` 的 GLB。
- 目标分辨率 1440×900；更小窗口下构图会裁边，尚未做响应式机位。
