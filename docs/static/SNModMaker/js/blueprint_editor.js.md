# `SNModMaker/js/blueprint_editor.js`

> 作用：船体蓝图槽位的可视化拖拽编辑器；在绑定的侧视 / 俯视线稿上显示舱位、模块位与武器位标记，拖动后自动计算归一化 uv 并通过 `data-field` 写回船体定义。

- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `META_KEYS` | L22 |
| `clamp01(value)` | L27 |
| `round4(value)` | L33 |
| `uvFromPoint(rect, clientX, clientY)` | L41 |
| `pointFromUv(rect, uv)` | L50 |
| `readDefinitionData(definition)` | L60 |
| `positionFieldOf(slot)` | L64 |
| `slotIdOf(item, fallback)` | L70 |
| `slotName(item)` | L76 |
| `collectSlots(definition)` | L81 |
| `slotKey(slot)` | L107 |
| `slotPosition(slot, view)` | L111 |
| `resolveViewImage(definition, project, view)` | L121 |
| `isImageAsset(asset)` | L138 |
| `findImageAssets(project)` | L144 |
| `formatPair(pair)` | L149 |
| `markerClass(group)` | L154 |
| `groupLabel(group)` | L158 |
| `escapeHtml(value)` | L164 |
| `assetPickerHtml(path, value, project, placeholder)` | L173 |
| `mount(host, options)` | L182 |
| `SNBlueprintEditor (global)` | L508 |

## 契约与约束
- 纯经典脚本（无 ES module），暴露 `globalThis.SNBlueprintEditor`；`mount()` 之外不访问 DOM，便于 Node 单测。
- 坐标空间：每个视图自己的线稿纹理归一化 uv，原点左上，范围 0..1；`space` 由 `data.blueprint_views.<view>.space` 决定，编辑器不重解释。
- 写回路径：舱位 / 模块位 = `data.<array>.<i>.blueprint_position.<view>`，武器位 = `data.weapon_sockets.<i>.blueprint.<view>`。
- 所有写入都经 `options.writeField(path, [u, v])`；由 app.js 转成一次 `change` 事件，复用撤销、校验与自动保存。本模块不直接改 project / definition 结构。

## 重点逻辑
### `uvFromPoint(rect, clientX, clientY)`
- 用图片实际渲染矩形（`getBoundingClientRect`）做分母，避免留白导致坐标漂移；越界钳制到 0..1，并保留 4 位小数。
### `collectSlots(definition)`
- 汇总 `compartments` / `module_slots` / `weapon_sockets` 为统一槽位描述；没有坐标的槽位也会返回，编辑器用默认位置显示为“未定位”。
### `mount(host, options)`
- 渲染视图切换、线稿绑定选择器、画布与侧栏；拖动在 pointerup 时提交一次，避免连续 pointermove 产生大量历史快照。
- 线稿通过 `project.assets[].dataUrl` 显示；工作区模式下 core 资源可能没有字节数据，此时只提示资源键而不报错。

模块索引：[SNModMaker](../README.md)
