#!/usr/bin/env node
// @static-doc
// 作用：Phase E 发布门禁：确认 Content Schema 1.0 已冻结，内容类型、Schema 文件与
// Core/SDK 内容 envelope 全部为 2.0；发现 1.0 或非 2.0 内容时以清晰错误退出。
//
// ## 契约与约束
// - 读取 `content_types.json`：所有 active 类型与草案类型必须声明 2.0，且 schema 路径存在。
// - `FrameworkInfo.CONTENT_SCHEMA` 必须是 "2.0"（存档 header 基线）。
// - `schemas/` 顶层只允许 common/manifest，其余类型 Schema 必须位于 `schemas/v2/`。
// - 扫描 `dev_mods/core/content`、`sdk/examples/*/content`、`sdk/templates/*/content`
//   的 `.json` 内容文件：带 `content_type` 的 envelope 的 `schema_version` 必须是 2.0。
// - 退出码 0 = 全部通过；1 = 存在违规；2 = 输入读取失败。
// - 无外部依赖，可在 CI / 本地任意 Node 22+ 运行。
// @end-static-doc

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const errors = [];
const notes = [];

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    errors.push(`${rel(file)}: cannot read JSON (${error.message})`);
    return null;
  }
}

function rel(file) {
  return path.relative(root, file).split(path.sep).join('/');
}

function schemaExists(relPath) {
  return fs.existsSync(path.join(root, relPath));
}

const typesPath = path.join(root, 'content_types.json');
const catalog = readJson(typesPath);
if (!catalog) {
  console.error('content-schema-v2: content_types.json is unreadable');
  process.exit(2);
}

const active = Array.isArray(catalog.types) ? catalog.types : [];
const drafts = Array.isArray(catalog.draft_types) ? catalog.draft_types : [];
const draftSchemas = catalog.draft_schemas && typeof catalog.draft_schemas === 'object' ? catalog.draft_schemas : {};
if (String(catalog.content_schema || '') !== '2.0') {
  errors.push(`content_types.json: content_schema must be "2.0" (got "${catalog.content_schema || ''}")`);
}
if (active.length === 0) errors.push('content_types.json: no active types');
for (const type of [...active, ...drafts]) {
  const key = String(type.key || '<missing-key>');
  const isDraft = drafts.includes(type);
  if (String(type.schema_version || '') !== '2.0') {
    errors.push(`${key}: schema_version must be "2.0" (got "${type.schema_version || ''}")`);
  }
  const schema = String(type.schema || (isDraft ? draftSchemas[key] || '' : ''));
  if (!schema) errors.push(`${key}: missing schema path`);
  else if (!schemaExists(schema)) errors.push(`${key}: schema file not found: ${schema}`);
  else if (!schema.replace(/\\/g, '/').startsWith('schemas/v2/')) {
    errors.push(`${key}: active/draft Schema must live under schemas/v2/ (got ${schema})`);
  }
}

const infoPath = path.join(root, 'framework/core/framework_info.gd');
try {
  const info = fs.readFileSync(infoPath, 'utf8');
  const match = info.match(/const\s+CONTENT_SCHEMA\s*:=\s*"([^"]+)"/);
  if (!match) errors.push('framework/core/framework_info.gd: CONTENT_SCHEMA constant not found');
  else if (match[1] !== '2.0') {
    errors.push(`framework/core/framework_info.gd: CONTENT_SCHEMA must be "2.0" (got "${match[1]}")`);
  }
} catch (error) {
  errors.push(`framework/core/framework_info.gd: cannot read (${error.message})`);
}

const schemasDir = path.join(root, 'schemas');
try {
  const topLevel = fs.readdirSync(schemasDir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.schema.json'))
    .map((entry) => entry.name)
    .sort();
  const allowed = new Set(['common.schema.json', 'manifest.schema.json']);
  for (const name of topLevel) {
    if (!allowed.has(name)) errors.push(`schemas/${name}: type Schemas must live under schemas/v2/`);
  }
  notes.push(`schemas/: ${topLevel.length} top-level (common/manifest only)`);
} catch (error) {
  errors.push(`schemas/: cannot list (${error.message})`);
}

function scanContentDir(dir) {
  if (!fs.existsSync(dir)) return 0;
  let count = 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      count += scanContentDir(full);
      continue;
    }
    if (!entry.isFile() || !entry.name.endsWith('.json')) continue;
    let payload;
    try {
      payload = JSON.parse(fs.readFileSync(full, 'utf8'));
    } catch {
      continue; // localization / manifest files are validated elsewhere
    }
    if (!payload || typeof payload !== 'object' || !payload.content_type) continue;
    count += 1;
    if (String(payload.schema_version || '') !== '2.0') {
      errors.push(`${rel(full)}: content envelope must be schema_version "2.0" (got "${payload.schema_version || ''}")`);
    }
  }
  return count;
}

const contentRoots = [path.join(root, 'dev_mods/core/content')];
for (const examplesDir of ['sdk/examples', 'sdk/templates']) {
  const base = path.join(root, examplesDir);
  if (!fs.existsSync(base)) continue;
  for (const entry of fs.readdirSync(base, { withFileTypes: true })) {
    if (entry.isDirectory()) contentRoots.push(path.join(base, entry.name, 'content'));
  }
}
let scanned = 0;
for (const dir of contentRoots) scanned += scanContentDir(dir);
notes.push(`content files scanned: ${scanned}`);

const summary = {
  ok: errors.length === 0,
  activeTypes: active.length,
  draftTypes: drafts.length,
  contentFiles: scanned,
  notes,
  errors,
};
if (process.argv.includes('--json')) {
  console.log(JSON.stringify(summary, null, 2));
} else if (summary.ok) {
  console.log(`content-schema-v2: ok (${active.length} active + ${drafts.length} draft types, ${scanned} content files, 2.0 only)`);
  for (const note of notes) console.log(`  - ${note}`);
} else {
  console.error(`content-schema-v2: ${errors.length} violation(s)`);
  for (const error of errors) console.error(`  - ${error}`);
  for (const note of notes) console.error(`  note: ${note}`);
}
process.exit(summary.ok ? 0 : 1);