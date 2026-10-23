// @static-doc
// 作用：船体蓝图槽位的可视化拖拽编辑器；在绑定的侧视 / 俯视线稿上显示舱位、模块位与武器位标记，拖动后自动计算归一化 uv 并通过 `data-field` 写回船体定义。
//
// ## 契约与约束
// - 纯经典脚本（无 ES module），暴露 `globalThis.SNBlueprintEditor`；`mount()` 之外不访问 DOM，便于 Node 单测。
// - 坐标空间：每个视图自己的线稿纹理归一化 uv，原点左上，范围 0..1；`space` 由 `data.blueprint_views.<view>.space` 决定，编辑器不重解释。
// - 写回路径：舱位 / 模块位 = `data.<array>.<i>.blueprint_position.<view>`，武器位 = `data.weapon_sockets.<i>.blueprint.<view>`。
// - 所有写入都经 `options.writeField(path, [u, v])`；由 app.js 转成一次 `change` 事件，复用撤销、校验与自动保存。本模块不直接改 project / definition 结构。
//
// ## 重点逻辑
// ### `uvFromPoint(rect, clientX, clientY)`
// - 用图片实际渲染矩形（`getBoundingClientRect`）做分母，避免留白导致坐标漂移；越界钳制到 0..1，并保留 4 位小数。
// ### `collectSlots(definition)`
// - 汇总 `compartments` / `module_slots` / `weapon_sockets` 为统一槽位描述；没有坐标的槽位也会返回，编辑器用默认位置显示为“未定位”。
// ### `mount(host, options)`
// - 渲染视图切换、线稿绑定选择器、画布与侧栏；拖动在 pointerup 时提交一次，避免连续 pointermove 产生大量历史快照。
// - 线稿通过 `project.assets[].dataUrl` 显示；工作区模式下 core 资源可能没有字节数据，此时只提示资源键而不报错。
// @end-static-doc
(function (root) {
  'use strict';

  const META_KEYS = {
    side: '侧视 side',
    top: '俯视 top',
  };

  function clamp01(value) {
    const number = Number(value);
    if (!Number.isFinite(number)) return 0;
    return Math.min(1, Math.max(0, number));
  }

  function round4(value) {
    return Math.round(clamp01(value) * 10000) / 10000;
  }

  /**
   * 把浏览器客户区坐标换算成图片内归一化 uv。
   * rect: { left, top, width, height }（通常是 img.getBoundingClientRect()）
   */
  function uvFromPoint(rect, clientX, clientY) {
    if (!rect || !(rect.width > 0) || !(rect.height > 0)) return [0, 0];
    return [
      round4((Number(clientX) - Number(rect.left)) / rect.width),
      round4((Number(clientY) - Number(rect.top)) / rect.height),
    ];
  }

  /** 把归一化 uv 换算成相对 rect 左上角的像素坐标，用于测试或外部叠加层。 */
  function pointFromUv(rect, uv) {
    const pair = Array.isArray(uv) ? uv : [0, 0];
    const width = rect && rect.width ? rect.width : 0;
    const height = rect && rect.height ? rect.height : 0;
    return {
      x: (rect ? Number(rect.left) || 0 : 0) + clamp01(pair[0]) * width,
      y: (rect ? Number(rect.top) || 0 : 0) + clamp01(pair[1]) * height,
    };
  }

  function readDefinitionData(definition) {
    return definition && typeof definition.data === 'object' && definition.data ? definition.data : {};
  }

  function positionFieldOf(slot) {
    return slot.group === 'weapon'
      ? `data.weapon_sockets.${slot.index}.blueprint`
      : `data.${slot.array}.${slot.index}.blueprint_position`;
  }

  function slotIdOf(item, fallback) {
    if (!item || typeof item !== 'object') return fallback;
    if (slotName(item)) return slotName(item);
    return fallback;
  }

  function slotName(item) {
    return String(item.id || item.name || '').trim();
  }

  /** 汇总船体定义里的三类槽位；返回顺序固定为舱位 → 模块位 → 武器位。 */
  function collectSlots(definition) {
    const data = readDefinitionData(definition);
    const slots = [];
    const push = (group, array, items, labelPrefix) => {
      (Array.isArray(items) ? items : []).forEach((item, index) => {
        const value = item && typeof item === 'object' ? item : {};
        const id = slotName(value) || `${group}_${index + 1}`;
        slots.push({
          group,
          array,
          index,
          id,
          label: `${labelPrefix} ${id}`,
          positionField: group === 'weapon'
            ? `data.weapon_sockets.${index}.blueprint`
            : `data.${array}.${index}.blueprint_position`,
          value,
        });
      });
    };
    push('compartment', 'compartments', data.compartments, '舱位');
    push('module_slot', 'module_slots', data.module_slots, '模块位');
    push('weapon', 'weapon_sockets', data.weapon_sockets, '武器位');
    return slots;
  }

  function slotKey(slot) {
    return `${slot.group}:${slot.index}`;
  }

  function slotPosition(slot, view) {
    const value = slot && slot.value && typeof slot.value === 'object' ? slot.value : {};
    const source = slot.group === 'weapon' ? value.blueprint : value.blueprint_position;
    const pair = source && Array.isArray(source[view]) ? source[view] : null;
    if (!pair || pair.length < 2) return null;
    if (!Number.isFinite(Number(pair[0])) || !Number.isFinite(Number(pair[1]))) return null;
    return [clamp01(pair[0]), clamp01(pair[1])];
  }

  /** 解析某视图绑定的线稿资源；返回 { key, asset, dataUrl } 或 null。 */
  function resolveViewImage(definition, project, view) {
    const data = readDefinitionData(definition);
    const views = data.blueprint_views && typeof data.blueprint_views === 'object' ? data.blueprint_views : {};
    const entry = views[view];
    const key = entry && typeof entry === 'object' ? String(entry.image || '') : '';
    if (!key) return null;
    const assets = project && Array.isArray(project.assets) ? project.assets : [];
    const asset = assets.find((item) => item && item.key === key) || null;
    return {
      key,
      asset,
      dataUrl: asset && asset.dataUrl ? String(asset.dataUrl) : '',
      width: (entry && Number(entry.width)) || (asset && Number(asset.width)) || 0,
      height: (entry && Number(entry.height)) || (asset && Number(asset.height)) || 0,
    };
  }

  function isImageAsset(asset) {
    const mime = String((asset && asset.mime) || '').toLowerCase();
    const path = String((asset && asset.path) || '').toLowerCase();
    return mime.startsWith('image/') || /\.(png|webp|svg)$/.test(path);
  }

  function findImageAssets(project) {
    const assets = project && Array.isArray(project.assets) ? project.assets : [];
    return assets.filter(isImageAsset).sort((a, b) => String(a.key || '').localeCompare(String(b.key || '')));
  }

  function formatPair(pair) {
    if (!pair) return '未定位';
    return `(${Number(pair[0]).toFixed(3)}, ${Number(pair[1]).toFixed(3)})`;
  }

  function markerClass(group) {
    return `bp-marker bp-marker-${group}`;
  }

  function groupLabel(group) {
    if (group === 'compartment') return '舱位';
    if (group === 'module_slot') return '模块位';
    return '武器位';
  }

  function escapeHtml(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function assetPickerHtml(path, value, project, placeholder) {
    const UI = root.SNUI;
    if (UI && typeof UI.assetPicker === 'function') {
      return UI.assetPicker(path, value || '', 'image', project, { placeholder });
    }
    return `<input class="input mono" type="text" value="${escapeHtml(value || '')}"
      data-field="${escapeHtml(path)}" data-parse="text" placeholder="${escapeHtml(placeholder || '')}">`;
  }

  function mount(host, options) {
    if (!host) return null;
    const opts = options || {};
    const project = opts.project || {};
    const getDefinition = typeof opts.getDefinition === 'function' ? opts.getDefinition : () => opts.definition;
    const writeField = typeof opts.writeField === 'function' ? opts.writeField : () => {};
    const state = {
      view: 'side',
      selected: '',
      drag: null,
      imageRect: null,
    };

    host.innerHTML = `
      <div class="bp-editor">
        <div class="bp-toolbar">
          <div class="bp-view-tabs">
            <button type="button" class="btn small bp-view-tab" data-bp-view="side">侧视 side</button>
            <button type="button" class="btn small bp-view-tab" data-bp-view="top">俯视 top</button>
          </div>
          <div class="bp-bindings">
            <label class="bp-binding">
              <span class="muted-sm">侧视线稿</span>
              ${assetPickerHtml('data.blueprint_views.side.image', '', project, '例如 blueprint.ship.side')}
            </label>
            <label class="bp-binding">
              <span class="muted-sm">俯视线稿</span>
              ${assetPickerHtml('data.blueprint_views.top.image', '', project, '例如 blueprint.ship.top')}
            </label>
          </div>
          <p class="bp-hint muted-sm">拖动标记定位；坐标自动写回船体定义。</p>
        </div>
        <div class="bp-body">
          <div class="bp-stage">
            <div class="bp-canvas" data-bp-canvas hidden>
              <div class="bp-marker-layer" data-bp-markers></div>
            </div>
            <div class="bp-empty" data-bp-empty>
              <p>当前视图还没有可预览的线稿。</p>
              <p class="muted-sm">在上方选择资源键，或先到「资源」页添加一张 PNG / WebP 线稿图片。工作区模式下的 core 资源可能只有键、没有图片字节。</p>
            </div>
          </div>
          <aside class="bp-side">
            <div class="bp-side-head">
              <h5>槽位</h5>
              <span class="muted-sm" data-bp-count></span>
            </div>
            <div class="bp-slot-list" data-bp-list></div>
            <p class="bp-readout muted-sm" data-bp-readout>选择或拖动一个槽位查看坐标。</p>
          </aside>
        </div>
      </div>`;

    const canvas = host.querySelector('[data-bp-canvas]');
    const markers = host.querySelector('[data-bp-markers]');
    const empty = host.querySelector('[data-bp-empty]');
    const list = host.querySelector('[data-bp-list]');
    const readout = host.querySelector('[data-bp-readout]');
    const count = host.querySelector('[data-bp-count]');
    let imageNode = null;

    function definition() {
      return getDefinition() || {};
    }

    function slots() {
      return collectSlots(definition());
    }

    function selectedSlot() {
      const all = slots();
      return all.find((slot) => slotKey(slot) === state.selected) || null;
    }

    function bindingValue(view) {
      const data = readDefinitionData(definition());
      const views = data.blueprint_views && typeof data.blueprint_views === 'object' ? data.blueprint_views : {};
      return views[view] && views[view].image ? String(views[view].image) : '';
    }

    function renderToolbar() {
      host.querySelectorAll('[data-bp-view]').forEach((button) => {
        button.classList.toggle('active', button.dataset.bpView === state.view);
      });
      const pickers = host.querySelectorAll('.bp-bindings input[data-field]');
      pickers.forEach((input) => {
        const view = input.dataset.field.endsWith('.side.image') ? 'side' : 'top';
        if (document.activeElement !== input) input.value = bindingValue(view);
      });
    }

    function renderEmpty() {
      const image = resolveViewImage(definition(), project, state.view);
      const hasKey = Boolean(image && image.key);
      const message = host.querySelector('[data-bp-empty] p');
      if (message) {
        message.textContent = hasKey
          ? `已绑定资源键 ${image.key}，但当前项目无法读取图片数据（工作区模式或资源缺失）。`
          : '当前视图还没有可预览的线稿。';
      }
      canvas.hidden = true;
      empty.hidden = false;
    }

    function renderCanvas() {
      const image = resolveViewImage(definition(), project, state.view);
      if (!image || !image.dataUrl) {
        renderEmpty();
        return;
      }
      empty.hidden = true;
      canvas.hidden = false;
      const currentSrc = imageNode ? imageNode.getAttribute('src') : '';
      if (!imageNode || currentSrc !== image.dataUrl) {
        if (imageNode) imageNode.remove();
        imageNode = document.createElement('img');
        imageNode.className = 'bp-image';
        imageNode.alt = image.key;
        imageNode.draggable = false;
        imageNode.addEventListener('load', () => {
          state.imageRect = imageNode.getBoundingClientRect();
          placeMarkers();
        });
        imageNode.src = image.dataUrl;
        canvas.insertBefore(imageNode, markers);
      }
      requestAnimationFrame(() => {
        if (imageNode) state.imageRect = imageNode.getBoundingClientRect();
        placeMarkers();
      });
    }

    function placeMarkers() {
      const all = slots();
      const byKey = new Map();
      markers.querySelectorAll('[data-bp-slot]').forEach((node) => byKey.set(node.dataset.bpSlot, node));
      const unplaced = [];
      all.forEach((slot, order) => {
        const key = slotKey(slot);
        let node = byKey.get(key);
        if (!node) {
          node = document.createElement('button');
          node.type = 'button';
          node.className = markerClass(slot.group);
          node.dataset.bpSlot = key;
          node.title = slot.label;
          node.innerHTML = `<span class="bp-marker-dot"></span><span class="bp-marker-label">${escapeHtml(slot.id)}</span>`;
          markers.appendChild(node);
        }
        node.classList.toggle('selected', key === state.selected);
        const position = slotPosition(slot, state.view);
        if (position) {
          node.classList.remove('unplaced');
          node.style.left = `${(position[0] * 100).toFixed(2)}%`;
          node.style.top = `${(position[1] * 100).toFixed(2)}%`;
        } else {
          node.classList.add('unplaced');
          unplaced.push({ node, order });
          node.style.left = '50%';
          node.style.top = '50%';
        }
      });
      unplaced.forEach((entry, index) => {
        const angle = (Math.PI * 2 * index) / Math.max(1, unplaced.length);
        const radius = 18 + Math.floor(index / 6) * 12;
        entry.node.style.left = `calc(50% + ${Math.round(Math.cos(angle) * radius)}px)`;
        entry.node.style.top = `calc(50% + ${Math.round(Math.sin(angle) * radius)}px)`;
      });
    }

    function renderList() {
      const all = slots();
      count.textContent = `${all.length} 个`;
      if (!all.length) {
        list.innerHTML = '<p class="muted-sm">当前船体还没有舱位 / 模块位 / 武器位。先在表单里添加上方数组项。</p>';
        return;
      }
      list.innerHTML = all.map((slot) => {
        const side = slotPosition(slot, 'side');
        const top = slotPosition(slot, 'top');
        return `<button type="button" class="bp-slot-row ${slotKey(slot) === state.selected ? 'active' : ''}" data-bp-select="${slotKey(slot)}">
          <span class="bp-slot-group bp-slot-group-${slot.group}">${groupLabel(slot.group)}</span>
          <span class="bp-slot-id mono">${escapeHtml(slot.id)}</span>
          <span class="bp-slot-uv muted-sm">${escapeHtml(`side ${formatPair(side)} · top ${formatPair(top)}`)}</span>
        </button>`;
      }).join('');
    }

    function updateReadout() {
      const slot = selectedSlot();
      if (!slot) {
        readout.textContent = '选择或拖动一个槽位查看坐标。';
        return;
      }
      const position = slotPosition(slot, state.view);
      readout.textContent = `${groupLabel(slot.group)} ${slot.id} · ${META_KEYS[state.view]} = ${formatPair(position)}`;
    }

    function selectSlot(key, switchView) {
      state.selected = key;
      if (switchView) {
        const slot = slots().find((item) => slotKey(item) === key);
        if (slot && !slotPosition(slot, state.view)) {
          const other = state.view === 'side' ? 'top' : 'side';
          if (slotPosition(slot, other)) state.view = other;
        }
      }
      renderToolbar();
      placeMarkers();
      renderList();
      updateReadout();
    }

    function refresh() {
      if (state.view === 'side' && !resolveViewImage(definition(), project, 'side')?.dataUrl) {
        const top = resolveViewImage(definition(), project, 'top');
        if (top && top.dataUrl) state.view = 'top';
      }
      renderToolbar();
      renderCanvas();
      placeMarkers();
      renderList();
      updateReadout();
    }

    function onViewClick(event) {
      const button = event.target.closest('[data-bp-view]');
      if (!button) return;
      state.view = button.dataset.bpView === 'top' ? 'top' : 'side';
      refresh();
    }

    function onListClick(event) {
      const row = event.target.closest('[data-bp-select]');
      if (!row) return;
      selectSlot(row.dataset.bpSelect, true);
    }

    function onPointerDown(event) {
      const marker = event.target.closest('[data-bp-slot]');
      if (!marker) {
        const row = event.target.closest('[data-bp-select]');
        if (row) return;
        const stage = event.target.closest('.bp-stage');
        if (stage) {
          state.selected = '';
          renderList();
          placeMarkers();
          updateReadout();
        }
        return;
      }
      const slot = slots().find((item) => slotKey(item) === marker.dataset.bpSlot);
      if (!slot) return;
      event.preventDefault();
      state.selected = slotKey(slot);
      if (imageNode) state.imageRect = imageNode.getBoundingClientRect();
      state.drag = { slot };
      try {
        if (marker.setPointerCapture) marker.setPointerCapture(event.pointerId);
      } catch (error) {
        /* 合成事件没有活动指针，忽略捕获即可继续拖动 */
      }
      marker.classList.add('dragging');
      window.addEventListener('pointermove', onPointerMove);
      window.addEventListener('pointerup', onPointerUp, { once: true });
      renderList();
      updateReadout();
    }

    function onPointerMove(event) {
      if (!state.drag) return;
      // 每次移动都取实时矩形：Modal 布局/滚动变化后缓存矩形会过期，导致坐标漂移。
      const rect = imageNode ? imageNode.getBoundingClientRect() : state.imageRect;
      const uv = uvFromPoint(rect, event.clientX, event.clientY);
      state.drag.uv = uv;
      const marker = markers.querySelector(`[data-bp-slot="${state.drag.slot.group}:${state.drag.slot.index}"]`);
      if (marker) {
        marker.classList.remove('unplaced');
        marker.style.left = `${(uv[0] * 100).toFixed(2)}%`;
        marker.style.top = `${(uv[1] * 100).toFixed(2)}%`;
      }
      readout.textContent = `${groupLabel(state.drag.slot.group)} ${state.drag.slot.id} · ${META_KEYS[state.view]} = ${formatPair(uv)}`;
    }

    function onPointerUp() {
      const drag = state.drag;
      state.drag = null;
      window.removeEventListener('pointermove', onPointerMove);
      if (!drag || !drag.uv) return;
      const path = `${drag.slot.positionField}.${state.view}`;
      writeField(path, [round4(drag.uv[0]), round4(drag.uv[1])]);
      const marker = markers.querySelector(`[data-bp-slot="${drag.slot.group}:${drag.slot.index}"]`);
      if (marker) marker.classList.remove('dragging');
      refresh();
    }

    function onBindingChange(event) {
      const input = event.target;
      if (!input || !input.matches || !input.matches('input[data-field]')) return;
      if (!String(input.dataset.field || '').startsWith('data.blueprint_views.')) return;
      // app.js 的 document 级 change 监听在本监听之后才写回定义，等一拍再刷新。
      setTimeout(refresh, 0);
    }

    host.addEventListener('click', onViewClick);
    host.addEventListener('click', onListClick);
    host.addEventListener('pointerdown', onPointerDown);
    host.addEventListener('change', onBindingChange);
    window.addEventListener('resize', refresh);
    refresh();

    return {
      refresh,
      destroy() {
        host.removeEventListener('click', onViewClick);
        host.removeEventListener('click', onListClick);
        host.removeEventListener('pointerdown', onPointerDown);
        host.removeEventListener('change', onBindingChange);
        window.removeEventListener('resize', refresh);
        window.removeEventListener('pointermove', onPointerMove);
        window.removeEventListener('pointerup', onPointerUp);
      },
    };
  }

  root.SNBlueprintEditor = {
    clamp01,
    round4,
    uvFromPoint,
    pointFromUv,
    collectSlots,
    slotKey,
    slotPosition,
    resolveViewImage,
    findImageAssets,
    formatPair,
    mount,
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
