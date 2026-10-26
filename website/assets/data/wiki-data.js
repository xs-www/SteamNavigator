// 由 website/tools/build-wiki-data.mjs 从 dev_mods/core 内容生成，请勿手工编辑。
window.SN_WIKI_DATA = {
  "updated": "2026-10-24",
  "categories": [
    {
      "id": "world",
      "label": "世界",
      "heading": "世界与海域",
      "icon": "compass",
      "intro": "五片海域与散落其间的遗迹、残骸和避风锚地，构成了这片群岛的航路网络。"
    },
    {
      "id": "port",
      "label": "港口",
      "heading": "港口",
      "icon": "anchor",
      "intro": "港口是补给、交易与改装的中转站；设施与市场决定了每座港口能给船队什么。"
    },
    {
      "id": "goods",
      "label": "商品与贸易",
      "heading": "商品与贸易",
      "icon": "cargo",
      "intro": "商品、补给与材料构成贸易的基本盘；重量、价格与库存共同决定一趟航程的利润。"
    },
    {
      "id": "ships",
      "label": "船只",
      "heading": "船只与船坞",
      "icon": "hull",
      "intro": "从起步小船的轻便，到大型船体的厚重，船体决定载重、槽位与续航的边界。"
    },
    {
      "id": "modules",
      "label": "模块与改装",
      "heading": "模块与改装",
      "icon": "boiler",
      "intro": "锅炉、货舱、导航与安全模块决定船只的速度、运力与抗风险能力。"
    },
    {
      "id": "voyage",
      "label": "航行",
      "heading": "航行与补给",
      "icon": "chart",
      "intro": "补给、锅炉、航道与天气共同塑造一次航程：快一点，还是稳一点。"
    },
    {
      "id": "combat",
      "label": "战斗",
      "heading": "蒸汽与火炮",
      "icon": "cannon",
      "intro": "蒸汽舰炮、装甲与机动构成海战；交战距离与伤害类型决定谁先沉没。"
    },
    {
      "id": "fleet",
      "label": "舰队",
      "heading": "舰队与指挥官",
      "icon": "flag",
      "intro": "舰长、阵型与战术把多艘船编成一支舰队，让护航与猎袭各有所长。"
    },
    {
      "id": "base",
      "label": "基地与生产",
      "heading": "基地与生产",
      "icon": "factory",
      "intro": "在海岸建立前哨，把原料加工成造船与航行所需的材料。"
    },
    {
      "id": "ruins",
      "label": "遗迹与秘宝",
      "heading": "遗迹与秘宝",
      "icon": "ruin",
      "intro": "半沉的城市、封闭的金库与仍在运转的蒸汽机关，藏着蓝图与遗物。"
    },
    {
      "id": "glossary",
      "label": "术语",
      "heading": "航海术语",
      "icon": "book",
      "intro": "航行中反复出现的参数与概念，先在这里对齐术语。"
    }
  ],
  "entries": [
    {
      "id": "region-start-haven",
      "category": "world",
      "title": "起始港湾",
      "kind": "海域",
      "description": "战役起点的安全海岸，设施齐备、风险最低。",
      "tags": [
        "起点",
        "安全"
      ],
      "stats": [
        [
          "地形",
          "沿海"
        ],
        [
          "规模",
          "中型"
        ],
        [
          "气候",
          "温带气候"
        ],
        [
          "敌对程度",
          "低"
        ]
      ]
    },
    {
      "id": "region-trade-coast",
      "category": "world",
      "title": "贸易海岸",
      "kind": "海域",
      "description": "商路密集的沿海区域，商船与市场都很活跃。",
      "tags": [
        "商路"
      ],
      "stats": [
        [
          "地形",
          "沿海"
        ],
        [
          "规模",
          "中型"
        ],
        [
          "气候",
          "温带气候"
        ],
        [
          "敌对程度",
          "中"
        ]
      ]
    },
    {
      "id": "region-shiver-archipelago",
      "category": "world",
      "title": "群岛海域",
      "kind": "海域",
      "description": "岛链与浅滩交错，遗迹与残骸多，航行风险偏高。",
      "tags": [
        "荒野"
      ],
      "stats": [
        [
          "地形",
          "群岛"
        ],
        [
          "规模",
          "大型"
        ],
        [
          "气候",
          "温带气候"
        ],
        [
          "敌对程度",
          "高"
        ]
      ]
    },
    {
      "id": "region-open-sea",
      "category": "world",
      "title": "外海",
      "kind": "海域",
      "description": "开阔深水区，风暴频繁，海盗与未知遭遇出没。",
      "tags": [
        "深水"
      ],
      "stats": [
        [
          "地形",
          "外海"
        ],
        [
          "规模",
          "大型"
        ],
        [
          "气候",
          "风暴带"
        ],
        [
          "敌对程度",
          "高"
        ]
      ]
    },
    {
      "id": "region-industrial-belt",
      "category": "world",
      "title": "工业带",
      "kind": "海域",
      "description": "钢铁与煤烟笼罩的工业化海岸，造船与材料贸易的中心。",
      "tags": [
        "工业"
      ],
      "stats": [
        [
          "地形",
          "工业"
        ],
        [
          "规模",
          "中型"
        ],
        [
          "气候",
          "温带气候"
        ],
        [
          "敌对程度",
          "低"
        ]
      ]
    },
    {
      "id": "site-sunken-ruin",
      "category": "world",
      "title": "沉没遗迹",
      "kind": "海上地点",
      "description": "半沉于水下的旧时代建筑，藏有蓝图与遗物。",
      "tags": [
        "遗迹"
      ],
      "stats": [
        [
          "地点类型",
          "遗迹"
        ],
        [
          "出现海域",
          "沿海、群岛"
        ],
        [
          "可重复",
          "否"
        ]
      ]
    },
    {
      "id": "site-old-wreck",
      "category": "world",
      "title": "古老残骸",
      "kind": "海上地点",
      "description": "搁浅多年的沉船，仍有可回收的货物与图纸。",
      "tags": [
        "残骸"
      ],
      "stats": [
        [
          "地点类型",
          "残骸"
        ],
        [
          "出现海域",
          "沿海、外海"
        ],
        [
          "可重复",
          "否"
        ]
      ]
    },
    {
      "id": "site-sea-landmark",
      "category": "world",
      "title": "海上地标",
      "kind": "海上地点",
      "description": "航路旁的醒目地标，可用于定位并安全通行。",
      "tags": [
        "地标"
      ],
      "stats": [
        [
          "地点类型",
          "地标"
        ],
        [
          "出现海域",
          "沿海、群岛、外海"
        ],
        [
          "可重复",
          "是"
        ]
      ]
    },
    {
      "id": "site-pirate-encounter",
      "category": "world",
      "title": "海盗遭遇",
      "kind": "海上地点",
      "description": "海盗船队出没的海域，可能爆发战斗或谈判。",
      "tags": [
        "遭遇",
        "敌对"
      ],
      "stats": [
        [
          "地点类型",
          "遭遇"
        ],
        [
          "出现海域",
          "群岛、外海"
        ],
        [
          "可重复",
          "是"
        ]
      ]
    },
    {
      "id": "site-base-camp",
      "category": "world",
      "title": "基地营地",
      "kind": "海上地点",
      "description": "可供建立前哨的避风锚地。",
      "tags": [
        "基地"
      ],
      "stats": [
        [
          "地点类型",
          "基地点"
        ],
        [
          "出现海域",
          "沿海、工业"
        ],
        [
          "可重复",
          "否"
        ]
      ]
    },
    {
      "id": "site-ore-shoal",
      "category": "world",
      "title": "矿脉浅滩",
      "kind": "海上地点",
      "description": "浅海下的矿石露头，可反复采集。",
      "tags": [
        "资源"
      ],
      "stats": [
        [
          "地点类型",
          "资源点"
        ],
        [
          "出现海域",
          "沿海、工业"
        ],
        [
          "可重复",
          "是"
        ]
      ]
    },
    {
      "id": "port-template-iron-harbor",
      "category": "port",
      "title": "铁港",
      "kind": "港口",
      "description": "工业港口，拥有造船厂，铁矿石与钢板供应充足。",
      "tags": [
        "枢纽",
        "工业港",
        "造船厂"
      ],
      "stats": [
        [
          "规模",
          "中型"
        ],
        [
          "设施",
          "交易所、委托、补给、造船厂、酒馆"
        ],
        [
          "市场",
          "6 种商品"
        ]
      ]
    },
    {
      "id": "port-template-spice-port",
      "category": "port",
      "title": "香料港",
      "kind": "港口",
      "description": "香料贸易繁荣，设有情报站。",
      "tags": [
        "贸易",
        "情报"
      ],
      "stats": [
        [
          "规模",
          "小型"
        ],
        [
          "设施",
          "交易所、委托、补给、酒馆"
        ],
        [
          "市场",
          "4 种商品"
        ]
      ]
    },
    {
      "id": "port-template-free-town",
      "category": "port",
      "title": "自由镇",
      "kind": "港口",
      "description": "设施齐全的中立贸易港，造船厂与情报站并存。",
      "tags": [
        "枢纽",
        "贸易",
        "造船厂"
      ],
      "stats": [
        [
          "规模",
          "中型"
        ],
        [
          "设施",
          "交易所、委托、补给、造船厂、酒馆"
        ],
        [
          "市场",
          "7 种商品"
        ]
      ]
    },
    {
      "id": "port-template-fishing-village",
      "category": "port",
      "title": "渔村",
      "kind": "港口",
      "description": "木材与铁矿便宜，但设施有限。",
      "tags": [
        "村镇",
        "补给"
      ],
      "stats": [
        [
          "规模",
          "小型"
        ],
        [
          "设施",
          "交易所、委托、补给"
        ],
        [
          "市场",
          "4 种商品"
        ]
      ]
    },
    {
      "id": "port-template-glass-port",
      "category": "port",
      "title": "玻璃港",
      "kind": "港口",
      "description": "玻璃器皿的产地，设有情报站。",
      "tags": [
        "工艺",
        "情报"
      ],
      "stats": [
        [
          "规模",
          "小型"
        ],
        [
          "设施",
          "交易所、委托、补给、酒馆"
        ],
        [
          "市场",
          "4 种商品"
        ]
      ]
    },
    {
      "id": "item-iron-ore",
      "category": "goods",
      "title": "铁矿石",
      "kind": "材料",
      "description": "造船与冶炼的基础原料，单位重量大。",
      "tags": [
        "贸易品",
        "大宗货",
        "造船材料"
      ],
      "stats": [
        [
          "类别",
          "矿石"
        ],
        [
          "重量",
          "3"
        ],
        [
          "基准价",
          "42 金币"
        ]
      ]
    },
    {
      "id": "item-brass",
      "category": "goods",
      "title": "黄铜",
      "kind": "材料",
      "description": "锅炉与精密机械常用的金属材料。",
      "tags": [
        "贸易品",
        "造船材料"
      ],
      "stats": [
        [
          "类别",
          "金属"
        ],
        [
          "重量",
          "2"
        ],
        [
          "基准价",
          "88 金币"
        ]
      ]
    },
    {
      "id": "item-textiles",
      "category": "goods",
      "title": "纺织品",
      "kind": "商品",
      "description": "轻便的日用商品，适合填充剩余舱位。",
      "tags": [
        "贸易品",
        "日用"
      ],
      "stats": [
        [
          "类别",
          "纺织品"
        ],
        [
          "重量",
          "1"
        ],
        [
          "基准价",
          "64 金币"
        ]
      ]
    },
    {
      "id": "item-spices",
      "category": "goods",
      "title": "香料",
      "kind": "商品",
      "description": "重量极轻、价格昂贵的奢侈品。",
      "tags": [
        "贸易品",
        "奢侈品"
      ],
      "stats": [
        [
          "类别",
          "奢侈品"
        ],
        [
          "重量",
          "0.5"
        ],
        [
          "基准价",
          "150 金币"
        ]
      ]
    },
    {
      "id": "item-timber",
      "category": "goods",
      "title": "木材",
      "kind": "材料",
      "description": "船体与货舱的通用建造材料。",
      "tags": [
        "贸易品",
        "大宗货",
        "造船材料"
      ],
      "stats": [
        [
          "类别",
          "木材"
        ],
        [
          "重量",
          "2.5"
        ],
        [
          "基准价",
          "36 金币"
        ]
      ]
    },
    {
      "id": "item-glassware",
      "category": "goods",
      "title": "玻璃器皿",
      "kind": "商品",
      "description": "易碎但利润可观的工艺品。",
      "tags": [
        "贸易品",
        "易碎"
      ],
      "stats": [
        [
          "类别",
          "工艺品"
        ],
        [
          "重量",
          "1.5"
        ],
        [
          "基准价",
          "105 金币"
        ]
      ]
    },
    {
      "id": "item-contract-freight",
      "category": "goods",
      "title": "委托货箱",
      "kind": "委托货",
      "description": "由委托方提供的封装货物，不能自由买卖或抛弃。",
      "tags": [
        "委托"
      ],
      "stats": [
        [
          "类别",
          "委托货"
        ],
        [
          "重量",
          "1"
        ],
        [
          "基准价",
          "1 金币"
        ]
      ]
    },
    {
      "id": "item-coal",
      "category": "goods",
      "title": "煤",
      "kind": "补给",
      "description": "锅炉燃料，重量轻、价格低，任何航程都离不开。",
      "tags": [
        "燃料",
        "大宗货"
      ],
      "stats": [
        [
          "类别",
          "补给"
        ],
        [
          "重量",
          "1"
        ],
        [
          "基准价",
          "4 金币"
        ]
      ]
    },
    {
      "id": "item-water",
      "category": "goods",
      "title": "淡水",
      "kind": "补给",
      "description": "锅炉给水与日常补给，长途航行消耗很大。",
      "tags": [
        "给水",
        "大宗货"
      ],
      "stats": [
        [
          "类别",
          "补给"
        ],
        [
          "重量",
          "1"
        ],
        [
          "基准价",
          "2 金币"
        ]
      ]
    },
    {
      "id": "item-boiler-plate",
      "category": "goods",
      "title": "锅炉钢板",
      "kind": "材料",
      "description": "耐压锅炉与中型船体的专用材料。",
      "tags": [
        "造船材料",
        "二级材料"
      ],
      "stats": [
        [
          "类别",
          "钢板"
        ],
        [
          "重量",
          "2"
        ],
        [
          "基准价",
          "120 金币"
        ],
        [
          "等级",
          "II"
        ]
      ]
    },
    {
      "id": "item-precision-gear",
      "category": "goods",
      "title": "精密齿轮",
      "kind": "材料",
      "description": "大型船只与高性能锅炉所需的高级材料。",
      "tags": [
        "造船材料",
        "三级材料"
      ],
      "stats": [
        [
          "类别",
          "精密机械"
        ],
        [
          "重量",
          "0.8"
        ],
        [
          "基准价",
          "190 金币"
        ],
        [
          "等级",
          "III"
        ]
      ]
    },
    {
      "id": "item-sealing-compound",
      "category": "goods",
      "title": "密封胶",
      "kind": "材料",
      "description": "用于锅炉、客舱和导航设备的密封耗材。",
      "tags": [
        "造船材料",
        "一级材料"
      ],
      "stats": [
        [
          "类别",
          "密封耗材"
        ],
        [
          "重量",
          "0.5"
        ],
        [
          "基准价",
          "75 金币"
        ],
        [
          "等级",
          "I"
        ]
      ]
    },
    {
      "id": "trade-policy-bulk-lane",
      "category": "goods",
      "title": "大宗航线",
      "kind": "贸易策略",
      "description": "在工业港买入木材与锅炉钢板，卖往贸易/工艺港的稳健航线。",
      "tags": [
        "大宗",
        "稳健"
      ],
      "stats": [
        [
          "预算",
          "1600 金币"
        ],
        [
          "预留资金",
          "250 金币"
        ],
        [
          "载货上限",
          "40"
        ],
        [
          "最短利润",
          "5%"
        ]
      ]
    },
    {
      "id": "trade-policy-luxury-run",
      "category": "goods",
      "title": "奢侈品快线",
      "kind": "贸易策略",
      "description": "在贸易港买入香料与玻璃器皿，卖往枢纽港的高利润高风险航线。",
      "tags": [
        "奢侈品",
        "高风险"
      ],
      "stats": [
        [
          "预算",
          "1500 金币"
        ],
        [
          "预留资金",
          "500 金币"
        ],
        [
          "载货上限",
          "14"
        ],
        [
          "最短利润",
          "20%"
        ]
      ]
    },
    {
      "id": "hull-small-efficient",
      "category": "ships",
      "title": "效率型小型船体",
      "kind": "船体",
      "description": "造价低、自重轻，只有一个货舱槽，适合起步。",
      "tags": [
        "小型",
        "效率型"
      ],
      "stats": [
        [
          "重量",
          "22"
        ],
        [
          "售价",
          "380 金币"
        ],
        [
          "航速",
          "14 节"
        ],
        [
          "货舱槽",
          "1"
        ]
      ]
    },
    {
      "id": "hull-medium-standard",
      "category": "ships",
      "title": "标准中型船体",
      "kind": "船体",
      "description": "两个货舱槽与一个客舱槽，是中期成长的核心。",
      "tags": [
        "中型",
        "标准"
      ],
      "stats": [
        [
          "重量",
          "38"
        ],
        [
          "售价",
          "1100 金币"
        ],
        [
          "航速",
          "15 节"
        ],
        [
          "货舱槽",
          "2"
        ]
      ]
    },
    {
      "id": "hull-large-efficient",
      "category": "ships",
      "title": "效率型大型船体",
      "kind": "船体",
      "description": "三个货舱槽、高耐久与低单位重量成本。",
      "tags": [
        "大型",
        "效率型"
      ],
      "stats": [
        [
          "重量",
          "60"
        ],
        [
          "售价",
          "2600 金币"
        ],
        [
          "航速",
          "14 节"
        ],
        [
          "货舱槽",
          "3"
        ]
      ]
    },
    {
      "id": "hull-large-performance",
      "category": "ships",
      "title": "性能型大型船体",
      "kind": "船体",
      "description": "更快但更重、更贵的大型船体。",
      "tags": [
        "大型",
        "性能型"
      ],
      "stats": [
        [
          "重量",
          "66"
        ],
        [
          "售价",
          "3400 金币"
        ],
        [
          "航速",
          "17 节"
        ],
        [
          "货舱槽",
          "3"
        ]
      ]
    },
    {
      "id": "ship-archetype-flagship-ironclad",
      "category": "ships",
      "title": "铁甲旗舰",
      "kind": "舰队船型",
      "description": "大型高性能船体改造的旗舰：重炮双联装、厚甲与充足船员，是舰队的核心。",
      "tags": [
        "舰队",
        "旗舰"
      ],
      "stats": [
        [
          "船员",
          "40 人"
        ],
        [
          "载货",
          "160"
        ],
        [
          "航速",
          "17 节"
        ],
        [
          "维护",
          "120 金币"
        ]
      ]
    },
    {
      "id": "ship-archetype-freight-hauler",
      "category": "ships",
      "title": "货运商船",
      "kind": "舰队船型",
      "description": "中型标准船体的货船：货舱大、维护费低，适合商队运输。",
      "tags": [
        "舰队",
        "货运"
      ],
      "stats": [
        [
          "船员",
          "18 人"
        ],
        [
          "载货",
          "165"
        ],
        [
          "航速",
          "15 节"
        ],
        [
          "维护",
          "45 金币"
        ]
      ]
    },
    {
      "id": "ship-archetype-courier-sloop",
      "category": "ships",
      "title": "快信单桅船",
      "kind": "舰队船型",
      "description": "小型高效船体的快船：航速高、维护便宜，适合侦察与传令。",
      "tags": [
        "舰队",
        "传令"
      ],
      "stats": [
        [
          "船员",
          "8 人"
        ],
        [
          "载货",
          "60"
        ],
        [
          "航速",
          "14 节"
        ],
        [
          "维护",
          "20 金币"
        ]
      ]
    },
    {
      "id": "ship-archetype-flagship-large-efficient",
      "category": "ships",
      "title": "稳健级旗舰",
      "kind": "舰队船型",
      "description": "大型高效船体改造的终局旗舰：三货舱、双舷炮列与充足船员，兼顾续航与火力。",
      "tags": [
        "舰队",
        "旗舰"
      ],
      "stats": [
        [
          "船员",
          "34 人"
        ],
        [
          "载货",
          "260"
        ],
        [
          "航速",
          "14 节"
        ],
        [
          "维护",
          "100 金币"
        ]
      ]
    },
    {
      "id": "module-small-efficient",
      "category": "modules",
      "title": "效率型小型锅炉",
      "kind": "模块",
      "description": "省煤省水，航速略低，适合长途与学习。",
      "tags": [
        "锅炉",
        "小型",
        "效率型"
      ],
      "stats": [
        [
          "类别",
          "锅炉"
        ],
        [
          "等级",
          "I"
        ],
        [
          "价格",
          "420 金币"
        ],
        [
          "关键效果",
          "航速 ×0.94"
        ]
      ]
    },
    {
      "id": "module-standard",
      "category": "modules",
      "title": "标准锅炉",
      "kind": "模块",
      "description": "速度与补给消耗均衡的默认锅炉。",
      "tags": [
        "锅炉",
        "标准"
      ],
      "stats": [
        [
          "类别",
          "锅炉"
        ],
        [
          "等级",
          "I"
        ],
        [
          "价格",
          "650 金币"
        ]
      ]
    },
    {
      "id": "module-performance",
      "category": "modules",
      "title": "性能型锅炉",
      "kind": "模块",
      "description": "航速高，但煤水消耗显著上升。",
      "tags": [
        "锅炉",
        "性能型"
      ],
      "stats": [
        [
          "类别",
          "锅炉"
        ],
        [
          "等级",
          "II"
        ],
        [
          "价格",
          "1200 金币"
        ],
        [
          "关键效果",
          "航速 ×1.18"
        ]
      ]
    },
    {
      "id": "module-small-hold",
      "category": "modules",
      "title": "小型货舱",
      "kind": "模块",
      "description": "自重低，容量 32。",
      "tags": [
        "货舱",
        "小型",
        "效率型"
      ],
      "stats": [
        [
          "类别",
          "货舱"
        ],
        [
          "等级",
          "I"
        ],
        [
          "价格",
          "260 金币"
        ],
        [
          "关键效果",
          "容量 32"
        ]
      ]
    },
    {
      "id": "module-medium-hold",
      "category": "modules",
      "title": "中型货舱",
      "kind": "模块",
      "description": "容量 68，适合中型船体。",
      "tags": [
        "货舱",
        "中型",
        "标准"
      ],
      "stats": [
        [
          "类别",
          "货舱"
        ],
        [
          "等级",
          "II"
        ],
        [
          "价格",
          "900 金币"
        ],
        [
          "关键效果",
          "容量 68"
        ]
      ]
    },
    {
      "id": "module-large-hold",
      "category": "modules",
      "title": "大型货舱",
      "kind": "模块",
      "description": "容量 110，适合大型船体。",
      "tags": [
        "货舱",
        "大型",
        "性能型"
      ],
      "stats": [
        [
          "类别",
          "货舱"
        ],
        [
          "等级",
          "III"
        ],
        [
          "价格",
          "1800 金币"
        ],
        [
          "关键效果",
          "容量 110"
        ]
      ]
    },
    {
      "id": "module-spyglass",
      "category": "modules",
      "title": "望远镜",
      "kind": "模块",
      "description": "略微降低迷航风险，价格便宜。",
      "tags": [
        "导航",
        "效率型"
      ],
      "stats": [
        [
          "类别",
          "通用设备"
        ],
        [
          "等级",
          "I"
        ],
        [
          "价格",
          "300 金币"
        ],
        [
          "关键效果",
          "风险 -1.2%"
        ]
      ]
    },
    {
      "id": "module-chart-room",
      "category": "modules",
      "title": "海图室",
      "kind": "模块",
      "description": "降低风险并提升航速，出航前可揭示未知目的港设施。",
      "tags": [
        "导航",
        "性能型"
      ],
      "stats": [
        [
          "类别",
          "通用设备"
        ],
        [
          "等级",
          "II"
        ],
        [
          "价格",
          "850 金币"
        ],
        [
          "关键效果",
          "航速 ×1.03、揭示目的港设施、风险 -2.2%"
        ]
      ]
    },
    {
      "id": "module-lifeboat",
      "category": "modules",
      "title": "救生艇",
      "kind": "模块",
      "description": "降低事故损失与部分风险。",
      "tags": [
        "安全",
        "效率型"
      ],
      "stats": [
        [
          "类别",
          "通用设备"
        ],
        [
          "等级",
          "I"
        ],
        [
          "价格",
          "280 金币"
        ],
        [
          "关键效果",
          "风险 -1.5%、损伤 ×0.9"
        ]
      ]
    },
    {
      "id": "module-safety-valve",
      "category": "modules",
      "title": "安全阀组",
      "kind": "模块",
      "description": "显著降低锅炉事故风险与维修费用。",
      "tags": [
        "安全",
        "性能型"
      ],
      "stats": [
        [
          "类别",
          "通用设备"
        ],
        [
          "等级",
          "II"
        ],
        [
          "价格",
          "760 金币"
        ],
        [
          "关键效果",
          "风险 -3%、损伤 ×0.75、维修费 ×0.85"
        ]
      ]
    },
    {
      "id": "module-passenger-cabin",
      "category": "modules",
      "title": "固定客舱",
      "kind": "模块",
      "description": "可搭载 4 名旅客，占用船体客舱槽。",
      "tags": [
        "客舱",
        "客运"
      ],
      "stats": [
        [
          "类别",
          "客舱"
        ],
        [
          "等级",
          "I"
        ],
        [
          "价格",
          "600 金币"
        ],
        [
          "关键效果",
          "载客 4 人"
        ]
      ]
    },
    {
      "id": "module-small-cabin",
      "category": "modules",
      "title": "小型客舱（1 人）",
      "kind": "模块",
      "description": "第三港船厂为教学船准备的单人客舱：只能载 1 名旅客，重量轻，适合刚起步的船。",
      "tags": [
        "客舱",
        "客运",
        "小型"
      ],
      "stats": [
        [
          "类别",
          "客舱"
        ],
        [
          "等级",
          "I"
        ],
        [
          "价格",
          "120 金币"
        ],
        [
          "关键效果",
          "载客 1 人"
        ]
      ]
    },
    {
      "id": "boiler-strategy-economic",
      "category": "voyage",
      "title": "经济",
      "kind": "锅炉策略",
      "description": "降低航速与补给消耗，适合长途与补给紧张。",
      "tags": [
        "慢速"
      ],
      "stats": [
        [
          "航速",
          "×0.8"
        ],
        [
          "煤耗",
          "×0.68"
        ],
        [
          "水耗",
          "×0.78"
        ],
        [
          "风险",
          "-1%"
        ]
      ]
    },
    {
      "id": "boiler-strategy-standard",
      "category": "voyage",
      "title": "标准",
      "kind": "锅炉策略",
      "description": "速度、补给与风险的平衡方案。",
      "tags": [
        "均衡"
      ],
      "stats": [
        [
          "定位",
          "基准值"
        ]
      ]
    },
    {
      "id": "boiler-strategy-fast",
      "category": "voyage",
      "title": "极速",
      "kind": "锅炉策略",
      "description": "显著提高航速，但煤水消耗与风险更高。",
      "tags": [
        "高风险"
      ],
      "stats": [
        [
          "航速",
          "×1.28"
        ],
        [
          "煤耗",
          "×1.8"
        ],
        [
          "水耗",
          "×1.6"
        ],
        [
          "风险",
          "+6%"
        ]
      ]
    },
    {
      "id": "voyage-event-boiler-overheat",
      "category": "voyage",
      "title": "锅炉过热",
      "kind": "航行事件",
      "description": "压力表指针越过红线，锅炉发出尖锐的鸣响。",
      "tags": [
        "风险事件",
        "机械"
      ],
      "stats": [
        [
          "触发",
          "航行风险"
        ],
        [
          "类别",
          "机械故障"
        ],
        [
          "选项",
          "5 个"
        ]
      ]
    },
    {
      "id": "voyage-event-merchant-intel",
      "category": "voyage",
      "title": "偶遇商船",
      "kind": "航行事件",
      "description": "一艘商船靠近，表示愿意出售刚获得的市场情报。",
      "tags": [
        "机遇",
        "商人"
      ],
      "stats": [
        [
          "触发",
          "航行机遇"
        ],
        [
          "类别",
          "商人"
        ],
        [
          "选项",
          "2 个"
        ]
      ]
    },
    {
      "id": "crew-role-engineer-basic",
      "category": "voyage",
      "title": "工程师",
      "kind": "船员岗位",
      "description": "降低故障风险与维修费用，每次航行领取工资。",
      "tags": [
        "机舱",
        "船员"
      ],
      "stats": [
        [
          "岗位",
          "工程师"
        ],
        [
          "出航工资",
          "40 金币"
        ],
        [
          "雇佣费",
          "100 金币"
        ],
        [
          "效果",
          "风险 -1.5%、维修费 ×0.85、伤害 ×0.95"
        ]
      ]
    },
    {
      "id": "crew-role-navigator-basic",
      "category": "voyage",
      "title": "领航员",
      "kind": "船员岗位",
      "description": "降低迷航风险并略微提升航速。",
      "tags": [
        "领航",
        "船员"
      ],
      "stats": [
        [
          "岗位",
          "领航员"
        ],
        [
          "出航工资",
          "35 金币"
        ],
        [
          "雇佣费",
          "100 金币"
        ],
        [
          "效果",
          "风险 -2%、航速 ×1.03"
        ]
      ]
    },
    {
      "id": "route-template-coastal-lane",
      "category": "voyage",
      "title": "沿海航道",
      "kind": "航道",
      "description": "沿大陆架航行的安全常规航线。",
      "tags": [
        "安全"
      ],
      "stats": [
        [
          "类型",
          "海上航道"
        ],
        [
          "距离",
          "90–180"
        ],
        [
          "航行时间",
          "8–20 小时"
        ],
        [
          "风险",
          "1%–4%"
        ]
      ]
    },
    {
      "id": "route-template-archipelago-trade",
      "category": "voyage",
      "title": "群岛商路",
      "kind": "航道",
      "description": "穿越岛屿之间的贸易航线，利润与风险都更高。",
      "tags": [
        "贸易"
      ],
      "stats": [
        [
          "类型",
          "贸易航线"
        ],
        [
          "距离",
          "120–220"
        ],
        [
          "航行时间",
          "10–26 小时"
        ],
        [
          "风险",
          "2%–6%"
        ]
      ]
    },
    {
      "id": "route-template-storm-shortcut",
      "category": "voyage",
      "title": "风暴捷径",
      "kind": "航道",
      "description": "穿过风暴带的危险近路，能省下大量航时。",
      "tags": [
        "危险",
        "快速"
      ],
      "stats": [
        [
          "类型",
          "危险近路"
        ],
        [
          "距离",
          "60–120"
        ],
        [
          "航行时间",
          "4–10 小时"
        ],
        [
          "风险",
          "6%–14%"
        ]
      ]
    },
    {
      "id": "weather-profile-temperate",
      "category": "voyage",
      "title": "温带气候",
      "kind": "气候",
      "description": "四季分明、雾与风暴都较温和的气候带。",
      "tags": [
        "温和"
      ],
      "stats": [
        [
          "气候",
          "温带"
        ],
        [
          "起雾概率",
          "15%"
        ],
        [
          "风暴概率",
          "10%"
        ],
        [
          "航速影响",
          "0%"
        ]
      ]
    },
    {
      "id": "weather-profile-storm-belt",
      "category": "voyage",
      "title": "风暴带",
      "kind": "气候",
      "description": "常年强风巨浪，风险与煤耗显著上升。",
      "tags": [
        "风暴",
        "危险"
      ],
      "stats": [
        [
          "气候",
          "风暴带"
        ],
        [
          "起雾概率",
          "20%"
        ],
        [
          "风暴概率",
          "45%"
        ],
        [
          "航速影响",
          "-10%"
        ]
      ]
    },
    {
      "id": "weapon-deck-gun",
      "category": "combat",
      "title": "甲板速射炮",
      "kind": "武器",
      "description": "轻型甲板速射炮：射速快、射程适中，是最通用的舰载火炮。",
      "tags": [
        "直射",
        "轻型"
      ],
      "stats": [
        [
          "伤害",
          "12"
        ],
        [
          "射程",
          "245"
        ],
        [
          "冷却",
          "1.65"
        ],
        [
          "伤害类型",
          "动能"
        ]
      ]
    },
    {
      "id": "weapon-heavy-cannon",
      "category": "combat",
      "title": "重型舰炮",
      "kind": "武器",
      "description": "重型舰炮：单发伤害高、射程远，但装填慢、需要重级安装点。",
      "tags": [
        "直射",
        "重型"
      ],
      "stats": [
        [
          "伤害",
          "30"
        ],
        [
          "射程",
          "355"
        ],
        [
          "冷却",
          "4.2"
        ],
        [
          "伤害类型",
          "动能"
        ]
      ]
    },
    {
      "id": "weapon-mortar",
      "category": "combat",
      "title": "曲射迫击炮",
      "kind": "武器",
      "description": "曲射迫击炮：高抛弹道、射程最远且带大范围溅射，近距离无法开火。",
      "tags": [
        "曲射",
        "重型"
      ],
      "stats": [
        [
          "伤害",
          "24"
        ],
        [
          "射程",
          "430"
        ],
        [
          "冷却",
          "5.1"
        ],
        [
          "伤害类型",
          "爆炸"
        ]
      ]
    },
    {
      "id": "weapon-repeater",
      "category": "combat",
      "title": "机关连发炮",
      "kind": "武器",
      "description": "机关连发炮：射速极快、射程短，适合压制近距离目标。",
      "tags": [
        "直射",
        "中型"
      ],
      "stats": [
        [
          "伤害",
          "7"
        ],
        [
          "射程",
          "185"
        ],
        [
          "冷却",
          "0.72"
        ],
        [
          "伤害类型",
          "动能"
        ]
      ]
    },
    {
      "id": "weapon-broadside",
      "category": "combat",
      "title": "侧弦炮列",
      "kind": "武器",
      "description": "侧弦炮列：四门短舰炮共用一个舷侧安装点，齐射后装填较慢。",
      "tags": [
        "齐射",
        "舷侧炮位"
      ],
      "stats": [
        [
          "伤害",
          "8"
        ],
        [
          "射程",
          "285"
        ],
        [
          "冷却",
          "5.4"
        ],
        [
          "伤害类型",
          "动能"
        ]
      ]
    },
    {
      "id": "damage-type-kinetic",
      "category": "combat",
      "title": "动能",
      "kind": "伤害类型",
      "description": "实心弹与破片造成的冲击伤害；大部分舰炮的主要伤害类型。",
      "tags": [
        "穿甲"
      ],
      "stats": [
        [
          "装甲穿透",
          "10%"
        ],
        [
          "附加状态",
          "无"
        ]
      ]
    },
    {
      "id": "damage-type-explosive",
      "category": "combat",
      "title": "爆炸",
      "kind": "伤害类型",
      "description": "爆炸冲击与破片；对装甲的穿透略高，适合曲射火炮。",
      "tags": [
        "破片"
      ],
      "stats": [
        [
          "装甲穿透",
          "35%"
        ],
        [
          "附加状态",
          "无"
        ]
      ]
    },
    {
      "id": "damage-type-fire",
      "category": "combat",
      "title": "燃烧",
      "kind": "伤害类型",
      "description": "高温火焰，命中后可能追加燃烧状态。",
      "tags": [
        "灼烧"
      ],
      "stats": [
        [
          "装甲穿透",
          "0%"
        ],
        [
          "附加状态",
          "燃烧"
        ]
      ]
    },
    {
      "id": "damage-type-shock",
      "category": "combat",
      "title": "电击",
      "kind": "伤害类型",
      "description": "电流与震荡伤害，命中后可能追加电击状态。",
      "tags": [
        "震荡"
      ],
      "stats": [
        [
          "装甲穿透",
          "20%"
        ],
        [
          "附加状态",
          "电击"
        ]
      ]
    },
    {
      "id": "enemy-archetype-pirate-sloop",
      "category": "combat",
      "title": "海盗单桅船",
      "kind": "敌舰",
      "description": "轻快海盗船：装甲薄、速度高，成群袭扰商路。",
      "tags": [
        "轻型",
        "海盗"
      ],
      "stats": [
        [
          "舰级",
          "轻型"
        ],
        [
          "船体耐久",
          "140"
        ],
        [
          "装甲",
          "5%"
        ],
        [
          "最高航速",
          "16 节"
        ]
      ]
    },
    {
      "id": "enemy-archetype-gunboat",
      "category": "combat",
      "title": "炮艇",
      "kind": "敌舰",
      "description": "轻装炮艇：船首重炮、两舷轻炮，是巡逻队的核心。",
      "tags": [
        "轻型",
        "海军"
      ],
      "stats": [
        [
          "舰级",
          "轻型"
        ],
        [
          "船体耐久",
          "180"
        ],
        [
          "装甲",
          "15%"
        ],
        [
          "最高航速",
          "13 节"
        ]
      ]
    },
    {
      "id": "enemy-archetype-armed-merchantman",
      "category": "combat",
      "title": "武装商船",
      "kind": "敌舰",
      "description": "重载商船：装甲一般、货舱宽大，护航时以防御机动脱离战斗。",
      "tags": [
        "中型",
        "商船"
      ],
      "stats": [
        [
          "舰级",
          "中型"
        ],
        [
          "船体耐久",
          "320"
        ],
        [
          "装甲",
          "20%"
        ],
        [
          "最高航速",
          "9 节"
        ]
      ]
    },
    {
      "id": "enemy-archetype-ironclad-raider",
      "category": "combat",
      "title": "铁甲袭击者",
      "kind": "敌舰",
      "description": "重甲袭击者：装甲厚、血量高，炮位以重炮为主，正面交战极难击沉。",
      "tags": [
        "重型",
        "海盗"
      ],
      "stats": [
        [
          "舰级",
          "重型"
        ],
        [
          "船体耐久",
          "520"
        ],
        [
          "装甲",
          "45%"
        ],
        [
          "最高航速",
          "7 节"
        ]
      ]
    },
    {
      "id": "combat-ability-aggressive",
      "category": "combat",
      "title": "激进交战",
      "kind": "战斗能力",
      "description": "优先扑向最弱目标，保持中近距离持续火力。",
      "tags": [
        "激进"
      ],
      "stats": [
        [
          "交战动作",
          "交战"
        ],
        [
          "目标优先",
          "最弱目标"
        ],
        [
          "交战航速",
          "×0.85"
        ]
      ]
    },
    {
      "id": "combat-ability-defensive",
      "category": "combat",
      "title": "防御规避",
      "kind": "战斗能力",
      "description": "装甲受损时优先规避脱离，保护货舱与船员。",
      "tags": [
        "防御"
      ],
      "stats": [
        [
          "交战动作",
          "规避"
        ],
        [
          "目标优先",
          "最近目标"
        ],
        [
          "撤退耐久",
          "35%"
        ]
      ]
    },
    {
      "id": "combat-ability-raider",
      "category": "combat",
      "title": "劫掠突袭",
      "kind": "战斗能力",
      "description": "优先追击货船，抢在护航舰反应前接近并登船。",
      "tags": [
        "劫掠"
      ],
      "stats": [
        [
          "交战动作",
          "接近"
        ],
        [
          "目标优先",
          "货舱"
        ],
        [
          "交战航速",
          "×0.9"
        ]
      ]
    },
    {
      "id": "combat-ability-escort",
      "category": "combat",
      "title": "护航机动",
      "kind": "战斗能力",
      "description": "侧向迂回，拦截威胁货船的敌人。",
      "tags": [
        "护航"
      ],
      "stats": [
        [
          "交战动作",
          "侧击"
        ],
        [
          "目标优先",
          "货舱"
        ],
        [
          "交战航速",
          "×0.6"
        ]
      ]
    },
    {
      "id": "encounter-table-coastal-patrol",
      "category": "combat",
      "title": "近海巡逻",
      "kind": "遭遇表",
      "description": "近海常见的小规模巡逻遭遇：海盗船与炮艇混合。",
      "tags": [
        "巡逻"
      ],
      "stats": [
        [
          "类型",
          "巡逻"
        ],
        [
          "危险度",
          "3"
        ],
        [
          "编成",
          "海盗单桅船 ×1–2、炮艇 ×1、武装商船 ×1"
        ]
      ]
    },
    {
      "id": "encounter-table-iron-convoy",
      "category": "combat",
      "title": "铁甲护航队",
      "kind": "遭遇表",
      "description": "高危险度护航队：铁甲袭击者率领炮艇掩护商船。",
      "tags": [
        "护航队"
      ],
      "stats": [
        [
          "类型",
          "护航队"
        ],
        [
          "危险度",
          "6"
        ],
        [
          "编成",
          "铁甲袭击者 ×1、炮艇 ×1–2、武装商船 ×1"
        ]
      ]
    },
    {
      "id": "captain-elena-voss",
      "category": "fleet",
      "title": "艾莲娜·沃斯",
      "kind": "舰长",
      "description": "商队出身的舰队指挥官：领导与导航出色，擅长组织护航与编队。",
      "tags": [
        "商队",
        "舰队"
      ],
      "stats": [
        [
          "导航",
          "72"
        ],
        [
          "炮术",
          "58"
        ],
        [
          "工程",
          "64"
        ],
        [
          "领导",
          "78"
        ]
      ]
    },
    {
      "id": "captain-marcus-reed",
      "category": "fleet",
      "title": "马库斯·里德",
      "kind": "舰长",
      "description": "前私掠船长：炮术精湛、行事果决，适合突击与猎袭任务。",
      "tags": [
        "私掠",
        "舰队"
      ],
      "stats": [
        [
          "导航",
          "64"
        ],
        [
          "炮术",
          "76"
        ],
        [
          "工程",
          "55"
        ],
        [
          "领导",
          "62"
        ]
      ]
    },
    {
      "id": "captain-yuki-sato",
      "category": "fleet",
      "title": "佐藤雪",
      "kind": "舰长",
      "description": "远洋侦察专家：导航与工程见长，擅长带领快船脱离险境。",
      "tags": [
        "侦察",
        "舰队"
      ],
      "stats": [
        [
          "导航",
          "80"
        ],
        [
          "炮术",
          "45"
        ],
        [
          "工程",
          "70"
        ],
        [
          "领导",
          "66"
        ]
      ]
    },
    {
      "id": "formation-line-abreast",
      "category": "fleet",
      "title": "横队阵型",
      "kind": "阵型",
      "description": "舰队横向展开，旗舰居中指挥，侧翼包夹时全队伤害略有提升。",
      "tags": [
        "战列"
      ],
      "stats": [
        [
          "最大舰数",
          "5"
        ],
        [
          "阵位",
          "4 个"
        ],
        [
          "增益",
          "伤害 ×1.05"
        ]
      ]
    },
    {
      "id": "formation-escort-screen",
      "category": "fleet",
      "title": "护航环阵",
      "kind": "阵型",
      "description": "护航舰分布两翼与后方，把商船护卫在中央，降低全队风险。",
      "tags": [
        "护航"
      ],
      "stats": [
        [
          "最大舰数",
          "4"
        ],
        [
          "阵位",
          "4 个"
        ],
        [
          "增益",
          "风险 -2%"
        ]
      ]
    },
    {
      "id": "fleet-doctrine-merchant-escort",
      "category": "fleet",
      "title": "商队护航",
      "kind": "战术",
      "description": "防御优先的护航战术：保护货船、节约补给，遇险时优先撤离。",
      "tags": [
        "护航"
      ],
      "stats": [
        [
          "交战",
          "防御"
        ],
        [
          "撤退",
          "货舱受威胁时"
        ],
        [
          "护航",
          "护航队"
        ],
        [
          "目标优先",
          "货舱"
        ]
      ]
    },
    {
      "id": "fleet-doctrine-raider-hunt",
      "category": "fleet",
      "title": "猎袭战术",
      "kind": "战术",
      "description": "激进猎杀战术：优先击溃最弱目标，主动交战并积极补给。",
      "tags": [
        "猎袭"
      ],
      "stats": [
        [
          "交战",
          "激进"
        ],
        [
          "撤退",
          "受损时"
        ],
        [
          "护航",
          "巡逻"
        ],
        [
          "目标优先",
          "最弱目标"
        ]
      ]
    },
    {
      "id": "base-site-coastal-outpost",
      "category": "base",
      "title": "海岸前哨",
      "kind": "基地点",
      "description": "一处临海的小型基地点，适合起步的仓储与生产。",
      "tags": [
        "沿海",
        "起步"
      ],
      "stats": [
        [
          "建筑槽",
          "3"
        ],
        [
          "仓储",
          "600"
        ],
        [
          "防御",
          "10"
        ],
        [
          "声索费用",
          "250 金币"
        ]
      ]
    },
    {
      "id": "base-site-industrial-yard",
      "category": "base",
      "title": "工业堆场",
      "kind": "基地点",
      "description": "靠近航道的较大基地点，可容纳更多建筑与工人。",
      "tags": [
        "工业",
        "进阶"
      ],
      "stats": [
        [
          "建筑槽",
          "5"
        ],
        [
          "仓储",
          "1200"
        ],
        [
          "防御",
          "25"
        ],
        [
          "声索费用",
          "900 金币"
        ]
      ]
    },
    {
      "id": "building-sawmill",
      "category": "base",
      "title": "锯木厂",
      "kind": "建筑",
      "description": "把煤炭与本地木料加工成造船木材。",
      "tags": [
        "生产",
        "木材"
      ],
      "stats": [
        [
          "类别",
          "生产"
        ],
        [
          "建造费用",
          "120 金币"
        ],
        [
          "建造耗时",
          "2 小时"
        ],
        [
          "工位",
          "2 个"
        ]
      ]
    },
    {
      "id": "building-smelter",
      "category": "base",
      "title": "冶炼炉",
      "kind": "建筑",
      "description": "熔炼铁矿并轧制锅炉钢板。",
      "tags": [
        "生产",
        "金属"
      ],
      "stats": [
        [
          "类别",
          "生产"
        ],
        [
          "建造费用",
          "220 金币"
        ],
        [
          "建造耗时",
          "3 小时"
        ],
        [
          "工位",
          "2 个"
        ]
      ]
    },
    {
      "id": "building-foundry",
      "category": "base",
      "title": "铸造车间",
      "kind": "建筑",
      "description": "把黄铜与钢板加工成精密齿轮。",
      "tags": [
        "生产",
        "精密加工"
      ],
      "stats": [
        [
          "类别",
          "生产"
        ],
        [
          "建造费用",
          "380 金币"
        ],
        [
          "建造耗时",
          "4 小时"
        ],
        [
          "工位",
          "3 个"
        ]
      ]
    },
    {
      "id": "building-stockyard",
      "category": "base",
      "title": "仓库堆场",
      "kind": "建筑",
      "description": "为基地提供额外仓储空间。",
      "tags": [
        "仓储"
      ],
      "stats": [
        [
          "类别",
          "仓储"
        ],
        [
          "建造费用",
          "160 金币"
        ],
        [
          "建造耗时",
          "2 小时"
        ],
        [
          "工位",
          "1 个"
        ]
      ]
    },
    {
      "id": "building-defense-tower",
      "category": "base",
      "title": "防御塔",
      "kind": "建筑",
      "description": "提升基地防御，抵御袭击。",
      "tags": [
        "防御"
      ],
      "stats": [
        [
          "类别",
          "防御"
        ],
        [
          "建造费用",
          "300 金币"
        ],
        [
          "建造耗时",
          "3 小时"
        ],
        [
          "工位",
          "1 个"
        ]
      ]
    },
    {
      "id": "building-upgrade-sawmill-2",
      "category": "base",
      "title": "锯木厂 II",
      "kind": "升级",
      "description": "扩建锯木厂，生产速度 +25%。",
      "tags": [
        "产能"
      ],
      "stats": [
        [
          "升级目标",
          "锯木厂 II"
        ],
        [
          "费用",
          "180 金币"
        ],
        [
          "耗时",
          "3 小时"
        ],
        [
          "增益",
          "生产速度 ×1.25"
        ]
      ]
    },
    {
      "id": "building-upgrade-smelter-2",
      "category": "base",
      "title": "冶炼炉 II",
      "kind": "升级",
      "description": "扩建冶炼炉，生产速度 +25%。",
      "tags": [
        "产能"
      ],
      "stats": [
        [
          "升级目标",
          "冶炼炉 II"
        ],
        [
          "费用",
          "320 金币"
        ],
        [
          "耗时",
          "4 小时"
        ],
        [
          "增益",
          "生产速度 ×1.25"
        ]
      ]
    },
    {
      "id": "building-upgrade-foundry-2",
      "category": "base",
      "title": "铸造车间 II",
      "kind": "升级",
      "description": "扩建铸造车间，生产速度 +30%。",
      "tags": [
        "产能"
      ],
      "stats": [
        [
          "升级目标",
          "铸造车间 II"
        ],
        [
          "费用",
          "520 金币"
        ],
        [
          "耗时",
          "5 小时"
        ],
        [
          "增益",
          "生产速度 ×1.3"
        ]
      ]
    },
    {
      "id": "building-upgrade-stockyard-2",
      "category": "base",
      "title": "仓库堆场 II",
      "kind": "升级",
      "description": "扩建堆场，额外提供 600 仓储。",
      "tags": [
        "仓储"
      ],
      "stats": [
        [
          "升级目标",
          "仓库堆场 II"
        ],
        [
          "费用",
          "240 金币"
        ],
        [
          "耗时",
          "3 小时"
        ],
        [
          "增益",
          "仓储 +600"
        ]
      ]
    },
    {
      "id": "building-upgrade-defense-tower-2",
      "category": "base",
      "title": "防御塔 II",
      "kind": "升级",
      "description": "加固防御塔，防御 +25。",
      "tags": [
        "防御"
      ],
      "stats": [
        [
          "升级目标",
          "防御塔 II"
        ],
        [
          "费用",
          "420 金币"
        ],
        [
          "耗时",
          "4 小时"
        ],
        [
          "增益",
          "防御 +25"
        ]
      ]
    },
    {
      "id": "production-recipe-timber",
      "category": "base",
      "title": "加工木材",
      "kind": "配方",
      "description": "消耗煤炭，产出 2 份木材。",
      "tags": [
        "一级材料"
      ],
      "stats": [
        [
          "建筑",
          "锯木厂"
        ],
        [
          "投入",
          "煤 1"
        ],
        [
          "产出",
          "木材 2"
        ],
        [
          "耗时",
          "2 小时"
        ]
      ]
    },
    {
      "id": "production-recipe-boiler-plate",
      "category": "base",
      "title": "轧制锅炉钢板",
      "kind": "配方",
      "description": "熔炼铁矿并消耗煤炭，产出锅炉钢板。",
      "tags": [
        "二级材料"
      ],
      "stats": [
        [
          "建筑",
          "冶炼炉"
        ],
        [
          "投入",
          "铁矿石 2、煤 1"
        ],
        [
          "产出",
          "锅炉钢板 1"
        ],
        [
          "耗时",
          "3 小时"
        ]
      ]
    },
    {
      "id": "production-recipe-precision-gear",
      "category": "base",
      "title": "加工精密齿轮",
      "kind": "配方",
      "description": "用黄铜与锅炉钢板加工舰队所需的精密齿轮。",
      "tags": [
        "三级材料",
        "造船材料"
      ],
      "stats": [
        [
          "建筑",
          "铸造车间"
        ],
        [
          "投入",
          "黄铜 2、锅炉钢板 1"
        ],
        [
          "产出",
          "精密齿轮 1"
        ],
        [
          "耗时",
          "4 小时"
        ]
      ]
    },
    {
      "id": "worker-role-laborer",
      "category": "base",
      "title": "劳工",
      "kind": "工人工种",
      "description": "通用体力工人，工资低、加成小。",
      "tags": [
        "体力"
      ],
      "stats": [
        [
          "技能",
          "体力劳动"
        ],
        [
          "每周期工资",
          "0.5 金币"
        ],
        [
          "雇佣费",
          "8 金币"
        ],
        [
          "速度加成",
          "10%"
        ]
      ]
    },
    {
      "id": "worker-role-smelter",
      "category": "base",
      "title": "冶炼工",
      "kind": "工人工种",
      "description": "熟悉炉温与轧制的技术工人。",
      "tags": [
        "冶炼"
      ],
      "stats": [
        [
          "技能",
          "冶炼"
        ],
        [
          "每周期工资",
          "0.8 金币"
        ],
        [
          "雇佣费",
          "14 金币"
        ],
        [
          "速度加成",
          "15%"
        ]
      ]
    },
    {
      "id": "worker-role-engineer",
      "category": "base",
      "title": "工程师",
      "kind": "工人工种",
      "description": "负责精密加工的高级工人。",
      "tags": [
        "工程"
      ],
      "stats": [
        [
          "技能",
          "工程"
        ],
        [
          "每周期工资",
          "1.2 金币"
        ],
        [
          "雇佣费",
          "22 金币"
        ],
        [
          "速度加成",
          "20%"
        ]
      ]
    },
    {
      "id": "ruin-archetype-sunken-hall",
      "category": "ruins",
      "title": "沉没大厅",
      "kind": "遗迹",
      "description": "半淹的沿岸遗迹，适合第一次远征。",
      "tags": [
        "沿海",
        "起步"
      ],
      "stats": [
        [
          "难度",
          "2"
        ],
        [
          "房间数",
          "4"
        ],
        [
          "危险表",
          "轻微危险"
        ],
        [
          "遗物池",
          "黄铜罗盘、密封海图"
        ]
      ]
    },
    {
      "id": "ruin-archetype-collapsed-vault",
      "category": "ruins",
      "title": "坍塌金库",
      "kind": "遗迹",
      "description": "深层工业遗迹，危险更高，遗物更好。",
      "tags": [
        "工业",
        "深层"
      ],
      "stats": [
        [
          "难度",
          "3"
        ],
        [
          "房间数",
          "6"
        ],
        [
          "危险表",
          "严重危险"
        ],
        [
          "遗物池",
          "密封海图、蒸汽之心"
        ]
      ]
    },
    {
      "id": "room-template-flooded-hall",
      "category": "ruins",
      "title": "积水大厅",
      "kind": "房间",
      "description": "海水漫过石阶的大厅。",
      "tags": [
        "大厅",
        "积水"
      ],
      "stats": [
        [
          "规模",
          "大型"
        ],
        [
          "出口",
          "2 个"
        ],
        [
          "危险表",
          "轻微危险"
        ]
      ]
    },
    {
      "id": "room-template-collapsed-gallery",
      "category": "ruins",
      "title": "坍塌回廊",
      "kind": "房间",
      "description": "横梁断裂的回廊。",
      "tags": [
        "回廊",
        "坍塌"
      ],
      "stats": [
        [
          "规模",
          "中型"
        ],
        [
          "出口",
          "1 个"
        ],
        [
          "关联事件",
          "倒塌的横梁"
        ]
      ]
    },
    {
      "id": "room-template-old-shrine",
      "category": "ruins",
      "title": "古老神龛",
      "kind": "房间",
      "description": "被遗忘的小神龛。",
      "tags": [
        "神龛"
      ],
      "stats": [
        [
          "规模",
          "小型"
        ],
        [
          "出口",
          "1 个"
        ],
        [
          "关联事件",
          "古老神龛"
        ]
      ]
    },
    {
      "id": "room-template-sealed-vault",
      "category": "ruins",
      "title": "封闭金库",
      "kind": "房间",
      "description": "门缝里透出黄铜光。",
      "tags": [
        "金库"
      ],
      "stats": [
        [
          "规模",
          "中型"
        ],
        [
          "出口",
          "1 个"
        ],
        [
          "关联事件",
          "封闭金库"
        ]
      ]
    },
    {
      "id": "relic-brass-compass",
      "category": "ruins",
      "title": "黄铜罗盘",
      "kind": "遗物",
      "description": "指针始终指向传说中的航线。",
      "tags": [
        "导航",
        "稀有"
      ],
      "stats": [
        [
          "稀有度",
          "稀有"
        ],
        [
          "估值",
          "400 金币"
        ],
        [
          "效果",
          "导航 +2"
        ]
      ]
    },
    {
      "id": "relic-sealed-chart",
      "category": "ruins",
      "title": "密封海图",
      "kind": "遗物",
      "description": "一张标注着未知暗礁的旧海图。",
      "tags": [
        "制图",
        "稀有"
      ],
      "stats": [
        [
          "稀有度",
          "稀有"
        ],
        [
          "估值",
          "450 金币"
        ],
        [
          "效果",
          "制图 +3"
        ]
      ]
    },
    {
      "id": "relic-steam-heart",
      "category": "ruins",
      "title": "蒸汽之心",
      "kind": "遗物",
      "description": "仍在缓慢跳动的蒸汽机械核心。",
      "tags": [
        "工程",
        "传说"
      ],
      "stats": [
        [
          "稀有度",
          "传说"
        ],
        [
          "估值",
          "1200 金币"
        ],
        [
          "效果",
          "工程 +5、维护费 ×0.95"
        ]
      ]
    },
    {
      "id": "expedition-event-fallen-beam",
      "category": "ruins",
      "title": "倒塌的横梁",
      "kind": "远征事件",
      "description": "通道被巨梁堵住。",
      "tags": [
        "风险"
      ],
      "stats": [
        [
          "选项",
          "2 个"
        ],
        [
          "可能后果",
          "受伤、金钱收益"
        ]
      ]
    },
    {
      "id": "expedition-event-old-shrine",
      "category": "ruins",
      "title": "古老神龛",
      "kind": "远征事件",
      "description": "神龛上落满盐霜。",
      "tags": [
        "收益"
      ],
      "stats": [
        [
          "选项",
          "2 个"
        ],
        [
          "可能后果",
          "金钱收益、物品收益"
        ]
      ]
    },
    {
      "id": "expedition-event-sealed-vault",
      "category": "ruins",
      "title": "封闭金库",
      "kind": "远征事件",
      "description": "金库门被蒸汽锁死。",
      "tags": [
        "收益"
      ],
      "stats": [
        [
          "选项",
          "2 个"
        ],
        [
          "可能后果",
          "受伤、金钱收益"
        ]
      ]
    },
    {
      "id": "hazard-table-minor",
      "category": "ruins",
      "title": "轻微危险",
      "kind": "危险表",
      "description": "潮湿与松动石块。",
      "tags": [
        "轻微"
      ],
      "stats": [
        [
          "条目",
          "2 条"
        ],
        [
          "可能损失",
          "船体耐久、金钱"
        ]
      ]
    },
    {
      "id": "hazard-table-major",
      "category": "ruins",
      "title": "严重危险",
      "kind": "危险表",
      "description": "坍塌与蒸汽泄漏。",
      "tags": [
        "严重"
      ],
      "stats": [
        [
          "条目",
          "3 条"
        ],
        [
          "可能损失",
          "船体耐久、金钱、货物"
        ]
      ]
    },
    {
      "id": "glossary-load",
      "category": "glossary",
      "title": "载重",
      "kind": "术语",
      "description": "船只当前承载的总重量，由货物、模块与船员累加而成；接近船体载重上限时，航线风险会上升。",
      "tags": [
        "船只",
        "风险"
      ],
      "stats": []
    },
    {
      "id": "glossary-cargo-hold",
      "category": "glossary",
      "title": "货舱",
      "kind": "术语",
      "description": "装载货物的舱位，容量由装配的货舱模块决定；每个货舱槽只能安装一个货舱模块。",
      "tags": [
        "船只",
        "货物"
      ],
      "stats": []
    },
    {
      "id": "glossary-durability",
      "category": "glossary",
      "title": "耐久",
      "kind": "术语",
      "description": "船体结构的完整度。受损后需要在港口修理，耐久偏低会增加航程风险。",
      "tags": [
        "船只",
        "维修"
      ],
      "stats": []
    },
    {
      "id": "glossary-boiler-strategy",
      "category": "glossary",
      "title": "锅炉策略",
      "kind": "术语",
      "description": "出航前设定的三档锅炉工况：经济、标准、极速，在航速与煤水消耗之间取舍。",
      "tags": [
        "航行",
        "补给"
      ],
      "stats": []
    },
    {
      "id": "glossary-risk",
      "category": "glossary",
      "title": "风险",
      "kind": "术语",
      "description": "一次航程发生事故的可能性，受航线、载重、耐久、船员与天气共同影响，在抵达时结算。",
      "tags": [
        "航行",
        "概率"
      ],
      "stats": []
    },
    {
      "id": "glossary-reputation",
      "category": "glossary",
      "title": "声望",
      "kind": "术语",
      "description": "船队与各阵营势力分别累计的信誉。声望越高，该势力的态度越友好，能同时接取的委托也越多。",
      "tags": [
        "势力",
        "信誉"
      ],
      "stats": []
    },
    {
      "id": "glossary-clue",
      "category": "glossary",
      "title": "线索",
      "kind": "术语",
      "description": "酒馆里买到的搜索方向，会在海图上圈出目标区域；循线索出航，才能找到遗迹与秘境。",
      "tags": [
        "探索",
        "海图"
      ],
      "stats": []
    },
    {
      "id": "glossary-fog",
      "category": "glossary",
      "title": "迷雾",
      "kind": "术语",
      "description": "海图上尚未探明的区域，船只靠近才会逐步揭开；迷雾中的港口与地点需要亲自抵达或循线索发现。",
      "tags": [
        "探索",
        "海图"
      ],
      "stats": []
    },
    {
      "id": "glossary-time",
      "category": "glossary",
      "title": "时间",
      "kind": "术语",
      "description": "航行、生产与委托期限都以小时推进；补给、修理和货物加工都会占用时间。",
      "tags": [
        "航行",
        "生产"
      ],
      "stats": []
    },
    {
      "id": "glossary-slot",
      "category": "glossary",
      "title": "槽位",
      "kind": "术语",
      "description": "船体上按类型划分的安装位：锅炉、货舱、导航、安全、客舱；同槽位的设备可以直接替换。",
      "tags": [
        "船只",
        "改装"
      ],
      "stats": []
    },
    {
      "id": "glossary-contract",
      "category": "glossary",
      "title": "委托",
      "kind": "术语",
      "description": "港口发布的运输与载客任务，完成后获得报酬；随船的委托货箱不能自由买卖或抛弃。",
      "tags": [
        "贸易",
        "任务"
      ],
      "stats": []
    },
    {
      "id": "glossary-fleet",
      "category": "glossary",
      "title": "舰队",
      "kind": "术语",
      "description": "由多艘船组成的编队，由舰长指挥，可设定阵型与战术，并统一分配护航与猎袭的目标。",
      "tags": [
        "编队",
        "战斗"
      ],
      "stats": []
    }
  ]
};
