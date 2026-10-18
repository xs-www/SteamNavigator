# `SNModMaker/js/ui.js`

> 作用：Schema 驱动的表单渲染与通用 UI 组件：字段控件、数组/条件/效果编辑器、模态框、Toast、Datalist。

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
| `expectedTypes(field)` | L204 |
| `listIdFor(field)` | L208 |
| `renderDatalists(project)` | L214 |
| `translated(project, key)` | L262 |
| `label(typeKey, field)` | L269 |
| `hint(typeKey, field)` | L273 |
| `fieldShell(typeKey, field, control, options)` | L277 |
| `inputText(path, value, options)` | L291 |
| `inputNumber(path, value, schema, options)` | L299 |
| `selectEnum(path, value, values, options)` | L311 |
| `toggle(path, checked, text)` | L323 |
| `rangePair(path, value, itemSchema, itemFile)` | L330 |
| `refInput(path, value, field, options)` | L340 |
| `stringList(path, value, options)` | L351 |
| `enumMulti(path, value, values)` | L369 |
| `arrayShell(path, items, renderItem, addLabel, emptyText, addExtra)` | L383 |
| `itemHead(path, index, title, options)` | L395 |
| `renderModifier(item, index, path, ctx)` | L407 |
| `renderMaterial(item, index, path, ctx)` | L419 |
| `renderPayload(item, index, path, ctx)` | L430 |
| `renderMarket(item, index, path)` | L444 |
| `renderOperation(item, index, path)` | L456 |
| `renderOption(item, index, path, ctx)` | L469 |
| `conditionKind(value)` | L495 |
| `renderCondition(value, path, ctx, nested, depth)` | L503 |
| `conditionField(field, value, path)` | L560 |
| `renderEffect(item, index, path, ctx)` | L574 |
| `effectField(field, value, path)` | L589 |
| `renderObjectFields(objectSchema, objectFile, value, basePath, ctx, options)` | L603 |
| `renderField(field, schema, value, path, ctx, options, schemaFile)` | L621 |
| `renderKeyBlock(project, definition, field, typeKey, key)` | L729 |
| `renderDefinitionForm(options)` | L740 |
| `SNUI (global)` | L798 |

## 契约与约束

- 渲染层只输出 HTML；所有编辑通过 `data-field` / `data-action` 交给 app.js，不直接修改项目。
- 表单字段类型、枚举、范围与必填来自 Schema；专用控件只针对 modifier/material/payload/condition/effect/option 等结构。
- 所有用户文本与属性值经过 `esc/attr` 转义；引用候选来自当前项目 + Core 索引。
- 表单生成的路径是相对定义的属性路径（manifest 除外），与 app.setByPath 的约定一致。

## 重点逻辑

### `renderField(field, schema, value, path, ctx, options, schemaFile)`

- 先解引用；按 `id_ref/range2/modifier/craft_material/payload/option_data/effect/condition_node` 分派专用控件，再按 type/enum 分派通用控件。
- 递归传入当前 schema 文件，保证 common.schema.json 内的本地 `$ref` 能正确解析。

### `renderDefinitionForm(ctx)`

- 普通定义渲染身份区（ID/名称键/描述键/标签/启用）与数据区；补丁定义渲染目标、来源约束与操作列表。
- ID 输入只显示 local 部分，前缀由 app 在写回时补齐。

### `renderCondition(value, path, ctx)`

- 支持 leaf、all、any、not 递归；操作码切换只保留适用字段。
- 空条件显示“始终满足”，由 app 添加首个节点。

模块索引：[SNModMaker](../README.md)
