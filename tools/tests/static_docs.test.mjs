// @static-doc
// 作用：静态文档生成器的 Node 单元测试，守护源码注释解析与符号提取。
//
// ## 契约与约束
// - 注释块必须提取作用和 Markdown 正文，并拒绝缺少结束标记的块。
// - GDScript 的 `static func`、普通函数、`const X :=` 与显式类型常量都必须进入符号表。
// @end-static-doc

import test from "node:test";
import assert from "node:assert/strict";
import { extractStaticDoc, extractSymbols } from "../gen_static_docs.mjs";

test("extractStaticDoc reads a Markdown block from GDScript comments", () => {
  const source = `class_name Example
## @static-doc
## 作用：示例职责。
##
## ## 契约与约束
## - 保持确定性。
## @end-static-doc
extends RefCounted
`;
  assert.deepEqual(extractStaticDoc("example.gd", source), {
    role: "示例职责。",
    fragment: "## 契约与约束\n- 保持确定性。",
  });
});

test("extractStaticDoc preserves Markdown headings after JavaScript comments", () => {
  const source = `// @static-doc
// role: Generator.
//
// ## Contracts
// - Atomic output.
// @end-static-doc
`;
  assert.equal(extractStaticDoc("example.mjs", source).fragment, "## Contracts\n- Atomic output.");
});

test("extractStaticDoc rejects an unterminated block", () => {
  assert.throws(
    () => extractStaticDoc("broken.gd", "## @static-doc\n## 作用：坏示例。\n"),
    /missing @end-static-doc/
  );
});

test("extractSymbols includes static functions and both const syntaxes", () => {
  const source = `class_name Example
const INFERRED := 1
const TYPED: int = 2
static func from_dict(data: Dictionary) -> Example:
  return Example.new()
func value() -> int:
  return 1
`;
  const labels = extractSymbols("example.gd", source).map((symbol) => symbol.label);
  assert.deepEqual(labels, [
    "Example",
    "INFERRED",
    "TYPED",
    "from_dict(data: Dictionary) -> Example",
    "value() -> int",
  ]);
});
