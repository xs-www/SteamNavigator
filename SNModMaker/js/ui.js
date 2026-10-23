/*
 * Presentational helpers and the schema-driven definition form.
 *
 * This module renders HTML only. app.js owns state, mutation and persistence;
 * every control communicates through data-* attributes so the form can be
 * rebuilt without attaching hundreds of listeners.
 */
(function (root) {
  'use strict';

  const catalog = () => root.SNCatalog;
  const validate = () => root.SNValidate;

  /* ------------------------------------------------------------------ */
  /* Small helpers                                                       */
  /* ------------------------------------------------------------------ */

  function esc(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function attr(value) {
    return esc(value);
  }

  function fmtSize(bytes) {
    const size = Number(bytes) || 0;
    if (size < 1024) return `${size} B`;
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
    return `${(size / 1024 / 1024).toFixed(1)} MB`;
  }

  function fmtDate(value) {
    if (!value) return '—';
    try {
      return new Date(value).toLocaleString('zh-CN', { hour12: false });
    } catch (error) {
      return value;
    }
  }

  function debounce(fn, wait) {
    let timer = null;
    return function debounced(...args) {
      clearTimeout(timer);
      timer = setTimeout(() => fn.apply(this, args), wait);
    };
  }

  function uid(prefix) {
    return `${prefix || 'x'}-${Math.random().toString(36).slice(2, 9)}`;
  }

  /* ------------------------------------------------------------------ */
  /* Schema access                                                       */
  /* ------------------------------------------------------------------ */

  function schemas() {
    return root.SN_SCHEMAS || {};
  }

  function contentSchema(typeKey) {
    const info = catalog().BY_KEY[typeKey];
    return info ? schemas()[info.schema] || null : null;
  }

  function dataSchema(typeKey) {
    const schema = contentSchema(typeKey);
    if (!schema) return null;
    const definitions = schema.properties && schema.properties.definitions;
    if (!definitions || !definitions.items) return null;
    let ref = null;
    if (definitions.items.$ref) ref = definitions.items.$ref;
    else if (Array.isArray(definitions.items.allOf)) {
      for (const branch of definitions.items.allOf) {
        if (branch.properties && branch.properties.data && branch.properties.data.$ref) {
          ref = branch.properties.data.$ref;
          break;
        }
      }
    }
    if (!ref) return null;
    return validate().resolveRef(ref, catalog().BY_KEY[typeKey].schema);
  }

  function resolve(schema, file) {
    return validate().deref(schema, file || '');
  }

  /* ------------------------------------------------------------------ */
  /* Feedback: toast, modal, busy                                        */
  /* ------------------------------------------------------------------ */

  function toast(message, type, timeout) {
    const host = document.getElementById('toasts');
    if (!host) return;
    const node = document.createElement('div');
    node.className = `toast toast-${type || 'info'}`;
    node.innerHTML = `<span class="toast-dot"></span><span>${esc(message)}</span>`;
    host.appendChild(node);
    setTimeout(() => {
      node.classList.add('leaving');
      setTimeout(() => node.remove(), 220);
    }, timeout || 3200);
  }

  function modal(options) {
    const opts = options || {};
    const dialog = document.getElementById('modal');
    if (!dialog) return null;
    dialog.innerHTML = `
      <div class="modal-card ${opts.size ? `modal-${opts.size}` : ''}" role="document">
        <header class="modal-head">
          <div>
            <h2>${esc(opts.title || '')}</h2>
            ${opts.subtitle ? `<p>${esc(opts.subtitle)}</p>` : ''}
          </div>
          <button type="button" class="icon-btn" data-modal-close aria-label="关闭">✕</button>
        </header>
        <div class="modal-body">${opts.body || ''}</div>
        ${opts.footer ? `<footer class="modal-foot">${opts.footer}</footer>` : ''}
      </div>`;
    if (!dialog.open) dialog.showModal();
    dialog.querySelectorAll('[data-modal-close]').forEach((button) => {
      button.addEventListener('click', () => dialog.close());
    });
    dialog.onclick = (event) => {
      if (event.target === dialog) dialog.close();
    };
    return dialog;
  }

  function closeModal() {
    const dialog = document.getElementById('modal');
    if (dialog && dialog.open) dialog.close();
  }

  function confirm(options) {
    const opts = options || {};
    return new Promise((resolve) => {
      const dialog = modal({
        title: opts.title || '确认',
        body: `<p class="confirm-text">${esc(opts.message || '')}</p>`,
        size: 'sm',
        footer: `
          <button type="button" class="btn ghost" data-confirm="no">取消</button>
          <button type="button" class="btn ${opts.danger ? 'danger' : 'primary'}" data-confirm="yes">${esc(opts.confirmLabel || '确定')}</button>`,
      });
      if (!dialog) {
        resolve(false);
        return;
      }
      let settled = false;
      const done = (value) => {
        if (settled) return;
        settled = true;
        dialog.close();
        resolve(value);
      };
      dialog.querySelector('[data-confirm="no"]').addEventListener('click', () => done(false));
      dialog.querySelector('[data-confirm="yes"]').addEventListener('click', () => done(true));
      dialog.addEventListener('cancel', () => done(false));
      dialog.addEventListener('close', () => {
        if (!settled) {
          settled = true;
          resolve(false);
        }
      });
    });
  }

  function setBusy(active, text) {
    const overlay = document.getElementById('busy');
    if (!overlay) return;
    overlay.classList.toggle('visible', Boolean(active));
    overlay.querySelector('[data-busy-text]').textContent = text || '处理中…';
  }

  /* ------------------------------------------------------------------ */
  /* Reference pickers                                                   */
  /* ------------------------------------------------------------------ */

  const REF_TYPE_BY_FIELD = {
    hull: ['hull'],
    boiler: ['module'],
    cargo_modules: ['module'],
    navigation_module: ['module'],
    safety_module: ['module'],
    passenger_cabin: ['module'],
    engineer: ['crew_role'],
    navigator: ['crew_role'],
    default_starting_scenario: ['starting_scenario'],
    archetypes: ['port_template'],
    good: ['item'],
    materials: ['item'],
    item_id: ['item'],
    starting_scenario: ['starting_scenario'],
    damage_type: ['damage_type'],
    combat_ability: ['combat_ability'],
    loot_table: ['loot_table'],
    enemy_archetype: ['enemy_archetype'],
    hull_ref: ['hull'],
    module: ['module'],
    weapon: ['weapon'],
    formation: ['formation'],
    commandable_archetypes: ['ship_archetype'],
    building_ref: ['building'],
    recipes: ['production_recipe'],
    worker_role: ['worker_role'],
    item: ['item'],
    quests_completed: ['quest'],
  };

  function expectedTypes(field) {
    return REF_TYPE_BY_FIELD[field] || null;
  }

  function listIdFor(field) {
    const types = expectedTypes(field);
    if (types && types.length === 1) return `dl-type-${types[0]}`;
    return 'dl-all-ids';
  }

  function renderDatalists(project) {
    const buckets = new Map();
    function push(definition, typeInfo, title) {
      if (!definition || !definition.id) return;
      const list = buckets.get(typeInfo.singular) || [];
      list.push({ id: definition.id, title: title || '' });
      buckets.set(typeInfo.singular, list);
    }
    for (const file of project.contentFiles) {
      const info = catalog().BY_KEY[file.content_type];
      if (!info) continue;
      for (const definition of file.definitions || []) {
        push(definition, info, root.SNStore.localizationValue(project, definition, 'name_key', 'zh_CN'));
      }
    }
    const core = root.SN_CORE_INDEX;
    if (core) {
      for (const item of core.definitions) {
        const info = catalog().BY_KEY[item.content_type];
        if (info) push(item.definition, info, item.name_zh || item.name_en);
      }
    }
    const all = [];
    let html = '';
    for (const [singular, items] of buckets) {
      const options = items
        .sort((a, b) => a.id.localeCompare(b.id))
        .map((item) => `<option value="${attr(item.id)}">${esc(item.title || item.id)}</option>`)
        .join('');
      html += `<datalist id="dl-type-${attr(singular)}">${options}</datalist>`;
      all.push(...items);
    }
    const unique = new Map();
    for (const item of all) unique.set(item.id, item);
    html += `<datalist id="dl-all-ids">${[...unique.values()]
      .sort((a, b) => a.id.localeCompare(b.id))
      .map((item) => `<option value="${attr(item.id)}">${esc(item.title || item.id)}</option>`)
      .join('')}</datalist>`;
    html += `<datalist id="dl-stats">${catalog().MODIFIER_STATS.map((stat) => `<option value="${attr(stat)}"></option>`).join('')}</datalist>`;
    html += `<datalist id="dl-formulas">${catalog().DEADLINE_FORMULAS.map((item) => `<option value="${attr(item)}"></option>`).join('')}</datalist>`;
    return html;
  }

  /* ------------------------------------------------------------------ */
  /* Form primitives                                                     */
  /* ------------------------------------------------------------------ */

  function translated(project, key) {
    if (!key) return '';
    const zh = root.SNStore.getLoc(project, 'zh_CN');
    const en = root.SNStore.getLoc(project, 'en');
    return (zh && zh.entries[key]) || (en && en.entries[key]) || '';
  }

  function label(typeKey, field) {
    return catalog().labelFor(typeKey, field);
  }

  function hint(typeKey, field) {
    return catalog().hintFor(typeKey, field);
  }

  function fieldShell(typeKey, field, control, options) {
    const opts = options || {};
    const hintText = opts.hint || hint(typeKey, field);
    return `
      <div class="field ${opts.wide ? 'field-wide' : ''} ${opts.compact ? 'field-compact' : ''}">
        <div class="field-head">
          <label class="field-label">${esc(opts.label || label(typeKey, field))}${opts.required ? '<span class="req">*</span>' : ''}</label>
          ${opts.badge ? `<span class="mini-badge">${esc(opts.badge)}</span>` : ''}
        </div>
        ${control}
        ${hintText ? `<p class="field-hint">${esc(hintText)}</p>` : ''}
      </div>`;
  }

  function inputText(path, value, options) {
    const opts = options || {};
    return `<input class="input ${opts.className || ''}" type="text" value="${attr(value == null ? '' : value)}"
      data-field="${attr(path)}" data-parse="${opts.parse || 'text'}"
      ${opts.list ? `list="${attr(opts.list)}"` : ''} ${opts.placeholder ? `placeholder="${attr(opts.placeholder)}"` : ''}
      ${opts.spellcheck === false ? 'spellcheck="false"' : ''} ${opts.extra || ''}>`;
  }

  function assetMatchesKind(asset, kind) {
    const mime = String(asset && asset.mime || '').toLowerCase();
    const path = String(asset && asset.path || '').toLowerCase();
    if (kind === 'model') return mime === 'model/gltf-binary' || path.endsWith('.glb');
    return mime.startsWith('image/') || /\.(png|webp|svg)$/.test(path);
  }

  function assetPicker(path, value, kind, project, options) {
    const opts = options || {};
    const assets = (project && Array.isArray(project.assets) ? project.assets : [])
      .filter((asset) => assetMatchesKind(asset, kind))
      .sort((a, b) => String(a.key || '').localeCompare(String(b.key || '')));
    const emptyText = kind === 'model'
      ? '暂无 GLB 模型，请先到资源页添加。'
      : '暂无图片资源，请先到资源页添加 png / webp / svg。';
    const optionsHtml = assets.map((asset) => `
      <button type="button" class="asset-picker-option" data-action="asset-picker-value"
        data-value="${attr(asset.key || '')}" data-asset-search="${attr(`${asset.key || ''} ${asset.path || ''}`.toLowerCase())}">
        <span class="asset-picker-key mono">${esc(asset.key || '')}</span>
        <span class="asset-picker-path mono">${esc(asset.path || '')}</span>
      </button>`).join('');
    return `<div class="asset-picker" data-asset-kind="${attr(kind)}">
      <div class="asset-picker-control">
        <input class="input mono" type="text" value="${attr(value == null ? '' : value)}"
          data-field="${attr(path)}" data-parse="text" data-asset-picker-input
          placeholder="${attr(opts.placeholder || (kind === 'model' ? '例如 model.ship_part' : '例如 texture.entity_preview'))}"
          autocomplete="off" spellcheck="false">
        <button type="button" class="asset-picker-toggle" data-action="asset-picker-toggle" aria-label="展开资源候选" aria-expanded="false">⌄</button>
      </div>
      <div class="asset-picker-menu" hidden>
        <button type="button" class="asset-picker-option asset-picker-clear" data-action="asset-picker-value" data-value="" data-asset-search="">
          <span>不配置资源</span><span class="asset-picker-path">清空</span>
        </button>
        ${optionsHtml || `<p class="asset-picker-empty">${esc(emptyText)}</p>`}
        ${optionsHtml ? '<p class="asset-picker-no-match" hidden>没有匹配的资源键。</p>' : ''}
      </div>
    </div>`;
  }

  function inputNumber(path, value, schema, options) {
    const opts = options || {};
    const node = schema || {};
    const isInt = node.type === 'integer';
    const min = node.minimum != null ? `min="${attr(node.minimum)}"` : '';
    const max = node.maximum != null ? `max="${attr(node.maximum)}"` : '';
    const step = opts.step || (isInt ? '1' : 'any');
    return `<input class="input mono ${opts.className || ''}" type="number" value="${value == null ? '' : attr(value)}"
      data-field="${attr(path)}" data-parse="${isInt ? 'int' : 'number'}" step="${step}" ${min} ${max}
      ${opts.extra || ''}>`;
  }

  function selectEnum(path, value, values, options) {
    const opts = options || {};
    const entries = values.map((item) => {
      const key = typeof item === 'object' ? item.key : item;
      const text = typeof item === 'object' ? item.label : item;
      return `<option value="${attr(key)}" ${String(value) === String(key) ? 'selected' : ''}>${esc(text)}</option>`;
    }).join('');
    return `<select class="input select" data-field="${attr(path)}" data-parse="text" ${opts.extra || ''}>
      ${opts.placeholder ? `<option value="">${esc(opts.placeholder)}</option>` : ''}${entries}
    </select>`;
  }

  function toggle(path, checked, text) {
    return `<label class="switch-row">
      <span class="switch"><input type="checkbox" data-field="${attr(path)}" data-parse="bool" ${checked ? 'checked' : ''}><span class="switch-track"></span></span>
      <span>${esc(text || '')}</span>
    </label>`;
  }

  function rangePair(path, value, itemSchema, itemFile) {
    const values = Array.isArray(value) ? value : [null, null];
    const node = resolve(itemSchema, itemFile).schema || {};
    return `<div class="range-pair">
      <input class="input mono" type="number" step="any" value="${values[0] == null ? '' : attr(values[0])}" data-field="${attr(path)}.0" data-parse="number" ${node.minimum != null ? `min="${attr(node.minimum)}"` : ''}>
      <span class="range-dash">–</span>
      <input class="input mono" type="number" step="any" value="${values[1] == null ? '' : attr(values[1])}" data-field="${attr(path)}.1" data-parse="number" ${node.minimum != null ? `min="${attr(node.minimum)}"` : ''}>
    </div>`;
  }

  function refInput(path, value, field, options) {
    const opts = options || {};
    return inputText(path, value, {
      list: listIdFor(field),
      placeholder: opts.placeholder || '模组ID:类型/本地ID',
      spellcheck: false,
      className: 'mono ref-input',
      extra: opts.extra || '',
    });
  }

  function stringList(path, value, options) {
    const opts = options || {};
    const items = Array.isArray(value) ? value : [];
    const chips = items.map((item, index) => `
      <span class="chip">
        <span class="mono">${esc(item)}</span>
        <button type="button" class="chip-x" data-action="list-remove" data-path="${attr(path)}" data-index="${index}" title="移除">✕</button>
      </span>`).join('');
    return `<div class="list-editor">
      <div class="chips">${chips || '<span class="muted-sm">暂无条目</span>'}</div>
      <div class="list-add">
        <input class="input" type="text" data-list-input="${attr(path)}" placeholder="${esc(opts.placeholder || '输入后回车添加')}"
          ${opts.list ? `list="${attr(opts.list)}"` : ''} spellcheck="false">
        <button type="button" class="btn small" data-action="list-add" data-path="${attr(path)}">添加</button>
      </div>
    </div>`;
  }

  function enumMulti(path, value, values) {
    const selected = new Set(Array.isArray(value) ? value : []);
    return `<div class="chips">${values.map((item) => {
      const key = typeof item === 'object' ? item.key : item;
      const text = typeof item === 'object' ? item.label : item;
      return `<button type="button" class="chip toggle ${selected.has(key) ? 'active' : ''}"
        data-action="enum-toggle" data-path="${attr(path)}" data-value="${attr(key)}">${esc(text)}</button>`;
    }).join('')}</div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Array item editors                                                  */
  /* ------------------------------------------------------------------ */

  function arrayShell(path, items, renderItem, addLabel, emptyText, addExtra) {
    const body = items.length
      ? items.map((item, index) => renderItem(item, index)).join('')
      : `<p class="empty-inline">${esc(emptyText || '暂无条目')}</p>`;
    return `<div class="array-editor">
      ${body}
      <div class="array-actions">
        <button type="button" class="btn small ghost" data-action="array-add" data-path="${attr(path)}" ${addExtra || ''}>+ ${esc(addLabel)}</button>
      </div>
    </div>`;
  }

  function itemHead(path, index, title, options) {
    const opts = options || {};
    return `<header class="item-head">
      <span class="item-title">${esc(title || `条目 ${index + 1}`)}</span>
      <div class="item-tools">
        ${opts.up ? `<button type="button" class="icon-btn tiny" data-action="array-move" data-path="${attr(path)}" data-index="${index}" data-dir="-1" title="上移">↑</button>` : ''}
        ${opts.down ? `<button type="button" class="icon-btn tiny" data-action="array-move" data-path="${attr(path)}" data-index="${index}" data-dir="1" title="下移">↓</button>` : ''}
        <button type="button" class="icon-btn tiny danger" data-action="array-remove" data-path="${attr(path)}" data-index="${index}" title="删除">✕</button>
      </div>
    </header>`;
  }

  function renderModifier(item, index, path, ctx) {
    const value = item || {};
    return `<div class="item-card slim">
      ${itemHead(path, index, `修正 ${index + 1}`, { up: index > 0, down: true })}
      <div class="grid-3">
        <div class="field"><label class="field-label">属性</label><input class="input mono" list="dl-stats" value="${attr(value.stat || '')}" data-field="${attr(path)}.${index}.stat" data-parse="text"></div>
        <div class="field"><label class="field-label">运算</label>${selectEnum(`${path}.${index}.op`, value.op || 'mul', ['add', 'mul', 'set'])}</div>
        <div class="field"><label class="field-label">数值</label><input class="input mono" type="number" step="any" value="${value.value == null ? '' : attr(value.value)}" data-field="${attr(path)}.${index}.value" data-parse="number"></div>
      </div>
    </div>`;
  }

  function renderMaterial(item, index, path, ctx) {
    const value = item || {};
    return `<div class="item-card slim">
      ${itemHead(path, index, `材料 ${index + 1}`, { up: index > 0, down: true })}
      <div class="grid-2">
        <div class="field"><label class="field-label">材料 ID</label>${refInput(`${path}.${index}.id`, value.id || '', 'materials')}</div>
        <div class="field"><label class="field-label">数量</label><input class="input mono" type="number" step="0.1" min="0.1" value="${value.amount == null ? '' : attr(value.amount)}" data-field="${attr(path)}.${index}.amount" data-parse="number"></div>
      </div>
    </div>`;
  }

  function renderPayload(item, index, path, ctx) {
    const value = item || {};
    const kind = value.kind || 'cargo';
    const rangeField = kind === 'passenger' ? 'count_range' : 'weight_range';
    return `<div class="item-card">
      ${itemHead(path, index, `${kind === 'passenger' ? '载客' : '载货'}需求 ${index + 1}`, { up: index > 0, down: true })}
      <div class="grid-2">
        <div class="field"><label class="field-label">类型</label>${selectEnum(`${path}.${index}.kind`, kind, [{ key: 'cargo', label: '载货 cargo' }, { key: 'passenger', label: '载客 passenger' }], { extra: 'data-rerender="true"' })}</div>
        <div class="field"><label class="field-label">${kind === 'passenger' ? '人数区间' : '重量区间'}</label>${rangePair(`${path}.${index}.${rangeField}`, value[rangeField], { type: 'number' }, '')}</div>
        <div class="field field-wide"><label class="field-label">名称键（可选）</label>${inputText(`${path}.${index}.name_key`, value.name_key || '', { placeholder: 'contract.<mod>.<id>.payload' })}</div>
      </div>
    </div>`;
  }

  function renderMarket(item, index, path) {
    const value = item || {};
    return `<div class="item-card slim">
      ${itemHead(path, index, `商品 ${index + 1}`, { up: index > 0, down: true })}
      <div class="grid-3">
        <div class="field"><label class="field-label">物品</label>${refInput(`${path}.${index}.good`, value.good || '', 'good')}</div>
        <div class="field"><label class="field-label">库存区间</label>${rangePair(`${path}.${index}.stock_range`, value.stock_range, { type: 'number', minimum: 0 }, '')}</div>
        <div class="field"><label class="field-label">价格偏移</label><input class="input mono" type="number" step="any" min="0.5" max="2" value="${value.price_bias == null ? '' : attr(value.price_bias)}" data-field="${attr(path)}.${index}.price_bias" data-parse="number"></div>
      </div>
    </div>`;
  }

  function renderOperation(item, index, path) {
    const value = item || {};
    const json = value.value === undefined ? '' : JSON.stringify(value.value);
    return `<div class="item-card slim">
      ${itemHead(path, index, `操作 ${index + 1}`, { up: index > 0, down: true })}
      <div class="grid-3">
        <div class="field"><label class="field-label">操作</label>${selectEnum(`${path}.${index}.op`, value.op || 'replace', ['add', 'replace', 'remove'])}</div>
        <div class="field"><label class="field-label">JSON 指针</label>${inputText(`${path}.${index}.path`, value.path || '', { placeholder: '/data/purchase_price', className: 'mono' })}</div>
        <div class="field"><label class="field-label">值（JSON）</label><textarea class="input mono code" rows="1" data-field="${attr(path)}.${index}.value" data-parse="json" placeholder="380">${esc(json)}</textarea></div>
      </div>
    </div>`;
  }

  function renderOption(item, index, path, ctx) {
    const value = item || {};
    const effects = Array.isArray(value.effects) ? value.effects : [];
    return `<div class="item-card option-card">
      ${itemHead(path, index, value.id ? `选项 · ${value.id}` : `选项 ${index + 1}`, { up: index > 0, down: true })}
      <div class="grid-3">
        <div class="field"><label class="field-label">选项 ID</label>${inputText(`${path}.${index}.id`, value.id || '', { className: 'mono', placeholder: 'accept' })}</div>
        <div class="field"><label class="field-label">名称键</label>${inputText(`${path}.${index}.name_key`, value.name_key || '', { className: 'mono' })}
          <p class="field-hint">${esc(translated(ctx.project, value.name_key) || '尚未翻译')}</p></div>
        <div class="field"><label class="field-label">权重</label><input class="input mono" type="number" step="any" min="0" value="${value.weight == null ? '1' : attr(value.weight)}" data-field="${attr(path)}.${index}.weight" data-parse="number"></div>
      </div>
      <div class="sub-section">
        <h5>条件</h5>
        ${renderCondition(value.condition, `${path}.${index}.condition`, ctx, true)}
      </div>
      <div class="sub-section">
        <h5>效果</h5>
        ${arrayShell(`${path}.${index}.effects`, effects, (effect, effectIndex) => renderEffect(effect, effectIndex, `${path}.${index}.effects`, ctx), '添加效果', '至少需要一个效果')}
      </div>
    </div>`;
  }

  /* ------------------------------------------------------------------ */
  /* Condition and effect editors                                        */
  /* ------------------------------------------------------------------ */

  function conditionKind(value) {
    if (!value || typeof value !== 'object') return 'none';
    if (Array.isArray(value.all)) return 'all';
    if (Array.isArray(value.any)) return 'any';
    if (value.not) return 'not';
    return 'leaf';
  }

  function renderCondition(value, path, ctx, nested, depth) {
    const level = depth || 0;
    if (level > 16) {
      return '<p class="field-hint">条件嵌套过深，请使用顶部「JSON」编辑。</p>';
    }
    if (!value || typeof value !== 'object') {
      return `<div class="condition-empty">
        <span class="muted-sm">无条件（始终满足）</span>
        <button type="button" class="btn small ghost" data-action="condition-add" data-path="${attr(path)}">+ 添加条件</button>
      </div>`;
    }
    const kind = conditionKind(value);
    const kindSelect = `<select class="input select kind-select" data-action="condition-kind" data-path="${attr(path)}">
      <option value="leaf" ${kind === 'leaf' ? 'selected' : ''}>条件</option>
      <option value="all" ${kind === 'all' ? 'selected' : ''}>全部满足 (all)</option>
      <option value="any" ${kind === 'any' ? 'selected' : ''}>任一满足 (any)</option>
      <option value="not" ${kind === 'not' ? 'selected' : ''}>取反 (not)</option>
    </select>`;

    if (kind === 'all' || kind === 'any') {
      const children = value[kind] || [];
      return `<div class="condition-box">
        <div class="condition-head">${kindSelect}
          <button type="button" class="icon-btn tiny danger" data-action="condition-remove" data-path="${attr(path)}" title="删除条件组">✕</button>
        </div>
        <div class="condition-children">
          ${children.map((child, index) => `<div class="condition-child">${renderCondition(child, `${path}.${kind}.${index}`, ctx, true, level + 1)}</div>`).join('')}
        </div>
        <div class="array-actions">
          <button type="button" class="btn small ghost" data-action="condition-add" data-path="${attr(path)}.${kind}" data-kind="leaf">+ 条件</button>
          <button type="button" class="btn small ghost" data-action="condition-add" data-path="${attr(path)}.${kind}" data-kind="all">+ 条件组</button>
        </div>
      </div>`;
    }

    if (kind === 'not') {
      return `<div class="condition-box">
        <div class="condition-head">${kindSelect}
          <button type="button" class="icon-btn tiny danger" data-action="condition-remove" data-path="${attr(path)}" title="删除条件">✕</button>
        </div>
        <div class="condition-child">${renderCondition(value.not, `${path}.not`, ctx, true, level + 1)}</div>
      </div>`;
    }

    const op = value.op || 'money_gte';
    const fields = catalog().CONDITION_FIELDS[op] || [];
    const opSelect = `<select class="input select op-select" data-action="condition-op" data-path="${attr(path)}">
      ${catalog().CONDITION_OPS.map((item) => `<option value="${attr(item)}" ${op === item ? 'selected' : ''}>${esc(item)}</option>`).join('')}
    </select>`;
    return `<div class="condition-box leaf">
      <div class="condition-head">${kindSelect}${opSelect}
        <button type="button" class="icon-btn tiny danger" data-action="condition-remove" data-path="${attr(path)}" title="删除条件">✕</button>
      </div>
      ${fields.length ? `<div class="condition-fields">${fields.map((field) => conditionField(field, value[field], `${path}.${field}`)).join('')}</div>` : ''}
    </div>`;
  }

  function conditionField(field, value, path) {
    const labelText = label('voyage_events', field);
    if (['value', 'amount'].includes(field)) {
      return `<div class="field compact"><label class="field-label">${esc(labelText)}</label><input class="input mono" type="number" step="any" value="${value == null ? '' : attr(value)}" data-field="${attr(path)}" data-parse="number"></div>`;
    }
    if (field === 'role_kind') {
      return `<div class="field compact"><label class="field-label">${esc(labelText)}</label>${selectEnum(path, value || 'engineer', ['engineer', 'navigator'])}</div>`;
    }
    if (['port_id', 'item_id', 'id', 'contract_id'].includes(field)) {
      return `<div class="field compact"><label class="field-label">${esc(labelText)}</label>${inputText(path, value || '', { list: 'dl-all-ids', className: 'mono', spellcheck: false })}</div>`;
    }
    return `<div class="field compact"><label class="field-label">${esc(labelText)}</label>${inputText(path, value || '', { className: 'mono' })}</div>`;
  }

  function renderEffect(item, index, path, ctx) {
    const value = item || {};
    const op = value.op || 'add_money';
    const fields = catalog().EFFECT_FIELDS[op] || [];
    return `<div class="effect-row">
      <select class="input select" data-action="effect-op" data-path="${attr(path)}.${index}.op">
        ${catalog().EFFECT_OPS.map((itemOp) => `<option value="${attr(itemOp)}" ${op === itemOp ? 'selected' : ''}>${esc(itemOp)}</option>`).join('')}
      </select>
      <div class="effect-fields">
        ${fields.map((field) => effectField(field, value[field], `${path}.${index}.${field}`)).join('')}
      </div>
      <button type="button" class="icon-btn tiny danger" data-action="array-remove" data-path="${attr(path)}" data-index="${index}" title="删除效果">✕</button>
    </div>`;
  }

  function effectField(field, value, path) {
    if (['amount'].includes(field)) {
      return `<input class="input mono narrow" type="number" step="any" value="${value == null ? '' : attr(value)}" data-field="${attr(path)}" data-parse="number" placeholder="${esc(label('voyage_events', field))}">`;
    }
    if (field === 'text_key') {
      return `<input class="input mono" type="text" value="${attr(value || '')}" data-field="${attr(path)}" data-parse="text" placeholder="notice.<mod>.<event>.<option>">`;
    }
    return `<input class="input mono" type="text" list="dl-all-ids" value="${attr(value || '')}" data-field="${attr(path)}" data-parse="text" placeholder="${esc(label('voyage_events', field))}" spellcheck="false">`;
  }

  /* ------------------------------------------------------------------ */
  /* Generic field renderer                                              */
  /* ------------------------------------------------------------------ */

  function renderObjectFields(objectSchema, objectFile, value, basePath, ctx, options) {
    const opts = options || {};
    const flat = validate().flattenObject(objectSchema, objectFile);
    const properties = flat.schema.properties || {};
    const required = new Set(flat.schema.required || []);
    const fields = [];
    for (const [field, schema] of Object.entries(properties)) {
      if (opts.skip && opts.skip.includes(field)) continue;
      fields.push(renderField(field, schema, value ? value[field] : undefined, basePath ? `${basePath}.${field}` : field, ctx, {
        required: required.has(field),
      }, flat.file));
    }
    if (opts.extraNote && flat.schema.additionalProperties !== false) {
      fields.push(`<p class="field-hint span-2">此对象允许额外字段；如需添加未列出的字段，请使用顶部「JSON」编辑。</p>`);
    }
    return `<div class="field-grid">${fields.join('')}</div>`;
  }

  function renderField(field, schema, value, path, ctx, options, schemaFile) {
    const opts = options || {};
    const resolved = resolve(schema, schemaFile || ctx.schemaFile);
    const node = resolved.schema || {};
    const ref = resolved.ref || '';
    const type = node.type;
    const typeKey = ctx.typeKey;
    const itemResolved = type === 'array' ? resolve(node.items || {}, resolved.file) : null;
    const itemRef = itemResolved ? itemResolved.ref || '' : '';
    const isWide = ['array', 'object'].includes(type) && !ref.includes('range2');
    const shellOpts = {
      required: opts.required,
      wide: isWide,
      hint: hint(typeKey, field),
      badge: '',
    };

    if (ref.endsWith('condition_node')) {
      return fieldShell(typeKey, field, renderCondition(value, path, ctx, true), shellOpts);
    }
    if (ref.endsWith('range2')) {
      return fieldShell(typeKey, field, rangePair(path, value, resolved.schema.items || {}, resolved.file), shellOpts);
    }
    if (ref.endsWith('id_ref')) {
      return fieldShell(typeKey, field, refInput(path, value || '', field), shellOpts);
    }
    if (itemRef.endsWith('modifier')) {
      return fieldShell(typeKey, field, arrayShell(path, value || [], (item, index) => renderModifier(item, index, path, ctx), '属性修正'), shellOpts);
    }
    if (itemRef.endsWith('craft_material')) {
      return fieldShell(typeKey, field, arrayShell(path, value || [], (item, index) => renderMaterial(item, index, path, ctx), '材料'), shellOpts);
    }
    if (itemRef.endsWith('payload')) {
      return fieldShell(typeKey, field, arrayShell(path, value || [], (item, index) => renderPayload(item, index, path, ctx), '需求'), shellOpts);
    }
    if (itemRef.endsWith('option_data')) {
      return fieldShell(typeKey, field, arrayShell(path, value || [], (item, index) => renderOption(item, index, path, ctx), '选项', '事件至少需要两个选项'), shellOpts);
    }
    if (itemRef.endsWith('effect')) {
      return fieldShell(typeKey, field, arrayShell(path, value || [], (item, index) => renderEffect(item, index, path, ctx), '效果'), shellOpts);
    }
    if (field === 'operations' && ctx.typeKey === 'patches') {
      return fieldShell(typeKey, field, arrayShell(path, value || [], (item, index) => renderOperation(item, index, path), '操作'), shellOpts);
    }
    if (field === 'market' && Array.isArray(value) !== false) {
      return fieldShell(typeKey, field, arrayShell(path, value || [], (item, index) => renderMarket(item, index, path), '商品'), shellOpts);
    }

    if (type === 'array') {
      const itemNode = itemResolved.schema || {};
      if (itemNode.enum) {
        return fieldShell(typeKey, field, enumMulti(path, value || [], itemNode.enum), shellOpts);
      }
      if (itemNode.type === 'string' || itemResolved.ref.endsWith('id_ref')) {
        return fieldShell(typeKey, field, stringList(path, value || [], {
          list: itemResolved.ref.endsWith('id_ref') ? listIdFor(field) : '',
        }), shellOpts);
      }
      if (itemNode.type === 'object') {
        return fieldShell(typeKey, field, arrayShell(path, value || [], (item, index) => {
          const title = item && (item.id || item.name || item.kind) ? `${item.id || item.name || item.kind}` : `条目 ${index + 1}`;
          return `<div class="item-card">
            ${itemHead(path, index, title, { up: index > 0, down: true })}
            ${renderObjectFields(itemResolved.schema, itemResolved.file, item, `${path}.${index}`, ctx)}
          </div>`;
        }, '条目'), shellOpts);
      }
      return fieldShell(typeKey, field, stringList(path, value || []), shellOpts);
    }

    if (type === 'object') {
      if (field === 'condition') {
        return fieldShell(typeKey, field, renderCondition(value, path, ctx, true), shellOpts);
      }
      return `<fieldset class="sub-object field-wide">
        <legend>${esc(label(typeKey, field))}${opts.required ? '<span class="req">*</span>' : ''}</legend>
        ${renderObjectFields(resolved.schema, resolved.file, value, path, ctx, { extraNote: true })}
        ${hint(typeKey, field) ? `<p class="field-hint">${esc(hint(typeKey, field))}</p>` : ''}
      </fieldset>`;
    }

    if (node.enum) {
      const enumValues = typeof catalog().enumOptions === 'function'
        ? catalog().enumOptions(typeKey, field, node.enum)
        : node.enum;
      return fieldShell(typeKey, field, selectEnum(path, value != null ? value : node.enum[0], enumValues), shellOpts);
    }
    if (type === 'boolean') {
      return fieldShell(typeKey, field, toggle(path, Boolean(value)), shellOpts);
    }
    if (type === 'integer' || type === 'number') {
      return fieldShell(typeKey, field, inputNumber(path, value, node), shellOpts);
    }
    if (field === 'deadline_formula') {
      return fieldShell(typeKey, field, inputText(path, value || '', { list: 'dl-formulas', className: 'mono' }), shellOpts);
    }
    if (field === 'icon' || field === 'texture' || field === 'model') {
      const kind = field === 'model' ? 'model' : 'image';
      return fieldShell(typeKey, field, assetPicker(path, value || '', kind, ctx.project), shellOpts);
    }
    if (field === 'name_key' || field === 'description_key') {
      const previewKey = previewLocalizationKey(value, ctx.localizationDraft);
      const preview = translated(ctx.project, value);
      return fieldShell(typeKey, field,
        `<input class="input mono key-preview" type="text" value="${attr(previewKey)}" data-nested-key-preview data-source-key="${attr(value || '')}" readonly spellcheck="false"><p class="field-hint">${esc(preview || '本地化键尚未填写或没有翻译')}</p>`, shellOpts);
    }
    return fieldShell(typeKey, field, inputText(path, value == null ? '' : value, { className: 'mono' }), shellOpts);
  }

  /* ------------------------------------------------------------------ */
  /* Definition editor                                                   */
  /* ------------------------------------------------------------------ */

  function previewLocalizationKey(key, draft) {
    if (!key || !draft || !draft.sourceBase || !draft.previewBase) return key || '';
    if (key === draft.sourceBase || key.startsWith(`${draft.sourceBase}.`)) {
      return draft.previewBase + key.slice(draft.sourceBase.length);
    }
    return key;
  }

  function renderKeyBlock(project, definition, field, typeKey, key, draft, token) {
    const draftToken = token || field;
    const previewKey = previewLocalizationKey(key, draft);
    const previewAttrs = draftToken.startsWith('key:')
      ? `data-nested-key-preview data-source-key="${attr(key || '')}"`
      : `data-key-preview-field="${attr(field)}"`;
    const localeRows = (project.localization || []).map((entry) => {
      const pending = draft && draft.values && draft.values[entry.locale]
        && Object.prototype.hasOwnProperty.call(draft.values[entry.locale], draftToken);
      const value = pending
        ? draft.values[entry.locale][draftToken]
        : ((entry.entries || {})[key] ?? (entry.entries || {})[previewKey] ?? '');
      return `<label class="entity-locale-row">
        <span class="locale-code mono">${esc(entry.locale)}</span>
        <input class="input" type="text" value="${attr(value)}" data-entity-locale="${attr(entry.locale)}" data-entity-locale-field="${attr(draftToken)}" placeholder="输入 ${esc(entry.locale)} 文本">
      </label>`;
    }).join('');
    const translatedCount = (project.localization || []).filter((entry) => {
      const pending = draft && draft.values && draft.values[entry.locale]
        && Object.prototype.hasOwnProperty.call(draft.values[entry.locale], draftToken);
      return String(pending ? draft.values[entry.locale][draftToken] : ((entry.entries || {})[key] || '')).trim();
    }).length;
    const localeCount = (project.localization || []).length;
    return `<div class="key-block">
      <div class="key-line">
        <input class="input mono key-preview" type="text" value="${attr(previewKey)}" ${previewAttrs} readonly spellcheck="false">
        <span class="key-state ${translatedCount === localeCount && localeCount ? 'ok' : 'missing'}">${translatedCount}/${localeCount}</span>
      </div>
      <div class="entity-locales">${localeRows || '<p class="field-hint">项目尚未创建语言文件。</p>'}</div>
      <button type="button" class="link-btn key-jump" data-action="goto-definition-localization" data-field="${attr(field)}" data-key="${attr(key || '')}">在语言配置中打开</button>
    </div>`;
  }

  function renderAdditionalLocalization(project, definition, typeKey, draft) {
    const primary = new Set([definition.name_key, definition.description_key].filter(Boolean));
    const keys = [...root.SNStore.collectDefinitionKeys(definition)].filter((key) => !primary.has(key));
    if (!keys.length) return '';
    return `<section class="form-section">
      <header class="section-head"><h4>条目内其他多语言文本</h4><p>事件选项、载荷等嵌套键也随实体 ID 一起预览和保存。</p></header>
      <div class="nested-localization-list">
        ${keys.map((key) => `<div class="nested-localization-item">
          <div class="nested-key-title mono">${esc(previewLocalizationKey(key, draft))}</div>
          ${renderKeyBlock(project, definition, 'nested_key', typeKey, key, draft, `key:${key}`)}
        </div>`).join('')}
      </div>
    </section>`;
  }

  function renderHullModuleConfiguration(definition) {
    const data = definition.data || {};
    const slotSchema = (max) => ({ type: 'integer', minimum: 0, maximum: max });
    const fixed = [
      { kind: 'boiler', code: 'BL', label: '锅炉', note: '推进系统，固定 1 位' },
      { kind: 'navigation', code: 'NV', label: '导航模块', note: '航线修正，固定 1 位' },
      { kind: 'safety', code: 'SF', label: '安全模块', note: '风险修正，固定 1 位' },
    ];
    return `<section class="form-section hull-module-section">
      <header class="section-head"><h4>模块配置</h4><p>船体决定可安装的模块位置；锅炉、导航与安全位由运行时固定，货舱和客舱位可在这里配置。</p></header>
      <div class="hull-module-grid">
        ${fixed.map((item) => `<div class="hull-module-card fixed" data-module-kind="${attr(item.kind)}">
          <span class="hull-module-code">${esc(item.code)}</span>
          <div><strong>${esc(item.label)}</strong><p>${esc(item.note)}</p></div>
          <span class="hull-module-count mono">1</span>
        </div>`).join('')}
        <div class="hull-module-card configurable" data-module-kind="cargo">
          <span class="hull-module-code">CG</span>
          <div><strong>货舱模块</strong><p>可安装的货舱模块数量</p></div>
          ${inputNumber('data.cargo_slots', data.cargo_slots, slotSchema(8), { extra: 'aria-label="货舱模块槽位"' })}
        </div>
        <div class="hull-module-card configurable" data-module-kind="cabin">
          <span class="hull-module-code">CB</span>
          <div><strong>客舱模块</strong><p>可安装的客舱模块数量</p></div>
          ${inputNumber('data.cabin_slots', data.cabin_slots, slotSchema(4), { extra: 'aria-label="客舱模块槽位"' })}
        </div>
      </div>
    </section>`;
  }

  /* ------------------------------------------------------------------ */
  /* Hull socket mirror (weapon_sockets / rig_sockets)                   */
  /* ------------------------------------------------------------------ */

  const SOCKET_CLASSES = ['Light', 'Medium', 'Heavy', 'Tower', 'Side'];
  const SOCKET_KINDS = ['mast', 'yard', 'sail'];
  const SOCKET_CLASS_COLORS = {
    Light: '#7fc7a4',
    Medium: '#e0b45a',
    Heavy: '#d97a72',
    Tower: '#9aa7e0',
    Side: '#8fc3e8',
  };
  const SOCKET_ROW_STYLE = 'display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:8px;';

  function socketBadge(value) {
    if (!value) return ' <span class="mini-badge ghost">未设置</span>';
    const color = SOCKET_CLASS_COLORS[value] || '#8fa2a4';
    return ` <span class="mini-badge" style="color:${attr(color)};border-color:${attr(color)}66;background:${attr(color)}1a">${esc(value)}</span>`;
  }

  function socketValueCounts(items, key) {
    const counts = new Map();
    for (const item of items) {
      const value = item ? item[key] : undefined;
      if (value == null || value === '') continue;
      counts.set(value, (counts.get(value) || 0) + 1);
    }
    return counts;
  }

  function socketRowHead(path, index, title, badge) {
    return `<header class="item-head">
      <span class="item-title">${esc(title)}${badge || ''}</span>
      <div class="item-tools">
        ${index > 0 ? `<button type="button" class="icon-btn tiny" data-action="array-move" data-path="${attr(path)}" data-index="${index}" data-dir="-1" title="上移">↑</button>` : ''}
        <button type="button" class="icon-btn tiny" data-action="array-move" data-path="${attr(path)}" data-index="${index}" data-dir="1" title="下移">↓</button>
        <button type="button" class="icon-btn tiny danger" data-action="array-remove" data-path="${attr(path)}" data-index="${index}" title="删除">✕</button>
      </div>
    </header>`;
  }

  function socketPositionField(path, value) {
    const values = Array.isArray(value) ? value : [];
    const axes = ['X', 'Y', 'Z'];
    return `<div class="field">
      <label class="field-label">${esc(label('hulls', 'position'))}</label>
      <div class="socket-position" style="display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:4px">
        ${axes.map((axis, axisIndex) => `<label class="socket-axis" style="display:flex;align-items:center;gap:3px" title="${axis} 轴（米）">
          <span class="muted-sm mono">${axis}</span>
          <input class="input mono" type="number" step="any" value="${values[axisIndex] == null ? '' : attr(values[axisIndex])}"
            data-field="${attr(`${path}.${axisIndex}`)}" data-parse="number" aria-label="${axis} 轴局部坐标">
        </label>`).join('')}
      </div>
      <p class="field-hint">船体局部坐标，Z 为该点甲板实测高度。</p>
    </div>`;
  }

  function socketDuplicateNote(duplicate, text) {
    return duplicate ? `<p class="field-hint" style="color:#eccb8a">${esc(text)}</p>` : '';
  }

  function renderWeaponSocketRow(item, index, nameCounts, indexCounts) {
    const value = item || {};
    const path = `data.weapon_sockets.${index}`;
    const duplicateName = value.name != null && value.name !== '' && (nameCounts.get(value.name) || 0) > 1;
    const duplicateIndex = value.socket_index != null && (indexCounts.get(value.socket_index) || 0) > 1;
    const title = value.name ? value.name : `武器安装点 ${index + 1}`;
    return `<div class="item-card slim socket-row" data-socket-row="weapon">
      ${socketRowHead('data.weapon_sockets', index, title, socketBadge(value.socket_class))}
      <div class="socket-fields" style="${SOCKET_ROW_STYLE}">
        <div class="field">
          <label class="field-label">安装点名称</label>
          ${inputText(`${path}.name`, value.name || '', { className: `mono ${duplicateName ? 'invalid' : ''}`, spellcheck: false })}
          ${socketDuplicateNote(duplicateName, '名称与同一船体的其它武器安装点重复。')}
        </div>
        <div class="field">
          <label class="field-label">安装点等级</label>
          ${selectEnum(`${path}.socket_class`, value.socket_class || 'Light', socketEnumOptions(SOCKET_CLASSES, 'socket_class'))}
        </div>
        <div class="field">
          <label class="field-label">安装点序号</label>
          ${inputNumber(`${path}.socket_index`, value.socket_index, { type: 'integer', minimum: 0, maximum: 64 }, { className: duplicateIndex ? 'invalid' : '' })}
          ${socketDuplicateNote(duplicateIndex, '序号与同一船体的其它武器安装点重复。')}
        </div>
        ${socketPositionField(`${path}.position`, value.position)}
        <div class="field">
          <label class="field-label">水平净空半径</label>
          ${inputNumber(`${path}.clearance_r`, value.clearance_r, { type: 'number', minimum: 0, maximum: 30 })}
        </div>
        <div class="field">
          <label class="field-label">X 向净空</label>
          ${inputNumber(`${path}.clearance_x`, value.clearance_x, { type: 'number', minimum: 0, maximum: 30 })}
        </div>
        <div class="field">
          <label class="field-label">Y 向净空</label>
          ${inputNumber(`${path}.clearance_y`, value.clearance_y, { type: 'number', minimum: 0, maximum: 30 })}
        </div>
        <div class="field">
          <label class="field-label">上方净空高度</label>
          ${inputNumber(`${path}.clearance_h`, value.clearance_h, { type: 'number', minimum: 0, maximum: 40 })}
        </div>
        <div class="field">
          <label class="field-label">装配缩放</label>
          ${inputNumber(`${path}.mount_scale`, value.mount_scale, { type: 'number', minimum: 0.1, maximum: 10 })}
        </div>
        <div class="field field-wide">
          <label class="field-label">备注</label>
          ${inputText(`${path}.note`, value.note || '', { className: '', placeholder: '人类可读备注，装配时忽略' })}
        </div>
      </div>
    </div>`;
  }

  function renderRigSocketRow(item, index, nameCounts, indexCounts) {
    const value = item || {};
    const path = `data.rig_sockets.${index}`;
    const duplicateName = value.name != null && value.name !== '' && (nameCounts.get(value.name) || 0) > 1;
    const duplicateIndex = value.socket_index != null && (indexCounts.get(value.socket_index) || 0) > 1;
    const title = value.name ? value.name : `帆索安装点 ${index + 1}`;
    return `<div class="item-card slim socket-row" data-socket-row="rig">
      ${socketRowHead('data.rig_sockets', index, title, socketBadge(value.socket_kind))}
      <div class="socket-fields" style="${SOCKET_ROW_STYLE}">
        <div class="field">
          <label class="field-label">安装点名称</label>
          ${inputText(`${path}.name`, value.name || '', { className: `mono ${duplicateName ? 'invalid' : ''}`, spellcheck: false })}
          ${socketDuplicateNote(duplicateName, '名称与同一船体的其它帆索安装点重复。')}
        </div>
        <div class="field">
          <label class="field-label">安装点类型</label>
          ${selectEnum(`${path}.socket_kind`, value.socket_kind || 'mast', socketEnumOptions(SOCKET_KINDS, 'socket_kind'))}
        </div>
        <div class="field">
          <label class="field-label">所属桅杆</label>
          ${inputText(`${path}.mast_id`, value.mast_id || '', { className: 'mono', placeholder: 'fore / main / mizzen' })}
        </div>
        <div class="field">
          <label class="field-label">安装点序号</label>
          ${inputNumber(`${path}.socket_index`, value.socket_index, { type: 'integer', minimum: 0, maximum: 64 }, { className: duplicateIndex ? 'invalid' : '' })}
          ${socketDuplicateNote(duplicateIndex, '序号与同一船体的其它帆索安装点重复。')}
        </div>
        ${socketPositionField(`${path}.position`, value.position)}
        <div class="field">
          <label class="field-label">帆索高度</label>
          ${inputNumber(`${path}.rig_height`, value.rig_height, { type: 'number', minimum: 0, maximum: 80 })}
        </div>
        <div class="field">
          <label class="field-label">甲板高度 Z</label>
          ${inputNumber(`${path}.rig_deck_z`, value.rig_deck_z, { type: 'number', minimum: 0, maximum: 80 })}
        </div>
        <div class="field">
          <label class="field-label">横桁高度 Z</label>
          ${inputNumber(`${path}.rig_yard_z`, value.rig_yard_z, { type: 'number', minimum: 0, maximum: 80 })}
        </div>
        <div class="field">
          <label class="field-label">横桁长度</label>
          ${inputNumber(`${path}.rig_yard_length`, value.rig_yard_length, { type: 'number', minimum: 0, maximum: 80 })}
        </div>
        <div class="field">
          <label class="field-label">帆面积（㎡）</label>
          ${inputNumber(`${path}.rig_sail_area_m2`, value.rig_sail_area_m2, { type: 'number', minimum: 0, maximum: 2000 })}
        </div>
        <div class="field">
          <label class="field-label">帆已收起</label>
          ${toggle(`${path}.rig_stowed`, Boolean(value.rig_stowed), '默认收起')}
        </div>
        <div class="field field-wide">
          <label class="field-label">备注</label>
          ${inputText(`${path}.note`, value.note || '', { className: '', placeholder: '人类可读备注，装配时忽略' })}
        </div>
      </div>
    </div>`;
  }

  function socketEnumOptions(values, field) {
    const entry = (catalog().FIELD_ENUM_LABELS || {})[`hulls.${field}`] || {};
    return values.map((value) => ({ key: value, label: entry[value] || value }));
  }

  function renderHullSocketConfiguration(definition) {
    const data = definition.data || {};
    const weaponSockets = Array.isArray(data.weapon_sockets) ? data.weapon_sockets : [];
    const rigSockets = Array.isArray(data.rig_sockets) ? data.rig_sockets : [];
    const weaponNameCounts = socketValueCounts(weaponSockets, 'name');
    const weaponIndexCounts = socketValueCounts(weaponSockets, 'socket_index');
    const rigNameCounts = socketValueCounts(rigSockets, 'name');
    const rigIndexCounts = socketValueCounts(rigSockets, 'socket_index');
    const weaponRows = weaponSockets.length
      ? weaponSockets.map((item, index) => renderWeaponSocketRow(item, index, weaponNameCounts, weaponIndexCounts)).join('')
      : '<p class="empty-inline">暂无武器安装点；GLB 里有 SN_Socket_Weapon_* 节点时可在此回填镜像。</p>';
    const rigRows = rigSockets.length
      ? rigSockets.map((item, index) => renderRigSocketRow(item, index, rigNameCounts, rigIndexCounts)).join('')
      : '<p class="empty-inline">暂无帆索安装点；GLB 里有 SN_Socket_Mast/Yard/Sail_* 节点时可在此回填镜像。</p>';
    return `<section class="form-section hull-socket-section">
      <header class="section-head"><h4>安装点（GLB socket 镜像）</h4>
        <p>与 GLB 节点 extras 同口径的船体侧镜像：武器安装点决定可装哪类武器（weapon_class），帆索安装点描述桅杆 / 横桁 / 帆面。运行时装配仍读 GLB；这里用于查看、编辑与校验。</p>
      </header>
      <div class="sub-section">
        <h5>武器安装点 <span class="muted-sm mono">${weaponSockets.length}</span></h5>
        <div class="array-editor">
          ${weaponRows}
          <div class="array-actions">
            <button type="button" class="btn small ghost" data-action="array-add" data-path="data.weapon_sockets">+ 新增武器安装点</button>
          </div>
        </div>
      </div>
      <div class="sub-section">
        <h5>帆索安装点 <span class="muted-sm mono">${rigSockets.length}</span></h5>
        <div class="array-editor">
          ${rigRows}
          <div class="array-actions">
            <button type="button" class="btn small ghost" data-action="array-add" data-path="data.rig_sockets">+ 新增帆索安装点</button>
          </div>
        </div>
      </div>
    </section>`;
  }

  function renderDefinitionForm(options) {
    const ctx = options;
    const project = ctx.project;
    const typeKey = ctx.typeKey;
    const info = catalog().BY_KEY[typeKey];
    const definition = ctx.definition;

    if (typeKey === 'patches') {
      const data = dataSchema('patches');
      return `<div class="form-body">
        <section class="form-section">
          <header class="section-head"><h4>补丁目标</h4><p>只能修改其他模组的定义；同一指针被多个模组修改时加载会失败。</p></header>
          ${renderObjectFields(data.schema, data.file, definition, '', ctx, { extraNote: false })}
        </section>
      </div>`;
    }

    const data = dataSchema(typeKey);
    if (!data) {
      /* A draft type whose schema is missing from the bundle (stale
       * schema-bundle.js) must not take the whole editor down. */
      return `<div class="form-body">
        <section class="form-section">
          <div class="notice warning" role="note">
            <div>
              <strong>找不到 ${esc(info.schema)} 对应的 Schema。</strong>
              <span>运行 <code>node SNModMaker/tools/sync-schemas.mjs</code> 重新生成 schema-bundle.js；在此之前可用顶部「JSON」直接编辑原始定义。</span>
            </div>
          </div>
          <textarea class="input mono code raw-json" id="raw-json" spellcheck="false">${esc(JSON.stringify(definition, null, 2))}</textarea>
        </section>
      </div>`;
    }
    const localId = root.SNStore.localPart(definition.id);
    const prefix = `${project.manifest.id}:${info.singular}/`;
    return `<div class="form-body">
      <section class="form-section">
        <header class="section-head"><h4>身份</h4><p>ID 使用三段式命名空间；名称键与描述键指向本地化文件。</p></header>
        <div class="field-grid">
          <div class="field field-wide">
            <label class="field-label">内容 ID<span class="req">*</span></label>
            <div class="id-input">
              <span class="id-prefix mono">${esc(prefix)}</span>
              <input class="input mono" type="text" value="${attr(localId)}" data-id-local="true" data-field="id" data-prefix="${attr(prefix)}" spellcheck="false">
            </div>
            <p class="field-hint">完整 ID：<span class="mono" data-id-preview>${esc(definition.id || '')}</span></p>
          </div>
          <div class="field">
            <label class="field-label">名称键<span class="req">*</span></label>
            ${renderKeyBlock(project, definition, 'name_key', typeKey, definition.name_key, ctx.localizationDraft)}
          </div>
          <div class="field">
            <label class="field-label">描述键</label>
            ${renderKeyBlock(project, definition, 'description_key', typeKey, definition.description_key, ctx.localizationDraft)}
          </div>
          <div class="field field-wide">
            <label class="field-label">标签</label>
            ${stringList('tags', definition.tags || [], { placeholder: '输入标签后回车' })}
            <p class="field-hint">常用：${(catalog().TAG_SUGGESTIONS[typeKey] || []).map((tag) => `<code>${esc(tag)}</code>`).join(' ') || '自由标签'}</p>
          </div>
          <div class="field">
            <label class="field-label">启用</label>
            ${toggle('enabled', definition.enabled !== false, '进入最终内容集合')}
          </div>
        </div>
      </section>
      ${renderAdditionalLocalization(project, definition, typeKey, ctx.localizationDraft)}
      <section class="form-section">
        <header class="section-head"><h4>视觉资源</h4><p>每个实体可以引用一个贴图与一个 GLB 模型；先在“资源”页添加文件，再选择对应资源键。</p></header>
        <div class="field-grid">
          ${fieldShell(typeKey, 'texture', assetPicker('information.texture', definition.information && definition.information.texture || '', 'image', project), { label: '贴图资源键', hint: '仅显示 png / webp / svg；也可以直接输入资源键。' })}
          ${fieldShell(typeKey, 'model', assetPicker('information.model', definition.information && definition.information.model || '', 'model', project), { label: '模型资源键', hint: '仅显示单文件 GLB；也可以直接输入资源键。' })}
        </div>
      </section>
      ${typeKey === 'hulls' ? renderHullModuleConfiguration(definition) : ''}
      ${typeKey === 'hulls' ? renderHullSocketConfiguration(definition) : ''}
      <section class="form-section">
        <header class="section-head"><h4>${esc(info.label)}数据</h4><p>字段约束来自 <code>${esc(info.schema)}</code>，留空或越界会立刻在校验页报出。</p></header>
        ${renderObjectFields(data.schema, data.file, definition.data || {}, 'data', ctx, {
          extraNote: true,
          skip: typeKey === 'hulls' ? ['cargo_slots', 'cabin_slots', 'weapon_sockets', 'rig_sockets'] : [],
        })}
      </section>
    </div>`;
  }

  root.SNUI = {
    esc,
    attr,
    fmtSize,
    fmtDate,
    debounce,
    uid,
    renderDatalists,
    renderDefinitionForm,
    renderHullSocketConfiguration,
    renderObjectFields,
    inputText,
    assetPicker,
    inputNumber,
    selectEnum,
    toggle,
    stringList,
    enumMulti,
    refInput,
    translated,
    fieldShell,
    toast,
    modal,
    closeModal,
    confirm,
    setBusy,
    dataSchema,
    listIdFor,
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
