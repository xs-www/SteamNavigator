// @static-doc
// 作用：渲染独立 FSM 工作台，支持状态拖放、端口拉线、空白处快速建状态、Delete 删除及按选中状态过滤的聚合转移编辑。
//
// ## 契约与约束
// - 状态定义可从外部以 application/x-snbattle-fsm-action 拖入画布。
// - 选中状态后只显示该状态的出向转移；每条转移可使用 all/any 聚合最多 8 个条件。
// - Delete 只在非表单焦点下删除当前状态；删除状态会同时删除关联转移。
// @end-static-doc

import { defaultFsm, FSM_ACTIONS, FSM_CONDITIONS, normalizeFsm } from "./tactics.mjs";

const escapeHtml = (value) => String(value).replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[char]));
const actionOptions = (selected) => Object.entries(FSM_ACTIONS).map(([id, label]) => `<option value="${id}" ${id === selected ? "selected" : ""}>${label}</option>`).join("");
const conditionOptions = (selected) => Object.entries(FSM_CONDITIONS).map(([id, label]) => `<option value="${id}" ${id === selected ? "selected" : ""}>${label}</option>`).join("");

export function mountFsmEditor(root, initialFsm, onChange) {
  let fsm = normalizeFsm(initialFsm);
  let selection = { type: "node", id: fsm.initial };
  let connection = null;
  let pendingConnection = null;
  root.innerHTML = `<div class="fsm-toolbar"><button type="button" data-fsm-add>+ 状态</button><button type="button" data-fsm-reset>恢复默认</button><span>拖入左侧状态定义，从节点右端口拉线创建转移</span></div>
    <div class="fsm-canvas"><svg class="fsm-wires"><defs><marker id="fsmArrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z"></path></marker></defs><g data-fsm-lines></g><path data-fsm-preview class="fsm-preview"></path></svg><div data-fsm-nodes></div></div>
    <div class="fsm-inspector" data-fsm-inspector></div>
    <section class="fsm-transition-panel"><div class="fsm-transition-heading"><b data-transition-title>选中状态的转移</b><span>同一状态内自上而下判定</span></div><div data-fsm-transition-list></div></section>
    <dialog class="fsm-create-dialog"><form method="dialog"><h3>创建并连接新状态</h3><label>状态名称<input data-new-node-name maxlength="24" value="新状态"></label><label>运行时动作<select data-new-node-action>${actionOptions("engage")}</select></label><div><button value="cancel">取消</button><button value="default" class="primary" data-new-node-confirm>创建并连接</button></div></form></dialog>`;

  const canvas = root.querySelector(".fsm-canvas");
  const nodesHost = root.querySelector("[data-fsm-nodes]");
  const linesHost = root.querySelector("[data-fsm-lines]");
  const preview = root.querySelector("[data-fsm-preview]");
  const inspector = root.querySelector("[data-fsm-inspector]");
  const transitionList = root.querySelector("[data-fsm-transition-list]");
  const transitionTitle = root.querySelector("[data-transition-title]");
  const dialog = root.querySelector(".fsm-create-dialog");

  const commit = () => { fsm = normalizeFsm(fsm); onChange(fsm); };
  const nodeById = (id) => fsm.nodes.find((node) => node.id === id);
  const uniqueNodeId = () => { let id = `state_${Date.now().toString(36)}`, serial = 2; while (nodeById(id)) id = `state_${Date.now().toString(36)}_${serial++}`; return id; };
  const addNode = (action = "engage", x = 0.5, y = 0.5, name = FSM_ACTIONS[action]) => {
    if (fsm.nodes.length >= 20) return null;
    const node = { id: uniqueNodeId(), name: String(name || FSM_ACTIONS[action]).slice(0, 24), action: Object.hasOwn(FSM_ACTIONS, action) ? action : "engage", x, y };
    fsm.nodes.push(node); selection = { type: "node", id: node.id }; return node;
  };
  const removeNode = (node) => {
    if (!node || fsm.nodes.length <= 1) return;
    fsm.nodes = fsm.nodes.filter((item) => item.id !== node.id);
    fsm.transitions = fsm.transitions.filter((edge) => edge.from !== node.id && edge.to !== node.id);
    if (fsm.initial === node.id) fsm.initial = fsm.nodes[0].id;
    selection = { type: "node", id: fsm.initial }; commit(); render();
  };
  const pointFor = (id, side) => {
    const element = nodesHost.querySelector(`[data-node-id="${CSS.escape(id)}"]`);
    if (!element) return { x: 0, y: 0 };
    const box = element.getBoundingClientRect(); const parent = canvas.getBoundingClientRect();
    return { x: (side === "out" ? box.right : box.left) - parent.left, y: box.top + box.height / 2 - parent.top };
  };
  const pathBetween = (from, to) => { const bend = Math.max(34, Math.abs(to.x - from.x) * 0.48); return `M${from.x},${from.y} C${from.x + bend},${from.y} ${to.x - bend},${to.y} ${to.x},${to.y}`; };
  const drawLines = () => {
    linesHost.innerHTML = fsm.transitions.map((edge) => {
      const d = pathBetween(pointFor(edge.from, "out"), pointFor(edge.to, "in"));
      const active = selection.type === "edge" && selection.id === edge.id ? " active" : "";
      return `<path class="fsm-edge-hit" data-edge-id="${escapeHtml(edge.id)}" d="${d}"></path><path class="fsm-edge${active}" d="${d}" marker-end="url(#fsmArrow)"></path>`;
    }).join("");
  };
  const selectedSourceId = () => selection.type === "edge" ? fsm.transitions.find((edge) => edge.id === selection.id)?.from || fsm.initial : selection.id;
  const renderInspector = () => {
    if (selection.type === "edge") {
      const edge = fsm.transitions.find((item) => item.id === selection.id);
      if (!edge) { selection = { type: "node", id: fsm.initial }; return renderInspector(); }
      inspector.innerHTML = `<b>转移</b><span>${escapeHtml(nodeById(edge.from)?.name)} → ${escapeHtml(nodeById(edge.to)?.name)}</span><button type="button" data-select-source>查看该状态全部转移</button><button type="button" class="danger-inline" data-edge-delete>删除转移</button>`;
      inspector.querySelector("[data-select-source]").addEventListener("click", () => { selection = { type: "node", id: edge.from }; render(); });
      inspector.querySelector("[data-edge-delete]").addEventListener("click", () => { fsm.transitions = fsm.transitions.filter((item) => item.id !== edge.id); selection = { type: "node", id: edge.from }; commit(); render(); });
      return;
    }
    const node = nodeById(selection.id) || fsm.nodes[0];
    inspector.innerHTML = `<b>状态节点</b><input data-node-name maxlength="24" value="${escapeHtml(node.name)}"><select data-node-action>${actionOptions(node.action)}</select><button type="button" data-node-initial ${fsm.initial === node.id ? "disabled" : ""}>${fsm.initial === node.id ? "初始状态" : "设为初始"}</button><button type="button" class="danger-inline" data-node-delete ${fsm.nodes.length <= 1 ? "disabled" : ""}>删除状态</button>`;
    inspector.querySelector("[data-node-name]").addEventListener("change", (event) => { node.name = event.target.value || FSM_ACTIONS[node.action]; commit(); render(); });
    inspector.querySelector("[data-node-action]").addEventListener("change", (event) => { node.action = event.target.value; commit(); render(); });
    inspector.querySelector("[data-node-initial]").addEventListener("click", () => { fsm.initial = node.id; commit(); render(); });
    inspector.querySelector("[data-node-delete]").addEventListener("click", () => removeNode(node));
  };
  const renderTransitions = () => {
    const sourceId = selectedSourceId(); const source = nodeById(sourceId) || fsm.nodes[0];
    const outgoing = fsm.transitions.filter((edge) => edge.from === source.id);
    transitionTitle.textContent = `${source.name} 的转移扳机`;
    const nodeOptions = (selected) => fsm.nodes.map((node) => `<option value="${escapeHtml(node.id)}" ${node.id === selected ? "selected" : ""}>${escapeHtml(node.name)}</option>`).join("");
    transitionList.innerHTML = outgoing.map((edge, index) => `<div class="fsm-transition-row ${selection.type === "edge" && selection.id === edge.id ? "active" : ""}" data-transition-id="${escapeHtml(edge.id)}"><span class="fsm-priority">${index + 1}</span><select data-edge-logic title="条件聚合"><option value="all" ${edge.logic === "all" ? "selected" : ""}>全部满足（且）</option><option value="any" ${edge.logic === "any" ? "selected" : ""}>任一满足（或）</option></select><div class="fsm-condition-stack">${edge.conditions.map((condition, conditionIndex) => `<div><select data-condition-index="${conditionIndex}">${conditionOptions(condition)}</select><button data-remove-condition="${conditionIndex}" ${edge.conditions.length <= 1 ? "disabled" : ""} title="移除条件">−</button></div>`).join("")}<button data-add-condition ${edge.conditions.length >= 8 ? "disabled" : ""}>+ 条件</button></div><span>→</span><select data-edge-to>${nodeOptions(edge.to)}</select><button data-edge-up title="提高优先级">↑</button><button data-edge-down title="降低优先级">↓</button><button data-edge-delete class="danger-inline" title="删除转移">×</button></div>`).join("") || `<div class="empty compact">该状态没有转移。请从节点右端口拉线创建。</div>`;
    transitionList.querySelectorAll(".fsm-transition-row").forEach((row) => {
      const edge = fsm.transitions.find((item) => item.id === row.dataset.transitionId);
      row.addEventListener("click", () => { selection = { type: "edge", id: edge.id }; render(); });
      row.querySelectorAll("select,button").forEach((control) => control.addEventListener("click", (event) => event.stopPropagation()));
      row.querySelector("[data-edge-logic]").addEventListener("change", (event) => { edge.logic = event.target.value; commit(); render(); });
      row.querySelector("[data-edge-to]").addEventListener("change", (event) => { edge.to = event.target.value; commit(); render(); });
      row.querySelectorAll("[data-condition-index]").forEach((select) => select.addEventListener("change", () => { edge.conditions[Number(select.dataset.conditionIndex)] = select.value; commit(); render(); }));
      row.querySelector("[data-add-condition]").addEventListener("click", () => { edge.conditions.push("always"); commit(); render(); });
      row.querySelectorAll("[data-remove-condition]").forEach((button) => button.addEventListener("click", () => { edge.conditions.splice(Number(button.dataset.removeCondition), 1); commit(); render(); }));
      const move = (offset) => { const peers = fsm.transitions.filter((item) => item.from === edge.from); const peerIndex = peers.indexOf(edge); const other = peers[peerIndex + offset]; if (!other) return; const at = fsm.transitions.indexOf(edge), otherAt = fsm.transitions.indexOf(other); [fsm.transitions[at], fsm.transitions[otherAt]] = [fsm.transitions[otherAt], fsm.transitions[at]]; commit(); render(); };
      row.querySelector("[data-edge-up]").addEventListener("click", () => move(-1));
      row.querySelector("[data-edge-down]").addEventListener("click", () => move(1));
      row.querySelector("[data-edge-delete]").addEventListener("click", () => { fsm.transitions = fsm.transitions.filter((item) => item.id !== edge.id); selection = { type: "node", id: edge.from }; commit(); render(); });
    });
  };
  const bindNode = (element, node) => {
    element.addEventListener("click", () => { selection = { type: "node", id: node.id }; render(); });
    element.addEventListener("pointerdown", (event) => {
      if (event.target.closest(".fsm-port")) return;
      event.preventDefault(); element.setPointerCapture(event.pointerId);
      const bounds = canvas.getBoundingClientRect(); const start = { x: event.clientX, y: event.clientY, nx: node.x, ny: node.y };
      const move = (next) => { node.x = Math.max(0.08, Math.min(0.92, start.nx + (next.clientX - start.x) / bounds.width)); node.y = Math.max(0.08, Math.min(0.92, start.ny + (next.clientY - start.y) / bounds.height)); element.style.left = `${node.x * 100}%`; element.style.top = `${node.y * 100}%`; drawLines(); };
      const up = () => { element.removeEventListener("pointermove", move); element.removeEventListener("pointerup", up); commit(); };
      element.addEventListener("pointermove", move); element.addEventListener("pointerup", up);
    });
    element.querySelector(".fsm-port.out").addEventListener("pointerdown", (event) => {
      event.preventDefault(); event.stopPropagation(); connection = { from: node.id, pointerId: event.pointerId }; canvas.setPointerCapture(event.pointerId);
      const box = canvas.getBoundingClientRect(); preview.setAttribute("d", pathBetween(pointFor(node.id, "out"), { x: event.clientX - box.left, y: event.clientY - box.top }));
    });
  };
  const render = () => {
    nodesHost.innerHTML = fsm.nodes.map((node) => `<div class="fsm-node ${selection.type === "node" && selection.id === node.id ? "active" : ""} ${fsm.initial === node.id ? "initial" : ""}" data-node-id="${escapeHtml(node.id)}" style="left:${node.x * 100}%;top:${node.y * 100}%"><i class="fsm-port in"></i><b>${escapeHtml(node.name)}</b><small>${FSM_ACTIONS[node.action]}</small><i class="fsm-port out"></i></div>`).join("");
    fsm.nodes.forEach((node) => bindNode(nodesHost.querySelector(`[data-node-id="${CSS.escape(node.id)}"]`), node));
    drawLines(); renderInspector(); renderTransitions();
  };
  const createEdge = (from, to) => { if (fsm.transitions.length >= 80 || from === to) return null; const edge = { id: `edge_${Date.now().toString(36)}`, from, to, logic: "all", conditions: ["always"] }; fsm.transitions.push(edge); selection = { type: "edge", id: edge.id }; return edge; };

  canvas.addEventListener("pointermove", (event) => { if (!connection) return; const box = canvas.getBoundingClientRect(); preview.setAttribute("d", pathBetween(pointFor(connection.from, "out"), { x: event.clientX - box.left, y: event.clientY - box.top })); });
  canvas.addEventListener("pointerup", (event) => {
    if (!connection) return;
    const target = document.elementFromPoint(event.clientX, event.clientY)?.closest(".fsm-node");
    if (target && target.dataset.nodeId !== connection.from) { createEdge(connection.from, target.dataset.nodeId); commit(); }
    else if (fsm.nodes.length < 20) { const box = canvas.getBoundingClientRect(); pendingConnection = { from: connection.from, x: Math.max(0.08, Math.min(0.92, (event.clientX - box.left) / box.width)), y: Math.max(0.08, Math.min(0.92, (event.clientY - box.top) / box.height)) }; dialog.showModal(); }
    connection = null; preview.setAttribute("d", ""); render();
  });
  canvas.addEventListener("dragover", (event) => { if (Array.from(event.dataTransfer.types).includes("application/x-snbattle-fsm-action")) { event.preventDefault(); event.dataTransfer.dropEffect = "copy"; } });
  canvas.addEventListener("drop", (event) => { let payload; try { payload = JSON.parse(event.dataTransfer.getData("application/x-snbattle-fsm-action")); } catch { payload = { action: event.dataTransfer.getData("application/x-snbattle-fsm-action") }; } if (!Object.hasOwn(FSM_ACTIONS, payload.action)) return; event.preventDefault(); const box = canvas.getBoundingClientRect(); addNode(payload.action, Math.max(0.08, Math.min(0.92, (event.clientX - box.left) / box.width)), Math.max(0.08, Math.min(0.92, (event.clientY - box.top) / box.height)), payload.name || FSM_ACTIONS[payload.action]); commit(); render(); });
  dialog.querySelector("[data-new-node-confirm]").addEventListener("click", (event) => { event.preventDefault(); if (!pendingConnection) return dialog.close(); const action = dialog.querySelector("[data-new-node-action]").value; const node = addNode(action, pendingConnection.x, pendingConnection.y, dialog.querySelector("[data-new-node-name]").value); if (node) createEdge(pendingConnection.from, node.id); pendingConnection = null; dialog.close(); commit(); render(); });
  dialog.addEventListener("close", () => { pendingConnection = null; });
  linesHost.addEventListener("click", (event) => { const id = event.target.dataset.edgeId; if (id) { selection = { type: "edge", id }; render(); } });
  root.querySelector("[data-fsm-add]").addEventListener("click", () => { if (addNode()) { commit(); render(); } });
  root.querySelector("[data-fsm-reset]").addEventListener("click", () => { fsm = defaultFsm(); selection = { type: "node", id: fsm.initial }; commit(); render(); });
  const deleteSelected = (event) => { if (event.key !== "Delete" || !root.isConnected || /^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(document.activeElement?.tagName || "")) return; const node = selection.type === "node" ? nodeById(selection.id) : null; if (node) { event.preventDefault(); removeNode(node); } };
  window.addEventListener("resize", drawLines, { passive: true }); document.addEventListener("keydown", deleteSelected);
  render();
  return () => { window.removeEventListener("resize", drawLines); document.removeEventListener("keydown", deleteSelected); };
}
