// @static-doc
// 作用：定义模拟器扩展模组的数据类型，解析游戏约定 definitions 外壳，并生成可写入 mods/ 的标准模组文件集合。
//
// ## 契约与约束
// - 文件沿用 manifest.json + content/*.json + localization/*.json 结构，实体 ID 必须带模组命名空间。
// - 模拟器扩展类型为 battle_weapons、battle_sensors、battle_ships、battle_states、battle_state_machines。
// - 船体仍只允许 small/medium/large；状态 runtime_action 必须映射到内置安全动作。
// @end-static-doc

import { normalizeSensor, normalizeWeapon } from "./catalog.mjs";
import { createShip } from "./loadout.mjs";
import { FSM_ACTIONS, FSM_STATE_DEFINITIONS, normalizeTactic } from "./tactics.mjs";
import { normalizeTacticLibrary } from "./tactic_library.mjs";

export const SIM_MOD_TYPES = Object.freeze(["battle_weapons", "battle_sensors", "battle_ships", "battle_states", "battle_state_machines"]);
const localId = (value, fallback) => String(value || fallback).split("/").pop().replace(/[^a-zA-Z0-9_-]/g, "_").toLowerCase();
const envelope = (contentType, definitions) => ({ schema_version: "1.0", content_type: contentType, definitions });
const definition = (id, nameKey, data) => ({ id, name_key: nameKey, enabled: true, data });

export function importSimulatorMods(packages, existing = {}) {
  const result = { weapons: [], sensors: [], ships: [[], []], machines: [], stateDefinitions: [], warnings: [] };
  const weaponIds = [...(existing.weaponIds || [])]; const sensorIds = [...(existing.sensorIds || [])]; const machineIds = new Set(existing.machineIds || []);
  const machineRefs = new Map();
  for (const pkg of packages || []) {
    const modId = String(pkg?.manifest?.id || "unknown");
    for (const doc of Object.values(pkg?.content || {})) if (doc?.content_type === "battle_state_machines" && Array.isArray(doc.definitions)) {
      for (const item of doc.definitions) {
        const base = `${localId(modId, "mod")}__${localId(item.id, "tactic")}`; let internal = base, serial = 2;
        while (machineIds.has(internal)) internal = `${base}_${serial++}`;
        machineIds.add(internal); machineRefs.set(item.id, internal);
      }
    }
  }
  for (const pkg of packages || []) {
    const modId = String(pkg?.manifest?.id || "unknown");
    for (const doc of Object.values(pkg?.content || {})) {
      if (!SIM_MOD_TYPES.includes(doc?.content_type) || !Array.isArray(doc.definitions)) continue;
      for (const item of doc.definitions) {
        if (item?.enabled === false) continue;
        const data = item?.data || {};
        try {
          if (doc.content_type === "battle_weapons") { const weapon = normalizeWeapon({ ...data, id: localId(item.id, "weapon"), name: data.name || item.name_key || item.id }, weaponIds); weapon.sourceMod = modId; weaponIds.push(weapon.id); result.weapons.push(weapon); }
          if (doc.content_type === "battle_sensors") { const sensor = normalizeSensor({ ...data, id: localId(item.id, "sensor"), name: data.name || item.name_key || item.id }, sensorIds); sensor.sourceMod = modId; sensorIds.push(sensor.id); result.sensors.push(sensor); }
          if (doc.content_type === "battle_ships") { const faction = Number(data.faction) === 1 ? 1 : 0; const tacticId = machineRefs.get(data.tactic_ref) || machineRefs.get(`${modId}:battle_state_machine/${data.tacticId}`) || data.tacticId || "default"; const ship = createShip({ ...data, tacticId, id: localId(item.id, "ship"), name: data.name || item.name_key || item.id }); ship.sourceMod = modId; result.ships[faction].push(ship); }
          if (doc.content_type === "battle_states") { if (!Object.hasOwn(FSM_ACTIONS, data.runtime_action)) throw new Error(`未知 runtime_action：${data.runtime_action}`); result.stateDefinitions.push({ id: `${localId(modId, "mod")}__${localId(item.id, data.runtime_action)}`, sourceId: item.id, name: data.name || FSM_ACTIONS[data.runtime_action], description: data.description || "", runtimeAction: data.runtime_action, sourceMod: modId }); }
          if (doc.content_type === "battle_state_machines") { const id = machineRefs.get(item.id); result.machines.push({ id, sourceId: item.id, name: data.name || item.name_key || item.id, builtin: false, tactic: normalizeTactic(data.tactic || data), sourceMod: modId }); }
        } catch (error) { result.warnings.push(`${modId}/${item?.id || "unknown"}：${error.message}`); }
      }
    }
  }
  return result;
}

export function buildSimulatorMod({ id = "simulator_custom", name = "SNBattleSim Custom Data", customWeapons = [], customSensors = [], fleets = [[], []], tacticLibrary = [], stateDefinitions = FSM_STATE_DEFINITIONS }) {
  const modId = String(id).toLowerCase().replace(/[^a-z0-9_-]/g, "_") || "simulator_custom";
  const localization = {};
  const makeDefs = (type, values, mapper) => values.map((value, index) => {
    const entityId = `${modId}:${type}/${localId(value.id, `${type}_${index + 1}`)}`;
    const key = `${modId}.${type}.${localId(value.id, index + 1)}.name`; localization[key] = value.name || entityId;
    return definition(entityId, key, mapper(value));
  });
  const machines = normalizeTacticLibrary(tacticLibrary);
  const files = {
    "content/battle_weapons.json": envelope("battle_weapons", makeDefs("battle_weapon", customWeapons, (value) => { const { sourceMod, ...data } = value; return data; })),
    "content/battle_sensors.json": envelope("battle_sensors", makeDefs("battle_sensor", customSensors, (value) => { const { sourceMod, ...data } = value; return data; })),
    "content/battle_ships.json": envelope("battle_ships", fleets.flatMap((fleet, faction) => makeDefs("battle_ship", fleet, (value) => { const { sourceMod, tactic, tacticId, ...data } = value; return { ...data, faction, tactic_ref: `${modId}:battle_state_machine/${localId(tacticId, "default")}` }; }))),
    "content/battle_states.json": envelope("battle_states", stateDefinitions.map((state) => definition(`${modId}:battle_state/${localId(state.id, state.runtimeAction)}`, `${modId}.battle_state.${localId(state.id, state.runtimeAction)}.name`, { name: state.name, description: state.description, runtime_action: state.runtimeAction }))),
    "content/battle_state_machines.json": envelope("battle_state_machines", makeDefs("battle_state_machine", machines, (value) => ({ name: value.name, tactic: value.tactic }))),
    "localization/zh_CN.json": localization,
  };
  for (const state of stateDefinitions) localization[`${modId}.battle_state.${localId(state.id, state.runtimeAction)}.name`] = state.name;
  const content = Object.keys(files).filter((file) => file.startsWith("content/"));
  const manifest = { $schema: "https://steam-navigator.local/schema/mod-manifest-1.json", id: modId, name, version: "1.0.0", api_version: "1.0", type: "content", load_priority: 100, required: false, dependencies: [], optional_dependencies: [], conflicts: [], content, localization: ["localization/zh_CN.json"], assets: {}, authors: ["SNBattleSim"], license: "Unspecified", description: "Battle simulator data exported using Steam Navigator mod conventions.", capabilities: ["content.combat.simulator.v1"] };
  return { manifest, files: { "manifest.json": manifest, ...files } };
}
