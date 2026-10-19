# `SNModMaker/tools/content_json.mjs`

> 作用：保源 JSON 源文本编辑器（纯函数、无 fs）：解析带 start / end 的节点树，只替换目标节点附近的文本切片，让 CLI 增删改内容时既有字节、缩进与 BOM 保持不变。

- 关键依赖：`content.mjs（唯一调用方）`
- 类型：Node ES 模块

## 关键符号

| 符号 | 位置 |
| --- | --- |
| `WHITESPACE` | L16 |
| `NUMBER_RE` | L17 |
| `syntaxError(message, offset)` | L19 |
| `parseSource(text)` | L27 |
| `skipWhitespace()` | L35 |
| `parseString()` | L43 |
| `parseNumber()` | L71 |
| `parseLiteral(word, type, value)` | L84 |
| `parseValue()` | L93 |
| `parseObject()` | L113 |
| `parseArray()` | L149 |
| `findNode(root, path)` | L185 |
| `nodePathToValue(root, text, path)` | L213 |
| `lineIndentAt(text, index)` | L220 |
| `columnAt(text, index)` | L229 |
| `normalizeIndent(indent)` | L234 |
| `scalarText(value)` | L240 |
| `isScalar(value)` | L251 |
| `formatInline(value)` | L257 |
| `isScalarArray(value)` | L267 |
| `formatStyled(value, indentLevel = 0, inlineLimit = 100)` | L276 |
| `format(node, depth)` | L279 |
| `defaultFormatter(value, indent)` | L303 |
| `assertInsertable(value)` | L307 |
| `findArrayNode(text, arrayNode)` | L323 |
| `arrayIsMultiline(text, node)` | L329 |
| `insertArrayItem(text, arrayNode, value, formatter)` | L337 |
| `removeArrayItem(text, arrayNode, index)` | L365 |
| `replaceNodeValue(text, node, value, formatter)` | L388 |
| `insertObjectMember(text, objectNode, key, value, formatter)` | L403 |

## 契约与约束

- 节点 `start / end` 是半开区间（`end` 指向最后一个字符之后），`open / close` 是括号下标；object 带 `members[{key, keyStart, value}]`（`findNode` 取同名键最后一个），array 带 `items[]`。
- `parseSource` 是严格 JSON 解析：尾随内容、悬空逗号、前导零、未转义控制字符与嵌套超过 256 层都抛 `SyntaxError`（附源偏移）；字符串值交 `JSON.parse` 校验转义。
- BOM 容忍：开头 U+FEFF 跳过但游标起点同步前移，节点偏移仍以原文为准，因此插入 / 删除切片会原样保留 BOM；`add` 后再 `rm` 仍可逐字节还原。
- 函数不重新定位节点：调用方传入的 node 必须与 text 来自同一次 `parseSource`，文本变化后需重新解析。
- 插入 / 删除只动目标节点附近的字节：是否多行、缩进与逗号都取自源文本；对象插入与数组插入使用同一套策略。
- `formatStyled`：2 空格缩进（缩进基准可传列号或字符串），对象恒多行，纯标量数组在缩进基准加行内长度不超过 `inlineLimit`（默认 100）时单行，空容器为 `[]` / `{}`，返回值首行不带缩进。

## 重点逻辑

### `parseSource(text)`

- 手写递归下降：skipWhitespace / parseString / parseNumber / parseLiteral / parseObject / parseArray 组成节点树并记录偏移。
- 数字用 JSON 数字正则后 `Number(...)`，字符串 value 由切片交 `JSON.parse`；解析结束要求恰好消费完整文本。

### `insertArrayItem(text, arrayNode, value, formatter)`

- 空数组展开为三行（换行、缩进两格的新项、原关闭缩进）；单行数组在 `]` 前内联插入 `, <inline>`；多行数组在最后一项之后追加逗号、换行与新项，并复用最后一项的缩进。
- 插入前用 `assertInsertable` 拒绝 undefined 与不可序列化值；`formatter(value, indent)` 返回首行不带缩进的文本。

### `removeArrayItem(text, arrayNode, index)`

- 唯一项 → `[]`；首项 → 删除到第二项 start（带走尾随逗号与缩进）；中间 / 末项 → 从前一项 end 删除到目标 end。
- 这正是 `add` → `rm` 逐字节还原与首 / 中 / 末 / 唯一项四种边界的关键不变量。

### `replaceNodeValue / insertObjectMember`

- 标量直接切片替换 token；对象 / 数组用 `formatStyled(value, columnAt(node.start))` 按起始列重写。
- `insertObjectMember` 与数组插入同策略：空对象展开、单行对象内联、多行对象插在最后成员之后。

### `formatStyled / formatInline`

- `formatStyled` 递归输出多行文本，首行不带缩进、后续行按基准逐层加两格；`formatInline` 生成永不换行的一行表示，供单行数组 / 对象与内联插入使用。
- 非有限数字或不可序列化值抛 `TypeError`；缩进参数传 number 时按列数生成空格。

模块索引：[SNModMaker](../README.md)
