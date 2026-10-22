#!/usr/bin/env node
/*
 * Zero-dependency test harness for the Mod Maker's pure modules.
 *
 *   node SNModMaker/tests/run-tests.js
 */
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const js = (name) => path.join(__dirname, '..', 'js', name);
require(js('schema-bundle.js'));
require(js('core-index.js'));
require(js('content-types.js'));
require(js('catalog.js'));
require(js('zip.js'));
require(js('validate.js'));
require(js('store.js'));
require(js('glb.js'));
require(js('ui.js'));

const Store = globalThis.SNStore;
const Validate = globalThis.SNValidate;
const Catalog = globalThis.SNCatalog;
const Types = globalThis.SNContentTypes;
const UI = globalThis.SNUI;
const Zip = globalThis.SNZip;
const GLB = globalThis.SNGLB;

/* Recursively list every schema file relative to `/schemas`, posix style. */
function schemaFilesOnDisk() {
  const schemaDir = path.resolve(__dirname, '..', '..', 'schemas');
  const files = [];
  const walk = (dir, prefix) => {
    const entries = fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1));
    for (const entry of entries) {
      const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.isDirectory()) walk(path.join(dir, entry.name), relative);
      else if (entry.name.endsWith('.schema.json')) files.push(relative);
    }
  };
  walk(schemaDir, '');
  return files.sort();
}

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

/* Load a directory of mod files (manifest + content + localization) as a project. */
function projectFromDir(dir) {
  const entries = [];
  const walk = (current, prefix) => {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.isDirectory()) walk(path.join(current, entry.name), relative);
      else entries.push({ path: relative, data: fs.readFileSync(path.join(current, entry.name)) });
    }
  };
  walk(dir, '');
  return Store.fromFiles(entries).project;
}

/* The shipped Story Mode sample pack (story-only content mod, not loadable by
 * the 1.0 runtime yet, so it lives under sdk/templates rather than sdk/examples). */
function storyPackProject() {
  return projectFromDir(path.resolve(__dirname, '..', '..', 'sdk', 'templates', 'story_pack_iron_tide'));
}

function errorsOf(result) {
  return result.issues.filter((issue) => issue.severity === 'error');
}

function warningsOf(result) {
  return result.issues.filter((issue) => issue.severity === 'warning');
}

(async () => {
  await test('schema bundle contains every canonical schema', () => {
    const files = schemaFilesOnDisk();
    const keys = Object.keys(globalThis.SN_SCHEMAS).sort();
    assert.equal(keys.length, 31, `expected 18 top-level + 13 v2 schemas, got ${keys.length}`);
    assert.equal(files.length, 31, `expected 31 schema files on disk, got ${files.length}`);
    assert.deepEqual(keys, files, 'the bundle keys must mirror /schemas recursively');
    assert.ok(globalThis.SN_SCHEMAS['good.schema.json']);
    assert.ok(globalThis.SN_SCHEMAS['common.schema.json']);
    assert.ok(globalThis.SN_SCHEMAS['v2/common.schema.json'], 'v2/common is needed by the draft schemas');
    assert.ok(globalThis.SN_SCHEMAS['v2/world_profile.schema.json']);
    assert.ok(globalThis.SN_SCHEMAS['v2/map_config.schema.json'], 'v2/map_config is the Phase B scenario config schema');
    assert.ok(globalThis.SN_SCHEMAS['v2/weapon.schema.json'], 'v2/weapon is the weapons draft schema');
    assert.ok(globalThis.SN_SCHEMAS['v2/story_arc.schema.json'], 'v2/story_arc is the Story Mode arc draft schema');
    assert.ok(globalThis.SN_SCHEMAS['v2/story_level.schema.json'], 'v2/story_level is the Story Mode level draft schema');
  });

  await test('embedded schema bundle is in sync with /schemas recursively', () => {
    const files = schemaFilesOnDisk();
    for (const file of files) {
      const disk = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'schemas', file), 'utf8'));
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

  await test('createProject with drafts builds a pure Schema 2.0 project', () => {
    const project = Store.createProject({ id: 'draft_mod', name: 'Draft Mod', template: null, drafts: ['weapons'] });
    assert.deepEqual(project.contentFiles.map((file) => file.content_type), ['weapons'], 'only the requested draft type is created');
    assert.equal(project.contentFiles[0].path, 'content/weapons.json');
    assert.equal(project.contentFiles[0].schema_version, '2.0');
    assert.equal(project.contentFiles[0].definitions.length, 1);
    assert.equal(project.contentFiles[0].definitions[0].id, 'draft_mod:weapon/weapon_starter');
    assert.deepEqual(project.manifest.content, ['content/weapons.json']);
    assert.deepEqual(project.manifest.capabilities, ['content.combat.v1'], 'the draft capability is declared in the manifest');
    assert.equal(project.manifest.localization.length, 2, 'both localization files are created');

    const validation = Validate.validateProject(project);
    assert.equal(validation.counts.error, 0, JSON.stringify(errorsOf(validation), null, 2));
    assert.deepEqual(warningsOf(validation).map((issue) => issue.code), ['draft_content'], 'capability_undeclared must not fire');

    // Phase B promoted the world/campaign family out of the draft API; weapons
    // and the two Story Mode types are the only creatable drafts now, and
    // promoted types are editable through the normal runtime-type path.
    const promoted = Store.createProject({ id: 'world_mod', name: 'World Mod', template: 'goods' });
    Store.addDefinition(promoted, 'world_profiles', {});
    Store.addDefinition(promoted, 'regions', {});
    assert.deepEqual(promoted.contentFiles.map((file) => file.content_type), ['goods', 'world_profiles', 'regions']);
    assert.deepEqual(
      promoted.contentFiles.filter((file) => file.content_type !== 'goods').map((file) => file.schema_version),
      ['2.0', '2.0'],
      'promoted types write Schema 2.0 content files'
    );
    assert.deepEqual(promoted.manifest.capabilities, [], 'active types do not auto-declare capabilities yet');
    assert.equal(Validate.validateProject(promoted).counts.error, 0);
    assert.throws(
      () => Store.createProject({ id: 'promoted_draft', name: 'Promoted', template: null, drafts: ['world_profiles'] }),
      /未知 Schema 2\.0 草案类型/
    );

    // The legacy template path is untouched (goods starter, 1.0, no capabilities).
    const legacy = Store.createProject({ id: 'legacy_mod', name: 'Legacy Mod', template: 'goods' });
    assert.deepEqual(legacy.contentFiles.map((file) => file.content_type), ['goods']);
    assert.equal(legacy.contentFiles[0].schema_version, '1.0');
    assert.deepEqual(legacy.manifest.capabilities, []);

    // Unknown draft types are rejected instead of silently ignored.
    assert.throws(
      () => Store.createProject({ id: 'bad_mod', name: 'Bad Mod', template: null, drafts: ['nope'] }),
      /未知 Schema 2\.0 草案类型/
    );
  });

  await test('weapons template creates five Schema 2.0 weapon presets', () => {
    const template = Catalog.TEMPLATES.find((item) => item.key === 'weapons');
    assert.ok(template, 'catalog must expose the weapons starter template');
    assert.equal(template.type, 'weapons');
    assert.equal(template.name, '舰载武器包');
    assert.equal(Catalog.WEAPON_PRESETS.length, 5, 'the template ships exactly five preset weapons');
    const presets = Catalog.WEAPON_PRESETS;
    const presetIds = ['deck_gun', 'heavy_cannon', 'mortar', 'repeater', 'broadside'];
    assert.deepEqual(presets.map((preset) => preset.localId), presetIds, 'presets follow the battle simulator order');

    // Combat numbers mirror SNBattleSim/js/catalog.mjs BUILTIN_WEAPONS; assembly fields follow GLB extras.
    const expected = {
      deck_gun: { kind: 'direct', damage: 12, range: 245, min_range: 0, cooldown: 1.65, salvo: 1, weapon_class: 'Light', assembly_profile: 'yaw_pitch' },
      heavy_cannon: { kind: 'direct', damage: 30, range: 355, min_range: 35, cooldown: 4.2, salvo: 1, weapon_class: 'Heavy', assembly_profile: 'yaw_pitch' },
      mortar: { kind: 'artillery', damage: 24, range: 430, min_range: 105, cooldown: 5.1, salvo: 1, weapon_class: 'Heavy', assembly_profile: 'yaw_pitch' },
      repeater: { kind: 'direct', damage: 7, range: 185, min_range: 0, cooldown: 0.72, salvo: 1, weapon_class: 'Medium', assembly_profile: 'yaw_pitch' },
      broadside: { kind: 'broadside', damage: 8, range: 285, min_range: 20, cooldown: 5.4, salvo: 4, weapon_class: 'Side', assembly_profile: 'pitch_only' },
    };
    const coreManifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'dev_mods', 'core', 'manifest.json'), 'utf8'));
    for (const preset of presets) {
      assert.equal(preset.model, `model.weapon.${preset.localId}`, `${preset.localId} points at its Core model key`);
      assert.ok(coreManifest.assets[preset.model], `Core manifest must declare ${preset.model}`);
      for (const [field, value] of Object.entries(expected[preset.localId])) {
        assert.equal(preset.data[field], value, `${preset.localId}.data.${field}`);
      }
      assert.ok(Number.isInteger(preset.data.muzzle_count) && preset.data.muzzle_count >= 1, `${preset.localId} declares muzzle_count`);
      assert.ok(Array.isArray(preset.data.materials), `${preset.localId} declares craft materials`);
    }

    const project = Store.createProject({ id: 'weapon_pack', name: 'Weapon Pack', template: 'weapons' });
    assert.deepEqual(project.contentFiles.map((file) => file.content_type), ['weapons'], 'the template creates one content file');
    assert.equal(project.contentFiles[0].path, 'content/weapons.json');
    assert.equal(project.contentFiles[0].schema_version, '2.0');
    assert.equal(project.contentFiles[0].definitions.length, 5);
    assert.deepEqual(project.manifest.content, ['content/weapons.json']);
    assert.deepEqual(project.manifest.capabilities, ['content.combat.v1']);
    assert.deepEqual(
      project.contentFiles[0].definitions.map((definition) => definition.id),
      presetIds.map((localId) => `weapon_pack:weapon/${localId}`)
    );
    for (let index = 0; index < presets.length; index += 1) {
      const preset = presets[index];
      const definition = project.contentFiles[0].definitions[index];
      assert.deepEqual(definition.information, { model: `asset://core/${preset.model}` }, `${preset.localId} model is namespaced to Core`);
      assert.deepEqual(definition.data, preset.data, `${preset.localId} draft data matches the preset`);
      for (const locale of ['zh_CN', 'en']) {
        const entries = Store.getLoc(project, locale).entries;
        assert.ok(entries[`weapon.weapon_pack.${preset.localId}.name`], `${locale} name for ${preset.localId}`);
        assert.ok(entries[`weapon.weapon_pack.${preset.localId}.description`], `${locale} description for ${preset.localId}`);
      }
    }

    const validation = Validate.validateProject(project);
    assert.equal(validation.counts.error, 0, JSON.stringify(errorsOf(validation), null, 2));
    assert.deepEqual(
      warningsOf(validation).map((issue) => issue.code),
      ['draft_content'],
      'only draft_content may warn: no capability_undeclared and no entity_model_missing'
    );
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
        assert.ok(html.includes('条目内其他多语言文本'), 'nested localization values are editable in the entity');
      }
      if (info.key === 'boilers') {
        assert.ok(html.includes('item-card slim'), 'boiler materials use the material editor');
      }
      if (info.key === 'roles') {
        assert.ok(html.includes('dl-stats'), 'role modifiers use the stat editor');
      }
      if (info.key === 'hulls') {
        assert.ok(html.includes('hull-module-grid'), 'hulls expose a dedicated module configuration area');
        assert.ok(html.includes('data-module-kind="boiler"'), 'hulls show the fixed boiler slot');
        assert.ok(html.includes('data-module-kind="navigation"'), 'hulls show the fixed navigation slot');
        assert.ok(html.includes('data-module-kind="safety"'), 'hulls show the fixed safety slot');
        assert.equal((html.match(/data-field="data\.cargo_slots"/g) || []).length, 1, 'cargo slots render once in module configuration');
        assert.equal((html.match(/data-field="data\.cabin_slots"/g) || []).length, 1, 'cabin slots render once in module configuration');
      }
      if (info.key !== 'patches') {
        assert.ok(html.includes('data-field="information.texture"'), `${info.key} exposes texture configuration`);
        assert.ok(html.includes('data-field="information.model"'), `${info.key} exposes model configuration`);
        assert.ok(html.includes('data-asset-kind="image"'), `${info.key} uses the custom image picker`);
        assert.ok(html.includes('data-asset-kind="model"'), `${info.key} uses the custom model picker`);
        assert.ok(!html.includes('list="dl-asset-keys"'), `${info.key} does not use the native asset datalist`);
      }
    }
    const result = Validate.validateProject(project);
    assert.equal(result.counts.error, 0, JSON.stringify(errorsOf(result), null, 2));
  });

  await test('draft types are generated with schema 2.0 and registered in the catalog', () => {
    assert.equal(Types.DRAFT_TYPES.length, 3, 'weapons and the two Story Mode types are Schema 2.0 draft types');
    assert.deepEqual(Types.DRAFT_TYPES.map((info) => info.key), ['weapons', 'story_arcs', 'story_levels']);
    for (const info of Types.DRAFT_TYPES) {
      assert.equal(info.draft, true, `${info.key} must be marked draft`);
      assert.equal(info.schemaVersion, '2.0', `${info.key} must declare schema 2.0`);
      assert.ok(info.capability, `${info.key} must declare a capability`);
      assert.ok(globalThis.SN_SCHEMAS[info.schema], `${info.key} schema ${info.schema} must be embedded`);
      assert.ok(Catalog.BY_KEY[info.key], `${info.key} must be registered in catalog.BY_KEY`);
      assert.equal(typeof Catalog.DEFAULTS[info.key], 'function', `${info.key} must provide DEFAULTS`);
      assert.equal(Validate.schemaVersionFor(info.key), '2.0', `${info.key} version by key`);
      assert.equal(Validate.schemaVersionFor({ content_type: info.key }), '2.0', `${info.key} version by file`);
    }
    // 1.0 types keep their version without regression.
    assert.equal(Validate.schemaVersionFor('goods'), '1.0');
    assert.equal(Validate.schemaVersionFor({ content_type: 'goods', schema_version: '1.0' }), '1.0');
    assert.equal(Validate.schemaVersionFor('not_a_type'), '1.0', 'unknown types fall back to 1.0');
  });

  await test('every runtime type declares its content schema version (type-level versioning)', () => {
    assert.equal(Types.TYPES.length, 25, 'content_types.json exposes 25 runtime types (24 definitions + patches)');
    const promoted = new Set([
      'world_profiles', 'regions', 'sites', 'route_templates', 'weather_profiles',
      'factions', 'discoveries', 'start_profiles', 'map_configs',
    ]);
    for (const info of Types.TYPES) {
      const expected = promoted.has(info.key) ? '2.0' : '1.0';
      assert.equal(info.schemaVersion, expected, `${info.key} must declare schemaVersion ${expected}`);
      assert.equal(Catalog.schemaVersionFor(info.key), expected, `${info.key} catalog version`);
      assert.equal(Validate.schemaVersionFor(info.key), expected, `${info.key} validator version by type`);
      assert.equal(Validate.schemaVersionFor({ content_type: info.key }), expected, `${info.key} version by file`);
    }
    // An explicit file version still wins so a wrong version is reported by validation.
    assert.equal(Validate.schemaVersionFor({ content_type: 'goods', schema_version: '2.0' }), '2.0');
    assert.equal(Catalog.schemaVersionFor('patches'), '1.0', 'patches are a runtime type at 1.0');
  });

  await test('draft content is detected for the export and deploy guards', () => {
    const project = freshProject();
    assert.equal(Store.hasDraftContent(project), false, 'a 1.0-only project has no draft content');
    assert.deepEqual(Store.draftContentFiles(project), []);

    const added = Store.addDefinition(project, 'world_profiles', {});
    assert.equal(Store.hasDraftContent(project), true, 'draft types must be detected');
    const files = Store.draftContentFiles(project);
    assert.deepEqual(files.map((file) => file.content_type), ['world_profiles']);
    assert.equal(files[0].path, added.file.path);

    // A runtime type whose file declares 2.0 (imported or malformed) is blocked too.
    project.contentFiles.push({
      path: 'content/legacy_2.json',
      content_type: 'goods',
      schema_version: '2.0',
      definitions: [],
    });
    assert.equal(Store.hasDraftContent(project), true, 'schema_version 2.0 files must be detected');

    const legacy = freshProject();
    Store.addDefinition(legacy, 'boilers', {});
    assert.equal(Store.hasDraftContent(legacy), false, 'runtime content stays exportable');
  });

  await test('every draft type validates with zero errors using catalog defaults', () => {
    /* Story packs are story-only, so weapons and the Story Mode drafts live in
     * separate projects: mixing them would trip the story_pack_off_whitelist rule. */
    const families = [
      { drafts: ['weapons'], types: ['weapons'] },
      { drafts: ['story_arcs', 'story_levels'], types: ['story_arcs', 'story_levels'] },
    ];
    for (const family of families) {
      const project = Store.createProject({
        id: 'draft_family_mod',
        name: 'Draft Family',
        template: null,
        drafts: family.drafts,
      });
      for (const typeKey of family.types) {
        const info = Types.DRAFT_TYPES.find((item) => item.key === typeKey);
        assert.ok(info, `${typeKey} must be a draft type`);
        const file = project.contentFiles.find((item) => item.content_type === typeKey);
        assert.ok(file, `${typeKey} content file must exist`);
        assert.equal(file.schema_version, '2.0', `${typeKey} content file must be written as schema 2.0`);
        assert.equal(file.definitions.length, 1, `${typeKey} adds exactly one starter definition`);
        const html = UI.renderDefinitionForm({
          project,
          typeKey,
          definition: file.definitions[0],
          file,
          index: 0,
          schemaFile: info.schema,
        });
        assert.ok(html.length > 200, `${typeKey} form too small`);
        assert.ok(html.includes('data-field='), `${typeKey} form has no inputs`);
        assert.ok(!html.includes('undefined'), `${typeKey} form contains undefined`);
      }
      const result = Validate.validateProject(project);
      assert.equal(result.counts.error, 0, JSON.stringify(errorsOf(result), null, 2));
      const warningCodes = new Set(warningsOf(result).map((issue) => issue.code));
      assert.ok(warningCodes.has('draft_content'), 'draft content must produce a draft_content warning');
      assert.ok(!warningCodes.has('capability_undeclared'), 'the draft starter must declare its capability');
    }
  });

  await test('weapons draft defaults satisfy the Schema 2.0 weapon schema', () => {
    const weaponSchema = globalThis.SN_SCHEMAS['v2/weapon.schema.json'];
    assert.ok(weaponSchema, 'v2/weapon.schema.json must be embedded in the schema bundle');
    const defaults = Catalog.DEFAULTS.weapons();
    assert.equal(typeof defaults, 'object', 'DEFAULTS.weapons must return a data object');
    const envelope = {
      schema_version: '2.0',
      content_type: 'weapons',
      definitions: [{
        id: 'test_mod:weapon/deck_gun',
        name_key: 'weapon.test_mod.deck_gun.name',
        tags: ['weapon.direct'],
        enabled: true,
        data: defaults,
      }],
    };
    const errors = Validate.validateSchema(envelope, weaponSchema, 'v2/weapon.schema.json');
    assert.deepEqual(errors, [], `DEFAULTS.weapons must pass the draft schema: ${JSON.stringify(errors, null, 2)}`);
    for (const field of weaponSchema.$defs.weapon_data.required) {
      assert.ok(Object.prototype.hasOwnProperty.call(defaults, field), `DEFAULTS.weapons must provide required field ${field}`);
    }
    // Economy defaults use the runtime module material shape ({id, amount}).
    assert.equal(defaults.kind, 'direct');
    assert.equal(defaults.weapon_class, 'Light');
    assert.equal(defaults.assembly_profile, 'yaw_pitch');
    assert.equal(defaults.muzzle_count, 1);
    assert.deepEqual(defaults.materials, []);
  });

  await test('weapons is registered as a Schema 2.0 draft type and stays out of runtime types', () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'content_types.json'), 'utf8'));
    assert.equal(manifest.draft_schemas.weapons, 'schemas/v2/weapon.schema.json', 'weapons must point at the weapon schema');
    const entry = (manifest.draft_types || []).find((type) => type.key === 'weapons');
    assert.ok(entry, 'weapons must be listed in draft_types');
    assert.equal(entry.singular, 'weapon');
    assert.equal(entry.key_prefix, 'weapon');
    assert.equal(entry.group, 'ships_modules');
    assert.equal(entry.default_file, 'content/weapons.json');
    assert.equal(entry.schema_version, '2.0');
    assert.equal(entry.capability, 'content.combat.v1');
    const weaponSchema = globalThis.SN_SCHEMAS['v2/weapon.schema.json'];
    assert.equal(weaponSchema.properties.content_type.const, 'weapons', 'schema pins content_type weapons');
    assert.equal(weaponSchema.properties.schema_version.const, entry.schema_version, 'draft metadata matches the schema const');
    const combat = (manifest.planned || []).find((system) => system.capability === 'content.combat.v1');
    assert.ok(combat && combat.types.includes('weapons'), 'weapons stays planned under content.combat.v1');
    assert.ok(!Types.TYPES.some((type) => type.key === 'weapons'), 'the Godot runtime type list must not load weapons');
  });

  await test('story drafts satisfy their Schema 2.0 schemas and stay out of runtime types', () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'content_types.json'), 'utf8'));
    for (const key of ['story_arcs', 'story_levels']) {
      const entry = (manifest.draft_types || []).find((type) => type.key === key);
      assert.ok(entry, `${key} must be listed in draft_types`);
      assert.equal(entry.capability, 'content.story.v1', `${key} declares the story capability`);
      assert.equal(entry.schema_version, '2.0');
      const schemaFile = String(manifest.draft_schemas[key]).replace(/^schemas\//, '');
      const schema = globalThis.SN_SCHEMAS[schemaFile];
      assert.ok(schema, `${schemaFile} must be embedded in the schema bundle`);
      assert.equal(schema.properties.content_type.const, key, `${key} schema pins content_type`);
      assert.equal(schema.properties.schema_version.const, '2.0', `${key} schema pins schema_version`);
      assert.ok(!Types.TYPES.some((type) => type.key === key), 'the runtime type list must not load story drafts');
    }
    const story = (manifest.planned || []).find((system) => system.capability === 'content.story.v1');
    assert.ok(story, 'the story family stays planned under content.story.v1');
    assert.deepEqual(story.types, ['story_arcs', 'story_levels']);

    // Catalog defaults must pass the real draft schemas.
    for (const [typeKey, id, required] of [
      ['story_arcs', 'test_mod:story_arc/iron_tide', ['protagonist_id', 'characters', 'levels']],
      ['story_levels', 'test_mod:story_level/01_first_smoke', ['map', 'stages', 'narrative']],
    ]) {
      const info = Types.DRAFT_TYPES.find((item) => item.key === typeKey);
      const defaults = Catalog.DEFAULTS[typeKey]();
      const envelope = {
        schema_version: '2.0',
        content_type: typeKey,
        definitions: [{ id, name_key: `${typeKey}.test_mod.name`, enabled: true, data: defaults }],
      };
      const errors = Validate.validateSchema(envelope, globalThis.SN_SCHEMAS[info.schema], info.schema);
      assert.deepEqual(errors, [], `${typeKey} defaults must pass the draft schema: ${JSON.stringify(errors, null, 2)}`);
      for (const field of required) {
        assert.ok(Object.prototype.hasOwnProperty.call(defaults, field), `${typeKey} defaults must provide ${field}`);
      }
    }
  });

  await test('story example pack validates as a story-only mod', () => {
    const project = storyPackProject();
    assert.deepEqual(project.contentFiles.map((file) => file.content_type), ['story_arcs', 'story_levels']);
    assert.deepEqual(project.manifest.capabilities, ['content.story.v1'], 'the pack declares the story capability');
    const result = Validate.validateProject(project);
    assert.equal(result.counts.error, 0, JSON.stringify(errorsOf(result), null, 2));
    assert.deepEqual(
      warningsOf(result).map((issue) => issue.code),
      ['draft_content', 'draft_content'],
      'the sample pack may only warn that draft content is not loaded by the runtime'
    );
    const arc = project.contentFiles[0].definitions[0];
    assert.deepEqual(arc.data.levels, [
      'example_story_iron_tide:story_level/01_first_smoke',
      'example_story_iron_tide:story_level/02_homeward',
    ]);
  });

  await test('story semantics catch cast, checkpoint, beat, fixed map and whitelist mistakes', () => {
    const project = Store.createProject({
      id: 'story_mod',
      name: 'Story Mod',
      template: null,
      drafts: ['story_arcs', 'story_levels'],
    });
    const arcFile = project.contentFiles.find((file) => file.content_type === 'story_arcs');
    const levelFile = project.contentFiles.find((file) => file.content_type === 'story_levels');
    const arc = arcFile.definitions[0];
    const level = levelFile.definitions[0];
    const codes = () => new Set(Validate.validateProject(project).issues.map((issue) => issue.code));

    assert.ok(!codes().has('story_protagonist_unknown'), 'the starter keeps its protagonist in the cast');
    arc.data.protagonist_id = 'ghost';
    assert.ok(codes().has('story_protagonist_unknown'), 'an unknown protagonist must error');
    arc.data.protagonist_id = 'protagonist';

    arc.data.levels = ['story_mod:story_arc/other'];
    assert.ok(codes().has('story_arc_level_type'), 'an arc may only list story_level ids');
    arc.data.levels = [];

    level.data.stages = level.data.stages.map((stage) => Object.assign({}, stage, { checkpoint: false }));
    assert.ok(codes().has('story_level_checkpoint_missing'), 'a level without a checkpoint must error');
    level.data.stages[0].checkpoint = true;

    level.data.narrative.beats = [{
      id: 'oops',
      stage_id: 'missing_stage',
      dialogue: { title_key: 'story.placeholder.title', body_keys: ['story.placeholder.body'] },
    }];
    assert.ok(codes().has('story_beat_stage_unknown'), 'a beat on an unknown stage must error');
    level.data.narrative.beats = [];

    level.data.fail = { default_mode: 'level_start', allow: ['checkpoint'] };
    assert.ok(codes().has('story_fail_default_not_allowed'), 'default_mode outside allow must error');
    level.data.fail = { default_mode: 'checkpoint', allow: ['checkpoint', 'level_start'] };

    level.data.map.fixed.edges.push({ from: 'port_0', to: 'port_9', distance: 10, risk: 0.1 });
    assert.ok(codes().has('story_fixed_edge_port_unknown'), 'an edge to an unknown port must error');
    level.data.map.fixed.edges.pop();

    level.data.map.fixed.start_port = 'port_9';
    assert.ok(codes().has('story_fixed_start_port_unknown'), 'start_port must be a declared port');
    level.data.map.fixed.start_port = 'port_0';

    Store.addDefinition(project, 'goods', {});
    assert.ok(codes().has('story_pack_off_whitelist'), 'a story pack may not carry free-mode content');
  });

  await test('weapon form renders combat, assembly and economy fields with readable enums', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'weapons', {});
    added.definition.data.materials = [{ id: 'core:material/boiler_plate', amount: 2 }];
    const html = UI.renderDefinitionForm({
      project,
      typeKey: 'weapons',
      definition: added.definition,
      file: added.file,
      index: added.index,
      schemaFile: Catalog.BY_KEY.weapons.schema,
    });
    const paths = [
      'data.kind', 'data.damage', 'data.range', 'data.min_range', 'data.accuracy',
      'data.weapon_class', 'data.mount_class', 'data.assembly_profile',
      'data.has_yaw', 'data.has_pitch', 'data.has_muzzle', 'data.muzzle_count',
      'data.envelope_x', 'data.envelope_y', 'data.height', 'data.mount_scale',
      'data.tier', 'data.weight', 'data.purchase_price', 'data.craft_cost',
      'data.materials.0.id', 'data.materials.0.amount',
    ];
    for (const field of paths) {
      assert.ok(html.includes(`data-field="${field}"`), `weapon form must render ${field}`);
    }
    assert.ok(html.includes('直射 direct'), 'kind enum uses readable options');
    assert.ok(html.includes('轻型 Light'), 'weapon_class enum uses readable options');
    assert.ok(html.includes('偏航 + 俯仰 yaw_pitch'), 'assembly_profile enum uses readable options');
    assert.ok(!html.includes('undefined'), 'weapon form must not render undefined values');
  });

  await test('hull form renders weapon and rig socket mirror editors', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'hulls', {});
    const emptyHtml = UI.renderDefinitionForm({
      project,
      typeKey: 'hulls',
      definition: added.definition,
      file: added.file,
      index: added.index,
      schemaFile: Catalog.BY_KEY.hulls.schema,
    });
    assert.ok(emptyHtml.includes('data-action="array-add" data-path="data.weapon_sockets"'), 'hulls expose add-weapon-socket control');
    assert.ok(emptyHtml.includes('data-action="array-add" data-path="data.rig_sockets"'), 'hulls expose add-rig-socket control');

    added.definition.data.weapon_sockets = [{
      name: 'SN_Socket_Weapon_New_1',
      socket_class: 'Light',
      socket_index: 0,
      position: [0, 0, 0],
      clearance_r: 1,
      clearance_x: 1,
      clearance_y: 1,
      clearance_h: 20,
      mount_scale: 1,
    }];
    added.definition.data.rig_sockets = [{
      name: 'SN_Socket_Mast_New_1',
      socket_kind: 'mast',
      mast_id: 'fore',
      socket_index: 0,
      position: [0, 0, 0],
    }];
    const html = UI.renderDefinitionForm({
      project,
      typeKey: 'hulls',
      definition: added.definition,
      file: added.file,
      index: added.index,
      schemaFile: Catalog.BY_KEY.hulls.schema,
    });
    assert.ok(html.includes('data-socket-row="weapon"'), 'weapon socket rows use the socket row renderer');
    assert.ok(html.includes('data-socket-row="rig"'), 'rig socket rows use the socket row renderer');
    for (const field of [
      'data.weapon_sockets.0.name',
      'data.weapon_sockets.0.socket_class',
      'data.weapon_sockets.0.socket_index',
      'data.weapon_sockets.0.position.0',
      'data.weapon_sockets.0.position.1',
      'data.weapon_sockets.0.position.2',
      'data.weapon_sockets.0.clearance_r',
      'data.weapon_sockets.0.mount_scale',
      'data.rig_sockets.0.name',
      'data.rig_sockets.0.socket_kind',
      'data.rig_sockets.0.mast_id',
      'data.rig_sockets.0.socket_index',
      'data.rig_sockets.0.position.2',
      'data.rig_sockets.0.rig_height',
      'data.rig_sockets.0.rig_stowed',
    ]) {
      assert.ok(html.includes(`data-field="${field}"`), `hull form must render ${field}`);
    }
    assert.ok(html.includes('轻型 Light'), 'socket_class enum uses readable options');
    assert.ok(html.includes('桅杆 mast'), 'socket_kind enum uses readable options');
    assert.ok(!html.includes('undefined'), 'hull socket editor must not render undefined values');
  });

  await test('weapon semantics report range order, assembly pivot and muzzle problems', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'weapons', {});
    const data = added.definition.data;
    data.min_range = data.range;
    data.has_yaw = false;
    data.muzzle_count = 3;
    data.has_muzzle = false;
    data.weapon_class = 'Modular';
    const result = Validate.validateProject(project);
    const errorCodes = new Set(errorsOf(result).map((issue) => issue.code));
    assert.ok(errorCodes.has('weapon_range_order'), 'min_range >= range must report weapon_range_order');
    assert.ok(errorCodes.has('weapon_assembly_pivot'), 'yaw_pitch without has_yaw must report weapon_assembly_pivot');
    assert.ok(errorCodes.has('weapon_muzzle_count'), 'muzzle_count > 1 without has_muzzle must report weapon_muzzle_count');
    const warningCodes = new Set(warningsOf(result).map((issue) => issue.code));
    assert.ok(warningCodes.has('weapon_class_modular'), 'Modular weapons warn that they are kit parts');
  });

  await test('hull socket semantics report duplicates and unknown vocabularies', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'hulls', {});
    added.definition.data.weapon_sockets = [
      { name: 'SN_Socket_Weapon_Port_1', socket_class: 'Light', socket_index: 0 },
      { name: 'SN_Socket_Weapon_Port_1', socket_class: 'Giant', socket_index: 0 },
      { name: 'Weapon_Mount_3', socket_class: 'Light', socket_index: 2 },
    ];
    added.definition.data.rig_sockets = [
      { name: 'SN_Socket_Mast_Fore', socket_kind: 'mast', socket_index: 0 },
      { name: 'SN_Socket_Mast_Fore', socket_kind: 'rope', socket_index: 0 },
    ];
    const result = Validate.validateProject(project);
    const errorCodes = new Set(errorsOf(result).map((issue) => issue.code));
    assert.ok(errorCodes.has('socket_name_duplicate'), 'duplicate socket names must be an error');
    assert.ok(errorCodes.has('socket_index_duplicate'), 'duplicate socket indexes must be an error');
    const warningCodes = new Set(warningsOf(result).map((issue) => issue.code));
    assert.ok(warningCodes.has('socket_class_unknown'), 'unknown socket_class must warn');
    assert.ok(warningCodes.has('socket_kind_unknown'), 'unknown socket_kind must warn');
    assert.ok(warningCodes.has('socket_name_prefix'), 'non-standard socket names must warn');
    assert.ok(warningCodes.has('rig_socket_mast_id'), 'rig sockets without mast_id must warn');
  });

  await test('old hull content without socket mirrors stays free of socket issues', () => {
    const project = freshProject();
    Store.addDefinition(project, 'hulls', {});
    const result = Validate.validateProject(project);
    const socketIssues = result.issues.filter((issue) => (
      String(issue.code).startsWith('socket_') || issue.code === 'rig_socket_mast_id'
    ));
    assert.deepEqual(socketIssues, [], 'hulls without weapon_sockets / rig_sockets must not emit socket issues');
    assert.equal(errorsOf(result).length, 0, JSON.stringify(errorsOf(result), null, 2));
  });

  await test('draft files require schema 2.0 and 1.0 types keep 1.0', () => {
    const project = freshProject();
    Store.addDefinition(project, 'weapons', {});
    let result = Validate.validateProject(project);
    assert.equal(errorsOf(result).filter((issue) => issue.code === 'schema_version_mismatch').length, 0);

    const draftFile = project.contentFiles.find((file) => file.content_type === 'weapons');
    draftFile.schema_version = '1.0';
    result = Validate.validateProject(project);
    assert.ok(
      errorsOf(result).some((issue) => issue.code === 'schema_version_mismatch'),
      'a 2.0 draft file declaring 1.0 must report schema_version_mismatch'
    );

    draftFile.schema_version = '2.0';
    const legacyFile = project.contentFiles.find((file) => file.content_type === 'goods');
    legacyFile.schema_version = '2.0';
    result = Validate.validateProject(project);
    assert.ok(
      errorsOf(result).some((issue) => issue.code === 'schema_version_mismatch'),
      'a 1.0 type declaring 2.0 must report schema_version_mismatch'
    );

    legacyFile.schema_version = '1.0';
    draftFile.schema_version = '3.0';
    result = Validate.validateProject(project);
    assert.ok(
      errorsOf(result).some((issue) => issue.code === 'schema_version_unsupported'),
      'an unsupported schema version must be reported'
    );
    draftFile.schema_version = '2.0';
    result = Validate.validateProject(project);
    assert.equal(errorsOf(result).length, 0, JSON.stringify(errorsOf(result), null, 2));
  });

  await test('draft warnings: one draft_content per file and capability_undeclared per capability', () => {
    const project = freshProject();
    Store.addDefinition(project, 'weapons', {});
    let result = Validate.validateProject(project);

    const draftWarnings = warningsOf(result).filter((issue) => issue.code === 'draft_content');
    assert.equal(draftWarnings.length, 1, 'the weapons file gets exactly one draft_content warning');
    assert.equal(draftWarnings[0].view && draftWarnings[0].view.file, 'content/weapons.json');
    assert.match(draftWarnings[0].message, /Content Schema 1\.0/);

    const capabilityWarnings = warningsOf(result).filter((issue) => issue.code === 'capability_undeclared');
    assert.equal(capabilityWarnings.length, 1, 'the weapons capability warns once');
    assert.ok(capabilityWarnings[0].message.includes('content.combat.v1'));

    project.manifest.capabilities = ['content.combat.v1'];
    result = Validate.validateProject(project);
    assert.equal(
      warningsOf(result).filter((issue) => issue.code === 'capability_undeclared').length,
      0,
      'declaring the capability in manifest.capabilities silences the warning'
    );
    assert.equal(
      warningsOf(result).filter((issue) => issue.code === 'draft_content').length,
      1,
      'draft_content remains because the runtime still does not load draft content'
    );

    // Phase B promoted types are runtime types: they must not warn as drafts.
    const promoted = freshProject();
    Store.addDefinition(promoted, 'world_profiles', {});
    const promotedWarnings = warningsOf(Validate.validateProject(promoted));
    assert.equal(
      promotedWarnings.filter((issue) => issue.code === 'draft_content').length,
      0,
      'a promoted Schema 2.0 type is not draft content'
    );
  });

  await test('v2 draft schemas resolve cross-file $refs from v2/common.schema.json', () => {
    const project = freshProject();
    const added = Store.addDefinition(project, 'world_profiles', {});
    delete added.definition.enabled; // required by v2/common.schema.json#/$defs/definition
    added.definition.data.weather_profile = 'not-an-id'; // pattern from v2/common.schema.json#/$defs/id_ref
    const result = Validate.validateProject(project);
    const errors = errorsOf(result);
    assert.ok(
      errors.some((issue) => issue.code === 'schema_required' && issue.message.includes('enabled')),
      `missing enabled must be reported through the common definition $ref: ${JSON.stringify(errors)}`
    );
    assert.ok(
      errors.some((issue) => issue.code === 'schema_pattern' && String(issue.view && issue.view.field || '').includes('weather_profile')),
      `invalid id_ref must be reported through the common id_ref $ref: ${JSON.stringify(errors)}`
    );
  });

  await test('export and re-import preserves schema 2.0 alongside 1.0 content', () => {
    const project = freshProject();
    Store.addDefinition(project, 'start_profiles', {});
    const files = Store.toExportFiles(project);
    const draftFile = files.find((file) => file.path.endsWith('content/start_profiles.json'));
    const legacyFile = files.find((file) => file.path.endsWith('content/goods.json'));
    assert.ok(draftFile && legacyFile);
    assert.equal(JSON.parse(draftFile.data).schema_version, '2.0');
    assert.equal(JSON.parse(legacyFile.data).schema_version, '1.0', '1.0 content keeps its 1.0 envelope');

    const back = Store.fromFiles(files);
    assert.equal(back.project.contentFiles.find((file) => file.content_type === 'start_profiles').schema_version, '2.0');
    assert.equal(back.project.contentFiles.find((file) => file.content_type === 'goods').schema_version, '1.0');
    const validation = Validate.validateProject(back.project);
    assert.equal(validation.counts.error, 0, JSON.stringify(errorsOf(validation), null, 2));
    assert.ok(!warningsOf(validation).some((issue) => issue.code === 'draft_content'), 'promoted types are not draft content');
    assert.ok(!warningsOf(validation).some((issue) => issue.code === 'schema_version_mismatch'));
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

  await test('entity localization rename commits once and removes old keys', () => {
    const project = freshProject();
    const definition = project.contentFiles[0].definitions[0];
    const oldBase = 'good.test_mod.tea';
    const newBase = 'good.test_mod.black_tea';
    const zh = Store.getLoc(project, 'zh_CN');
    const en = Store.getLoc(project, 'en');
    assert.ok(zh.entries[`${oldBase}.name`]);
    definition.id = 'test_mod:good/black_tea';
    Store.commitDefinitionLocalization(project, definition, 'goods', oldBase, newBase, {
      zh_CN: { [`${newBase}.name`]: '红茶' },
      en: { [`${newBase}.name`]: 'Black tea' },
    });
    assert.equal(definition.name_key, `${newBase}.name`);
    assert.equal(zh.entries[`${newBase}.name`], '红茶');
    assert.equal(en.entries[`${newBase}.name`], 'Black tea');
    assert.equal(zh.entries[`${oldBase}.name`], undefined);
    assert.equal(en.entries[`${oldBase}.description`], undefined);

    const event = Store.addDefinition(project, 'events', { localId: 'fog' });
    const oldOptionKey = event.definition.data.options[0].name_key;
    event.definition.id = 'test_mod:event/thick_fog';
    Store.commitDefinitionLocalization(project, event.definition, 'events', 'event.test_mod.fog', 'event.test_mod.thick_fog', {});
    assert.equal(event.definition.data.options[0].name_key, oldOptionKey.replace('event.test_mod.fog', 'event.test_mod.thick_fog'));
    assert.equal(zh.entries[oldOptionKey], undefined);
    assert.ok(zh.entries[event.definition.data.options[0].name_key]);
  });

  await test('entity texture and GLB model references validate against assets', () => {
    const project = freshProject();
    const definition = project.contentFiles[0].definitions[0];
    Store.addAsset(project, {
      key: 'texture.tea', path: 'assets/icons/tea.webp', mime: 'image/webp', size: 1,
      dataUrl: 'data:image/webp;base64,AA==',
    });
    Store.addAsset(project, {
      key: 'model.tea', path: 'assets/models/tea.glb', mime: 'model/gltf-binary', size: 1,
      dataUrl: 'data:model/gltf-binary;base64,AA==',
    });
    Store.addAsset(project, {
      key: 'audio.bell', path: 'assets/audio/bell.ogg', mime: 'audio/ogg', size: 1,
      dataUrl: 'data:audio/ogg;base64,AA==',
    });
    const imagePicker = UI.assetPicker('information.texture', '', 'image', project);
    const modelPicker = UI.assetPicker('information.model', '', 'model', project);
    assert.ok(imagePicker.includes('texture.tea'));
    assert.ok(!imagePicker.includes('model.tea'));
    assert.ok(!imagePicker.includes('audio.bell'));
    assert.ok(modelPicker.includes('model.tea'));
    assert.ok(!modelPicker.includes('texture.tea'));
    assert.ok(!modelPicker.includes('audio.bell'));
    definition.information = { texture: 'texture.tea', model: 'model.tea' };
    let result = Validate.validateProject(project);
    assert.equal(result.counts.error, 0, JSON.stringify(errorsOf(result), null, 2));
    definition.information = { texture: 'asset://core/icon.coal', model: 'asset://core/model.ship.prototype' };
    result = Validate.validateProject(project);
    assert.equal(result.counts.error, 0, JSON.stringify(errorsOf(result), null, 2));
    definition.information.model = 'model.missing';
    result = Validate.validateProject(project);
    assert.ok(errorsOf(result).some((issue) => issue.code === 'entity_model_missing'));
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
    assert.equal(result.definition.information.model, 'asset://core/model.module.boiler');
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
    assert.equal(result.definition.information.model, 'asset://core/model.ship.paddle_steamer');
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
    // Every asset declared by the core manifest must be imported (icons, banner, entity GLBs).
    const coreManifest = JSON.parse(fs.readFileSync(path.join(coreRoot, 'manifest.json'), 'utf8'));
    assert.equal(
      result.project.assets.length,
      Object.keys(coreManifest.assets || {}).length,
      'every core manifest asset must be imported'
    );
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

  await test('generated content types match content_types.json', () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'content_types.json'), 'utf8'));
    const generated = globalThis.SNContentTypes;
    assert.deepEqual(generated.TYPES.map((type) => type.key), manifest.types.map((type) => type.key));
    const groupLabel = new Map(manifest.groups.map((group) => [group.id, group.label_zh]));
    for (let index = 0; index < generated.TYPES.length; index += 1) {
      const source = manifest.types[index];
      const type = generated.TYPES[index];
      assert.equal(type.singular, source.singular, `${source.key} singular`);
      assert.equal(type.schema, String(source.schema).replace(/^schemas\//, ''), `${source.key} schema`);
      assert.equal(type.keyPrefix, source.key_prefix, `${source.key} key prefix`);
      assert.equal(type.group, groupLabel.get(source.group), `${source.key} group label`);
      assert.equal(type.file, source.default_file, `${source.key} default file`);
      assert.equal(Boolean(type.special), source.kind === 'patch', `${source.key} patch marker`);
    }
    assert.equal(globalThis.SNCatalog.TYPES, generated.TYPES, 'catalog uses the generated type list');
  });

  await test('semver helper accepts prerelease and rejects leading zeros', () => {
    assert.ok(Validate.parseSemver('1.2.3-beta.1+build.5'));
    assert.equal(Validate.parseSemver('01.2.3'), null);
  });

  await test('parses a real GLB for thumbnail previews', () => {
    const file = path.join(__dirname, '..', '..', 'dev_mods', 'core', 'assets', 'models', 'ships', 'SN_Ship_Prototype.glb');
    const parsed = GLB.parse(fs.readFileSync(file));
    assert.ok(parsed.triangles > 0, 'has triangles');
    assert.ok(parsed.primitives.length > 0, 'has primitives');
    assert.ok(parsed.materials > 0, 'has materials');
    assert.ok(parsed.bbox.size.every((value) => value >= 0), 'bbox is valid');
    assert.ok(parsed.bbox.radius > 0, 'bbox has a radius');
    assert.ok(
      parsed.primitives.every((primitive) => primitive.positions.length > 0 && primitive.normals.length === primitive.positions.length),
      'primitives carry positions and normals',
    );
    assert.throws(() => GLB.parse(new Uint8Array(32)), /GLB|glTF/);
  });

  await test('game mods dir defaults to the release package mods folder', async () => {
    const { pathToFileURL } = require('node:url');
    const { resolveGameModsDir } = await import(pathToFileURL(path.join(__dirname, '..', 'tools', 'game_mods_dir.mjs')).href);
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'snmod-paths-'));
    try {
      const root = path.join(temp, 'SNModMaker');
      fs.mkdirSync(root, { recursive: true });
      fs.mkdirSync(path.join(temp, 'dist', 'build', 'windows'), { recursive: true });
      assert.equal(
        resolveGameModsDir(root, { env: {}, platform: 'win32', exists: fs.existsSync }),
        path.join(temp, 'dist', 'build', 'windows', 'mods'),
      );
      assert.equal(
        resolveGameModsDir(root, { env: { SNMODMAKER_GAME_MODS_DIR: path.join(temp, 'custom') }, platform: 'win32', exists: fs.existsSync }),
        path.join(temp, 'custom'),
      );
      const emptyRoot = path.join(temp, 'empty', 'SNModMaker');
      fs.mkdirSync(emptyRoot, { recursive: true });
      assert.equal(
        resolveGameModsDir(emptyRoot, { env: {}, platform: 'linux', exists: fs.existsSync }),
        path.join(temp, 'empty', 'dist', 'build', 'linux', 'mods'),
      );
    } finally {
      fs.rmSync(temp, { recursive: true, force: true });
    }
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
