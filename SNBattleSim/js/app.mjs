// @static-doc
// 作用：连接战斗画布、舰队装配器、自定义武器表单、配置导入导出与实时模拟控制。
//
// ## 契约与约束
// - UI 只修改装配配置；开始/重置战斗时才创建独立 BattleSimulation 快照。
// - 自定义武器保存在浏览器 localStorage，导入配置仍需经过目录规范化与舰船校验。
// - 画布可切换蓝方、红方或全知视角；阵营视角只显示已发现目标及其最后已知位置。
// - 每艘可见舰在舰名上方显示逐挂载武器装填条；隐藏目标不泄露武器冷却状态。
// - 战斗事件覆盖在战场右上角；下方状态面板跟随装配器当前选中的舰船。
// @end-static-doc

import { HULLS, SENSORS, BUILTIN_WEAPONS, createWeaponCatalog, normalizeWeapon } from "./catalog.mjs";
import { createShip, createDefaultFleets, cloneFleetConfig, deriveShipStats, validateShip } from "./loadout.mjs";
import { BattleSimulation } from "./simulation.mjs";
import { createCamera, screenWorldBounds, updateCamera, worldToScreen } from "./camera.mjs";
import { rangeShapes } from "./range_overlay.mjs";
import { mountReloadState } from "./combat_hud.mjs";
import { normalizeTactic, TACTICAL_STATE_LABELS } from "./tactics.mjs";

const STORAGE_KEY = "sn-battle-sim-v1";
const state = {
  customWeapons: [],
  fleets: createDefaultFleets(),
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
function selectedFleet() { return state.fleets[state.selectedFaction]; }
function selectedShip() { return selectedFleet().find((ship) => ship.id === state.selectedShipId) || selectedFleet()[0]; }

function saveLocal() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ customWeapons: state.customWeapons, fleets: state.fleets }));
}

function loadLocal() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "null");
    if (!saved) return;
    createWeaponCatalog(saved.customWeapons || []);
    if (Array.isArray(saved.fleets) && saved.fleets.length === 2) {
      state.customWeapons = saved.customWeapons || [];
      state.fleets = saved.fleets.map((fleet) => fleet.map((ship) => ({ ...ship, tactic: normalizeTactic(ship.tactic) })));
      state.selectedShipId = state.fleets[0][0]?.id || "";
    }
  } catch (error) {
    console.warn("忽略无效的本地战斗配置", error);
  }
}

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
  $("#fleetList").innerHTML = selectedFleet().map((ship) => {
    const errors = validateShip(ship, weaponCatalog);
    const stats = deriveShipStats(ship, weaponCatalog);
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
  const stats = deriveShipStats(ship, weaponCatalog);
  const errors = validateShip(ship, weaponCatalog);
  const availableSlots = HULLS[ship.hullId].weaponSlots - ship.weaponIds.length;
  ship.tactic = normalizeTactic(ship.tactic);

  host.innerHTML = `
    <div class="form-grid two">
      <label>舰名<input id="shipName" value="${escapeHtml(ship.name)}"></label>
      <label>用途<select id="shipRole"><option value="combat" ${ship.role === "combat" ? "selected" : ""}>战斗舰</option><option value="cargo" ${ship.role === "cargo" ? "selected" : ""}>货船</option></select></label>
      <label>固定船体<select id="hullId">${optionRows(HULLS, [ship.hullId])}</select></label>
    </div>
    <div class="subhead"><span>战术状态机</span><span>随舰保存</span></div>
    <div class="tactic-flow"><span>侦索</span><i>→</i><span>接近</span><i>→</i><span>交战</span><i>↔</i><span>脱离</span></div>
    <div class="tactic-help">进入脱离：距离低于“近距脱离”，或耐久首次跌破阈值。退出脱离：距离达到“脱离退出”。低耐久不会反复锁定脱离。</div>
    <div class="form-grid two tactic-controls">
      <label>目标优先<select data-tactic="targetPriority"><option value="nearest" ${ship.tactic.targetPriority === "nearest" ? "selected" : ""}>最近目标</option><option value="cargo" ${ship.tactic.targetPriority === "cargo" ? "selected" : ""}>货船优先</option><option value="weakest" ${ship.tactic.targetPriority === "weakest" ? "selected" : ""}>残血优先</option></select></label>
      <label>最后位置<select data-tactic="chaseLastKnown"><option value="true" ${ship.tactic.chaseLastKnown ? "selected" : ""}>继续追击</option><option value="false" ${!ship.tactic.chaseLastKnown ? "selected" : ""}>立即放弃</option></select></label>
      <label>无接触动作<select data-tactic="searchAction"><option value="advance" ${ship.tactic.searchAction === "advance" ? "selected" : ""}>向敌方推进</option><option value="hold" ${ship.tactic.searchAction === "hold" ? "selected" : ""}>原地待命</option></select></label>
      <label>交战绕行<select data-tactic="strafeSide"><option value="auto" ${ship.tactic.strafeSide === "auto" ? "selected" : ""}>阵营自动</option><option value="port" ${ship.tactic.strafeSide === "port" ? "selected" : ""}>左舷向敌</option><option value="starboard" ${ship.tactic.strafeSide === "starboard" ? "selected" : ""}>右舷向敌</option></select></label>
      <label>货船行为<select data-tactic="cargoBehavior"><option value="flee" ${ship.tactic.cargoBehavior === "flee" ? "selected" : ""}>受威胁撤离</option><option value="escort" ${ship.tactic.cargoBehavior === "escort" ? "selected" : ""}>随队交战</option></select></label>
    </div>
    <div class="slider-grid tactic-sliders">
      ${tacticSlider("preferredRange", "理想射距", ship.tactic.preferredRange, 40, 100)}
      ${tacticSlider("approachThreshold", "接近触发", ship.tactic.approachThreshold, 102, 150)}
      ${tacticSlider("withdrawThreshold", "近距脱离", ship.tactic.withdrawThreshold, 35, 90)}
      ${tacticSlider("resumeThreshold", "脱离退出", ship.tactic.resumeThreshold, 70, 130)}
      ${tacticSlider("retreatHull", "低耐久脱离", ship.tactic.retreatHull, 0, 70)}
      ${tacticSlider("engageSpeed", "交战航速", ship.tactic.engageSpeed, 0, 80)}
    </div>
    <div class="subhead"><span>视野组件</span><span>${ship.sensorIds.length}/${HULLS[ship.hullId].sensorSlots}</span></div>
    <div class="mount-list">${ship.sensorIds.map((id, index) => {
      const sensor = SENSORS[id];
      return `<div class="mount sensor"><span>${escapeHtml(sensor?.name || id)}<small>${sensor ? `视野 +${sensor.rangeBonus} · 命中 +${Math.round(sensor.accuracyBonus * 100)}%` : "未知组件"}</small></span><button data-remove-sensor="${index}" title="卸下">×</button></div>`;
    }).join("") || `<div class="empty compact">没有视野组件</div>`}</div>
    <div class="inline-add"><select id="sensorToAdd">${optionRows(SENSORS, [])}</select><button id="addSensor" ${ship.sensorIds.length >= HULLS[ship.hullId].sensorSlots ? "disabled" : ""}>安装</button></div>
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
  host.querySelectorAll("select[data-tactic]").forEach((input) => input.addEventListener("change", () => {
    ship.tactic[input.dataset.tactic] = input.dataset.tactic === "chaseLastKnown" ? input.value === "true" : input.value;
    ship.tactic = normalizeTactic(ship.tactic); saveLocal();
  }));
  host.querySelectorAll("input[data-tactic-range]").forEach((input) => input.addEventListener("input", () => {
    ship.tactic[input.dataset.tacticRange] = Number(input.value) / 100;
    input.closest("label").querySelector("output").textContent = `${input.value}%`;
    saveLocal();
  }));
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
      refreshShipSheet(host, ship, weaponCatalog);
    });
    input.addEventListener("change", () => { saveLocal(); renderFleetList(); });
  });
  host.querySelector("#cargoValue").addEventListener("input", (event) => { ship.cargoValue = Number(event.target.value); saveLocal(); refreshShipSheet(host, ship, weaponCatalog); });
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

function refreshShipSheet(host, ship, weaponCatalog) {
  const stats = deriveShipStats(ship, weaponCatalog);
  const scratch = document.createElement("div");
  scratch.innerHTML = shipSheet(stats, ship);
  scratch.querySelectorAll("[data-stat]").forEach((next) => {
    const current = host.querySelector(`[data-stat="${next.dataset.stat}"]`);
    if (current) current.textContent = next.textContent;
  });
  const errors = validateShip(ship, weaponCatalog);
  const validation = host.querySelector("#shipValidation");
  validation.className = `validation ${errors.length ? "invalid" : "valid"}`;
  validation.innerHTML = errors.length ? errors.map(escapeHtml).join("<br>") : "装配有效，可以投入模拟";
}

function saveAndRender() { saveLocal(); renderFleetList(); renderEditor(); renderBattleStatus(); }

function renderWeapons() {
  const all = catalog();
  $("#weaponCatalog").innerHTML = Object.values(all).map((weapon) => `<div class="weapon-row"><span><b>${escapeHtml(weapon.name)}</b><small>${weaponKindLabel(weapon.kind)} · ${weapon.salvo || 1} 发齐射 · 伤害 ${weapon.damage} · 射程 ${weapon.range} · 射界 ${weapon.arc}° · ${weapon.mass}t</small></span>${BUILTIN_WEAPONS[weapon.id] ? "<em>内置</em>" : `<button data-delete-weapon="${weapon.id}">删除</button>`}</div>`).join("");
  $("#sensorCatalog").innerHTML = Object.values(SENSORS).map((sensor) => `<div class="weapon-row"><span><b>${escapeHtml(sensor.name)}</b><small>视野 +${sensor.rangeBonus} · 命中 +${Math.round(sensor.accuracyBonus * 100)}% · ${sensor.mass}t</small></span><em>内置</em></div>`).join("");
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
  const errors = state.fleets.flatMap((fleet) => fleet.flatMap((ship) => validateShip(ship, catalog()).map((error) => `${ship.name}：${error}`)));
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
  const stateLabel = ship.escaped ? "已撤离" : ship.disabled ? "失能" : TACTICAL_STATE_LABELS[ship.tacticalState] || "侦索";
  const weaponRows = ship.mounts.map((mount) => {
    const reload = mountReloadState(mount);
    return `<span style="--weapon:${mount.weapon.color}"><b>${escapeHtml(mount.weapon.name)}</b><em>${reload.label}</em></span>`;
  }).join("");
  host.innerHTML = `<div class="runtime-summary">
    <div><small>舰船</small><b>${escapeHtml(ship.config.name)}</b></div>
    <div><small>状态</small><b>${stateLabel}</b></div>
    <div><small>耐久</small><b>${ship.hull.toFixed(0)} / ${ship.stats.hullMax.toFixed(0)}</b></div>
    <div><small>航速</small><b>${ship.speedCurrent.toFixed(1)} / ${ship.stats.speed.toFixed(1)}</b></div>
    <div><small>目标</small><b>${target ? escapeHtml(target.config.name) : "无"}</b></div>
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
    state.battle = new BattleSimulation({ fleets: cloneFleetConfig(state.fleets), weaponCatalog: catalog(), seed: Number($("#seed").value) || 5201 });
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
  context.fillText(`${ship.config.name} · ${TACTICAL_STATE_LABELS[ship.tacticalState] || "侦索"}`, point.x, point.y - r - 8);
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

function renderAll() { renderFleetTabs(); renderFleetList(); renderEditor(); renderWeapons(); renderBattleStatus(); }

function bindStaticControls() {
  $("#addCombat").addEventListener("click", () => addShip("combat"));
  $("#addCargo").addEventListener("click", () => addShip("cargo"));
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
    const blob = new Blob([JSON.stringify({ version: 1, customWeapons: state.customWeapons, fleets: state.fleets }, null, 2)], { type: "application/json" });
    const link = document.createElement("a"); link.href = URL.createObjectURL(blob); link.download = "sn-battle-config.json"; link.click(); URL.revokeObjectURL(link.href);
  });
  $("#importConfig").addEventListener("change", async (event) => {
    try {
      const data = JSON.parse(await event.target.files[0].text());
      createWeaponCatalog(data.customWeapons || []);
      if (!Array.isArray(data.fleets) || data.fleets.length !== 2) throw new Error("配置必须包含两支舰队");
      state.customWeapons = data.customWeapons || []; state.fleets = data.fleets.map((fleet) => fleet.map((ship) => ({ ...ship, tactic: normalizeTactic(ship.tactic) }))); state.selectedFaction = 0; state.selectedShipId = state.fleets[0][0]?.id || "";
      saveLocal(); renderAll();
    } catch (error) { alert(`导入失败：${error.message}`); }
  });
}

function addShip(role) {
  const ship = createShip({ id: `ship_${state.selectedFaction}_${Date.now().toString(36)}_${selectedFleet().length}`, name: role === "cargo" ? "新货船" : "新战斗舰", role, hullId: role === "cargo" ? "large" : "small", weaponIds: role === "cargo" ? ["repeater"] : ["deck_gun"], sensorIds: ["lookout"] });
  selectedFleet().push(ship); state.selectedShipId = ship.id; saveAndRender();
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
