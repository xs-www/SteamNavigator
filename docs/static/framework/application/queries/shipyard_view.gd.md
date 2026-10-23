# `framework/application/queries/shipyard_view.gd`

> 作用：船厂只读 ViewModel；统一投影模块改装/打造/仓库、舰载武器 socket、购买/装配/库存，以及船体每视图蓝图线稿的已解析路径。

- 类型：GDScript 源文件

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `ShipyardViewQuery` | L1 |
| `SLOT_VIEW_DEFS` | L19 |
| `execute(_params: Dictionary, context) -> Dictionary` | L28 |

Shipyard ViewModel: current modules, transit modules, port warehouse, craft
recipes, open craft orders, wait options and every purchasable module with the
same blocker rules as ship.install_module / ship.craft_module. New arrays are
always present so the UI can render them even without a run or outside a shipyard.
`ship.blueprint_views.{side,top}` is resolved from hull `data.blueprint_views`
through AssetService into `{image_key, path, width, height, space}`; the 2D stage
draws them in the refit view and falls back to the generic section when absent.
4.5.5：剧情期间（`StoryService.module_filter`）购买 / 打造 / 仓库候选按 Core
`unlocked_modules` 裁剪；当前已装模块与当前槽位仍完整输出，保证可以卸下。

模块索引：[framework/application](../README.md)
