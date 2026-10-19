#!/usr/bin/env node
/*
 * Integration tests for the SNModMaker Content CLI (SNModMaker/tools/content.mjs).
 *
 * Contract: C:\Users\Zhoei\AppData\Local\Temp\content-cli-spec.md (frozen v1 spec).
 * Style: zero dependency, node:test + node:assert/strict, every CLI call is a real
 * child_process.spawnSync against `node SNModMaker/tools/content.mjs ...`.
 *
 * Run from the repository root:
 *
 *   node --test SNModMaker/tests/content-cli.test.mjs
 *
 * All write operations happen inside fs.mkdtempSync(os.tmpdir()) fixtures. The
 * repository's dev_mods/core is only ever read (a few tests hash its JSON files
 * before and after to prove that).
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..');
const cliPath = path.join(repoRoot, 'SNModMaker', 'tools', 'content.mjs');
const contentJsonPath = path.join(repoRoot, 'SNModMaker', 'tools', 'content_json.mjs');
const coreDir = path.join(repoRoot, 'dev_mods', 'core');
const cliCwd = repoRoot;

const MOD_ID = 'test_mod';
const GOODS_FILE = 'content/goods.json';

/* ------------------------------------------------------------------------- */
/* CLI invocation helpers                                                     */
/* ------------------------------------------------------------------------- */

function runCli(args) {
  assert.ok(
    fs.existsSync(cliPath),
    `CLI entry point is missing: ${cliPath}\n(the content CLI is implemented by another agent; this test suite is written against the frozen spec)`
  );
  const result = spawnSync(process.execPath, [cliPath, ...args], {
    cwd: cliCwd,
    encoding: 'utf8',
    maxBuffer: 32 * 1024 * 1024,
    timeout: 120000,
    env: { ...process.env, NO_COLOR: '1', FORCE_COLOR: '0' },
  });
  if (result.error) {
    assert.fail(`failed to spawn CLI (${args.join(' ')}): ${result.error.message}`);
  }
  return result;
}

function jsonRun(args) {
  return runCli([...args, '--json']);
}

/** Parse stdout as exactly one JSON object (no human text, no second object). */
function mustJson(result, label = 'CLI') {
  const stdout = String(result.stdout || '');
  const stderr = String(result.stderr || '');
  assert.ok(stdout.trim().length > 0, `${label}: empty stdout (exit ${result.status}); stderr=${stderr}`);
  assert.equal(
    stdout.trimStart().charAt(0),
    '{',
    `${label}: --json stdout must start with a JSON object, got: ${JSON.stringify(stdout.slice(0, 200))}`
  );
  try {
    return JSON.parse(stdout);
  } catch (error) {
    assert.fail(`${label}: --json stdout is not a single valid JSON object: ${error.message}\nstdout=${stdout}\nstderr=${stderr}`);
  }
}

function assertStatus(result, expected, label) {
  assert.equal(
    result.status,
    expected,
    `${label}: exit code ${result.status} (expected ${expected})\nstdout=${result.stdout}\nstderr=${result.stderr}`
  );
}

/** Non-zero exit + valid single JSON object + ok:false + error{code,message}. */
function mustFailJson(result, label) {
  const json = mustJson(result, label);
  assert.notEqual(result.status, 0, `${label}: expected a non-zero exit code\nstdout=${result.stdout}\nstderr=${result.stderr}`);
  assert.equal(json.ok, false, `${label}: failure JSON must have ok:false -> ${JSON.stringify(json)}`);
  assert.ok(json.error && typeof json.error === 'object', `${label}: failure JSON must contain error object -> ${JSON.stringify(json)}`);
  assert.equal(typeof json.error.code, 'string', `${label}: error.code must be a string -> ${JSON.stringify(json.error)}`);
  assert.ok(json.error.code.length > 0, `${label}: error.code must not be empty`);
  assert.equal(typeof json.error.message, 'string', `${label}: error.message must be a string -> ${JSON.stringify(json.error)}`);
  return json;
}

/** A usage error: exit code 2, JSON still valid and ok:false. */
function assertUsageError(result, label) {
  const json = mustFailJson(result, label);
  assertStatus(result, 2, label);
  return json;
}

/* ------------------------------------------------------------------------- */
/* Fixture helpers                                                            */
/* ------------------------------------------------------------------------- */

function tempRoot(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sn-content-cli-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

/**
 * Create a throwaway mod with the CLI's own `new` command. Returns the mod root.
 * Default fixture: template "goods" -> one definition (test_mod:good/tea) plus
 * localization/zh_CN.json + localization/en.json, 0 validation errors.
 */
function createMod(t, { id = MOD_ID, name = '测试模组', template = 'goods', extra = [] } = {}) {
  const root = tempRoot(t);
  const mod = path.join(root, 'mod');
  const result = jsonRun(['new', '--mod', mod, '--id', id, '--name', name, '--template', template, ...extra]);
  const json = mustJson(result, `new ${template}`);
  assertStatus(result, 0, `new ${template}`);
  assert.equal(json.ok, true, `new ${template}: ok must be true -> ${JSON.stringify(json)}`);
  return mod;
}

function readText(file) {
  return fs.readFileSync(file, 'utf8');
}

function readJson(file) {
  try {
    return JSON.parse(readText(file));
  } catch (error) {
    assert.fail(`invalid JSON at ${file}: ${error.message}`);
  }
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function manifestOf(mod) {
  return readJson(path.join(mod, 'manifest.json'));
}

function contentFilesOf(mod) {
  const manifest = manifestOf(mod);
  return (manifest.content || []).map((rel) => {
    const abs = path.join(mod, rel);
    return { rel, abs, payload: readJson(abs) };
  });
}

function contentFileOfType(mod, typeKey) {
  const files = contentFilesOf(mod).filter((file) => file.payload.content_type === typeKey);
  assert.equal(files.length, 1, `expected exactly one ${typeKey} content file in ${mod}, found ${files.length}`);
  return files[0];
}

function goodsFileOf(mod) {
  return contentFileOfType(mod, 'goods');
}

function definitionsOf(mod) {
  const rows = [];
  for (const file of contentFilesOf(mod)) {
    (file.payload.definitions || []).forEach((definition, index) => {
      rows.push({ file: file.rel, index, definition });
    });
  }
  return rows;
}

function definitionById(mod, id) {
  const found = definitionsOf(mod).find((row) => row.definition && row.definition.id === id);
  assert.ok(found, `definition ${id} not found; present: ${definitionsOf(mod).map((row) => row.definition && row.definition.id).join(', ')}`);
  return found;
}

function localeOf(mod, locale) {
  const manifest = manifestOf(mod);
  const rel = (manifest.localization || []).find((entry) => path.basename(entry, '.json') === locale);
  assert.ok(rel, `locale ${locale} is not declared in manifest.localization: ${JSON.stringify(manifest.localization)}`);
  return readJson(path.join(mod, rel));
}

function addGood(mod, id, extra = []) {
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', id,
    '--name-zh', `${id} 中文名`, '--name-en', `${id} English Name`,
    '--desc-zh', `${id} 的中文描述`, '--desc-en', `${id} English description`,
    '--tag', 'good.trade', ...extra,
  ]);
  const json = mustJson(result, `add ${id}`);
  assertStatus(result, 0, `add ${id}`);
  assert.equal(json.ok, true, `add ${id}: ok must be true -> ${JSON.stringify(json)}`);
  return json;
}

/* ------------------------------------------------------------------------- */
/* Filesystem snapshot / text helpers                                        */
/* ------------------------------------------------------------------------- */

function sha256File(file) {
  return createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

/**
 * Recursively snapshot a directory: relative path -> sha256. When onlyJson is
 * true only *.json files are considered (used for read-only checks of core).
 */
function snapshotDir(dir, { onlyJson = false } = {}) {
  const snapshot = {};
  const walk = (current) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (!onlyJson || entry.name.endsWith('.json')) {
        snapshot[path.relative(dir, full).split(path.sep).join('/')] = sha256File(full);
      }
    }
  };
  walk(dir);
  return snapshot;
}

function assertDirUnchanged(before, dir, label, options) {
  assert.deepEqual(snapshotDir(dir, options), before, `${label}: directory content must be unchanged (files written when they should not be)`);
}

/**
 * Assert every non-empty `before` line still occurs, in the same order, in `after`.
 * Appending a key to a flat JSON object necessarily appends a comma to the old
 * last line, so trailing commas are ignored when comparing.
 */
function assertLinesPreservedInOrder(beforeText, afterText, label) {
  const normalize = (line) => line.replace(/,\s*$/, '');
  const before = beforeText.split('\n');
  const after = afterText.split('\n');
  let cursor = 0;
  for (const line of before) {
    if (line === '') continue;
    let found = -1;
    for (let i = cursor; i < after.length; i += 1) {
      if (normalize(after[i]) === normalize(line)) {
        found = i;
        break;
      }
    }
    assert.ok(found >= 0, `${label}: original line was removed or reordered: ${JSON.stringify(line)}`);
    cursor = found + 1;
  }
}

/**
 * Extract the exact source slices of the items of the top-level `definitions`
 * array, so "minimal diff" can be checked without assuming an indentation style.
 */
function extractDefinitionSlices(text) {
  const keyIndex = text.indexOf('"definitions"');
  if (keyIndex < 0) return [];
  const bracket = text.indexOf('[', text.indexOf(':', keyIndex));
  if (bracket < 0) return [];
  const slices = [];
  let depth = 0;
  let start = -1;
  let inString = false;
  let escaped = false;
  for (let i = bracket + 1; i < text.length; i += 1) {
    const ch = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === '\\') escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === '{' || ch === '[') {
      depth += 1;
      if (depth === 1) start = i;
      continue;
    }
    if (ch === '}' || ch === ']') {
      depth -= 1;
      if (depth === 0 && start >= 0) {
        slices.push(text.slice(start, i + 1));
        start = -1;
      }
      if (depth < 0) break;
    }
  }
  return slices;
}

/** Return the 0-based indexes of lines that differ between two texts. */
function changedLineIndexes(beforeText, afterText) {
  const before = beforeText.split('\n');
  const after = afterText.split('\n');
  assert.equal(
    after.length,
    before.length,
    `expected the same line count, before=${before.length} after=${after.length}`
  );
  const indexes = [];
  for (let i = 0; i < before.length; i += 1) {
    if (before[i] !== after[i]) indexes.push(i);
  }
  return indexes;
}

/** `list` rows may be flat or grouped by type; collect every row-bearing array. */
function isDefinitionRow(value) {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value) && typeof value.id === 'string';
}

function collectRowArrays(value, out = []) {
  if (Array.isArray(value)) {
    if (value.length > 0 && value.every(isDefinitionRow)) out.push(value);
    else value.forEach((item) => collectRowArrays(item, out));
    return out;
  }
  if (value && typeof value === 'object') {
    Object.values(value).forEach((item) => collectRowArrays(item, out));
  }
  return out;
}

function listRows(json, label) {
  const arrays = collectRowArrays(json);
  assert.ok(arrays.length > 0, `${label}: no definition rows found in list JSON -> ${JSON.stringify(json).slice(0, 500)}`);
  const seen = new Set();
  const rows = [];
  for (const array of arrays) {
    for (const row of array) {
      if (seen.has(row.id)) continue;
      seen.add(row.id);
      rows.push(row);
    }
  }
  return rows;
}

function expectedCoreDefinitionCount() {
  const manifest = readJson(path.join(coreDir, 'manifest.json'));
  let total = 0;
  for (const rel of manifest.content || []) {
    total += readJson(path.join(coreDir, rel)).definitions.length;
  }
  return total;
}

/* ------------------------------------------------------------------------- */
/* 1. types / describe / list                                                */
/* ------------------------------------------------------------------------- */

test('CLI entry points exist (content.mjs and content_json.mjs)', (t) => {
  assert.ok(fs.existsSync(cliPath), `missing CLI entry: ${cliPath}`);
  assert.ok(fs.existsSync(contentJsonPath), `missing source-preserving JSON module: ${contentJsonPath}`);
});

test('types --json lists every content type with presentation metadata', (t) => {
  const result = jsonRun(['types']);
  assertStatus(result, 0, 'types');
  const json = mustJson(result, 'types');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'types');
  assert.ok(Array.isArray(json.types), 'types must be an array');
  assert.equal(json.types.length, 16, 'content_types.json currently declares 16 runtime types');
  const keys = json.types.map((entry) => entry.key);
  for (const key of ['goods', 'materials', 'hulls', 'boilers', 'events', 'contracts', 'patches']) {
    assert.ok(keys.includes(key), `types must include ${key}`);
  }
  const goods = json.types.find((entry) => entry.key === 'goods');
  assert.equal(goods.singular, 'good');
  assert.equal(goods.keyPrefix, 'good');
  assert.equal(goods.label, '商品');
  assert.equal(goods.en, 'Goods');
  assert.equal(goods.file, 'content/goods.json');
  assert.equal(goods.schema, 'good.schema.json');
  assert.ok(goods.group, 'goods.group must be present');
  assert.ok(goods.summary, 'goods.summary must be present');
  const patches = json.types.find((entry) => entry.key === 'patches');
  assert.equal(patches.file, 'content/patches.json');
  assert.equal(patches.schema, 'patch.schema.json');
});

test('describe goods --json reports id pattern, keys, fields, defaults and skeleton', (t) => {
  const result = jsonRun(['describe', 'goods']);
  assertStatus(result, 0, 'describe goods');
  const json = mustJson(result, 'describe goods');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'describe');

  assert.equal(json.type.key, 'goods');
  assert.equal(json.type.singular, 'good');
  assert.equal(json.type.keyPrefix, 'good');
  assert.equal(json.type.label, '商品');
  assert.equal(json.type.file, 'content/goods.json');
  assert.equal(json.type.schema, 'good.schema.json');

  assert.equal(json.id.pattern, '^[a-z][a-z0-9_]{2,31}:[a-z_]+/[a-z0-9_]+$');
  assert.equal(json.id.singular, 'good');
  assert.equal(json.id.example, 'my_mod:good/tea');

  assert.equal(json.keys.base, 'good.my_mod.tea');
  assert.equal(json.keys.name, 'good.my_mod.tea.name');
  assert.equal(json.keys.description, 'good.my_mod.tea.description');

  assert.ok(Array.isArray(json.fields), 'fields must be an array');
  const basePrice = json.fields.find((field) => field.path === 'data.base_price');
  assert.ok(basePrice, `fields must contain data.base_price: ${JSON.stringify(json.fields)}`);
  assert.equal(basePrice.type, 'number');
  assert.equal(basePrice.required, true);
  assert.equal(basePrice.minimum, 1);
  const category = json.fields.find((field) => field.path === 'data.category');
  assert.ok(category, 'fields must contain data.category');
  assert.equal(category.type, 'string');
  const elasticity = json.fields.find((field) => field.path === 'data.price_elasticity');
  assert.ok(elasticity, 'fields must contain data.price_elasticity');
  assert.equal(elasticity.type, 'number');
  assert.equal(elasticity.minimum, 0);
  assert.equal(elasticity.maximum, 1);

  assert.equal(json.defaults.unit_weight, 1);
  assert.equal(json.defaults.base_price, 50);
  assert.equal(json.defaults.base_stock, 80);
  assert.equal(json.defaults.price_elasticity, 0.15);
  assert.equal(json.defaults.spawn_weight, 1);
  assert.equal(json.defaults.category, 'trade');

  assert.ok(Array.isArray(json.suggestions.tags));
  assert.ok(json.suggestions.tags.includes('good.trade'));

  assert.equal(json.skeleton.id, 'my_mod:good/tea');
  assert.equal(json.skeleton.name_key, 'good.my_mod.tea.name');
  assert.equal(json.skeleton.description_key, 'good.my_mod.tea.description');
  assert.deepEqual(json.skeleton.tags, ['good.trade']);
  assert.equal(json.skeleton.enabled, true);
  assert.equal(json.skeleton.data.base_price, 50);
});

test('describe patches --json reports the patch target/operations skeleton and null defaults', (t) => {
  const result = jsonRun(['describe', 'patches']);
  assertStatus(result, 0, 'describe patches');
  const json = mustJson(result, 'describe patches');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'describe');
  assert.equal(json.type.key, 'patches');
  assert.equal(json.type.singular, 'patch');
  assert.equal(json.type.file, 'content/patches.json');
  assert.equal(json.defaults, null, 'patches have no defaults');
  assert.equal(json.skeleton.target, 'core:boiler/small_efficient');
  assert.equal(json.skeleton.requires.mod, 'core');
  assert.equal(json.skeleton.requires.version, '>=1.0.0 <2.0.0');
  assert.ok(Array.isArray(json.skeleton.operations));
  assert.deepEqual(json.skeleton.operations[0], { op: 'replace', path: '/data/purchase_price', value: 380 });
});

test('list --mod dev_mods/core --json lists every core definition and leaves core untouched', (t) => {
  const before = snapshotDir(coreDir, { onlyJson: true });
  const result = jsonRun(['list', '--mod', 'dev_mods/core']);
  assertStatus(result, 0, 'list core');
  const json = mustJson(result, 'list core');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'list');

  const rows = listRows(json, 'list core');
  assert.equal(rows.length, expectedCoreDefinitionCount(), `list must return one row per core definition`);

  const ironOre = rows.find((row) => row.id === 'core:good/iron_ore');
  assert.ok(ironOre, 'list must contain core:good/iron_ore');
  assert.equal(ironOre.type, 'goods');
  assert.equal(ironOre.file, 'content/goods.json');
  assert.equal(ironOre.index, 0);
  assert.equal(ironOre.name_zh, '铁矿石');
  assert.equal(ironOre.name_en, 'Iron Ore');
  assert.equal(ironOre.enabled, true);
  assert.equal(ironOre.keys.name, 'good.core.iron_ore.name');
  assert.equal(ironOre.keys.description, 'good.core.iron_ore.description');

  assert.deepEqual(snapshotDir(coreDir, { onlyJson: true }), before, 'list must not modify dev_mods/core');
});

test('list --type goods filters core rows down to goods definitions', (t) => {
  const result = jsonRun(['list', '--mod', 'dev_mods/core', '--type', 'goods']);
  assertStatus(result, 0, 'list core goods');
  const json = mustJson(result, 'list core goods');
  assert.equal(json.ok, true);
  const rows = listRows(json, 'list core goods');
  assert.equal(rows.length, 9, 'core currently has 9 goods definitions');
  for (const row of rows) {
    assert.equal(row.type, 'goods');
    assert.equal(row.file, 'content/goods.json');
  }
  assert.ok(rows.some((row) => row.id === 'core:good/coal'));
  assert.ok(!rows.some((row) => row.id === 'core:material/boiler_plate'));
});

/* ------------------------------------------------------------------------- */
/* 2. new                                                                    */
/* ------------------------------------------------------------------------- */

test('new --json creates a valid mod (manifest, content, both locales) that validates cleanly', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'brand_new_mod');
  const result = jsonRun(['new', '--mod', mod, '--id', 'my_mod', '--name', '我的模组', '--template', 'goods', '--description', '测试用模组']);
  const json = mustJson(result, 'new');
  assertStatus(result, 0, 'new');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'new');
  assert.ok(Array.isArray(json.changes), 'new must report created files in changes[]');
  assert.ok(json.changes.length >= 3, `new must report manifest + content + locales, got ${JSON.stringify(json.changes)}`);
  for (const change of json.changes) {
    assert.equal(change.action, 'create', `new change must be create: ${JSON.stringify(change)}`);
    assert.equal(typeof change.path, 'string');
  }
  assert.ok(fs.existsSync(path.join(mod, 'manifest.json')), 'manifest.json must exist');
  assert.ok(fs.existsSync(path.join(mod, GOODS_FILE)), 'content/goods.json must exist');
  assert.ok(fs.existsSync(path.join(mod, 'localization', 'zh_CN.json')), 'zh_CN.json must exist');
  assert.ok(fs.existsSync(path.join(mod, 'localization', 'en.json')), 'en.json must exist');

  const manifest = manifestOf(mod);
  assert.equal(manifest.id, 'my_mod');
  assert.equal(manifest.name, '我的模组');
  assert.equal(manifest.version, '1.0.0');
  assert.equal(manifest.type, 'content');
  assert.equal(manifest.description, '测试用模组');
  assert.deepEqual(manifest.content, [GOODS_FILE]);
  assert.deepEqual(manifest.localization, ['localization/zh_CN.json', 'localization/en.json']);
  assert.ok(
    Array.isArray(manifest.dependencies) && manifest.dependencies.some((dependency) => dependency.id === 'core'),
    `new mod must depend on core: ${JSON.stringify(manifest.dependencies)}`
  );

  const goods = goodsFileOf(mod);
  assert.equal(goods.payload.schema_version, '1.0');
  assert.equal(goods.payload.content_type, 'goods');
  assert.equal(goods.payload.definitions.length, 1);
  const tea = goods.payload.definitions[0];
  assert.equal(tea.id, 'my_mod:good/tea');
  assert.equal(tea.name_key, 'good.my_mod.tea.name');
  assert.equal(tea.description_key, 'good.my_mod.tea.description');

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['good.my_mod.tea.name'], '茶叶');
  assert.equal(en['good.my_mod.tea.name'], 'Tea');
  assert.equal(typeof json.stats.definitions, 'number');
  assert.equal(json.stats.definitions, 1);

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate after new');
  const validateJson = mustJson(validateResult, 'validate after new');
  assert.equal(validateJson.ok, true);
  assert.equal(validateJson.issues.errors, 0, `new mod must validate with 0 errors: ${JSON.stringify(validateJson.issues.list)}`);
});

test('new refuses a non-empty target directory without --force and writes nothing', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'occupied');
  fs.mkdirSync(mod);
  const marker = path.join(mod, 'keep.txt');
  fs.writeFileSync(marker, 'keep me\n', 'utf8');
  const before = snapshotDir(mod);

  const result = jsonRun(['new', '--mod', mod, '--id', 'my_mod', '--name', '我的模组', '--template', 'goods']);
  mustFailJson(result, 'new non-empty');
  assertStatus(result, 1, 'new non-empty');
  assert.deepEqual(snapshotDir(mod), before, 'failed new must not touch the target directory');
  assert.ok(!fs.existsSync(path.join(mod, 'manifest.json')), 'failed new must not create manifest.json');
});

/* ------------------------------------------------------------------------- */
/* 3. add                                                                    */
/* ------------------------------------------------------------------------- */

test('add without --id is a usage error (exit 2) that still emits JSON', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['add', '--mod', mod, '--type', 'goods', '--name-zh', '甲', '--name-en', 'A']);
  assertUsageError(result, 'add missing id');
  assertDirUnchanged(before, mod, 'add missing id');
});

test('add with an unknown --type is a usage error (exit 2)', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['add', '--mod', mod, '--type', 'not_a_type', '--id', 'tea2', '--name-zh', '甲', '--name-en', 'A']);
  assertUsageError(result, 'add unknown type');
  assertDirUnchanged(before, mod, 'add unknown type');
});

test('add requires --name-zh and --name-en together', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['add', '--mod', mod, '--type', 'goods', '--id', 'only_zh', '--name-zh', '只有中文']);
  assertUsageError(result, 'add missing name-en');
  assertDirUnchanged(before, mod, 'add missing name-en');
});

test('add requires --desc-zh and --desc-en together', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'only_desc_zh',
    '--name-zh', '双语名', '--name-en', 'Bilingual', '--desc-zh', '只有中文描述',
  ]);
  assertUsageError(result, 'add missing desc-en');
  assertDirUnchanged(before, mod, 'add missing desc-en');
});

test('add writes the definition with tags/data and both bilingual localization files', (t) => {
  const mod = createMod(t);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'black_tea',
    '--name-zh', '红茶', '--name-en', 'Black Tea',
    '--desc-zh', '醇厚的红茶。', '--desc-en', 'A malty black tea.',
    '--tag', 'good.trade', '--data', 'data.base_price=80', '--data', 'data.unit_weight=1.5',
  ]);
  const json = mustJson(result, 'add black_tea');
  assertStatus(result, 0, 'add black_tea');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'add');
  assert.equal(json.stats.definitions, 2, 'stats.definitions must grow from 1 to 2');
  assert.equal(json.issues.newErrors, 0, `add must not introduce errors: ${JSON.stringify(json.issues.list)}`);

  assert.ok(Array.isArray(json.changes));
  const changedPaths = json.changes.map((change) => change.path);
  assert.ok(changedPaths.includes(GOODS_FILE), `changes must mention ${GOODS_FILE}: ${JSON.stringify(changedPaths)}`);
  assert.ok(changedPaths.includes('localization/zh_CN.json'), `changes must mention zh_CN.json: ${JSON.stringify(changedPaths)}`);
  assert.ok(changedPaths.includes('localization/en.json'), `changes must mention en.json: ${JSON.stringify(changedPaths)}`);
  for (const change of json.changes) {
    assert.ok(['create', 'update', 'delete'].includes(change.action), `unexpected change action ${change.action}`);
  }

  const found = definitionById(mod, 'test_mod:good/black_tea');
  assert.equal(found.file, GOODS_FILE);
  const definition = found.definition;
  assert.equal(definition.name_key, 'good.test_mod.black_tea.name');
  assert.equal(definition.description_key, 'good.test_mod.black_tea.description');
  assert.deepEqual(definition.tags, ['good.trade']);
  assert.equal(definition.enabled, true);
  assert.equal(definition.data.base_price, 80);
  assert.equal(definition.data.unit_weight, 1.5);
  assert.equal(definition.data.base_stock, 80, 'unspecified data fields keep catalog defaults');
  assert.equal(definition.data.category, 'trade');

  const goods = goodsFileOf(mod);
  assert.equal(goods.payload.definitions.length, 2);
  assert.equal(goods.payload.definitions[1].id, 'test_mod:good/black_tea', 'new definition is appended at the end');

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['good.test_mod.black_tea.name'], '红茶');
  assert.equal(zh['good.test_mod.black_tea.description'], '醇厚的红茶。');
  assert.equal(en['good.test_mod.black_tea.name'], 'Black Tea');
  assert.equal(en['good.test_mod.black_tea.description'], 'A malty black tea.');
  // The pre-existing template definition keeps its translations.
  assert.equal(zh['good.test_mod.tea.name'], '茶叶');
  assert.equal(en['good.test_mod.tea.name'], 'Tea');
});

test('add rejects a duplicate local id with conflict (exit 1) and leaves files untouched', (t) => {
  const mod = createMod(t);
  addGood(mod, 'dup_good');
  const before = snapshotDir(mod);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'dup_good',
    '--name-zh', '重复', '--name-en', 'Duplicate',
  ]);
  const json = mustJson(result, 'add duplicate id');
  assertStatus(result, 1, 'add duplicate id');
  assert.equal(json.ok, false);
  assert.equal(json.error.code, 'conflict', `duplicate id must report code:conflict -> ${JSON.stringify(json.error)}`);
  assert.deepEqual(snapshotDir(mod), before, 'conflicting add must not write anything');
});

test('add --suffix picks the next free local id instead of failing', (t) => {
  const mod = createMod(t);
  // "tea" already exists as the template definition test_mod:good/tea.
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'tea', '--suffix',
    '--name-zh', '第二份茶叶', '--name-en', 'Second Tea',
  ]);
  const json = mustJson(result, 'add --suffix');
  assertStatus(result, 0, 'add --suffix');
  assert.equal(json.ok, true);
  assert.equal(json.stats.definitions, 2);
  const ids = goodsFileOf(mod).payload.definitions.map((definition) => definition.id);
  assert.deepEqual(ids, ['test_mod:good/tea', 'test_mod:good/tea_2']);
  const zh = localeOf(mod, 'zh_CN');
  assert.equal(zh['good.test_mod.tea_2.name'], '第二份茶叶');
});

test('add --data-json is deep-merged and --data wins on conflicting paths', (t) => {
  const mod = createMod(t);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'merged_good',
    '--name-zh', '合并', '--name-en', 'Merged',
    '--data-json', '{"base_price":200,"base_stock":7,"category":"ore"}',
    '--data', 'data.base_price=300',
    '--data', 'data.spawn_weight=0.5',
    '--data', 'data.crafting_material=true',
  ]);
  const json = mustJson(result, 'add data merge');
  assertStatus(result, 0, 'add data merge');
  assert.equal(json.ok, true);
  const definition = definitionById(mod, 'test_mod:good/merged_good').definition;
  assert.equal(definition.data.base_price, 300, '--data must override --data-json');
  assert.equal(definition.data.base_stock, 7, '--data-json value is kept when --data does not touch it');
  assert.equal(definition.data.category, 'ore');
  assert.equal(definition.data.spawn_weight, 0.5);
  assert.equal(definition.data.crafting_material, true, 'true must be parsed as a boolean, not a string');
  assert.equal(definition.data.unit_weight, 1, 'untouched defaults survive the merge');
});

test('add --data-json accepts @file and parses typed values', (t) => {
  const mod = createMod(t);
  const root = path.dirname(mod);
  const dataFile = path.join(root, 'data.json');
  fs.writeFileSync(dataFile, JSON.stringify({ base_price: 210, base_stock: 9, category: 'craft' }), 'utf8');
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'from_file',
    '--name-zh', '来自文件', '--name-en', 'From File',
    '--data-json', `@${dataFile}`,
  ]);
  const json = mustJson(result, 'add @file');
  assertStatus(result, 0, 'add @file');
  assert.equal(json.ok, true);
  const definition = definitionById(mod, 'test_mod:good/from_file').definition;
  assert.equal(definition.data.base_price, 210);
  assert.equal(definition.data.base_stock, 9);
  assert.equal(definition.data.category, 'craft');
});

test('add --dry-run reports would-* changes and writes no file', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'dry_good',
    '--name-zh', '试运行', '--name-en', 'Dry Run', '--dry-run',
  ]);
  const json = mustJson(result, 'add --dry-run');
  assertStatus(result, 0, 'add --dry-run');
  assert.equal(json.ok, true);
  assert.ok(Array.isArray(json.changes) && json.changes.length > 0, 'dry-run must report planned changes');
  for (const change of json.changes) {
    assert.ok(
      change.action === 'would-create' || change.action === 'would-update',
      `dry-run change action must be would-* -> ${JSON.stringify(change)}`
    );
  }
  const goodsChange = json.changes.find((change) => change.path === GOODS_FILE);
  assert.ok(goodsChange, `dry-run must list ${GOODS_FILE}`);
  assert.equal(goodsChange.action, 'would-update');
  assert.equal(typeof goodsChange.diff, 'string', 'dry-run change must include a unified diff string');
  assert.match(goodsChange.diff, /^\+/m, 'dry-run diff must contain added lines');
  assert.ok(goodsChange.diff.includes('dry_good'), `dry-run diff must contain the new definition: ${goodsChange.diff}`);
  assert.deepEqual(snapshotDir(mod), before, '--dry-run must not write any file');
});

test('add keeps a minimal diff: old definitions and localization lines are untouched', (t) => {
  const mod = createMod(t);
  const goodsBefore = readText(goodsFileOf(mod).abs);
  const zhBefore = readText(path.join(mod, 'localization', 'zh_CN.json'));
  const enBefore = readText(path.join(mod, 'localization', 'en.json'));
  const oldSlices = extractDefinitionSlices(goodsBefore);
  assert.equal(oldSlices.length, 1);

  addGood(mod, 'minimal_diff');

  const goodsAfter = readText(goodsFileOf(mod).abs);
  const newSlices = extractDefinitionSlices(goodsAfter);
  assert.equal(newSlices.length, 2, 'exactly one definition was added');
  assert.deepEqual(
    JSON.parse(goodsAfter).definitions[0],
    JSON.parse(goodsBefore).definitions[0],
    'the pre-existing definition must be unchanged'
  );
  for (const slice of oldSlices) {
    assert.ok(goodsAfter.includes(slice), `old definition source slice must survive byte-for-byte:\n${slice}`);
  }
  assert.ok(goodsAfter.split('\n').length > goodsBefore.split('\n').length, 'the content file must grow');

  const zhAfter = readText(path.join(mod, 'localization', 'zh_CN.json'));
  const enAfter = readText(path.join(mod, 'localization', 'en.json'));
  assertLinesPreservedInOrder(zhBefore, zhAfter, 'zh_CN.json minimal diff');
  assertLinesPreservedInOrder(enBefore, enAfter, 'en.json minimal diff');
  assert.ok(zhAfter.includes('"good.test_mod.minimal_diff.name": "minimal_diff 中文名"'), 'zh key added verbatim');
  assert.ok(enAfter.includes('"good.test_mod.minimal_diff.name": "minimal_diff English Name"'), 'en key added verbatim');
});

test('add blocks new validation errors (exit 1) and writes nothing', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  // good.schema.json requires data.unit_weight >= 1.
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'bad_weight',
    '--name-zh', '非法重量', '--name-en', 'Bad Weight',
    '--data', 'data.unit_weight=0',
  ]);
  const json = mustJson(result, 'add validation gate');
  assertStatus(result, 1, 'add validation gate');
  assert.equal(json.ok, false);
  assert.equal(json.error.code, 'validation', `validation gate must report code:validation -> ${JSON.stringify(json.error)}`);
  assert.deepEqual(snapshotDir(mod), before, 'a blocked add must not write anything');
});

/* ------------------------------------------------------------------------- */
/* 4. set                                                                    */
/* ------------------------------------------------------------------------- */

test('set on a scalar rewrites only the target line', (t) => {
  const mod = createMod(t);
  const goods = goodsFileOf(mod);
  const before = readText(goods.abs);
  const localeBefore = snapshotDir(path.join(mod, 'localization'));

  const result = jsonRun(['set', '--mod', mod, 'test_mod:good/tea', 'data.base_price=123']);
  const json = mustJson(result, 'set scalar');
  assertStatus(result, 0, 'set scalar');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'set');
  assert.equal(json.issues.newErrors, 0);

  const after = readText(goods.abs);
  const changed = changedLineIndexes(before, after);
  assert.equal(changed.length, 1, `set must change exactly one line, changed indexes: ${changed.join(', ')}`);
  assert.match(after.split('\n')[changed[0]], /"base_price":\s*123/);
  assert.equal(JSON.parse(after).definitions[0].data.base_price, 123);
  assert.deepEqual(snapshotDir(path.join(mod, 'localization')), localeBefore, 'set must only write the content file');
  const changedPaths = (json.changes || []).map((change) => change.path);
  assert.deepEqual(changedPaths, [GOODS_FILE], `set changes must only mention ${GOODS_FILE}: ${JSON.stringify(changedPaths)}`);
});

test('set arrays support += append and -= remove-first', (t) => {
  const mod = createMod(t);
  const goods = goodsFileOf(mod);
  const original = readText(goods.abs);

  const addResult = jsonRun(['set', '--mod', mod, 'test_mod:good/tea', 'tags+=good.bulk']);
  assertStatus(addResult, 0, 'set tags+=');
  assert.equal(mustJson(addResult, 'set tags+=').ok, true);
  const afterAdd = readText(goods.abs);
  assert.deepEqual(JSON.parse(afterAdd).definitions[0].tags, ['good.trade', 'good.consumer', 'good.bulk']);
  assert.equal(changedLineIndexes(original, afterAdd).length, 1, 'tags+= must touch only the tags line');

  const removeResult = jsonRun(['set', '--mod', mod, 'test_mod:good/tea', 'tags-=good.trade']);
  assertStatus(removeResult, 0, 'set tags-=');
  assert.equal(mustJson(removeResult, 'set tags-=').ok, true);
  const afterRemove = readText(goods.abs);
  assert.deepEqual(JSON.parse(afterRemove).definitions[0].tags, ['good.consumer', 'good.bulk']);
  assert.equal(changedLineIndexes(afterAdd, afterRemove).length, 1, 'tags-= must touch only the tags line');
});

test('set refuses _key fields with a usage error (exit 2)', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['set', '--mod', mod, 'test_mod:good/tea', 'name_key=good.test_mod.tea.name']);
  assertUsageError(result, 'set _key');
  assert.deepEqual(snapshotDir(mod), before, 'rejected set must not write anything');
});

test('set reports an error for an unknown path and writes nothing', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['set', '--mod', mod, 'test_mod:good/tea', 'data.definitely_missing=1']);
  const json = mustFailJson(result, 'set unknown path');
  assert.ok(json.error.code, 'unknown path must report an error code');
  assert.deepEqual(snapshotDir(mod), before, 'failed set must not write anything');
});

/* ------------------------------------------------------------------------- */
/* 5. loc                                                                    */
/* ------------------------------------------------------------------------- */

test('loc --field name updates zh_CN and en for the definition name key', (t) => {
  const mod = createMod(t);
  const zhBefore = readJson(path.join(mod, 'localization', 'zh_CN.json'));
  const enBefore = readJson(path.join(mod, 'localization', 'en.json'));
  const result = jsonRun(['loc', '--mod', mod, 'test_mod:good/tea', '--field', 'name', '--zh', '特级茶叶', '--en', 'Premium Tea']);
  const json = mustJson(result, 'loc name');
  assertStatus(result, 0, 'loc name');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'loc');

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['good.test_mod.tea.name'], '特级茶叶');
  assert.equal(en['good.test_mod.tea.name'], 'Premium Tea');
  // Description keys are untouched by --field name.
  assert.equal(zh['good.test_mod.tea.description'], zhBefore['good.test_mod.tea.description']);
  assert.equal(en['good.test_mod.tea.description'], enBefore['good.test_mod.tea.description']);
});

test('loc only writes the language that was given', (t) => {
  const mod = createMod(t);
  const enBefore = readJson(path.join(mod, 'localization', 'en.json'));
  const result = jsonRun(['loc', '--mod', mod, 'test_mod:good/tea', '--field', 'description', '--zh', '新的中文描述']);
  assertStatus(result, 0, 'loc zh only');
  assert.equal(mustJson(result, 'loc zh only').ok, true);
  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['good.test_mod.tea.description'], '新的中文描述');
  assert.equal(en['good.test_mod.tea.description'], enBefore['good.test_mod.tea.description'], 'en must keep its value');
});

test('loc --key/--locale/--text writes an arbitrary localization key directly', (t) => {
  const mod = createMod(t);
  const result = jsonRun(['loc', '--mod', mod, '--key', 'notice.test_mod.hello', '--locale', 'zh_CN', '--text', '你好，世界']);
  const json = mustJson(result, 'loc direct key');
  assertStatus(result, 0, 'loc direct key');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'loc');
  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['notice.test_mod.hello'], '你好，世界');
  assert.ok(!('notice.test_mod.hello' in en), 'direct loc write must only touch the requested locale');

  const enResult = jsonRun(['loc', '--mod', mod, '--key', 'notice.test_mod.hello', '--locale', 'en', '--text', 'Hello, world']);
  assertStatus(enResult, 0, 'loc direct key en');
  assert.equal(localeOf(mod, 'en')['notice.test_mod.hello'], 'Hello, world');
  assert.equal(localeOf(mod, 'zh_CN')['notice.test_mod.hello'], '你好，世界');
});

/* ------------------------------------------------------------------------- */
/* 6. clone                                                                  */
/* ------------------------------------------------------------------------- */

test('clone --from core:good/iron_ore --id my_ore renames id and keys, and qualifies the core model asset', (t) => {
  const mod = createMod(test, { id: 'clone_mod' });
  const result = jsonRun(['clone', '--mod', mod, '--from', 'core:good/iron_ore', '--id', 'my_ore']);
  const json = mustJson(result, 'clone iron_ore');
  assertStatus(result, 0, 'clone iron_ore');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'clone');
  assert.equal(json.stats.definitions, 2, 'clone adds one definition to the template one');

  const goods = goodsFileOf(mod);
  assert.equal(goods.payload.definitions.length, 2);
  assert.equal(goods.payload.definitions[0].id, 'clone_mod:good/tea', 'existing definition is kept first');
  const cloned = definitionById(mod, 'clone_mod:good/my_ore').definition;
  assert.equal(cloned.name_key, 'good.clone_mod.my_ore.name');
  assert.equal(cloned.description_key, 'good.clone_mod.my_ore.description');
  assert.deepEqual(cloned.tags, ['good.trade', 'good.bulk', 'good.shipbuilding']);
  assert.equal(cloned.data.base_price, 42);
  assert.equal(cloned.data.unit_weight, 3);
  assert.equal(cloned.information.model, 'asset://core/model.good.iron_ore', 'copied core model must be namespaced under asset://core/');

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.ok(zh['good.clone_mod.my_ore.name'], 'zh name key must be migrated to the new base');
  assert.match(zh['good.clone_mod.my_ore.name'], /副本/, 'default clone name keeps a (副本) marker');
  assert.ok(en['good.clone_mod.my_ore.name'], 'en name key must be migrated to the new base');
  assert.match(en['good.clone_mod.my_ore.name'], /\(copy\)/, 'default clone name keeps a (copy) marker');
  for (const key of [...Object.keys(zh), ...Object.keys(en)]) {
    assert.ok(!key.includes('iron_ore_copy'), `no stale clone keys may remain, found ${key}`);
  }
});

test('clone --name-zh/--name-en overrides the default copy names', (t) => {
  const mod = createMod(test, { id: 'clone_mod2' });
  const result = jsonRun([
    'clone', '--mod', mod, '--from', 'core:good/coal', '--id', 'my_coal',
    '--name-zh', '我的煤', '--name-en', 'My Coal',
  ]);
  assertStatus(result, 0, 'clone with names');
  assert.equal(mustJson(result, 'clone with names').ok, true);
  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['good.clone_mod2.my_coal.name'], '我的煤');
  assert.equal(en['good.clone_mod2.my_coal.name'], 'My Coal');
});

/* ------------------------------------------------------------------------- */
/* 7. rm                                                                     */
/* ------------------------------------------------------------------------- */

test('rm without --yes is a usage error (exit 2) and keeps the mod intact', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['rm', '--mod', mod, 'test_mod:good/tea']);
  assertUsageError(result, 'rm without --yes');
  assert.deepEqual(snapshotDir(mod), before, 'guarded rm must not write anything');
});

test('rm handles the first, middle and last array item without disturbing the others', (t) => {
  const mod = createMod(t);
  addGood(mod, 'item_a');
  addGood(mod, 'item_b');
  addGood(mod, 'item_c');
  const ids = () => goodsFileOf(mod).payload.definitions.map((definition) => definition.id);
  assert.deepEqual(ids(), ['test_mod:good/tea', 'test_mod:good/item_a', 'test_mod:good/item_b', 'test_mod:good/item_c']);

  // first
  let result = jsonRun(['rm', '--mod', mod, 'test_mod:good/tea', '--yes']);
  assertStatus(result, 0, 'rm first');
  assert.equal(mustJson(result, 'rm first').ok, true);
  assert.deepEqual(ids(), ['test_mod:good/item_a', 'test_mod:good/item_b', 'test_mod:good/item_c']);

  // middle
  result = jsonRun(['rm', '--mod', mod, 'test_mod:good/item_b', '--yes']);
  assertStatus(result, 0, 'rm middle');
  assert.equal(mustJson(result, 'rm middle').ok, true);
  assert.deepEqual(ids(), ['test_mod:good/item_a', 'test_mod:good/item_c']);

  // last
  result = jsonRun(['rm', '--mod', mod, 'test_mod:good/item_c', '--yes']);
  assertStatus(result, 0, 'rm last');
  const lastJson = mustJson(result, 'rm last');
  assert.equal(lastJson.ok, true);
  assert.deepEqual(ids(), ['test_mod:good/item_a']);

  // Remaining definition data is intact and the mod still validates.
  assert.equal(definitionById(mod, 'test_mod:good/item_a').definition.data.base_price, 50);
  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate after rm first/middle/last');
  assert.equal(mustJson(validateResult, 'validate after rm').issues.errors, 0);
});

test('rm of the only definition in a content file deletes that file and its manifest entry', (t) => {
  const mod = createMod(test, { template: 'starter_kit' });
  assert.deepEqual(manifestOf(mod).content, [
    'content/goods.json',
    'content/boilers.json',
    'content/events.json',
    'content/contracts.json',
  ]);
  const otherFilesBefore = {
    'content/boilers.json': sha256File(path.join(mod, 'content/boilers.json')),
    'content/events.json': sha256File(path.join(mod, 'content/events.json')),
    'content/contracts.json': sha256File(path.join(mod, 'content/contracts.json')),
  };

  const result = jsonRun(['rm', '--mod', mod, 'test_mod:good/tea', '--yes']);
  const json = mustJson(result, 'rm unique item');
  assertStatus(result, 0, 'rm unique item');
  assert.equal(json.ok, true);

  assert.ok(!fs.existsSync(path.join(mod, 'content', 'goods.json')), 'emptied content file must be deleted');
  assert.deepEqual(manifestOf(mod).content, [
    'content/boilers.json',
    'content/events.json',
    'content/contracts.json',
  ], 'manifest.content must drop the deleted file');
  for (const [rel, hash] of Object.entries(otherFilesBefore)) {
    assert.equal(sha256File(path.join(mod, rel)), hash, `${rel} must be untouched`);
  }
  const zh = localeOf(mod, 'zh_CN');
  assert.ok(!('good.test_mod.tea.name' in zh), 'exclusive localization keys of the removed definition must be deleted');
  assert.ok(!('good.test_mod.tea.description' in zh));

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate after rm unique item');
  assert.equal(mustJson(validateResult, 'validate after rm unique item').issues.errors, 0);
});

test('rm deletes exclusive localization keys but keeps keys shared with remaining definitions', (t) => {
  const mod = createMod(t);
  addGood(mod, 'item_a');
  addGood(mod, 'item_b');

  // Make item_b's name key shared: item_a now uses it as its description key.
  const goodsFile = goodsFileOf(mod);
  const payload = readJson(goodsFile.abs);
  const defA = payload.definitions.find((definition) => definition.id === 'test_mod:good/item_a');
  const defB = payload.definitions.find((definition) => definition.id === 'test_mod:good/item_b');
  assert.ok(defA && defB);
  const sharedKey = defB.name_key;
  const exclusiveKey = defB.description_key;
  defA.description_key = sharedKey;
  writeJson(goodsFile.abs, payload);

  const zhBefore = localeOf(mod, 'zh_CN');
  const sharedValue = zhBefore[sharedKey];
  assert.ok(sharedValue, `fixture expected ${sharedKey} to exist`);

  const result = jsonRun(['rm', '--mod', mod, 'test_mod:good/item_b', '--yes']);
  const json = mustJson(result, 'rm shared keys');
  assertStatus(result, 0, 'rm shared keys');
  assert.equal(json.ok, true);

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh[sharedKey], sharedValue, 'shared key must be retained with its value');
  assert.ok(!(exclusiveKey in zh), 'exclusive key must be deleted from zh_CN');
  assert.ok(!(exclusiveKey in en), 'exclusive key must be deleted from en');
  assert.ok(zh['good.test_mod.item_a.name'], 'remaining definition translations must survive');
  const ids = goodsFileOf(mod).payload.definitions.map((definition) => definition.id);
  assert.deepEqual(ids, ['test_mod:good/tea', 'test_mod:good/item_a']);
});

test('add then rm restores the content file byte-for-byte', (t) => {
  const mod = createMod(t);
  const goodsRel = goodsFileOf(mod).rel;
  const goodsBytesBefore = fs.readFileSync(path.join(mod, goodsRel));
  const manifestBytesBefore = fs.readFileSync(path.join(mod, 'manifest.json'));
  const zhBefore = localeOf(mod, 'zh_CN');
  const enBefore = localeOf(mod, 'en');

  addGood(mod, 'temporary_good');
  assert.notDeepEqual(fs.readFileSync(path.join(mod, goodsRel)), goodsBytesBefore, 'add must actually change the content file');

  const result = jsonRun(['rm', '--mod', mod, 'test_mod:good/temporary_good', '--yes']);
  const json = mustJson(result, 'rm after add');
  assertStatus(result, 0, 'rm after add');
  assert.equal(json.ok, true);

  assert.ok(
    fs.readFileSync(path.join(mod, goodsRel)).equals(goodsBytesBefore),
    'content file must be byte-for-byte identical to the original after add -> rm'
  );
  assert.ok(
    fs.readFileSync(path.join(mod, 'manifest.json')).equals(manifestBytesBefore),
    'manifest.json must be byte-for-byte identical when no content file was created'
  );
  assert.deepEqual(localeOf(mod, 'zh_CN'), zhBefore, 'zh_CN.json entries must be restored');
  assert.deepEqual(localeOf(mod, 'en'), enBefore, 'en.json entries must be restored');
});

test('add/rm preserves a leading UTF-8 BOM in the content file', (t) => {
  const mod = createMod(t);
  const goods = goodsFileOf(mod);

  // Regression: parseSource must accept a leading U+FEFF, keep source offsets
  // anchored to the original text, and therefore preserve the BOM on writes.
  const bom = Buffer.from([0xef, 0xbb, 0xbf]);
  const bomBytesBefore = Buffer.concat([bom, fs.readFileSync(goods.abs)]);
  fs.writeFileSync(goods.abs, bomBytesBefore);
  assert.equal(fs.readFileSync(goods.abs).subarray(0, 3).toString('hex'), 'efbbbf', 'fixture must start with a UTF-8 BOM');

  const addResult = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'bom_good',
    '--name-zh', 'BOM 商品', '--name-en', 'BOM Good',
  ]);
  const addJson = mustJson(addResult, 'add with BOM');
  assertStatus(addResult, 0, 'add with BOM');
  assert.equal(addJson.ok, true);

  const afterAdd = fs.readFileSync(goods.abs);
  assert.equal(afterAdd.subarray(0, 3).toString('hex'), 'efbbbf', 'the BOM must still be the first bytes after add');
  const afterAddPayload = JSON.parse(afterAdd.subarray(3).toString('utf8'));
  assert.equal(afterAddPayload.definitions.length, 2);
  assert.ok(
    afterAddPayload.definitions.some((definition) => definition.id === 'test_mod:good/bom_good'),
    'the added definition must be present in the BOM-prefixed file'
  );

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate with BOM');
  const validateJson = mustJson(validateResult, 'validate with BOM');
  assert.equal(validateJson.issues.errors, 0, `a BOM-prefixed mod must validate with 0 errors: ${JSON.stringify(validateJson.issues.list)}`);

  const rmResult = jsonRun(['rm', '--mod', mod, 'test_mod:good/bom_good', '--yes']);
  const rmJson = mustJson(rmResult, 'rm with BOM');
  assertStatus(rmResult, 0, 'rm with BOM');
  assert.equal(rmJson.ok, true);

  const restored = fs.readFileSync(goods.abs);
  assert.equal(restored.subarray(0, 3).toString('hex'), 'efbbbf', 'the BOM must survive add -> rm');
  assert.ok(
    restored.equals(bomBytesBefore),
    'content file must be byte-for-byte identical to the BOM-prefixed original after add -> rm'
  );
});

/* ------------------------------------------------------------------------- */
/* 8. validate                                                               */
/* ------------------------------------------------------------------------- */

test('validate --mod dev_mods/core passes with 0 errors and correct stats, without touching core', (t) => {
  const before = snapshotDir(coreDir, { onlyJson: true });
  const expectedDefinitions = expectedCoreDefinitionCount();
  const expectedContentFiles = readJson(path.join(coreDir, 'manifest.json')).content.length;
  const expectedLocales = readJson(path.join(coreDir, 'manifest.json')).localization.length;

  const result = jsonRun(['validate', '--mod', 'dev_mods/core']);
  const json = mustJson(result, 'validate core');
  assertStatus(result, 0, 'validate core');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'validate');
  assert.ok(String(json.mod).replace(/\\/g, '/').endsWith('dev_mods/core'), `mod must identify dev_mods/core, got ${json.mod}`);
  assert.equal(json.issues.errors, 0, `core must validate with 0 errors: ${JSON.stringify(json.issues.list)}`);
  assert.ok(json.issues.warnings > 0, 'core currently has warnings, which makes --strict meaningful');
  assert.ok(Array.isArray(json.issues.list), 'validate must expose the full issue list');
  assert.equal(json.issues.list.length, json.issues.errors + json.issues.warnings, 'issues.list must contain every issue');
  assert.equal(json.stats.definitions, expectedDefinitions);
  assert.equal(json.stats.contentFiles, expectedContentFiles);
  assert.equal(json.stats.locales, expectedLocales);
  assert.deepEqual(snapshotDir(coreDir, { onlyJson: true }), before, 'validate must never modify dev_mods/core');
});

test('validate --strict exits 1 when there are warnings but no errors', (t) => {
  const result = jsonRun(['validate', '--mod', 'dev_mods/core', '--strict']);
  const json = mustJson(result, 'validate --strict');
  assertStatus(result, 1, 'validate --strict');
  assert.equal(json.command, 'validate');
  assert.equal(json.issues.errors, 0, 'core has no errors');
  assert.ok(json.issues.warnings > 0, 'core has warnings; --strict must fail because of them');
});

test('validate --json on a broken mod still prints exactly one valid JSON object', (t) => {
  const root = tempRoot(t);
  const broken = path.join(root, 'broken_mod');
  fs.mkdirSync(broken);
  fs.writeFileSync(path.join(broken, 'manifest.json'), '{"id": "broken"}', 'utf8');
  const result = jsonRun(['validate', '--mod', broken]);
  const json = mustJson(result, 'validate broken');
  assert.equal(result.status, 1);
  assert.equal(json.ok, false);
  assert.ok(json.error && typeof json.error.code === 'string');
});

/* ------------------------------------------------------------------------- */
/* 9. generic error / output contract                                        */
/* ------------------------------------------------------------------------- */

test('a failing add with --json emits only one valid JSON object and a conflict code', (t) => {
  const mod = createMod(t);
  addGood(mod, 'json_failure');
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'goods', '--id', 'json_failure',
    '--name-zh', '失败', '--name-en', 'Failure',
  ]);
  // mustJson already proves stdout is exactly one parseable JSON object.
  const json = mustFailJson(result, 'json failure');
  assertStatus(result, 1, 'json failure');
  assert.equal(json.error.code, 'conflict');
  assert.equal(json.command, 'add', 'failure JSON keeps the command name');
});

test('unknown command with --json exits 2 and still emits JSON', (t) => {
  const result = runCli(['not_a_command', '--json']);
  const json = mustFailJson(result, 'unknown command');
  assertStatus(result, 2, 'unknown command');
  assert.ok(json.error.code);
});

test('--mod directory without manifest.json fails with a JSON error and writes nothing', (t) => {
  const root = tempRoot(t);
  const noManifest = path.join(root, 'no_manifest');
  fs.mkdirSync(noManifest);
  fs.writeFileSync(path.join(noManifest, 'content.json'), '{}\n', 'utf8');
  const before = snapshotDir(noManifest);
  const result = jsonRun(['validate', '--mod', noManifest]);
  const json = mustFailJson(result, 'no manifest');
  assert.notEqual(result.status, 0, 'missing manifest must be a failure');
  assert.ok(json.error.code, 'missing manifest must report an error code');
  assert.deepEqual(snapshotDir(noManifest), before, 'failed command must not modify the target directory');
});
