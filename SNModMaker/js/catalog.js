/*
 * Steam Navigator Mod Maker - content catalog.
 *
 * Presentation metadata for the content types plus the small DSL vocabularies
 * (condition ops, effect ops, modifier stats). The type list is generated from
 * content_types.json into js/content-types.js; constraints themselves live in
 * the JSON Schemas and are never duplicated here.
 */
(function (root) {
  'use strict';

  const GENERATED = root.SNContentTypes;
  if (!GENERATED || !Array.isArray(GENERATED.TYPES)) {
    throw new Error('SNContentTypes is missing; load js/content-types.js before catalog.js');
  }
  const TYPES = GENERATED.TYPES;
  const BY_KEY = Object.fromEntries(TYPES.map((t) => [t.key, t]));
  const BY_SINGULAR = Object.fromEntries(TYPES.map((t) => [t.singular, t]));
  const GROUPS = [...new Set(TYPES.map((t) => t.group))];

  /* Field labels are shared by all types; type-scoped overrides win. */
  const FIELD_LABELS = {
    id: 'ID',
    name_key: '名称键',
    description_key: '描述键',
    tags: '标签',
    enabled: '启用',
    data: '数据',
    unit_weight: '单位重量',
    base_price: '基准价格',
    base_stock: '基准库存',
    price_elasticity: '价格弹性',
    spawn_weight: '出现权重',
    crafting_material: '可作为打造材料',
    category: '分类',
    tier: '等级',
    weight: '自重',
    purchase_price: '购买价',
    craft_time_hours: '打造工时',
    craft_cost: '打造费用',
    materials: '打造材料',
    modifiers: '属性修正',
    unlock_reputation: '解锁声望',
    icon: '图标资源键',
    speed_mul: '航速倍率',
    coal_rate: '煤耗系数',
    water_rate: '水耗系数',
    base_speed: '基础航速',
    max_weight: '最大载重',
    max_durability: '最大耐久',
    cargo_slots: '货舱槽位',
    cabin_slots: '客舱槽位',
    base_risk: '基础风险',
    size_tag: '船体尺寸',
    capacity: '货舱容量',
    risk_add: '风险修正',
    reveal_facilities: '揭示港口设施',
    damage_mul: '损伤倍率',
    repair_cost_mul: '维修费倍率',
    passenger_capacity: '载客量',
    kind: '类别',
    wage_per_voyage: '每航程工资',
    hire_cost: '雇佣费',
    coal_mul: '煤耗倍率',
    water_mul: '水耗倍率',
    trigger: '触发时机',
    options: '选项',
    base_delay_hours: '基础延误（小时）',
    condition: '条件',
    effects: '效果',
    op: '操作码',
    value: '数值',
    stat: '属性',
    amount: '数量',
    sequence: '主线序号',
    generator: '生成方式',
    constraints: '生成约束',
    payloads: '载货 / 载客需求',
    deadline_formula: '截止时间公式',
    rewards: '奖励',
    requires_completed: '前置委托',
    requires_discovered_origin: '要求已发现起点',
    min_route_edges: '最少航路跳数',
    max_route_edges: '最多航路跳数',
    required_port_tags: '必需港口标签',
    name_key_short: '名称键',
    base_money: '基础报酬',
    on_time_bonus: '准时奖励',
    reputation: '声望',
    unlock_ids: '解锁定义',
    size: '港口规模',
    facilities: '设施',
    market: '商品表',
    good: '商品',
    stock_range: '库存区间',
    price_bias: '价格偏移',
    port_count_range: '港口数量区间',
    edge_count_range: '航路数量区间',
    distance_range: '航路距离区间',
    route_risk_range: '航路风险区间',
    archetypes: '港口原型列表',
    port_name_keys: '港口名称键',
    start_archetype_tags: '起点原型标签',
    required_facility_tags: '必需设施标签',
    required_facility_max_edges: '必需设施最大跳数',
    npc_count_range: 'NPC 商船数量区间',
    npc_cargo_range: 'NPC 载货区间',
    supply_prices: '补给价格',
    coal: '煤炭',
    water: '淡水',
    repair_per_point: '每点维修价',
    loan: '贷款',
    limit: '额度',
    interest_rate: '利率',
    term_hours: '期限（小时）',
    intel_cost: '情报费用',
    trade_margin: '交易利润率',
    player_trade_impact: '玩家交易冲击',
    default_starting_build: '默认初始构筑',
    money: '金钱',
    hull: '船体',
    boiler: '锅炉',
    cargo_modules: '货舱模块',
    navigation_module: '导航模块',
    safety_module: '安全模块',
    passenger_cabin: '客舱',
    engineer: '工程师',
    navigator: '领航员',
    durability_ratio: '耐久比例',
    principal: '本金',
    target: '目标定义',
    requires: '前置来源',
    mod: '模组',
    version: '版本',
    operations: '操作',
    path: 'JSON 指针',
    option_id: '选项 ID',
    weight_range: '重量区间',
    count_range: '数量区间',
    text_key: '文本键',
    port_id: '港口',
    item_id: '物品',
    tag: '标签',
    role_kind: '岗位类别',
    contract_id: '委托',
    is_valid: '有效',
  };

  const TYPE_FIELD_LABELS = {
    'contracts.sequence': '主线序号',
    'events.weight': '出现权重',
    'port_archetypes.size': '港口规模',
    'map_profiles.distance_range': '航路距离区间',
    'map_profiles.supply_prices': '补给价格',
    'starting_builds.money': '初始金钱',
    'starting_builds.reputation': '初始声望',
    'patch.target': '目标定义',
    'patch.operations': '补丁操作',
    'patch.requires': '来源约束',
  };

  const FIELD_HINTS = {
    unit_weight: '每单位占用的载重，必须 > 0。',
    base_price: '新局市场均衡价的基准值。',
    base_stock: '港口初始库存的基准值。',
    price_elasticity: '0–1，越大表示价格对供需越敏感。',
    spawn_weight: '港口商品表中的抽取权重，0 表示不自动出现。',
    tier: '1–3 级。',
    weight: '安装后计入船只总重。',
    purchase_price: '船厂直接购买价格。',
    craft_time_hours: '预留字段：模块打造耗时。',
    craft_cost: '预留字段：模块打造人工费。',
    speed_mul: '与原航速相乘，1.0 为不变。',
    coal_rate: '每航程的基础煤耗系数。',
    water_rate: '每航程的基础水耗系数。',
    base_risk: '0–0.5，航行基础风险。',
    risk_add: '可正可负，直接加到风险上。',
    capacity: '载货容量（重量单位）。',
    deadline_formula: '必须是框架已注册的公式 ID。',
    target: '被修改定义的完整 ID，必须属于其他模组。',
    path: 'JSON Pointer，例如 /data/purchase_price。',
    name_key: '本地化键；建议使用 <类型>.<模组>.<本地ID>.name。',
    description_key: '本地化键；留空则不显示描述。',
    default_starting_build: '引用一个 starting_build 定义。',
    required_facility_tags: '例如 port.shipyard；Core 完整性依赖这些标签。',
  };

  const REF_LABELS = {
    'id_ref': '定义引用',
    'craft_material': '材料引用',
  };

  const DEFAULTS = {
    goods: () => ({
      unit_weight: 1.0,
      base_price: 50,
      base_stock: 80,
      price_elasticity: 0.15,
      spawn_weight: 1.0,
      category: 'trade',
    }),
    materials: () => ({
      tier: 1,
      unit_weight: 2.0,
      base_price: 60,
      base_stock: 60,
      price_elasticity: 0.15,
      category: 'material',
    }),
    hulls: () => ({
      tier: 1,
      weight: 20,
      purchase_price: 1200,
      base_speed: 10,
      max_weight: 120,
      max_durability: 100,
      cargo_slots: 1,
      cabin_slots: 0,
      base_risk: 0.08,
      size_tag: 'small',
    }),
    boilers: () => ({
      tier: 1,
      weight: 8,
      purchase_price: 420,
      speed_mul: 1.0,
      coal_rate: 0.4,
      water_rate: 0.28,
    }),
    cargo_modules: () => ({
      tier: 1,
      weight: 4,
      purchase_price: 300,
      capacity: 32,
    }),
    navigation_modules: () => ({
      tier: 1,
      weight: 2,
      purchase_price: 260,
      risk_add: -0.01,
      speed_mul: 1.0,
      reveal_facilities: false,
    }),
    safety_modules: () => ({
      tier: 1,
      weight: 3,
      purchase_price: 240,
      risk_add: -0.02,
      damage_mul: 0.9,
      repair_cost_mul: 1.0,
    }),
    cabins: () => ({
      tier: 1,
      weight: 5,
      purchase_price: 400,
      passenger_capacity: 2,
    }),
    roles: () => ({
      kind: 'engineer',
      wage_per_voyage: 30,
      hire_cost: 120,
      modifiers: [{ stat: 'speed', op: 'mul', value: 1.02 }],
    }),
    strategies: () => ({
      speed_mul: 1.0,
      coal_mul: 1.0,
      water_mul: 1.0,
      risk_add: 0,
    }),
    port_archetypes: () => ({
      size: 'medium',
      facilities: ['exchange', 'contracts'],
      market: [
        { good: 'core:good/brass', stock_range: [40, 80], price_bias: 1.0 },
        { good: 'core:good/timber', stock_range: [50, 100], price_bias: 1.0 },
      ],
    }),
    map_profiles: () => ({
      port_count_range: [4, 5],
      edge_count_range: [4, 6],
      distance_range: [1, 3],
      route_risk_range: [0.02, 0.12],
      archetypes: [
        'core:port_archetype/iron_harbor',
        'core:port_archetype/spice_port',
        'core:port_archetype/free_town',
        'core:port_archetype/fishing_village',
      ],
      port_name_keys: [
        'port.core.iron_harbor.name',
        'port.core.spice_port.name',
        'port.core.free_town.name',
        'port.core.fishing_village.name',
      ],
      start_archetype_tags: [],
      required_facility_tags: ['port.shipyard'],
      required_facility_max_edges: 2,
      npc_count_range: [2, 3],
      npc_cargo_range: [10, 40],
      supply_prices: { coal: 4, water: 2, repair_per_point: 8 },
      loan: { limit: 800, interest_rate: 0.04, term_hours: 120 },
      intel_cost: 40,
      trade_margin: 0.9,
      player_trade_impact: 0.35,
      default_starting_build: 'core:starting_build/steady',
    }),
    starting_builds: () => ({
      money: 1000,
      reputation: 0,
      hull: 'core:hull/small_efficient',
      boiler: 'core:boiler/small_efficient',
      cargo_modules: ['core:cargo_module/small_hold'],
      coal: 30,
      water: 30,
      durability_ratio: 1.0,
    }),
    contracts: () => ({
      kind: 'normal',
      sequence: 0,
      generator: 'route_pair',
      constraints: {
        requires_discovered_origin: true,
        min_route_edges: 1,
        max_route_edges: 3,
        required_port_tags: [],
      },
      payloads: [{ kind: 'cargo', weight_range: [10, 20], name_key: '' }],
      deadline_formula: 'normal_standard',
      rewards: {
        base_money: [200, 400],
        on_time_bonus: [100, 200],
        reputation: 1,
        unlock_ids: [],
      },
    }),
    events: () => ({
      trigger: 'voyage_risk',
      category: 'mechanical',
      weight: 1.0,
      base_delay_hours: 2,
      options: [
        {
          id: 'endure',
          name_key: '',
          weight: 1.0,
          effects: [{ op: 'damage_ship', amount: 4 }],
        },
        {
          id: 'repair',
          name_key: '',
          weight: 1.0,
          effects: [
            { op: 'remove_money', amount: 60 },
            { op: 'repair_ship', amount: 5 },
          ],
        },
      ],
    }),
    patches: () => null,
  };

  const TAG_SUGGESTIONS = {
    goods: ['good.trade', 'good.bulk', 'good.luxury', 'good.shipbuilding', 'good.supply'],
    hulls: ['module.hull', 'module.small', 'module.medium', 'module.large', 'module.efficient'],
    boilers: ['module.boiler', 'module.economic', 'module.performance'],
    cargo_modules: ['module.cargo', 'module.small', 'module.medium', 'module.large'],
    navigation_modules: ['module.navigation', 'module.intel'],
    safety_modules: ['module.safety', 'module.repair'],
    cabins: ['module.cabin', 'module.passenger'],
    roles: ['role.engineer', 'role.navigator'],
    strategies: ['strategy.economic', 'strategy.standard', 'strategy.fast'],
    contracts: ['contract.main', 'contract.normal', 'contract.cargo', 'contract.passenger'],
    events: ['event.risk', 'event.opportunity', 'event.mechanical', 'event.merchant'],
    port_archetypes: ['port.shipyard', 'port.market', 'port.intel', 'port.start'],
    map_profiles: ['map.standard'],
  };

  const CONDITION_OPS = [
    'money_gte', 'reputation_gte', 'debt_lte', 'at_port', 'port_has_tag', 'has_item',
    'has_module', 'has_module_tag', 'has_role', 'contract_completed', 'port_discovered',
    'ship_tier_gte', 'durability_gte',
  ];

  const CONDITION_FIELDS = {
    money_gte: ['value'],
    reputation_gte: ['value'],
    debt_lte: ['value'],
    at_port: ['port_id'],
    port_has_tag: ['port_id', 'tag'],
    has_item: ['item_id', 'amount'],
    has_module: ['id'],
    has_module_tag: ['tag'],
    has_role: ['role_kind', 'id'],
    contract_completed: ['id'],
    port_discovered: ['port_id'],
    ship_tier_gte: ['value'],
    durability_gte: ['value'],
  };

  const EFFECT_OPS = [
    'add_money', 'remove_money', 'add_reputation', 'remove_reputation', 'add_item',
    'remove_item', 'add_coal', 'remove_coal', 'add_water', 'remove_water', 'damage_ship',
    'repair_ship', 'add_delay_hours', 'damage_cargo', 'injure_passenger',
    'unlock_definition', 'complete_contract', 'fail_voyage', 'reveal_port_facilities',
    'update_intelligence', 'emit_notice',
  ];

  const EFFECT_FIELDS = {
    add_money: ['amount'],
    remove_money: ['amount'],
    add_reputation: ['amount'],
    remove_reputation: ['amount'],
    add_item: ['item_id', 'amount'],
    remove_item: ['item_id', 'amount'],
    add_coal: ['amount'],
    remove_coal: ['amount'],
    add_water: ['amount'],
    remove_water: ['amount'],
    damage_ship: ['amount'],
    repair_ship: ['amount'],
    add_delay_hours: ['amount'],
    damage_cargo: ['amount'],
    injure_passenger: ['amount'],
    unlock_definition: ['id'],
    complete_contract: ['contract_id'],
    fail_voyage: [],
    reveal_port_facilities: ['port_id'],
    update_intelligence: [],
    emit_notice: ['text_key'],
  };

  const MODIFIER_STATS = [
    'speed', 'coal_rate', 'water_rate', 'risk', 'damage', 'repair_cost', 'capacity',
  ];

  const DEADLINE_FORMULAS = [
    'tutorial_first', 'tutorial_trade', 'tutorial_craft', 'passenger_run',
    'balanced_finale', 'normal_standard', 'normal_urgent',
  ];

  const GENERATORS = ['route_pair', 'random_pair'];
  const FACILITIES = [
    { key: 'exchange', label: '交易所' },
    { key: 'contracts', label: '委托站' },
    { key: 'supply', label: '补给站' },
    { key: 'shipyard', label: '造船厂' },
    { key: 'intel', label: '情报站' },
  ];

  const TEMPLATES = [
    {
      key: 'goods',
      name: '商品包',
      description: '一件可交易商品 + 中英文本地化，适合第一次做模组。',
      type: 'goods',
      deps: true,
    },
    {
      key: 'boiler',
      name: '锅炉包',
      description: '一个可购买安装的锅炉，依赖 Core 的商品与飞船体系。',
      type: 'boilers',
      deps: true,
    },
    {
      key: 'event',
      name: '事件包',
      description: '一个双选项航行事件，演示条件、效果与本地化。',
      type: 'events',
      deps: true,
    },
    {
      key: 'starter_kit',
      name: '小型内容合集',
      description: '商品 + 锅炉 + 事件 + 委托，一次看到四种编辑器的配合。',
      type: 'multi',
      deps: true,
    },
    {
      key: 'blank',
      name: '空白模组',
      description: '只创建一个商品占位定义，结构合法、可随时扩展。',
      type: 'goods',
      deps: true,
    },
  ];

  const KEY_PREFIX = Object.fromEntries(TYPES.map((t) => [t.key, t.keyPrefix]));

  root.SNCatalog = {
    TYPES,
    BY_KEY,
    BY_SINGULAR,
    GROUPS,
    FIELD_LABELS,
    TYPE_FIELD_LABELS,
    FIELD_HINTS,
    REF_LABELS,
    DEFAULTS,
    TAG_SUGGESTIONS,
    CONDITION_OPS,
    CONDITION_FIELDS,
    EFFECT_OPS,
    EFFECT_FIELDS,
    MODIFIER_STATS,
    DEADLINE_FORMULAS,
    GENERATORS,
    FACILITIES,
    TEMPLATES,
    KEY_PREFIX,
    typeInfo(key) {
      return BY_KEY[key] || null;
    },
    labelFor(typeKey, field) {
      return TYPE_FIELD_LABELS[`${typeKey}.${field}`] || FIELD_LABELS[field] || field.replace(/_/g, ' ');
    },
    hintFor(typeKey, field) {
      const scoped = TYPE_FIELD_LABELS[`${typeKey}.${field}`];
      return FIELD_HINTS[field] || (scoped ? '' : '');
    },
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
