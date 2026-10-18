#!/usr/bin/env node
/*
 * Zero-dependency test harness for the Mod Maker's pure modules.
 *
 *   node SNModMaker/tests/run-tests.js
 */
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const js = (name) => path.join(__dirname, '..', 'js', name);
require(js('schema-bundle.js'));
require(js('core-index.js'));
require(js('catalog.js'));
require(js('zip.js'));
require(js('validate.js'));
require(js('store.js'));
require(js('ui.js'));

const Store = globalThis.SNStore;
const Validate = globalThis.SNValidate;
const Catalog = globalThis.SNCatalog;
const UI = globalThis.SNUI;
const Zip = globalThis.SNZip;

let passed = 0;
let failed = 0;
const failures = [];

async function test(name, fn) {
  try {
    await fn();
    passed += 1;
    console.log(`[PASS] ${name}`);
  } catch (error) {
    failed += 1;
    failures.push({ name, error });
    console.error(`[FAIL] ${name}`);
    console.error(`       ${error.message}`);
  }
}

function freshProject() {
  return Store.createProject({ id: 'test_mod', name: 'Test Mod', template: 'goods' });
}

function errorsOf(result) {
  return result.issues.filter((issue) => issue.severity === 'error');
}

function warningsOf(result) {
  return result.issues.filter((issue) => issue.severity === 'warning');
}

(async () => {
  await test('schema bundle contains every canonical schema', () => {
    assert.equal(Object.keys(globalThis.SN_SCHEMAS).length, 18);
    assert.ok(globalThis.SN_SCHEMAS['good.schema.json']);
    assert.ok(globalThis.SN_SCHEMAS['common.schema.json']);
  });

  await test('embedded schema bundle is in sync with /schemas', () => {
    const schemaDir = path.resolve(__dirname, '..', '..', 'schemas');
    const files = fs.readdirSync(schemaDir).filter((name) => name.endsWith('.schema.json'));
    assert.equal(files.length, Object.keys(globalThis.SN_SCHEMAS).length);
    for (const file of files) {
      const disk = JSON.parse(fs.readFileSync(path.join(schemaDir, file), 'utf8'));
      assert.deepEqual(globalThis.SN_SCHEMAS[file], disk, `${file} is stale; run sync-schemas.mjs`);
    }
  });

  await test('embedded core index is in sync with dev_mods/core', () => {
    const coreRoot = path.resolve(__dirname, '..', '..', 'dev_mods', 'core');
    const manifest = JSON.parse(fs.readFileSync(path.join(coreRoot, 'manifest.json'), 'utf8'));
    assert.deepEqual(globalThis.SN_CORE_INDEX.manifest, manifest, 'core manifest is stale; run sync-core-index.mjs');
    let definitions = 0;
    for (const file of manifest.content) {
      const payload = JSON.parse(fs.readFileSync(path.join(coreRoot, file), 'utf8'));
      definitions += payload.definitions.length;
    }
    assert.equal(globalThis.SN_CORE_INDEX.definitions.length, definitions);
    for (const localeFile of manifest.localization) {
      const locale = path.basename(localeFile, '.json');
      const entries = JSON.parse(fs.readFileSync(path.join(coreRoot, localeFile), 'utf8'));
      assert.deepEqual(globalThis.SN_CORE_INDEX.localization[locale], entries, `${locale} is stale`);
    }
  });

  await test('a fresh goods project validates without errors', () => {
    const project = freshProject();
    const result = Validate.validateProject(project);
    assert.equal(result.counts.error, 0, JSON.stringify(errorsOf(result), null, 2));
    assert.equal(result.stats.definitions, 1);
    assert.equal(project.manifest.content.length, 1);
    assert.equal(project.manifest.localization.length, 2);
  });

  await test('schema validator catches required, enum, pattern and extra fields', () => {
    const errors = Validate.validateSchema(
      { schema_version: '1.0', content_type: 'goods', definitions: [{ id: 'Bad', name_key: '', enabled: true, data: { unit_weight: 0, base_price: 1, base_stock: 1, price_elasticity: 2, extra: 1 } }] },
      globalThis.SN_SCHEMAS['good.schema.json'],
      'good.schema.json'
    );
    const keywords = new Set(errors.map((error) => error.keyword));
    assert.ok(keywords.has('pattern'), 'id pattern');
    assert.ok(keywords.has('minLength'), 'name_key minLength');
    assert.ok(keywords.has('minimum'), 'unit_weight minimum');
    assert.ok(keywords.has('maximum'), 'price_elasticity maximum');
    assert.ok(keywords.has('additionalProperties'), 'extra data field');
  });

  await test('every content type renders a form and validates with defaults', () => {
    const project = freshProject();
    for (const info of Catalog.TYPES) {
      if (info.key === 'goods') continue;
      const added = Store.addDefinition(project, info.key, {});
      assert.ok(added && added.definition, `add ${info.key}`);
      if (info.key === 'boilers') added.definition.data.materials = [{ id: 'core:good/brass', amount: 2 }];
      const html = UI.renderDefinitionForm({
        project,
        typeKey: info.key,
        definition: added.definition,
        file: added.file,
        index: added.index,
        schemaFile: info.schema,
      });
      assert.ok(html.length > 400, `${info.key} form too small`);
      assert.ok(html.includes('data-field='), `${info.key} form has no inputs`);
      assert.ok(!html.includes('undefined'), `${info.key} form contains undefined`);
      if (info.key === 'events') {
        assert.ok(html.includes('option-card'), 'event options use the option editor');
        assert.ok(html.includes('effect-row'), 'event effects use the effect editor');
        assert.ok(html.includes('condition-empty'), 'event conditions use the condition editor');
      }
      if (info.key === 'boilers') {
        assert.ok(html.includes('item-card slim'), 'boiler materials use the material editor');
      }
      if (info.key === 'roles') {
        assert.ok(html.includes('dl-stats'), 'role modifiers use the stat editor');
      }
    }
    const result = Validate.validateProject(project);
    assert.equal(result.counts.error, 0, JSON.stringify(errorsOf(result), null, 2));
  });

  await test('module localization keys do not collide across module types', () => {
    const project = freshProject();
    const hull = Store.addDefinition(project, 'hulls', {});
    const boiler = Store.addDefinition(project, 'boilers', {});
    const cargo = Store.addDefinition(project, 'cargo_modules', {});
    assert.equal(hull.definition.name_key, 'module.test_mod.new_item.name');
    assert.notEqual(boiler.definition.name_key, hull.definition.name_key);
    assert.notEqual(cargo.definition.name_key, boiler.definition.name_key);
  });

  await test('ID namespace and type mismatches are reported', () => {
    const project = freshProject();
    const definition = project.contentFiles[0].definitions[0];
    definition.id = 'other_mod:good/tea';
    let result = Validate.validateProject(project);
    assert.ok(errorsOf(result).some((issue) => issue.code === 'id_namespace'));
    definition.id = 'test_mod:boiler/tea';
    result = Validate.validateProject(project);
    assert.ok(errorsOf(result).some((issue) => issue.code === 'id_type'));
  });

  await test('duplicate IDs are reported across content files', () => {
    const project = freshProject();
    const second = Store.addDefinition(project, 'goods', { localId: 'second' });
    second.definition.id = project.contentFiles[0].definitions[0].id;
    const result = Validate.validateProject(project);
    assert.ok(errorsOf(result).some((issue) => issue.code === 'duplicate_id'));
  });

  await test('missing own-namespace reference is an error; unknown core reference is a warning', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'starting_builds', {});
    added.definition.data.hull = 'test_mod:hull/does_not_exist';
    added.definition.data.boiler = 'core:boiler/also_missing';
    const result = Validate.validateProject(project);
    assert.ok(errorsOf(result).some((issue) => issue.code === 'ref_missing'));
    assert.ok(warningsOf(result).some((issue) => issue.code === 'ref_core_unknown'));
  });

  await test('missing localization key produces a warning and blank translation is reported', () => {
    const project = freshProject();
    const definition = project.contentFiles[0].definitions[0];
    definition.name_key = 'good.test_mod.untracked.name';
    let result = Validate.validateProject(project);
    assert.ok(warningsOf(result).some((issue) => issue.code === 'localization_missing'));
    const zh = Store.getLoc(project, 'zh_CN');
    zh.entries[definition.name_key] = '';
    result = Validate.validateProject(project);
    assert.ok(warningsOf(result).some((issue) => issue.code === 'localization_blank'));
  });

  await test('patch targeting own namespace and invalid source range are rejected', () => {
    const project = freshProject();
    const patch = Store.addDefinition(project, 'patches', {});
    patch.definition.target = 'test_mod:good/tea';
    patch.definition.requires.version = 'not-a-range';
    const result = Validate.validateProject(project);
    assert.ok(errorsOf(result).some((issue) => issue.code === 'patch_own_target'));
    assert.ok(errorsOf(result).some((issue) => issue.code === 'patch_requires_version'));
  });

  await test('version ranges accept supported syntax and reject junk', () => {
    for (const range of ['*', '', '1.2.3', '>=1.0.0 <2.0.0', '^1.2.3', '~1.2.3', '>=1.0.0 <2.0.0 || 3.0.0']) {
      assert.equal(Validate.versionRangeError(range), '', range);
    }
    for (const range of ['abc', '>=1.0', '~x.y.z', '1.2.3.4']) {
      assert.notEqual(Validate.versionRangeError(range), '', range);
    }
  });

  await test('core definition clone rewrites IDs, keys and translations', () => {
    const project = freshProject();
    const result = Store.cloneCoreDefinition(project, 'core:boiler/small_efficient');
    assert.ok(result);
    assert.equal(result.definition.id, 'test_mod:boiler/small_efficient_copy');
    assert.ok(result.definition.name_key.startsWith('module.test_mod.'));
    const zh = Store.getLoc(project, 'zh_CN');
    assert.ok(zh.entries[result.definition.name_key]);
    assert.ok(zh.entries[result.definition.name_key].includes('副本'));
  });

  await test('core clone handles ID local names that differ from key prefixes', () => {
    const project = freshProject();
    const result = Store.cloneCoreDefinition(project, 'core:hull/small_efficient');
    assert.ok(result);
    assert.ok(result.definition.name_key.startsWith('module.test_mod.small_efficient_copy.'));
    assert.equal(result.definition.description_key, 'module.test_mod.small_efficient_copy.description');
    const zh = Store.getLoc(project, 'zh_CN');
    assert.ok(zh.entries[result.definition.name_key]);
    const validation = Validate.validateProject(project);
    assert.equal(validation.counts.error, 0, JSON.stringify(errorsOf(validation), null, 2));
  });

  await test('deleting the last definition removes its empty content file', () => {
    const project = freshProject();
    const file = project.contentFiles[0];
    Store.removeDefinition(project, file.path, 0);
    assert.equal(project.contentFiles.length, 0);
    assert.equal(project.manifest.content.length, 0);
    const validation = Validate.validateProject(project);
    assert.ok(errorsOf(validation).some((issue) => issue.code === 'no_content'));
  });

  await test('duplicate definition rewrites keys and copies translations', () => {
    const project = freshProject();
    const first = project.contentFiles[0].definitions[0];
    const result = Store.duplicateDefinition(project, project.contentFiles[0].path, 0);
    assert.ok(result);
    assert.notEqual(result.definition.id, first.id);
    assert.notEqual(result.definition.name_key, first.name_key);
    assert.ok(Store.getLoc(project, 'zh_CN').entries[result.definition.name_key]);
  });

  await test('ZIP builder and reader round-trip text and binary entries', async () => {
    const entries = [
      { path: 'mods/demo/manifest.json', data: '{"id":"demo"}' },
      { path: 'mods/demo/assets/icon.svg', data: '<svg xmlns="http://www.w3.org/2000/svg"/>' },
      { path: 'mods/demo/data.bin', data: new Uint8Array([0, 1, 2, 3, 250, 255]) },
    ];
    const bytes = await Zip.build(entries);
    const back = await Zip.read(bytes);
    assert.equal(back.length, 3);
    assert.equal(new TextDecoder().decode(back[0].data), '{"id":"demo"}');
    assert.deepEqual([...back[2].data], [0, 1, 2, 3, 250, 255]);
  });

  await test('ZIP deflate path compresses repetitive data and round-trips', async () => {
    const raw = 'A'.repeat(8000);
    const bytes = await Zip.build([{ path: 'mods/demo/big.txt', data: raw }]);
    assert.ok(bytes.length < raw.length / 4, `expected compression, got ${bytes.length} bytes`);
    const back = await Zip.read(bytes);
    assert.equal(new TextDecoder().decode(back[0].data), raw);
  });

  await test('default event definitions get readable option names', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'events', {});
    const keys = Store.collectDefinitionKeys(added.definition);
    const zh = Store.getLoc(project, 'zh_CN');
    const en = Store.getLoc(project, 'en');
    for (const key of keys) {
      assert.ok(zh.entries[key], `missing zh translation ${key}`);
      assert.ok(en.entries[key], `missing en translation ${key}`);
    }
    assert.ok(keys.has('event.test_mod.new_item.endure'));
    assert.equal(zh.entries['event.test_mod.new_item.endure'], '硬撑过去');
  });

  await test('export/import round-trip preserves manifest, content, locales and assets', async () => {
    const project = freshProject();
    Store.addAsset(project, {
      key: 'icon.tea',
      path: 'assets/icons/tea.svg',
      mime: 'image/svg+xml',
      size: 4,
      dataUrl: Store.bytesToDataUrl(new Uint8Array([60, 115, 118, 103]), 'image/svg+xml'),
    });
    const files = Store.toExportFiles(project);
    assert.ok(files.every((file) => file.path.startsWith('mods/test_mod/')));
    const result = Store.fromFiles(files);
    assert.equal(result.project.manifest.id, 'test_mod');
    assert.equal(result.project.contentFiles.length, project.contentFiles.length);
    assert.equal(result.project.localization.length, 2);
    assert.equal(result.project.assets.length, 1);
    assert.equal(result.project.assets[0].key, 'icon.tea');
    const validation = Validate.validateProject(result.project);
    assert.equal(validation.counts.error, 0, JSON.stringify(errorsOf(validation), null, 2));
    const bytes = await Zip.build(Store.toExportFiles(result.project));
    const reread = await Zip.read(bytes);
    assert.ok(reread.some((entry) => entry.path.endsWith('manifest.json')));
  });

  await test('CSV localization is skipped with a warning instead of failing import', () => {
    const project = freshProject();
    const files = Store.toExportFiles(project);
    const manifestFile = files.find((file) => file.path.endsWith('manifest.json'));
    const manifest = JSON.parse(manifestFile.data);
    manifest.localization.push('localization/extra.csv');
    manifestFile.data = JSON.stringify(manifest);
    files.push({ path: 'mods/test_mod/localization/extra.csv', data: 'key,zh_CN\nfoo,bar\n' });
    const result = Store.fromFiles(files);
    assert.ok(result.warnings.some((warning) => warning.includes('CSV')));
    assert.equal(result.project.localization.length, project.localization.length);
  });

  await test('imports the official core mod without errors', () => {
    const coreRoot = path.resolve(__dirname, '..', '..', 'dev_mods', 'core');
    const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) return walk(full);
      return [{ path: path.relative(coreRoot, full).replaceAll('\\', '/'), data: fs.readFileSync(full) }];
    });
    const result = Store.fromFiles(walk(coreRoot));
    assert.equal(result.project.manifest.id, 'core');
    assert.equal(result.project.contentFiles.length, 15);
    assert.equal(result.project.assets.length, 3);
    const validation = Validate.validateProject(result.project);
    assert.equal(validation.counts.error, 0, JSON.stringify(errorsOf(validation), null, 2));
  });

  await test('imports the real SDK example boiler mod', () => {
    const modRoot = path.resolve(__dirname, '..', '..', 'sdk', 'examples', 'example_boilers');
    const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) return walk(full);
      return [{ path: path.relative(modRoot, full).replaceAll('\\', '/'), data: fs.readFileSync(full) }];
    });
    const result = Store.fromFiles(walk(modRoot));
    assert.equal(result.project.manifest.id, 'example_boilers');
    assert.equal(result.warnings.length, 0, JSON.stringify(result.warnings));
    const validation = Validate.validateProject(result.project);
    assert.equal(validation.counts.error, 0, JSON.stringify(errorsOf(validation), null, 2));
    assert.ok(result.project.contentFiles.some((file) => file.content_type === 'boilers'));
  });

  await test('condition group rendering is recursive', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'events', {});
    added.definition.data.options[0].condition = {
      all: [
        { op: 'money_gte', value: 10 },
        { any: [{ op: 'at_port', port_id: '' }, { op: 'has_module', id: 'core:boiler/small_efficient' }] },
        { not: { op: 'has_item', item_id: 'core:good/tea', amount: 1 } },
      ],
    };
    const html = UI.renderDefinitionForm({
      project, typeKey: 'events', definition: added.definition, file: added.file, index: added.index, schemaFile: 'event.schema.json',
    });
    assert.ok(html.includes('全部满足 (all)'));
    assert.ok(html.includes('任一满足 (any)'));
    assert.ok(html.includes('取反 (not)'));
    assert.ok(html.includes('data-field="data.options.0.condition.all.0.value"'));
    assert.ok(html.includes('data-field="data.options.0.condition.all.2.not.item_id"'));
    const validation = Validate.validateProject(project);
    assert.equal(validation.counts.error, 0, JSON.stringify(errorsOf(validation), null, 2));
  });

  await test('project serialization round-trips', () => {
    const project = freshProject();
    const text = Store.serialize(project);
    const restored = Store.deserialize(text);
    assert.equal(restored.manifest.id, project.manifest.id);
    assert.equal(restored.contentFiles[0].definitions[0].id, project.contentFiles[0].definitions[0].id);
    assert.equal(Validate.validateProject(restored).counts.error, 0);
  });

  await test('field delete helpers handle array conditions', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'events', {});
    const definition = added.definition;
    assert.equal(definition.data.options.length, 2);
    definition.data.options[0].condition = { all: [{ op: 'money_gte', value: 10 }, { op: 'has_module', id: 'core:boiler/small_efficient' }] };
    const result = Validate.validateProject(project);
    assert.equal(result.counts.error, 0, JSON.stringify(errorsOf(result), null, 2));
    const html = UI.renderDefinitionForm({
      project, typeKey: 'events', definition, file: added.file, index: added.index, schemaFile: 'event.schema.json',
    });
    assert.ok(html.includes('condition-box'));
    assert.ok(html.includes('全部满足'));
  });

  await test('semver helper accepts prerelease and rejects leading zeros', () => {
    assert.ok(Validate.parseSemver('1.2.3-beta.1+build.5'));
    assert.equal(Validate.parseSemver('01.2.3'), null);
  });

  console.log(`\nTests: ${passed} passed, ${failed} failed, ${passed + failed} total`);
  if (failed) {
    for (const failure of failures) {
      console.error(`\n--- ${failure.name} ---`);
      console.error(failure.error.stack);
    }
    process.exitCode = 1;
  }
})();
