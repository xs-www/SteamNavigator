# `framework/ui/stages/location_stage.gd`

> 作用：2.5D 固定机位舞台契约基类：舞台自持相机/灯光/环境/水面/道具与 idle 动画，由 `SNStageHost` 驱动 enter→bind→exit 生命周期；只读已解析 ViewModel，不访问 GameState / QueryBus / CommandBus。

- 关键依赖：`SNStageHost`、`SNShipStage3D`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `LocationStage` | L1 |
| `portal_requested (signal)` | L19 |
| `enter(_payload: Dictionary = {}) -> void` | L26 |
| `exit() -> void` | L30 |
| `bind(_view_model: Dictionary = {}) -> void` | L34 |
| `has_visual() -> bool` | L41 |
| `hotspot_anchors() -> Dictionary` | L48 |

## 契约与约束

- 信号 `portal_requested(target_id)` 只表达玩家意图；host 重新发出，由 UI Shell / 未来的 StageDirector 决定跳转。
- `stage_id` 由具体舞台场景覆盖（`shipyard` / `port`）；为空时 host 回退到节点名。
- `enter(payload)` 进入时启用局部动画并应用 payload；`bind(view_model)` 可重复调用做数据刷新；`exit()` 停止动画并丢弃局部状态。
- `has_visual()` 默认 true：程序化舞台在内容资产缺失时仍可绘制，页面据此决定是否回退 2D banner。
- `hotspot_anchors()` 返回设施/入口 id → 世界坐标；2D Control 热点用舞台相机投影这些点，不做 3D RayCast。

模块索引：[framework/ui](../README.md)
