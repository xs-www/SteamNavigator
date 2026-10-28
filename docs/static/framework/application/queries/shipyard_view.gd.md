# `framework/application/queries/shipyard_view.gd`

> 作用：船厂只读 ViewModel；统一投影模块改装/打造/仓库、舰载武器 socket、购买/装配/库存、船体每视图蓝图线稿的已解析路径，以及槽位圆点用的蓝图锚点（`ship.slot_anchors`）。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardViewQuery` | L1 |
| `SLOT_VIEW_DEFS` | L37 |
| `execute(_params: Dictionary, context) -> Dictionary` | L46 |

Shipyard ViewModel: current modules, transit modules, port warehouse, craft
recipes, open craft orders, wait options and every purchasable module with the
same blocker rules as ship.install_module / ship.craft_module. New arrays are
always present so the UI can render them even without a run or outside a shipyard.
`ship.blueprint_views.{side,top}` is resolved from hull `data.blueprint_views`
through AssetService into `{image_key, path, width, height, space}`; the 2D stage
draws them in the refit view and falls back to the generic section when absent.
4.5.5：剧情期间（`StoryService.module_filter`）购买 / 打造 / 仓库候选按 Core
`unlocked_modules` 裁剪；当前已装模块与当前槽位仍完整输出，保证可以卸下。

## `ship.slot_anchors`（P2b 契约，2026-10-28）
把内容 `hull.data.module_slots[]` / `hull.data.compartments[]` 的
`blueprint_position.side`（左上原点 0..1，相对 `space:"trimmed"` 侧视线稿）投影成
UI 槽位键，供 `SNShipView` 在船体上画圆点 + 折线：
```
{
  "hull": [x, y], "boiler": [x, y], "navigation_module": [x, y],
  "safety_module": [x, y], "passenger_cabin": [x, y],
  "cargo_modules": [[x, y], ...]   # 按 x 从左到右，序号对应 UI 货舱槽
}
```
- `module_slots` 按 `allowed_categories` 映射（boiler/cabin/cargo），`navigation` /
  `safety` 同属 utility，用 id 关键字区分；不依赖 id 的其它键留空。
- `compartments` 按 `allowed_types` 映射：cabin→客舱，其余→货舱（`cargo_N` 顺序）。
- schema 的 `module_slots.allowed_categories` 没有 `hull`，因此 `hull` 锚点默认用所有
  已解析锚点的质心兜底（内容显式给 `id:"hull"` 的 module_slot 时优先采用）。
- 内容没有锚点时返回**空字典**：UI 回退到面板内通用锚点，旧内容 / SDK 模板不崩。

模块索引：[framework/application](../README.md)
