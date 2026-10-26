#!/usr/bin/env node
// @static-doc
// 作用：把 Core 内容 JSON（`dev_mods/core/content/*.json`）与中文文案（`dev_mods/core/localization/zh_CN.json`）编译成官网百科数据 `website/assets/data/wiki-data.js`。
//
// ## 契约与约束
// - 只读输入，不修改 `dev_mods/`；输出固定为 `window.SN_WIKI_DATA = { updated, categories, entries }`。
// - `updated` 恒为 `2026-10-24`，不读取系统时间；条目按“分类固定顺序 + 内容定义顺序”输出，同输入必同输出。
// - 11 个分类的 id / label / heading / icon 固定（docs/design/WEBSITE.md §6），顺序固定。
// - 条目字段：`id`（锚点 slug，不展示）、`category`、`title`、`kind`（中文徽标）、`description`、`tags`（中文 1–3）、`stats`（0–4 组 [中文标签, 玩家可读数值]）；`link` 预留但当前不输出。
// - 文案只取 zh_CN 的 `name_key` / `description_key`；`description` 缺失时输出空字符串，绝不用 key 或英文兜底。
// - 禁止展示实现字段：`core:` ID、`schema_version`、`content_type`、`capability`、`*_key`、资产路径；构建末尾有强制扫描。
// - 数值原样展示并补玩家可读单位（金币 / 节 / 人 / 槽 / 小时）；概率与风险增量统一为带符号百分比（`-1.5%` / `+6%`），倍率写 `×1.18`，只改写法、不做单位换算；权重、射程、冷却、距离、危险度等无单位语义的数值保持原样。
// - 内部生成字段（如地点 `weight` 出现权重、`spawn_weight`）不进入玩家可见文案，`validate()` 有回归守卫。
// - 标签从内容 tag slug 翻译成中文，去掉与徽标 / 标题重复的词后截断到 3 个；不照搬英文 slug。
// - `link` 为可选字段；`LINK_BY_CATEGORY` 目前为空（game.html 锚点未冻结），不生成对不存在锚点的链接。
// - 零依赖，只使用 Node 内置模块；`ROOT` 由脚本位置推导，可在仓库根直接 `node website/tools/build-wiki-data.mjs`。
//
// ## 重点逻辑
// ### 数据装配
// - `SOURCE_SPECS` 按内容文件声明徽标与 stats 构造器；`SECTIONS` 决定分类内各来源的先后，保证条目顺序稳定。
// - `REF_NAMES` 把全部定义 id 映射到中文名，用于“投入 / 产出 / 遗物池 / 危险表”等引用字段，避免把 `core:` ID 写进正文。
// - 引用解析不到时该 stats 直接省略（宁缺毋滥），而不是回退成原始 ID。
// ### 文案与回退
// - `textOf(key)` 只返回 zh_CN 的非空字符串；名称缺失时用本地 id 的连字符写法兜底并记录警告（当前数据无缺失）。
// - 描述缺失输出 `''`，由页面决定是否隐藏，避免把 `item.core.x.description` 展示给玩家。
// ### 校验
// - `validate()` 检查 slug 唯一性、tags 数量与中文、stats 上限、禁用字段扫描、内部生成字段与风险百分比守卫；任一失败直接抛错，不写出半成品。
// - 输出前与磁盘内容比较，内容相同则跳过写入，避免并行构建时无意义的时间戳抖动。
// @end-static-doc

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, "..", "..");
const CONTENT_DIR = path.join(ROOT, "dev_mods", "core", "content");
const LOC_PATH = path.join(ROOT, "dev_mods", "core", "localization", "zh_CN.json");
const OUT_PATH = path.join(ROOT, "website", "assets", "data", "wiki-data.js");

const UPDATED = "2026-10-24"; // 固定值：数据快照日期，不随构建时间变化

// ---------------------------------------------------------------------------
// 分类（id / label / heading / icon 由官网设计契约固定）
// ---------------------------------------------------------------------------

const CATEGORIES = [
  { id: "world", label: "世界", heading: "世界与海域", icon: "compass", intro: "五片海域与散落其间的遗迹、残骸和避风锚地，构成了这片群岛的航路网络。" },
  { id: "port", label: "港口", heading: "港口", icon: "anchor", intro: "港口是补给、交易与改装的中转站；设施与市场决定了每座港口能给船队什么。" },
  { id: "goods", label: "商品与贸易", heading: "商品与贸易", icon: "cargo", intro: "商品、补给与材料构成贸易的基本盘；重量、价格与库存共同决定一趟航程的利润。" },
  { id: "ships", label: "船只", heading: "船只与船坞", icon: "hull", intro: "从起步小船的轻便，到大型船体的厚重，船体决定载重、槽位与续航的边界。" },
  { id: "modules", label: "模块与改装", heading: "模块与改装", icon: "boiler", intro: "锅炉、货舱、导航与安全模块决定船只的速度、运力与抗风险能力。" },
  { id: "voyage", label: "航行", heading: "航行与补给", icon: "chart", intro: "补给、锅炉、航道与天气共同塑造一次航程：快一点，还是稳一点。" },
  { id: "combat", label: "战斗", heading: "蒸汽与火炮", icon: "cannon", intro: "蒸汽舰炮、装甲与机动构成海战；交战距离与伤害类型决定谁先沉没。" },
  { id: "fleet", label: "舰队", heading: "舰队与指挥官", icon: "flag", intro: "舰长、阵型与战术把多艘船编成一支舰队，让护航与猎袭各有所长。" },
  { id: "base", label: "基地与生产", heading: "基地与生产", icon: "factory", intro: "在海岸建立前哨，把原料加工成造船与航行所需的材料。" },
  { id: "ruins", label: "遗迹与秘宝", heading: "遗迹与秘宝", icon: "ruin", intro: "半沉的城市、封闭的金库与仍在运转的蒸汽机关，藏着蓝图与遗物。" },
  { id: "glossary", label: "术语", heading: "航海术语", icon: "book", intro: "航行中反复出现的参数与概念，先在这里对齐术语。" },
];

// 分类内各内容来源的先后顺序（决定条目顺序，必须稳定）
const SECTIONS = [
  { category: "world", files: ["regions", "sites"] },
  { category: "port", files: ["port_templates"] },
  { category: "goods", files: ["items", "trade_policies"] },
  { category: "ships", files: ["hulls", "ship_archetypes"] },
  { category: "modules", files: ["modules"] },
  { category: "voyage", files: ["boiler_strategies", "voyage_events", "crew_roles", "route_templates", "weather_profiles"] },
  { category: "combat", files: ["weapons", "damage_types", "enemy_archetypes", "combat_abilities", "encounter_tables"] },
  { category: "fleet", files: ["captains", "formations", "fleet_doctrines"] },
  { category: "base", files: ["base_sites", "buildings", "building_upgrades", "production_recipes", "worker_roles"] },
  { category: "ruins", files: ["ruin_archetypes", "room_templates", "relics", "expedition_events", "hazard_tables"] },
];

// ---------------------------------------------------------------------------
// 中文枚举
// ---------------------------------------------------------------------------

const ZH = {
  // 区域 / 地点
  coastal: "沿海", archipelago: "群岛", open_sea: "外海", industrial: "工业",
  medium: "中型", large: "大型", small: "小型",
  ruin: "遗迹", wreck: "残骸", landmark: "地标", encounter: "遭遇", base_site: "基地点", resource: "资源点",
  // 港口设施
  exchange: "交易所", contracts: "委托", supply: "补给", shipyard: "造船厂", tavern: "酒馆",
  market: "市场", intel: "情报站",
  // 商品分类
  ore: "矿石", metal: "金属", textile: "纺织品", luxury: "奢侈品", wood: "木材", craft: "工艺品",
  contract: "委托货", plate: "钢板", mechanism: "精密机械", compound: "密封耗材",
  // 模块分类
  boiler: "锅炉", cargo: "货舱", utility: "通用设备", cabin: "客舱",
  // 航行
  voyage_risk: "航行风险", voyage_opportunity: "航行机遇", mechanical: "机械故障", merchant: "商人",
  engineer: "工程师", navigator: "领航员",
  sea_lane: "海上航道", trade_route: "贸易航线", hazardous_shortcut: "危险近路",
  temperate: "温带", storm_belt: "风暴带",
  // 战斗
  direct: "直射", artillery: "曲射", broadside: "舷侧齐射",
  Light: "轻型", Medium: "中型", Heavy: "重型", Side: "舷侧",
  none: "无", burn: "燃烧", shock: "电击",
  engage: "交战", evade: "规避", approach: "接近", flank: "侧击",
  weakest: "最弱目标", nearest: "最近目标",
  ignore: "无视", defend: "防守", flee: "逃离",
  patrol: "巡逻", convoy: "护航队",
  // 舰队
  defensive: "防御", aggressive: "激进",
  when_cargo_threatened: "货舱受威胁时", when_damaged: "受损时",
  conservative: "保守",
  // 基地
  production: "生产", storage: "仓储", defense: "防御",
  labor: "体力劳动", smithing: "冶炼", engineering: "工程",
  // 遗迹
  rare: "稀有", legendary: "传说",
  durability: "船体耐久", money: "金钱", cargo_loss: "货物",
};

// 内容 tag slug → 中文标签（只保留能直接对应玩家概念的词；未知 slug 丢弃）
const TAG_ZH = {
  "region.start": "起点", "region.safe": "安全", "region.trade": "商路", "region.wild": "荒野",
  "region.deep": "深水", "region.industry": "工业",
  "site.ruin": "遗迹", "site.wreck": "残骸", "site.landmark": "地标", "site.encounter": "遭遇",
  "site.hostile": "敌对", "site.base": "基地", "site.resource": "资源",
  "port.hub": "枢纽", "port.industrial": "工业港", "port.shipyard": "造船厂", "port.trade": "贸易",
  "port.intel": "情报", "port.rural": "村镇", "port.supply": "补给", "port.craft": "工艺",
  "good.trade": "贸易品", "good.bulk": "大宗货", "good.shipbuilding": "造船材料", "good.consumer": "日用",
  "good.luxury": "奢侈品", "good.fragile": "易碎", "good.contract": "委托", "good.supply": "补给",
  "supply.coal": "燃料", "supply.water": "给水",
  "material.shipbuilding": "造船材料", "material.tier1": "一级材料", "material.tier2": "二级材料",
  "material.tier3": "三级材料",
  "trade_policy.bulk": "大宗", "trade_policy.safe": "稳健", "trade_policy.luxury": "奢侈品", "trade_policy.risky": "高风险",
  "module.hull": "船体", "module.small": "小型", "module.medium": "中型", "module.large": "大型",
  "module.efficient": "效率型", "module.standard": "标准", "module.performance": "性能型",
  "module.boiler": "锅炉", "module.cargo": "货舱", "module.navigation": "导航", "module.safety": "安全",
  "module.cabin": "客舱", "module.passenger": "客运",
  "ship_archetype.fleet": "舰队", "ship_archetype.flagship": "旗舰", "ship_archetype.freight": "货运",
  "ship_archetype.courier": "传令",
  "strategy.economy": "经济", "strategy.slow": "慢速", "strategy.balanced": "均衡",
  "strategy.fast": "极速", "strategy.risky": "高风险",
  "event.risk": "风险事件", "event.mechanical": "机械", "event.opportunity": "机遇", "event.merchant": "商人",
  "role.engineer": "机舱", "role.crew": "船员", "role.navigator": "领航",
  "route.safe": "安全", "route.trade": "贸易", "route.risky": "危险", "route.fast": "快速",
  "weather.temperate": "温和", "weather.storm": "风暴", "weather.hazardous": "危险",
  "weapon.direct": "直射", "weapon.light": "轻型", "weapon.medium": "中型", "weapon.heavy": "重型",
  "weapon.artillery": "曲射", "weapon.broadside": "齐射", "weapon.side": "舷侧炮位",
  "damage.kinetic": "穿甲", "damage.explosive": "破片", "damage.fire": "灼烧", "damage.shock": "震荡",
  "enemy.light": "轻型", "enemy.medium": "中型", "enemy.heavy": "重型", "enemy.pirate": "海盗",
  "enemy.navy": "海军", "enemy.merchant": "商船",
  "ability.aggressive": "激进", "ability.defensive": "防御", "ability.raider": "劫掠", "ability.escort": "护航",
  "encounter.patrol": "巡逻", "encounter.convoy": "护航队", "encounter.ambush": "伏击", "encounter.blockade": "封锁",
  "captain.merchant": "商队", "captain.fleet": "舰队", "captain.raider": "私掠", "captain.scout": "侦察",
  "formation.battle": "战列", "formation.escort": "护航",
  "doctrine.escort": "护航", "doctrine.raider": "猎袭",
  "base.site.coastal": "沿海", "base.site.starter": "起步", "base.site.industrial": "工业",
  "base.site.advanced": "进阶",
  "building.production": "生产", "building.wood": "木材", "building.metal": "金属",
  "building.precision": "精密加工", "building.storage": "仓储", "building.defense": "防御",
  "building_upgrade.production": "产能", "building_upgrade.storage": "仓储", "building_upgrade.defense": "防御",
  "production_recipe.tier1": "一级材料", "production_recipe.tier2": "二级材料",
  "production_recipe.tier3": "三级材料", "production_recipe.shipbuilding": "造船材料",
  "worker_role.labor": "体力", "worker_role.smithing": "冶炼", "worker_role.engineering": "工程",
  "ruin.coastal": "沿海", "ruin.starter": "起步", "ruin.industrial": "工业", "ruin.deep": "深层",
  "room.hall": "大厅", "room.flooded": "积水", "room.gallery": "回廊", "room.collapsed": "坍塌",
  "room.shrine": "神龛", "room.vault": "金库",
  "relic.navigation": "导航", "relic.charting": "制图", "relic.engineering": "工程",
  "relic.rare": "稀有", "relic.legendary": "传说",
  "expedition_event.hazard": "风险", "expedition_event.reward": "收益",
  "hazard_table.minor": "轻微", "hazard_table.major": "严重",
};

// 修正值与效果的语义标签（modifiers / bonuses 共用）
const STAT_ZH = {
  risk: "风险", repair_cost: "维修费", damage: "伤害", speed: "航速", navigation: "导航",
  gunnery: "炮术", engineering: "工程", leadership: "领导", charting: "制图", upkeep: "维护费",
  production_speed: "生产速度", storage_capacity: "仓储", defense: "防御",
};

// 远征事件 effect.op → 后果描述
const EFFECT_ZH = {
  damage_ship: "受伤", damage_module: "模块受损", damage_cargo: "货物损失",
  remove_money: "花钱", add_money: "金钱收益", add_item: "物品收益",
  remove_water: "消耗淡水", add_delay_hours: "耽误航时", repair_ship: "修复船体",
  update_intelligence: "获得情报",
};

// ---------------------------------------------------------------------------
// 基础工具
// ---------------------------------------------------------------------------

const warnings = [];
const refNames = new Map();
let LOC = {};

function readJson(file) {
  const raw = fs.readFileSync(file, "utf8").replace(/^\uFEFF/, "");
  return JSON.parse(raw);
}

function textOf(key) {
  if (!key || typeof key !== "string") return "";
  const value = LOC[key];
  return typeof value === "string" ? value.trim() : "";
}

function refName(id) {
  return refNames.get(id) || "";
}

function refList(ids) {
  return (Array.isArray(ids) ? ids : []).map(refName).filter(Boolean).join("、");
}

function num(value) {
  return Number.isFinite(value) ? String(value) : "";
}

function signed(value) {
  if (!Number.isFinite(value)) return "";
  return value > 0 ? `+${value}` : String(value);
}

// 0–1 比率 → 百分比；只改变写法，不改变语义（概率类不加 "+"，负值保留符号）
function pct(value) {
  if (!Number.isFinite(value)) return "";
  return `${Math.round(value * 1000) / 10}%`;
}

// 概率 / 风险“增量” → 带符号百分比；-0.015 → "-1.5%"，0.06 → "+6%"，0 → "0%"
function signedPct(value) {
  if (!Number.isFinite(value)) return "";
  const rounded = Math.round(value * 1000) / 10;
  return `${rounded > 0 ? "+" : ""}${rounded}%`;
}

function mul(value) {
  return Number.isFinite(value) ? `×${value}` : "";
}

// 阈值分档：pairs 为 [[上界, 文案], ...]，取第一个 v < 上界
function band(value, pairs) {
  if (!Number.isFinite(value)) return "";
  for (const [limit, label] of pairs) if (value < limit) return label;
  return "";
}

function roman(n) {
  return { 1: "I", 2: "II", 3: "III", 4: "IV", 5: "V" }[n] || String(n);
}

// 只保留有效 [标签, 数值] 组，空值直接丢弃（宁缺毋滥）
function pairs(...items) {
  const out = [];
  for (const item of items) {
    if (!item) continue;
    const [label, value] = item;
    if (!label || value === "" || value === null || value === undefined) continue;
    out.push([label, String(value)]);
  }
  return out.slice(0, 4);
}

function zh(key) {
  return ZH[key] || "";
}

// 引用字段 → "名称 数量" 形式
function itemCounts(list, keyName, amountKey) {
  return (Array.isArray(list) ? list : [])
    .map((entry) => {
      const name = refName(entry[keyName]);
      return name ? `${name} ${num(entry[amountKey])}` : "";
    })
    .filter(Boolean)
    .join("、");
}

// modifiers / bonuses → "风险 -1.5%、维修费 ×0.85"
// stat 含 risk 的加法项是概率增量，必须用百分比；其余加法项（技能 +2、仓储 +600 等）保持原值。
function modifierText(list) {
  return (Array.isArray(list) ? list : [])
    .map((mod) => {
      const label = STAT_ZH[mod.stat];
      if (!label) return "";
      if (mod.op === "mul") return `${label} ${mul(mod.value)}`;
      if (mod.op === "add") {
        const isRisk = String(mod.stat).includes("risk");
        return `${label} ${isRisk ? signedPct(mod.value) : signed(mod.value)}`;
      }
      return "";
    })
    .filter(Boolean)
    .join("、");
}

// ---------------------------------------------------------------------------
// 各内容来源的条目构造（徽标 + stats）；文本、标签与 id 由通用管线生成
// ---------------------------------------------------------------------------

const SOURCE_SPECS = {
  regions: {
    kind: "海域",
    stats: (d) => pairs(
      ["地形", zh(d.data.kind)],
      ["规模", zh(d.data.size)],
      ["气候", refName(d.data.weather_profile)],
      ["敌对程度", band(d.data.hostile_density, [[0.15, "低"], [0.3, "中"], [Infinity, "高"]])],
    ),
  },
  sites: {
    kind: "海上地点",
    stats: (d) => pairs(
      ["地点类型", zh(d.data.site_kind)],
      ["出现海域", (d.data.region_kinds || []).map(zh).filter(Boolean).join("、")],
      ["可重复", d.data.repeatable ? "是" : "否"],
    ),
  },
  port_templates: {
    kind: "港口",
    stats: (d) => pairs(
      ["规模", zh(d.data.size)],
      ["设施", (d.data.facilities || []).map(zh).filter(Boolean).join("、")],
      ["市场", Number.isFinite(d.data.market?.length) ? `${d.data.market.length} 种商品` : ""],
    ),
  },
  items: {
    // 物品徽标按内容分类细化：补给 / 委托货 / 材料 / 普通商品
    kind: (d) => (d.data.category === "supply" ? "补给" : d.data.category === "contract" ? "委托货" : d.data.crafting_material ? "材料" : "商品"),
    stats: (d) => pairs(
      ["类别", zh(d.data.category)],
      ["重量", num(d.data.unit_weight)],
      ["基准价", Number.isFinite(d.data.base_price) ? `${d.data.base_price} 金币` : ""],
      ["等级", d.data.tier ? roman(d.data.tier) : ""],
    ),
  },
  trade_policies: {
    kind: "贸易策略",
    stats: (d) => pairs(
      ["预算", Number.isFinite(d.data.budget) ? `${d.data.budget} 金币` : ""],
      ["预留资金", Number.isFinite(d.data.reserve_money) ? `${d.data.reserve_money} 金币` : ""],
      ["载货上限", num(d.data.max_cargo)],
      ["最短利润", pct(d.data.min_margin)],
    ),
  },
  hulls: {
    kind: "船体",
    stats: (d) => pairs(
      ["重量", num(d.data.weight)],
      ["售价", Number.isFinite(d.data.purchase_price) ? `${d.data.purchase_price} 金币` : ""],
      ["航速", Number.isFinite(d.data.base_speed) ? `${d.data.base_speed} 节` : ""],
      ["货舱槽", num(d.data.cargo_slots)],
    ),
  },
  ship_archetypes: {
    kind: "舰队船型",
    stats: (d) => pairs(
      ["船员", Number.isFinite(d.data.crew_capacity) ? `${d.data.crew_capacity} 人` : ""],
      ["载货", num(d.data.cargo_capacity)],
      ["航速", Number.isFinite(d.data.base_speed) ? `${d.data.base_speed} 节` : ""],
      ["维护", Number.isFinite(d.data.upkeep) ? `${d.data.upkeep} 金币` : ""],
    ),
  },
  modules: {
    kind: "模块",
    stats: (d) => {
      const effects = [];
      if (Number.isFinite(d.data.speed_mul) && d.data.speed_mul !== 1) effects.push(`航速 ${mul(d.data.speed_mul)}`);
      if (Number.isFinite(d.data.capacity)) effects.push(`容量 ${d.data.capacity}`);
      if (Number.isFinite(d.data.passenger_capacity)) effects.push(`载客 ${d.data.passenger_capacity} 人`);
      if (d.data.reveal_facilities) effects.push("揭示目的港设施");
      if (Number.isFinite(d.data.risk_add) && d.data.risk_add !== 0) effects.push(`风险 ${signedPct(d.data.risk_add)}`);
      if (Number.isFinite(d.data.damage_mul) && d.data.damage_mul !== 1) effects.push(`损伤 ${mul(d.data.damage_mul)}`);
      if (Number.isFinite(d.data.repair_cost_mul) && d.data.repair_cost_mul !== 1) effects.push(`维修费 ${mul(d.data.repair_cost_mul)}`);
      return pairs(
        ["类别", zh(d.data.v2_category)],
        ["等级", d.data.tier ? roman(d.data.tier) : ""],
        ["价格", Number.isFinite(d.data.purchase_price) ? `${d.data.purchase_price} 金币` : ""],
        ["关键效果", effects.join("、")],
      );
    },
  },
  boiler_strategies: {
    kind: "锅炉策略",
    // 只展示偏离基准的项；"标准"三档均为 ×1，改为一句定位说明
    stats: (d) => {
      const rows = [];
      if (Number.isFinite(d.data.speed_mul) && d.data.speed_mul !== 1) rows.push(["航速", mul(d.data.speed_mul)]);
      if (Number.isFinite(d.data.coal_mul) && d.data.coal_mul !== 1) rows.push(["煤耗", mul(d.data.coal_mul)]);
      if (Number.isFinite(d.data.water_mul) && d.data.water_mul !== 1) rows.push(["水耗", mul(d.data.water_mul)]);
      if (Number.isFinite(d.data.risk_add) && d.data.risk_add !== 0) rows.push(["风险", signedPct(d.data.risk_add)]);
      return rows.length ? pairs(...rows) : pairs(["定位", "基准值"]);
    },
  },
  voyage_events: {
    kind: "航行事件",
    stats: (d) => pairs(
      ["触发", zh(d.data.trigger)],
      ["类别", zh(d.data.category)],
      ["选项", Number.isFinite(d.data.options?.length) ? `${d.data.options.length} 个` : ""],
    ),
  },
  crew_roles: {
    kind: "船员岗位",
    stats: (d) => pairs(
      ["岗位", zh(d.data.kind)],
      ["出航工资", Number.isFinite(d.data.wage_per_voyage) ? `${d.data.wage_per_voyage} 金币` : ""],
      ["雇佣费", Number.isFinite(d.data.hire_cost) ? `${d.data.hire_cost} 金币` : ""],
      ["效果", modifierText(d.data.modifiers)],
    ),
  },
  route_templates: {
    kind: "航道",
    stats: (d) => {
      const [d0, d1] = d.data.distance_range || [];
      const [t0, t1] = d.data.travel_time_range || [];
      const [r0, r1] = d.data.risk_range || [];
      return pairs(
        ["类型", zh(d.data.kind)],
        ["距离", Number.isFinite(d0) && Number.isFinite(d1) ? `${d0}–${d1}` : ""],
        ["航行时间", Number.isFinite(t0) && Number.isFinite(t1) ? `${t0}–${t1} 小时` : ""],
        ["风险", Number.isFinite(r0) && Number.isFinite(r1) ? `${pct(r0)}–${pct(r1)}` : ""],
      );
    },
  },
  weather_profiles: {
    kind: "气候",
    stats: (d) => pairs(
      ["气候", zh(d.data.climate)],
      ["起雾概率", pct(d.data.fog_chance)],
      ["风暴概率", pct(d.data.storm_chance)],
      ["航速影响", pct(d.data.speed_modifier)],
    ),
  },
  weapons: {
    kind: "武器",
    stats: (d) => pairs(
      ["伤害", num(d.data.damage)],
      ["射程", num(d.data.range)],
      ["冷却", num(d.data.cooldown)],
      ["伤害类型", refName(d.data.damage_type)],
    ),
  },
  damage_types: {
    kind: "伤害类型",
    stats: (d) => pairs(
      ["装甲穿透", pct(d.data.armor_pierce)],
      ["附加状态", zh(d.data.status_effect)],
    ),
  },
  enemy_archetypes: {
    kind: "敌舰",
    stats: (d) => pairs(
      ["舰级", zh(d.data.enemy_class)],
      ["船体耐久", num(d.data.hull_points)],
      ["装甲", pct(d.data.armor)],
      ["最高航速", Number.isFinite(d.data.max_speed) ? `${d.data.max_speed} 节` : ""],
    ),
  },
  combat_abilities: {
    kind: "战斗能力",
    stats: (d) => pairs(
      ["交战动作", zh(d.data.action)],
      ["目标优先", zh(d.data.target_priority)],
      ["交战航速", mul(d.data.engage_speed)],
      ["撤退耐久", pct(d.data.retreat_hull)],
    ),
  },
  encounter_tables: {
    kind: "遭遇表",
    stats: (d) => {
      const composition = (Array.isArray(d.data.entries) ? d.data.entries : [])
        .map((entry) => {
          const name = refName(entry.enemy_archetype);
          const [c0, c1] = entry.count_range || [];
          if (!name) return "";
          if (Number.isFinite(c0) && Number.isFinite(c1) && c0 !== c1) return `${name} ×${c0}–${c1}`;
          return Number.isFinite(c0) ? `${name} ×${c0}` : name;
        })
        .filter(Boolean)
        .join("、");
      return pairs(
        ["类型", zh(d.data.kind)],
        ["危险度", num(d.data.danger)],
        ["编成", composition],
      );
    },
  },
  captains: {
    kind: "舰长",
    stats: (d) => {
      const skills = d.data.skills || {};
      return pairs(
        ["导航", num(skills.navigation)],
        ["炮术", num(skills.gunnery)],
        ["工程", num(skills.engineering)],
        ["领导", num(skills.leadership)],
      );
    },
  },
  formations: {
    kind: "阵型",
    stats: (d) => pairs(
      ["最大舰数", num(d.data.max_ships)],
      ["阵位", Number.isFinite(d.data.slots?.length) ? `${d.data.slots.length} 个` : ""],
      ["增益", modifierText(d.data.bonuses)],
    ),
  },
  fleet_doctrines: {
    kind: "战术",
    stats: (d) => pairs(
      ["交战", zh(d.data.engagement)],
      ["撤退", zh(d.data.retreat)],
      ["护航", zh(d.data.escort)],
      ["目标优先", zh(d.data.target_priority)],
    ),
  },
  base_sites: {
    kind: "基地点",
    stats: (d) => pairs(
      ["建筑槽", num(d.data.slot_count)],
      ["仓储", num(d.data.storage_capacity)],
      ["防御", num(d.data.defense)],
      ["声索费用", Number.isFinite(d.data.claim_cost_money) ? `${d.data.claim_cost_money} 金币` : ""],
    ),
  },
  buildings: {
    kind: "建筑",
    stats: (d) => pairs(
      ["类别", zh(d.data.category)],
      ["建造费用", Number.isFinite(d.data.build_cost_money) ? `${d.data.build_cost_money} 金币` : ""],
      ["建造耗时", Number.isFinite(d.data.build_time_hours) ? `${d.data.build_time_hours} 小时` : ""],
      ["工位", Number.isFinite(d.data.worker_slots) ? `${d.data.worker_slots} 个` : ""],
    ),
  },
  building_upgrades: {
    kind: "升级",
    stats: (d) => {
      const target = refName(d.data.building_ref);
      return pairs(
        ["升级目标", target && Number.isFinite(d.data.to_level) ? `${target} ${roman(d.data.to_level)}` : ""],
        ["费用", Number.isFinite(d.data.cost_money) ? `${d.data.cost_money} 金币` : ""],
        ["耗时", Number.isFinite(d.data.time_hours) ? `${d.data.time_hours} 小时` : ""],
        ["增益", modifierText(d.data.modifiers)],
      );
    },
  },
  production_recipes: {
    kind: "配方",
    stats: (d) => pairs(
      ["建筑", refName(d.data.building_ref)],
      ["投入", itemCounts(d.data.inputs, "item", "amount")],
      ["产出", itemCounts(d.data.outputs, "item", "amount")],
      ["耗时", Number.isFinite(d.data.duration_hours) ? `${d.data.duration_hours} 小时` : ""],
    ),
  },
  worker_roles: {
    kind: "工人工种",
    stats: (d) => pairs(
      ["技能", zh(d.data.skill)],
      ["每周期工资", Number.isFinite(d.data.wage_per_tick) ? `${d.data.wage_per_tick} 金币` : ""],
      ["雇佣费", Number.isFinite(d.data.hire_cost_money) ? `${d.data.hire_cost_money} 金币` : ""],
      ["速度加成", pct(d.data.speed_bonus)],
    ),
  },
  ruin_archetypes: {
    kind: "遗迹",
    stats: (d) => pairs(
      ["难度", num(d.data.difficulty)],
      ["房间数", num(d.data.room_count)],
      ["危险表", refName(d.data.hazard_table)],
      ["遗物池", refList(d.data.relic_pool)],
    ),
  },
  room_templates: {
    kind: "房间",
    stats: (d) => pairs(
      ["规模", zh(d.data.size)],
      ["出口", Number.isFinite(d.data.exits) ? `${d.data.exits} 个` : ""],
      ["危险表", refName(d.data.hazard_table)],
      ["关联事件", refName(d.data.event_ref)],
    ),
  },
  relics: {
    kind: "遗物",
    stats: (d) => pairs(
      ["稀有度", zh(d.data.rarity)],
      ["估值", Number.isFinite(d.data.value) ? `${d.data.value} 金币` : ""],
      ["效果", modifierText(d.data.modifiers)],
    ),
  },
  expedition_events: {
    kind: "远征事件",
    stats: (d) => {
      const outcomes = [];
      for (const option of Array.isArray(d.data.options) ? d.data.options : []) {
        const label = EFFECT_ZH[option?.effect?.op];
        if (label && !outcomes.includes(label)) outcomes.push(label);
      }
      return pairs(
        ["选项", Number.isFinite(d.data.options?.length) ? `${d.data.options.length} 个` : ""],
        ["可能后果", outcomes.join("、")],
      );
    },
  },
  hazard_tables: {
    kind: "危险表",
    stats: (d) => {
      const consequences = [];
      for (const entry of Array.isArray(d.data.entries) ? d.data.entries : []) {
        const label = { durability: "船体耐久", money: "金钱", cargo: "货物" }[entry?.type];
        if (label && !consequences.includes(label)) consequences.push(label);
      }
      return pairs(
        ["条目", Number.isFinite(d.data.entries?.length) ? `${d.data.entries.length} 条` : ""],
        ["可能损失", consequences.join("、")],
      );
    },
  },
};

// ---------------------------------------------------------------------------
// 术语表（手写；10–12 条，覆盖 docs/design/WEBSITE.md §6 列出的概念）
// ---------------------------------------------------------------------------

const GLOSSARY = [
  { id: "glossary-load", title: "载重", description: "船只当前承载的总重量，由货物、模块与船员累加而成；接近船体载重上限时，航线风险会上升。", tags: ["船只", "风险"] },
  { id: "glossary-cargo-hold", title: "货舱", description: "装载货物的舱位，容量由装配的货舱模块决定；每个货舱槽只能安装一个货舱模块。", tags: ["船只", "货物"] },
  { id: "glossary-durability", title: "耐久", description: "船体结构的完整度。受损后需要在港口修理，耐久偏低会增加航程风险。", tags: ["船只", "维修"] },
  { id: "glossary-boiler-strategy", title: "锅炉策略", description: "出航前设定的三档锅炉工况：经济、标准、极速，在航速与煤水消耗之间取舍。", tags: ["航行", "补给"] },
  { id: "glossary-risk", title: "风险", description: "一次航程发生事故的可能性，受航线、载重、耐久、船员与天气共同影响，在抵达时结算。", tags: ["航行", "概率"] },
  { id: "glossary-reputation", title: "声望", description: "船队与各阵营势力分别累计的信誉。声望越高，该势力的态度越友好，能同时接取的委托也越多。", tags: ["势力", "信誉"] },
  { id: "glossary-clue", title: "线索", description: "酒馆里买到的搜索方向，会在海图上圈出目标区域；循线索出航，才能找到遗迹与秘境。", tags: ["探索", "海图"] },
  { id: "glossary-fog", title: "迷雾", description: "海图上尚未探明的区域，船只靠近才会逐步揭开；迷雾中的港口与地点需要亲自抵达或循线索发现。", tags: ["探索", "海图"] },
  { id: "glossary-time", title: "时间", description: "航行、生产与委托期限都以小时推进；补给、修理和货物加工都会占用时间。", tags: ["航行", "生产"] },
  { id: "glossary-slot", title: "槽位", description: "船体上按类型划分的安装位：锅炉、货舱、导航、安全、客舱；同槽位的设备可以直接替换。", tags: ["船只", "改装"] },
  { id: "glossary-contract", title: "委托", description: "港口发布的运输与载客任务，完成后获得报酬；随船的委托货箱不能自由买卖或抛弃。", tags: ["贸易", "任务"] },
  { id: "glossary-fleet", title: "舰队", description: "由多艘船组成的编队，由舰长指挥，可设定阵型与战术，并统一分配护航与猎袭的目标。", tags: ["编队", "战斗"] },
];

// 站内相关页（`link` 为可选字段）：官网子页与其锚点由 Lead 维护，未冻结前保持为空，
// 避免生成对不存在的 `game.html#xxx` 锚点。确定后在这里按分类登记，例如 { world: "game.html#world" }。
const LINK_BY_CATEGORY = {};

// ---------------------------------------------------------------------------
// 装配
// ---------------------------------------------------------------------------

function slugFor(definitionId, fallbackType) {
  const local = definitionId.includes(":") ? definitionId.slice(definitionId.indexOf(":") + 1) : definitionId;
  const slash = local.indexOf("/");
  const type = slash >= 0 ? local.slice(0, slash) : fallbackType;
  const name = slash >= 0 ? local.slice(slash + 1) : local;
  const slug = `${type}-${name}`.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
  return slug || fallbackType;
}

function tagsFor(definition, kind, title) {
  const tags = [];
  for (const slug of Array.isArray(definition.tags) ? definition.tags : []) {
    const label = TAG_ZH[slug];
    // 与徽标或标题重复的标签没有信息量，直接丢弃（宁缺毋滥）
    if (!label || label === kind || label === title || tags.includes(label)) continue;
    tags.push(label);
    if (tags.length === 3) break;
  }
  if (!tags.length) tags.push(kind);
  return tags.slice(0, 3);
}

function titleFor(definition, type, local) {
  const title = textOf(definition.name_key);
  if (title) return title;
  warnings.push(`${definition.id}：缺少中文名称（name_key=${definition.name_key || "无"}）`);
  return local.replace(/[_-]+/g, " ").trim() || type;
}

function descriptionFor(definition) {
  return textOf(definition.description_key);
}

function loadInputs() {
  LOC = readJson(LOC_PATH);
  const data = new Map();
  const allFiles = new Set(SECTIONS.flatMap((section) => section.files));
  for (const file of allFiles) {
    const parsed = readJson(path.join(CONTENT_DIR, `${file}.json`));
    if (!Array.isArray(parsed.definitions)) throw new Error(`${file}.json 缺少 definitions 数组`);
    data.set(file, parsed.definitions);
  }
  for (const definitions of data.values()) {
    for (const definition of definitions) {
      const name = textOf(definition.name_key);
      if (definition.id && name) refNames.set(definition.id, name);
    }
  }
  return data;
}

function buildEntries(data) {
  const entries = [];
  const countByCategory = new Map();
  for (const section of SECTIONS) {
    const bucket = [];
    for (const file of section.files) {
      const spec = SOURCE_SPECS[file];
      if (!spec) throw new Error(`SOURCE_SPECS 缺少 ${file} 的配置`);
      for (const definition of data.get(file)) {
        if (definition.enabled === false) continue; // 未启用的定义不进入玩家可见百科
        const local = definition.id.includes("/") ? definition.id.slice(definition.id.indexOf("/") + 1) : definition.id;
        const kind = typeof spec.kind === "function" ? spec.kind(definition) : spec.kind;
        const title = titleFor(definition, kind, local);
        const entry = {
          id: slugFor(definition.id, file.replace(/s$/, "")),
          category: section.category,
          title,
          kind,
          description: descriptionFor(definition),
          tags: tagsFor(definition, kind, title),
          stats: pairs(...(spec.stats(definition) || [])),
        };
        if (LINK_BY_CATEGORY[section.category]) entry.link = LINK_BY_CATEGORY[section.category];
        bucket.push(entry);
      }
    }
    countByCategory.set(section.category, bucket.length);
    entries.push(...bucket);
  }
  for (const term of GLOSSARY) {
    const entry = {
      id: term.id,
      category: "glossary",
      title: term.title,
      kind: "术语",
      description: term.description,
      tags: term.tags.slice(0, 3),
      stats: [],
    };
    if (LINK_BY_CATEGORY.glossary) entry.link = LINK_BY_CATEGORY.glossary;
    entries.push(entry);
  }
  countByCategory.set("glossary", GLOSSARY.length);
  return { entries, countByCategory };
}

// ---------------------------------------------------------------------------
// 校验：任何一条失败都抛错，避免写出会把实现字段泄漏给玩家的文件
// ---------------------------------------------------------------------------

const SLUG_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const FORBIDDEN = ["core:", "schema_version", "content_type", "capability", "_key", "asset://", "dev_mods", "model.", "banner."];
// 内部生成字段：出现过就说明把生成概率之类的实现参数泄露给玩家了
const INTERNAL_LABELS = ["出现权重", "生成权重", "spawn_weight", "price_elasticity"];
// 风险 / 概率必须是百分比；原始小数（-0.015 / 0.012）不可读
const RAW_RISK_RE = /风险\s*[-+]?\d*\.\d+(?![%\d])/;
const CJK_RE = /[\u4e00-\u9fff]/;

function validate(entries) {
  const ids = new Set();
  const categoryIds = new Set(CATEGORIES.map((category) => category.id));
  for (const entry of entries) {
    const where = `条目 ${entry.id}`;
    if (!SLUG_RE.test(entry.id)) throw new Error(`${where}：id 不是稳定 slug`);
    if (ids.has(entry.id)) throw new Error(`${where}：id 重复`);
    ids.add(entry.id);
    if (!categoryIds.has(entry.category)) throw new Error(`${where}：未知分类 ${entry.category}`);
    if (!entry.title) throw new Error(`${where}：缺 title`);
    if (!entry.kind || !CJK_RE.test(entry.kind)) throw new Error(`${where}：kind 必须是中文徽标`);
    if (entry.tags.length < 1 || entry.tags.length > 3) throw new Error(`${where}：tags 必须为 1–3 个`);
    for (const tag of entry.tags) {
      if (!CJK_RE.test(tag)) throw new Error(`${where}：标签 "${tag}" 不是中文`);
      if (/[.]/.test(tag)) throw new Error(`${where}：标签 "${tag}" 疑似英文 slug`);
    }
    if (entry.stats.length > 4) throw new Error(`${where}：stats 超过 4 组`);
    if (entry.link !== undefined && !/^[a-z0-9-]+\.html(#[a-z0-9-]+)?$/.test(entry.link)) {
      throw new Error(`${where}：link 必须是站内 html 相对路径：${entry.link}`);
    }
    for (const [label, value] of entry.stats) {
      if (!label || !CJK_RE.test(label)) throw new Error(`${where}：stats 标签必须是中文`);
      if (value === "" || value === "undefined" || value === "NaN") throw new Error(`${where}：stats 数值无效`);
      if (INTERNAL_LABELS.some((internal) => label.includes(internal))) {
        throw new Error(`${where}：stats 不应展示内部生成字段「${label}」`);
      }
      if (label === "风险" && !String(value).includes("%")) {
        throw new Error(`${where}：风险必须用百分比展示：${label} ${value}`);
      }
    }
    const visible = [entry.title, entry.kind, entry.description, ...entry.tags, ...entry.stats.flat()];
    for (const text of visible) {
      for (const bad of FORBIDDEN) {
        if (String(text).includes(bad)) throw new Error(`${where}：可见文本出现实现字段 "${bad}"：${text}`);
      }
      if (INTERNAL_LABELS.some((internal) => String(text).includes(internal))) {
        throw new Error(`${where}：可见文本出现内部生成字段：${text}`);
      }
      if (RAW_RISK_RE.test(String(text))) throw new Error(`${where}：风险增量必须用百分比：${text}`);
    }
  }
  return ids;
}

function buildDocument(entries) {
  return {
    updated: UPDATED,
    categories: CATEGORIES.map((category) => ({ ...category })),
    entries,
  };
}

function serialize(document) {
  // 首行声明生成来源：该文件是构建产物，页面只读、人手不改
  return `// 由 website/tools/build-wiki-data.mjs 从 dev_mods/core 内容生成，请勿手工编辑。\n` +
    `window.SN_WIKI_DATA = ${JSON.stringify(document, null, 2)};\n`;
}

// ---------------------------------------------------------------------------
// 输出与报告
// ---------------------------------------------------------------------------

function report(document, countByCategory, file, written) {
  const bytes = Buffer.byteLength(serialize(document), "utf8");
  const lines = [];
  lines.push("== wiki-data 构建完成 ==");
  lines.push(`分类计数: ${CATEGORIES.map((c) => `${c.id}=${countByCategory.get(c.id) || 0}`).join(" ")}`);
  lines.push(`总条目: ${document.entries.length}`);
  const missing = document.entries.filter((entry) => !entry.description).map((entry) => entry.id);
  lines.push(`缺失 description: ${missing.length ? missing.join(", ") : "无"}`);
  if (warnings.length) lines.push(`警告: ${warnings.join("；")}`);
  lines.push(`输出: ${path.relative(ROOT, file).replace(/\\/g, "/")} (${bytes} B, ${written ? "已写入" : "内容未变化"})`);
  console.log(lines.join("\n"));
  return missing;
}

function main() {
  const data = loadInputs();
  const { entries, countByCategory } = buildEntries(data);
  validate(entries);
  const document = buildDocument(entries);
  const content = serialize(document);
  fs.mkdirSync(path.dirname(OUT_PATH), { recursive: true });
  const previous = fs.existsSync(OUT_PATH) ? fs.readFileSync(OUT_PATH, "utf8") : null;
  const written = previous !== content;
  if (written) fs.writeFileSync(OUT_PATH, content, "utf8");
  report(document, countByCategory, OUT_PATH, written);
}

main();
