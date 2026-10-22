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
 *   node SNModMaker/tests/content-cli.test.mjs
 *   # or: node --test SNModMaker/tests/content-cli.test.mjs
 *
 * Covers the 25 runtime Content Schema types (16 1.0 + 9 promoted Phase B 2.0)
 * and the 3 Schema 2.0 draft types (weapons + Story Mode arcs/levels):
 * draft:true / schema_version 2.0, draft_content warning, v2 $refs, the
 * story-pack whitelist, and capability exposure / capability_undeclared for
 * every Schema 2.0 type. All write operations happen inside
 * fs.mkdtempSync(os.tmpdir()) fixtures. The repository's dev_mods/core and
 * sdk/templates are only ever read (a few tests hash them before and after to
 * prove that).
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
const ITEMS_FILE = 'content/items.json';
/* Shipped Story Mode sample pack: story-only content mod, read-only fixture.
 * It lives under sdk/templates because the 1.0 runtime cannot load it yet. */
const STORY_PACK_DIR = path.join(repoRoot, 'sdk', 'templates', 'story_pack_iron_tide');

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
 * Default fixture: template "items" -> one definition (test_mod:item/tea) plus
 * localization/zh_CN.json + localization/en.json, 0 validation errors.
 */
function createMod(t, { id = MOD_ID, name = '测试模组', template = 'items', extra = [] } = {}) {
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

function itemsFileOf(mod) {
  return contentFileOfType(mod, 'items');
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

function addItem(mod, id, extra = []) {
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', id,
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

/** Recursively copy a directory so a test can mutate a read-only fixture copy. */
function copyDir(source, target) {
  fs.mkdirSync(target, { recursive: true });
  for (const entry of fs.readdirSync(source, { withFileTypes: true })) {
    const from = path.join(source, entry.name);
    const to = path.join(target, entry.name);
    if (entry.isDirectory()) copyDir(from, to);
    else fs.copyFileSync(from, to);
  }
  return target;
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
  assert.equal(json.types.length, 23, '20 runtime types + 3 Schema 2.0 draft types are editable');
  assert.equal(json.activeTypes, 20, 'activeTypes counts runtime types at both 1.0 and 2.0');
  assert.equal(json.draftTypes, 3, 'draftTypes counts the Schema 2.0 draft types');
  const keys = json.types.map((entry) => entry.key);
  for (const key of ['items', 'hulls', 'modules', 'events', 'contracts', 'patches']) {
    assert.ok(keys.includes(key), `types must include ${key}`);
  }
  for (const legacyModuleType of ['boilers', 'cargo_modules', 'navigation_modules', 'safety_modules', 'cabins']) {
    assert.ok(!keys.includes(legacyModuleType), `C1 removed the ${legacyModuleType} content type in favour of modules`);
  }
  for (const legacyItemType of ['goods', 'materials']) {
    assert.ok(!keys.includes(legacyItemType), `C2 removed the ${legacyItemType} content type in favour of items`);
  }
  const items = json.types.find((entry) => entry.key === 'items');
  assert.equal(items.singular, 'item');
  assert.equal(items.keyPrefix, 'item');
  assert.equal(items.label, '物品');
  assert.equal(items.en, 'Items');
  assert.equal(items.file, 'content/items.json');
  assert.equal(items.schema, 'v2/item.schema.json');
  assert.equal(items.schema_version, '2.0');
  assert.equal(items.capability, 'content.items.v1', 'the merged item type exposes its capability');
  assert.ok(items.group, 'items.group must be present');
  assert.ok(items.summary, 'items.summary must be present');
  assert.ok(!items.draft, 'runtime types are not marked draft');
  const patches = json.types.find((entry) => entry.key === 'patches');
  assert.equal(patches.file, 'content/patches.json');
  assert.equal(patches.schema, 'patch.schema.json');

  const drafts = json.types.filter((entry) => entry.draft);
  assert.equal(drafts.length, 3, 'weapons and the two Story Mode drafts are listed with draft:true');
  assert.deepEqual(drafts.map((entry) => entry.key), ['weapons', 'story_arcs', 'story_levels']);
  const world = json.types.find((entry) => entry.key === 'world_profiles');
  assert.ok(world, 'world_profiles must be listed as an active type');
  assert.equal(world.singular, 'world_profile');
  assert.equal(world.keyPrefix, 'world');
  assert.equal(world.file, 'content/world_profiles.json');
  assert.equal(world.schema, 'v2/world_profile.schema.json');
  assert.equal(world.schema_version, '2.0');
  assert.equal(world.capability, 'content.world.v1', 'promoted Schema 2.0 runtime rows expose their capability');
  assert.ok(!world.draft, 'Phase B promoted world_profiles to a runtime type');
  const mapConfig = json.types.find((entry) => entry.key === 'map_configs');
  assert.ok(mapConfig, 'map_configs must be listed as an active type');
  assert.equal(mapConfig.schema, 'v2/map_config.schema.json');
  assert.equal(mapConfig.schema_version, '2.0');
  assert.equal(mapConfig.capability, 'content.world.v1');
  const startProfile = json.types.find((entry) => entry.key === 'start_profiles');
  assert.ok(startProfile, 'start_profiles must be listed as an active type');
  assert.equal(startProfile.schema_version, '2.0');
  assert.equal(startProfile.capability, 'content.campaign.v1');

  // The Phase B world/campaign types plus the C1 hull/module and C2 item types are active runtime rows at Schema 2.0.
  const runtimeV2 = json.types.filter((entry) => !entry.draft && entry.schema_version === '2.0');
  assert.deepEqual(
    runtimeV2.map((entry) => entry.key).sort(),
    ['discoveries', 'factions', 'hulls', 'items', 'map_configs', 'modules', 'regions', 'route_templates', 'sites',
      'start_profiles', 'weather_profiles', 'world_profiles'],
    'exactly the twelve Schema 2.0 runtime rows are active'
  );
  const runtimeCapabilities = {
    hulls: 'content.hulls.v1',
    items: 'content.items.v1',
    modules: 'content.modules.v1',
    start_profiles: 'content.campaign.v1',
  };
  for (const runtime of runtimeV2) {
    assert.equal(runtime.schema, `v2/${runtime.singular}.schema.json`,
      `${runtime.key} must point at its v2 schema`);
    assert.ok(runtime.capability, `${runtime.key} must expose its capability`);
    assert.equal(
      runtime.capability,
      runtimeCapabilities[runtime.key] || 'content.world.v1',
      `${runtime.key} declares its capability`
    );
  }
  const modules = json.types.find((entry) => entry.key === 'modules');
  assert.ok(modules, 'modules must be listed as an active type');
  assert.equal(modules.singular, 'module');
  assert.equal(modules.keyPrefix, 'module');
  assert.equal(modules.file, 'content/modules.json');
  assert.equal(modules.schema, 'v2/module.schema.json');
  assert.equal(modules.schema_version, '2.0');
  assert.equal(modules.capability, 'content.modules.v1');
  assert.ok(!modules.draft, 'C1 promoted modules to a runtime type');
  const hulls = json.types.find((entry) => entry.key === 'hulls');
  assert.equal(hulls.schema, 'v2/hull.schema.json');
  assert.equal(hulls.schema_version, '2.0');
  assert.equal(hulls.capability, 'content.hulls.v1');
  const weapons = drafts.find((entry) => entry.key === 'weapons');
  assert.ok(weapons, 'weapons must be listed as a draft type');
  assert.equal(weapons.singular, 'weapon');
  assert.equal(weapons.keyPrefix, 'weapon');
  assert.equal(weapons.file, 'content/weapons.json');
  assert.equal(weapons.schema, 'v2/weapon.schema.json');
  assert.equal(weapons.schema_version, '2.0');
  assert.equal(weapons.capability, 'content.combat.v1');
  for (const key of ['story_arcs', 'story_levels']) {
    const story = drafts.find((entry) => entry.key === key);
    assert.ok(story, `${key} must be listed as a draft type`);
    assert.equal(story.schema_version, '2.0');
    assert.equal(story.schema, `v2/${key === 'story_arcs' ? 'story_arc' : 'story_level'}.schema.json`);
    assert.equal(story.capability, 'content.story.v1');
    assert.equal(story.group, json.types.find((entry) => entry.key === 'contracts').group, 'story drafts share the narrative/events group');
  }
  for (const draft of drafts) {
    assert.equal(draft.schema_version, '2.0', `${draft.key} must list schema_version 2.0`);
    assert.match(draft.schema, /^v2\/.+\.schema\.json$/, `${draft.key} must point at the v2 schema bundle entry`);
    assert.ok(draft.capability, `${draft.key} must expose its capability`);
  }
});

test('types human output separates Schema 2.0 runtime rows from the remaining drafts', (t) => {
  const result = runCli(['types']);
  assertStatus(result, 0, 'types human');
  const stdout = String(result.stdout);
  assert.match(
    stdout,
    /运行时内容类型（20；其中 12 类为运行时 Schema 2\.0）：/,
    `runtime section must report the 20 active types, 12 of them Schema 2.0:\n${stdout}`
  );
  assert.equal(
    stdout.split('[runtime 2.0]').length - 1,
    12,
    `every promoted Schema 2.0 runtime row must be marked:\n${stdout}`
  );
  assert.match(
    stdout,
    /^modules\s+模块\s+module\s+content\/modules\.json  \[runtime 2\.0\]$/m,
    `modules must be shown as a runtime Schema 2.0 type:\n${stdout}`
  );
  assert.match(
    stdout,
    /^hulls\s+船体\s+hull\s+content\/hulls\.json  \[runtime 2\.0\]$/m,
    `hulls must be shown as a runtime Schema 2.0 type:\n${stdout}`
  );
  assert.match(
    stdout,
    /^world_profiles\s+世界配置\s+world_profile\s+content\/world_profiles\.json  \[runtime 2\.0\]$/m,
    `world_profiles must be shown as a runtime Schema 2.0 type:\n${stdout}`
  );
  assert.match(
    stdout,
    /^items\s+物品\s+item\s+content\/items\.json  \[runtime 2\.0\]$/m,
    `items must be shown as a runtime Schema 2.0 type:\n${stdout}`
  );
  assert.match(
    stdout,
    /^roles\s+船员岗位\s+role\s+content\/roles\.json$/m,
    `1.0 runtime rows stay unmarked:\n${stdout}`
  );
  assert.match(
    stdout,
    /Schema 2\.0 草案类型（3）：编辑器 \/ CLI 可编辑，游戏运行时不加载/,
    `the draft section must describe the three remaining draft types:\n${stdout}`
  );
  assert.match(
    stdout,
    /^weapons\s+舰载武器\s+weapon\s+content\/weapons\.json  \[draft 2\.0\]$/m,
    `weapons keeps a draft marker:\n${stdout}`
  );
  for (const [key, label, singular, schema] of [
    ['story_arcs', '剧情篇章', 'story_arc', 'content/story_arcs.json'],
    ['story_levels', '剧情关卡', 'story_level', 'content/story_levels.json'],
  ]) {
    assert.match(
      stdout,
      new RegExp(`^${key}\\s+${label}\\s+${singular}\\s+${schema}  \\[draft 2\\.0\\]$`, 'm'),
      `${key} must be listed in the draft section:\n${stdout}`
    );
  }
  const runtimeIndex = stdout.indexOf('运行时内容类型');
  const draftIndex = stdout.indexOf('Schema 2.0 草案类型');
  assert.ok(runtimeIndex >= 0 && draftIndex > runtimeIndex, 'the draft section must come after the runtime section');
  assert.ok(
    stdout.indexOf('world_profiles') < draftIndex,
    'world_profiles must be listed inside the runtime section, not in the draft section'
  );
  assert.ok(
    stdout.indexOf('story_arcs') > draftIndex,
    'story_arcs must be listed inside the draft section, not in the runtime section'
  );
});

test('describe items --json reports id pattern, keys, fields, defaults and skeleton', (t) => {
  const result = jsonRun(['describe', 'items']);
  assertStatus(result, 0, 'describe items');
  const json = mustJson(result, 'describe items');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'describe');

  assert.equal(json.type.key, 'items');
  assert.equal(json.type.singular, 'item');
  assert.equal(json.type.keyPrefix, 'item');
  assert.equal(json.type.label, '物品');
  assert.equal(json.type.file, 'content/items.json');
  assert.equal(json.type.schema, 'v2/item.schema.json');
  assert.equal(json.type.schema_version, '2.0');
  assert.equal(json.type.capability, 'content.items.v1');

  assert.equal(json.id.pattern, '^[a-z][a-z0-9_]{2,31}:[a-z_]+/[a-z0-9_]+$');
  assert.equal(json.id.singular, 'item');
  assert.equal(json.id.example, 'my_mod:item/tea');

  assert.equal(json.keys.base, 'item.my_mod.tea');
  assert.equal(json.keys.name, 'item.my_mod.tea.name');
  assert.equal(json.keys.description, 'item.my_mod.tea.description');

  assert.ok(Array.isArray(json.fields), 'fields must be an array');
  const basePrice = json.fields.find((field) => field.path === 'data.base_price');
  assert.ok(basePrice, `fields must contain data.base_price: ${JSON.stringify(json.fields)}`);
  assert.equal(basePrice.type, 'number');
  assert.equal(basePrice.required, true);
  assert.equal(basePrice.minimum, 1);
  const craftingMaterial = json.fields.find((field) => field.path === 'data.crafting_material');
  assert.ok(craftingMaterial, 'fields must contain data.crafting_material');
  assert.equal(craftingMaterial.type, 'boolean');
  assert.equal(craftingMaterial.required, true, 'C2 requires the explicit crafting_material flag');
  const category = json.fields.find((field) => field.path === 'data.category');
  assert.ok(category, 'fields must contain data.category');
  assert.equal(category.type, 'string');
  const elasticity = json.fields.find((field) => field.path === 'data.price_elasticity');
  assert.ok(elasticity, 'fields must contain data.price_elasticity');
  assert.equal(elasticity.type, 'number');
  assert.equal(elasticity.minimum, 0);
  assert.equal(elasticity.maximum, 1);

  assert.equal(json.defaults.crafting_material, false);
  assert.equal(json.defaults.unit_weight, 1);
  assert.equal(json.defaults.base_price, 50);
  assert.equal(json.defaults.base_stock, 80);
  assert.equal(json.defaults.price_elasticity, 0.15);
  assert.equal(json.defaults.spawn_weight, 1);
  assert.equal(json.defaults.category, 'trade');

  assert.ok(Array.isArray(json.suggestions.tags));
  assert.ok(json.suggestions.tags.includes('good.trade'));

  assert.equal(json.skeleton.id, 'my_mod:item/tea');
  assert.equal(json.skeleton.name_key, 'item.my_mod.tea.name');
  assert.equal(json.skeleton.description_key, 'item.my_mod.tea.description');
  assert.deepEqual(json.skeleton.tags, ['good.trade']);
  assert.equal(json.skeleton.enabled, true);
  assert.equal(json.skeleton.data.base_price, 50);
  assert.equal(json.skeleton.data.crafting_material, false);
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
  assert.equal(json.skeleton.target, 'core:module/small_efficient');
  assert.equal(json.skeleton.requires.mod, 'core');
  assert.equal(json.skeleton.requires.version, '>=1.0.0 <2.0.0');
  assert.ok(Array.isArray(json.skeleton.operations));
  assert.deepEqual(json.skeleton.operations[0], { op: 'replace', path: '/data/purchase_price', value: 380 });
});

test('describe world_profiles --json reports the Schema 2.0 runtime contract', (t) => {
  const result = jsonRun(['describe', 'world_profiles']);
  assertStatus(result, 0, 'describe world_profiles');
  const json = mustJson(result, 'describe world_profiles');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'describe');
  assert.equal(json.type.key, 'world_profiles');
  assert.equal(json.type.singular, 'world_profile');
  assert.equal(json.type.keyPrefix, 'world');
  assert.equal(json.type.file, 'content/world_profiles.json');
  assert.equal(json.type.schema, 'v2/world_profile.schema.json');
  assert.ok(!json.type.draft, 'Phase B promoted world_profiles to a runtime type');
  assert.equal(json.type.schema_version, '2.0');
  assert.equal(json.type.capability, 'content.world.v1', 'describe must expose the runtime capability');
  assert.equal(json.id.singular, 'world_profile');
  assert.equal(json.id.example, 'my_mod:world_profile/tea');
  assert.equal(json.keys.base, 'world.my_mod.tea');

  const regionCount = json.fields.find((field) => field.path === 'data.region_count');
  assert.ok(regionCount, `fields must contain data.region_count: ${JSON.stringify(json.fields)}`);
  assert.equal(regionCount.type, 'integer');
  assert.equal(regionCount.required, true);
  assert.equal(regionCount.minimum, 1);
  assert.equal(regionCount.maximum, 64);
  const weather = json.fields.find((field) => field.path === 'data.weather_profile');
  assert.ok(weather, 'fields must contain data.weather_profile');
  assert.match(String(weather.$ref), /id_ref/, 'the v2 common id_ref $ref must be preserved in the field table');

  assert.equal(json.defaults.region_count, 3);
  assert.equal(json.defaults.port_count, 8);
  assert.equal(json.defaults.weather_profile, 'core:weather_profile/temperate');
  assert.equal(json.skeleton.id, 'my_mod:world_profile/tea');
  assert.equal(json.skeleton.name_key, 'world.my_mod.tea.name');
  assert.equal(json.skeleton.data.region_count, 3);

  // Human output: a promoted type is a runtime Schema 2.0 type, never a draft.
  const humanResult = runCli(['describe', 'world_profiles']);
  assertStatus(humanResult, 0, 'describe world_profiles human');
  const human = String(humanResult.stdout);
  assert.match(human, /运行时 Schema 2\.0/, `subtitle must name the runtime Schema 2.0:\n${human}`);
  assert.match(human, /capability content\.world\.v1/, 'subtitle must name the declared capability');
  assert.ok(!human.includes('草案'), `a promoted type must not be described as a draft:\n${human}`);
  assert.ok(!human.includes('不加载'), `a promoted type is loaded by the runtime:\n${human}`);
});

test('describe weapons --json reports the Schema 2.0 weapon contract', (t) => {
  const result = jsonRun(['describe', 'weapons']);
  assertStatus(result, 0, 'describe weapons');
  const json = mustJson(result, 'describe weapons');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'describe');
  assert.equal(json.type.key, 'weapons');
  assert.equal(json.type.singular, 'weapon');
  assert.equal(json.type.keyPrefix, 'weapon');
  assert.equal(json.type.file, 'content/weapons.json');
  assert.equal(json.type.schema, 'v2/weapon.schema.json');
  assert.equal(json.type.draft, true, 'draft types must be marked');
  assert.equal(json.type.schema_version, '2.0');
  assert.equal(json.type.capability, 'content.combat.v1');
  assert.equal(json.id.singular, 'weapon');
  assert.equal(json.id.example, 'my_mod:weapon/tea');
  assert.equal(json.keys.base, 'weapon.my_mod.tea');

  const kind = json.fields.find((field) => field.path === 'data.kind');
  assert.ok(kind, `fields must contain data.kind: ${JSON.stringify(json.fields)}`);
  assert.equal(kind.type, 'string');
  assert.equal(kind.required, true);
  assert.deepEqual(kind.enum, ['direct', 'artillery', 'broadside']);
  const damage = json.fields.find((field) => field.path === 'data.damage');
  assert.ok(damage, 'fields must contain data.damage');
  assert.equal(damage.type, 'number');
  assert.equal(damage.required, true);
  assert.equal(damage.minimum, 1);
  assert.equal(damage.maximum, 120);
  const weaponClass = json.fields.find((field) => field.path === 'data.weapon_class');
  assert.ok(weaponClass, 'fields must contain data.weapon_class');
  assert.deepEqual(weaponClass.enum, ['Light', 'Medium', 'Heavy', 'Tower', 'Side', 'Modular']);
  const assembly = json.fields.find((field) => field.path === 'data.assembly_profile');
  assert.ok(assembly, 'fields must contain data.assembly_profile');
  assert.ok(assembly.enum.includes('yaw_pitch_multi'), 'assembly_profile exposes every mechanism combo');
  const muzzle = json.fields.find((field) => field.path === 'data.muzzle_count');
  assert.ok(muzzle, 'fields must contain data.muzzle_count');
  assert.equal(muzzle.type, 'integer');
  assert.equal(muzzle.minimum, 1);
  assert.equal(muzzle.maximum, 8);
  const materials = json.fields.find((field) => field.path === 'data.materials[]');
  assert.ok(materials, 'fields must contain the data.materials item shape');
  assert.equal(materials.$ref, '#/$defs/craft_material');
  const materialId = json.fields.find((field) => field.path === 'data.materials[].id');
  assert.ok(materialId, 'weapon craft materials use the {id, amount} runtime module shape');
  assert.match(String(materialId.$ref), /id_ref/, 'material id keeps the common id_ref $ref');

  assert.equal(json.defaults.kind, 'direct');
  assert.equal(json.defaults.damage, 12);
  assert.equal(json.defaults.range, 245);
  assert.equal(json.defaults.weapon_class, 'Light');
  assert.equal(json.defaults.assembly_profile, 'yaw_pitch');
  assert.equal(json.defaults.color, '#ffd37a');
  assert.deepEqual(json.defaults.materials, []);
  assert.equal(json.skeleton.id, 'my_mod:weapon/tea');
  assert.equal(json.skeleton.name_key, 'weapon.my_mod.tea.name');
  assert.equal(json.skeleton.data.kind, 'direct');
  assert.ok(json.suggestions.tags.includes('weapon.direct'), 'weapon tag suggestions are exposed');

  // Human output: the remaining weapon type is still a draft the runtime does not load.
  const humanResult = runCli(['describe', 'weapons']);
  assertStatus(humanResult, 0, 'describe weapons human');
  const human = String(humanResult.stdout);
  assert.match(human, /草案 Schema 2\.0/, `the weapon draft must stay marked as a draft:\n${human}`);
  assert.match(human, /游戏运行时不加载/, 'the draft subtitle must explain that the runtime does not load it');
  assert.match(human, /capability content\.combat\.v1/, 'the draft subtitle must expose its capability');
});

test('add --type world_profiles writes a Schema 2.0 content file as a runtime type', (t) => {
  const mod = createMod(t);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'world_profiles', '--id', 'first_world',
    '--name-zh', '首个世界', '--name-en', 'First World',
  ]);
  const json = mustJson(result, 'add world_profiles');
  assertStatus(result, 0, 'add world_profiles');
  assert.equal(json.ok, true);
  assert.equal(json.issues.newErrors, 0, `add must not introduce errors: ${JSON.stringify(json.issues.list)}`);
  const changedPaths = json.changes.map((change) => change.path);
  assert.ok(changedPaths.includes('content/world_profiles.json'), `changes must mention the draft content file: ${JSON.stringify(changedPaths)}`);
  assert.ok(changedPaths.includes('manifest.json'), 'the new content file must be declared in manifest.content');

  const file = contentFileOfType(mod, 'world_profiles');
  assert.equal(file.payload.schema_version, '2.0');
  assert.equal(file.payload.content_type, 'world_profiles');
  assert.equal(file.payload.definitions.length, 1);
  const definition = file.payload.definitions[0];
  assert.equal(definition.id, 'test_mod:world_profile/first_world');
  assert.equal(definition.name_key, 'world.test_mod.first_world.name');
  assert.equal(definition.data.region_count, 3);
  assert.equal(definition.data.weather_profile, 'core:weather_profile/temperate');
  assert.ok(manifestOf(mod).content.includes('content/world_profiles.json'));
  assert.equal(localeOf(mod, 'zh_CN')['world.test_mod.first_world.name'], '首个世界');
  assert.equal(localeOf(mod, 'en')['world.test_mod.first_world.name'], 'First World');
  // Merged items keep their 2.0 envelope in the same project.
  assert.equal(itemsFileOf(mod).payload.schema_version, '2.0');

  const warningCodes = (json.issues.list || []).filter((issue) => issue.severity === 'warning').map((issue) => issue.code);
  assert.ok(!warningCodes.includes('draft_content'), `a promoted type must not warn as draft: ${JSON.stringify(json.issues.list)}`);
  // Schema 2.0 content needs its capability in manifest.capabilities; the CLI never
  // declares it automatically, so the add reports `capability_undeclared` instead.
  assert.ok(
    warningCodes.includes('capability_undeclared'),
    `Schema 2.0 content without a declared capability must warn: ${JSON.stringify(json.issues.list)}`
  );
  assert.ok(json.issues.newWarnings >= 1, 'the undeclared capability is a new warning for the add');
  const undeclared = json.issues.list.find(
    (issue) => issue.code === 'capability_undeclared' && /content\.world\.v1/.test(String(issue.message))
  );
  assert.ok(undeclared, 'the world capability must be reported as undeclared');
  assert.match(String(undeclared.message), /content\.world\.v1/, 'the warning must name the required capability');
  assert.deepEqual(manifestOf(mod).capabilities || [], [], 'add must not declare the capability automatically');
  // B4 landed the Core world content (`core:weather_profile/temperate` etc.), so the starter
  // reference resolves and must no longer warn as `ref_core_unknown`.
  assert.ok(
    !warningCodes.includes('ref_core_unknown'),
    `Core world content is shipped by B4, so no unknown Core reference may remain: ${JSON.stringify(json.issues.list)}`
  );

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate world mod');
  const validateJson = mustJson(validateResult, 'validate world mod');
  assert.equal(validateJson.issues.errors, 0, `Schema 2.0 content must validate with 0 errors: ${JSON.stringify(validateJson.issues.list)}`);
  assert.ok(!validateJson.issues.list.some((issue) => issue.code === 'draft_content'));
  assert.ok(
    validateJson.issues.list.some((issue) => issue.code === 'capability_undeclared'),
    `validate must report the undeclared capability: ${JSON.stringify(validateJson.issues.list)}`
  );

  // `--strict` turns the undeclared-capability warning into a failure.
  const strictResult = jsonRun(['validate', '--mod', mod, '--strict']);
  assertStatus(strictResult, 1, 'an undeclared capability warning fails --strict');
  const strictJson = mustJson(strictResult, 'validate world mod strict');
  assert.equal(strictJson.ok, false);
  assert.equal(strictJson.error.code, 'validation', JSON.stringify(strictJson.error));

  // Declaring the capability in the manifest clears the warning. The CLI does not do
  // this for `add`, so the project author has to make the declaration explicit.
  const manifest = manifestOf(mod);
  manifest.capabilities = ['content.world.v1', 'content.items.v1'];
  writeJson(path.join(mod, 'manifest.json'), manifest);
  const declaredResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(declaredResult, 0, 'validate world mod with declared capability');
  const declaredJson = mustJson(declaredResult, 'validate world mod declared');
  assert.equal(declaredJson.issues.errors, 0, JSON.stringify(declaredJson.issues.list));
  assert.ok(
    !declaredJson.issues.list.some((issue) => issue.code === 'capability_undeclared'),
    `the declared capability must clear the warning: ${JSON.stringify(declaredJson.issues.list)}`
  );
  const strictDeclared = jsonRun(['validate', '--mod', mod, '--strict']);
  assertStatus(strictDeclared, 0, 'declaring content.world.v1 and content.items.v1 makes --strict pass');
});

test('add --type weapons writes a Schema 2.0 content file that validates cleanly', (t) => {
  const mod = createMod(t);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'weapons', '--id', 'deck_gun',
    '--name-zh', '甲板速射炮', '--name-en', 'Deck Rapid Gun',
  ]);
  const json = mustJson(result, 'add weapons');
  assertStatus(result, 0, 'add weapons');
  assert.equal(json.ok, true);
  assert.equal(json.issues.newErrors, 0, `add must not introduce errors: ${JSON.stringify(json.issues.list)}`);
  const changedPaths = json.changes.map((change) => change.path);
  assert.ok(changedPaths.includes('content/weapons.json'), `changes must mention the weapon content file: ${JSON.stringify(changedPaths)}`);
  assert.ok(changedPaths.includes('manifest.json'), 'the new content file must be declared in manifest.content');

  const file = contentFileOfType(mod, 'weapons');
  assert.equal(file.payload.schema_version, '2.0');
  assert.equal(file.payload.content_type, 'weapons');
  assert.equal(file.payload.definitions.length, 1);
  const definition = file.payload.definitions[0];
  assert.equal(definition.id, 'test_mod:weapon/deck_gun');
  assert.equal(definition.name_key, 'weapon.test_mod.deck_gun.name');
  assert.ok(definition.tags.includes('weapon.direct'), 'default weapon tag is applied');
  assert.equal(definition.data.kind, 'direct');
  assert.equal(definition.data.damage, 12);
  assert.equal(definition.data.range, 245);
  assert.equal(definition.data.weapon_class, 'Light');
  assert.equal(definition.data.assembly_profile, 'yaw_pitch');
  assert.equal(definition.data.muzzle_count, 1);
  assert.deepEqual(definition.data.materials, []);
  assert.ok(manifestOf(mod).content.includes('content/weapons.json'));
  assert.equal(localeOf(mod, 'zh_CN')['weapon.test_mod.deck_gun.name'], '甲板速射炮');
  assert.equal(localeOf(mod, 'en')['weapon.test_mod.deck_gun.name'], 'Deck Rapid Gun');

  const warningCodes = (json.issues.list || []).filter((issue) => issue.severity === 'warning').map((issue) => issue.code);
  assert.ok(warningCodes.includes('draft_content'), `draft content must warn: ${JSON.stringify(json.issues.list)}`);
  assert.ok(warningCodes.includes('capability_undeclared'), `undeclared capability must warn: ${JSON.stringify(json.issues.list)}`);
  const undeclared = json.issues.list.find((issue) => issue.code === 'capability_undeclared');
  assert.match(String(undeclared.message), /content\.combat\.v1/, 'the weapon capability must be named');
  assert.deepEqual(manifestOf(mod).capabilities || [], [], 'add must not declare the capability automatically');

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate weapons mod');
  const validateJson = mustJson(validateResult, 'validate weapons mod');
  assert.equal(validateJson.issues.errors, 0, `weapon content must validate with 0 errors: ${JSON.stringify(validateJson.issues.list)}`);
});

test('validate accepts the shipped Story Mode example pack', () => {
  const before = snapshotDir(STORY_PACK_DIR);
  const result = jsonRun(['validate', '--mod', STORY_PACK_DIR]);
  assertStatus(result, 0, 'validate story example pack');
  const json = mustJson(result, 'validate story example pack');
  assert.equal(json.issues.errors, 0, `story pack must validate with 0 errors: ${JSON.stringify(json.issues.list)}`);
  const warningCodes = (json.issues.list || [])
    .filter((issue) => issue.severity === 'warning')
    .map((issue) => issue.code)
    .sort();
  assert.deepEqual(warningCodes, ['draft_content', 'draft_content']);
  assert.equal(json.stats.definitions, 3, 'one arc + two levels');
  assert.equal(json.stats.contentFiles, 2);
  assert.equal(json.stats.locales, 2);
  assertDirUnchanged(before, STORY_PACK_DIR, 'the story example pack is a read-only fixture');
});

test('validate rejects free-mode content inside a story pack', (t) => {
  const mod = copyDir(STORY_PACK_DIR, path.join(tempRoot(t), 'story_pack'));
  writeJson(path.join(mod, 'content', 'items.json'), {
    schema_version: '2.0',
    content_type: 'items',
    definitions: [{
      id: 'example_story_iron_tide:item/tea',
      name_key: 'story.iron_tide.l01.name',
      enabled: true,
      data: { crafting_material: false, unit_weight: 1, base_price: 50, base_stock: 80, price_elasticity: 0.15, spawn_weight: 1, category: 'trade' },
    }],
  });
  const manifest = manifestOf(mod);
  manifest.content.push('content/items.json');
  writeJson(path.join(mod, 'manifest.json'), manifest);

  const result = jsonRun(['validate', '--mod', mod]);
  assertStatus(result, 1, 'validate story pack with free-mode content');
  const json = mustJson(result, 'validate story pack with free-mode content');
  assert.ok(
    json.issues.list.some((issue) => issue.code === 'story_pack_off_whitelist'),
    `story packs are story-only: ${JSON.stringify(json.issues.list)}`
  );
});

test('add blocks new Schema 2.0 errors and writes nothing', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'world_profiles', '--id', 'bad_world',
    '--name-zh', '坏世界', '--name-en', 'Bad World',
    '--data', 'data.port_count=0',
  ]);
  const json = mustFailJson(result, 'add invalid draft');
  assertStatus(result, 1, 'add invalid draft');
  assert.equal(json.error.code, 'validation', `schema errors from the v2 bundle must block the write: ${JSON.stringify(json.error)}`);
  assert.deepEqual(snapshotDir(mod), before, 'a blocked draft add must not write anything');
});

test('validate reports schema_version_mismatch for a 1.0 draft content file', (t) => {
  const mod = createMod(t);
  const addResult = jsonRun([
    'add', '--mod', mod, '--type', 'world_profiles', '--id', 'first_world',
    '--name-zh', '首个世界', '--name-en', 'First World',
  ]);
  assertStatus(addResult, 0, 'add draft before mismatch');

  const file = contentFileOfType(mod, 'world_profiles');
  const payload = readJson(file.abs);
  payload.schema_version = '1.0';
  writeJson(file.abs, payload);

  const result = jsonRun(['validate', '--mod', mod]);
  const json = mustJson(result, 'validate draft mismatch');
  assertStatus(result, 1, 'validate draft mismatch');
  assert.equal(json.ok, false);
  assert.ok(
    json.issues.list.some((issue) => issue.code === 'schema_version_mismatch'),
    `expected schema_version_mismatch: ${JSON.stringify(json.issues.list)}`
  );
});

test('list --type world_profiles lists a draft definition', (t) => {
  const mod = createMod(t);
  const addResult = jsonRun([
    'add', '--mod', mod, '--type', 'world_profiles', '--id', 'first_world',
    '--name-zh', '首个世界', '--name-en', 'First World',
  ]);
  assertStatus(addResult, 0, 'add draft before list');
  const result = jsonRun(['list', '--mod', mod, '--type', 'world_profiles']);
  assertStatus(result, 0, 'list drafts');
  const json = mustJson(result, 'list drafts');
  const rows = listRows(json, 'list drafts');
  assert.equal(rows.length, 1);
  assert.equal(rows[0].id, 'test_mod:world_profile/first_world');
  assert.equal(rows[0].type, 'world_profiles');
  assert.equal(rows[0].file, 'content/world_profiles.json');
  assert.equal(rows[0].name_zh, '首个世界');
});

test('set on a draft definition keeps the 2.0 envelope and rewrites one line', (t) => {
  const mod = createMod(t);
  const addResult = jsonRun([
    'add', '--mod', mod, '--type', 'world_profiles', '--id', 'first_world',
    '--name-zh', '首个世界', '--name-en', 'First World',
  ]);
  assertStatus(addResult, 0, 'add draft before set');
  const file = contentFileOfType(mod, 'world_profiles');
  const before = readText(file.abs);
  const result = jsonRun(['set', '--mod', mod, 'test_mod:world_profile/first_world', 'data.region_count=5']);
  const json = mustJson(result, 'set draft');
  assertStatus(result, 0, 'set draft');
  assert.equal(json.ok, true);
  assert.equal(json.issues.newErrors, 0);
  const after = readText(file.abs);
  assert.equal(changedLineIndexes(before, after).length, 1, 'set must touch exactly one line');
  const payload = JSON.parse(after);
  assert.equal(payload.schema_version, '2.0');
  assert.equal(payload.definitions[0].data.region_count, 5);
  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate after set draft');
  assert.equal(mustJson(validateResult, 'validate after set draft').issues.errors, 0);
});

test('set updates weapon data and keeps the 2.0 envelope and one-line diff', (t) => {
  const mod = createMod(t);
  const addResult = jsonRun([
    'add', '--mod', mod, '--type', 'weapons', '--id', 'deck_gun',
    '--name-zh', '甲板速射炮', '--name-en', 'Deck Rapid Gun',
  ]);
  assertStatus(addResult, 0, 'add weapon before set');
  const file = contentFileOfType(mod, 'weapons');
  const before = readText(file.abs);
  const result = jsonRun(['set', '--mod', mod, 'test_mod:weapon/deck_gun', 'data.damage=24']);
  const json = mustJson(result, 'set weapon');
  assertStatus(result, 0, 'set weapon');
  assert.equal(json.ok, true);
  assert.equal(json.issues.newErrors, 0);
  const after = readText(file.abs);
  assert.equal(changedLineIndexes(before, after).length, 1, 'set must touch exactly one line');
  const payload = JSON.parse(after);
  assert.equal(payload.schema_version, '2.0');
  assert.equal(payload.definitions[0].data.damage, 24);
  assert.equal(payload.definitions[0].data.range, 245, 'untouched weapon fields keep their defaults');
  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate after set weapon');
  assert.equal(mustJson(validateResult, 'validate after set weapon').issues.errors, 0);
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

  const ironOre = rows.find((row) => row.id === 'core:item/iron_ore');
  assert.ok(ironOre, 'list must contain core:item/iron_ore');
  assert.equal(ironOre.type, 'items');
  assert.equal(ironOre.file, 'content/items.json');
  assert.equal(ironOre.index, 0);
  assert.equal(ironOre.name_zh, '铁矿石');
  assert.equal(ironOre.name_en, 'Iron Ore');
  assert.equal(ironOre.enabled, true);
  assert.equal(ironOre.keys.name, 'item.core.iron_ore.name');
  assert.equal(ironOre.keys.description, 'item.core.iron_ore.description');

  assert.deepEqual(snapshotDir(coreDir, { onlyJson: true }), before, 'list must not modify dev_mods/core');
});

test('list --type items filters core rows down to item definitions', (t) => {
  const result = jsonRun(['list', '--mod', 'dev_mods/core', '--type', 'items']);
  assertStatus(result, 0, 'list core items');
  const json = mustJson(result, 'list core items');
  assert.equal(json.ok, true);
  const rows = listRows(json, 'list core items');
  assert.equal(rows.length, 12, 'core currently has 12 items definitions (9 trade goods + 3 crafting materials)');
  for (const row of rows) {
    assert.equal(row.type, 'items');
    assert.equal(row.file, 'content/items.json');
  }
  assert.ok(rows.some((row) => row.id === 'core:item/coal'));
  assert.ok(rows.some((row) => row.id === 'core:item/boiler_plate'), 'C2 merged the crafting materials into items');
});

/* ------------------------------------------------------------------------- */
/* 2. new                                                                    */
/* ------------------------------------------------------------------------- */

test('new --json creates a valid mod (manifest, content, both locales) that validates cleanly', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'brand_new_mod');
  const result = jsonRun(['new', '--mod', mod, '--id', 'my_mod', '--name', '我的模组', '--template', 'items', '--description', '测试用模组']);
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
  assert.ok(fs.existsSync(path.join(mod, ITEMS_FILE)), 'content/items.json must exist');
  assert.ok(fs.existsSync(path.join(mod, 'localization', 'zh_CN.json')), 'zh_CN.json must exist');
  assert.ok(fs.existsSync(path.join(mod, 'localization', 'en.json')), 'en.json must exist');

  const manifest = manifestOf(mod);
  assert.equal(manifest.id, 'my_mod');
  assert.equal(manifest.name, '我的模组');
  assert.equal(manifest.version, '1.0.0');
  assert.equal(manifest.type, 'content');
  assert.equal(manifest.description, '测试用模组');
  assert.deepEqual(manifest.content, [ITEMS_FILE]);
  assert.deepEqual(manifest.localization, ['localization/zh_CN.json', 'localization/en.json']);
  assert.ok(
    Array.isArray(manifest.dependencies) && manifest.dependencies.some((dependency) => dependency.id === 'core'),
    `new mod must depend on core: ${JSON.stringify(manifest.dependencies)}`
  );

  const items = itemsFileOf(mod);
  assert.equal(items.payload.schema_version, '2.0');
  assert.equal(items.payload.content_type, 'items');
  assert.equal(items.payload.definitions.length, 1);
  const tea = items.payload.definitions[0];
  assert.equal(tea.id, 'my_mod:item/tea');
  assert.equal(tea.name_key, 'item.my_mod.tea.name');
  assert.equal(tea.description_key, 'item.my_mod.tea.description');
  assert.equal(tea.data.crafting_material, false, 'the starter item is a pure trade item');

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['item.my_mod.tea.name'], '茶叶');
  assert.equal(en['item.my_mod.tea.name'], 'Tea');
  assert.equal(typeof json.stats.definitions, 'number');
  assert.equal(json.stats.definitions, 1);

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate after new');
  const validateJson = mustJson(validateResult, 'validate after new');
  assert.equal(validateJson.ok, true);
  assert.equal(validateJson.issues.errors, 0, `new mod must validate with 0 errors: ${JSON.stringify(validateJson.issues.list)}`);
});

test('new --draft weapons creates a pure Schema 2.0 draft project', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'weapon_mod');
  const result = jsonRun([
    'new', '--mod', mod, '--id', 'weapon_mod', '--name', '武器包', '--draft', 'weapons',
  ]);
  const json = mustJson(result, 'new --draft weapons');
  assertStatus(result, 0, 'new --draft weapons');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'new');

  // Pure draft project: manifest + one 2.0 content file + two locales, no 1.0 starter.
  const changedPaths = json.changes.map((change) => change.path).sort();
  assert.deepEqual(changedPaths, [
    'content/weapons.json',
    'localization/en.json',
    'localization/zh_CN.json',
    'manifest.json',
  ]);
  for (const change of json.changes) {
    assert.equal(change.action, 'create', `new --draft change must be create: ${JSON.stringify(change)}`);
  }
  assert.ok(!fs.existsSync(path.join(mod, ITEMS_FILE)), 'pure draft projects must not create content/items.json');
  assert.deepEqual(manifestOf(mod).content, ['content/weapons.json'], 'only the draft content file is declared');
  assert.deepEqual(manifestOf(mod).localization, ['localization/zh_CN.json', 'localization/en.json']);
  assert.deepEqual(manifestOf(mod).capabilities, ['content.combat.v1'], 'the weapons capability is declared automatically');

  const file = contentFileOfType(mod, 'weapons');
  assert.equal(file.payload.schema_version, '2.0');
  assert.equal(file.payload.content_type, 'weapons');
  assert.equal(file.payload.definitions.length, 1, 'exactly one starter definition is written');
  const definition = file.payload.definitions[0];
  assert.equal(definition.id, 'weapon_mod:weapon/weapon_starter');
  assert.equal(definition.name_key, 'weapon.weapon_mod.weapon_starter.name');
  assert.equal(definition.enabled, true);
  assert.equal(definition.data.kind, 'direct', 'the starter uses the weapons draft defaults');
  assert.equal(definition.data.weapon_class, 'Light');
  assert.equal(definition.data.damage, 12);
  assert.ok(localeOf(mod, 'zh_CN')['weapon.weapon_mod.weapon_starter.name'], 'zh_CN has the starter name');
  assert.equal(localeOf(mod, 'en')['weapon.weapon_mod.weapon_starter.name'], 'Starter Weapons');
  assert.equal(json.stats.definitions, 1);
  assert.equal(json.stats.contentFiles, 1);
  assert.equal(json.stats.locales, 2);

  // Only draft_content warns: the capability is already in the manifest.
  assert.equal(json.issues.errors, 0, `pure draft project must have no errors: ${JSON.stringify(json.issues.list)}`);
  assert.deepEqual(
    json.issues.list.map((issue) => issue.code),
    ['draft_content'],
    `only draft_content may warn: ${JSON.stringify(json.issues.list)}`
  );

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate pure draft project');
  const validateJson = mustJson(validateResult, 'validate pure draft project');
  assert.equal(validateJson.issues.errors, 0, `pure draft project validates with 0 errors: ${JSON.stringify(validateJson.issues.list)}`);
  assert.deepEqual(
    validateJson.issues.list.map((issue) => issue.code),
    ['draft_content'],
    `capability_undeclared must not fire for --draft projects: ${JSON.stringify(validateJson.issues.list)}`
  );
});

test('new --draft rejects promoted runtime types and only offers real drafts', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'world_mod');
  const result = jsonRun([
    'new', '--mod', mod, '--id', 'world_mod', '--name', 'World Mod',
    '--draft', 'world_profiles',
  ]);
  const json = assertUsageError(result, 'new --draft world_profiles');
  assert.equal(json.command, 'new');
  assert.match(String(json.error.message), /未知 Schema 2\.0 草案类型/, `promoted types are no longer drafts: ${json.error.message}`);
  assert.ok(String(json.error.message).includes('weapons'), 'the usage error lists weapons as a draft');
  assert.ok(String(json.error.message).includes('story_arcs'), 'the usage error lists the Story Mode drafts');
  assert.ok(!fs.existsSync(mod), 'a rejected new must not create the target directory');
});

test('new --draft story_arcs --draft story_levels creates a pure story pack', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'story_mod');
  const result = jsonRun([
    'new', '--mod', mod, '--id', 'story_mod', '--name', 'Story Mod',
    '--draft', 'story_arcs', '--draft', 'story_levels',
  ]);
  const json = mustJson(result, 'new --draft story pack');
  assertStatus(result, 0, 'new --draft story pack');
  assert.deepEqual(manifestOf(mod).content, ['content/story_arcs.json', 'content/story_levels.json']);
  assert.deepEqual(manifestOf(mod).capabilities, ['content.story.v1']);
  assert.equal(contentFileOfType(mod, 'story_arcs').payload.schema_version, '2.0');
  assert.equal(contentFileOfType(mod, 'story_levels').payload.schema_version, '2.0');
  assert.equal(contentFileOfType(mod, 'story_levels').payload.definitions[0].data.map.fixed.ports.length, 2);
  assert.equal(json.issues.errors, 0, `a fresh story pack must have no errors: ${JSON.stringify(json.issues.list)}`);
  const codes = new Set(json.issues.list.map((issue) => issue.code));
  assert.ok(codes.has('draft_content'));
  assert.ok(codes.has('story_arc_empty_levels'), 'an arc with no levels warns instead of failing');
  assert.ok(codes.has('story_level_orphan'), 'a level not yet listed by the arc warns instead of failing');

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate fresh story pack');
  assert.equal(mustJson(validateResult, 'validate fresh story pack').issues.errors, 0);
});

test('new --draft rejects unknown draft types with a usage error listing the available drafts', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'bad_draft_mod');
  const result = jsonRun([
    'new', '--mod', mod, '--id', 'bad_draft_mod', '--name', 'Bad Draft', '--draft', 'nope',
  ]);
  const json = assertUsageError(result, 'new unknown draft');
  assert.equal(json.command, 'new');
  assert.match(String(json.error.message), /未知 Schema 2\.0 草案类型/, `usage error must name the problem: ${json.error.message}`);
  const manifest = readJson(path.join(repoRoot, 'content_types.json'));
  for (const entry of manifest.draft_types) {
    assert.ok(
      String(json.error.message).includes(entry.key),
      `usage error must list available draft type ${entry.key}: ${json.error.message}`
    );
  }
  assert.ok(!fs.existsSync(mod), 'a rejected new must not create the target directory');
});

test('new --template items --draft weapons layers 2.0 template and draft content', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'mix_mod');
  const result = jsonRun([
    'new', '--mod', mod, '--id', 'mix_mod', '--name', 'Mix Mod',
    '--template', 'items', '--draft', 'weapons',
  ]);
  const json = mustJson(result, 'new template + draft');
  assertStatus(result, 0, 'new template + draft');
  assert.equal(json.ok, true);
  assert.deepEqual(
    manifestOf(mod).content,
    ['content/items.json', 'content/weapons.json'],
    'template content and draft content coexist'
  );
  assert.deepEqual(manifestOf(mod).capabilities, ['content.combat.v1']);
  assert.equal(contentFileOfType(mod, 'items').payload.schema_version, '2.0', 'merged items content is 2.0');
  assert.equal(contentFileOfType(mod, 'weapons').payload.schema_version, '2.0', 'draft content is 2.0');
  assert.equal(json.stats.contentFiles, 2);
  assert.equal(json.stats.definitions, 2);
  assert.equal(json.issues.errors, 0, JSON.stringify(json.issues.list));
  assert.deepEqual(
    json.issues.list.map((issue) => issue.code).sort(),
    ['capability_undeclared', 'draft_content'],
    'the undeclared items capability and the weapons draft both warn'
  );

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate template + draft project');
  assert.equal(mustJson(validateResult, 'validate template + draft project').issues.errors, 0);
});

test('new --draft --dry-run reports would-create changes and writes nothing', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'dry_draft_mod');
  const result = jsonRun([
    'new', '--mod', mod, '--id', 'dry_draft_mod', '--name', 'Dry Draft',
    '--draft', 'weapons', '--dry-run',
  ]);
  const json = mustJson(result, 'new --draft --dry-run');
  assertStatus(result, 0, 'new --draft --dry-run');
  assert.equal(json.ok, true);
  assert.ok(Array.isArray(json.changes) && json.changes.length > 0, 'dry-run must report planned changes');
  for (const change of json.changes) {
    assert.equal(change.action, 'would-create', `dry-run change action must be would-create: ${JSON.stringify(change)}`);
  }
  assert.ok(
    json.changes.some((change) => change.path === 'content/weapons.json'),
    `dry-run must plan content/weapons.json: ${JSON.stringify(json.changes.map((change) => change.path))}`
  );
  assert.ok(!fs.existsSync(mod), '--dry-run must not create the target directory');
});

test('new --template weapons creates the five-weapon draft pack', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'weapon_pack');
  const result = jsonRun([
    'new', '--mod', mod, '--id', 'weapon_pack', '--name', '武器包', '--template', 'weapons',
  ]);
  const json = mustJson(result, 'new --template weapons');
  assertStatus(result, 0, 'new --template weapons');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'new');
  assert.deepEqual(
    json.changes.map((change) => change.path).sort(),
    ['content/weapons.json', 'localization/en.json', 'localization/zh_CN.json', 'manifest.json'],
    'the weapons template only creates the draft content file plus manifest and locales'
  );
  for (const change of json.changes) {
    assert.equal(change.action, 'create', `weapons template change must be create: ${JSON.stringify(change)}`);
  }
  assert.ok(!fs.existsSync(path.join(mod, ITEMS_FILE)), 'the weapons template must not create items content');

  const manifest = manifestOf(mod);
  assert.deepEqual(manifest.content, ['content/weapons.json']);
  assert.deepEqual(manifest.capabilities, ['content.combat.v1']);
  assert.deepEqual(manifest.localization, ['localization/zh_CN.json', 'localization/en.json']);

  const file = contentFileOfType(mod, 'weapons');
  assert.equal(file.payload.schema_version, '2.0');
  assert.equal(file.payload.content_type, 'weapons');
  assert.equal(file.payload.definitions.length, 5, 'the template ships the five simulator weapons');
  const expected = [
    { localId: 'deck_gun', model: 'model.weapon.deck_gun', kind: 'direct', damage: 12, range: 245, cooldown: 1.65, salvo: 1 },
    { localId: 'heavy_cannon', model: 'model.weapon.heavy_cannon', kind: 'direct', damage: 30, range: 355, cooldown: 4.2, salvo: 1 },
    { localId: 'mortar', model: 'model.weapon.mortar', kind: 'artillery', damage: 24, range: 430, cooldown: 5.1, salvo: 1 },
    { localId: 'repeater', model: 'model.weapon.repeater', kind: 'direct', damage: 7, range: 185, cooldown: 0.72, salvo: 1 },
    { localId: 'broadside', model: 'model.weapon.broadside', kind: 'broadside', damage: 8, range: 285, cooldown: 5.4, salvo: 4 },
  ];
  assert.deepEqual(
    file.payload.definitions.map((definition) => definition.id),
    expected.map((weapon) => `weapon_pack:weapon/${weapon.localId}`),
    'definitions keep the battle simulator order'
  );
  for (let index = 0; index < expected.length; index += 1) {
    const weapon = expected[index];
    const definition = file.payload.definitions[index];
    assert.equal(definition.name_key, `weapon.weapon_pack.${weapon.localId}.name`);
    assert.equal(definition.description_key, `weapon.weapon_pack.${weapon.localId}.description`);
    assert.deepEqual(definition.information, { model: `asset://core/${weapon.model}` }, `${weapon.localId} uses the Core model key`);
    for (const field of ['kind', 'damage', 'range', 'cooldown', 'salvo']) {
      assert.equal(definition.data[field], weapon[field], `${weapon.localId}.data.${field}`);
    }
  }

  for (const locale of ['zh_CN', 'en']) {
    const entries = localeOf(mod, locale);
    for (const weapon of expected) {
      assert.ok(entries[`weapon.weapon_pack.${weapon.localId}.name`], `${locale} name for ${weapon.localId}`);
      assert.ok(entries[`weapon.weapon_pack.${weapon.localId}.description`], `${locale} description for ${weapon.localId}`);
    }
  }
  assert.equal(json.stats.definitions, 5);
  assert.equal(json.stats.contentFiles, 1);
  assert.equal(json.stats.locales, 2);
  assert.equal(json.issues.errors, 0, JSON.stringify(json.issues.list));
  assert.deepEqual(json.issues.list.map((issue) => issue.code), ['draft_content']);

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate weapons template project');
  const validateJson = mustJson(validateResult, 'validate weapons template project');
  assert.equal(validateJson.issues.errors, 0, JSON.stringify(validateJson.issues.list));
  assert.deepEqual(validateJson.issues.list.map((issue) => issue.code), ['draft_content']);
  assert.ok(!validateJson.issues.list.some((issue) => issue.code === 'capability_undeclared'));
  assert.ok(!validateJson.issues.list.some((issue) => issue.code === 'entity_model_missing'));
});

test('new --template nope rejects unknown templates and lists weapons among the options', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'bad_template_mod');
  const result = jsonRun([
    'new', '--mod', mod, '--id', 'bad_template_mod', '--name', 'Bad Template', '--template', 'nope',
  ]);
  const json = assertUsageError(result, 'new unknown template');
  assert.equal(json.command, 'new');
  assert.match(String(json.error.message), /未知模板/, `usage error must name the problem: ${json.error.message}`);
  assert.ok(
    String(json.error.message).includes('weapons'),
    `available templates must include weapons: ${json.error.message}`
  );
  assert.ok(!fs.existsSync(mod), 'a rejected new must not create the target directory');
});

test('new refuses a non-empty target directory without --force and writes nothing', (t) => {
  const root = tempRoot(t);
  const mod = path.join(root, 'occupied');
  fs.mkdirSync(mod);
  const marker = path.join(mod, 'keep.txt');
  fs.writeFileSync(marker, 'keep me\n', 'utf8');
  const before = snapshotDir(mod);

  const result = jsonRun(['new', '--mod', mod, '--id', 'my_mod', '--name', '我的模组', '--template', 'items']);
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
  const result = jsonRun(['add', '--mod', mod, '--type', 'items', '--name-zh', '甲', '--name-en', 'A']);
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
  const result = jsonRun(['add', '--mod', mod, '--type', 'items', '--id', 'only_zh', '--name-zh', '只有中文']);
  assertUsageError(result, 'add missing name-en');
  assertDirUnchanged(before, mod, 'add missing name-en');
});

test('add requires --desc-zh and --desc-en together', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'only_desc_zh',
    '--name-zh', '双语名', '--name-en', 'Bilingual', '--desc-zh', '只有中文描述',
  ]);
  assertUsageError(result, 'add missing desc-en');
  assertDirUnchanged(before, mod, 'add missing desc-en');
});

test('add writes the definition with tags/data and both bilingual localization files', (t) => {
  const mod = createMod(t);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'black_tea',
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
  assert.ok(changedPaths.includes(ITEMS_FILE), `changes must mention ${ITEMS_FILE}: ${JSON.stringify(changedPaths)}`);
  assert.ok(changedPaths.includes('localization/zh_CN.json'), `changes must mention zh_CN.json: ${JSON.stringify(changedPaths)}`);
  assert.ok(changedPaths.includes('localization/en.json'), `changes must mention en.json: ${JSON.stringify(changedPaths)}`);
  for (const change of json.changes) {
    assert.ok(['create', 'update', 'delete'].includes(change.action), `unexpected change action ${change.action}`);
  }

  const found = definitionById(mod, 'test_mod:item/black_tea');
  assert.equal(found.file, ITEMS_FILE);
  const definition = found.definition;
  assert.equal(definition.name_key, 'item.test_mod.black_tea.name');
  assert.equal(definition.description_key, 'item.test_mod.black_tea.description');
  assert.deepEqual(definition.tags, ['good.trade']);
  assert.equal(definition.enabled, true);
  assert.equal(definition.data.base_price, 80);
  assert.equal(definition.data.unit_weight, 1.5);
  assert.equal(definition.data.base_stock, 80, 'unspecified data fields keep catalog defaults');
  assert.equal(definition.data.category, 'trade');

  const goods = itemsFileOf(mod);
  assert.equal(goods.payload.definitions.length, 2);
  assert.equal(goods.payload.definitions[1].id, 'test_mod:item/black_tea', 'new definition is appended at the end');

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['item.test_mod.black_tea.name'], '红茶');
  assert.equal(zh['item.test_mod.black_tea.description'], '醇厚的红茶。');
  assert.equal(en['item.test_mod.black_tea.name'], 'Black Tea');
  assert.equal(en['item.test_mod.black_tea.description'], 'A malty black tea.');
  // The pre-existing template definition keeps its translations.
  assert.equal(zh['item.test_mod.tea.name'], '茶叶');
  assert.equal(en['item.test_mod.tea.name'], 'Tea');
});

test('add rejects a duplicate local id with conflict (exit 1) and leaves files untouched', (t) => {
  const mod = createMod(t);
  addItem(mod, 'dup_good');
  const before = snapshotDir(mod);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'dup_good',
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
  // "tea" already exists as the template definition test_mod:item/tea.
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'tea', '--suffix',
    '--name-zh', '第二份茶叶', '--name-en', 'Second Tea',
  ]);
  const json = mustJson(result, 'add --suffix');
  assertStatus(result, 0, 'add --suffix');
  assert.equal(json.ok, true);
  assert.equal(json.stats.definitions, 2);
  const ids = itemsFileOf(mod).payload.definitions.map((definition) => definition.id);
  assert.deepEqual(ids, ['test_mod:item/tea', 'test_mod:item/tea_2']);
  const zh = localeOf(mod, 'zh_CN');
  assert.equal(zh['item.test_mod.tea_2.name'], '第二份茶叶');
});

test('add --data-json is deep-merged and --data wins on conflicting paths', (t) => {
  const mod = createMod(t);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'merged_good',
    '--name-zh', '合并', '--name-en', 'Merged',
    '--data-json', '{"base_price":200,"base_stock":7,"category":"ore"}',
    '--data', 'data.base_price=300',
    '--data', 'data.spawn_weight=0.5',
    '--data', 'data.crafting_material=true',
  ]);
  const json = mustJson(result, 'add data merge');
  assertStatus(result, 0, 'add data merge');
  assert.equal(json.ok, true);
  const definition = definitionById(mod, 'test_mod:item/merged_good').definition;
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
    'add', '--mod', mod, '--type', 'items', '--id', 'from_file',
    '--name-zh', '来自文件', '--name-en', 'From File',
    '--data-json', `@${dataFile}`,
  ]);
  const json = mustJson(result, 'add @file');
  assertStatus(result, 0, 'add @file');
  assert.equal(json.ok, true);
  const definition = definitionById(mod, 'test_mod:item/from_file').definition;
  assert.equal(definition.data.base_price, 210);
  assert.equal(definition.data.base_stock, 9);
  assert.equal(definition.data.category, 'craft');
});

test('add --dry-run reports would-* changes and writes no file', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'dry_good',
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
  const goodsChange = json.changes.find((change) => change.path === ITEMS_FILE);
  assert.ok(goodsChange, `dry-run must list ${ITEMS_FILE}`);
  assert.equal(goodsChange.action, 'would-update');
  assert.equal(typeof goodsChange.diff, 'string', 'dry-run change must include a unified diff string');
  assert.match(goodsChange.diff, /^\+/m, 'dry-run diff must contain added lines');
  assert.ok(goodsChange.diff.includes('dry_good'), `dry-run diff must contain the new definition: ${goodsChange.diff}`);
  assert.deepEqual(snapshotDir(mod), before, '--dry-run must not write any file');
});

test('add keeps a minimal diff: old definitions and localization lines are untouched', (t) => {
  const mod = createMod(t);
  const goodsBefore = readText(itemsFileOf(mod).abs);
  const zhBefore = readText(path.join(mod, 'localization', 'zh_CN.json'));
  const enBefore = readText(path.join(mod, 'localization', 'en.json'));
  const oldSlices = extractDefinitionSlices(goodsBefore);
  assert.equal(oldSlices.length, 1);

  addItem(mod, 'minimal_diff');

  const goodsAfter = readText(itemsFileOf(mod).abs);
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
  assert.ok(zhAfter.includes('"item.test_mod.minimal_diff.name": "minimal_diff 中文名"'), 'zh key added verbatim');
  assert.ok(enAfter.includes('"item.test_mod.minimal_diff.name": "minimal_diff English Name"'), 'en key added verbatim');
});

test('add blocks new validation errors (exit 1) and writes nothing', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  // good.schema.json requires data.unit_weight >= 1.
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'bad_weight',
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
  const goods = itemsFileOf(mod);
  const before = readText(goods.abs);
  const localeBefore = snapshotDir(path.join(mod, 'localization'));

  const result = jsonRun(['set', '--mod', mod, 'test_mod:item/tea', 'data.base_price=123']);
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
  assert.deepEqual(changedPaths, [ITEMS_FILE], `set changes must only mention ${ITEMS_FILE}: ${JSON.stringify(changedPaths)}`);
});

test('set arrays support += append and -= remove-first', (t) => {
  const mod = createMod(t);
  const goods = itemsFileOf(mod);
  const original = readText(goods.abs);

  const addResult = jsonRun(['set', '--mod', mod, 'test_mod:item/tea', 'tags+=good.bulk']);
  assertStatus(addResult, 0, 'set tags+=');
  assert.equal(mustJson(addResult, 'set tags+=').ok, true);
  const afterAdd = readText(goods.abs);
  assert.deepEqual(JSON.parse(afterAdd).definitions[0].tags, ['good.trade', 'good.consumer', 'good.bulk']);
  assert.equal(changedLineIndexes(original, afterAdd).length, 1, 'tags+= must touch only the tags line');

  const removeResult = jsonRun(['set', '--mod', mod, 'test_mod:item/tea', 'tags-=good.trade']);
  assertStatus(removeResult, 0, 'set tags-=');
  assert.equal(mustJson(removeResult, 'set tags-=').ok, true);
  const afterRemove = readText(goods.abs);
  assert.deepEqual(JSON.parse(afterRemove).definitions[0].tags, ['good.consumer', 'good.bulk']);
  assert.equal(changedLineIndexes(afterAdd, afterRemove).length, 1, 'tags-= must touch only the tags line');
});

test('set refuses _key fields with a usage error (exit 2)', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['set', '--mod', mod, 'test_mod:item/tea', 'name_key=item.test_mod.tea.name']);
  assertUsageError(result, 'set _key');
  assert.deepEqual(snapshotDir(mod), before, 'rejected set must not write anything');
});

test('set reports an error for an unknown path and writes nothing', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['set', '--mod', mod, 'test_mod:item/tea', 'data.definitely_missing=1']);
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
  const result = jsonRun(['loc', '--mod', mod, 'test_mod:item/tea', '--field', 'name', '--zh', '特级茶叶', '--en', 'Premium Tea']);
  const json = mustJson(result, 'loc name');
  assertStatus(result, 0, 'loc name');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'loc');

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['item.test_mod.tea.name'], '特级茶叶');
  assert.equal(en['item.test_mod.tea.name'], 'Premium Tea');
  // Description keys are untouched by --field name.
  assert.equal(zh['item.test_mod.tea.description'], zhBefore['item.test_mod.tea.description']);
  assert.equal(en['item.test_mod.tea.description'], enBefore['item.test_mod.tea.description']);
});

test('loc only writes the language that was given', (t) => {
  const mod = createMod(t);
  const enBefore = readJson(path.join(mod, 'localization', 'en.json'));
  const result = jsonRun(['loc', '--mod', mod, 'test_mod:item/tea', '--field', 'description', '--zh', '新的中文描述']);
  assertStatus(result, 0, 'loc zh only');
  assert.equal(mustJson(result, 'loc zh only').ok, true);
  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['item.test_mod.tea.description'], '新的中文描述');
  assert.equal(en['item.test_mod.tea.description'], enBefore['item.test_mod.tea.description'], 'en must keep its value');
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

test('clone --from core:item/iron_ore --id my_ore renames id and keys, and qualifies the core model asset', (t) => {
  const mod = createMod(test, { id: 'clone_mod' });
  const result = jsonRun(['clone', '--mod', mod, '--from', 'core:item/iron_ore', '--id', 'my_ore']);
  const json = mustJson(result, 'clone iron_ore');
  assertStatus(result, 0, 'clone iron_ore');
  assert.equal(json.ok, true);
  assert.equal(json.command, 'clone');
  assert.equal(json.stats.definitions, 2, 'clone adds one definition to the template one');

  const goods = itemsFileOf(mod);
  assert.equal(goods.payload.definitions.length, 2);
  assert.equal(goods.payload.definitions[0].id, 'clone_mod:item/tea', 'existing definition is kept first');
  const cloned = definitionById(mod, 'clone_mod:item/my_ore').definition;
  assert.equal(cloned.name_key, 'item.clone_mod.my_ore.name');
  assert.equal(cloned.description_key, 'item.clone_mod.my_ore.description');
  assert.deepEqual(cloned.tags, ['good.trade', 'good.bulk', 'good.shipbuilding']);
  assert.equal(cloned.data.base_price, 42);
  assert.equal(cloned.data.unit_weight, 3);
  assert.equal(cloned.information.model, 'asset://core/model.good.iron_ore', 'copied core model must be namespaced under asset://core/');

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.ok(zh['item.clone_mod.my_ore.name'], 'zh name key must be migrated to the new base');
  assert.match(zh['item.clone_mod.my_ore.name'], /副本/, 'default clone name keeps a (副本) marker');
  assert.ok(en['item.clone_mod.my_ore.name'], 'en name key must be migrated to the new base');
  assert.match(en['item.clone_mod.my_ore.name'], /\(copy\)/, 'default clone name keeps a (copy) marker');
  for (const key of [...Object.keys(zh), ...Object.keys(en)]) {
    assert.ok(!key.includes('iron_ore_copy'), `no stale clone keys may remain, found ${key}`);
  }
});

test('clone --name-zh/--name-en overrides the default copy names', (t) => {
  const mod = createMod(test, { id: 'clone_mod2' });
  const result = jsonRun([
    'clone', '--mod', mod, '--from', 'core:item/coal', '--id', 'my_coal',
    '--name-zh', '我的煤', '--name-en', 'My Coal',
  ]);
  assertStatus(result, 0, 'clone with names');
  assert.equal(mustJson(result, 'clone with names').ok, true);
  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh['item.clone_mod2.my_coal.name'], '我的煤');
  assert.equal(en['item.clone_mod2.my_coal.name'], 'My Coal');
});

/* ------------------------------------------------------------------------- */
/* 7. rm                                                                     */
/* ------------------------------------------------------------------------- */

test('rm without --yes is a usage error (exit 2) and keeps the mod intact', (t) => {
  const mod = createMod(t);
  const before = snapshotDir(mod);
  const result = jsonRun(['rm', '--mod', mod, 'test_mod:item/tea']);
  assertUsageError(result, 'rm without --yes');
  assert.deepEqual(snapshotDir(mod), before, 'guarded rm must not write anything');
});

test('rm handles the first, middle and last array item without disturbing the others', (t) => {
  const mod = createMod(t);
  addItem(mod, 'item_a');
  addItem(mod, 'item_b');
  addItem(mod, 'item_c');
  const ids = () => itemsFileOf(mod).payload.definitions.map((definition) => definition.id);
  assert.deepEqual(ids(), ['test_mod:item/tea', 'test_mod:item/item_a', 'test_mod:item/item_b', 'test_mod:item/item_c']);

  // first
  let result = jsonRun(['rm', '--mod', mod, 'test_mod:item/tea', '--yes']);
  assertStatus(result, 0, 'rm first');
  assert.equal(mustJson(result, 'rm first').ok, true);
  assert.deepEqual(ids(), ['test_mod:item/item_a', 'test_mod:item/item_b', 'test_mod:item/item_c']);

  // middle
  result = jsonRun(['rm', '--mod', mod, 'test_mod:item/item_b', '--yes']);
  assertStatus(result, 0, 'rm middle');
  assert.equal(mustJson(result, 'rm middle').ok, true);
  assert.deepEqual(ids(), ['test_mod:item/item_a', 'test_mod:item/item_c']);

  // last
  result = jsonRun(['rm', '--mod', mod, 'test_mod:item/item_c', '--yes']);
  assertStatus(result, 0, 'rm last');
  const lastJson = mustJson(result, 'rm last');
  assert.equal(lastJson.ok, true);
  assert.deepEqual(ids(), ['test_mod:item/item_a']);

  // Remaining definition data is intact and the mod still validates.
  assert.equal(definitionById(mod, 'test_mod:item/item_a').definition.data.base_price, 50);
  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate after rm first/middle/last');
  assert.equal(mustJson(validateResult, 'validate after rm').issues.errors, 0);
});

test('rm of the only definition in a content file deletes that file and its manifest entry', (t) => {
  const mod = createMod(test, { template: 'starter_kit' });
  assert.deepEqual(manifestOf(mod).content, [
    'content/items.json',
    'content/modules.json',
    'content/events.json',
    'content/contracts.json',
  ]);
  const otherFilesBefore = {
    'content/modules.json': sha256File(path.join(mod, 'content/modules.json')),
    'content/events.json': sha256File(path.join(mod, 'content/events.json')),
    'content/contracts.json': sha256File(path.join(mod, 'content/contracts.json')),
  };

  const result = jsonRun(['rm', '--mod', mod, 'test_mod:item/tea', '--yes']);
  const json = mustJson(result, 'rm unique item');
  assertStatus(result, 0, 'rm unique item');
  assert.equal(json.ok, true);

  assert.ok(!fs.existsSync(path.join(mod, 'content', 'items.json')), 'emptied content file must be deleted');
  assert.deepEqual(manifestOf(mod).content, [
    'content/modules.json',
    'content/events.json',
    'content/contracts.json',
  ], 'manifest.content must drop the deleted file');
  for (const [rel, hash] of Object.entries(otherFilesBefore)) {
    assert.equal(sha256File(path.join(mod, rel)), hash, `${rel} must be untouched`);
  }
  const zh = localeOf(mod, 'zh_CN');
  assert.ok(!('item.test_mod.tea.name' in zh), 'exclusive localization keys of the removed definition must be deleted');
  assert.ok(!('item.test_mod.tea.description' in zh));

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate after rm unique item');
  assert.equal(mustJson(validateResult, 'validate after rm unique item').issues.errors, 0);
});

test('rm deletes exclusive localization keys but keeps keys shared with remaining definitions', (t) => {
  const mod = createMod(t);
  addItem(mod, 'item_a');
  addItem(mod, 'item_b');

  // Make item_b's name key shared: item_a now uses it as its description key.
  const goodsFile = itemsFileOf(mod);
  const payload = readJson(goodsFile.abs);
  const defA = payload.definitions.find((definition) => definition.id === 'test_mod:item/item_a');
  const defB = payload.definitions.find((definition) => definition.id === 'test_mod:item/item_b');
  assert.ok(defA && defB);
  const sharedKey = defB.name_key;
  const exclusiveKey = defB.description_key;
  defA.description_key = sharedKey;
  writeJson(goodsFile.abs, payload);

  const zhBefore = localeOf(mod, 'zh_CN');
  const sharedValue = zhBefore[sharedKey];
  assert.ok(sharedValue, `fixture expected ${sharedKey} to exist`);

  const result = jsonRun(['rm', '--mod', mod, 'test_mod:item/item_b', '--yes']);
  const json = mustJson(result, 'rm shared keys');
  assertStatus(result, 0, 'rm shared keys');
  assert.equal(json.ok, true);

  const zh = localeOf(mod, 'zh_CN');
  const en = localeOf(mod, 'en');
  assert.equal(zh[sharedKey], sharedValue, 'shared key must be retained with its value');
  assert.ok(!(exclusiveKey in zh), 'exclusive key must be deleted from zh_CN');
  assert.ok(!(exclusiveKey in en), 'exclusive key must be deleted from en');
  assert.ok(zh['item.test_mod.item_a.name'], 'remaining definition translations must survive');
  const ids = itemsFileOf(mod).payload.definitions.map((definition) => definition.id);
  assert.deepEqual(ids, ['test_mod:item/tea', 'test_mod:item/item_a']);
});

test('add then rm restores the content file byte-for-byte', (t) => {
  const mod = createMod(t);
  const goodsRel = itemsFileOf(mod).rel;
  const goodsBytesBefore = fs.readFileSync(path.join(mod, goodsRel));
  const manifestBytesBefore = fs.readFileSync(path.join(mod, 'manifest.json'));
  const zhBefore = localeOf(mod, 'zh_CN');
  const enBefore = localeOf(mod, 'en');

  addItem(mod, 'temporary_good');
  assert.notDeepEqual(fs.readFileSync(path.join(mod, goodsRel)), goodsBytesBefore, 'add must actually change the content file');

  const result = jsonRun(['rm', '--mod', mod, 'test_mod:item/temporary_good', '--yes']);
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
  const goods = itemsFileOf(mod);

  // Regression: parseSource must accept a leading U+FEFF, keep source offsets
  // anchored to the original text, and therefore preserve the BOM on writes.
  const bom = Buffer.from([0xef, 0xbb, 0xbf]);
  const bomBytesBefore = Buffer.concat([bom, fs.readFileSync(goods.abs)]);
  fs.writeFileSync(goods.abs, bomBytesBefore);
  assert.equal(fs.readFileSync(goods.abs).subarray(0, 3).toString('hex'), 'efbbbf', 'fixture must start with a UTF-8 BOM');

  const addResult = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'bom_good',
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
    afterAddPayload.definitions.some((definition) => definition.id === 'test_mod:item/bom_good'),
    'the added definition must be present in the BOM-prefixed file'
  );

  const validateResult = jsonRun(['validate', '--mod', mod]);
  assertStatus(validateResult, 0, 'validate with BOM');
  const validateJson = mustJson(validateResult, 'validate with BOM');
  assert.equal(validateJson.issues.errors, 0, `a BOM-prefixed mod must validate with 0 errors: ${JSON.stringify(validateJson.issues.list)}`);

  const rmResult = jsonRun(['rm', '--mod', mod, 'test_mod:item/bom_good', '--yes']);
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
  addItem(mod, 'json_failure');
  const result = jsonRun([
    'add', '--mod', mod, '--type', 'items', '--id', 'json_failure',
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
