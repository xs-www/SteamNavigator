// @static-doc
// 作用：覆盖三种固定船体、多武器装配、货船派生值、视野发现、自定义武器校验和确定性战斗结果。
// @end-static-doc

import test from "node:test";
import assert from "node:assert/strict";
import { HULLS, createWeaponCatalog, normalizeWeapon } from "../js/catalog.mjs";
import { createShip, deriveShipStats, validateShip } from "../js/loadout.mjs";
import { BattleSimulation } from "../js/simulation.mjs";
import { cameraTarget, worldToScreen } from "../js/camera.mjs";
import { rangeShapes } from "../js/range_overlay.mjs";
import { mountReloadState } from "../js/combat_hud.mjs";
import { normalizeTactic, tacticalDecision, tacticalState } from "../js/tactics.mjs";

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
  assert.equal(tacticalState({ ...base, hasTarget: false }), "search");
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
  assert.equal(entered.reason, "耐久首次跌破阈值");
  assert.equal(tacticalDecision({ ...base, targetDistance: 270, previousState: "withdraw", previousReason: entered.reason }).state, "withdraw");
  assert.equal(tacticalDecision({ ...base, targetDistance: 300, previousState: "withdraw", previousReason: entered.reason }).state, "engage");
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
