#!/usr/bin/env node
// @static-doc
// 作用：Story Mode 数据契约冻结门禁：锁定 story_arc / story_level Schema 与
// common 里的 story DSL 定义，防止在实现加载链/运行时前被无意改动。
//
// ## 契约与约束
// - 冻结契约见 `docs/specs/STORY_MODE_DATA_CONTRACT_V2.md`；锁文件在
//   `schemas/v2/story_schema_freeze.json`。
// - 比较对象是**规范化 JSON**（递归 key 排序）的 SHA-256，格式化/缩进变化不算改动。
// - `common.schema.json` 只锁 story_presentation / story_stage / story_condition /
//   story_match 四个定义；同文件的其它系统字段不受影响。
// - 默认 `--check`：任何漂移都退出码 1，并提示先评审契约再 `--update`。
// - `--update`：重新冻结（写入新 digest）；只在明确决定升契约版本/接受变更时使用。
// - `--json`：输出机器可读摘要。
// @end-static-doc

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const lockPath = path.join(root, 'schemas/v2/story_schema_freeze.json');
const schemaDir = path.join(root, 'schemas/v2');
const frozenFiles = ['story_arc.schema.json', 'story_level.schema.json'];
const commonSchema = 'common.schema.json';
const frozenCommonDefs = [
  'story_presentation', 'story_stage', 'story_condition', 'story_match',
  'story_line', 'story_choice', 'story_page_entry', 'story_action_entry',
  'story_market_filter', 'story_module_filter', 'story_access', 'story_effect',
];

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') {
    const result = {};
    for (const key of Object.keys(value).sort()) result[key] = canonical(value[key]);
    return result;
  }
  return value;
}

function digest(value) {
  return crypto.createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function currentDigests() {
  const files = {};
  for (const name of frozenFiles) files[name] = digest(readJson(path.join(schemaDir, name)));
  const common = readJson(path.join(schemaDir, commonSchema));
  const defs = {};
  for (const key of frozenCommonDefs) {
    if (!common.$defs || !common.$defs[key]) {
      throw new Error(`${commonSchema} is missing $defs.${key}`);
    }
    defs[key] = digest(common.$defs[key]);
  }
  return { files, commonDefs: defs };
}

function loadLock() {
  if (!fs.existsSync(lockPath)) return null;
  return readJson(lockPath);
}

function compare(lock, current) {
  const drift = [];
  for (const name of frozenFiles) {
    const expected = lock.files ? lock.files[name] : undefined;
    if (!expected) drift.push(`${name}: missing from the lock file`);
    else if (expected !== current.files[name]) drift.push(`${name}: digest changed`);
  }
  for (const key of frozenCommonDefs) {
    const expected = lock.common_story_defs ? lock.common_story_defs[key] : undefined;
    if (!expected) drift.push(`${commonSchema}#/$defs/${key}: missing from the lock file`);
    else if (expected !== current.commonDefs[key]) drift.push(`${commonSchema}#/$defs/${key}: digest changed`);
  }
  return drift;
}

const args = new Set(process.argv.slice(2));
const wantJson = args.has('--json');
const update = args.has('--update');
const contractDoc = path.join(root, 'docs/specs/STORY_MODE_DATA_CONTRACT_V2.md');
const errors = [];

if (!fs.existsSync(contractDoc)) {
  errors.push(`missing contract document: ${path.relative(root, contractDoc).split(path.sep).join('/')}`);
}

let current;
try {
  current = currentDigests();
} catch (error) {
  console.error(`story-schema-freeze: ${error.message}`);
  process.exit(2);
}

if (update) {
  if (errors.length) {
    console.error('story-schema-freeze: cannot freeze while the contract document is missing');
    for (const error of errors) console.error(`  - ${error}`);
    process.exit(2);
  }
  const lock = {
    contract: 'STORY_MODE_DATA_CONTRACT_V2',
    contract_version: 2,
    frozen_at: '2026-10-27',
    schema_version: '2.0',
    source: 'node tools/check_story_schema_freeze.mjs --update',
    files: current.files,
    common_schema: commonSchema,
    common_story_defs: current.commonDefs,
  };
  fs.writeFileSync(lockPath, `${JSON.stringify(lock, null, 2)}\n`, 'utf8');
  console.log(`story-schema-freeze: locked ${frozenFiles.length} schema files + ${frozenCommonDefs.length} common story defs`);
  process.exit(0);
}

const lock = loadLock();
if (!lock) {
  console.error('story-schema-freeze: lock file missing; run node tools/check_story_schema_freeze.mjs --update');
  process.exit(1);
}
const drift = compare(lock, current);
if (drift.length) {
  errors.push(...drift);
  errors.push('Story Mode data contract v2 is frozen; review docs/specs/STORY_MODE_DATA_CONTRACT_V2.md before re-freezing');
}

const summary = {
  ok: errors.length === 0,
  contract: lock.contract,
  contract_version: lock.contract_version,
  frozen_at: lock.frozen_at,
  files: frozenFiles,
  commonDefs: frozenCommonDefs,
  drift,
  errors,
};

if (wantJson) {
  console.log(JSON.stringify(summary, null, 2));
} else if (summary.ok) {
  console.log(`story-schema-freeze: ok (${lock.contract} v${lock.contract_version}, frozen ${lock.frozen_at}; ${frozenFiles.length} files + ${frozenCommonDefs.length} common defs)`);
} else {
  console.error('story-schema-freeze: contract drift detected');
  for (const error of errors) console.error(`  - ${error}`);
}

process.exit(summary.ok ? 0 : 1);
