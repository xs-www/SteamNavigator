// @static-doc
// 作用：维护模拟器舰船装配数据、固定船体派生数值与舰队默认配置，并集中给出非法装配原因。
//
// ## 契约与约束
// - 装配只保存定义引用与调校值，战斗中的位置、耐久和冷却不写回装配。
// - 一艘船可以重复安装同一种武器，但总挂载数不得超过船体武器槽位。
// - 非武器组件暂以装甲、引擎、操舵和货舱调校反映到最终船舶数值。
// - 每艘船保存一份经限幅的声明式战术配置，旧配置自动使用默认战术。
// @end-static-doc

import { HULLS, SENSORS } from "./catalog.mjs";
import { normalizeTactic } from "./tactics.mjs";

let shipSerial = 0;

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, Number(value) || 0));
}

export function createShip(overrides = {}) {
  const id = overrides.id || `ship_${++shipSerial}`;
  return {
    id,
    name: overrides.name || `新舰 ${shipSerial}`,
    hullId: HULLS[overrides.hullId] ? overrides.hullId : "medium",
    role: overrides.role === "cargo" ? "cargo" : "combat",
    weaponIds: Array.isArray(overrides.weaponIds) ? [...overrides.weaponIds] : ["deck_gun"],
    sensorIds: Array.isArray(overrides.sensorIds) ? [...overrides.sensorIds] : ["lookout"],
    tuning: {
      armor: clamp(overrides.tuning?.armor ?? 0, -10, 30),
      engine: clamp(overrides.tuning?.engine ?? 0, -15, 30),
      maneuver: clamp(overrides.tuning?.maneuver ?? 0, -15, 30),
      cargo: clamp(overrides.tuning?.cargo ?? (overrides.role === "cargo" ? 35 : 0), 0, 100),
    },
    cargoValue: clamp(overrides.cargoValue ?? (overrides.role === "cargo" ? 800 : 0), 0, 999999),
    tactic: normalizeTactic(overrides.tactic),
  };
}

export function deriveShipStats(ship, weaponCatalog) {
  const hull = HULLS[ship.hullId] || HULLS.medium;
  const weapons = ship.weaponIds.map((id) => weaponCatalog[id]).filter(Boolean);
  const sensors = ship.sensorIds.map((id) => SENSORS[id]).filter(Boolean);
  const weaponMass = weapons.reduce((sum, weapon) => sum + weapon.mass, 0);
  const sensorMass = sensors.reduce((sum, sensor) => sum + sensor.mass, 0);
  const armorMass = Math.max(0, ship.tuning.armor) * 0.7;
  const engineMass = Math.max(0, ship.tuning.engine) * 0.45;
  const maneuverMass = Math.max(0, ship.tuning.maneuver) * 0.32;
  const cargoMass = ship.tuning.cargo * 0.38;
  const mass = hull.baseMass + weaponMass + sensorMass + armorMass + engineMass + maneuverMass + cargoMass;
  const overload = Math.max(0, mass / hull.massLimit - 1);
  const speed = hull.speed * (1 + ship.tuning.engine / 100) * (1 - Math.min(0.55, overload * 1.6));
  const sensorRange = hull.baseVision + sensors.reduce((sum, sensor) => sum + sensor.rangeBonus, 0);

  return {
    ...hull,
    hullId: hull.id,
    hullMax: hull.hull + ship.tuning.armor * 1.5,
    armor: Math.max(0, hull.armor + ship.tuning.armor),
    speed: Math.max(18, speed),
    acceleration: hull.acceleration * (1 + ship.tuning.engine / 180),
    turnRate: hull.turnRate * (1 + ship.tuning.maneuver / 100),
    rudderResponse: hull.rudderResponse * (1 + ship.tuning.maneuver / 120),
    vision: sensorRange,
    accuracyBonus: sensors.reduce((sum, sensor) => sum + sensor.accuracyBonus, 0),
    cargoCapacity: hull.cargoBase + ship.tuning.cargo,
    mass, overload, weapons, sensors,
  };
}

export function validateShip(ship, weaponCatalog) {
  const errors = [];
  const hull = HULLS[ship.hullId];
  if (!hull) return ["未知船体"];
  if (ship.weaponIds.length > hull.weaponSlots) errors.push(`武器槽超限：${ship.weaponIds.length}/${hull.weaponSlots}`);
  if (ship.sensorIds.length > hull.sensorSlots) errors.push(`视野槽超限：${ship.sensorIds.length}/${hull.sensorSlots}`);
  for (const id of ship.weaponIds) if (!weaponCatalog[id]) errors.push(`未知武器：${id}`);
  for (const id of ship.sensorIds) if (!SENSORS[id]) errors.push(`未知视野组件：${id}`);
  const stats = deriveShipStats(ship, weaponCatalog);
  if (stats.mass > hull.massLimit) errors.push(`超重：${stats.mass.toFixed(1)}/${hull.massLimit}`);
  if (ship.role === "combat" && ship.weaponIds.length === 0) errors.push("战斗舰至少需要一件武器");
  if (ship.role === "cargo" && stats.cargoCapacity <= 0) errors.push("货船需要有效货舱");
  return errors;
}

export function createDefaultFleets() {
  return [
    [
      createShip({ id: "blue_escort", name: "蓝方护航舰", hullId: "medium", weaponIds: ["deck_gun", "heavy_cannon", "broadside"], sensorIds: ["optics"] }),
      createShip({ id: "blue_cargo", name: "蓝方货船", hullId: "large", role: "cargo", weaponIds: ["repeater"], sensorIds: ["mast", "lookout"], tuning: { armor: 4, engine: 0, maneuver: -5, cargo: 70 }, cargoValue: 1600 }),
    ],
    [
      createShip({ id: "red_raider", name: "红方袭击舰", hullId: "small", weaponIds: ["repeater", "deck_gun"], sensorIds: ["lookout"], tuning: { engine: 12, maneuver: 8 } }),
      createShip({ id: "red_bombard", name: "红方炮击舰", hullId: "medium", weaponIds: ["mortar", "heavy_cannon"], sensorIds: ["director"], tuning: { armor: 6 } }),
    ],
  ];
}

export function cloneFleetConfig(fleets) {
  return fleets.map((fleet) => fleet.map((ship) => JSON.parse(JSON.stringify(ship))));
}
