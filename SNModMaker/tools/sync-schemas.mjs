#!/usr/bin/env node
/**
 * Regenerate js/schema-bundle.js from the canonical JSON Schemas in /schemas.
 *
 * The Mod Maker must stay usable from file:// with zero network access, so the
 * schemas are embedded as a plain script instead of being fetched at runtime.
 * The bundle includes the Content Schema 2.0 draft schemas under /schemas/v2
 * (editor support only; the runtime stays on Content Schema 1.0). Every key is
 * the schema's posix path relative to /schemas, so the top-level schemas keep
 * their basenames ("good.schema.json") and drafts are "v2/<name>.schema.json".
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

function collectSchemas(directory) {
  const found = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      found.push(...collectSchemas(full));
    } else if (entry.isFile() && entry.name.endsWith('.schema.json')) {
      found.push(path.relative(schemaDir, full).split(path.sep).join('/'));
    }
  }
  return found;
}

const files = collectSchemas(schemaDir).sort();
if (!files.length) {
  console.error('[sync-schemas] no *.schema.json files found under /schemas');
  process.exit(1);
}

const bundle = {};
for (const file of files) {
  bundle[file] = JSON.parse(fs.readFileSync(path.join(schemaDir, file), 'utf8'));
}

const header = [
  '/*',
  ' * AUTO-GENERATED FILE - do not edit by hand.',
  ' * Source: /schemas (Content Schema 1.0 top-level + 2.0 draft under v2/)',
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
