/*
 * Project validation for the Mod Maker.
 *
 * Two layers:
 *   1. A JSON Schema subset validator over the embedded canonical schemas.
 *      This includes the Content Schema 2.0 draft schemas under schemas/v2/;
 *      their $refs are resolved relative to the referencing schema file.
 *   2. Steam Navigator semantic rules (schema_version, namespace, localization
 *      coverage, cross-references, patch safety) that a schema cannot express.
 *      Draft (2.0) content is editable in the Mod Maker but is NOT loaded by
 *      the Content Schema 1.0 runtime, so it gets a per-file draft warning.
 *
 * Results use the same shape as the Godot validator where practical:
 * { path, keyword, message } plus a UI navigation hint.
 */
(function (root) {
  'use strict';

  const MAX_ERRORS = 300;
  const MAX_DEPTH = 64;
  const SEMVER_RE = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$/;
  const MOD_ID_RE = /^[a-z][a-z0-9_]{2,31}$/;
  const ID_REF_RE = /^[a-z][a-z0-9_]{2,31}:[a-z_]+\/[a-z0-9_]+$/;
  const ASSET_URI_RE = /^asset:\/\/([a-z][a-z0-9_]{2,31})\/(.+)$/;
  const ASSET_EXTENSIONS = ['.png', '.webp', '.svg', '.ogg', '.wav', '.glb'];
  const FORBIDDEN_EXTENSIONS = ['.gd', '.gdshader', '.cs', '.dll', '.so', '.dylib', '.exe', '.bat',
    '.cmd', '.ps1', '.sh', '.pck', '.tscn', '.tres', '.import'];
  /* Content Schema versions the Mod Maker understands. The runtime only loads 1.0. */
  const SUPPORTED_SCHEMA_VERSIONS = ['1.0', '2.0'];
  const DEFAULT_SCHEMA_VERSION = '1.0';

  const REF_TYPE_BY_FIELD = {
    hull: ['hull'],
    boiler: ['boiler'],
    cargo_modules: ['cargo_module'],
    navigation_module: ['navigation_module'],
    safety_module: ['safety_module'],
    passenger_cabin: ['cabin'],
    engineer: ['role'],
    navigator: ['role'],
    default_starting_build: ['starting_build'],
    archetypes: ['port_archetype'],
    good: ['good'],
    materials: ['good', 'material'],
    item_id: ['good', 'material'],
  };

  function schemas() {
    return root.SN_SCHEMAS || {};
  }

  function catalog() {
    return root.SNCatalog || { BY_KEY: {}, BY_SINGULAR: {} };
  }

  /**
   * Content Schema version for a content file or a content type key.
   *
   * Order: an explicit `file.schema_version`, then the type's catalog
   * `schemaVersion` (draft types are 2.0), then the legacy 1.0 default.
   */
  function schemaVersionFor(typeKeyOrFile) {
    if (typeKeyOrFile && typeof typeKeyOrFile === 'object') {
      const explicit = typeKeyOrFile.schema_version;
      if (explicit) return String(explicit);
      return schemaVersionFor(typeKeyOrFile.content_type);
    }
    const info = catalog().BY_KEY[String(typeKeyOrFile == null ? '' : typeKeyOrFile)];
    if (info && info.schemaVersion) return String(info.schemaVersion);
    return DEFAULT_SCHEMA_VERSION;
  }

  function normalizeSchemaPath(file) {
    const parts = [];
    for (const segment of String(file).split('/')) {
      if (!segment || segment === '.') continue;
      if (segment === '..') parts.pop();
      else parts.push(segment);
    }
    return parts.join('/');
  }

  function pointerEscape(text) {
    return String(text).replace(/~/g, '~0').replace(/\//g, '~1');
  }

  function pointerUnescape(text) {
    return String(text).replace(/~1/g, '/').replace(/~0/g, '~');
  }

  function joinPointer(base, key) {
    return `${base}/${pointerEscape(key)}`;
  }

  /**
   * Resolve a $ref against the file it appears in.
   *
   * A bare file name is a sibling of the referencing schema, so
   * 'common.schema.json' inside 'v2/start_profile.schema.json' resolves to
   * 'v2/common.schema.json'. A file part that already contains a directory is
   * kept relative to the schemas/ root. Top-level schemas (basename baseFile)
   * keep resolving exactly as before.
   */
  function resolveRef(ref, baseFile) {
    if (typeof ref !== 'string') return null;
    const hash = ref.indexOf('#');
    const filePart = hash >= 0 ? ref.slice(0, hash) : ref;
    const pointerPart = hash >= 0 ? ref.slice(hash + 1) : '';
    let file = baseFile;
    if (filePart) {
      const clean = filePart.replace(/^\.\//, '');
      if (clean.includes('/')) {
        file = normalizeSchemaPath(clean);
      } else {
        const directory = baseFile ? String(baseFile).replace(/[^/]*$/, '') : '';
        file = normalizeSchemaPath(directory + clean);
      }
    }
    const schemaRoot = schemas()[file];
    if (!schemaRoot) return null;
    let node = schemaRoot;
    if (pointerPart) {
      const segments = pointerPart.split('/').slice(1);
      for (const raw of segments) {
        const segment = pointerUnescape(raw);
        if (node == null || !(segment in node)) return null;
        node = node[segment];
      }
    }
    return { schema: node, file };
  }

  /**
   * Follow $ref chains and return the effective schema plus source file.
   */
  function deref(schema, file, seen) {
    let current = schema;
    let currentFile = file;
    let refText = '';
    let guard = 0;
    const visited = seen || new Set();
    while (current && typeof current === 'object' && typeof current.$ref === 'string') {
      refText = current.$ref;
      if (visited.has(refText) || guard > 32) {
        return { schema: current, file: currentFile, ref: refText, loop: true };
      }
      visited.add(refText);
      const resolved = resolveRef(refText, currentFile);
      if (!resolved) {
        return { schema: {}, file: currentFile, ref: refText, missing: true };
      }
      current = resolved.schema;
      currentFile = resolved.file;
      guard += 1;
    }
    return { schema: current || {}, file: currentFile, ref: refText };
  }

  /**
   * Merge an object schema (following refs and allOf) for form rendering.
   */
  function flattenObject(schema, file, seen) {
    const resolved = deref(schema, file, seen);
    const merged = { type: 'object', properties: {}, required: [], additionalProperties: true };
    const branches = [];
    if (Array.isArray(resolved.schema.allOf)) {
      for (const branch of resolved.schema.allOf) branches.push(branch);
    } else {
      branches.push(resolved.schema);
    }
    for (const branch of branches) {
      const sub = deref(branch, resolved.file, seen);
      if (sub.schema && Array.isArray(sub.schema.allOf)) {
        const nested = flattenObject(sub.schema, sub.file, seen);
        Object.assign(merged.properties, nested.properties);
        merged.required = merged.required.concat(nested.required);
        if (nested.additionalProperties === false) merged.additionalProperties = false;
        continue;
      }
      const value = sub.schema || {};
      if (value.properties) Object.assign(merged.properties, value.properties);
      if (Array.isArray(value.required)) merged.required = merged.required.concat(value.required);
      if (value.additionalProperties === false) merged.additionalProperties = false;
      if (value.type) merged.type = value.type;
    }
    merged.required = [...new Set(merged.required)];
    return { schema: merged, file: resolved.file };
  }

  function typeOf(value) {
    if (value === null) return 'null';
    if (Array.isArray(value)) return 'array';
    return typeof value;
  }

  function matchesType(value, type) {
    const actual = typeOf(value);
    if (type === 'integer') return actual === 'number' && Number.isInteger(value);
    if (type === 'number') return actual === 'number' && Number.isFinite(value);
    return actual === type;
  }

  function validateSchema(instance, schema, file) {
    return runSchemaValidation(instance, schema, { file: file || '', rootFile: file || '' }, 0);
  }

  function runSchemaValidation(instance, schema, context, startDepth) {
    const errors = [];
    function add(path, keyword, message) {
      if (errors.length >= MAX_ERRORS) return;
      errors.push({ path, keyword, message });
    }

    function validate(value, schemaNode, pointer, depth) {
      if (errors.length >= MAX_ERRORS) return;
      if (depth > MAX_DEPTH) {
        add(pointer, 'depth', '嵌套层级超过上限');
        return;
      }
      if (!schemaNode || typeof schemaNode !== 'object') return;

      const resolved = deref(schemaNode, context.file);
      if (resolved.missing) {
        add(pointer, '$ref', `无法解析 Schema 引用: ${resolved.ref}`);
        return;
      }
      if (resolved.loop) return;

      const previousFile = context.file;
      context.file = resolved.file;
      const node = resolved.schema || {};
      const probePasses = (branch) => runSchemaValidation(
        value,
        branch,
        { file: context.file, rootFile: context.rootFile },
        depth + 1
      ).length === 0;

      if (Array.isArray(node.allOf)) {
        for (const branch of node.allOf) validate(value, branch, pointer, depth + 1);
      }
      if (Array.isArray(node.anyOf) && !node.anyOf.some(probePasses)) {
        add(pointer, 'anyOf', '不满足任意一种允许的结构');
      }
      if (Array.isArray(node.oneOf)) {
        const pass = node.oneOf.filter(probePasses).length;
        if (pass !== 1) add(pointer, 'oneOf', '必须且只能满足一种允许的结构');
      }
      if (node.not && probePasses(node.not)) {
        add(pointer, 'not', '不允许该结构');
      }

      if ('const' in node && value !== node.const) {
        add(pointer, 'const', `必须为 ${JSON.stringify(node.const)}`);
      }
      if (Array.isArray(node.enum) && !node.enum.some((item) => item === value)) {
        add(pointer, 'enum', `必须是 ${node.enum.map((item) => JSON.stringify(item)).join(' / ')} 之一`);
      }

      if (node.type) {
        const types = Array.isArray(node.type) ? node.type : [node.type];
        if (!types.some((type) => matchesType(value, type))) {
          add(pointer, 'type', `类型应为 ${types.join(' / ')}，实际为 ${typeOf(value)}`);
          context.file = previousFile;
          return;
        }
      }

      if (typeOf(value) === 'string') {
        if (typeof node.minLength === 'number' && value.length < node.minLength) {
          add(pointer, 'minLength', `长度不能少于 ${node.minLength}`);
        }
        if (typeof node.maxLength === 'number' && value.length > node.maxLength) {
          add(pointer, 'maxLength', `长度不能超过 ${node.maxLength}`);
        }
        if (typeof node.pattern === 'string') {
          try {
            if (!new RegExp(node.pattern).test(value)) add(pointer, 'pattern', `格式不匹配 /${node.pattern}/`);
          } catch (error) {
            /* ignore an invalid schema regex */
          }
        }
      }

      if (typeOf(value) === 'number') {
        if (typeof node.minimum === 'number' && value < node.minimum) {
          add(pointer, 'minimum', `不能小于 ${node.minimum}`);
        }
        if (typeof node.maximum === 'number' && value > node.maximum) {
          add(pointer, 'maximum', `不能大于 ${node.maximum}`);
        }
        if (typeof node.exclusiveMinimum === 'number' && value <= node.exclusiveMinimum) {
          add(pointer, 'exclusiveMinimum', `必须大于 ${node.exclusiveMinimum}`);
        }
        if (typeof node.exclusiveMaximum === 'number' && value >= node.exclusiveMaximum) {
          add(pointer, 'exclusiveMaximum', `必须小于 ${node.exclusiveMaximum}`);
        }
      }

      if (typeOf(value) === 'array') {
        if (typeof node.minItems === 'number' && value.length < node.minItems) {
          add(pointer, 'minItems', `至少需要 ${node.minItems} 项`);
        }
        if (typeof node.maxItems === 'number' && value.length > node.maxItems) {
          add(pointer, 'maxItems', `最多允许 ${node.maxItems} 项`);
        }
        if (node.uniqueItems) {
          const seen = new Set();
          value.forEach((item) => {
            const key = JSON.stringify(item);
            if (seen.has(key)) add(pointer, 'uniqueItems', '存在重复项');
            seen.add(key);
          });
        }
        if (node.items && !Array.isArray(node.items)) {
          value.forEach((item, index) => validate(item, node.items, joinPointer(pointer, index), depth + 1));
        } else if (Array.isArray(node.items)) {
          node.items.forEach((itemSchema, index) => {
            if (index < value.length) validate(value[index], itemSchema, joinPointer(pointer, index), depth + 1);
          });
        }
      }

      if (typeOf(value) === 'object') {
        if (Array.isArray(node.required)) {
          for (const key of node.required) {
            if (!(key in value)) add(pointer, 'required', `缺少必填字段 "${key}"`);
          }
        }
        const properties = node.properties || {};
        for (const [key, child] of Object.entries(properties)) {
          if (key in value) validate(value[key], child, joinPointer(pointer, key), depth + 1);
        }
        if (node.patternProperties) {
          for (const [pattern, child] of Object.entries(node.patternProperties)) {
            let regex = null;
            try {
              regex = new RegExp(pattern);
            } catch (error) {
              continue;
            }
            for (const key of Object.keys(value)) {
              if (regex.test(key)) validate(value[key], child, joinPointer(pointer, key), depth + 1);
            }
          }
        }
        if (node.additionalProperties === false) {
          for (const key of Object.keys(value)) {
            if (!(key in properties)) add(pointer, 'additionalProperties', `不允许的字段 "${key}"`);
          }
        } else if (node.additionalProperties && typeof node.additionalProperties === 'object') {
          for (const key of Object.keys(value)) {
            if (!(key in properties)) {
              validate(value[key], node.additionalProperties, joinPointer(pointer, key), depth + 1);
            }
          }
        }
      }

      context.file = previousFile;
    }

    validate(instance, schema, '', startDepth);
    return errors;
  }

  function parseSemver(text) {
    const match = SEMVER_RE.exec(String(text || '').trim());
    if (!match) return null;
    return {
      major: Number(match[1]),
      minor: Number(match[2]),
      patch: Number(match[3]),
      prerelease: match[4] || '',
    };
  }

  function versionRangeError(text) {
    const raw = String(text == null ? '' : text).trim();
    if (!raw || raw === '*') return '';
    const groups = raw.split('||');
    for (const group of groups) {
      const tokens = group.replace(/,/g, ' ').split(/\s+/).filter(Boolean);
      if (tokens.length === 0) continue;
      for (let token of tokens) {
        if (token === '*') continue;
        if (token.startsWith('^') || token.startsWith('~')) token = token.slice(1);
        else token = token.replace(/^(>=|<=|>|<|=)/, '');
        if (!parseSemver(token)) return `无法解析版本范围片段 "${token}"`;
      }
    }
    return '';
  }

  function safePath(path) {
    if (!path || path.length > 240) return false;
    if (path.includes('\\') || path.includes('\0')) return false;
    if (path.startsWith('/') || path.includes('://') || path.includes(':')) return false;
    const parts = path.split('/');
    if (parts.length > 16) return false;
    if (parts.some((part) => !part || part === '.' || part === '..')) return false;
    return true;
  }

  function extensionOf(path) {
    const name = String(path).split('/').pop() || '';
    const index = name.lastIndexOf('.');
    return index >= 0 ? name.slice(index).toLowerCase() : '';
  }

  function isForbiddenPath(path) {
    return FORBIDDEN_EXTENSIONS.includes(extensionOf(path));
  }

  function walkStrings(value, path, callback, depth) {
    if ((depth || 0) > 32 || value == null) return;
    if (Array.isArray(value)) {
      value.forEach((item, index) => walkStrings(item, `${path}/${index}`, callback, (depth || 0) + 1));
      return;
    }
    if (typeof value === 'object') {
      for (const [key, child] of Object.entries(value)) {
        walkStrings(child, `${path}/${pointerEscape(key)}`, callback, (depth || 0) + 1);
      }
      return;
    }
    callback(value, path);
  }

  function referencedIdType(id) {
    const match = /^[a-z][a-z0-9_]{2,31}:([a-z_]+)\//.exec(String(id || ''));
    return match ? match[1] : '';
  }

  function expectedRefType(path) {
    const segments = path.split('/').filter(Boolean).map(pointerUnescape);
    if (segments.length >= 2 && /^\d+$/.test(segments[segments.length - 1])) {
      return REF_TYPE_BY_FIELD[segments[segments.length - 2]] || null;
    }
    const leaf = segments[segments.length - 1] || '';
    if (leaf === 'id' && segments.includes('materials')) return REF_TYPE_BY_FIELD.materials;
    return REF_TYPE_BY_FIELD[leaf] || null;
  }

  function validateProject(project, options) {
    const opts = options || {};
    const issues = [];
    const seenIssue = new Set();

    function add(severity, code, message, view, extra) {
      const key = `${severity}|${code}|${message}|${JSON.stringify(view || {})}`;
      if (seenIssue.has(key)) return;
      seenIssue.add(key);
      issues.push(Object.assign({ severity, code, message, view: view || { name: 'overview' } }, extra || {}));
    }

    if (!project || !project.manifest) {
      add('error', 'project_missing', '没有打开任何模组项目。', { name: 'overview' });
      return finish(issues);
    }

    const manifest = project.manifest;
    const modId = String(manifest.id || '');
    const manifestSchema = schemas()['manifest.schema.json'];
    if (manifestSchema) {
      for (const error of validateSchema(manifest, manifestSchema, 'manifest.schema.json')) {
        const field = (error.path.split('/')[1] || '').replace(/~1/g, '/');
        add('error', `manifest_${error.keyword}`, `Manifest ${error.path || '/'}：${error.message}`,
          { name: 'overview', field });
      }
    } else {
      add('error', 'schema_missing', '未加载 Manifest Schema 包，请重新生成 schema-bundle.js。', { name: 'overview' });
    }

    if (manifest.type !== 'content') {
      add('error', 'manifest_type', 'MVP 只支持 type = "content"。', { name: 'overview', field: 'type' });
    }
    if (modId === 'core') {
      add('warning', 'manifest_reserved_id', 'id "core" 保留给官方内容包；修改官方内容前请确认发布流程。', { name: 'overview', field: 'id' });
    }
    if (manifest.required === true && modId !== 'core') {
      add('error', 'manifest_required', '只有官方 core 模组可以声明 required = true。', { name: 'overview', field: 'required' });
    }

    const contentFiles = Array.isArray(project.contentFiles) ? project.contentFiles : [];
    const localization = Array.isArray(project.localization) ? project.localization : [];
    const assets = Array.isArray(project.assets) ? project.assets : [];
    const declaredContent = Array.isArray(manifest.content) ? manifest.content : [];
    const declaredLocalization = Array.isArray(manifest.localization) ? manifest.localization : [];
    const declaredAssets = manifest.assets && typeof manifest.assets === 'object' ? manifest.assets : {};

    const contentPaths = new Set(contentFiles.map((file) => file.path));
    for (const path of declaredContent) {
      if (!contentPaths.has(path)) {
        add('error', 'manifest_content_missing', `Manifest 声明的内容文件不存在：${path}`, { name: 'overview', field: 'content' });
      }
    }
    for (const file of contentFiles) {
      if (!declaredContent.includes(file.path)) {
        add('warning', 'content_not_declared', `内容文件未写入 manifest.content：${file.path}`, { name: 'content', type: file.content_type, file: file.path });
      }
    }
    const localizationPaths = new Set(localization.map((entry) => entry.path));
    for (const path of declaredLocalization) {
      if (!localizationPaths.has(path)) {
        add('error', 'manifest_localization_missing', `Manifest 声明的本地化文件不存在：${path}`, { name: 'overview', field: 'localization' });
      }
    }
    for (const entry of localization) {
      if (!declaredLocalization.includes(entry.path)) {
        add('warning', 'localization_not_declared', `本地化文件未写入 manifest.localization：${entry.path}`, { name: 'localization', locale: entry.locale });
      }
    }

    const dependencyIds = new Set();
    for (const dependency of [...(manifest.dependencies || []), ...(manifest.optional_dependencies || [])]) {
      if (!dependency || !dependency.id) continue;
      if (dependencyIds.has(dependency.id)) {
        add('error', 'duplicate_dependency', `依赖 ID 重复：${dependency.id}`, { name: 'overview', field: 'dependencies' });
      }
      dependencyIds.add(dependency.id);
      if (dependency.version) {
        const error = versionRangeError(dependency.version);
        if (error) add('error', 'dependency_range', `依赖 ${dependency.id} 的版本范围无效：${error}`, { name: 'overview', field: 'dependencies' });
      }
    }
    if ((manifest.conflicts || []).includes(modId)) {
      add('error', 'self_conflict', '模组不能与自身冲突。', { name: 'overview', field: 'conflicts' });
    }

    const assetPaths = new Map(assets.map((asset) => [asset.path, asset]));
    for (const [key, path] of Object.entries(declaredAssets)) {
      if (!assetPaths.has(path)) {
        add('warning', 'asset_missing', `资源键 ${key} 指向的文件不在项目中：${path}`, { name: 'assets', path });
      }
    }
    for (const asset of assets) {
      if (!safePath(asset.path)) {
        add('error', 'asset_path', `资源路径不安全：${asset.path}`, { name: 'assets', path: asset.path });
      } else if (!ASSET_EXTENSIONS.includes(extensionOf(asset.path))) {
        add('error', 'asset_extension', `资源只允许 png/webp/svg/ogg/wav/glb：${asset.path}`, { name: 'assets', path: asset.path });
      }
      if (asset.path && isForbiddenPath(asset.path)) {
        add('error', 'asset_forbidden', `禁止的可执行/场景资源：${asset.path}`, { name: 'assets', path: asset.path });
      }
      if (!asset.dataUrl) {
        add('warning', 'asset_no_data', `资源没有附件内容，导出 ZIP 时将跳过：${asset.path}`, { name: 'assets', path: asset.path });
      }
    }

    const allIds = new Map();
    const core = root.SN_CORE_INDEX;
    let usesCore = false;
    for (const entry of localization) {
      if (!entry.entries || typeof entry.entries !== 'object') continue;
      for (const [key, text] of Object.entries(entry.entries)) {
        if (!key.trim()) {
          add('warning', 'localization_empty_key', `${entry.locale} 中存在空键。`, { name: 'localization', locale: entry.locale, key });
        }
        if (typeof text !== 'string') {
          add('error', 'localization_type', `本地化 ${key} 的值必须是字符串。`, { name: 'localization', locale: entry.locale, key });
        } else if (!text.trim()) {
          add('warning', 'localization_blank', `${entry.locale} 的 "${key}" 翻译为空。`, { name: 'localization', locale: entry.locale, key });
        }
      }
    }

    for (const file of contentFiles) {
      const info = catalog().BY_KEY[file.content_type];
      const typeKey = info ? info.key : file.content_type;
      const baseView = { name: 'content', type: typeKey, file: file.path };
      const declaredVersion = file.schema_version == null ? '' : String(file.schema_version);
      if (declaredVersion && !SUPPORTED_SCHEMA_VERSIONS.includes(declaredVersion)) {
        add('error', 'schema_version_unsupported',
          `内容文件 ${file.path} 的 schema_version 不受支持：${declaredVersion}（只支持 1.0 / 2.0）`, baseView);
      }
      if (!info) {
        add('error', 'unknown_content_type', `未知的内容类型：${file.content_type}`, baseView);
        continue;
      }
      const expectedVersion = schemaVersionFor(info.key);
      if (declaredVersion && SUPPORTED_SCHEMA_VERSIONS.includes(declaredVersion) && declaredVersion !== expectedVersion) {
        add('error', 'schema_version_mismatch',
          `内容文件 ${file.path} 的 schema_version 是 ${declaredVersion}，但类型 ${info.key} 期望 ${expectedVersion}`, baseView);
      }
      if (info.draft) {
        add('warning', 'draft_content',
          `草案内容文件：${file.path}（当前游戏运行时 Content Schema 1.0 不加载）`, baseView);
        const declaredCapabilities = Array.isArray(manifest.capabilities) ? manifest.capabilities : [];
        if (info.capability && !declaredCapabilities.includes(info.capability)) {
          add('warning', 'capability_undeclared',
            `草案内容使用了 capability，但未写入 manifest.capabilities：${info.capability}`,
            { name: 'overview', field: 'capabilities' });
        }
      }
      const schema = schemas()[info.schema];
      if (!schema) {
        add('error', 'schema_missing', `找不到 Schema：${info.schema}`, baseView);
        continue;
      }
      const instance = {
        schema_version: file.schema_version || expectedVersion,
        content_type: file.content_type,
        definitions: Array.isArray(file.definitions) ? file.definitions : [],
      };
      const errors = validateSchema(instance, schema, info.schema);
      for (const error of errors) {
        const match = /^\/definitions\/(\d+)(\/.*)?$/.exec(error.path);
        const index = match ? Number(match[1]) : -1;
        const tail = match && match[2] ? match[2].replace(/^\//, '') : '';
        add('error', `schema_${error.keyword}`, `定义${index >= 0 ? ` #${index + 1}` : ''} ${info.label}：${error.message}`,
          { name: 'content', type: typeKey, file: file.path, index, field: tail }, { schemaKeyword: error.keyword });
      }

      file.definitions.forEach((definition, index) => {
        if (!definition || typeof definition !== 'object') return;
        const view = { name: 'content', type: typeKey, file: file.path, index };
        const id = String(definition.id || '');

        if (info.key !== 'patches') {
          if (id) {
            if (allIds.has(id)) {
              const first = allIds.get(id);
              add('error', 'duplicate_id', `内容 ID 重复：${id}（另一处在 ${first}）`, view);
            } else {
              allIds.set(id, file.path);
            }
            const namespace = id.split(':')[0];
            if (namespace !== modId) {
              add('error', 'id_namespace', `ID 必须使用本模组的命名空间 "${modId}"：${id}`, view);
            }
            if (!id.startsWith(`${modId}:${info.singular}/`)) {
              add('error', 'id_type', `ID 的类型段应为 "${info.singular}"：${id}`, view);
            }
          }

          const ownKeys = new Set();
          walkStrings(definition, '', (value, path) => {
            if (!path.endsWith('_key') || typeof value !== 'string' || !value) return;
            ownKeys.add(value);
            for (const entry of localization) {
              const text = entry.entries ? entry.entries[value] : undefined;
              if (text == null) {
                add('warning', 'localization_missing', `${entry.locale} 缺少本地化键 "${value}"`, { name: 'localization', locale: entry.locale, key: value });
              }
            }
          }, 0);
          if (ownKeys.size && localization.length === 0) {
            add('warning', 'localization_absent', '内容使用了本地化键，但项目没有本地化文件。', view);
          }

          const information = definition.information || {};
          for (const [field, extensions] of Object.entries({ texture: ['.png', '.webp', '.svg'], model: ['.glb'] })) {
            const reference = String(information[field] || '').trim();
            if (!reference) continue;
            const uriMatch = ASSET_URI_RE.exec(reference);
            const namespace = uriMatch ? uriMatch[1] : modId;
            const assetKey = uriMatch ? uriMatch[2] : reference;
            let assetPath = '';
            if (namespace === modId) {
              assetPath = declaredAssets[assetKey] || '';
            } else if (namespace === 'core') {
              usesCore = true;
              assetPath = String(core && core.manifest && core.manifest.assets && core.manifest.assets[assetKey] || '');
            } else {
              if (!dependencyIds.has(namespace)) {
                add('warning', 'entity_asset_dependency', `实体资源引用了未声明的模组依赖：${namespace}`, view);
              }
              add('warning', `entity_${field}_unverified`, `编辑器无法验证外部模组资源：${reference}`, view);
              continue;
            }
            if (!assetPath) {
              add('error', `entity_${field}_missing`, `实体${field === 'texture' ? '贴图' : '模型'}引用了不存在的资源：${reference}`, view);
            } else if (!extensions.includes(extensionOf(assetPath))) {
              add('error', `entity_${field}_type`, `实体${field === 'texture' ? '贴图' : '模型'}资源格式不正确：${assetPath}`, view);
            }
          }
        }

        if (info.key === 'contracts') {
          const formula = definition.data && definition.data.deadline_formula;
          if (formula && !(catalog().DEADLINE_FORMULAS || []).includes(formula)) {
            add('warning', 'formula_unknown', `框架未注册截止公式 "${formula}"，运行时会回退或拒绝。`, view);
          }
        }

        if (info.key === 'patches') {
          const target = String(definition.target || '');
          if (target.startsWith('core:')) usesCore = true;
          if (target.startsWith(`${modId}:`)) {
            add('error', 'patch_own_target', '不能 Patch 自己模组的定义，请直接修改定义本身。', view);
          }
          if (!ID_REF_RE.test(target)) {
            add('error', 'patch_target_format', `补丁目标 ID 格式无效：${target}`, view);
          } else {
            const core = root.SN_CORE_INDEX;
            if (target.startsWith('core:') && core) {
              const exists = core.definitions.some((item) => item.id === target);
              if (!exists) add('warning', 'patch_target_unknown', `Core 中找不到补丁目标：${target}`, view);
            }
          }
          const requires = definition.requires || {};
          if (requires.mod && target && !target.startsWith(`${requires.mod}:`)) {
            add('warning', 'patch_requires_mismatch', `requires.mod 与补丁目标命名空间不一致：${requires.mod}`, view);
          }
          if (requires.version) {
            const rangeIssue = versionRangeError(requires.version);
            if (rangeIssue) add('error', 'patch_requires_version', `补丁来源版本范围无效：${rangeIssue}`, view);
          }
          const operations = Array.isArray(definition.operations) ? definition.operations : [];
          const pointers = new Set();
          operations.forEach((operation, opIndex) => {
            const opView = { name: 'content', type: typeKey, file: file.path, index, field: `operations.${opIndex}` };
            if (!operation || typeof operation !== 'object') return;
            if (operation.path === '/id') {
              add('error', 'patch_id', '补丁不能修改定义的 id。', opView);
            }
            if (operation.path === '') {
              add('error', 'patch_root', '补丁路径不能指向根对象。', opView);
            }
            if (operation.op !== 'remove' && !('value' in operation)) {
              add('warning', 'patch_value', `${operation.op} 操作缺少 value。`, opView);
            }
            if (pointers.has(operation.path)) {
              add('warning', 'patch_duplicate_pointer', `同一补丁内重复修改 ${operation.path}。`, opView);
            }
            pointers.add(operation.path);
          });
        }
      });
    }

    if (contentFiles.length === 0) {
      add('error', 'no_content', '模组至少需要一个内容文件。', { name: 'overview', field: 'content' });
    }

    for (const file of contentFiles) {
      if (!safePath(file.path) || extensionOf(file.path) !== '.json') {
        add('error', 'content_path', `内容路径必须是不含 .. 的 .json 相对路径：${file.path}`, { name: 'content', type: file.content_type, file: file.path });
      }
      if (isForbiddenPath(file.path)) {
        add('error', 'content_forbidden', `禁止的内容文件：${file.path}`, { name: 'content', type: file.content_type, file: file.path });
      }
      if (!Array.isArray(file.definitions) || file.definitions.length === 0) {
        add('warning', 'content_empty', `${file.path} 没有任何定义；可删除此文件或补一条定义。`, { name: 'content', type: file.content_type, file: file.path });
      }
    }

    for (const file of contentFiles) {
      const fileInfo = catalog().BY_KEY[file.content_type];
      /* Draft (2.0) types reference planned types that Core does not ship yet. */
      const draftFile = !!(fileInfo && fileInfo.draft);
      file.definitions.forEach((definition, index) => {
        if (!definition || typeof definition !== 'object' || file.content_type === 'patches') return;
        const view = { name: 'content', type: file.content_type, file: file.path, index };
        walkStrings(definition.data, '', (value, path) => {
          if (typeof value !== 'string' || !ID_REF_RE.test(value)) return;
          const referencedType = referencedIdType(value);
          const expected = expectedRefType(path);
          if (expected && !expected.includes(referencedType)) {
            add('warning', 'ref_type', `字段 ${path} 期望引用 ${expected.join(' / ')}，实际是 ${referencedType}：${value}`, view);
          }
          const namespace = value.split(':')[0];
          if (namespace === modId) {
            if (!allIds.has(value)) {
              add('error', 'ref_missing', `引用了本模组中不存在的定义：${value}`, view);
            }
          } else if (namespace === 'core') {
            usesCore = true;
            if (!draftFile && core && !core.definitions.some((item) => item.id === value)) {
              add('warning', 'ref_core_unknown', `Core 中找不到引用的定义：${value}`, view);
            }
          }
        }, 0);
      });
    }

    if (usesCore && modId !== 'core' && !dependencyIds.has('core')) {
      add('warning', 'missing_core_dependency', '内容引用了 core 定义，但 Manifest 没有声明 core 依赖。', { name: 'overview', field: 'dependencies' });
    }

    const requiredIds = new Set();
    for (const file of contentFiles) {
      if (file.content_type === 'patches') continue;
      file.definitions.forEach((definition) => {
        if (definition && typeof definition.id === 'string') requiredIds.add(definition.id);
      });
    }

    const result = finish(issues);
    result.stats = { definitions: requiredIds.size, contentFiles: contentFiles.length, locales: localization.length, assets: assets.length };
    if (opts.focus) result.focus = opts.focus;
    return result;
  }

  function finish(issues) {
    const order = { error: 0, warning: 1, info: 2 };
    issues.sort((a, b) => order[a.severity] - order[b.severity]);
    const counts = { error: 0, warning: 0, info: 0, total: issues.length };
    for (const issue of issues) counts[issue.severity] = (counts[issue.severity] || 0) + 1;
    return { issues, counts };
  }

  /** Badge counts keyed by definition: "path#index". */
  function byDefinition(issues) {
    const map = new Map();
    for (const issue of issues) {
      if (!issue.view || issue.view.name !== 'content' || issue.view.index == null || issue.view.index < 0) continue;
      const key = `${issue.view.file}#${issue.view.index}`;
      const bucket = map.get(key) || { error: 0, warning: 0 };
      if (issue.severity === 'error') bucket.error += 1;
      if (issue.severity === 'warning') bucket.warning += 1;
      map.set(key, bucket);
    }
    return map;
  }

  root.SNValidate = {
    validateSchema,
    validateProject,
    byDefinition,
    schemaVersionFor,
    versionRangeError,
    parseSemver,
    safePath,
    isForbiddenPath,
    extensionOf,
    flattenObject,
    deref,
    resolveRef,
    ID_REF_RE,
    MOD_ID_RE,
    SUPPORTED_SCHEMA_VERSIONS,
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
