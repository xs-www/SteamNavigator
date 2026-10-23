# `SNModMaker/js/ui.js`

> 作用：Schema 驱动的表单渲染与通用 UI 组件：字段控件、数组/条件/效果编辑器、自定义资源选择器、船体模块区、模态框与 Toast。

- 关键依赖：`validate.flattenObject/deref`、`store`、`catalog`
- 类型：浏览器经典脚本

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `esc(value)` | L18 |
| `attr(value)` | L27 |
| `fmtSize(bytes)` | L31 |
| `fmtDate(value)` | L38 |
| `debounce(fn, wait)` | L47 |
| `uid(prefix)` | L55 |
| `schemas()` | L63 |
| `contentSchema(typeKey)` | L67 |
| `dataSchema(typeKey)` | L72 |
| `resolve(schema, file)` | L91 |
| `toast(message, type, timeout)` | L99 |
| `modal(options)` | L112 |
| `closeModal()` | L138 |
| `confirm(options)` | L143 |
| `setBusy(active, text)` | L177 |
| `REF_TYPE_BY_FIELD` | L188 |
| `expectedTypes(field)` | L226 |
| `listIdFor(field)` | L230 |
| `renderDatalists(project)` | L236 |
| `translated(project, key)` | L283 |
| `label(typeKey, field)` | L290 |
| `hint(typeKey, field)` | L294 |
| `fieldShell(typeKey, field, control, options)` | L298 |
| `inputText(path, value, options)` | L312 |
| `assetMatchesKind(asset, kind)` | L320 |
| `assetPicker(path, value, kind, project, options)` | L327 |
| `inputNumber(path, value, schema, options)` | L359 |
| `selectEnum(path, value, values, options)` | L371 |
| `toggle(path, checked, text)` | L383 |
| `rangePair(path, value, itemSchema, itemFile)` | L390 |
| `refInput(path, value, field, options)` | L400 |
| `stringList(path, value, options)` | L411 |
| `enumMulti(path, value, values)` | L429 |
| `arrayShell(path, items, renderItem, addLabel, emptyText, addExtra)` | L443 |
| `itemHead(path, index, title, options)` | L455 |
| `renderModifier(item, index, path, ctx)` | L467 |
| `renderMaterial(item, index, path, ctx)` | L479 |
| `renderPayload(item, index, path, ctx)` | L490 |
| `renderMarket(item, index, path)` | L504 |
| `renderOperation(item, index, path)` | L516 |
| `renderOption(item, index, path, ctx)` | L529 |
| `conditionKind(value)` | L555 |
| `renderCondition(value, path, ctx, nested, depth)` | L563 |
| `conditionField(field, value, path)` | L620 |
| `renderEffect(item, index, path, ctx)` | L634 |
| `effectField(field, value, path)` | L649 |
| `renderObjectFields(objectSchema, objectFile, value, basePath, ctx, options)` | L663 |
| `renderField(field, schema, value, path, ctx, options, schemaFile)` | L681 |
| `previewLocalizationKey(key, draft)` | L794 |
| `renderKeyBlock(project, definition, field, typeKey, key, draft, token)` | L802 |
| `renderAdditionalLocalization(project, definition, typeKey, draft)` | L835 |
| `renderHullModuleConfiguration(definition)` | L850 |
| `SOCKET_CLASSES` | L884 |
| `SOCKET_KINDS` | L885 |
| `SOCKET_CLASS_COLORS` | L886 |
| `SOCKET_ROW_STYLE` | L893 |
| `socketBadge(value)` | L895 |
| `socketValueCounts(items, key)` | L901 |
| `socketRowHead(path, index, title, badge)` | L911 |
| `socketPositionField(path, value)` | L922 |
| `socketDuplicateNote(duplicate, text)` | L938 |
| `renderWeaponSocketRow(item, index, nameCounts, indexCounts)` | L942 |
| `renderRigSocketRow(item, index, nameCounts, indexCounts)` | L995 |
| `socketEnumOptions(values, field)` | L1055 |
| `renderHullSocketConfiguration(definition)` | L1060 |
| `blueprintVectorFields(path, value, viewLabel)` | L1103 |
| `blueprintPositionField(path, value)` | L1117 |
| `blueprintAssetPreview(project, key)` | L1129 |
| `renderCompartmentRow(item, index)` | L1137 |
| `renderModuleSlotRow(item, index)` | L1164 |
| `blueprintSlotCount(items)` | L1194 |
| `renderHullBlueprintConfiguration(definition, project)` | L1199 |
| `renderDefinitionForm(options)` | L1243 |
| `SNUI (global)` | L1333 |

## 契约与约束

- 渲染层只输出 HTML；所有编辑通过 `data-field` / `data-action` 交给 app.js，不直接修改项目。
- 表单字段类型、枚举、范围与必填来自 Schema；专用控件只针对 modifier/material/payload/condition/effect/option 等结构。
- Schema 2.0 草案类型复用同一套 Schema 驱动表单；`schema-bundle` 缺少该 Schema 时给出提示并退回原始 JSON 编辑，而不是整页报错。
- 标准实体表单额外呈现所有语言的名称/描述暂存输入，以及 information.texture/model 资源键配置。
- 贴图与模型不用浏览器原生 datalist：图片候选仅含 png/webp/svg，模型候选仅含 GLB，并保留直接输入资源键能力。
- 船体把 cargo_slots/cabin_slots 移入专属模块区，并展示运行时固定的锅炉、导航、安全各一槽；普通数据区不重复渲染。
- 船体安装点子面板：`weapon_sockets` / `rig_sockets` 表格行可增删，按 `socket_class` / `socket_kind` 着色徽标，重复 name / 索引就地提示；武器草案复用通用 Schema 渲染并显示中文枚举标签。
- 船体蓝图区：绑定 `blueprint_views.side/top.image` 线稿资源；`compartments` / `module_slots` 用专属行渲染（ID、等级/类别限制、`blueprint_position` 四分量输入），并提供「打开蓝图槽位编辑器」入口。
- 武器安装点行渲染 `blueprint.side/top` 的 U/V 数值输入；坐标 0..1，留空表示该视图不显示。
- 所有用户文本与属性值经过 `esc/attr` 转义；引用候选来自当前项目 + Core 索引。
- 表单生成的路径是相对定义的属性路径（manifest 除外），与 app.setByPath 的约定一致。

## 重点逻辑

### `renderField(field, schema, value, path, ctx, options, schemaFile)`

- 先解引用；按 `id_ref/range2/modifier/craft_material/payload/option_data/effect/condition_node` 分派专用控件，再按 type/enum 分派通用控件。
- 递归传入当前 schema 文件，保证 common.schema.json 内的本地 `$ref` 能正确解析。

### `renderDefinitionForm(ctx)`

- 普通定义渲染身份区、条目内多语言值、视觉资源与数据区；补丁定义渲染目标、来源约束与操作列表。
- ID 输入只显示 local 部分，前缀由 app 在写回时补齐；名称/描述键显示只读的待提交预览。
- hulls 额外渲染模块配置区，并从通用数据字段中跳过 cargo_slots/cabin_slots。

### `assetPicker(path, value, kind, project)`

- 输出可编辑输入、展开按钮和主题化候选菜单；候选同时显示资源键与项目内路径。
- kind=image 仅接受图片 MIME/扩展名，kind=model 仅接受 model/gltf-binary 或 .glb。

### `renderCondition(value, path, ctx)`

- 支持 leaf、all、any、not 递归；操作码切换只保留适用字段。
- 空条件显示“始终满足”，由 app 添加首个节点。

模块索引：[SNModMaker](../README.md)
