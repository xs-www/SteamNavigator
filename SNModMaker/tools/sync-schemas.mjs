#!/usr/bin/env node
/**
 * Regenerate js/schema-bundle.js from the canonical JSON Schemas in /schemas.
 *
 * The Mod Maker must stay usable from file:// with zero network access, so the
 * schemas are embedded as a plain script instead of being fetched at runtime.
 * Run this script after any schema change:
 *
 *   node SNModMaker/tools/sync-schemas.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..', '..');
const schemaDir = path.join(repoRoot, 'schemas');
const outFile = path.resolve(here, '..', 'js', 'schema-bundle.js');

const files = fs
  .readdirSync(schemaDir)
  .filter((name) => name.endsWith('.schema.json'))
  .sort();

const bundle = {};
for (const file of files) {
  bundle[file] = JSON.parse(fs.readFileSync(path.join(schemaDir, file), 'utf8'));
}

const header = [
  '/*',
  ' * AUTO-GENERATED FILE - do not edit by hand.',
  ' * Source: /schemas/*.schema.json',
  ' * Regenerate: node SNModMaker/tools/sync-schemas.mjs',
  ' */',
  '(function (root) {',
  "  'use strict';",
  '  root.SN_SCHEMAS = ' + JSON.stringify(bundle, null, 2).replace(/\n/g, '\n  ') + ';',
  "})(typeof globalThis !== 'undefined' ? globalThis : this);",
  '',
].join('\n');

fs.writeFileSync(outFile, header, 'utf8');
console.log(`Wrote ${outFile} (${files.length} schemas, ${Buffer.byteLength(header)} bytes)`);
