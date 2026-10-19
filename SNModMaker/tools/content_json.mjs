/*
 * 保源 JSON 源文本编辑器（纯函数，无 fs）。
 *
 * 用途：内容 CLI 需要增删改模组内容而不重排既有字节。
 * parseSource() 建立带 start/end（半开区间）的节点树；其余函数只在
 * 目标节点附近做文本切片替换，数组项的插入/删除会精确复用原有缩进与逗号，
 * 因此 add 之后再 rm 可以逐字节还原原文件。
 *
 * 节点形状：
 *   { type:'object', start, end, open, close, members:[{ key, keyStart, value }] }
 *   { type:'array',  start, end, open, close, items:[node] }
 *   { type:'string'|'number'|'boolean'|'null', start, end, value }
 * start/end 是半开区间（end 指向最后一个字符之后）；open/close 是括号字符下标。
 */

const WHITESPACE = new Set([0x20, 0x09, 0x0a, 0x0d]);
const NUMBER_RE = /^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/;

function syntaxError(message, offset) {
  return new SyntaxError(`JSON 解析失败（偏移 ${offset}）：${message}`);
}

/**
 * 严格解析 JSON 源文本，返回 { root, text }。
 * 非法输入（包括尾随内容、悬空逗号、前导零等）会抛 SyntaxError。
 */
export function parseSource(text) {
  const source = String(text);
  let pos = 0;
  let depth = 0;
  // 允许 UTF-8 BOM：Windows 工具链（如 PowerShell 5.1）写出的 JSON 常带 BOM。
  // 偏移仍以原文为准，因此插入/删除切片会原样保留 BOM。
  if (source.charCodeAt(0) === 0xfeff) pos = 1;

  function skipWhitespace() {
    while (pos < source.length) {
      const code = source.charCodeAt(pos);
      if (!WHITESPACE.has(code)) break;
      pos += 1;
    }
  }

  function parseString() {
    const start = pos;
    if (source[pos] !== '"') throw syntaxError('期望字符串', pos);
    pos += 1;
    while (pos < source.length) {
      const ch = source[pos];
      if (ch === '\\') {
        if (pos + 1 >= source.length) throw syntaxError('字符串转义不完整', pos);
        pos += 2;
        continue;
      }
      if (ch === '"') {
        pos += 1;
        let value;
        try {
          value = JSON.parse(source.slice(start, pos));
        } catch (error) {
          throw syntaxError(error.message, start);
        }
        return { type: 'string', start, end: pos, value };
      }
      const code = source.charCodeAt(pos);
      if (code < 0x20) throw syntaxError('字符串中包含未转义的控制字符', pos);
      pos += 1;
    }
    throw syntaxError('字符串没有闭合', start);
  }

  function parseNumber() {
    const start = pos;
    const match = NUMBER_RE.exec(source.slice(pos));
    if (!match) throw syntaxError('数字格式无效', pos);
    pos += match[0].length;
    const next = source[pos];
    if (next !== undefined && !WHITESPACE.has(next.charCodeAt(0))
      && next !== ',' && next !== ']' && next !== '}') {
      throw syntaxError('数字后出现意外字符', pos);
    }
    return { type: 'number', start, end: pos, value: Number(match[0]) };
  }

  function parseLiteral(word, type, value) {
    if (source.slice(pos, pos + word.length) !== word) {
      throw syntaxError(`期望 ${word}`, pos);
    }
    const start = pos;
    pos += word.length;
    return { type, start, end: pos, value };
  }

  function parseValue() {
    depth += 1;
    if (depth > 256) throw syntaxError('嵌套层级过深', pos);
    try {
      skipWhitespace();
      const ch = source[pos];
      if (ch === '{') return parseObject();
      if (ch === '[') return parseArray();
      if (ch === '"') return parseString();
      if (ch === 't' || ch === 'f') {
        return parseLiteral(ch === 't' ? 'true' : 'false', 'boolean', ch === 't');
      }
      if (ch === 'n') return parseLiteral('null', 'null', null);
      if (ch === '-' || (ch >= '0' && ch <= '9')) return parseNumber();
      throw syntaxError(ch === undefined ? '内容意外结束' : `意外字符 ${JSON.stringify(ch)}`, pos);
    } finally {
      depth -= 1;
    }
  }

  function parseObject() {
    const open = pos;
    pos += 1;
    const members = [];
    skipWhitespace();
    if (source[pos] === '}') {
      const close = pos;
      pos += 1;
      return { type: 'object', start: open, end: pos, open, close, members };
    }
    for (;;) {
      skipWhitespace();
      const keyStart = pos;
      if (source[pos] !== '"') throw syntaxError('期望对象键', pos);
      const keyNode = parseString();
      skipWhitespace();
      if (source[pos] !== ':') throw syntaxError('对象键后缺少冒号', pos);
      pos += 1;
      const value = parseValue();
      members.push({ key: keyNode.value, keyStart, value });
      skipWhitespace();
      if (source[pos] === ',') {
        pos += 1;
        skipWhitespace();
        if (source[pos] === '}') throw syntaxError('对象中存在悬空逗号', pos);
        continue;
      }
      if (source[pos] === '}') {
        const close = pos;
        pos += 1;
        return { type: 'object', start: open, end: pos, open, close, members };
      }
      throw syntaxError('对象成员之间缺少逗号或括号未闭合', pos);
    }
  }

  function parseArray() {
    const open = pos;
    pos += 1;
    const items = [];
    skipWhitespace();
    if (source[pos] === ']') {
      const close = pos;
      pos += 1;
      return { type: 'array', start: open, end: pos, open, close, items };
    }
    for (;;) {
      const item = parseValue();
      items.push(item);
      skipWhitespace();
      if (source[pos] === ',') {
        pos += 1;
        skipWhitespace();
        if (source[pos] === ']') throw syntaxError('数组中存在悬空逗号', pos);
        continue;
      }
      if (source[pos] === ']') {
        const close = pos;
        pos += 1;
        return { type: 'array', start: open, end: pos, open, close, items };
      }
      throw syntaxError('数组项之间缺少逗号或括号未闭合', pos);
    }
  }

  const root = parseValue();
  skipWhitespace();
  if (pos !== source.length) throw syntaxError('JSON 之后存在多余内容', pos);
  return { root, text: source };
}

/** 按 (string|number)[] 路径取节点；不存在返回 null。 */
export function findNode(root, path) {
  let node = root;
  for (const segment of path || []) {
    if (!node) return null;
    if (node.type === 'object') {
      if (typeof segment !== 'string') return null;
      let found = null;
      for (let i = node.members.length - 1; i >= 0; i -= 1) {
        if (node.members[i].key === segment) {
          found = node.members[i];
          break;
        }
      }
      node = found ? found.value : null;
    } else if (node.type === 'array') {
      const index = typeof segment === 'number'
        ? segment
        : (/^\d+$/.test(String(segment)) ? Number(segment) : NaN);
      if (!Number.isInteger(index) || index < 0 || index >= node.items.length) return null;
      node = node.items[index];
    } else {
      return null;
    }
  }
  return node || null;
}

/** 调试用：按节点切片 JSON.parse；不给 path 时把第一个参数当节点。 */
export function nodePathToValue(root, text, path) {
  const node = path ? findNode(root, path) : root;
  if (!node || typeof node.start !== 'number') return undefined;
  return JSON.parse(String(text).slice(node.start, node.end));
}

/** 返回 index 所在行的前导空白（空格/制表符）。 */
export function lineIndentAt(text, index) {
  const source = String(text);
  const lineStart = source.lastIndexOf('\n', Math.max(0, index - 1)) + 1;
  let i = lineStart;
  while (i < source.length && (source[i] === ' ' || source[i] === '\t')) i += 1;
  return source.slice(lineStart, i);
}

/** 返回 index 在所在行内的列号（0 起）。 */
export function columnAt(text, index) {
  const source = String(text);
  return index - (source.lastIndexOf('\n', Math.max(0, index - 1)) + 1);
}

function normalizeIndent(indent) {
  if (typeof indent === 'number') return ' '.repeat(Math.max(0, Math.trunc(indent)));
  if (typeof indent === 'string') return indent;
  return '';
}

function scalarText(value) {
  if (value === null) return 'null';
  if (typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new TypeError('无法序列化非有限数字');
    return String(value);
  }
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  throw new TypeError(`无法序列化标量：${typeof value}`);
}

function isScalar(value) {
  return value === null || typeof value === 'string'
    || typeof value === 'number' || typeof value === 'boolean';
}

/** 行内风格：{"a": 1, "b": [2, 3]}。 */
export function formatInline(value) {
  if (isScalar(value)) return scalarText(value);
  if (Array.isArray(value)) return `[${value.map((item) => formatInline(item)).join(', ')}]`;
  if (typeof value === 'object' && value) {
    const entries = Object.entries(value).filter(([, child]) => child !== undefined);
    return `{${entries.map(([key, child]) => `${JSON.stringify(key)}: ${formatInline(child)}`).join(', ')}}`;
  }
  throw new TypeError(`无法序列化值：${String(value)}`);
}

function isScalarArray(value) {
  return Array.isArray(value) && value.every((item) => isScalar(item));
}

/**
 * 2 空格缩进风格化。
 * indent 可以是空格数量（列号）或缩进字符串；返回文本首行不带缩进，
 * 其余行以 indent 为基准逐层 +2 空格。
 */
export function formatStyled(value, indentLevel = 0, inlineLimit = 100) {
  const indent = normalizeIndent(indentLevel);

  function format(node, depth) {
    const prefix = indent + '  '.repeat(depth);
    if (isScalar(node)) return scalarText(node);
    if (Array.isArray(node)) {
      if (node.length === 0) return '[]';
      const inline = formatInline(node);
      if (isScalarArray(node) && prefix.length + inline.length <= inlineLimit) return inline;
      const inner = prefix + '  ';
      const lines = node.map((item) => inner + format(item, depth + 1));
      return `[\n${lines.join(',\n')}\n${prefix}]`;
    }
    if (typeof node === 'object' && node) {
      const entries = Object.entries(node).filter(([, child]) => child !== undefined);
      if (entries.length === 0) return '{}';
      const inner = prefix + '  ';
      const lines = entries.map(([key, child]) => `${inner}${JSON.stringify(key)}: ${format(child, depth + 1)}`);
      return `{\n${lines.join(',\n')}\n${prefix}}`;
    }
    throw new TypeError(`无法序列化值：${String(node)}`);
  }

  return format(value, 0);
}

function defaultFormatter(value, indent) {
  return formatStyled(value, indent);
}

function assertInsertable(value) {
  if (isScalar(value)) return;
  if (Array.isArray(value)) {
    for (const item of value) assertInsertable(item);
    return;
  }
  if (typeof value === 'object' && value) {
    for (const child of Object.values(value)) {
      if (child === undefined) throw new TypeError('无法插入 undefined');
      assertInsertable(child);
    }
    return;
  }
  throw new TypeError(`无法插入值：${String(value)}`);
}

function findArrayNode(text, arrayNode) {
  // 重新解析并未使用：调用方传入的节点与 text 必须来自同一次 parseSource。
  if (!arrayNode || arrayNode.type !== 'array') throw new TypeError('insertArrayItem/removeArrayItem 需要一个数组节点');
  return arrayNode;
}

function arrayIsMultiline(text, node) {
  return text.slice(node.open, node.close + 1).includes('\n');
}

/**
 * 在数组尾部插入一项，保持数组其余字节不变。
 * formatter(value, indentString) 负责返回首行不带缩进的文本。
 */
export function insertArrayItem(text, arrayNode, value, formatter) {
  const source = String(text);
  const node = findArrayNode(source, arrayNode);
  const format = typeof formatter === 'function' ? formatter : defaultFormatter;
  assertInsertable(value);

  if (node.items.length === 0) {
    const closeIndent = lineIndentAt(source, node.open);
    const itemIndent = `${closeIndent}  `;
    const formatted = format(value, itemIndent);
    const inner = `\n${itemIndent}${formatted}\n${closeIndent}`;
    return `${source.slice(0, node.open + 1)}${inner}${source.slice(node.close)}`;
  }

  if (!arrayIsMultiline(source, node)) {
    return `${source.slice(0, node.close)}, ${formatInline(value)}${source.slice(node.close)}`;
  }

  const last = node.items[node.items.length - 1];
  const itemIndent = lineIndentAt(source, last.start);
  const formatted = format(value, itemIndent);
  return `${source.slice(0, last.end)},\n${itemIndent}${formatted}${source.slice(last.end)}`;
}

/**
 * 删除数组第 index 项：正确处理首项 / 中间 / 末项 / 唯一项。
 * 唯一项时数组整体变成 []。
 */
export function removeArrayItem(text, arrayNode, index) {
  const source = String(text);
  const node = findArrayNode(source, arrayNode);
  const items = node.items;
  if (items.length === 0) return source;
  const position = Number(index);
  if (!Number.isInteger(position) || position < 0 || position >= items.length) {
    throw new RangeError(`数组下标越界：${index}`);
  }
  if (items.length === 1) {
    return `${source.slice(0, node.start)}[]${source.slice(node.end)}`;
  }
  if (position === 0) {
    // 删掉「首项 + 尾随逗号 + 下一项的缩进」，保留下一项之前的分隔。
    return `${source.slice(0, items[0].start)}${source.slice(items[1].start)}`;
  }
  // 中间项与末项：删除「前一项结尾 → 目标项结尾」，即逗号 + 空白 + 目标项。
  return `${source.slice(0, items[position - 1].end)}${source.slice(items[position].end)}`;
}

/**
 * 替换节点值：标量直接替换 token；对象/数组按节点起始列风格化重写。
 */
export function replaceNodeValue(text, node, value, formatter) {
  const source = String(text);
  if (!node || typeof node.start !== 'number') throw new TypeError('replaceNodeValue 需要一个节点');
  if (isScalar(value)) {
    return `${source.slice(0, node.start)}${scalarText(value)}${source.slice(node.end)}`;
  }
  const format = typeof formatter === 'function' ? formatter : defaultFormatter;
  const formatted = format(value, columnAt(source, node.start));
  return `${source.slice(0, node.start)}${formatted}${source.slice(node.end)}`;
}

/**
 * 在对象末尾插入成员（CLI 的 set 需要给定义补新字段时使用）。
 * 与 insertArrayItem 相同的保源策略。
 */
export function insertObjectMember(text, objectNode, key, value, formatter) {
  const source = String(text);
  if (!objectNode || objectNode.type !== 'object') throw new TypeError('insertObjectMember 需要一个对象节点');
  if (typeof key !== 'string' || !key) throw new TypeError('insertObjectMember 需要非空字符串键');
  const format = typeof formatter === 'function' ? formatter : defaultFormatter;
  assertInsertable(value);
  const memberText = `${JSON.stringify(key)}: `;

  if (objectNode.members.length === 0) {
    const lineIndent = lineIndentAt(source, objectNode.open);
    const memberIndent = `${lineIndent}  `;
    const formatted = format(value, memberIndent);
    const inner = `\n${memberIndent}${memberText}${formatted}\n${lineIndent}`;
    return `${source.slice(0, objectNode.open + 1)}${inner}${source.slice(objectNode.close)}`;
  }

  if (!arrayIsMultiline(source, objectNode)) {
    return `${source.slice(0, objectNode.close)}, ${memberText}${formatInline(value)}${source.slice(objectNode.close)}`;
  }

  const last = objectNode.members[objectNode.members.length - 1];
  const memberIndent = lineIndentAt(source, last.keyStart);
  const formatted = format(value, memberIndent);
  return `${source.slice(0, last.value.end)},\n${memberIndent}${memberText}${formatted}${source.slice(last.value.end)}`;
}
