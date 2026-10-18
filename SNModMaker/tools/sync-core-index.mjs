#!/usr/bin/env node
/**
 * Regenerate js/core-index.js from the official core mod.
 *
 * The index powers:
 *   - reference pickers (known core IDs with localized names),
 *   - "copy a core definition" starters,
 *   - external-reference checks during validation.
 *
 * Run after content/localization changes in dev_mods/core:
 *
 *   node SNModMaker/tools/sync-core-index.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..');
const coreDir = path.join(repoRoot, 'dev_mods', 'core');
const outFile = path.resolve(here, '..', 'js', 'core-index.js');

const manifest = JSON.parse(fs.readFileSync(path.join(coreDir, 'manifest.json'), 'utf8'));

const readJson = (relative) => JSON.parse(fs.readFileSync(path.join(coreDir, relative), 'utf8'));

const contentFiles = {};
for (const relative of manifest.content || []) {
  contentFiles[relative] = readJson(relative);
}

const localization = {};
for (const relative of manifest.localization || []) {
  const locale = path.basename(relative, '.json');
  localization[locale] = readJson(relative);
}

const definitions = [];
for (const [file, payload] of Object.entries(contentFiles)) {
  if (!Array.isArray(payload.definitions)) continue;
  for (const definition of payload.definitions) {
    if (!definition || typeof definition.id !== 'string') continue;
    const nameKey = definition.name_key || '';
    definitions.push({
      id: definition.id,
      content_type: payload.content_type,
      file,
      name_key: nameKey,
      name_zh: localization.zh_CN?.[nameKey] || '',
      name_en: localization.en?.[nameKey] || '',
      tags: definition.tags || [],
      definition,
    });
  }
}

const index = {
  generated_at: new Date().toISOString(),
  manifest,
  contentFiles,
  localization,
  definitions,
};

const header = [
  '/*',
  ' * AUTO-GENERATED FILE - do not edit by hand.',
  ' * Source: /dev_mods/core (manifest, content, localization)',
  ' * Regenerate: node SNModMaker/tools/sync-core-index.mjs',
  ' */',
  '(function (root) {',
  "  'use strict';",
  '  root.SN_CORE_INDEX = ' + JSON.stringify(index, null, 2).replace(/\n/g, '\n  ') + ';',
  "})(typeof globalThis !== 'undefined' ? globalThis : this);",
  '',
].join('\n');

fs.writeFileSync(outFile, header, 'utf8');
console.log(`Wrote ${outFile} (${definitions.length} definitions, ${Buffer.byteLength(header)} bytes)`);
