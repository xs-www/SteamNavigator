// @static-doc
// 作用：覆盖装配、十状态 FSM、状态机库挂载、模组目录/ZIP 往返、视野、武器射界和确定性战斗结果。
// @end-static-doc

import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { HULLS, createSensorCatalog, createWeaponCatalog, normalizeWeapon } from "../js/catalog.mjs";
import { createDefaultFleets, createShip, deriveShipStats, validateShip } from "../js/loadout.mjs";
import { BattleSimulation } from "../js/simulation.mjs";
import { cameraTarget, worldToScreen } from "../js/camera.mjs";
import { rangeShapes } from "../js/range_overlay.mjs";
import { mountReloadState } from "../js/combat_hud.mjs";
import { defaultFsm, FSM_ACTIONS, normalizeFsm, normalizeTactic, tacticalDecision, tacticalState } from "../js/tactics.mjs";
import { createDefaultTacticLibrary, migrateTacticalData, resolveShipTactic } from "../js/tactic_library.mjs";
import { buildSimulatorMod, importSimulatorMods } from "../js/mod_format.mjs";
import { readModPackages, writeModArchive, writeModBundle } from "../tools/mod_io.mjs";
import { readWorkspace, writeWorkspace } from "../tools/workspace_io.mjs";

test("船体固定为大中小三种", () => {
  assert.deepEqual(Object.keys(HULLS), ["small", "medium", "large"]);
});

test("一艘船可安装多种武器并受槽位限制", () => {
  const weapons = createWeaponCatalog();
  const valid = createShip({ hullId: "medium", weaponIds: ["deck_gun", "heavy_cannon", "mortar"] });
  assert.equal(validateShip(valid, weapons).length, 0);
  valid.weaponIds.push("repeater");
  assert.match(validateShip(valid, weapons).join(" "), /武器槽超限/);
});

test("货船扩容反映到船舶数值和重量", () => {
  const weapons = createWeaponCatalog();
  const cargo = createShip({ hullId: "large", role: "cargo", weaponIds: ["repeater"], sensorIds: ["lookout"], tuning: { cargo: 70 } });
  const stats = deriveShipStats(cargo, weapons);
  assert.ok(stats.cargoCapacity > HULLS.large.cargoBase);
  assert.ok(stats.mass > HULLS.large.baseMass);
});

test("用户武器被规范化且不能覆盖已有 ID", () => {
  const custom = normalizeWeapon({ id: "long_gun", name: "长炮", damage: 999, range: 320 }, Object.keys(createWeaponCatalog()));
  assert.equal(custom.damage, 120);
  assert.equal(custom.id, "long_gun");
  assert.throws(() => normalizeWeapon({ id: "deck_gun", name: "覆盖" }, Object.keys(createWeaponCatalog())), /已存在/);
});

test("舰队共享视野但远距离目标保持隐藏", () => {
  const weapons = createWeaponCatalog();
  const fleets = [
    [createShip({ id: "a", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
    [createShip({ id: "b", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
  ];
  const battle = new BattleSimulation({ fleets, weaponCatalog: weapons });
  const enemy = battle.ships.find((ship) => ship.faction === 1);
  assert.equal(battle.contactFor(0, enemy.uid), null);
  enemy.x = -80;
  battle.tick(0.05);
  assert.equal(battle.contactFor(0, enemy.uid)?.visible, true);
});

test("战斗世界没有地图边缘，远坐标不会被夹回画布", () => {
  const weapons = createWeaponCatalog();
  const fleets = [
    [createShip({ id: "a", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
    [createShip({ id: "b", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
  ];
  const battle = new BattleSimulation({ fleets, weaponCatalog: weapons });
  const ship = battle.ships[0];
  ship.x = 4200; ship.y = -3100;
  battle.tick(0.1);
  assert.ok(ship.x > 4000);
  assert.ok(ship.y < -3000);
});

test("跟随镜头能把任意世界坐标的全部战船收入画面", () => {
  const ships = [{ x: -1400, y: -900, escaped: false }, { x: 2300, y: 1250, escaped: false }, { x: 9000, y: 9000, escaped: true }];
  const camera = { ...cameraTarget(ships, 920, 560), initialized: true };
  const points = ships.slice(0, 2).map((ship) => worldToScreen(camera, ship, 920, 560));
  for (const point of points) {
    assert.ok(point.x >= 70 && point.x <= 850);
    assert.ok(point.y >= 70 && point.y <= 490);
  }
});

test("船体使用低转向率和低加速度", () => {
  assert.ok(HULLS.small.turnRate < 0.5 && HULLS.small.acceleration < 10);
  assert.ok(HULLS.medium.turnRate < HULLS.small.turnRate);
  assert.ok(HULLS.large.turnRate < HULLS.medium.turnRate);
  assert.ok(HULLS.large.hull < 200);
});

test("基础视野与最高航速保留足够观察时间", () => {
  for (const hull of Object.values(HULLS)) assert.ok(hull.baseVision / hull.speed >= 9);
});

test("所选舰为每个武器生成独立射界且侧弦为双扇区", () => {
  const weapons = createWeaponCatalog();
  const ship = {
    heading: 0.4,
    stats: { vision: 410, weapons: [weapons.deck_gun, weapons.broadside, weapons.mortar] },
  };
  const shapes = rangeShapes(ship);
  assert.equal(shapes.filter((shape) => shape.role === "vision").length, 1);
  assert.equal(shapes.filter((shape) => shape.weapon?.id === "deck_gun").length, 1);
  assert.equal(shapes.filter((shape) => shape.weapon?.id === "broadside").length, 2);
  assert.equal(shapes.find((shape) => shape.weapon?.id === "mortar")?.type, "circle");
});

test("武器装填条显示独立倒计时和归一化进度", () => {
  const weapon = { cooldown: 5 };
  assert.deepEqual(mountReloadState({ weapon, cooldown: 0 }), { ready: true, remaining: 0, progress: 1, label: "就绪" });
  assert.deepEqual(mountReloadState({ weapon, cooldown: 2.5 }), { ready: false, remaining: 2.5, progress: 0.5, label: "2.5" });
  assert.equal(mountReloadState({ weapon, cooldown: 8 }).progress, 0);
});

test("战术状态机按用户阈值切换状态", () => {
  const tactic = normalizeTactic({ preferredRange: 0.8, approachThreshold: 1.2, withdrawThreshold: 0.5, retreatHull: 0.3 });
  const base = { tactic, role: "combat", hullRatio: 1, hasTarget: true, maxRange: 400, threatened: false, wasThreatened: false };
  assert.equal(tacticalState({ ...base, targetDistance: 390 }), "approach");
  assert.equal(tacticalState({ ...base, targetDistance: 260 }), "engage");
  assert.equal(tacticalState({ ...base, targetDistance: 140 }), "withdraw");
  assert.equal(tacticalState({ ...base, targetDistance: 260, hullRatio: 0.2, lowHullCrossed: true }), "withdraw");
  assert.equal(tacticalState({ ...base, hasTarget: false }), "cruise");
});

test("开发者状态机提供十种战术动作", () => {
  assert.deepEqual(Object.keys(FSM_ACTIONS), ["recon", "cruise", "approach", "flank", "evade", "maneuver", "withdraw", "flee", "engage", "focus"]);
  assert.deepEqual(defaultFsm().nodes.map((node) => node.action), ["cruise", "approach", "engage", "withdraw", "evade"]);
});

test("状态机库迁移旧随舰配置并保持单一挂载", () => {
  const legacy = createShip({ id: "legacy", tactic: { targetPriority: "weakest" } });
  delete legacy.tacticId;
  const fleets = [[legacy], []];
  const library = migrateTacticalData(fleets, createDefaultTacticLibrary());
  assert.match(fleets[0][0].tacticId, /^legacy_/);
  assert.equal(resolveShipTactic(fleets[0][0], library).targetPriority, "weakest");
  assert.equal(library.filter((entry) => entry.id === "default").length, 1);
});

test("货船战术可在规避和随队交战间切换", () => {
  const base = { role: "cargo", hullRatio: 1, hasTarget: true, targetDistance: 220, maxRange: 300, threatened: true, wasThreatened: true };
  assert.equal(tacticalState({ ...base, tactic: { cargoBehavior: "flee" } }), "evade");
  assert.notEqual(tacticalState({ ...base, tactic: { cargoBehavior: "escort" } }), "evade");
});

test("脱离使用退出距离且低耐久不会永久重复触发", () => {
  const tactic = normalizeTactic({ preferredRange: 0.8, withdrawThreshold: 0.5, resumeThreshold: 0.9, retreatHull: 0.3 });
  const base = { tactic, role: "combat", hullRatio: 0.2, hasTarget: true, maxRange: 400, threatened: false, wasThreatened: false };
  const entered = tacticalDecision({ ...base, targetDistance: 250, previousState: "engage", lowHullCrossed: true });
  assert.equal(entered.state, "withdraw");
  assert.match(entered.reason, /耐久阈值/);
  assert.equal(tacticalDecision({ ...base, targetDistance: 270, previousState: "withdraw", previousReason: entered.reason }).state, "withdraw");
  assert.equal(tacticalDecision({ ...base, targetDistance: 300, previousState: "withdraw", previousReason: entered.reason }).state, "engage");
});

test("自定义 FSM 保存节点布局并过滤无效连线", () => {
  const fsm = normalizeFsm({
    initial: "wait",
    nodes: [{ id: "wait", name: "伏击", action: "search", x: 0.2, y: 0.3 }, { id: "rush", name: "冲锋", action: "approach", x: 0.8, y: 0.7 }],
    transitions: [{ id: "go", from: "wait", to: "rush", condition: "has_target" }, { id: "bad", from: "missing", to: "rush", condition: "always" }],
  });
  assert.equal(fsm.initial, "wait");
  assert.equal(fsm.nodes[0].name, "伏击");
  assert.equal(fsm.nodes[1].x, 0.8);
  assert.deepEqual(fsm.transitions.map((edge) => edge.id), ["go"]);
});

test("运行时按玩家绘制的 FSM 连线转换", () => {
  const tactic = normalizeTactic({ fsm: {
    initial: "wait",
    nodes: [{ id: "wait", name: "伏击", action: "search" }, { id: "attack", name: "突击", action: "engage" }],
    transitions: [{ id: "spot", from: "wait", to: "attack", condition: "has_target" }],
  } });
  const decision = tacticalDecision({ tactic, role: "combat", hullRatio: 1, hasTarget: true, targetDistance: 500, maxRange: 200, previousNodeId: "wait" });
  assert.equal(decision.nodeId, "attack");
  assert.equal(decision.state, "engage");
});

test("转移条件支持且与或聚合", () => {
  const baseFsm = { initial: "wait", nodes: [{ id: "wait", name: "等待", action: "cruise" }, { id: "attack", name: "攻击", action: "engage" }] };
  const all = normalizeTactic({ fsm: { ...baseFsm, transitions: [{ id: "go", from: "wait", to: "attack", logic: "all", conditions: ["visible_target", "weapon_ready"] }] } });
  assert.equal(tacticalDecision({ tactic: all, role: "combat", hullRatio: 1, hasTarget: true, targetVisible: true, weaponReady: false, previousNodeId: "wait" }).state, "cruise");
  assert.equal(tacticalDecision({ tactic: all, role: "combat", hullRatio: 1, hasTarget: true, targetVisible: true, weaponReady: true, previousNodeId: "wait" }).state, "engage");
  const any = normalizeTactic({ fsm: { ...baseFsm, transitions: [{ id: "go", from: "wait", to: "attack", logic: "any", conditions: ["visible_target", "weapon_ready"] }] } });
  assert.equal(tacticalDecision({ tactic: any, role: "combat", hullRatio: 1, hasTarget: false, targetVisible: false, weaponReady: true, previousNodeId: "wait" }).state, "engage");
});

test("游戏约定 Mod 可往返武器、视野组件、船舶、状态与状态机", () => {
  const fleets = [[createShip({ id: "escort", tacticId: "custom" })], []];
  const library = [...createDefaultTacticLibrary(), { id: "custom", name: "自定义", builtin: false, tactic: normalizeTactic() }];
  const bundle = buildSimulatorMod({ id: "roundtrip", customWeapons: [{ id: "longgun", name: "长炮", kind: "direct", damage: 20, range: 300, minRange: 0, cooldown: 2, accuracy: 0.7, projectileSpeed: 300, splash: 0, mass: 10, arc: 180, salvo: 1, color: "#ffffff" }], customSensors: [{ id: "tower", name: "观测塔", rangeBonus: 120, accuracyBonus: 0.03, mass: 6 }], fleets, tacticLibrary: library });
  const imported = importSimulatorMods([{ manifest: bundle.manifest, content: Object.fromEntries(Object.entries(bundle.files).filter(([key]) => key.startsWith("content/"))) }], { weaponIds: Object.keys(createWeaponCatalog()), sensorIds: Object.keys(createSensorCatalog()), machineIds: ["default"] });
  assert.equal(imported.weapons[0].id, "longgun");
  assert.equal(imported.sensors[0].id, "tower");
  assert.equal(imported.ships[0][0].tacticId, "roundtrip__custom");
  assert.equal(imported.machines.length, 2);
  assert.equal(imported.stateDefinitions.length, 10);
  assert.deepEqual(imported.warnings, []);
});

test("Mod IO 仅在独立目录写入并可重新扫描", () => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "snbattle-mods-"));
  try {
    const bundle = buildSimulatorMod({ id: "io_test", fleets: createDefaultFleets(), tacticLibrary: createDefaultTacticLibrary() });
    const target = writeModBundle(temp, bundle);
    assert.equal(path.dirname(target), temp);
    const packages = readModPackages(temp);
    assert.equal(packages[0].manifest.id, "io_test");
    assert.equal(packages[0].content["content/battle_states.json"].definitions.length, 10);
  } finally { fs.rmSync(temp, { recursive: true, force: true }); }
});

test("Mod IO 可导出并重新读取游戏约定 ZIP", () => {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), "snbattle-zip-"));
  try {
    const bundle = buildSimulatorMod({ id: "zip_test", fleets: createDefaultFleets(), tacticLibrary: createDefaultTacticLibrary() });
    const target = writeModArchive(temp, bundle);
    assert.equal(path.basename(target), "zip_test.snavmod.zip");
    const packages = readModPackages(temp);
    assert.equal(packages[0].source, "zip");
    assert.equal(packages[0].manifest.id, "zip_test");
    assert.equal(packages[0].content["content/battle_states.json"].definitions.length, 10);
  } finally { fs.rmSync(temp, { recursive: true, force: true }); }
});

test("工程目录可原子保存并读取装配数据", () => {
  const temp = fs.mkdtempSync(path.join(path.dirname(fileURLToPath(import.meta.url)), ".workspace-"));
  try {
    const value = { version: 4, fleets: createDefaultFleets(), tacticLibrary: createDefaultTacticLibrary() };
    writeWorkspace(temp, value); assert.deepEqual(readWorkspace(temp), value);
  } finally { fs.rmSync(temp, { recursive: true, force: true }); }
});

test("脱离状态在射界内仍会开火", () => {
  const weapons = createWeaponCatalog();
  const withdrawOnly = normalizeTactic({ fsm: { initial: "withdraw", nodes: [{ id: "withdraw", name: "脱离", action: "withdraw" }], transitions: [] } });
  const blue = createShip({ id: "blue", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"], tactic: withdrawOnly });
  const red = createShip({ id: "red", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] });
  const battle = new BattleSimulation({ fleets: [[blue], [red]], weaponCatalog: weapons });
  battle.ships[0].x = 0; battle.ships[0].y = 0; battle.ships[0].heading = 0; battle.ships[1].x = 100; battle.ships[1].y = 0;
  battle.tick(0.05);
  assert.equal(battle.ships[0].tacticalState, "withdraw"); assert.ok(battle.ships[0].shots > 0);
});

test("急转时速度方向不会落到船尾半球", () => {
  const weapons = createWeaponCatalog();
  const fleets = [
    [createShip({ id: "cargo", hullId: "large", role: "cargo", weaponIds: ["repeater"], sensorIds: ["mast"] })],
    [createShip({ id: "enemy", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
  ];
  const battle = new BattleSimulation({ fleets, weaponCatalog: weapons });
  const cargo = battle.ships[0]; const enemy = battle.ships[1];
  cargo.speedCurrent = 12; cargo.velocityHeading = 0; cargo.heading = 0;
  enemy.x = cargo.x + 80; enemy.y = cargo.y;
  for (let index = 0; index < 180; index += 1) {
    battle.tick(0.05);
    assert.ok(Math.cos(cargo.velocityHeading - cargo.heading) >= -0.001);
  }
});

test("丢失当前视野后仍追击最后已知位置", () => {
  const weapons = createWeaponCatalog();
  const fleets = [
    [createShip({ id: "a", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
    [createShip({ id: "b", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
  ];
  const battle = new BattleSimulation({ fleets, weaponCatalog: weapons });
  const blue = battle.ships[0];
  const red = battle.ships[1];
  red.x = -40; red.y = blue.y;
  battle.tick(0.05);
  assert.equal(battle.contactFor(0, red.uid)?.visible, true);
  red.x = 1200;
  battle.tick(0.05);
  assert.equal(battle.contactFor(0, red.uid)?.visible, false);
  assert.equal(blue.targetUid, red.uid);
});

test("侧弦炮在船舷方向发射多弹齐射", () => {
  const weapons = createWeaponCatalog();
  const fleets = [
    [createShip({ id: "a", hullId: "small", weaponIds: ["broadside"], sensorIds: ["lookout"] })],
    [createShip({ id: "b", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
  ];
  const battle = new BattleSimulation({ fleets, weaponCatalog: weapons });
  const blue = battle.ships[0]; const red = battle.ships[1];
  red.x = blue.x; red.y = blue.y + 120;
  battle._scanContacts();
  battle._fire(blue, battle._chooseTarget(blue));
  assert.equal(battle.projectiles.length, 4);
});

test("炮击可对新鲜的最后已知位置盲射", () => {
  const weapons = createWeaponCatalog();
  const fleets = [
    [createShip({ id: "a", hullId: "medium", weaponIds: ["mortar"], sensorIds: [] })],
    [createShip({ id: "b", hullId: "small", weaponIds: ["deck_gun"], sensorIds: ["lookout"] })],
  ];
  const battle = new BattleSimulation({ fleets, weaponCatalog: weapons });
  const blue = battle.ships[0]; const red = battle.ships[1];
  red.x = blue.x + 250; red.y = blue.y;
  battle._scanContacts();
  red.x = blue.x + 650;
  battle._scanContacts();
  const target = battle._chooseTarget(blue);
  assert.equal(target.visible, false);
  battle._fire(blue, target);
  assert.equal(battle.projectiles[0]?.blindFire, true);
});

test("相同种子与配置产生相同战斗摘要", () => {
  const weapons = createWeaponCatalog();
  const fleets = [
    [createShip({ id: "a", hullId: "medium", weaponIds: ["deck_gun", "mortar"], sensorIds: ["mast"] })],
    [createShip({ id: "b", hullId: "medium", weaponIds: ["deck_gun", "heavy_cannon"], sensorIds: ["mast"] })],
  ];
  const run = () => {
    const battle = new BattleSimulation({ fleets, weaponCatalog: weapons, seed: 77, width: 620, height: 420 });
    for (let index = 0; index < 4000 && battle.state === "engaging"; index += 1) battle.tick(0.05);
    return { winner: battle.winner, summary: battle.summary(), events: battle.events.length };
  };
  assert.deepEqual(run(), run());
});
