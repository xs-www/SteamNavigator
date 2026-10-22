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
| `expectedTypes(field)` | L210 |
| `listIdFor(field)` | L214 |
| `renderDatalists(project)` | L220 |
| `translated(project, key)` | L267 |
| `label(typeKey, field)` | L274 |
| `hint(typeKey, field)` | L278 |
| `fieldShell(typeKey, field, control, options)` | L282 |
| `inputText(path, value, options)` | L296 |
| `assetMatchesKind(asset, kind)` | L304 |
| `assetPicker(path, value, kind, project, options)` | L311 |
| `inputNumber(path, value, schema, options)` | L343 |
| `selectEnum(path, value, values, options)` | L355 |
| `toggle(path, checked, text)` | L367 |
| `rangePair(path, value, itemSchema, itemFile)` | L374 |
| `refInput(path, value, field, options)` | L384 |
| `stringList(path, value, options)` | L395 |
| `enumMulti(path, value, values)` | L413 |
| `arrayShell(path, items, renderItem, addLabel, emptyText, addExtra)` | L427 |
| `itemHead(path, index, title, options)` | L439 |
| `renderModifier(item, index, path, ctx)` | L451 |
| `renderMaterial(item, index, path, ctx)` | L463 |
| `renderPayload(item, index, path, ctx)` | L474 |
| `renderMarket(item, index, path)` | L488 |
| `renderOperation(item, index, path)` | L500 |
| `renderOption(item, index, path, ctx)` | L513 |
| `conditionKind(value)` | L539 |
| `renderCondition(value, path, ctx, nested, depth)` | L547 |
| `conditionField(field, value, path)` | L604 |
| `renderEffect(item, index, path, ctx)` | L618 |
| `effectField(field, value, path)` | L633 |
| `renderObjectFields(objectSchema, objectFile, value, basePath, ctx, options)` | L647 |
| `renderField(field, schema, value, path, ctx, options, schemaFile)` | L665 |
| `previewLocalizationKey(key, draft)` | L778 |
| `renderKeyBlock(project, definition, field, typeKey, key, draft, token)` | L786 |
| `renderAdditionalLocalization(project, definition, typeKey, draft)` | L819 |
| `renderHullModuleConfiguration(definition)` | L834 |
| `SOCKET_CLASSES` | L868 |
| `SOCKET_KINDS` | L869 |
| `SOCKET_CLASS_COLORS` | L870 |
| `SOCKET_ROW_STYLE` | L877 |
| `socketBadge(value)` | L879 |
| `socketValueCounts(items, key)` | L885 |
| `socketRowHead(path, index, title, badge)` | L895 |
| `socketPositionField(path, value)` | L906 |
| `socketDuplicateNote(duplicate, text)` | L922 |
| `renderWeaponSocketRow(item, index, nameCounts, indexCounts)` | L926 |
| `renderRigSocketRow(item, index, nameCounts, indexCounts)` | L978 |
| `socketEnumOptions(values, field)` | L1038 |
| `renderHullSocketConfiguration(definition)` | L1043 |
| `renderDefinitionForm(options)` | L1082 |
| `SNUI (global)` | L1168 |

## 契约与约束

- 渲染层只输出 HTML；所有编辑通过 `data-field` / `data-action` 交给 app.js，不直接修改项目。
- 表单字段类型、枚举、范围与必填来自 Schema；专用控件只针对 modifier/material/payload/condition/effect/option 等结构。
- Schema 2.0 草案类型复用同一套 Schema 驱动表单；`schema-bundle` 缺少该 Schema 时给出提示并退回原始 JSON 编辑，而不是整页报错。
- 标准实体表单额外呈现所有语言的名称/描述暂存输入，以及 information.texture/model 资源键配置。
- 贴图与模型不用浏览器原生 datalist：图片候选仅含 png/webp/svg，模型候选仅含 GLB，并保留直接输入资源键能力。
- 船体把 cargo_slots/cabin_slots 移入专属模块区，并展示运行时固定的锅炉、导航、安全各一槽；普通数据区不重复渲染。
- 船体安装点子面板：`weapon_sockets` / `rig_sockets` 表格行可增删，按 `socket_class` / `socket_kind` 着色徽标，重复 name / 索引就地提示；武器草案复用通用 Schema 渲染并显示中文枚举标签。
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
