/*
 * Project model, templates, import/export mapping and small helpers.
 *
 * A project stores logical files, never derived UI state:
 *   { uid, manifest, contentFiles[], localization[], assets[], meta }
 * Manifest content/localization/assets arrays are always rebuilt from those
 * collections so the editor cannot drift from what is exported.
 */
(function (root) {
  'use strict';

  const FORMAT = 'steam-navigator-mod-maker';
  const FORMAT_VERSION = 1;
  const MANIFEST_SCHEMA_URL = 'https://steam-navigator.local/schema/mod-manifest-1.json';
  const DEFAULT_OPTION_NAMES = {
    endure: { zh: '硬撑过去', en: 'Endure' },
    repair: { zh: '靠港修理', en: 'Repair' },
    salvage: { zh: '打捞货箱', en: 'Salvage the crate' },
    leave: { zh: '保持航向', en: 'Keep course' },
  };

  function catalog() {
    return root.SNCatalog;
  }

  function deepClone(value) {
    return value == null ? value : JSON.parse(JSON.stringify(value));
  }

  function uid() {
    if (root.crypto && typeof root.crypto.randomUUID === 'function') return root.crypto.randomUUID();
    return `p-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
  }

  function slugify(text, fallback) {
    const slug = String(text || '')
      .toLowerCase()
      .normalize('NFKD')
      .replace(/[^a-z0-9_]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .replace(/_{2,}/g, '_');
    if (!slug) return fallback || 'item';
    return /^[a-z]/.test(slug) ? slug : `m_${slug}`;
  }

  function localPart(id) {
    const text = String(id || '');
    const slash = text.indexOf('/');
    return slash >= 0 ? text.slice(slash + 1) : '';
  }

  function namespaceOf(id) {
    return String(id || '').split(':')[0];
  }

  function keyBase(typeKey, modId, localId) {
    const info = catalog().BY_KEY[typeKey];
    return `${info ? info.keyPrefix : typeKey}.${modId}.${localId}`;
  }

  /**
   * The localization base a definition actually uses. Imported content (including
   * core) does not always derive keys from the local ID, so trust name_key first.
   */
  function keyBaseOf(definition, typeKey, modId, localId) {
    const nameKey = definition && definition.name_key;
    if (typeof nameKey === 'string' && nameKey.endsWith('.name') && nameKey.length > 5) {
      return nameKey.slice(0, -'.name'.length);
    }
    return keyBase(typeKey, modId, localId);
  }

  function blankManifest(id, name) {
    return {
      $schema: MANIFEST_SCHEMA_URL,
      id,
      name,
      version: '1.0.0',
      api_version: '1.0',
      type: 'content',
      load_priority: 10,
      required: false,
      dependencies: [{ id: 'core', version: '>=1.0.0 <2.0.0' }],
      optional_dependencies: [],
      conflicts: [],
      content: [],
      localization: [],
      assets: {},
      authors: [],
      license: 'CC-BY-4.0',
      description: '',
      capabilities: [],
    };
  }

  function createProject(options) {
    const opts = options || {};
    const id = opts.id || 'my_mod';
    const name = opts.name || 'My Content Mod';
    const project = {
      format: FORMAT,
      formatVersion: FORMAT_VERSION,
      uid: uid(),
      manifest: blankManifest(id, name),
      contentFiles: [],
      localization: [],
      assets: [],
      meta: { createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(), template: opts.template || 'goods' },
    };
    if (opts.dependencies === false) project.manifest.dependencies = [];
    if (opts.description) project.manifest.description = opts.description;
    if (Array.isArray(opts.authors) && opts.authors.length) project.manifest.authors = opts.authors.slice();

    addLocale(project, 'zh_CN');
    addLocale(project, 'en');
    applyTemplate(project, opts.template || 'goods');

    if (!project.contentFiles.length) {
      addDefinition(project, 'goods', { localId: 'starter_good', nameZh: '起始商品', nameEn: 'Starter Good' });
    }
    syncManifest(project);
    return project;
  }

  function applyTemplate(project, templateKey) {
    const key = templateKey || 'goods';
    if (key === 'goods' || key === 'blank') {
      addDefinition(project, 'goods', {
        localId: 'tea',
        nameZh: '茶叶',
        nameEn: 'Tea',
        descriptionZh: '来自东方港口的轻便饮品，适合填充剩余舱位。',
        descriptionEn: 'A light beverage from eastern ports, good for filling spare capacity.',
        tags: ['good.trade', 'good.consumer'],
        data: {
          unit_weight: 0.8,
          base_price: 95,
          base_stock: 60,
          price_elasticity: 0.16,
          spawn_weight: 0.8,
          category: 'beverage',
        },
      });
      return;
    }
    if (key === 'boiler') {
      addDefinition(project, 'boilers', {
        localId: 'compound_economizer',
        nameZh: '复合省煤锅炉',
        nameEn: 'Compound Economizer Boiler',
        descriptionZh: '二级锅炉：航速略高于标准锅炉，同时显著节省煤水。',
        descriptionEn: 'A tier-2 boiler with better speed and noticeably lower coal/water use.',
        tags: ['module.boiler', 'module.efficient'],
        data: {
          tier: 2,
          weight: 9,
          purchase_price: 520,
          craft_time_hours: 6,
          craft_cost: 80,
          materials: [{ id: 'core:good/brass', amount: 3 }],
          speed_mul: 1.02,
          coal_rate: 0.33,
          water_rate: 0.24,
        },
      });
      return;
    }
    if (key === 'event') {
      addDefinition(project, 'events', {
        localId: 'drifting_wreck',
        nameZh: '风暴后的漂流物',
        nameEn: 'Wreck After the Storm',
        descriptionZh: '风暴过后，海面漂来一只无人货箱。',
        descriptionEn: 'After the storm, an abandoned crate drifts alongside.',
        tags: ['event.opportunity', 'event.merchant'],
        optionNamesZh: { salvage: '打捞货箱', leave: '保持航向' },
        optionNamesEn: { salvage: 'Salvage the crate', leave: 'Keep course' },
        localeExtras: {
          zh_CN: {
            'notice.mod.drifting_wreck.salvaged': '你打捞了漂流货箱，获得 4 单位木材。',
            'notice.mod.drifting_wreck.left': '你决定保持航向，漂流物消失在雾中。',
          },
          en: {
            'notice.mod.drifting_wreck.salvaged': 'You salvage the drifting crate and recover 4 units of timber.',
            'notice.mod.drifting_wreck.left': 'You keep your course and the wreck fades into the fog.',
          },
        },
        data: {
          trigger: 'voyage_opportunity',
          category: 'merchant',
          weight: 1,
          base_delay_hours: 0,
          options: [
            {
              id: 'salvage',
              name_key: '',
              weight: 1,
              effects: [
                { op: 'add_item', item_id: 'core:good/timber', amount: 4 },
                { op: 'add_delay_hours', amount: 1 },
                { op: 'emit_notice', text_key: 'notice.mod.drifting_wreck.salvaged' },
              ],
            },
            {
              id: 'leave',
              name_key: '',
              weight: 1,
              effects: [{ op: 'emit_notice', text_key: 'notice.mod.drifting_wreck.left' }],
            },
          ],
        },
      });
      return;
    }
    if (key === 'starter_kit') {
      applyTemplate(project, 'goods');
      applyTemplate(project, 'boiler');
      applyTemplate(project, 'event');
      addDefinition(project, 'contracts', {
        localId: 'sample_run',
        nameZh: '样品运输',
        nameEn: 'Sample Run',
        descriptionZh: '把一箱样品送到相邻港口。',
        descriptionEn: 'Carry a crate of samples to a neighbouring port.',
        tags: ['contract.normal', 'contract.cargo'],
        data: {
          kind: 'normal',
          sequence: 0,
          generator: 'route_pair',
          constraints: {
            requires_discovered_origin: true,
            min_route_edges: 1,
            max_route_edges: 2,
            required_port_tags: [],
          },
          payloads: [{ kind: 'cargo', weight_range: [8, 14], name_key: '' }],
          deadline_formula: 'normal_standard',
          rewards: {
            base_money: [180, 320],
            on_time_bonus: [80, 160],
            reputation: 1,
            unlock_ids: [],
          },
        },
      });
    }
  }

  function ensureContentFile(project, typeKey) {
    const info = catalog().BY_KEY[typeKey];
    if (!info) throw new Error(`未知内容类型: ${typeKey}`);
    const existing = project.contentFiles.find((file) => file.content_type === typeKey);
    if (existing) return existing;
    let path = info.file;
    let counter = 2;
    while (project.contentFiles.some((file) => file.path === path)) {
      path = info.file.replace(/\.json$/, `_${counter}.json`);
      counter += 1;
    }
    const file = {
      path,
      content_type: typeKey,
      schema_version: '1.0',
      definitions: [],
    };
    project.contentFiles.push(file);
    syncManifest(project);
    return file;
  }

  function allDefinitions(project) {
    const list = [];
    for (const file of project.contentFiles) {
      (file.definitions || []).forEach((definition, index) => {
        list.push({ file, index, definition });
      });
    }
    return list;
  }

  function definitionIdSet(project) {
    const set = new Set();
    for (const item of allDefinitions(project)) {
      if (item.definition && typeof item.definition.id === 'string') set.add(item.definition.id);
    }
    return set;
  }

  function uniqueLocalId(project, typeKey, preferred) {
    const info = catalog().BY_KEY[typeKey];
    const base = slugify(preferred || 'new_item', 'new_item');
    const used = new Set();
    for (const item of allDefinitions(project)) {
      const itemInfo = catalog().BY_KEY[item.file.content_type];
      if (item.file.content_type !== typeKey && (!itemInfo || itemInfo.keyPrefix !== info.keyPrefix)) continue;
      used.add(localPart(item.definition.id));
    }
    let candidate = base;
    let counter = 2;
    while (used.has(candidate)) {
      candidate = `${base}_${counter}`;
      counter += 1;
    }
    return candidate;
  }

  function getLoc(project, locale) {
    return project.localization.find((entry) => entry.locale === locale) || null;
  }

  function addLocale(project, locale, path) {
    const clean = String(locale || '').trim();
    if (!clean) return null;
    let entry = getLoc(project, clean);
    if (entry) return entry;
    entry = {
      path: path || `localization/${clean}.json`,
      locale: clean,
      entries: {},
    };
    project.localization.push(entry);
    syncManifest(project);
    return entry;
  }

  function removeLocale(project, locale) {
    project.localization = project.localization.filter((entry) => entry.locale !== locale);
    syncManifest(project);
  }

  function setLocalization(project, locale, key, value) {
    const entry = getLoc(project, locale) || addLocale(project, locale);
    if (!key) return;
    if (value == null || value === '') delete entry.entries[key];
    else entry.entries[key] = String(value);
    touch(project);
  }

  function collectAutoNameKeys(definition) {
    const keys = new Set();
    const walk = (value, depth) => {
      if ((depth || 0) > 24 || value == null) return;
      if (Array.isArray(value)) {
        value.forEach((item) => walk(item, (depth || 0) + 1));
        return;
      }
      if (typeof value === 'object') {
        for (const [key, child] of Object.entries(value)) {
          if (key === 'name_key' && typeof child === 'string' && child.trim()) keys.add(child);
          else walk(child, (depth || 0) + 1);
        }
      }
    };
    walk(definition, 0);
    return keys;
  }

  function collectDefinitionKeys(definition) {
    const keys = new Set();
    const walk = (value, depth) => {
      if ((depth || 0) > 24 || value == null) return;
      if (Array.isArray(value)) {
        value.forEach((item) => walk(item, (depth || 0) + 1));
        return;
      }
      if (typeof value === 'object') {
        for (const [key, child] of Object.entries(value)) {
          if (typeof child === 'string' && key.endsWith('_key') && child.trim()) keys.add(child);
          else walk(child, (depth || 0) + 1);
        }
      }
    };
    walk(definition, 0);
    return keys;
  }

  function fillNestedKeys(definition, typeKey, modId, localId) {
    const base = keyBase(typeKey, modId, localId);
    const data = definition.data || {};
    if (Array.isArray(data.options)) {
      data.options.forEach((option, index) => {
        const suffix = option && option.id ? option.id : `option_${index + 1}`;
        if (option && !option.name_key) option.name_key = `${base}.${suffix}`;
      });
    }
    if (Array.isArray(data.payloads)) {
      data.payloads.forEach((payload, index) => {
        if (payload && !payload.name_key && data.payloads.length > 1) {
          payload.name_key = `${base}.payload_${index + 1}`;
        }
      });
    }
  }

  function addDefinition(project, typeKey, options) {
    const opts = options || {};
    const info = catalog().BY_KEY[typeKey];
    if (!info) throw new Error(`未知内容类型: ${typeKey}`);
    const file = opts.filePath
      ? project.contentFiles.find((item) => item.path === opts.filePath)
      : ensureContentFile(project, typeKey);
    if (!file) throw new Error(`找不到内容文件: ${opts.filePath}`);
    const modId = project.manifest.id;
    const localId = uniqueLocalId(project, typeKey, opts.localId);
    let definition;
    if (typeKey === 'patches') {
      definition = {
        target: opts.target || 'core:boiler/small_efficient',
        requires: { mod: 'core', version: '>=1.0.0 <2.0.0' },
        operations: [{ op: 'replace', path: '/data/purchase_price', value: 380 }],
      };
    } else {
      const base = keyBase(typeKey, modId, localId);
      const defaults = catalog().DEFAULTS[typeKey];
      definition = {
        id: `${modId}:${info.singular}/${localId}`,
        name_key: `${base}.name`,
        description_key: `${base}.description`,
        tags: Array.isArray(opts.tags) && opts.tags.length ? opts.tags.slice() : [catalog().TAG_SUGGESTIONS[typeKey] && catalog().TAG_SUGGESTIONS[typeKey][0] || `${info.singular}.custom`],
        enabled: true,
        data: deepClone(opts.data || (defaults ? defaults() : {})),
      };
      if (opts.descriptionKey === false) delete definition.description_key;
      fillNestedKeys(definition, typeKey, modId, localId);
    }
    file.definitions.push(definition);
    const index = file.definitions.length - 1;

    if (typeKey !== 'patches') {
      const nameZh = opts.nameZh || `新${info.label}`;
      const nameEn = opts.nameEn || `New ${info.en}`;
      const descZh = opts.descriptionZh || `在 Steam Navigator 中新增的${info.label}。`;
      const descEn = opts.descriptionEn || `A new ${info.en.toLowerCase()} for Steam Navigator.`;
      const zh = getLoc(project, 'zh_CN') || addLocale(project, 'zh_CN');
      const en = getLoc(project, 'en') || addLocale(project, 'en');
      const keys = collectDefinitionKeys(definition);
      const autoKeys = collectAutoNameKeys(definition);
      for (const key of keys) {
        if (key === definition.name_key) {
          zh.entries[key] = nameZh;
          en.entries[key] = nameEn;
        } else if (key === definition.description_key) {
          zh.entries[key] = descZh;
          en.entries[key] = descEn;
        } else if (autoKeys.has(key)) {
          const suffix = key.slice(key.lastIndexOf('.') + 1);
          const known = DEFAULT_OPTION_NAMES[suffix];
          if (!(key in zh.entries)) zh.entries[key] = opts.optionNamesZh?.[suffix] || (known && known.zh) || suffix.replace(/_/g, ' ');
          if (!(key in en.entries)) en.entries[key] = opts.optionNamesEn?.[suffix] || (known && known.en) || suffix.replace(/_/g, ' ');
        }
      }
      if (opts.localeExtras) {
        for (const locale of Object.keys(opts.localeExtras)) {
          const target = locale === 'zh_CN' ? zh : locale === 'en' ? en : (getLoc(project, locale) || addLocale(project, locale));
          for (const [key, text] of Object.entries(opts.localeExtras[locale] || {})) {
            target.entries[key] = text;
          }
        }
      }
    }

    syncManifest(project);
    touch(project);
    return { file, index, definition, localId };
  }

  function removeDefinition(project, filePath, index) {
    const file = project.contentFiles.find((item) => item.path === filePath);
    if (!file || index < 0 || index >= file.definitions.length) return;
    file.definitions.splice(index, 1);
    if (file.definitions.length === 0) {
      project.contentFiles = project.contentFiles.filter((item) => item !== file);
    }
    syncManifest(project);
    touch(project);
  }

  function rewriteKeyBase(value, oldBase, newBase) {
    if (typeof value === 'string') {
      if (value === oldBase || value.startsWith(`${oldBase}.`)) return newBase + value.slice(oldBase.length);
      return value;
    }
    if (Array.isArray(value)) {
      value.forEach((item, index) => {
        value[index] = rewriteKeyBase(item, oldBase, newBase);
      });
      return value;
    }
    if (value && typeof value === 'object') {
      for (const key of Object.keys(value)) {
        if (typeof value[key] === 'string' && key.endsWith('_key')) {
          if (value[key] === oldBase || value[key].startsWith(`${oldBase}.`)) {
            value[key] = newBase + value[key].slice(oldBase.length);
          }
        } else {
          value[key] = rewriteKeyBase(value[key], oldBase, newBase);
        }
      }
    }
    return value;
  }

  /**
   * Commit an editor localization transaction after an entity ID changes.
   * Definition keys and every locale move together, so intermediate ID edits
   * never leave copied keys behind. Translation overrides are keyed by locale
   * and by their final localization key.
   */
  function commitDefinitionLocalization(project, definition, typeKey, oldBase, newBase, translations) {
    const sourceBase = String(oldBase || '').trim();
    const targetBase = String(newBase || '').trim();
    if (!project || !definition || !sourceBase || !targetBase) {
      throw new Error('无法保存多语言键：键前缀不完整');
    }

    const movesByLocale = [];
    for (const locale of project.localization || []) {
      const entries = locale.entries || {};
      const moves = Object.keys(entries)
        .filter((key) => key === sourceBase || key.startsWith(`${sourceBase}.`))
        .map((key) => ({ from: key, to: targetBase + key.slice(sourceBase.length), value: entries[key] }));
      for (const move of moves) {
        if (move.to !== move.from && Object.prototype.hasOwnProperty.call(entries, move.to)
            && !moves.some((candidate) => candidate.from === move.to)) {
          throw new Error(`无法保存多语言键：${locale.locale} 已存在 ${move.to}`);
        }
      }
      movesByLocale.push({ locale, moves });
    }

    rewriteKeyBase(definition, sourceBase, targetBase);
    for (const { locale, moves } of movesByLocale) {
      const entries = locale.entries || (locale.entries = {});
      for (const move of moves) {
        if (move.from !== move.to) delete entries[move.from];
      }
      for (const move of moves) entries[move.to] = move.value;
      const localeOverrides = translations && translations[locale.locale];
      for (const [key, value] of Object.entries(localeOverrides || {})) {
        if (value == null || value === '') delete entries[key];
        else entries[key] = String(value);
      }
    }
    syncManifest(project);
    touch(project);
    return { oldBase: sourceBase, newBase: targetBase };
  }

  function duplicateDefinition(project, filePath, index) {
    const file = project.contentFiles.find((item) => item.path === filePath);
    if (!file) return null;
    const source = file.definitions[index];
    if (!source) return null;
    const clone = deepClone(source);
    const typeKey = file.content_type;
    if (typeKey === 'patches') {
      file.definitions.splice(index + 1, 0, clone);
      syncManifest(project);
      touch(project);
      return { file, index: index + 1, definition: clone };
    }
    const info = catalog().BY_KEY[typeKey];
    const modId = project.manifest.id;
    const oldLocal = localPart(source.id);
    const newLocal = uniqueLocalId(project, typeKey, `${oldLocal}_copy`);
    const oldBase = keyBaseOf(source, typeKey, modId, oldLocal);
    const newBase = keyBase(typeKey, modId, newLocal);
    rewriteKeyBase(clone, oldBase, newBase);
    clone.id = `${modId}:${info.singular}/${newLocal}`;
    for (const locale of ['zh_CN', 'en']) {
      const entry = getLoc(project, locale);
      if (!entry) continue;
      for (const [key, value] of Object.entries(entry.entries)) {
        if (key === oldBase + '.name') entry.entries[newBase + '.name'] = `${value}${locale === 'zh_CN' ? '（副本）' : ' (copy)'}`;
        else if (key.startsWith(`${oldBase}.`) || key === oldBase) {
          const nextKey = newBase + key.slice(oldBase.length);
          entry.entries[nextKey] = value;
        }
      }
    }
    file.definitions.splice(index + 1, 0, clone);
    syncManifest(project);
    touch(project);
    return { file, index: index + 1, definition: clone };
  }

  function coreIndex() {
    return root.SN_CORE_INDEX;
  }

  function qualifyCoreAssetReferences(definition) {
    const information = definition && definition.information;
    if (!information || typeof information !== 'object') return;
    for (const field of ['texture', 'model']) {
      const value = String(information[field] || '').trim();
      if (value && !value.startsWith('asset://')) information[field] = `asset://core/${value}`;
    }
  }

  function cloneCoreDefinition(project, coreDefinitionId) {
    const index = coreIndex();
    if (!index) return null;
    const source = index.definitions.find((item) => item.id === coreDefinitionId);
    if (!source) return null;
    const typeKey = source.content_type;
    const info = catalog().BY_KEY[typeKey];
    if (!info) return null;
    const file = ensureContentFile(project, typeKey);
    const modId = project.manifest.id;
    const coreLocal = localPart(source.id);
    const newLocal = uniqueLocalId(project, typeKey, `${coreLocal}_copy`);
    const clone = deepClone(source.definition);
    const oldBase = keyBaseOf(source.definition, typeKey, 'core', coreLocal);
    const newBase = keyBase(typeKey, modId, newLocal);
    rewriteKeyBase(clone, oldBase, newBase);
    qualifyCoreAssetReferences(clone);
    clone.id = `${modId}:${info.singular}/${newLocal}`;
    file.definitions.push(clone);
    const indexInFile = file.definitions.length - 1;

    for (const locale of ['zh_CN', 'en']) {
      const target = getLoc(project, locale) || addLocale(project, locale);
      const sourceLoc = (index.localization && index.localization[locale]) || {};
      for (const [key, value] of Object.entries(sourceLoc)) {
        if (key.startsWith(`${oldBase}.`)) target.entries[newBase + key.slice(oldBase.length)] = value;
      }
      if (target.entries[newBase + '.name']) {
        target.entries[newBase + '.name'] += locale === 'zh_CN' ? '（副本）' : ' (copy)';
      } else {
        target.entries[newBase + '.name'] = locale === 'zh_CN'
          ? (source.name_zh || `新${info.label}`)
          : (source.name_en || `New ${info.en}`);
      }
      if (!(newBase + '.description' in target.entries)) {
        target.entries[newBase + '.description'] = locale === 'zh_CN'
          ? `复制自 core 的${info.label}，可按需调整数值。`
          : `Copied from core; adjust the values as needed.`;
      }
    }
    syncManifest(project);
    touch(project);
    return { file, index: indexInFile, definition: clone, localId: newLocal };
  }

  function addAsset(project, asset) {
    if (!asset || !asset.path) return null;
    const existing = project.assets.find((item) => item.path === asset.path);
    if (existing) Object.assign(existing, asset);
    else project.assets.push(asset);
    syncManifest(project);
    touch(project);
    return asset;
  }

  function removeAsset(project, path) {
    project.assets = project.assets.filter((item) => item.path !== path);
    syncManifest(project);
    touch(project);
  }

  function syncManifest(project) {
    if (!project || !project.manifest) return;
    project.contentFiles = project.contentFiles || [];
    project.localization = project.localization || [];
    project.assets = project.assets || [];
    project.manifest.type = 'content';
    if (project.manifest.id !== 'core') project.manifest.required = false;
    project.manifest.content = project.contentFiles.map((file) => file.path);
    project.manifest.localization = project.localization.map((entry) => entry.path);
    project.manifest.assets = {};
    for (const asset of project.assets) {
      if (!asset.path) continue;
      const key = asset.key || `asset.${slugify(asset.path.split('/').pop() || 'file', 'file')}`;
      asset.key = key;
      project.manifest.assets[key] = asset.path;
    }
  }

  function touch(project) {
    if (!project.meta) project.meta = {};
    project.meta.updatedAt = new Date().toISOString();
  }

  function normalizeProject(raw, options) {
    if (!raw || typeof raw !== 'object') throw new Error('项目文件为空');
    const project = deepClone(raw);
    const shouldSync = !options || options.sync !== false;
    project.format = FORMAT;
    project.formatVersion = FORMAT_VERSION;
    project.uid = project.uid || uid();
    project.manifest = project.manifest || blankManifest('my_mod', 'My Content Mod');
    if (project.manifest.checksum === '') delete project.manifest.checksum;
    project.contentFiles = Array.isArray(project.contentFiles) ? project.contentFiles : [];
    project.localization = Array.isArray(project.localization) ? project.localization : [];
    project.assets = Array.isArray(project.assets) ? project.assets : [];
    project.meta = project.meta || {};
    project.meta.createdAt = project.meta.createdAt || new Date().toISOString();
    project.meta.updatedAt = project.meta.updatedAt || new Date().toISOString();
    for (const file of project.contentFiles) {
      file.definitions = Array.isArray(file.definitions) ? file.definitions : [];
      file.schema_version = file.schema_version || '1.0';
    }
    for (const entry of project.localization) {
      entry.entries = entry.entries && typeof entry.entries === 'object' ? entry.entries : {};
      entry.locale = entry.locale || String(entry.path || '').split('/').pop().replace(/\.json$/, '');
    }
    if (shouldSync) syncManifest(project);
    return project;
  }

  function serialize(project) {
    return JSON.stringify(normalizeProject(deepClone(project)), null, 2);
  }

  function deserialize(text) {
    return normalizeProject(JSON.parse(text));
  }

  function bytesToBase64(bytes) {
    let binary = '';
    const chunk = 0x8000;
    for (let i = 0; i < bytes.length; i += chunk) {
      binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
    }
    return root.btoa ? root.btoa(binary) : Buffer.from(bytes).toString('base64');
  }

  function base64ToBytes(base64) {
    const clean = String(base64 || '').replace(/^data:[^;]+;base64,/, '');
    if (!clean) return new Uint8Array(0);
    const binary = root.atob ? root.atob(clean) : Buffer.from(clean, 'base64').toString('binary');
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
    return bytes;
  }

  function mimeFor(path) {
    const ext = String(path).split('.').pop().toLowerCase();
    return {
      png: 'image/png',
      webp: 'image/webp',
      svg: 'image/svg+xml',
      ogg: 'audio/ogg',
      wav: 'audio/wav',
      glb: 'model/gltf-binary',
      json: 'application/json',
    }[ext] || 'application/octet-stream';
  }

  function bytesToDataUrl(bytes, mime) {
    return `data:${mime || 'application/octet-stream'};base64,${bytesToBase64(bytes)}`;
  }

  function dataUrlToBytes(dataUrl) {
    return base64ToBytes(dataUrl);
  }

  function decodeText(data) {
    const text = typeof data === 'string' ? data : new TextDecoder('utf-8').decode(data);
    return text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
  }

  function encodeText(text) {
    return new TextEncoder().encode(String(text));
  }

  /** Materialize the mod as [{path,data}] ready for ZIP or folder export. */
  function toExportFiles(project, options) {
    const opts = options || {};
    const prefix = opts.prefix === false ? '' : `mods/${project.manifest.id}/`;
    const files = [];
    const manifest = deepClone(project.manifest);
    manifest.$schema = MANIFEST_SCHEMA_URL;
    syncManifest(project);
    files.push({ path: `${prefix}manifest.json`, data: `${JSON.stringify(manifest, null, 2)}\n` });
    for (const file of project.contentFiles) {
      const payload = {
        schema_version: file.schema_version || '1.0',
        content_type: file.content_type,
        definitions: file.definitions || [],
      };
      files.push({ path: `${prefix}${file.path}`, data: `${JSON.stringify(payload, null, 2)}\n` });
    }
    for (const entry of project.localization) {
      files.push({ path: `${prefix}${entry.path}`, data: `${JSON.stringify(entry.entries || {}, null, 2)}\n` });
    }
    for (const asset of project.assets) {
      if (!asset.dataUrl) continue;
      files.push({ path: `${prefix}${asset.path}`, data: dataUrlToBytes(asset.dataUrl) });
    }
    return files;
  }

  function stripRoot(paths) {
    const manifestCandidates = paths.filter((path) => path === 'manifest.json' || path.endsWith('/manifest.json'));
    if (!manifestCandidates.length) return null;
    manifestCandidates.sort((a, b) => a.split('/').length - b.split('/').length);
    const manifestPath = manifestCandidates[0];
    const prefix = manifestPath.slice(0, -'manifest.json'.length);
    return { manifestPath, prefix };
  }

  /**
   * Build a project from loose files.
   * @param {Array<{path:string,data:Uint8Array|string}>} entries
   */
  function fromFiles(entries) {
    const warnings = [];
    const byPath = new Map();
    for (const entry of entries) {
      const path = String(entry.path || '').replace(/\\/g, '/').replace(/^\/+/, '');
      if (!path) continue;
      byPath.set(path, entry);
    }
    const rootInfo = stripRoot([...byPath.keys()]);
    if (!rootInfo) throw new Error('没有找到 manifest.json，请选择模组根目录或 .snavmod.zip。');
    const normalize = (path) => (path.startsWith(rootInfo.prefix) ? path.slice(rootInfo.prefix.length) : path);
    const readJson = (path) => {
      const entry = byPath.get(path) || byPath.get(rootInfo.prefix + path);
      if (!entry) return null;
      try {
        return JSON.parse(decodeText(entry.data));
      } catch (error) {
        throw new Error(`${normalize(path)} 不是合法 JSON：${error.message}`);
      }
    };

    const manifestEntry = byPath.get(rootInfo.manifestPath);
    let manifest;
    try {
      manifest = JSON.parse(decodeText(manifestEntry.data));
    } catch (error) {
      throw new Error(`manifest.json 不是合法 JSON：${error.message}`);
    }
    const project = normalizeProject({
      format: FORMAT,
      formatVersion: FORMAT_VERSION,
      uid: uid(),
      manifest,
      contentFiles: [],
      localization: [],
      assets: [],
      meta: { createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(), importedFrom: rootInfo.prefix || 'folder' },
    }, { sync: false });

    project.contentFiles = [];
    for (const path of manifest.content || []) {
      const payload = readJson(path);
      if (!payload) {
        warnings.push(`Manifest 声明的内容文件不存在：${path}`);
        project.contentFiles.push({ path, content_type: 'goods', schema_version: '1.0', definitions: [] });
        continue;
      }
      const contentType = payload.content_type;
      if (!catalog().BY_KEY[contentType]) {
        warnings.push(`跳过未知内容类型 "${contentType}"：${path}`);
        continue;
      }
      project.contentFiles.push({
        path,
        content_type: contentType,
        schema_version: payload.schema_version || '1.0',
        definitions: Array.isArray(payload.definitions) ? payload.definitions : [],
      });
    }

    project.localization = [];
    for (const path of manifest.localization || []) {
      if (/\.csv$/i.test(path)) {
        warnings.push(`暂不支持 CSV 本地化，已跳过：${path}`);
        continue;
      }
      const entriesObj = readJson(path);
      if (!entriesObj) {
        warnings.push(`Manifest 声明的本地化文件不存在：${path}`);
        project.localization.push({ path, locale: String(path).split('/').pop().replace(/\.json$/, ''), entries: {} });
        continue;
      }
      const locale = String(path).split('/').pop().replace(/\.json$/, '');
      project.localization.push({
        path,
        locale,
        entries: entriesObj && typeof entriesObj === 'object' ? entriesObj : {},
      });
    }

    project.assets = [];
    for (const [key, path] of Object.entries(manifest.assets || {})) {
      const entry = byPath.get(path) || byPath.get(rootInfo.prefix + path);
      if (!entry) {
        warnings.push(`Manifest 声明的资源不存在：${path}`);
        project.assets.push({ key, path, mime: mimeFor(path), size: 0, dataUrl: '' });
        continue;
      }
      const bytes = typeof entry.data === 'string' ? encodeText(entry.data) : new Uint8Array(entry.data);
      project.assets.push({
        key,
        path,
        mime: mimeFor(path),
        size: bytes.length,
        dataUrl: bytesToDataUrl(bytes, mimeFor(path)),
      });
    }

    syncManifest(project);
    project.meta.updatedAt = new Date().toISOString();
    return { project, warnings };
  }

  function definitionKeys(project, typeKey) {
    return allDefinitions(project).filter((item) => item.file.content_type === typeKey);
  }

  function findDefinition(project, filePath, index) {
    const file = project.contentFiles.find((item) => item.path === filePath);
    if (!file) return null;
    return file.definitions[index] || null;
  }

  function localizationValue(project, definition, field, locale) {
    const key = definition && definition[field];
    if (!key) return '';
    const entry = getLoc(project, locale || 'zh_CN');
    return entry && entry.entries[key] ? entry.entries[key] : '';
  }

  function definitionTitle(project, definition) {
    return localizationValue(project, definition, 'name_key', 'zh_CN')
      || localizationValue(project, definition, 'name_key', 'en')
      || localPart(definition && definition.id)
      || (definition && definition.target)
      || '未命名';
  }

  function dependencyOnCore(project) {
    return (project.manifest.dependencies || []).some((dependency) => dependency.id === 'core');
  }

  root.SNStore = {
    FORMAT,
    FORMAT_VERSION,
    MANIFEST_SCHEMA_URL,
    deepClone,
    uid,
    slugify,
    localPart,
    namespaceOf,
    keyBase,
    keyBaseOf,
    blankManifest,
    createProject,
    applyTemplate,
    ensureContentFile,
    allDefinitions,
    definitionKeys,
    definitionIdSet,
    uniqueLocalId,
    addLocale,
    removeLocale,
    getLoc,
    setLocalization,
    collectDefinitionKeys,
    addDefinition,
    removeDefinition,
    duplicateDefinition,
    cloneCoreDefinition,
    addAsset,
    removeAsset,
    syncManifest,
    touch,
    normalizeProject,
    serialize,
    deserialize,
    toExportFiles,
    fromFiles,
    bytesToBase64,
    base64ToBytes,
    bytesToDataUrl,
    dataUrlToBytes,
    decodeText,
    encodeText,
    mimeFor,
    findDefinition,
    localizationValue,
    definitionTitle,
    dependencyOnCore,
    commitDefinitionLocalization,
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
