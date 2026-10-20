#!/usr/bin/env node
// @static-doc
// 作用：提供无浏览器的模组校验、状态机检查、确定性战斗快跑与示例模组导出，供 Agent 快速调试。
//
// ## 契约与约束
// - 默认读取 SNBattleSim/mods 下的散装目录与 ZIP；export-sample 创建不覆盖的 .snavmod.zip。
// - simulate 使用固定时间步长，输出机器可读 JSON；非零退出码表示校验或运行失败。
// @end-static-doc
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createSensorCatalog, createWeaponCatalog, SENSORS } from "../js/catalog.mjs";
import { createDefaultFleets } from "../js/loadout.mjs";
import { BattleSimulation } from "../js/simulation.mjs";
import { createDefaultTacticLibrary, resolveShipTactic } from "../js/tactic_library.mjs";
import { buildSimulatorMod, importSimulatorMods } from "../js/mod_format.mjs";
import { readModPackages, writeModArchive } from "./mod_io.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const modsRoot = path.join(root, "mods");
const args = process.argv.slice(2); const command = args[0] || "help";
const option = (name, fallback) => { const index = args.indexOf(`--${name}`); return index >= 0 ? args[index + 1] : fallback; };
const output = (value) => process.stdout.write(`${JSON.stringify(value, null, 2)}\n`);

function load() {
  const packages = readModPackages(modsRoot); const broken = packages.filter((pkg) => pkg.error);
  const imported = importSimulatorMods(packages, { weaponIds: Object.keys(createWeaponCatalog()), sensorIds: Object.keys(SENSORS), machineIds: ["default"] });
  return { packages, broken, imported };
}

try {
  if (command === "help") output({ commands: { "validate-mods": "校验 mods/ 并列出导入数量", "inspect": "输出模组与状态机摘要", "simulate --ticks 1200 --seed 5201": "确定性战斗快跑", "export-sample --id agent_debug": "导出标准示例模组" } });
  else if (command === "validate-mods") { const { packages, broken, imported } = load(); output({ ok: !broken.length && !imported.warnings.length, mods: packages.map((pkg) => pkg.manifest.id), errors: broken.map((pkg) => `${pkg.directory}: ${pkg.error}`), warnings: imported.warnings, imported: { weapons: imported.weapons.length, sensors: imported.sensors.length, ships: imported.ships.map((fleet) => fleet.length), machines: imported.machines.length, states: imported.stateDefinitions.length } }); if (broken.length || imported.warnings.length) process.exitCode = 1; }
  else if (command === "inspect") { const { packages, imported } = load(); output({ modsRoot, mods: packages.map((pkg) => ({ id: pkg.manifest.id, directory: pkg.directory, content: Object.keys(pkg.content) })), machines: imported.machines.map((machine) => ({ id: machine.id, name: machine.name, nodes: machine.tactic.fsm.nodes.length, transitions: machine.tactic.fsm.transitions.length })), warnings: imported.warnings }); }
  else if (command === "simulate") {
    const { imported } = load(); const weapons = createWeaponCatalog(imported.weapons); const sensors = createSensorCatalog(imported.sensors);
    const fleets = imported.ships.some((fleet) => fleet.length) ? imported.ships : createDefaultFleets(); const library = [...createDefaultTacticLibrary(), ...imported.machines];
    for (const fleet of fleets) for (const ship of fleet) ship.tactic = resolveShipTactic(ship, library);
    const battle = new BattleSimulation({ fleets, weaponCatalog: weapons, sensorCatalog: sensors, seed: Number(option("seed", 5201)) });
    const ticks = Math.max(1, Math.min(100000, Number(option("ticks", 1200)))); for (let index = 0; index < ticks && battle.state === "engaging"; index += 1) battle.tick(0.05);
    output({ ok: true, ticks, time: battle.time, state: battle.state, winner: battle.winner, summary: battle.summary(), events: battle.events.length });
  } else if (command === "export-sample") {
    const id = String(option("id", `agent_debug_${Date.now().toString(36)}`)); const bundle = buildSimulatorMod({ id, name: "SNBattleSim Agent Debug", fleets: createDefaultFleets(), tacticLibrary: createDefaultTacticLibrary() }); const archive = writeModArchive(modsRoot, bundle); output({ ok: true, archive });
  } else throw new Error(`未知命令：${command}`);
} catch (error) { output({ ok: false, error: error.message }); process.exitCode = 1; }
