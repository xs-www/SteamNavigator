// @static-doc
// 作用：连接战斗画布、Mod 蓝图舰体装配、双层工程持久化、配置交换与实时模拟控制。
//
// ## 契约与约束
// - UI 只修改装配配置；开始/重置战斗时才创建独立 BattleSimulation 快照。
// - 工程自动保存到 localStorage，也可手动持久化到 user_data/workspace.json；两者恢复时共用校验。
// - 画布可切换蓝方、红方或全知视角；阵营视角只显示已发现目标及其最后已知位置。
// - 每艘可见舰在舰名上方显示逐挂载武器装填条；隐藏目标不泄露武器冷却状态。
// - 战斗事件覆盖在战场右上角；下方状态面板跟随选中舰，其攻击目标同时在战场上红色高亮。
// - 独立战术工作台维护状态定义与状态机库；本地服务负责 mods/ 导入和游戏约定格式导出。
// @end-static-doc

import { HULLS, SENSORS, BUILTIN_WEAPONS, createSensorCatalog, createWeaponCatalog, normalizeWeapon } from "./catalog.mjs";
import { createShip, createDefaultFleets, cloneFleetConfig, deriveShipStats, validateShip } from "./loadout.mjs";
import { BattleSimulation } from "./simulation.mjs";
import { createCamera, screenWorldBounds, updateCamera, worldToScreen } from "./camera.mjs";
import { rangeShapes } from "./range_overlay.mjs";
import { mountReloadState } from "./combat_hud.mjs";
import { defaultFsm, DEFAULT_FSM_REVISION, normalizeTactic, TACTICAL_STATE_LABELS, FSM_ACTION_DESCRIPTIONS, FSM_STATE_DEFINITIONS } from "./tactics.mjs";
import { mountFsmEditor } from "./fsm_editor.mjs";
import { createDefaultTacticLibrary, migrateTacticalData, resolveShipTactic, uniqueMachineId } from "./tactic_library.mjs";
import { buildSimulatorMod, importSimulatorMods } from "./mod_format.mjs";

const STORAGE_KEY = "sn-battle-sim-v1";
const state = {
  customWeapons: [],
  customSensors: [],
  shipBlueprints: [],
  stateDefinitions: FSM_STATE_DEFINITIONS.map((item) => ({ ...item })),
  fleets: createDefaultFleets(),
  tacticLibrary: createDefaultTacticLibrary(),
  selectedTacticId: "default",
  selectedFaction: 0,
  selectedShipId: "blue_escort",
  battle: null,
  camera: createCamera(),
  viewMode: "0",
  paused: false,
  speed: 1,
  lastTime: 0,
  accumulator: 0,
};

const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value) => String(value).replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[char]));
const weaponKindLabel = (kind) => ({ direct: "直射", artillery: "炮击", broadside: "侧弦" }[kind] || kind);

function catalog() { return createWeaponCatalog(state.customWeapons); }
function sensors() { return createSensorCatalog(state.customSensors); }
function selectedFleet() { return state.fleets[state.selectedFaction]; }
function selectedShip() { return selectedFleet().find((ship) => ship.id === state.selectedShipId) || selectedFleet()[0]; }

function workspaceData() {
  return { version: 4, defaultFsmRevision: DEFAULT_FSM_REVISION, customWeapons: state.customWeapons, customSensors: state.customSensors, shipBlueprints: state.shipBlueprints, stateDefinitions: state.stateDefinitions, fleets: state.fleets, tacticLibrary: state.tacticLibrary };
}

function applyWorkspace(saved) {
  if (!saved || !Array.isArray(saved.fleets) || saved.fleets.length !== 2) throw new Error("工程必须包含两支舰队");
  createWeaponCatalog(saved.customWeapons || []); createSensorCatalog(saved.customSensors || []);
  state.customWeapons = saved.customWeapons || []; state.customSensors = saved.customSensors || [];
  state.shipBlueprints = Array.isArray(saved.shipBlueprints) ? saved.shipBlueprints.map((ship) => ({ ...ship })) : [];
  state.stateDefinitions = Array.isArray(saved.stateDefinitions) && saved.stateDefinitions.length ? saved.stateDefinitions : FSM_STATE_DEFINITIONS.map((item) => ({ ...item }));
  state.fleets = saved.fleets.map((fleet) => fleet.map((ship) => ({ ...ship })));
  state.tacticLibrary = migrateTacticalData(state.fleets, saved.tacticLibrary);
  if (Number(saved.defaultFsmRevision || 0) < DEFAULT_FSM_REVISION) {
    const builtin = state.tacticLibrary.find((entry) => entry.id === "default");
    if (builtin) builtin.tactic = normalizeTactic({ ...builtin.tactic, fsm: defaultFsm() });
  }
  state.selectedFaction = 0; state.selectedShipId = state.fleets[0][0]?.id || ""; state.selectedTacticId = "default"; state.battle = null;
}

function saveLocal() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(workspaceData()));
}

function loadLocal() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    if (!saved) return;
    applyWorkspace(saved);
  } catch (error) {
    console.warn("忽略无效的本地战斗配置", error);
  }
}

async function saveWorkspaceFile() {
  try {
    const response = await fetch("./api/workspace", { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify(workspaceData()) }); const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || "保存失败");
    $("#modStatus").textContent = `工程已保存 · ${payload.file}`;
  } catch (error) { alert(`保存工程失败：${error.message}`); }
}

async function loadWorkspaceFile() {
  try {
    const response = await fetch("./api/workspace"); const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || "读取失败");
    if (!payload.workspace) throw new Error("还没有保存过工程");
    applyWorkspace(payload.workspace); saveLocal(); renderAll();
    if (!$("#tacticsWorkspace").hidden) renderTacticsWorkspace();
    $("#modStatus").textContent = "已读取 user_data/workspace.json";
  } catch (error) { alert(`读取工程失败：${error.message}`); }
}

function shipBuilderTemplates() {
  return [
    { key: "combat", label: "空白战斗舰", ship: createShip({ name: "新战斗舰", role: "combat", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] }) },
    { key: "cargo", label: "空白货船", ship: createShip({ name: "新货船", role: "cargo", hullId: "large", weaponIds: ["repeater"], sensorIds: ["lookout"] }) },
    ...state.shipBlueprints.map((ship, index) => ({ key: `mod:${index}`, label: `${ship.name} · ${ship.sourceMod || "Mod"}`, ship })),
  ];
}

function shipDraftFromBuilder() {
  const form = $("#shipBuilderForm"); const data = new FormData(form); const hullId = data.get("hullId") || "medium";
  return createShip({
    id: `ship_${state.selectedFaction}_${Date.now().toString(36)}_${selectedFleet().length}`,
    name: String(data.get("name") || "新舰").trim() || "新舰", role: data.get("role"), hullId,
    weaponIds: data.getAll("weaponIds"), sensorIds: data.getAll("sensorIds"), tacticId: data.get("tacticId") || "default",
    tuning: { armor: 0, engine: 0, maneuver: 0, cargo: data.get("role") === "cargo" ? 35 : 0 },
  });
}

function updateShipBuilderValidation() {
  const draft = shipDraftFromBuilder(); const errors = validateShip(draft, catalog(), sensors()); const host = $("#shipBuilderValidation");
  host.textContent = errors.length ? errors.join("；") : `${HULLS[draft.hullId].name} · ${draft.weaponIds.length}/${HULLS[draft.hullId].weaponSlots} 武器 · ${draft.sensorIds.length}/${HULLS[draft.hullId].sensorSlots} 视野`;
  host.classList.toggle("bad", errors.length > 0); $("#shipBuilderForm button[type=submit]").disabled = errors.length > 0;
}

function renderShipBuilder(templateKey = "combat") {
  const templates = shipBuilderTemplates(); const template = templates.find((entry) => entry.key === templateKey) || templates[0]; const ship = createShip(template.ship);
  const weaponCatalog = catalog(); const sensorCatalog = sensors();
  $("#shipBuilderContent").innerHTML = `<div class="builder-source"><label>装配起点<select id="shipBlueprint" name="blueprint">${templates.map((entry) => `<option value="${escapeHtml(entry.key)}" ${entry.key === template.key ? "selected" : ""}>${escapeHtml(entry.label)}</option>`).join("")}</select></label><span>当前加入${state.selectedFaction ? "红方" : "蓝方"}舰队</span></div>
    <div class="builder-identity"><label>舰名<input name="name" value="${escapeHtml(ship.name)}" maxlength="40"></label><label>用途<select name="role"><option value="combat" ${ship.role === "combat" ? "selected" : ""}>战斗舰</option><option value="cargo" ${ship.role === "cargo" ? "selected" : ""}>货船</option></select></label><label>状态机<select name="tacticId">${state.tacticLibrary.map((entry) => `<option value="${escapeHtml(entry.id)}" ${entry.id === ship.tacticId ? "selected" : ""}>${escapeHtml(entry.name)}</option>`).join("")}</select></label></div>
    <section><h3>舰体</h3><div class="hull-choice-grid">${Object.values(HULLS).map((hull) => `<label class="hull-choice"><input type="radio" name="hullId" value="${hull.id}" ${hull.id === ship.hullId ? "checked" : ""}><b>${hull.name}</b><span>${hull.weaponSlots} 武器槽 · ${hull.sensorSlots} 视野槽</span><small>${hull.hull} 耐久 · ${hull.speed} 航速 · ${hull.massLimit} 质量上限</small></label>`).join("")}</div></section>
    <div class="builder-components"><section><h3>武器组件</h3><div class="component-choice-grid">${Object.values(weaponCatalog).map((weapon) => `<label><input type="checkbox" name="weaponIds" value="${weapon.id}" ${ship.weaponIds.includes(weapon.id) ? "checked" : ""}><span><b>${escapeHtml(weapon.name)}</b><small>${weaponKindLabel(weapon.kind)} · ${weapon.range}m · ${weapon.mass}质量${weapon.sourceMod ? ` · ${escapeHtml(weapon.sourceMod)}` : ""}</small></span></label>`).join("")}</div></section><section><h3>视野组件</h3><div class="component-choice-grid">${Object.values(sensorCatalog).map((sensor) => `<label><input type="checkbox" name="sensorIds" value="${sensor.id}" ${ship.sensorIds.includes(sensor.id) ? "checked" : ""}><span><b>${escapeHtml(sensor.name)}</b><small>视野 +${sensor.rangeBonus} · ${sensor.mass}质量${sensor.sourceMod ? ` · ${escapeHtml(sensor.sourceMod)}` : ""}</small></span></label>`).join("")}</div></section></div>`;
  $("#shipBlueprint").addEventListener("change", (event) => renderShipBuilder(event.target.value));
  $("#shipBuilderContent").querySelectorAll("input,select").forEach((input) => input.addEventListener("change", updateShipBuilderValidation)); updateShipBuilderValidation();
}

function openShipBuilder() { renderShipBuilder(); $("#shipBuilderDialog").showModal(); }

function optionRows(values, selectedIds) {
  return Object.values(values).map((value) => `<option value="${value.id}" ${selectedIds.includes(value.id) ? "selected" : ""}>${escapeHtml(value.name)}</option>`).join("");
}

function renderFleetTabs() {
  $("#fleetTabs").innerHTML = [0, 1].map((faction) => `<button class="fleet-tab ${state.selectedFaction === faction ? "active" : ""}" data-faction="${faction}">${faction === 0 ? "蓝方舰队" : "红方舰队"}</button>`).join("");
  $("#fleetTabs").querySelectorAll("button").forEach((button) => button.addEventListener("click", () => {
    state.selectedFaction = Number(button.dataset.faction);
    state.selectedShipId = selectedFleet()[0]?.id || "";
    renderAll();
  }));
}

function renderFleetList() {
  const weaponCatalog = catalog();
  const sensorCatalog = sensors();
  $("#fleetList").innerHTML = selectedFleet().map((ship) => {
    const errors = validateShip(ship, weaponCatalog, sensorCatalog);
    const stats = deriveShipStats(ship, weaponCatalog, sensorCatalog);
    return `<button class="ship-card ${ship.id === state.selectedShipId ? "active" : ""}" data-id="${ship.id}">
      <span><b>${escapeHtml(ship.name)}</b><small>${HULLS[ship.hullId].name} · ${ship.role === "cargo" ? "货船" : "战斗舰"}</small></span>
      <span class="ship-card-meta ${errors.length ? "bad" : ""}">${errors.length ? `${errors.length} 项错误` : `${stats.weapons.length} 武器 · ${stats.vision.toFixed(0)} 视野`}</span>
    </button>`;
  }).join("") || `<div class="empty">舰队为空</div>`;
  $("#fleetList").querySelectorAll(".ship-card").forEach((button) => button.addEventListener("click", () => {
    state.selectedShipId = button.dataset.id;
    renderEditor(); renderFleetList();
  }));
}

function renderEditor() {
  const host = $("#shipEditor");
  const ship = selectedShip();
  if (!ship) { host.innerHTML = `<div class="empty">添加一艘船开始装配</div>`; return; }
  const weaponCatalog = catalog();
  const sensorCatalog = sensors();
  const stats = deriveShipStats(ship, weaponCatalog, sensorCatalog);
  const errors = validateShip(ship, weaponCatalog, sensorCatalog);
  const availableSlots = HULLS[ship.hullId].weaponSlots - ship.weaponIds.length;
  if (!state.tacticLibrary.some((entry) => entry.id === ship.tacticId)) ship.tacticId = "default";

  host.innerHTML = `
    <div class="form-grid two">
      <label>舰名<input id="shipName" value="${escapeHtml(ship.name)}"></label>
      <label>用途<select id="shipRole"><option value="combat" ${ship.role === "combat" ? "selected" : ""}>战斗舰</option><option value="cargo" ${ship.role === "cargo" ? "selected" : ""}>货船</option></select></label>
      <label>固定船体<select id="hullId">${optionRows(HULLS, [ship.hullId])}</select></label>
    </div>
    <div class="subhead"><span>战术状态机</span><span>单一挂载</span></div>
    <div class="machine-mount"><select id="shipTactic">${state.tacticLibrary.map((entry) => `<option value="${entry.id}" ${entry.id === ship.tacticId ? "selected" : ""}>${escapeHtml(entry.name)}</option>`).join("")}</select><button id="editShipTactic">打开战术工作台</button></div>
    <label class="commander-toggle"><input id="shipCommander" type="checkbox" ${ship.isCommander ? "checked" : ""}>设为本舰队指挥官（每方至多一艘）</label>
    <div class="subhead"><span>视野组件</span><span>${ship.sensorIds.length}/${HULLS[ship.hullId].sensorSlots}</span></div>
    <div class="mount-list">${ship.sensorIds.map((id, index) => {
      const sensor = sensorCatalog[id];
      return `<div class="mount sensor"><span>${escapeHtml(sensor?.name || id)}<small>${sensor ? `视野 +${sensor.rangeBonus} · 命中 +${Math.round(sensor.accuracyBonus * 100)}%` : "未知组件"}</small></span><button data-remove-sensor="${index}" title="卸下">×</button></div>`;
    }).join("") || `<div class="empty compact">没有视野组件</div>`}</div>
    <div class="inline-add"><select id="sensorToAdd">${optionRows(sensorCatalog, [])}</select><button id="addSensor" ${ship.sensorIds.length >= HULLS[ship.hullId].sensorSlots ? "disabled" : ""}>安装</button></div>
    <div class="subhead"><span>武器挂载</span><span>${ship.weaponIds.length}/${HULLS[ship.hullId].weaponSlots}</span></div>
    <div class="mount-list">${ship.weaponIds.map((id, index) => {
      const weapon = weaponCatalog[id];
      return `<div class="mount"><span>${escapeHtml(weapon?.name || id)}<small>${weapon ? `${weaponKindLabel(weapon.kind)} · ${weapon.range}m · ${weapon.damage}×${weapon.salvo || 1}伤害` : "未知组件"}</small></span><button data-remove-mount="${index}" title="卸下">×</button></div>`;
    }).join("") || `<div class="empty compact">没有武器</div>`}</div>
    <div class="inline-add"><select id="weaponToAdd">${optionRows(weaponCatalog, [])}</select><button id="addMount" ${availableSlots <= 0 ? "disabled" : ""}>安装</button></div>
    <div class="subhead"><span>其他组件折算</span><span>直接进入船舶数值</span></div>
    <div class="slider-grid">
      ${slider("armor", "装甲强化", ship.tuning.armor, -10, 30)}
      ${slider("engine", "引擎强化", ship.tuning.engine, -15, 30)}
      ${slider("maneuver", "操舵强化", ship.tuning.maneuver, -15, 30)}
      ${slider("cargo", "货舱扩容", ship.tuning.cargo, 0, 100)}
    </div>
    <label class="cargo-value">货物价值<input id="cargoValue" type="number" min="0" max="999999" value="${ship.cargoValue}"></label>
    <div class="subhead"><span>整舰数值</span><span>最终战斗属性</span></div>
    <div class="stats-grid ship-sheet">${shipSheet(stats, ship)}</div>
    <div id="shipValidation" class="validation ${errors.length ? "invalid" : "valid"}">${errors.length ? errors.map(escapeHtml).join("<br>") : "装配有效，可以投入模拟"}</div>
    <button id="removeShip" class="danger">从舰队移除</button>`;

  host.querySelector("#shipName").addEventListener("change", (event) => { ship.name = event.target.value; saveAndRender(); });
  host.querySelector("#shipRole").addEventListener("change", (event) => { ship.role = event.target.value; saveAndRender(); });
  host.querySelector("#shipTactic").addEventListener("change", (event) => { ship.tacticId = event.target.value; saveLocal(); });
  host.querySelector("#editShipTactic").addEventListener("click", () => { state.selectedTacticId = ship.tacticId; openTacticsWorkspace(); });
  host.querySelector("#shipCommander").addEventListener("change", (event) => { if(event.target.checked) selectedFleet().forEach((item)=>{item.isCommander=item.id===ship.id;}); else ship.isCommander=false; saveAndRender(); });
  host.querySelector("#hullId").addEventListener("change", (event) => {
    ship.hullId = event.target.value;
    ship.weaponIds = ship.weaponIds.slice(0, HULLS[ship.hullId].weaponSlots);
    ship.sensorIds = ship.sensorIds.slice(0, HULLS[ship.hullId].sensorSlots);
    saveAndRender();
  });
  host.querySelector("#addSensor").addEventListener("click", () => { ship.sensorIds.push(host.querySelector("#sensorToAdd").value); saveAndRender(); });
  host.querySelectorAll("[data-remove-sensor]").forEach((button) => button.addEventListener("click", () => { ship.sensorIds.splice(Number(button.dataset.removeSensor), 1); saveAndRender(); }));
  host.querySelector("#addMount").addEventListener("click", () => { ship.weaponIds.push(host.querySelector("#weaponToAdd").value); saveAndRender(); });
  host.querySelectorAll("[data-remove-mount]").forEach((button) => button.addEventListener("click", () => { ship.weaponIds.splice(Number(button.dataset.removeMount), 1); saveAndRender(); }));
  host.querySelectorAll("[data-tuning]").forEach((input) => {
    input.addEventListener("input", () => {
      ship.tuning[input.dataset.tuning] = Number(input.value);
      input.closest("label").querySelector("output").textContent = `${input.value >= 0 ? "+" : ""}${input.value}`;
      refreshShipSheet(host, ship, weaponCatalog, sensorCatalog);
    });
    input.addEventListener("change", () => { saveLocal(); renderFleetList(); });
  });
  host.querySelector("#cargoValue").addEventListener("input", (event) => { ship.cargoValue = Number(event.target.value); saveLocal(); refreshShipSheet(host, ship, weaponCatalog, sensorCatalog); });
  host.querySelector("#removeShip").addEventListener("click", () => {
    const index = selectedFleet().findIndex((item) => item.id === ship.id);
    selectedFleet().splice(index, 1);
    state.selectedShipId = selectedFleet()[0]?.id || "";
    saveAndRender();
  });
}

function slider(key, label, value, min, max) {
  return `<label><span>${label}<output>${value >= 0 ? "+" : ""}${value}</output></span><input data-tuning="${key}" type="range" min="${min}" max="${max}" value="${value}"></label>`;
}
function tacticSlider(key, label, value, min, max) {
  const percent = Math.round(value * 100);
  return `<label><span>${label}<output>${percent}%</output></span><input data-tactic-range="${key}" type="range" min="${min}" max="${max}" value="${percent}"></label>`;
}
function stat(key, label, value) { return `<div><small>${label}</small><b data-stat="${key}">${value}</b></div>`; }

function shipSheet(stats, ship) {
  const salvoDamage = stats.weapons.reduce((sum, weapon) => sum + weapon.damage * (weapon.salvo || 1), 0);
  const sustainedDps = stats.weapons.reduce((sum, weapon) => sum + weapon.damage * (weapon.salvo || 1) / weapon.cooldown, 0);
  const maxRange = Math.max(0, ...stats.weapons.map((weapon) => weapon.range));
  return [
    stat("hull", "耐久", stats.hullMax.toFixed(0)), stat("armor", "装甲", stats.armor.toFixed(0)),
    stat("mass", "重量", `${stats.mass.toFixed(1)}/${stats.massLimit}`), stat("speed", "最高航速", stats.speed.toFixed(1)),
    stat("acceleration", "加速度", stats.acceleration.toFixed(1)), stat("turn", "最大转向", `${(stats.turnRate * 180 / Math.PI).toFixed(1)}°/s`),
    stat("rudder", "舵响应", stats.rudderResponse.toFixed(2)), stat("vision", "视野", stats.vision.toFixed(0)),
    stat("visionTime", "视野航程", `${(stats.vision / Math.max(0.1, stats.speed)).toFixed(1)} 秒`),
    stat("accuracy", "命中加成", `+${Math.round(stats.accuracyBonus * 100)}%`), stat("signature", "目标特征", stats.signature.toFixed(2)),
    stat("weapons", "武器挂载", stats.weapons.length), stat("range", "最大射程", maxRange.toFixed(0)),
    stat("salvo", "齐射伤害", salvoDamage.toFixed(0)), stat("dps", "理论 DPS", sustainedDps.toFixed(1)),
    stat("cargo", "货舱容量", stats.cargoCapacity.toFixed(0)), stat("cargoValue", "携货价值", Number(ship.cargoValue || 0).toFixed(0)),
  ].join("");
}

function refreshShipSheet(host, ship, weaponCatalog, sensorCatalog = sensors()) {
  const stats = deriveShipStats(ship, weaponCatalog, sensorCatalog);
  const scratch = document.createElement("div");
  scratch.innerHTML = shipSheet(stats, ship);
  scratch.querySelectorAll("[data-stat]").forEach((next) => {
    const current = host.querySelector(`[data-stat="${next.dataset.stat}"]`);
    if (current) current.textContent = next.textContent;
  });
  const errors = validateShip(ship, weaponCatalog, sensorCatalog);
  const validation = host.querySelector("#shipValidation");
  validation.className = `validation ${errors.length ? "invalid" : "valid"}`;
  validation.innerHTML = errors.length ? errors.map(escapeHtml).join("<br>") : "装配有效，可以投入模拟";
}

function saveAndRender() { saveLocal(); renderFleetList(); renderEditor(); renderBattleStatus(); }

function renderWeapons() {
  const all = catalog();
  const sensorCatalog = sensors();
  $("#weaponCatalog").innerHTML = Object.values(all).map((weapon) => `<div class="weapon-row"><span><b>${escapeHtml(weapon.name)}</b><small>${weaponKindLabel(weapon.kind)} · ${weapon.salvo || 1} 发齐射 · 伤害 ${weapon.damage} · 射程 ${weapon.range} · 射界 ${weapon.arc}° · ${weapon.mass}t</small></span>${BUILTIN_WEAPONS[weapon.id] ? "<em>内置</em>" : `<button data-delete-weapon="${weapon.id}">删除</button>`}</div>`).join("");
  $("#sensorCatalog").innerHTML = Object.values(sensorCatalog).map((sensor) => `<div class="weapon-row"><span><b>${escapeHtml(sensor.name)}</b><small>视野 +${sensor.rangeBonus} · 命中 +${Math.round(sensor.accuracyBonus * 100)}% · ${sensor.mass}t</small></span><em>${SENSORS[sensor.id] ? "内置" : escapeHtml(sensor.sourceMod || "自定义")}</em></div>`).join("");
  $("#weaponCatalog").querySelectorAll("[data-delete-weapon]").forEach((button) => button.addEventListener("click", () => {
    const id = button.dataset.deleteWeapon;
    if (state.fleets.some((fleet) => fleet.some((ship) => ship.weaponIds.includes(id)))) {
      alert("该武器仍被舰船使用，请先卸下。"); return;
    }
    state.customWeapons = state.customWeapons.filter((weapon) => weapon.id !== id);
    saveLocal(); renderAll();
  }));
}

function renderBattleStatus() {
  const battle = state.battle;
  const errors = state.fleets.flatMap((fleet) => fleet.flatMap((ship) => validateShip(ship, catalog(), sensors()).map((error) => `${ship.name}：${error}`)));
  $("#startBattle").disabled = errors.length > 0 || state.fleets.some((fleet) => !fleet.length);
  if (!battle) {
    $("#battleStatus").innerHTML = errors.length ? `<span class="bad">${errors.length} 项装配问题</span>` : "等待开始";
    $("#eventLog").innerHTML = `<div class="empty compact">尚无事件</div>`;
    $("#shipRuntimeStatus").innerHTML = `<div class="empty compact">开始战斗后显示所选舰实时状态</div>`;
    return;
  }
  const summary = battle.summary();
  const outcome = battle.state === "finalized" ? (battle.winner === null ? "平局" : `${battle.winner === 0 ? "蓝方" : "红方"}获胜`) : "交战中";
  $("#battleStatus").innerHTML = `<b>${outcome}</b><span>${battle.time.toFixed(1)} 秒</span><span>蓝 ${summary[0].afloat} / 红 ${summary[1].afloat}</span><span>保全货值 ${summary[0].cargoSaved} : ${summary[1].cargoSaved}</span>`;
  const eventRows = battle.events.slice(-18).reverse().map(eventLabel).filter(Boolean).slice(0, 8);
  $("#eventLog").innerHTML = eventRows.join("") || `<div class="empty compact">等待交火</div>`;
  renderRuntimeShipStatus(battle);
}

function renderRuntimeShipStatus(battle) {
  const host = $("#shipRuntimeStatus");
  const ship = battle.ships.find((item) => item.config.id === state.selectedShipId && item.faction === state.selectedFaction);
  if (!ship) { host.innerHTML = `<div class="empty compact">所选舰不在本次战斗中</div>`; return; }
  const target = battle.ships.find((item) => item.uid === ship.targetUid);
  const targetDistance = target ? Math.hypot(target.x - ship.x, target.y - ship.y) : null;
  const stateLabel = ship.escaped ? "已撤离" : ship.disabled ? "失能" : ship.tacticalNodeName || TACTICAL_STATE_LABELS[ship.tacticalState] || "巡航";
  const weaponRows = ship.mounts.map((mount) => {
    const reload = mountReloadState(mount);
    return `<span style="--weapon:${mount.weapon.color}"><b>${escapeHtml(mount.weapon.name)}</b><em>${reload.label}</em></span>`;
  }).join("");
  host.innerHTML = `<div class="runtime-summary">
    <div><small>舰船</small><b>${escapeHtml(ship.config.name)}</b></div>
    <div><small>状态</small><b>${stateLabel}</b></div>
    <div><small>耐久</small><b>${ship.hull.toFixed(0)} / ${ship.stats.hullMax.toFixed(0)}</b></div>
    <div><small>航速</small><b>${ship.speedCurrent.toFixed(1)} / ${ship.stats.speed.toFixed(1)}</b></div>
    <div class="${target ? "runtime-target" : ""}"><small>攻击目标</small><b>${target ? escapeHtml(target.config.name) : "无"}</b></div>
    <div><small>目标距离</small><b>${targetDistance === null ? "—" : targetDistance.toFixed(0)}</b></div>
    <div><small>命中</small><b>${ship.hits} / ${ship.shots}</b></div>
    <div><small>累计伤害</small><b>${ship.damage.toFixed(0)}</b></div>
  </div><div class="runtime-reason"><b>状态原因</b><span>${escapeHtml(ship.tacticalReason || "—")}</span></div><div class="runtime-weapons">${weaponRows || "<i>无武器</i>"}</div>`;
}

function eventLabel(event) {
  const time = `<time>${event.time.toFixed(1)}s</time>`;
  if (event.type === "hit") return `<div>${time}${escapeHtml(event.attacker.config.name)} 的${escapeHtml(event.weapon.name)}命中，造成 ${event.damage.toFixed(0)}</div>`;
  if (event.type === "disabled") return `<div class="bad">${time}${escapeHtml(event.ship.config.name)}失去战斗能力</div>`;
  if (event.type === "escaped") return `<div class="good">${time}${escapeHtml(event.ship.config.name)}携货脱离</div>`;
  if (event.type === "finalized") return `<div>${time}战斗结束</div>`;
  return "";
}

function startBattle() {
  try {
    const fleets = cloneFleetConfig(state.fleets);
    for (const fleet of fleets) for (const ship of fleet) ship.tactic = resolveShipTactic(ship, state.tacticLibrary);
    state.battle = new BattleSimulation({ fleets, weaponCatalog: catalog(), sensorCatalog: sensors(), seed: Number($("#seed").value) || 5201 });
    state.camera = createCamera();
    state.paused = false;
    $("#pauseBattle").textContent = "暂停";
    renderBattleStatus();
  } catch (error) { alert(error.message); }
}

function draw() {
  const canvas = $("#battlefield");
  const context = canvas.getContext("2d");
  const battle = state.battle;
  context.clearRect(0, 0, canvas.width, canvas.height);
  const gradient = context.createLinearGradient(0, 0, 0, canvas.height);
  gradient.addColorStop(0, "#12313c"); gradient.addColorStop(1, "#071a24");
  context.fillStyle = gradient; context.fillRect(0, 0, canvas.width, canvas.height);
  if (!battle) {
    context.fillStyle = "rgba(230,240,235,.6)"; context.font = "16px sans-serif"; context.textAlign = "center";
    context.fillText("完成舰队装配后开始模拟", canvas.width / 2, canvas.height / 2); return;
  }

  const camera = updateCamera(state.camera, battle.ships, canvas.width, canvas.height);
  drawWorldGrid(context, camera, canvas.width, canvas.height);

  const selectedRuntimeShip = battle.ships.find((ship) => ship.config.id === state.selectedShipId && ship.faction === state.selectedFaction && !ship.escaped);
  if (selectedRuntimeShip && shipObservation(battle, selectedRuntimeShip)?.visible) drawRangeRings(context, camera, canvas, selectedRuntimeShip);
  for (const projectile of battle.projectiles) {
    if (state.viewMode !== "both") {
      const viewer = Number(state.viewMode);
      if (projectile.faction !== viewer && !battle.contactFor(viewer, projectile.source.uid)?.visible) continue;
    }
    const point = worldToScreen(camera, projectile, canvas.width, canvas.height);
    context.beginPath(); context.arc(point.x, point.y, projectile.weapon.kind === "artillery" ? 4.5 : 2.5, 0, TAU);
    context.fillStyle = projectile.weapon.color; context.fill();
    if (projectile.weapon.kind === "artillery") { context.strokeStyle = "rgba(243,200,255,.65)"; context.stroke(); }
  }
  for (const ship of battle.ships) {
    if (ship.escaped) continue;
    const observation = shipObservation(battle, ship);
    if (!observation) continue;
    if (!observation.visible) { drawGhost(context, camera, canvas, observation, ship); continue; }
    drawShip(context, camera, canvas, ship);
  }
  if (selectedRuntimeShip?.targetUid) drawTargetHighlight(context, camera, canvas, battle, selectedRuntimeShip);
}

const TAU = Math.PI * 2;
function shipObservation(battle, ship) {
  if (state.viewMode === "both") return { visible: true, x: ship.x, y: ship.y };
  const viewer = Number(state.viewMode);
  if (ship.faction === viewer) return { visible: true, x: ship.x, y: ship.y };
  return battle.contactFor(viewer, ship.uid);
}

const RANGE_COLORS = ["#ffd37a", "#ff9a63", "#f3c8ff", "#94e08a", "#ff98bd", "#72bfff"];

function drawRangeRings(context, camera, canvas, ship) {
  const point = worldToScreen(camera, ship, canvas.width, canvas.height);
  context.save();
  for (const shape of rangeShapes(ship)) {
    if (shape.role === "vision") {
      context.lineWidth = 1.6; context.setLineDash([7, 5]); context.strokeStyle = "rgba(90,222,225,.72)";
      context.beginPath(); context.arc(point.x, point.y, shape.radius * camera.zoom, 0, TAU); context.stroke();
      drawRangeLabel(context, point, shape.radius * camera.zoom, -Math.PI / 2, shape.label, "#7ceef0");
      continue;
    }
    const color = RANGE_COLORS[shape.mountIndex % RANGE_COLORS.length];
    context.lineWidth = 1.7; context.setLineDash(shape.mountIndex % 2 ? [8, 4] : [3, 4]);
    context.strokeStyle = color; context.fillStyle = `${color}18`;
    if (shape.type === "circle") drawAnnularCircle(context, point, shape.radius * camera.zoom, shape.minRadius * camera.zoom);
    else drawAnnularSector(context, point, shape.radius * camera.zoom, shape.minRadius * camera.zoom, shape.startAngle, shape.endAngle);
    if (shape.label) {
      const angle = shape.type === "circle" ? -Math.PI / 2 + 0.18 * (shape.mountIndex + 1) : (shape.startAngle + shape.endAngle) / 2;
      drawRangeLabel(context, point, shape.radius * camera.zoom, angle, shape.label, color);
    }
  }
  context.setLineDash([]); context.lineWidth = 2.2; context.strokeStyle = "rgba(255,255,255,.9)";
  context.beginPath(); context.arc(point.x, point.y, Math.max(8, ship.stats.radius * camera.zoom + 5), 0, TAU); context.stroke();
  context.restore();
}

function drawAnnularCircle(context, point, outerRadius, innerRadius) {
  context.beginPath(); context.arc(point.x, point.y, outerRadius, 0, TAU);
  if (innerRadius > 0) context.arc(point.x, point.y, innerRadius, 0, TAU, true);
  context.fill("evenodd"); context.stroke();
  if (innerRadius > 0) {
    context.save(); context.globalAlpha = 0.65; context.beginPath(); context.arc(point.x, point.y, innerRadius, 0, TAU); context.stroke(); context.restore();
  }
}

function drawAnnularSector(context, point, outerRadius, innerRadius, startAngle, endAngle) {
  context.beginPath();
  context.arc(point.x, point.y, outerRadius, startAngle, endAngle);
  if (innerRadius > 0) {
    context.lineTo(point.x + Math.cos(endAngle) * innerRadius, point.y + Math.sin(endAngle) * innerRadius);
    context.arc(point.x, point.y, innerRadius, endAngle, startAngle, true);
  } else context.lineTo(point.x, point.y);
  context.closePath(); context.fill(); context.stroke();
}

function drawRangeLabel(context, point, radius, angle, label, color) {
  const x = point.x + Math.cos(angle) * Math.max(24, radius - 8);
  const y = point.y + Math.sin(angle) * Math.max(24, radius - 8);
  context.save(); context.setLineDash([]); context.font = "10px sans-serif"; context.textAlign = "center";
  const width = context.measureText(label).width + 8;
  context.fillStyle = "rgba(5,20,28,.78)"; context.fillRect(x - width / 2, y - 8, width, 14);
  context.fillStyle = color; context.fillText(label, x, y + 3); context.restore();
}

function drawWorldGrid(context, camera, width, height) {
  const bounds = screenWorldBounds(camera, width, height);
  const worldStep = camera.zoom < 0.45 ? 200 : camera.zoom < 0.85 ? 100 : 50;
  context.strokeStyle = "rgba(142,210,220,.08)"; context.lineWidth = 1;
  for (let x = Math.floor(bounds.minX / worldStep) * worldStep; x <= bounds.maxX; x += worldStep) {
    const screen = worldToScreen(camera, { x, y: 0 }, width, height);
    context.beginPath(); context.moveTo(screen.x, 0); context.lineTo(screen.x, height); context.stroke();
  }
  for (let y = Math.floor(bounds.minY / worldStep) * worldStep; y <= bounds.maxY; y += worldStep) {
    const screen = worldToScreen(camera, { x: 0, y }, width, height);
    context.beginPath(); context.moveTo(0, screen.y); context.lineTo(width, screen.y); context.stroke();
  }
}

function drawGhost(context, camera, canvas, contact, ship) {
  const point = worldToScreen(camera, contact, canvas.width, canvas.height);
  const radius = Math.max(5, (ship.stats.radius + 4) * camera.zoom);
  context.save(); context.globalAlpha = 0.25; context.setLineDash([5, 5]);
  context.beginPath(); context.arc(point.x, point.y, radius, 0, TAU);
  context.strokeStyle = ship.faction === 0 ? "#52b9ff" : "#ff8b7d"; context.stroke(); context.restore();
}

function drawTargetHighlight(context, camera, canvas, battle, selectedShip) {
  const target = battle.ships.find((ship) => ship.uid === selectedShip.targetUid && !ship.escaped);
  if (!target) return;
  const targetObservation = shipObservation(battle, target); const sourceObservation = shipObservation(battle, selectedShip);
  if (!targetObservation || !sourceObservation) return;
  const source = worldToScreen(camera, sourceObservation, canvas.width, canvas.height); const point = worldToScreen(camera, targetObservation, canvas.width, canvas.height);
  const radius = Math.max(12, target.stats.radius * camera.zoom + 10); const pulse = 3 + Math.sin(battle.time * 6) * 2;
  context.save(); context.strokeStyle = "#ff3d35"; context.fillStyle = "#ff5b4f"; context.lineWidth = 2.5; context.setLineDash(targetObservation.visible ? [] : [6, 4]);
  context.globalAlpha = 0.62; context.beginPath(); context.moveTo(source.x, source.y); context.lineTo(point.x, point.y); context.stroke();
  context.globalAlpha = 1; context.beginPath(); context.arc(point.x, point.y, radius + pulse, 0, TAU); context.stroke();
  context.font = "700 10px sans-serif"; context.textAlign = "center"; context.fillText("攻击目标", point.x, point.y - radius - 9); context.restore();
}

function drawShip(context, camera, canvas, ship) {
  const point = worldToScreen(camera, ship, canvas.width, canvas.height);
  context.save(); context.translate(point.x, point.y); context.rotate(ship.heading);
  context.globalAlpha = ship.disabled ? 0.28 : 1;
  context.fillStyle = ship.faction === 0 ? "#52b9ff" : "#ff725f";
  context.strokeStyle = ship.config.role === "cargo" ? "#f5d26f" : "#dbe9e6";
  context.lineWidth = ship.config.role === "cargo" ? 3 : 1.5;
  const r = Math.max(5, ship.stats.radius * camera.zoom);
  context.beginPath(); context.moveTo(r * 1.3, 0); context.lineTo(-r, -r * 0.72); context.lineTo(-r * 0.7, r * 0.72); context.closePath(); context.fill(); context.stroke();
  context.restore();
  context.fillStyle = "rgba(0,0,0,.65)"; context.fillRect(point.x - 20, point.y + r + 6, 40, 4);
  context.fillStyle = ship.faction === 0 ? "#5bd5ff" : "#ff8677";
  context.fillRect(point.x - 20, point.y + r + 6, 40 * Math.max(0, ship.hull / ship.stats.hullMax), 4);
  context.fillStyle = "#e9f0eb"; context.font = "11px sans-serif"; context.textAlign = "center";
  context.fillText(`${ship.config.name} · ${ship.tacticalNodeName || TACTICAL_STATE_LABELS[ship.tacticalState] || "巡航"}`, point.x, point.y - r - 8);
  drawWeaponStatusBar(context, point, r, ship.mounts);
}

function drawWeaponStatusBar(context, point, shipRadius, mounts) {
  if (!mounts.length) return;
  const cellWidth = 34; const cellHeight = 16; const gap = 3;
  const totalWidth = mounts.length * cellWidth + (mounts.length - 1) * gap;
  const startX = point.x - totalWidth / 2; const y = point.y - shipRadius - 34;
  context.save(); context.font = "9px sans-serif"; context.textAlign = "center"; context.textBaseline = "middle";
  mounts.forEach((mount, index) => {
    const status = mountReloadState(mount);
    const x = startX + index * (cellWidth + gap);
    context.fillStyle = "rgba(4,16,23,.86)"; context.fillRect(x, y, cellWidth, cellHeight);
    context.fillStyle = `${mount.weapon.color}55`; context.fillRect(x + 1, y + cellHeight - 4, (cellWidth - 2) * status.progress, 3);
    context.strokeStyle = status.ready ? mount.weapon.color : "rgba(206,225,224,.38)";
    context.lineWidth = status.ready ? 1.5 : 1; context.strokeRect(x + 0.5, y + 0.5, cellWidth - 1, cellHeight - 1);
    context.fillStyle = status.ready ? mount.weapon.color : "rgba(235,241,236,.88)";
    const weaponMark = Array.from(mount.weapon.name || "?")[0];
    context.fillText(`${weaponMark} ${status.label}`, x + cellWidth / 2, y + 7);
  });
  context.restore();
}

function selectedMachine() {
  return state.tacticLibrary.find((entry) => entry.id === state.selectedTacticId) || state.tacticLibrary[0];
}

function openTacticsWorkspace() {
  $("#tacticsWorkspace").hidden = false;
  document.body.classList.add("tactics-open");
  renderTacticsWorkspace();
}

function closeTacticsWorkspace() {
  $("#tacticsWorkspace").hidden = true;
  document.body.classList.remove("tactics-open");
  $("#tacticsFsmEditor")._fsmCleanup?.();
}

function renderTacticsWorkspace() {
  const machine = selectedMachine();
  state.selectedTacticId = machine.id;
  $("#tacticLibraryList").innerHTML = state.tacticLibrary.map((entry) => `<button class="tactic-library-item ${entry.id === machine.id ? "active" : ""}" data-machine-id="${entry.id}"><b>${escapeHtml(entry.name)}</b><small>${entry.tactic.fsm.nodes.length} 状态 · ${entry.tactic.fsm.transitions.length} 转移${entry.builtin ? " · 默认" : ""}</small></button>`).join("");
  $("#tacticLibraryList").querySelectorAll("[data-machine-id]").forEach((button) => button.addEventListener("click", () => { state.selectedTacticId = button.dataset.machineId; renderTacticsWorkspace(); }));
  $("#actionReference").innerHTML = state.stateDefinitions.map((definition) => `<div class="action-definition" draggable="true" data-state-definition="${escapeHtml(definition.id)}"><b>${escapeHtml(definition.name || TACTICAL_STATE_LABELS[definition.runtimeAction])}</b><small>${escapeHtml(definition.description || FSM_ACTION_DESCRIPTIONS[definition.runtimeAction] || "")}</small><em>${escapeHtml(definition.runtimeAction)}${definition.sourceMod ? ` · ${escapeHtml(definition.sourceMod)}` : ""}</em></div>`).join("");
  $("#actionReference").querySelectorAll("[data-state-definition]").forEach((element) => element.addEventListener("dragstart", (event) => { const definition = state.stateDefinitions.find((item) => item.id === element.dataset.stateDefinition); event.dataTransfer.setData("application/x-snbattle-fsm-action", JSON.stringify({ action: definition.runtimeAction, name: definition.name })); event.dataTransfer.effectAllowed = "copy"; }));
  $("#tacticName").value = machine.name;
  $("#machineBadge").textContent = machine.builtin ? "内置默认 · 可编辑 · 不可删除" : "自定义状态机";
  $("#deleteTactic").disabled = machine.builtin;

  const editor = $("#tacticsFsmEditor");
  editor._fsmCleanup?.();
  editor._fsmCleanup = mountFsmEditor(editor, machine.tactic.fsm, (fsm) => { machine.tactic.fsm = fsm; saveLocal(); });
  const tactic = machine.tactic = normalizeTactic(machine.tactic);
  $("#tacticParameters").innerHTML = `<div class="form-grid two tactic-controls">
    <label>目标优先<select data-machine-field="targetPriority"><option value="nearest">最近目标</option><option value="cargo">货船优先</option><option value="weakest">残血优先</option></select></label>
    <label>最后位置<select data-machine-field="chaseLastKnown"><option value="true">继续追踪</option><option value="false">立即放弃</option></select></label>
    <label>巡航动作<select data-machine-field="searchAction"><option value="advance">沿默认方向</option><option value="hold">原地待命</option></select></label>
    <label>机动舷侧<select data-machine-field="strafeSide"><option value="auto">阵营自动</option><option value="port">左舷</option><option value="starboard">右舷</option></select></label>
    <label>货船行为<select data-machine-field="cargoBehavior"><option value="flee">受威胁规避</option><option value="escort">按状态机执行</option></select></label>
  </div><div class="slider-grid tactic-sliders">${tacticSlider("preferredRange","理想射距",tactic.preferredRange,40,100)}${tacticSlider("approachThreshold","接近线",tactic.approachThreshold,102,150)}${tacticSlider("withdrawThreshold","脱离进入线",tactic.withdrawThreshold,35,90)}${tacticSlider("resumeThreshold","脱离退出线",tactic.resumeThreshold,70,130)}${tacticSlider("retreatHull","低耐久线",tactic.retreatHull,0,70)}${tacticSlider("engageSpeed","交火航速",tactic.engageSpeed,0,80)}</div>`;
  $("#tacticParameters").querySelectorAll("[data-machine-field]").forEach((input) => { input.value = String(tactic[input.dataset.machineField]); input.addEventListener("change", () => { tactic[input.dataset.machineField] = input.dataset.machineField === "chaseLastKnown" ? input.value === "true" : input.value; machine.tactic = normalizeTactic(tactic); saveLocal(); }); });
  $("#tacticParameters").querySelectorAll("[data-tactic-range]").forEach((input) => input.addEventListener("input", () => { tactic[input.dataset.tacticRange] = Number(input.value) / 100; input.closest("label").querySelector("output").textContent = `${input.value}%`; machine.tactic = normalizeTactic(tactic); saveLocal(); }));

  $("#tacticAssignments").innerHTML = state.fleets.map((fleet, faction) => `<section class="assignment-fleet"><b>${faction ? "红方" : "蓝方"}</b>${fleet.map((ship) => `<div class="assignment-row"><span>${escapeHtml(ship.name)}</span><select data-ship-tactic="${faction}:${ship.id}">${state.tacticLibrary.map((entry) => `<option value="${entry.id}" ${ship.tacticId === entry.id ? "selected" : ""}>${escapeHtml(entry.name)}</option>`).join("")}</select><label title="指挥官"><input type="radio" name="commander-${faction}" data-commander="${faction}:${ship.id}" ${ship.isCommander ? "checked" : ""}>指挥</label></div>`).join("")}</section>`).join("");
  $("#tacticAssignments").querySelectorAll("[data-ship-tactic]").forEach((input) => input.addEventListener("change", () => { const [faction,id]=input.dataset.shipTactic.split(":");state.fleets[Number(faction)].find((ship)=>ship.id===id).tacticId=input.value;saveLocal();renderEditor(); }));
  $("#tacticAssignments").querySelectorAll("[data-commander]").forEach((input) => input.addEventListener("change", () => { const [faction,id]=input.dataset.commander.split(":");state.fleets[Number(faction)].forEach((ship)=>{ship.isCommander=ship.id===id;});saveLocal();renderEditor(); }));
}

async function loadModsFromDirectory() {
  const status = $("#modStatus"); status.textContent = "读取中…";
  try {
    const response = await fetch("./api/mods"); const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || "无法读取 mods/");
    state.customWeapons = state.customWeapons.filter((item) => !item.sourceMod);
    state.customSensors = state.customSensors.filter((item) => !item.sourceMod);
    state.fleets = state.fleets.map((fleet) => fleet.filter((ship) => !ship.sourceMod));
    state.shipBlueprints = state.shipBlueprints.filter((ship) => !ship.sourceMod);
    state.tacticLibrary = state.tacticLibrary.filter((machine) => !machine.sourceMod);
    state.stateDefinitions = state.stateDefinitions.filter((definition) => !definition.sourceMod);
    const imported = importSimulatorMods(payload.packages, { weaponIds: Object.keys(catalog()), sensorIds: Object.keys(sensors()), machineIds: state.tacticLibrary.map((item) => item.id) });
    state.customWeapons.push(...imported.weapons); state.customSensors.push(...imported.sensors);
    state.shipBlueprints.push(...imported.ships.flat()); state.tacticLibrary.push(...imported.machines); state.stateDefinitions.push(...imported.stateDefinitions);
    for (const fleet of state.fleets) for (const ship of fleet) if (!state.tacticLibrary.some((machine) => machine.id === ship.tacticId)) ship.tacticId = "default";
    if (!selectedFleet().some((ship) => ship.id === state.selectedShipId)) state.selectedShipId = selectedFleet()[0]?.id || "";
    saveLocal(); renderAll(); if (!$("#tacticsWorkspace").hidden) renderTacticsWorkspace();
    const errors = payload.packages.filter((pkg) => pkg.error).length; status.textContent = `${payload.packages.length} Mod · ${imported.warnings.length + errors} 警告`;
    if (imported.warnings.length || errors) console.warn("模组导入警告", [...payload.packages.filter((pkg) => pkg.error).map((pkg) => pkg.error), ...imported.warnings]);
  } catch (error) { status.textContent = "Mod 读取失败"; alert(`读取 mods/ 失败：${error.message}`); }
}

async function exportCurrentAsMod() {
  const id = `simulator_export_${new Date().toISOString().replace(/[-:TZ.]/g, "").slice(0, 14)}`;
  const bundle = buildSimulatorMod({ id, name: `SNBattleSim Export ${new Date().toLocaleString()}`, customWeapons: state.customWeapons, customSensors: state.customSensors, fleets: state.fleets, tacticLibrary: state.tacticLibrary, stateDefinitions: state.stateDefinitions });
  try {
    const response = await fetch("./api/mods/export", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(bundle) }); const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || "导出失败");
    $("#modStatus").textContent = `已导出 ${payload.directory}`; alert(`已按游戏模组约定导出到：\nSNBattleSim/${payload.directory}`);
  } catch (error) { alert(`Mod 导出失败：${error.message}\n请使用 node SNBattleSim/tools/serve.mjs 启动模拟器。`); }
}

function renderAll() { renderFleetTabs(); renderFleetList(); renderEditor(); renderWeapons(); renderBattleStatus(); }

function bindStaticControls() {
  $("#loadMods").addEventListener("click", loadModsFromDirectory);
  $("#saveWorkspace").addEventListener("click", saveWorkspaceFile);
  $("#loadWorkspace").addEventListener("click", loadWorkspaceFile);
  $("#exportMod").addEventListener("click", exportCurrentAsMod);
  $("#openTactics").addEventListener("click", openTacticsWorkspace);
  $("#closeTactics").addEventListener("click", closeTacticsWorkspace);
  $("#tacticName").addEventListener("change", (event) => { selectedMachine().name = event.target.value.trim() || "未命名战术"; saveLocal(); renderTacticsWorkspace(); });
  $("#newTactic").addEventListener("click", () => { const id=uniqueMachineId(state.tacticLibrary);state.tacticLibrary.push({id,name:"新战术",builtin:false,tactic:normalizeTactic()});state.selectedTacticId=id;saveLocal();renderTacticsWorkspace(); });
  $("#duplicateTactic").addEventListener("click", () => { const source=selectedMachine(),id=uniqueMachineId(state.tacticLibrary);state.tacticLibrary.push({id,name:`${source.name} 副本`,builtin:false,tactic:normalizeTactic(JSON.parse(JSON.stringify(source.tactic)))});state.selectedTacticId=id;saveLocal();renderTacticsWorkspace(); });
  $("#deleteTactic").addEventListener("click", () => { const machine=selectedMachine();if(machine.builtin)return;state.tacticLibrary=state.tacticLibrary.filter((entry)=>entry.id!==machine.id);for(const fleet of state.fleets)for(const ship of fleet)if(ship.tacticId===machine.id)ship.tacticId="default";state.selectedTacticId="default";saveLocal();renderTacticsWorkspace();renderEditor(); });
  $("#openShipBuilder").addEventListener("click", openShipBuilder);
  $("#shipBuilderDialog [data-close-ship-builder]").addEventListener("click", () => $("#shipBuilderDialog").close());
  $("#shipBuilderForm").addEventListener("submit", (event) => {
    event.preventDefault(); const ship = shipDraftFromBuilder(); const errors = validateShip(ship, catalog(), sensors());
    if (errors.length) return updateShipBuilderValidation();
    selectedFleet().push(ship); state.selectedShipId = ship.id; $("#shipBuilderDialog").close(); saveAndRender();
  });
  $("#startBattle").addEventListener("click", startBattle);
  $("#pauseBattle").addEventListener("click", () => { state.paused = !state.paused; $("#pauseBattle").textContent = state.paused ? "继续" : "暂停"; });
  $("#stepBattle").addEventListener("click", () => { if (state.battle) { state.battle.tick(0.1); draw(); renderBattleStatus(); } });
  $("#speed").addEventListener("change", (event) => { state.speed = Number(event.target.value); });
  $("#viewMode").addEventListener("change", (event) => { state.viewMode = event.target.value; });
  $("#weaponForm").addEventListener("submit", (event) => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    try {
      const weapon = normalizeWeapon(Object.fromEntries(form), Object.keys(catalog()));
      state.customWeapons.push(weapon); event.currentTarget.reset(); saveLocal(); renderAll();
    } catch (error) { alert(error.message); }
  });
  $("#exportConfig").addEventListener("click", () => {
    const blob = new Blob([JSON.stringify(workspaceData(), null, 2)], { type: "application/json" });
    const link = document.createElement("a"); link.href = URL.createObjectURL(blob); link.download = "sn-battle-config.json"; link.click(); URL.revokeObjectURL(link.href);
  });
  $("#importConfig").addEventListener("change", async (event) => {
    try {
      const data = JSON.parse(await event.target.files[0].text());
      applyWorkspace(data);
      saveLocal(); renderAll();
    } catch (error) { alert(`导入失败：${error.message}`); }
  });
}

function loop(timestamp) {
  const elapsed = Math.min(0.08, (timestamp - state.lastTime) / 1000 || 0); state.lastTime = timestamp;
  if (state.battle && !state.paused && state.battle.state === "engaging") {
    state.accumulator += elapsed * state.speed;
    while (state.accumulator >= 0.05) { state.battle.tick(0.05); state.accumulator -= 0.05; }
  }
  draw();
  if (Math.floor(timestamp / 250) !== Math.floor((timestamp - elapsed * 1000) / 250)) renderBattleStatus();
  requestAnimationFrame(loop);
}

loadLocal(); bindStaticControls(); renderAll(); requestAnimationFrame(loop);
