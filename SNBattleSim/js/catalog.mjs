// @static-doc
// 作用：定义战斗模拟器固定的三种船体、内置武器与视野组件，并提供可编辑武器的规范化入口。
//
// ## 契约与约束
// - 船体只有 small / medium / large 三种，用户配置不能创建第四种船体。
// - 武器与视野组件是纯数据；模拟器不按组件 ID 写死行为，行为由 kind 与数值字段决定。
// - 用户武器经 normalizeWeapon 校验与限幅后才进入目录。
// @end-static-doc

export const HULLS = Object.freeze({
  small: Object.freeze({
    id: "small", name: "小型船体", radius: 11, hull: 68, armor: 10,
    speed: 30, acceleration: 3.2, turnRate: 0.30, rudderResponse: 0.18, baseVision: 280,
    weaponSlots: 2, sensorSlots: 1, massLimit: 62, baseMass: 28, cargoBase: 12,
    signature: 0.78,
  }),
  medium: Object.freeze({
    id: "medium", name: "中型船体", radius: 15, hull: 112, armor: 22,
    speed: 24, acceleration: 2.3, turnRate: 0.20, rudderResponse: 0.12, baseVision: 320,
    weaponSlots: 3, sensorSlots: 1, massLimit: 112, baseMass: 54, cargoBase: 34,
    signature: 1,
  }),
  large: Object.freeze({
    id: "large", name: "大型船体", radius: 20, hull: 178, armor: 38,
    speed: 18, acceleration: 1.5, turnRate: 0.13, rudderResponse: 0.07, baseVision: 360,
    weaponSlots: 4, sensorSlots: 2, massLimit: 188, baseMass: 96, cargoBase: 72,
    signature: 1.28,
  }),
});

export const SENSORS = Object.freeze({
  lookout: Object.freeze({ id: "lookout", name: "强化瞭望台", rangeBonus: 85, accuracyBonus: 0.02, mass: 4 }),
  optics: Object.freeze({ id: "optics", name: "测距光学仪", rangeBonus: 55, accuracyBonus: 0.08, mass: 6 }),
  mast: Object.freeze({ id: "mast", name: "高位观测桅", rangeBonus: 145, accuracyBonus: 0, mass: 9 }),
  director: Object.freeze({ id: "director", name: "炮术指挥仪", rangeBonus: 95, accuracyBonus: 0.12, mass: 12 }),
});

export const BUILTIN_WEAPONS = Object.freeze({
  deck_gun: Object.freeze({
    id: "deck_gun", name: "甲板速射炮", kind: "direct", damage: 12, range: 245,
    minRange: 0, cooldown: 1.65, accuracy: 0.72, projectileSpeed: 360,
    splash: 0, mass: 9, arc: 260, salvo: 1, color: "#ffd37a",
  }),
  heavy_cannon: Object.freeze({
    id: "heavy_cannon", name: "重型舰炮", kind: "direct", damage: 30, range: 355,
    minRange: 35, cooldown: 4.2, accuracy: 0.61, projectileSpeed: 285,
    splash: 8, mass: 20, arc: 150, salvo: 1, color: "#ff9a63",
  }),
  mortar: Object.freeze({
    id: "mortar", name: "曲射迫击炮", kind: "artillery", damage: 24, range: 430,
    minRange: 105, cooldown: 5.1, accuracy: 0.58, projectileSpeed: 175,
    splash: 34, mass: 16, arc: 360, salvo: 1, color: "#f3c8ff",
  }),
  repeater: Object.freeze({
    id: "repeater", name: "机关连发炮", kind: "direct", damage: 7, range: 185,
    minRange: 0, cooldown: 0.72, accuracy: 0.76, projectileSpeed: 430,
    splash: 0, mass: 11, arc: 300, salvo: 1, color: "#fff0a4",
  }),
  broadside: Object.freeze({
    id: "broadside", name: "侧弦炮列", kind: "broadside", damage: 8, range: 285,
    minRange: 20, cooldown: 5.4, accuracy: 0.64, projectileSpeed: 330,
    splash: 0, mass: 22, arc: 76, salvo: 4, color: "#ffcf87",
  }),
});

const WEAPON_LIMITS = Object.freeze({
  damage: [1, 120], range: [60, 700], minRange: [0, 400], cooldown: [0.25, 20],
  accuracy: [0.05, 0.98], projectileSpeed: [60, 900], splash: [0, 100],
  mass: [1, 80], arc: [30, 360], salvo: [1, 8],
});

function finiteNumber(value, fallback) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function normalizeWeapon(input, existingIds = []) {
  const source = input ?? {};
  const rawId = String(source.id || source.name || "custom_weapon")
    .trim().toLowerCase().replace(/[^a-z0-9_\-]+/g, "_").replace(/^_+|_+$/g, "");
  if (!rawId) throw new Error("武器 ID 不能为空");
  if (existingIds.includes(rawId)) throw new Error(`武器 ID 已存在：${rawId}`);
  const name = String(source.name || "自定义武器").trim();
  if (!name) throw new Error("武器名称不能为空");

  const kinds = ["direct", "artillery", "broadside"];
  const weapon = { id: rawId, name, kind: kinds.includes(source.kind) ? source.kind : "direct" };
  for (const [field, [min, max]] of Object.entries(WEAPON_LIMITS)) {
    const fallback = field === "accuracy" ? 0.65 : field === "cooldown" ? 2 : field === "arc" ? 180 : field === "salvo" ? 1 : min;
    weapon[field] = clamp(finiteNumber(source[field], fallback), min, max);
  }
  weapon.minRange = Math.min(weapon.minRange, weapon.range - 1);
  weapon.color = /^#[0-9a-f]{6}$/i.test(String(source.color || "")) ? source.color : "#8fe3ff";
  return weapon;
}

export function createWeaponCatalog(customWeapons = []) {
  const result = { ...BUILTIN_WEAPONS };
  for (const value of customWeapons) {
    const weapon = normalizeWeapon(value, Object.keys(result));
    result[weapon.id] = Object.freeze(weapon);
  }
  return result;
}
