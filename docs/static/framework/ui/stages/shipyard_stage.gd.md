# `framework/ui/stages/shipyard_stage.gd`

> 作用：船厂 EXTERIOR 固定 3/4 机位船体舞台（首个切片的迁移目标）：自建环境/灯光/水面/相机，按 ViewModel 的 `hull_model_path`（旧 `hull_tier` 路径仅 dev 回退）挂载船体 GLB（切片 5 起 `ship.visual` 命中时改由 `ShipVisualAssembler` 装配船体 + rig_kit + 武器），并在 `_process` 做升沉/横摇。

- 关键依赖：`LocationStage`、`StageKit`、`ContentAssetLoader`
- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardStage` | L1 |
| `MODEL_BY_TIER` | L21 |
| `FALLBACK_MODEL` | L26 |
| `BACKGROUND_COLOR` | L27 |
| `WATER_COLOR` | L28 |
| `CAMERA_DIRECTION` | L29 |
| `CAMERA_FOV` | L30 |
| `FRAMING_MARGIN` | L31 |
| `BOB_AMPLITUDE` | L32 |
| `BOB_SPEED` | L33 |
| `enter(_payload: Dictionary = {}) -> void` | L55 |
| `exit() -> void` | L59 |
| `bind(view_model: Dictionary = {}) -> void` | L63 |
| `has_ship() -> bool` | L70 |
| `model_path() -> String` | L74 |
| `assembly_report() -> Dictionary` | L80 |
| `rig_report() -> Dictionary` | L85 |
| `weapon_mounts() -> Array` | L92 |

## 契约与约束

- `stage_id` 默认 `shipyard`（舞台场景再显式覆盖）。
- `bind()` 接受完整 ViewModel 或直接以 ship 字典作为根；内部深拷贝 `ship`，重复 bind 同一模型不重建船体。
- 船体路径优先 `hull_model_path`；为空才按 `hull_tier` 回退 `assets/models/ships/*.glb`，该文件不存在再退 `SN_Ship_Prototype.glb`；加载失败时舞台保持空场景，船厂继续用 `SNShipView` 程序化占位。
- 相机取景用 `StageKit.visual_aabb()` + 30° 长焦 FOV；水面泡沫环绑到当前船体包围盒（shore 推远、隐藏岸线泡沫）。
- `enter()` 恢复 `_process`，`exit()` 停止；不可见时不写升沉，避免隐藏舞台继续运动。
- 切片 5（ShipVisualAssembler）：`ship.visual` 计划（由 `ShipVisualPlan.resolve()` 生成）存在且 hull 路径可用时走 `ShipVisualAssembler.assemble()`，装配船体 GLB + rig_kit 套件 + 武器；装配失败 / 无计划回退原 `hull_model_path`→`hull_tier`→`SN_Ship_Prototype`→2D 占位链。
- 新增只读 `assembly_report()` / `rig_report()` / `weapon_mounts()`；船厂舞台不做静态合批，武器 `ShipWeaponMount` 句柄保持有效。

## 重点逻辑

### `_apply_model() / _rebuild_ship(path)`

- `hull_model_path` 为空时用 `_fallback_path_for_tier(hull_tier)`；路径相同时直接复用现有 Ship 根，否则释放旧节点并新建 `Ship` 节点。
- GLB 优先 `ContentAssetLoader.instantiate_model()` 读模组原始文件，`ResourceLoader` 作为已导入场景兜底；挂载成功后重新取景并更新泡沫环。

### `_process(delta)`

- `sin(t*0.9)*0.12` 升沉 + `sin(t*0.675)*0.004` 横摇；不做航行/物理。

模块索引：[framework/ui](../README.md)
