# `framework/ui/components/sn_ship_stage_3d.gd`

> 作用：船厂正常态的 3D 舞台适配器：把通用 `SNStageHost` 接入既有 `SNShipView.set_renderer()` 协议，加载 `ShipyardStage` 承载船体、环境、灯光与水面；节点本身只做 ViewModel/模式转发与显隐。

- 关键依赖：`SNStageHost`、`ShipyardStage`、`SNShipView`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `SNShipStage3D` | L1 |
| `SHIPYARD_STAGE_SCENE` | L17 |
| `MODEL_BY_TIER` | L18 |
| `FALLBACK_MODEL` | L23 |
| `is_supported() -> bool` | L32 |
| `has_ship() -> bool` | L48 |
| `model_path() -> String` | L53 |
| `ship_view_update(model: Dictionary) -> void` | L60 |
| `ship_view_set_mode(mode: int) -> void` | L65 |
| `ship_view_highlight(slot_ids: Array) -> void` | L70 |

## 契约与约束

- `SNShipStage3D` 现在是 `SNStageHost` 的薄适配器：视口、World3D 与舞台生命周期由宿主拥有，相机/灯光/水面/船体由 `ShipyardStage` 拥有。
- 实现 `ship_view_update(model)` / `ship_view_set_mode(mode)` / `ship_view_highlight(slot_ids)`；`_ready` 时自动加载 `res://framework/ui/stages/shipyard_stage.tscn`。
- `ship_view_update` 把 `{"ship": model}` 转发给舞台并缓存；`ship_view_set_mode` 用 `set_stage_visible(mode == EXTERIOR)` 控制 3D 显隐，CUTAWAY 隐藏视口但保留 2D 纵剖图。
- `ship_view_highlight()` 记录槽位并转发给舞台（舞台侧高亮属下一片）；`has_ship()` / `model_path()` 代理到当前舞台。
- `is_supported()` 只判断本地是否有 `hull_tier` 旧路径可回退；正式发布由页面用 `hull_model_path` 非空来挂载舞台，PCK 不含 `assets/models` 也能显示 3D。
- 只做表现层：不读 GameState / QueryBus / CommandBus；渲染器方法在 `_ready` 之前被调用时先缓存 model/mode，`_ready` 后统一应用。

模块索引：[framework/ui](../README.md)
