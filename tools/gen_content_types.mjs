#!/usr/bin/env node
// Generate framework ContentTypes and the editor's content type catalog from
// content_types.json.
//
//   node tools/gen_content_types.mjs
//   node tools/gen_content_types.mjs --check
//
// Content Schema 2.0 draft types (content_types.json "draft_types") are
// exported to the Mod Maker only; the framework loads active types, which are
// all Content Schema 2.0 after C4. The manifest is the single source; the
// generated files must not be edited by hand. --check exits with 1 when a
// generated file is missing or stale.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MANIFEST = path.join(ROOT, 'content_types.json');
const GD_OUTPUT = 'framework/modding/content_types.gd';
const JS_OUTPUT = 'SNModMaker/js/content-types.js';
const CHECK = process.argv.includes('--check');

function fail(message) {
  console.error(`[gen-content-types] ${message}`);
  process.exit(1);
}

function readJson(relativePath) {
  try {
    return JSON.parse(fs.readFileSync(path.join(ROOT, relativePath), 'utf8'));
  } catch (error) {
    fail(`cannot read ${relativePath}: ${error.message}`);
  }
}

/**
 * A content schema pins its version with `const` (C4 后所有 active 与草案
 * Schema 均为 Schema 2.0)；单值 `enum` 仅作兼容容忍。Both must yield one
 * string, which is what `content_types.json` has to mirror per type.
 */
function schemaVersionFromSchema(versionField) {
  if (!versionField || typeof versionField !== 'object') return '';
  if (typeof versionField.const === 'string' && versionField.const) return versionField.const;
  if (Array.isArray(versionField.enum) && versionField.enum.length === 1) {
    const only = versionField.enum[0];
    if (typeof only === 'string' && only) return only;
  }
  return '';
}

function readManifest() {
  let data;
  try {
    data = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
  } catch (error) {
    fail(`cannot read content_types.json: ${error.message}`);
  }
  if (data.format !== 'steam-navigator-content-types' || data.format_version !== 1) {
    fail('content_types.json has an unsupported format');
  }
  if (!Array.isArray(data.types) || !data.types.length) fail('content_types.json has no types');
  if (!Array.isArray(data.groups) || !data.groups.length) fail('content_types.json has no groups');
  return data;
}

function validate(data) {
  const groupIds = new Set();
  for (const group of data.groups) {
    if (!group.id || !group.label_zh) fail(`invalid group: ${JSON.stringify(group)}`);
    if (groupIds.has(group.id)) fail(`duplicate group id: ${group.id}`);
    groupIds.add(group.id);
  }
  const categoryIds = new Set();
  for (const category of data.v2_module_categories || []) {
    if (!category.id) fail(`invalid v2 module category: ${JSON.stringify(category)}`);
    if (categoryIds.has(category.id)) fail(`duplicate v2 module category: ${category.id}`);
    categoryIds.add(category.id);
  }
  const keys = new Set();
  const singulars = new Set();
  const schemas = new Set();
  let patches = 0;
  for (const type of data.types) {
    for (const field of ['key', 'singular', 'label_zh', 'label_en', 'group', 'schema', 'default_file', 'kind', 'capability']) {
      if (!type[field]) fail(`type ${type.key || '?'} is missing ${field}`);
    }
    if (keys.has(type.key)) fail(`duplicate type key: ${type.key}`);
    if (singulars.has(type.singular)) fail(`duplicate singular: ${type.singular}`);
    if (schemas.has(type.schema)) fail(`duplicate schema path: ${type.schema}`);
    if (!groupIds.has(type.group)) fail(`type ${type.key} references unknown group ${type.group}`);
    if (type.v2_category && !categoryIds.has(type.v2_category)) {
      fail(`type ${type.key} references unknown v2 module category ${type.v2_category}`);
    }
    if (!fs.existsSync(path.join(ROOT, type.schema))) fail(`schema file is missing: ${type.schema}`);
    if (!type.schema_version) fail(`type ${type.key} is missing schema_version`);
    const declaredSchemaVersion = schemaVersionFromSchema(readJson(type.schema).properties?.schema_version);
    if (!declaredSchemaVersion) {
      fail(`schema ${type.schema} does not pin properties.schema_version (const or single-value enum)`);
    }
    if (declaredSchemaVersion !== type.schema_version) {
      fail(`type ${type.key} schema_version ${type.schema_version} does not match ${type.schema} (${declaredSchemaVersion})`);
    }
    if (!Array.isArray(type.aliases)) fail(`type ${type.key} aliases must be an array`);
    if (type.v2_target != null && typeof type.v2_target !== 'string') fail(`type ${type.key} v2_target must be a string or null`);
    if (type.kind === 'patch') patches += 1;
    if (typeof type.module !== 'boolean') fail(`type ${type.key} must declare module: true/false`);
    keys.add(type.key);
    singulars.add(type.singular);
    schemas.add(type.schema);
  }
  if (patches !== 1) fail(`expected exactly one patch type, found ${patches}`);
  const plannedTypes = new Map();
  for (const system of data.planned || []) {
    if (!system.system || !system.capability || !Array.isArray(system.types)) fail('invalid planned system entry');
    for (const plannedType of system.types) {
      if (keys.has(plannedType)) fail(`planned type shadows active type: ${plannedType}`);
      if (plannedTypes.has(plannedType)) fail(`planned type is listed twice: ${plannedType}`);
      plannedTypes.set(plannedType, system.capability);
    }
  }
  validateDraftTypes(data, { keys, singulars, groupIds, plannedTypes });
}

/**
 * Content Schema 2.0 draft types are editor-only metadata; their schema path
 * lives in `draft_schemas` and must not be repeated on the type entry.
 */
function validateDraftTypes(data, context) {
  const { keys, singulars, groupIds, plannedTypes } = context;
  const draftSchemas = data.draft_schemas || {};
  const draftSchemaKeys = new Set(Object.keys(draftSchemas));
  const draftTypes = data.draft_types || [];
  if (!Array.isArray(draftTypes)) fail('draft_types must be an array');
  if (draftTypes.length !== draftSchemaKeys.size) {
    fail(`draft_types (${draftTypes.length}) and draft_schemas (${draftSchemaKeys.size}) must describe the same types`);
  }
  const draftKeys = new Set();
  const draftSingulars = new Set();
  const draftAbbrs = new Set();
  const draftColors = new Set();
  const draftFiles = new Set();
  for (const type of draftTypes) {
    for (const field of ['key', 'singular', 'key_prefix', 'label_zh', 'label_en', 'abbr', 'color',
      'group', 'default_file', 'schema_version', 'capability', 'summary_zh']) {
      if (!type[field]) fail(`draft type ${type.key || '?'} is missing ${field}`);
    }
    if (type.schema) fail(`draft type ${type.key} must not declare schema; list it in draft_schemas`);
    if (!draftSchemaKeys.has(type.key)) fail(`draft type ${type.key} has no draft_schemas entry`);
    if (keys.has(type.key)) fail(`draft type key shadows active type: ${type.key}`);
    if (singulars.has(type.singular)) fail(`draft singular shadows active type: ${type.singular}`);
    if (draftKeys.has(type.key)) fail(`duplicate draft type key: ${type.key}`);
    if (draftSingulars.has(type.singular)) fail(`duplicate draft singular: ${type.singular}`);
    if (!groupIds.has(type.group)) fail(`draft type ${type.key} references unknown group ${type.group}`);
    if (draftAbbrs.has(type.abbr)) fail(`duplicate draft abbr: ${type.abbr}`);
    if (draftColors.has(type.color)) fail(`duplicate draft color: ${type.color}`);
    if (draftFiles.has(type.default_file)) fail(`duplicate draft default_file: ${type.default_file}`);
    if (!plannedTypes.has(type.key)) fail(`draft type is not listed in planned: ${type.key}`);
    if (plannedTypes.get(type.key) !== type.capability) {
      fail(`draft type ${type.key} capability ${type.capability} does not match planned system capability ${plannedTypes.get(type.key)}`);
    }
    const schemaPath = draftSchemas[type.key];
    if (!fs.existsSync(path.join(ROOT, schemaPath))) fail(`draft schema file is missing: ${schemaPath}`);
    const schema = readJson(schemaPath);
    const schemaVersion = schemaVersionFromSchema(schema && schema.properties ? schema.properties.schema_version : null);
    if (!schemaVersion) fail(`draft schema ${schemaPath} does not pin properties.schema_version`);
    if (schemaVersion !== type.schema_version) {
      fail(`draft type ${type.key} schema_version ${type.schema_version} does not match ${schemaPath} (${schemaVersion})`);
    }
    draftKeys.add(type.key);
    draftSingulars.add(type.singular);
    draftAbbrs.add(type.abbr);
    draftColors.add(type.color);
    draftFiles.add(type.default_file);
  }
  for (const draftSchemaKey of draftSchemaKeys) {
    if (!draftKeys.has(draftSchemaKey)) fail(`draft_schemas entry has no draft_types metadata: ${draftSchemaKey}`);
  }
}

function constantName(type) {
  return String(type.singular).toUpperCase().replace(/[^A-Z0-9]+/g, '_');
}

function generatedHeader(commentPrefix) {
  return [
    `${commentPrefix} AUTO-GENERATED from content_types.json; do not edit by hand.`,
    `${commentPrefix} Regenerate: node tools/gen_content_types.mjs`,
  ];
}

function renderGd(data) {
  const defs = data.types.filter((type) => type.kind === 'definition');
  const patch = data.types.find((type) => type.kind === 'patch');
  const modules = data.types.filter((type) => type.module);
  const lines = [];
  lines.push('class_name ContentTypes');
  lines.push('extends RefCounted');
  for (const line of generatedHeader('##')) lines.push(line);
  lines.push('##');
  lines.push('## A content file\'s `content_type` selects both its registry and its JSON');
  lines.push('## schema. Framework code never refers to concrete content IDs.');
  lines.push('');
  for (const type of data.types) lines.push(`const ${constantName(type)} := &"${type.key}"`);
  lines.push('');
  lines.push('const SCHEMA_PATHS := {');
  for (const type of data.types) lines.push(`\t${constantName(type)}: "res://${type.schema}",`);
  lines.push('}');
  lines.push('');
  lines.push('const SCHEMA_VERSIONS := {');
  for (const type of data.types) lines.push(`\t${constantName(type)}: "${type.schema_version}",`);
  lines.push('}');
  lines.push('');
  lines.push('const SINGULAR := {');
  for (const type of data.types) lines.push(`\t${constantName(type)}: "${type.singular}",`);
  lines.push('}');
  lines.push('');
  lines.push(`const MODULE_TYPES := [${modules.map((type) => constantName(type)).join(', ')}]`);
  lines.push('');
  lines.push('');
  lines.push('static func all() -> Array[StringName]:');
  lines.push('\tvar types: Array[StringName] = [');
  const allNames = defs.map((type) => constantName(type));
  const rows = [];
  for (let i = 0; i < allNames.length; i += 5) rows.push(allNames.slice(i, i + 5).join(', '));
  for (let i = 0; i < rows.length; i += 1) lines.push(`\t\t${rows[i]}${i + 1 < rows.length ? ',' : ','}`);
  lines.push('\t]');
  lines.push('\treturn types');
  lines.push('');
  lines.push('');
  lines.push('static func registry_types() -> Array[StringName]:');
  lines.push('\tvar types := all()');
  lines.push(`\ttypes.append(${constantName(patch)})`);
  lines.push('\treturn types');
  lines.push('');
  lines.push('');
  lines.push('static func is_known(content_type: StringName) -> bool:');
  lines.push('\treturn SCHEMA_PATHS.has(content_type)');
  lines.push('');
  lines.push('');
  lines.push('static func is_module(content_type: StringName) -> bool:');
  lines.push('\treturn MODULE_TYPES.has(content_type)');
  lines.push('');
  lines.push('');
  lines.push('static func is_patch(content_type: StringName) -> bool:');
  lines.push(`\treturn content_type == ${constantName(patch)}`);
  lines.push('');
  lines.push('');
  lines.push('static func schema_path(content_type: StringName) -> String:');
  lines.push('\treturn String(SCHEMA_PATHS.get(content_type, ""))');
  lines.push('');
  lines.push('');
  lines.push('static func schema_version(content_type: StringName) -> String:');
  lines.push('\treturn String(SCHEMA_VERSIONS.get(content_type, ""))');
  lines.push('');
  lines.push('');
  lines.push('static func singular(content_type: StringName) -> String:');
  lines.push('\treturn String(SINGULAR.get(content_type, ""))');
  lines.push('');
  lines.push('');
  lines.push('static func from_singular(singular_name: String) -> StringName:');
  lines.push('\tfor content_type in SINGULAR.keys():');
  lines.push('\t\tif SINGULAR[content_type] == singular_name:');
  lines.push('\t\t\treturn content_type');
  lines.push('\treturn &""');
  return `${lines.join('\n')}\n`;
}

function renderJs(data) {
  const groupLabel = new Map(data.groups.map((group) => [group.id, group.label_zh]));
  const draftSchemas = data.draft_schemas || {};
  const draftTypes = data.draft_types || [];
  const lines = [];
  lines.push('/*');
  for (const line of generatedHeader(' *')) lines.push(line);
  lines.push(' *');
  lines.push(' * Exposes globalThis.SNContentTypes = { GROUPS, TYPES, DRAFT_TYPES }.');
  lines.push(' */');
  lines.push('(function (root) {');
  lines.push("  'use strict';");
  lines.push('');
  lines.push('  const GROUPS = [');
  for (const group of data.groups) lines.push(`    ${JSON.stringify(group.label_zh)},`);
  lines.push('  ];');
  lines.push('');
  lines.push('  const TYPES = [');
  for (const type of data.types) {
    const schemaKey = String(type.schema).replace(/^schemas[\\/]/, '').replace(/\\/g, '/');
    lines.push('    {');
    lines.push(`      key: ${JSON.stringify(type.key)},`);
    lines.push(`      singular: ${JSON.stringify(type.singular)},`);
    lines.push(`      keyPrefix: ${JSON.stringify(type.key_prefix)},`);
    lines.push(`      label: ${JSON.stringify(type.label_zh)},`);
    lines.push(`      en: ${JSON.stringify(type.label_en)},`);
    lines.push(`      abbr: ${JSON.stringify(type.abbr)},`);
    lines.push(`      color: ${JSON.stringify(type.color)},`);
    lines.push(`      group: ${JSON.stringify(groupLabel.get(type.group))},`);
    lines.push(`      file: ${JSON.stringify(type.default_file)},`);
    lines.push(`      schema: ${JSON.stringify(schemaKey)},`);
    lines.push(`      schemaVersion: ${JSON.stringify(type.schema_version)},`);
    lines.push(`      capability: ${JSON.stringify(type.capability || '')},`);
    lines.push(`      summary: ${JSON.stringify(type.summary_zh)},`);
    if (type.kind === 'patch') lines.push('      special: true,');
    lines.push('    },');
  }
  lines.push('  ];');
  lines.push('');
  lines.push('  const DRAFT_TYPES = [');
  for (const type of draftTypes) {
    const draftSchema = String(draftSchemas[type.key] || '').replace(/^schemas[\\/]/, '').replace(/\\/g, '/');
    lines.push('    {');
    lines.push(`      key: ${JSON.stringify(type.key)},`);
    lines.push(`      singular: ${JSON.stringify(type.singular)},`);
    lines.push(`      keyPrefix: ${JSON.stringify(type.key_prefix)},`);
    lines.push(`      label: ${JSON.stringify(type.label_zh)},`);
    lines.push(`      en: ${JSON.stringify(type.label_en)},`);
    lines.push(`      abbr: ${JSON.stringify(type.abbr)},`);
    lines.push(`      color: ${JSON.stringify(type.color)},`);
    lines.push(`      group: ${JSON.stringify(groupLabel.get(type.group))},`);
    lines.push(`      file: ${JSON.stringify(type.default_file)},`);
    lines.push(`      schema: ${JSON.stringify(draftSchema)},`);
    lines.push(`      summary: ${JSON.stringify(type.summary_zh)},`);
    lines.push('      draft: true,');
    lines.push(`      schemaVersion: ${JSON.stringify(type.schema_version)},`);
    lines.push(`      capability: ${JSON.stringify(type.capability)},`);
    lines.push('    },');
  }
  lines.push('  ];');
  lines.push('');
  lines.push('  root.SNContentTypes = { GROUPS, TYPES, DRAFT_TYPES };');
  lines.push('})(globalThis);');
  return `${lines.join('\n')}\n`;
}

function compareOrWrite(relativePath, content) {
  const absolute = path.join(ROOT, relativePath);
  const current = fs.existsSync(absolute) ? fs.readFileSync(absolute, 'utf8') : null;
  if (CHECK) {
    if (current === content) return true;
    console.error(`[gen-content-types] stale: ${relativePath} (run node tools/gen_content_types.mjs)`);
    return false;
  }
  if (current !== content) {
    fs.writeFileSync(absolute, content, 'utf8');
    console.log(`[gen-content-types] wrote ${relativePath}`);
  }
  return true;
}

const data = readManifest();
validate(data);
const results = [
  compareOrWrite(GD_OUTPUT, renderGd(data)),
  compareOrWrite(JS_OUTPUT, renderJs(data)),
];
if (!results.every(Boolean)) process.exit(1);
if (CHECK) console.log('[gen-content-types] generated files are up to date');
