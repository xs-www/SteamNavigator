/*
 * AUTO-GENERATED FILE - do not edit by hand.
 * Source: /dev_mods/core (manifest, content, localization)
 * Regenerate: node SNModMaker/tools/sync-core-index.mjs
 */
(function (root) {
  'use strict';
  root.SN_CORE_INDEX = {
    "generated_at": "2026-10-19T00:24:02.180Z",
    "manifest": {
      "$schema": "https://steam-navigator.local/schema/mod-manifest-1.json",
      "id": "core",
      "name": "Steam Navigator Core Content",
      "version": "1.0.0",
      "api_version": "1.0",
      "type": "content",
      "load_priority": 0,
      "required": true,
      "dependencies": [],
      "optional_dependencies": [],
      "conflicts": [],
      "content": [
        "content/goods.json",
        "content/materials.json",
        "content/hulls.json",
        "content/boilers.json",
        "content/cargo_modules.json",
        "content/navigation_modules.json",
        "content/safety_modules.json",
        "content/cabins.json",
        "content/roles.json",
        "content/strategies.json",
        "content/port_archetypes.json",
        "content/map_profiles.json",
        "content/starting_builds.json",
        "content/contracts.json",
        "content/events.json"
      ],
      "localization": [
        "localization/zh_CN.json",
        "localization/en.json"
      ],
      "assets": {
        "icon.coal": "assets/icons/coal.png",
        "icon.water": "assets/icons/water.png",
        "icon.money": "assets/icons/money.png",
        "banner.port.iron_harbor": "assets/ports/iron_harbor_banner.png"
      },
      "authors": [
        "Steam Navigator Team"
      ],
      "license": "Proprietary",
      "description": "Official MVP content: ports, goods, ships, contracts and events.",
      "capabilities": [
        "content.contract.passenger.v1",
        "content.event.choice_pool.v1"
      ]
    },
    "contentFiles": {
      "content/goods.json": {
        "schema_version": "1.0",
        "content_type": "goods",
        "definitions": [
          {
            "id": "core:good/iron_ore",
            "name_key": "good.core.iron_ore.name",
            "description_key": "good.core.iron_ore.description",
            "tags": [
              "good.trade",
              "good.bulk",
              "good.shipbuilding"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 3,
              "base_price": 42,
              "base_stock": 120,
              "price_elasticity": 0.16,
              "spawn_weight": 1,
              "crafting_material": true,
              "category": "ore"
            }
          },
          {
            "id": "core:good/brass",
            "name_key": "good.core.brass.name",
            "description_key": "good.core.brass.description",
            "tags": [
              "good.trade",
              "good.shipbuilding"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 2,
              "base_price": 88,
              "base_stock": 80,
              "price_elasticity": 0.18,
              "spawn_weight": 1,
              "crafting_material": true,
              "category": "metal"
            }
          },
          {
            "id": "core:good/textiles",
            "name_key": "good.core.textiles.name",
            "description_key": "good.core.textiles.description",
            "tags": [
              "good.trade",
              "good.consumer"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 1,
              "base_price": 64,
              "base_stock": 90,
              "price_elasticity": 0.15,
              "spawn_weight": 1,
              "category": "textile"
            }
          },
          {
            "id": "core:good/spices",
            "name_key": "good.core.spices.name",
            "description_key": "good.core.spices.description",
            "tags": [
              "good.trade",
              "good.luxury"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 0.5,
              "base_price": 150,
              "base_stock": 55,
              "price_elasticity": 0.12,
              "spawn_weight": 0.8,
              "category": "luxury"
            }
          },
          {
            "id": "core:good/timber",
            "name_key": "good.core.timber.name",
            "description_key": "good.core.timber.description",
            "tags": [
              "good.trade",
              "good.bulk",
              "good.shipbuilding"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 2.5,
              "base_price": 36,
              "base_stock": 130,
              "price_elasticity": 0.17,
              "spawn_weight": 1,
              "crafting_material": true,
              "category": "wood"
            }
          },
          {
            "id": "core:good/glassware",
            "name_key": "good.core.glassware.name",
            "description_key": "good.core.glassware.description",
            "tags": [
              "good.trade",
              "good.fragile"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 1.5,
              "base_price": 105,
              "base_stock": 60,
              "price_elasticity": 0.2,
              "spawn_weight": 0.9,
              "category": "craft"
            }
          },
          {
            "id": "core:good/contract_freight",
            "name_key": "good.core.contract_freight.name",
            "description_key": "good.core.contract_freight.description",
            "tags": [
              "good.contract"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 1,
              "base_price": 1,
              "base_stock": 1,
              "price_elasticity": 0.1,
              "spawn_weight": 0,
              "category": "contract"
            }
          },
          {
            "id": "core:good/coal",
            "name_key": "good.core.coal.name",
            "description_key": "good.core.coal.description",
            "tags": [
              "good.supply",
              "supply.coal",
              "good.bulk"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 1,
              "base_price": 4,
              "base_stock": 140,
              "price_elasticity": 0.12,
              "spawn_weight": 0,
              "category": "supply"
            }
          },
          {
            "id": "core:good/water",
            "name_key": "good.core.water.name",
            "description_key": "good.core.water.description",
            "tags": [
              "good.supply",
              "supply.water",
              "good.bulk"
            ],
            "enabled": true,
            "data": {
              "unit_weight": 1,
              "base_price": 2,
              "base_stock": 160,
              "price_elasticity": 0.1,
              "spawn_weight": 0,
              "category": "supply"
            }
          }
        ]
      },
      "content/materials.json": {
        "schema_version": "1.0",
        "content_type": "materials",
        "definitions": [
          {
            "id": "core:material/boiler_plate",
            "name_key": "material.core.boiler_plate.name",
            "description_key": "material.core.boiler_plate.description",
            "tags": [
              "material.shipbuilding",
              "material.tier2"
            ],
            "enabled": true,
            "data": {
              "tier": 2,
              "unit_weight": 2,
              "base_price": 120,
              "base_stock": 60,
              "price_elasticity": 0.15,
              "category": "plate"
            }
          },
          {
            "id": "core:material/precision_gear",
            "name_key": "material.core.precision_gear.name",
            "description_key": "material.core.precision_gear.description",
            "tags": [
              "material.shipbuilding",
              "material.tier3"
            ],
            "enabled": true,
            "data": {
              "tier": 3,
              "unit_weight": 0.8,
              "base_price": 190,
              "base_stock": 40,
              "price_elasticity": 0.12,
              "category": "mechanism"
            }
          },
          {
            "id": "core:material/sealing_compound",
            "name_key": "material.core.sealing_compound.name",
            "description_key": "material.core.sealing_compound.description",
            "tags": [
              "material.shipbuilding",
              "material.tier1"
            ],
            "enabled": true,
            "data": {
              "tier": 1,
              "unit_weight": 0.5,
              "base_price": 75,
              "base_stock": 70,
              "price_elasticity": 0.1,
              "category": "compound"
            }
          }
        ]
      },
      "content/hulls.json": {
        "schema_version": "1.0",
        "content_type": "hulls",
        "definitions": [
          {
            "id": "core:hull/small_efficient",
            "name_key": "module.core.small_efficient_hull.name",
            "description_key": "module.core.small_efficient_hull.description",
            "tags": [
              "module.hull",
              "module.small",
              "module.efficient",
              "ship.small"
            ],
            "enabled": true,
            "data": {
              "tier": 1,
              "weight": 22,
              "purchase_price": 380,
              "craft_time_hours": 4,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 4
                },
                {
                  "id": "core:good/iron_ore",
                  "amount": 2
                }
              ],
              "base_speed": 14,
              "max_weight": 100,
              "max_durability": 100,
              "cargo_slots": 1,
              "cabin_slots": 0,
              "base_risk": 0.025,
              "size_tag": "small"
            }
          },
          {
            "id": "core:hull/medium_standard",
            "name_key": "module.core.medium_standard_hull.name",
            "description_key": "module.core.medium_standard_hull.description",
            "tags": [
              "module.hull",
              "module.medium",
              "module.standard",
              "ship.medium"
            ],
            "enabled": true,
            "data": {
              "tier": 2,
              "weight": 38,
              "purchase_price": 1100,
              "craft_time_hours": 8,
              "craft_cost": 220,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 8
                },
                {
                  "id": "core:material/boiler_plate",
                  "amount": 3
                }
              ],
              "base_speed": 15,
              "max_weight": 165,
              "max_durability": 140,
              "cargo_slots": 2,
              "cabin_slots": 1,
              "base_risk": 0.02,
              "size_tag": "medium"
            }
          },
          {
            "id": "core:hull/large_efficient",
            "name_key": "module.core.large_efficient_hull.name",
            "description_key": "module.core.large_efficient_hull.description",
            "tags": [
              "module.hull",
              "module.large",
              "module.efficient",
              "ship.large"
            ],
            "enabled": true,
            "data": {
              "tier": 3,
              "weight": 60,
              "purchase_price": 2600,
              "craft_time_hours": 12,
              "craft_cost": 520,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 14
                },
                {
                  "id": "core:material/boiler_plate",
                  "amount": 6
                },
                {
                  "id": "core:material/precision_gear",
                  "amount": 2
                }
              ],
              "base_speed": 14,
              "max_weight": 260,
              "max_durability": 200,
              "cargo_slots": 3,
              "cabin_slots": 1,
              "base_risk": 0.02,
              "size_tag": "large"
            }
          },
          {
            "id": "core:hull/large_performance",
            "name_key": "module.core.large_performance_hull.name",
            "description_key": "module.core.large_performance_hull.description",
            "tags": [
              "module.hull",
              "module.large",
              "module.performance",
              "ship.large"
            ],
            "enabled": true,
            "data": {
              "tier": 3,
              "weight": 66,
              "purchase_price": 3400,
              "craft_time_hours": 14,
              "craft_cost": 680,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 12
                },
                {
                  "id": "core:material/boiler_plate",
                  "amount": 8
                },
                {
                  "id": "core:material/precision_gear",
                  "amount": 4
                }
              ],
              "base_speed": 17,
              "max_weight": 240,
              "max_durability": 180,
              "cargo_slots": 3,
              "cabin_slots": 1,
              "base_risk": 0.025,
              "size_tag": "large"
            }
          }
        ]
      },
      "content/boilers.json": {
        "schema_version": "1.0",
        "content_type": "boilers",
        "definitions": [
          {
            "id": "core:boiler/small_efficient",
            "name_key": "module.core.small_efficient_boiler.name",
            "description_key": "module.core.small_efficient_boiler.description",
            "tags": [
              "module.boiler",
              "module.small",
              "module.efficient"
            ],
            "enabled": true,
            "data": {
              "tier": 1,
              "weight": 8,
              "purchase_price": 420,
              "craft_time_hours": 4,
              "materials": [
                {
                  "id": "core:good/brass",
                  "amount": 4
                },
                {
                  "id": "core:material/sealing_compound",
                  "amount": 2
                }
              ],
              "speed_mul": 0.94,
              "coal_rate": 0.3,
              "water_rate": 0.22
            }
          },
          {
            "id": "core:boiler/standard",
            "name_key": "module.core.standard_boiler.name",
            "description_key": "module.core.standard_boiler.description",
            "tags": [
              "module.boiler",
              "module.standard"
            ],
            "enabled": true,
            "data": {
              "tier": 1,
              "weight": 10,
              "purchase_price": 650,
              "craft_time_hours": 5,
              "materials": [
                {
                  "id": "core:good/brass",
                  "amount": 6
                },
                {
                  "id": "core:material/boiler_plate",
                  "amount": 2
                }
              ],
              "speed_mul": 1,
              "coal_rate": 0.4,
              "water_rate": 0.28
            }
          },
          {
            "id": "core:boiler/performance",
            "name_key": "module.core.performance_boiler.name",
            "description_key": "module.core.performance_boiler.description",
            "tags": [
              "module.boiler",
              "module.performance"
            ],
            "enabled": true,
            "data": {
              "tier": 2,
              "weight": 14,
              "purchase_price": 1200,
              "craft_time_hours": 7,
              "craft_cost": 180,
              "materials": [
                {
                  "id": "core:good/brass",
                  "amount": 8
                },
                {
                  "id": "core:material/boiler_plate",
                  "amount": 4
                },
                {
                  "id": "core:material/precision_gear",
                  "amount": 1
                }
              ],
              "speed_mul": 1.18,
              "coal_rate": 0.58,
              "water_rate": 0.36
            }
          }
        ]
      },
      "content/cargo_modules.json": {
        "schema_version": "1.0",
        "content_type": "cargo_modules",
        "definitions": [
          {
            "id": "core:cargo_module/small_hold",
            "name_key": "module.core.small_hold.name",
            "description_key": "module.core.small_hold.description",
            "tags": [
              "module.cargo",
              "module.small",
              "module.efficient"
            ],
            "enabled": true,
            "data": {
              "tier": 1,
              "weight": 6,
              "purchase_price": 260,
              "craft_time_hours": 3,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 3
                }
              ],
              "capacity": 32
            }
          },
          {
            "id": "core:cargo_module/medium_hold",
            "name_key": "module.core.medium_hold.name",
            "description_key": "module.core.medium_hold.description",
            "tags": [
              "module.cargo",
              "module.medium",
              "module.standard"
            ],
            "enabled": true,
            "data": {
              "tier": 2,
              "weight": 12,
              "purchase_price": 900,
              "craft_time_hours": 6,
              "craft_cost": 160,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 6
                },
                {
                  "id": "core:material/boiler_plate",
                  "amount": 2
                }
              ],
              "capacity": 68
            }
          },
          {
            "id": "core:cargo_module/large_hold",
            "name_key": "module.core.large_hold.name",
            "description_key": "module.core.large_hold.description",
            "tags": [
              "module.cargo",
              "module.large",
              "module.performance"
            ],
            "enabled": true,
            "data": {
              "tier": 3,
              "weight": 20,
              "purchase_price": 1800,
              "craft_time_hours": 9,
              "craft_cost": 320,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 10
                },
                {
                  "id": "core:material/boiler_plate",
                  "amount": 4
                }
              ],
              "capacity": 110
            }
          }
        ]
      },
      "content/navigation_modules.json": {
        "schema_version": "1.0",
        "content_type": "navigation_modules",
        "definitions": [
          {
            "id": "core:navigation_module/spyglass",
            "name_key": "module.core.spyglass.name",
            "description_key": "module.core.spyglass.description",
            "tags": [
              "module.navigation",
              "module.efficient"
            ],
            "enabled": true,
            "data": {
              "tier": 1,
              "weight": 2,
              "purchase_price": 300,
              "craft_time_hours": 2,
              "materials": [
                {
                  "id": "core:good/brass",
                  "amount": 2
                }
              ],
              "risk_add": -0.012,
              "speed_mul": 1,
              "reveal_facilities": false
            }
          },
          {
            "id": "core:navigation_module/chart_room",
            "name_key": "module.core.chart_room.name",
            "description_key": "module.core.chart_room.description",
            "tags": [
              "module.navigation",
              "module.performance"
            ],
            "enabled": true,
            "data": {
              "tier": 2,
              "weight": 5,
              "purchase_price": 850,
              "craft_time_hours": 5,
              "craft_cost": 140,
              "materials": [
                {
                  "id": "core:good/brass",
                  "amount": 3
                },
                {
                  "id": "core:material/sealing_compound",
                  "amount": 2
                }
              ],
              "risk_add": -0.022,
              "speed_mul": 1.03,
              "reveal_facilities": true
            }
          }
        ]
      },
      "content/safety_modules.json": {
        "schema_version": "1.0",
        "content_type": "safety_modules",
        "definitions": [
          {
            "id": "core:safety_module/lifeboat",
            "name_key": "module.core.lifeboat.name",
            "description_key": "module.core.lifeboat.description",
            "tags": [
              "module.safety",
              "module.efficient"
            ],
            "enabled": true,
            "data": {
              "tier": 1,
              "weight": 4,
              "purchase_price": 280,
              "craft_time_hours": 2,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 3
                }
              ],
              "risk_add": -0.015,
              "damage_mul": 0.9,
              "repair_cost_mul": 1
            }
          },
          {
            "id": "core:safety_module/safety_valve",
            "name_key": "module.core.safety_valve.name",
            "description_key": "module.core.safety_valve.description",
            "tags": [
              "module.safety",
              "module.performance"
            ],
            "enabled": true,
            "data": {
              "tier": 2,
              "weight": 6,
              "purchase_price": 760,
              "craft_time_hours": 4,
              "craft_cost": 130,
              "materials": [
                {
                  "id": "core:good/brass",
                  "amount": 4
                },
                {
                  "id": "core:material/sealing_compound",
                  "amount": 3
                }
              ],
              "risk_add": -0.03,
              "damage_mul": 0.75,
              "repair_cost_mul": 0.85
            }
          }
        ]
      },
      "content/cabins.json": {
        "schema_version": "1.0",
        "content_type": "cabins",
        "definitions": [
          {
            "id": "core:cabin/passenger_cabin",
            "name_key": "module.core.passenger_cabin.name",
            "description_key": "module.core.passenger_cabin.description",
            "tags": [
              "module.cabin",
              "module.passenger"
            ],
            "enabled": true,
            "data": {
              "tier": 1,
              "weight": 12,
              "purchase_price": 600,
              "craft_time_hours": 4,
              "materials": [
                {
                  "id": "core:good/timber",
                  "amount": 4
                },
                {
                  "id": "core:good/textiles",
                  "amount": 3
                }
              ],
              "passenger_capacity": 4
            }
          }
        ]
      },
      "content/roles.json": {
        "schema_version": "1.0",
        "content_type": "roles",
        "definitions": [
          {
            "id": "core:role/engineer_basic",
            "name_key": "role.core.engineer_basic.name",
            "description_key": "role.core.engineer_basic.description",
            "tags": [
              "role.engineer",
              "role.crew"
            ],
            "enabled": true,
            "data": {
              "kind": "engineer",
              "wage_per_voyage": 40,
              "hire_cost": 100,
              "modifiers": [
                {
                  "stat": "risk",
                  "op": "add",
                  "value": -0.015
                },
                {
                  "stat": "repair_cost",
                  "op": "mul",
                  "value": 0.85
                },
                {
                  "stat": "damage",
                  "op": "mul",
                  "value": 0.95
                }
              ]
            }
          },
          {
            "id": "core:role/navigator_basic",
            "name_key": "role.core.navigator_basic.name",
            "description_key": "role.core.navigator_basic.description",
            "tags": [
              "role.navigator",
              "role.crew"
            ],
            "enabled": true,
            "data": {
              "kind": "navigator",
              "wage_per_voyage": 35,
              "hire_cost": 100,
              "modifiers": [
                {
                  "stat": "risk",
                  "op": "add",
                  "value": -0.02
                },
                {
                  "stat": "speed",
                  "op": "mul",
                  "value": 1.03
                }
              ]
            }
          }
        ]
      },
      "content/strategies.json": {
        "schema_version": "1.0",
        "content_type": "strategies",
        "definitions": [
          {
            "id": "core:strategy/economic",
            "name_key": "strategy.core.economic.name",
            "description_key": "strategy.core.economic.description",
            "tags": [
              "strategy.economy",
              "strategy.slow"
            ],
            "enabled": true,
            "data": {
              "speed_mul": 0.8,
              "coal_mul": 0.68,
              "water_mul": 0.78,
              "risk_add": -0.01
            }
          },
          {
            "id": "core:strategy/standard",
            "name_key": "strategy.core.standard.name",
            "description_key": "strategy.core.standard.description",
            "tags": [
              "strategy.standard",
              "strategy.balanced"
            ],
            "enabled": true,
            "data": {
              "speed_mul": 1,
              "coal_mul": 1,
              "water_mul": 1,
              "risk_add": 0
            }
          },
          {
            "id": "core:strategy/fast",
            "name_key": "strategy.core.fast.name",
            "description_key": "strategy.core.fast.description",
            "tags": [
              "strategy.fast",
              "strategy.risky"
            ],
            "enabled": true,
            "data": {
              "speed_mul": 1.28,
              "coal_mul": 1.8,
              "water_mul": 1.6,
              "risk_add": 0.06
            }
          }
        ]
      },
      "content/port_archetypes.json": {
        "schema_version": "1.0",
        "content_type": "port_archetypes",
        "definitions": [
          {
            "id": "core:port_archetype/iron_harbor",
            "name_key": "port.core.iron_harbor.name",
            "description_key": "port.core.iron_harbor.description",
            "tags": [
              "port.hub",
              "port.industrial",
              "port.shipyard"
            ],
            "enabled": true,
            "data": {
              "size": "medium",
              "banner_asset": "banner.port.iron_harbor",
              "facilities": [
                "exchange",
                "contracts",
                "supply",
                "shipyard"
              ],
              "market": [
                {
                  "good": "core:good/iron_ore",
                  "stock_range": [
                    70,
                    130
                  ]
                },
                {
                  "good": "core:good/timber",
                  "stock_range": [
                    80,
                    140
                  ]
                },
                {
                  "good": "core:good/brass",
                  "stock_range": [
                    40,
                    90
                  ],
                  "price_bias": 0.95
                },
                {
                  "good": "core:material/boiler_plate",
                  "stock_range": [
                    30,
                    70
                  ]
                },
                {
                  "good": "core:material/sealing_compound",
                  "stock_range": [
                    40,
                    80
                  ]
                },
                {
                  "good": "core:material/precision_gear",
                  "stock_range": [
                    10,
                    25
                  ]
                }
              ]
            }
          },
          {
            "id": "core:port_archetype/spice_port",
            "name_key": "port.core.spice_port.name",
            "description_key": "port.core.spice_port.description",
            "tags": [
              "port.trade",
              "port.intel"
            ],
            "enabled": true,
            "data": {
              "size": "small",
              "facilities": [
                "exchange",
                "contracts",
                "supply",
                "intel"
              ],
              "market": [
                {
                  "good": "core:good/spices",
                  "stock_range": [
                    30,
                    70
                  ],
                  "price_bias": 0.9
                },
                {
                  "good": "core:good/textiles",
                  "stock_range": [
                    50,
                    110
                  ]
                },
                {
                  "good": "core:good/glassware",
                  "stock_range": [
                    30,
                    80
                  ]
                },
                {
                  "good": "core:material/sealing_compound",
                  "stock_range": [
                    30,
                    60
                  ]
                }
              ]
            }
          },
          {
            "id": "core:port_archetype/free_town",
            "name_key": "port.core.free_town.name",
            "description_key": "port.core.free_town.description",
            "tags": [
              "port.hub",
              "port.trade",
              "port.shipyard",
              "port.intel"
            ],
            "enabled": true,
            "data": {
              "size": "medium",
              "facilities": [
                "exchange",
                "contracts",
                "supply",
                "shipyard",
                "intel"
              ],
              "market": [
                {
                  "good": "core:good/brass",
                  "stock_range": [
                    40,
                    90
                  ]
                },
                {
                  "good": "core:good/timber",
                  "stock_range": [
                    60,
                    120
                  ]
                },
                {
                  "good": "core:good/textiles",
                  "stock_range": [
                    50,
                    100
                  ]
                },
                {
                  "good": "core:good/spices",
                  "stock_range": [
                    25,
                    60
                  ]
                },
                {
                  "good": "core:good/glassware",
                  "stock_range": [
                    30,
                    75
                  ]
                },
                {
                  "good": "core:material/boiler_plate",
                  "stock_range": [
                    25,
                    60
                  ]
                },
                {
                  "good": "core:material/precision_gear",
                  "stock_range": [
                    10,
                    25
                  ]
                }
              ]
            }
          },
          {
            "id": "core:port_archetype/fishing_village",
            "name_key": "port.core.fishing_village.name",
            "description_key": "port.core.fishing_village.description",
            "tags": [
              "port.rural",
              "port.supply"
            ],
            "enabled": true,
            "data": {
              "size": "small",
              "facilities": [
                "exchange",
                "contracts",
                "supply"
              ],
              "market": [
                {
                  "good": "core:good/timber",
                  "stock_range": [
                    90,
                    150
                  ],
                  "price_bias": 0.9
                },
                {
                  "good": "core:good/iron_ore",
                  "stock_range": [
                    60,
                    110
                  ]
                },
                {
                  "good": "core:good/textiles",
                  "stock_range": [
                    40,
                    90
                  ]
                },
                {
                  "good": "core:material/sealing_compound",
                  "stock_range": [
                    30,
                    70
                  ]
                }
              ]
            }
          },
          {
            "id": "core:port_archetype/glass_port",
            "name_key": "port.core.glass_port.name",
            "description_key": "port.core.glass_port.description",
            "tags": [
              "port.craft",
              "port.intel"
            ],
            "enabled": true,
            "data": {
              "size": "small",
              "facilities": [
                "exchange",
                "contracts",
                "supply",
                "intel"
              ],
              "market": [
                {
                  "good": "core:good/glassware",
                  "stock_range": [
                    40,
                    90
                  ],
                  "price_bias": 0.9
                },
                {
                  "good": "core:good/brass",
                  "stock_range": [
                    35,
                    80
                  ]
                },
                {
                  "good": "core:good/spices",
                  "stock_range": [
                    25,
                    55
                  ]
                },
                {
                  "good": "core:material/precision_gear",
                  "stock_range": [
                    15,
                    40
                  ]
                }
              ]
            }
          }
        ]
      },
      "content/map_profiles.json": {
        "schema_version": "1.0",
        "content_type": "map_profiles",
        "definitions": [
          {
            "id": "core:map_profile/standard",
            "name_key": "map_profile.core.standard.name",
            "description_key": "map_profile.core.standard.description",
            "tags": [
              "map.standard",
              "map.mvp"
            ],
            "enabled": true,
            "data": {
              "port_count_range": [
                4,
                5
              ],
              "edge_count_range": [
                5,
                7
              ],
              "distance_range": [
                90,
                220
              ],
              "route_risk_range": [
                0.01,
                0.055
              ],
              "archetypes": [
                "core:port_archetype/iron_harbor",
                "core:port_archetype/spice_port",
                "core:port_archetype/free_town",
                "core:port_archetype/fishing_village",
                "core:port_archetype/glass_port"
              ],
              "port_name_keys": [
                "port_name.core.iron_harbor",
                "port_name.core.spice_port",
                "port_name.core.free_town",
                "port_name.core.fishing_village",
                "port_name.core.glass_port",
                "port_name.core.mist_cove"
              ],
              "start_archetype_tags": [
                "port.hub"
              ],
              "required_facility_tags": [
                "port.shipyard",
                "port.intel"
              ],
              "required_facility_max_edges": 2,
              "npc_count_range": [
                2,
                3
              ],
              "npc_cargo_range": [
                8,
                24
              ],
              "supply_prices": {
                "coal": 4,
                "water": 2,
                "repair_per_point": 6
              },
              "loan": {
                "limit": 400,
                "interest_rate": 0.1,
                "term_hours": 96
              },
              "intel_cost": 25,
              "trade_margin": 0.95,
              "player_trade_impact": 0.35,
              "default_starting_build": "core:starting_build/steady"
            }
          }
        ]
      },
      "content/starting_builds.json": {
        "schema_version": "1.0",
        "content_type": "starting_builds",
        "definitions": [
          {
            "id": "core:starting_build/steady",
            "name_key": "starting_build.core.steady.name",
            "description_key": "starting_build.core.steady.description",
            "tags": [
              "starting_build.efficient",
              "starting_build.safe"
            ],
            "enabled": true,
            "data": {
              "money": 900,
              "reputation": 0,
              "hull": "core:hull/small_efficient",
              "boiler": "core:boiler/small_efficient",
              "cargo_modules": [
                "core:cargo_module/small_hold"
              ],
              "navigation_module": "core:navigation_module/spyglass",
              "safety_module": "core:safety_module/lifeboat",
              "engineer": "core:role/engineer_basic",
              "navigator": "core:role/navigator_basic",
              "coal": 26,
              "water": 18,
              "durability_ratio": 1
            }
          },
          {
            "id": "core:starting_build/swift",
            "name_key": "starting_build.core.swift.name",
            "description_key": "starting_build.core.swift.description",
            "tags": [
              "starting_build.performance",
              "starting_build.risky"
            ],
            "enabled": true,
            "data": {
              "money": 700,
              "reputation": 0,
              "hull": "core:hull/small_efficient",
              "boiler": "core:boiler/performance",
              "cargo_modules": [
                "core:cargo_module/small_hold"
              ],
              "navigation_module": "core:navigation_module/spyglass",
              "navigator": "core:role/navigator_basic",
              "coal": 20,
              "water": 14,
              "durability_ratio": 0.9
            }
          }
        ]
      },
      "content/contracts.json": {
        "schema_version": "1.0",
        "content_type": "contracts",
        "definitions": [
          {
            "id": "core:contract/main_01",
            "name_key": "contract.core.main_01.name",
            "description_key": "contract.core.main_01.description",
            "tags": [
              "contract.main",
              "contract.cargo",
              "contract.tutorial"
            ],
            "enabled": true,
            "data": {
              "kind": "main",
              "sequence": 1,
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "cargo",
                  "name_key": "contract.core.main_01.payload",
                  "cargo_item_id": "core:good/contract_freight",
                  "weight_range": [
                    8,
                    12
                  ]
                }
              ],
              "deadline_formula": "tutorial_first",
              "rewards": {
                "base_money": [
                  220,
                  260
                ],
                "on_time_bonus": [
                  80,
                  100
                ],
                "reputation": 1,
                "unlock_ids": []
              },
              "requires_completed": []
            }
          },
          {
            "id": "core:contract/main_02",
            "name_key": "contract.core.main_02.name",
            "description_key": "contract.core.main_02.description",
            "tags": [
              "contract.main",
              "contract.cargo",
              "contract.tutorial"
            ],
            "enabled": true,
            "data": {
              "kind": "main",
              "sequence": 2,
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "cargo",
                  "name_key": "contract.core.main_02.payload",
                  "cargo_item_id": "core:good/contract_freight",
                  "weight_range": [
                    10,
                    14
                  ]
                }
              ],
              "deadline_formula": "tutorial_trade",
              "rewards": {
                "base_money": [
                  300,
                  340
                ],
                "on_time_bonus": [
                  120,
                  140
                ],
                "reputation": 1,
                "unlock_ids": []
              },
              "requires_completed": [
                "core:contract/main_01"
              ]
            }
          },
          {
            "id": "core:contract/main_03",
            "name_key": "contract.core.main_03.name",
            "description_key": "contract.core.main_03.description",
            "tags": [
              "contract.main",
              "contract.cargo",
              "contract.tutorial"
            ],
            "enabled": true,
            "data": {
              "kind": "main",
              "sequence": 3,
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "cargo",
                  "name_key": "contract.core.main_03.payload",
                  "cargo_item_id": "core:good/contract_freight",
                  "weight_range": [
                    12,
                    16
                  ]
                }
              ],
              "deadline_formula": "tutorial_craft",
              "rewards": {
                "base_money": [
                  380,
                  420
                ],
                "on_time_bonus": [
                  150,
                  180
                ],
                "reputation": 1,
                "unlock_ids": [
                  "core:hull/medium_standard",
                  "core:cargo_module/medium_hold"
                ]
              },
              "requires_completed": [
                "core:contract/main_02"
              ]
            }
          },
          {
            "id": "core:contract/main_04",
            "name_key": "contract.core.main_04.name",
            "description_key": "contract.core.main_04.description",
            "tags": [
              "contract.main",
              "contract.passenger",
              "contract.tutorial"
            ],
            "enabled": true,
            "data": {
              "kind": "main",
              "sequence": 4,
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "passenger",
                  "name_key": "contract.core.main_04.payload",
                  "count_range": [
                    2,
                    3
                  ]
                }
              ],
              "deadline_formula": "passenger_run",
              "rewards": {
                "base_money": [
                  420,
                  460
                ],
                "on_time_bonus": [
                  180,
                  220
                ],
                "reputation": 2,
                "unlock_ids": [
                  "core:safety_module/safety_valve"
                ]
              },
              "requires_completed": [
                "core:contract/main_03"
              ]
            }
          },
          {
            "id": "core:contract/main_05",
            "name_key": "contract.core.main_05.name",
            "description_key": "contract.core.main_05.description",
            "tags": [
              "contract.main",
              "contract.cargo",
              "contract.passenger",
              "contract.finale"
            ],
            "enabled": true,
            "data": {
              "kind": "main",
              "sequence": 5,
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "cargo",
                  "name_key": "contract.core.main_05.cargo",
                  "cargo_item_id": "core:good/contract_freight",
                  "weight_range": [
                    22,
                    30
                  ]
                },
                {
                  "kind": "passenger",
                  "name_key": "contract.core.main_05.passengers",
                  "count_range": [
                    2,
                    4
                  ]
                }
              ],
              "deadline_formula": "balanced_finale",
              "rewards": {
                "base_money": [
                  900,
                  1200
                ],
                "on_time_bonus": [
                  500,
                  700
                ],
                "reputation": 2,
                "unlock_ids": [
                  "core:hull/large_efficient",
                  "core:hull/large_performance"
                ]
              },
              "requires_completed": [
                "core:contract/main_04"
              ]
            }
          },
          {
            "id": "core:contract/normal_cargo_short",
            "name_key": "contract.core.normal_cargo_short.name",
            "description_key": "contract.core.normal_cargo_short.description",
            "tags": [
              "contract.normal",
              "contract.cargo"
            ],
            "enabled": true,
            "data": {
              "kind": "normal",
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "cargo",
                  "cargo_item_id": "core:good/contract_freight",
                  "weight_range": [
                    6,
                    10
                  ]
                }
              ],
              "deadline_formula": "normal_standard",
              "rewards": {
                "base_money": [
                  140,
                  180
                ],
                "on_time_bonus": [
                  40,
                  60
                ],
                "reputation": 1,
                "unlock_ids": []
              },
              "requires_completed": []
            }
          },
          {
            "id": "core:contract/normal_cargo_long",
            "name_key": "contract.core.normal_cargo_long.name",
            "description_key": "contract.core.normal_cargo_long.description",
            "tags": [
              "contract.normal",
              "contract.cargo"
            ],
            "enabled": true,
            "data": {
              "kind": "normal",
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "cargo",
                  "cargo_item_id": "core:good/contract_freight",
                  "weight_range": [
                    14,
                    20
                  ]
                }
              ],
              "deadline_formula": "normal_standard",
              "rewards": {
                "base_money": [
                  240,
                  300
                ],
                "on_time_bonus": [
                  60,
                  90
                ],
                "reputation": 1,
                "unlock_ids": []
              },
              "requires_completed": []
            }
          },
          {
            "id": "core:contract/normal_passenger",
            "name_key": "contract.core.normal_passenger.name",
            "description_key": "contract.core.normal_passenger.description",
            "tags": [
              "contract.normal",
              "contract.passenger"
            ],
            "enabled": true,
            "data": {
              "kind": "normal",
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "passenger",
                  "count_range": [
                    1,
                    2
                  ]
                }
              ],
              "deadline_formula": "normal_standard",
              "rewards": {
                "base_money": [
                  180,
                  220
                ],
                "on_time_bonus": [
                  50,
                  70
                ],
                "reputation": 1,
                "unlock_ids": []
              },
              "requires_completed": []
            }
          },
          {
            "id": "core:contract/normal_urgent",
            "name_key": "contract.core.normal_urgent.name",
            "description_key": "contract.core.normal_urgent.description",
            "tags": [
              "contract.normal",
              "contract.cargo",
              "contract.urgent"
            ],
            "enabled": true,
            "data": {
              "kind": "normal",
              "generator": "route_pair",
              "constraints": {
                "requires_discovered_origin": true,
                "min_route_edges": 1,
                "max_route_edges": 1,
                "required_port_tags": []
              },
              "payloads": [
                {
                  "kind": "cargo",
                  "cargo_item_id": "core:good/contract_freight",
                  "weight_range": [
                    8,
                    12
                  ]
                }
              ],
              "deadline_formula": "normal_urgent",
              "rewards": {
                "base_money": [
                  220,
                  260
                ],
                "on_time_bonus": [
                  100,
                  140
                ],
                "reputation": 1,
                "unlock_ids": []
              },
              "requires_completed": []
            }
          }
        ]
      },
      "content/events.json": {
        "schema_version": "1.0",
        "content_type": "events",
        "definitions": [
          {
            "id": "core:event/boiler_overheat",
            "name_key": "event.core.boiler_overheat.name",
            "description_key": "event.core.boiler_overheat.description",
            "tags": [
              "event.risk",
              "event.mechanical"
            ],
            "enabled": true,
            "data": {
              "trigger": "voyage_risk",
              "category": "mechanical",
              "weight": 1,
              "base_delay_hours": 0,
              "options": [
                {
                  "id": "water_cooling",
                  "name_key": "event.core.boiler_overheat.water_cooling",
                  "weight": 1,
                  "effects": [
                    {
                      "op": "remove_water",
                      "amount": 6
                    },
                    {
                      "op": "damage_ship",
                      "amount": 2
                    },
                    {
                      "op": "emit_notice",
                      "text_key": "notice.core.overheat.cooled"
                    }
                  ]
                },
                {
                  "id": "stop_repair",
                  "name_key": "event.core.boiler_overheat.stop_repair",
                  "weight": 1,
                  "effects": [
                    {
                      "op": "add_delay_hours",
                      "amount": 5
                    },
                    {
                      "op": "repair_ship",
                      "amount": 4
                    },
                    {
                      "op": "emit_notice",
                      "text_key": "notice.core.overheat.repaired"
                    }
                  ]
                },
                {
                  "id": "paid_repair",
                  "name_key": "event.core.boiler_overheat.paid_repair",
                  "weight": 1,
                  "condition": {
                    "op": "money_gte",
                    "value": 90
                  },
                  "effects": [
                    {
                      "op": "remove_money",
                      "amount": 90
                    },
                    {
                      "op": "repair_ship",
                      "amount": 6
                    },
                    {
                      "op": "add_delay_hours",
                      "amount": 1
                    },
                    {
                      "op": "emit_notice",
                      "text_key": "notice.core.overheat.paid"
                    }
                  ]
                },
                {
                  "id": "force_continue",
                  "name_key": "event.core.boiler_overheat.force_continue",
                  "weight": 1,
                  "effects": [
                    {
                      "op": "damage_ship",
                      "amount": 9
                    },
                    {
                      "op": "add_delay_hours",
                      "amount": 1
                    },
                    {
                      "op": "emit_notice",
                      "text_key": "notice.core.overheat.forced"
                    }
                  ]
                },
                {
                  "id": "jettison_cargo",
                  "name_key": "event.core.boiler_overheat.jettison_cargo",
                  "weight": 1,
                  "effects": [
                    {
                      "op": "damage_cargo",
                      "amount": 8
                    },
                    {
                      "op": "emit_notice",
                      "text_key": "notice.core.overheat.jettisoned"
                    }
                  ]
                }
              ]
            }
          },
          {
            "id": "core:event/merchant_intel",
            "name_key": "event.core.merchant_intel.name",
            "description_key": "event.core.merchant_intel.description",
            "tags": [
              "event.opportunity",
              "event.merchant"
            ],
            "enabled": true,
            "data": {
              "trigger": "voyage_opportunity",
              "category": "merchant",
              "weight": 1,
              "base_delay_hours": 0,
              "options": [
                {
                  "id": "buy_intel",
                  "name_key": "event.core.merchant_intel.buy_intel",
                  "weight": 1,
                  "condition": {
                    "op": "money_gte",
                    "value": 60
                  },
                  "effects": [
                    {
                      "op": "remove_money",
                      "amount": 60
                    },
                    {
                      "op": "update_intelligence"
                    },
                    {
                      "op": "emit_notice",
                      "text_key": "notice.core.merchant.bought"
                    }
                  ]
                },
                {
                  "id": "decline",
                  "name_key": "event.core.merchant_intel.decline",
                  "weight": 1,
                  "effects": [
                    {
                      "op": "emit_notice",
                      "text_key": "notice.core.merchant.declined"
                    }
                  ]
                }
              ]
            }
          }
        ]
      }
    },
    "localization": {
      "zh_CN": {
        "good.core.iron_ore.name": "铁矿石",
        "good.core.iron_ore.description": "造船与冶炼的基础原料，单位重量大。",
        "good.core.brass.name": "黄铜",
        "good.core.brass.description": "锅炉与精密机械常用的金属材料。",
        "good.core.textiles.name": "纺织品",
        "good.core.textiles.description": "轻便的日用商品，适合填充剩余舱位。",
        "good.core.spices.name": "香料",
        "good.core.spices.description": "重量极轻、价格昂贵的奢侈品。",
        "good.core.timber.name": "木材",
        "good.core.timber.description": "船体与货舱的通用建造材料。",
        "good.core.glassware.name": "玻璃器皿",
        "good.core.glassware.description": "易碎但利润可观的工艺品。",
        "good.core.contract_freight.name": "委托货箱",
        "good.core.contract_freight.description": "由委托方提供的封装货物，不能自由买卖或抛弃。",
        "material.core.boiler_plate.name": "锅炉钢板",
        "material.core.boiler_plate.description": "耐压锅炉与中型船体的专用材料。",
        "material.core.precision_gear.name": "精密齿轮",
        "material.core.precision_gear.description": "大型船只与高性能锅炉所需的高级材料。",
        "material.core.sealing_compound.name": "密封胶",
        "material.core.sealing_compound.description": "用于锅炉、客舱和导航设备的密封耗材。",
        "module.core.small_efficient_hull.name": "效率型小型船体",
        "module.core.small_efficient_hull.description": "造价低、自重轻，只有一个货舱槽，适合起步。",
        "module.core.medium_standard_hull.name": "标准中型船体",
        "module.core.medium_standard_hull.description": "两个货舱槽与一个客舱槽，是中期成长的核心。",
        "module.core.large_efficient_hull.name": "效率型大型船体",
        "module.core.large_efficient_hull.description": "三个货舱槽、高耐久与低单位重量成本。",
        "module.core.large_performance_hull.name": "性能型大型船体",
        "module.core.large_performance_hull.description": "更快但更重、更贵的大型船体。",
        "module.core.small_efficient_boiler.name": "效率型小型锅炉",
        "module.core.small_efficient_boiler.description": "省煤省水，航速略低，适合长途与学习。",
        "module.core.standard_boiler.name": "标准锅炉",
        "module.core.standard_boiler.description": "速度与补给消耗均衡的默认锅炉。",
        "module.core.performance_boiler.name": "性能型锅炉",
        "module.core.performance_boiler.description": "航速高，但煤水消耗显著上升。",
        "module.core.small_hold.name": "小型货舱",
        "module.core.small_hold.description": "自重低，容量 32。",
        "module.core.medium_hold.name": "中型货舱",
        "module.core.medium_hold.description": "容量 68，适合中型船体。",
        "module.core.large_hold.name": "大型货舱",
        "module.core.large_hold.description": "容量 110，适合大型船体。",
        "module.core.spyglass.name": "望远镜",
        "module.core.spyglass.description": "略微降低迷航风险，价格便宜。",
        "module.core.chart_room.name": "海图室",
        "module.core.chart_room.description": "降低风险并提升航速，出航前可揭示未知目的港设施。",
        "module.core.lifeboat.name": "救生艇",
        "module.core.lifeboat.description": "降低事故损失与部分风险。",
        "module.core.safety_valve.name": "安全阀组",
        "module.core.safety_valve.description": "显著降低锅炉事故风险与维修费用。",
        "module.core.passenger_cabin.name": "固定客舱",
        "module.core.passenger_cabin.description": "可搭载 4 名旅客，占用船体客舱槽。",
        "role.core.engineer_basic.name": "工程师",
        "role.core.engineer_basic.description": "降低故障风险与维修费用，每次航行领取工资。",
        "role.core.navigator_basic.name": "领航员",
        "role.core.navigator_basic.description": "降低迷航风险并略微提升航速。",
        "strategy.core.economic.name": "经济",
        "strategy.core.economic.description": "降低航速与补给消耗，适合长途与补给紧张。",
        "strategy.core.standard.name": "标准",
        "strategy.core.standard.description": "速度、补给与风险的平衡方案。",
        "strategy.core.fast.name": "极速",
        "strategy.core.fast.description": "显著提高航速，但煤水消耗与风险更高。",
        "port.core.iron_harbor.name": "铁港",
        "port.core.iron_harbor.description": "工业港口，拥有造船厂，铁矿石与钢板供应充足。",
        "port.core.spice_port.name": "香料港",
        "port.core.spice_port.description": "香料贸易繁荣，设有情报站。",
        "port.core.free_town.name": "自由镇",
        "port.core.free_town.description": "设施齐全的中立贸易港，造船厂与情报站并存。",
        "port.core.fishing_village.name": "渔村",
        "port.core.fishing_village.description": "木材与铁矿便宜，但设施有限。",
        "port.core.glass_port.name": "玻璃港",
        "port.core.glass_port.description": "玻璃器皿的产地，设有情报站。",
        "port_name.core.iron_harbor": "铁港",
        "port_name.core.spice_port": "香料港",
        "port_name.core.free_town": "自由镇",
        "port_name.core.fishing_village": "渔村",
        "port_name.core.glass_port": "玻璃港",
        "port_name.core.mist_cove": "雾湾",
        "map_profile.core.standard.name": "标准海图",
        "map_profile.core.standard.description": "4–5 个港口的分支网络，包含造船厂与情报站。",
        "starting_build.core.steady.name": "低耗稳健型",
        "starting_build.core.steady.description": "效率型锅炉与较充足补给，风险低，适合学习。",
        "starting_build.core.swift.name": "高速冒险型",
        "starting_build.core.swift.description": "性能型锅炉与较少补给，抢时间但容错低。",
        "contract.core.main_01.name": "主线一：初次出航",
        "contract.core.main_01.description": "把第一批委托货箱送到相邻港口，熟悉航线与补给。",
        "contract.core.main_02.name": "主线二：自由贸易",
        "contract.core.main_02.description": "运货之余观察市场，理解重量与航速的关系。",
        "contract.core.main_03.name": "主线三：模块制造",
        "contract.core.main_03.description": "积累资金与材料，为中型船体做准备。",
        "contract.core.main_04.name": "主线四：客运",
        "contract.core.main_04.description": "安装客舱并准备额外淡水，按时送达旅客。",
        "contract.core.main_05.name": "主线五：综合挑战",
        "contract.core.main_05.description": "同时运输重货与旅客，在期限内抵达。",
        "contract.core.normal_cargo_short.name": "短途货运",
        "contract.core.normal_cargo_short.description": "相邻港口之间的普通货箱运输。",
        "contract.core.normal_cargo_long.name": "大宗货运",
        "contract.core.normal_cargo_long.description": "更重的货箱，报酬也更高。",
        "contract.core.normal_passenger.name": "短途客运",
        "contract.core.normal_passenger.description": "少量旅客的短途运输。",
        "contract.core.normal_urgent.name": "紧急货运",
        "contract.core.normal_urgent.description": "期限紧张，但准时奖金可观。",
        "event.core.boiler_overheat.name": "锅炉过热",
        "event.core.boiler_overheat.description": "压力表指针越过红线，锅炉发出尖锐的鸣响。",
        "event.core.boiler_overheat.water_cooling": "消耗淡水紧急降温",
        "event.core.boiler_overheat.stop_repair": "停船检修",
        "event.core.boiler_overheat.paid_repair": "支付加班费抢修",
        "event.core.boiler_overheat.force_continue": "强行继续",
        "event.core.boiler_overheat.jettison_cargo": "抛弃部分普通货物",
        "event.core.merchant_intel.name": "偶遇商船",
        "event.core.merchant_intel.description": "一艘商船靠近，表示愿意出售刚获得的市场情报。",
        "event.core.merchant_intel.buy_intel": "支付 60 金币购买情报",
        "event.core.merchant_intel.decline": "婉拒并继续航行",
        "notice.core.overheat.cooled": "淡水喷入锅炉，压力暂时回落。",
        "notice.core.overheat.repaired": "船停在平静海面完成检修，航程被延误。",
        "notice.core.overheat.paid": "船员加班抢修，锅炉恢复稳定。",
        "notice.core.overheat.forced": "你选择继续航行，船体承受了额外损伤。",
        "notice.core.overheat.jettisoned": "部分普通货物被抛入海中，船身轻了一些。",
        "notice.core.merchant.bought": "商船提供了最新的市场与航向情报。",
        "notice.core.merchant.declined": "商船收起海图，转向离开。",
        "risk.route": "航线基础风险",
        "risk.strategy": "锅炉策略",
        "risk.overload": "接近载重上限",
        "risk.low_durability": "船体耐久偏低",
        "risk.equipment_crew": "设备与船员修正"
      },
      "en": {
        "good.core.iron_ore.name": "Iron Ore",
        "good.core.iron_ore.description": "Heavy base material for smelting and shipbuilding.",
        "good.core.brass.name": "Brass",
        "good.core.brass.description": "A metal used in boilers and precision machinery.",
        "good.core.textiles.name": "Textiles",
        "good.core.textiles.description": "Light consumer goods that fill spare hold space.",
        "good.core.spices.name": "Spices",
        "good.core.spices.description": "Very light, very expensive luxury cargo.",
        "good.core.timber.name": "Timber",
        "good.core.timber.description": "General shipbuilding material for hulls and holds.",
        "good.core.glassware.name": "Glassware",
        "good.core.glassware.description": "Fragile craft goods with a healthy margin.",
        "good.core.contract_freight.name": "Contract Freight",
        "good.core.contract_freight.description": "Sealed cargo supplied by the client. Cannot be sold or jettisoned.",
        "material.core.boiler_plate.name": "Boiler Plate",
        "material.core.boiler_plate.description": "Pressure-rated plate for medium hulls and boilers.",
        "material.core.precision_gear.name": "Precision Gear",
        "material.core.precision_gear.description": "Advanced material for large ships and high-performance boilers.",
        "material.core.sealing_compound.name": "Sealing Compound",
        "material.core.sealing_compound.description": "Consumable sealant for boilers, cabins and navigation gear.",
        "module.core.small_efficient_hull.name": "Small Efficient Hull",
        "module.core.small_efficient_hull.description": "Cheap and light, with a single cargo slot. A good starter.",
        "module.core.medium_standard_hull.name": "Medium Standard Hull",
        "module.core.medium_standard_hull.description": "Two cargo slots and one cabin slot. The mid-game core.",
        "module.core.large_efficient_hull.name": "Large Efficient Hull",
        "module.core.large_efficient_hull.description": "Three cargo slots, high durability and low weight cost.",
        "module.core.large_performance_hull.name": "Large Performance Hull",
        "module.core.large_performance_hull.description": "Faster, heavier and more expensive than the efficient large hull.",
        "module.core.small_efficient_boiler.name": "Small Efficient Boiler",
        "module.core.small_efficient_boiler.description": "Thrifty on coal and water, slightly slower. Good for long hauls.",
        "module.core.standard_boiler.name": "Standard Boiler",
        "module.core.standard_boiler.description": "A balanced default for speed and supplies.",
        "module.core.performance_boiler.name": "Performance Boiler",
        "module.core.performance_boiler.description": "High speed at a steep coal and water cost.",
        "module.core.small_hold.name": "Small Hold",
        "module.core.small_hold.description": "Light hold with capacity 32.",
        "module.core.medium_hold.name": "Medium Hold",
        "module.core.medium_hold.description": "Capacity 68, sized for medium hulls.",
        "module.core.large_hold.name": "Large Hold",
        "module.core.large_hold.description": "Capacity 110, sized for large hulls.",
        "module.core.spyglass.name": "Spyglass",
        "module.core.spyglass.description": "Slightly reduces navigation risk. Cheap.",
        "module.core.chart_room.name": "Chart Room",
        "module.core.chart_room.description": "Reduces risk, adds speed, and reveals unknown port facilities before departure.",
        "module.core.lifeboat.name": "Lifeboat",
        "module.core.lifeboat.description": "Reduces accident damage and some risk.",
        "module.core.safety_valve.name": "Safety Valve Set",
        "module.core.safety_valve.description": "Sharply reduces boiler risk and repair cost.",
        "module.core.passenger_cabin.name": "Fixed Passenger Cabin",
        "module.core.passenger_cabin.description": "Carries 4 passengers and uses the hull's cabin slot.",
        "role.core.engineer_basic.name": "Engineer",
        "role.core.engineer_basic.description": "Reduces breakdown risk and repair cost. Paid per voyage.",
        "role.core.navigator_basic.name": "Navigator",
        "role.core.navigator_basic.description": "Reduces navigation risk and slightly increases speed.",
        "strategy.core.economic.name": "Economic",
        "strategy.core.economic.description": "Slower but thrifty. For long hauls and tight supplies.",
        "strategy.core.standard.name": "Standard",
        "strategy.core.standard.description": "A balanced mix of speed, supplies and risk.",
        "strategy.core.fast.name": "Full Speed",
        "strategy.core.fast.description": "Much faster, but burns coal and water and raises risk.",
        "port.core.iron_harbor.name": "Iron Harbor",
        "port.core.iron_harbor.description": "Industrial port with a shipyard and plenty of ore and plate.",
        "port.core.spice_port.name": "Spice Port",
        "port.core.spice_port.description": "A busy spice trade port with an intelligence station.",
        "port.core.free_town.name": "Free Town",
        "port.core.free_town.description": "A neutral trade hub with every facility.",
        "port.core.fishing_village.name": "Fishing Village",
        "port.core.fishing_village.description": "Cheap timber and ore, but limited facilities.",
        "port.core.glass_port.name": "Glass Port",
        "port.core.glass_port.description": "Glassware producer with an intelligence station.",
        "port_name.core.iron_harbor": "Iron Harbor",
        "port_name.core.spice_port": "Spice Port",
        "port_name.core.free_town": "Free Town",
        "port_name.core.fishing_village": "Fishing Village",
        "port_name.core.glass_port": "Glass Port",
        "port_name.core.mist_cove": "Mist Cove",
        "map_profile.core.standard.name": "Standard Chart",
        "map_profile.core.standard.description": "A 4-5 port branch network with a shipyard and intelligence station.",
        "starting_build.core.steady.name": "Steady and Thrifty",
        "starting_build.core.steady.description": "Efficient boiler and generous supplies. Low risk, easy to learn.",
        "starting_build.core.swift.name": "Swift and Bold",
        "starting_build.core.swift.description": "Performance boiler and light supplies. Fast, but unforgiving.",
        "contract.core.main_01.name": "Main 1: First Departure",
        "contract.core.main_01.description": "Deliver the first sealed crates to a neighbouring port.",
        "contract.core.main_02.name": "Main 2: Free Trade",
        "contract.core.main_02.description": "Watch the market while hauling, and feel how weight changes speed.",
        "contract.core.main_03.name": "Main 3: Module Crafting",
        "contract.core.main_03.description": "Build capital and materials for a medium hull.",
        "contract.core.main_04.name": "Main 4: Passengers",
        "contract.core.main_04.description": "Install a cabin, carry extra water, and deliver passengers on time.",
        "contract.core.main_05.name": "Main 5: The Final Run",
        "contract.core.main_05.description": "Carry heavy freight and passengers together, on deadline.",
        "contract.core.normal_cargo_short.name": "Short Cargo Run",
        "contract.core.normal_cargo_short.description": "Ordinary crates between neighbouring ports.",
        "contract.core.normal_cargo_long.name": "Bulk Cargo Run",
        "contract.core.normal_cargo_long.description": "Heavier crates for a higher fee.",
        "contract.core.normal_passenger.name": "Short Passenger Run",
        "contract.core.normal_passenger.description": "A few passengers on a short route.",
        "contract.core.normal_urgent.name": "Urgent Cargo",
        "contract.core.normal_urgent.description": "Tight deadline, attractive on-time bonus.",
        "event.core.boiler_overheat.name": "Boiler Overheat",
        "event.core.boiler_overheat.description": "The pressure gauge crosses the red line and the boiler shrieks.",
        "event.core.boiler_overheat.water_cooling": "Use fresh water for emergency cooling",
        "event.core.boiler_overheat.stop_repair": "Stop and repair",
        "event.core.boiler_overheat.paid_repair": "Pay overtime for an emergency repair",
        "event.core.boiler_overheat.force_continue": "Press on regardless",
        "event.core.boiler_overheat.jettison_cargo": "Jettison some ordinary cargo",
        "event.core.merchant_intel.name": "Merchant Encounter",
        "event.core.merchant_intel.description": "A merchant ship offers freshly gathered market intelligence.",
        "event.core.merchant_intel.buy_intel": "Pay 60 gold for the report",
        "event.core.merchant_intel.decline": "Decline and sail on",
        "notice.core.overheat.cooled": "Water floods the boiler and pressure falls back.",
        "notice.core.overheat.repaired": "The ship stops in calm water for repairs. The voyage is delayed.",
        "notice.core.overheat.paid": "The crew works overtime and the boiler stabilises.",
        "notice.core.overheat.forced": "You press on. The hull takes extra damage.",
        "notice.core.overheat.jettisoned": "Some ordinary cargo goes overboard, lightening the ship.",
        "notice.core.merchant.bought": "The merchant hands over a fresh market and heading report.",
        "notice.core.merchant.declined": "The merchant folds the charts and turns away.",
        "risk.route": "Route base risk",
        "risk.strategy": "Boiler strategy",
        "risk.overload": "Near weight limit",
        "risk.low_durability": "Low hull durability",
        "risk.equipment_crew": "Equipment and crew modifiers"
      }
    },
    "definitions": [
      {
        "id": "core:good/iron_ore",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.iron_ore.name",
        "name_zh": "铁矿石",
        "name_en": "Iron Ore",
        "tags": [
          "good.trade",
          "good.bulk",
          "good.shipbuilding"
        ],
        "definition": {
          "id": "core:good/iron_ore",
          "name_key": "good.core.iron_ore.name",
          "description_key": "good.core.iron_ore.description",
          "tags": [
            "good.trade",
            "good.bulk",
            "good.shipbuilding"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 3,
            "base_price": 42,
            "base_stock": 120,
            "price_elasticity": 0.16,
            "spawn_weight": 1,
            "crafting_material": true,
            "category": "ore"
          }
        }
      },
      {
        "id": "core:good/brass",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.brass.name",
        "name_zh": "黄铜",
        "name_en": "Brass",
        "tags": [
          "good.trade",
          "good.shipbuilding"
        ],
        "definition": {
          "id": "core:good/brass",
          "name_key": "good.core.brass.name",
          "description_key": "good.core.brass.description",
          "tags": [
            "good.trade",
            "good.shipbuilding"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 2,
            "base_price": 88,
            "base_stock": 80,
            "price_elasticity": 0.18,
            "spawn_weight": 1,
            "crafting_material": true,
            "category": "metal"
          }
        }
      },
      {
        "id": "core:good/textiles",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.textiles.name",
        "name_zh": "纺织品",
        "name_en": "Textiles",
        "tags": [
          "good.trade",
          "good.consumer"
        ],
        "definition": {
          "id": "core:good/textiles",
          "name_key": "good.core.textiles.name",
          "description_key": "good.core.textiles.description",
          "tags": [
            "good.trade",
            "good.consumer"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 1,
            "base_price": 64,
            "base_stock": 90,
            "price_elasticity": 0.15,
            "spawn_weight": 1,
            "category": "textile"
          }
        }
      },
      {
        "id": "core:good/spices",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.spices.name",
        "name_zh": "香料",
        "name_en": "Spices",
        "tags": [
          "good.trade",
          "good.luxury"
        ],
        "definition": {
          "id": "core:good/spices",
          "name_key": "good.core.spices.name",
          "description_key": "good.core.spices.description",
          "tags": [
            "good.trade",
            "good.luxury"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 0.5,
            "base_price": 150,
            "base_stock": 55,
            "price_elasticity": 0.12,
            "spawn_weight": 0.8,
            "category": "luxury"
          }
        }
      },
      {
        "id": "core:good/timber",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.timber.name",
        "name_zh": "木材",
        "name_en": "Timber",
        "tags": [
          "good.trade",
          "good.bulk",
          "good.shipbuilding"
        ],
        "definition": {
          "id": "core:good/timber",
          "name_key": "good.core.timber.name",
          "description_key": "good.core.timber.description",
          "tags": [
            "good.trade",
            "good.bulk",
            "good.shipbuilding"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 2.5,
            "base_price": 36,
            "base_stock": 130,
            "price_elasticity": 0.17,
            "spawn_weight": 1,
            "crafting_material": true,
            "category": "wood"
          }
        }
      },
      {
        "id": "core:good/glassware",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.glassware.name",
        "name_zh": "玻璃器皿",
        "name_en": "Glassware",
        "tags": [
          "good.trade",
          "good.fragile"
        ],
        "definition": {
          "id": "core:good/glassware",
          "name_key": "good.core.glassware.name",
          "description_key": "good.core.glassware.description",
          "tags": [
            "good.trade",
            "good.fragile"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 1.5,
            "base_price": 105,
            "base_stock": 60,
            "price_elasticity": 0.2,
            "spawn_weight": 0.9,
            "category": "craft"
          }
        }
      },
      {
        "id": "core:good/contract_freight",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.contract_freight.name",
        "name_zh": "委托货箱",
        "name_en": "Contract Freight",
        "tags": [
          "good.contract"
        ],
        "definition": {
          "id": "core:good/contract_freight",
          "name_key": "good.core.contract_freight.name",
          "description_key": "good.core.contract_freight.description",
          "tags": [
            "good.contract"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 1,
            "base_price": 1,
            "base_stock": 1,
            "price_elasticity": 0.1,
            "spawn_weight": 0,
            "category": "contract"
          }
        }
      },
      {
        "id": "core:good/coal",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.coal.name",
        "name_zh": "",
        "name_en": "",
        "tags": [
          "good.supply",
          "supply.coal",
          "good.bulk"
        ],
        "definition": {
          "id": "core:good/coal",
          "name_key": "good.core.coal.name",
          "description_key": "good.core.coal.description",
          "tags": [
            "good.supply",
            "supply.coal",
            "good.bulk"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 1,
            "base_price": 4,
            "base_stock": 140,
            "price_elasticity": 0.12,
            "spawn_weight": 0,
            "category": "supply"
          }
        }
      },
      {
        "id": "core:good/water",
        "content_type": "goods",
        "file": "content/goods.json",
        "name_key": "good.core.water.name",
        "name_zh": "",
        "name_en": "",
        "tags": [
          "good.supply",
          "supply.water",
          "good.bulk"
        ],
        "definition": {
          "id": "core:good/water",
          "name_key": "good.core.water.name",
          "description_key": "good.core.water.description",
          "tags": [
            "good.supply",
            "supply.water",
            "good.bulk"
          ],
          "enabled": true,
          "data": {
            "unit_weight": 1,
            "base_price": 2,
            "base_stock": 160,
            "price_elasticity": 0.1,
            "spawn_weight": 0,
            "category": "supply"
          }
        }
      },
      {
        "id": "core:material/boiler_plate",
        "content_type": "materials",
        "file": "content/materials.json",
        "name_key": "material.core.boiler_plate.name",
        "name_zh": "锅炉钢板",
        "name_en": "Boiler Plate",
        "tags": [
          "material.shipbuilding",
          "material.tier2"
        ],
        "definition": {
          "id": "core:material/boiler_plate",
          "name_key": "material.core.boiler_plate.name",
          "description_key": "material.core.boiler_plate.description",
          "tags": [
            "material.shipbuilding",
            "material.tier2"
          ],
          "enabled": true,
          "data": {
            "tier": 2,
            "unit_weight": 2,
            "base_price": 120,
            "base_stock": 60,
            "price_elasticity": 0.15,
            "category": "plate"
          }
        }
      },
      {
        "id": "core:material/precision_gear",
        "content_type": "materials",
        "file": "content/materials.json",
        "name_key": "material.core.precision_gear.name",
        "name_zh": "精密齿轮",
        "name_en": "Precision Gear",
        "tags": [
          "material.shipbuilding",
          "material.tier3"
        ],
        "definition": {
          "id": "core:material/precision_gear",
          "name_key": "material.core.precision_gear.name",
          "description_key": "material.core.precision_gear.description",
          "tags": [
            "material.shipbuilding",
            "material.tier3"
          ],
          "enabled": true,
          "data": {
            "tier": 3,
            "unit_weight": 0.8,
            "base_price": 190,
            "base_stock": 40,
            "price_elasticity": 0.12,
            "category": "mechanism"
          }
        }
      },
      {
        "id": "core:material/sealing_compound",
        "content_type": "materials",
        "file": "content/materials.json",
        "name_key": "material.core.sealing_compound.name",
        "name_zh": "密封胶",
        "name_en": "Sealing Compound",
        "tags": [
          "material.shipbuilding",
          "material.tier1"
        ],
        "definition": {
          "id": "core:material/sealing_compound",
          "name_key": "material.core.sealing_compound.name",
          "description_key": "material.core.sealing_compound.description",
          "tags": [
            "material.shipbuilding",
            "material.tier1"
          ],
          "enabled": true,
          "data": {
            "tier": 1,
            "unit_weight": 0.5,
            "base_price": 75,
            "base_stock": 70,
            "price_elasticity": 0.1,
            "category": "compound"
          }
        }
      },
      {
        "id": "core:hull/small_efficient",
        "content_type": "hulls",
        "file": "content/hulls.json",
        "name_key": "module.core.small_efficient_hull.name",
        "name_zh": "效率型小型船体",
        "name_en": "Small Efficient Hull",
        "tags": [
          "module.hull",
          "module.small",
          "module.efficient",
          "ship.small"
        ],
        "definition": {
          "id": "core:hull/small_efficient",
          "name_key": "module.core.small_efficient_hull.name",
          "description_key": "module.core.small_efficient_hull.description",
          "tags": [
            "module.hull",
            "module.small",
            "module.efficient",
            "ship.small"
          ],
          "enabled": true,
          "data": {
            "tier": 1,
            "weight": 22,
            "purchase_price": 380,
            "craft_time_hours": 4,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 4
              },
              {
                "id": "core:good/iron_ore",
                "amount": 2
              }
            ],
            "base_speed": 14,
            "max_weight": 100,
            "max_durability": 100,
            "cargo_slots": 1,
            "cabin_slots": 0,
            "base_risk": 0.025,
            "size_tag": "small"
          }
        }
      },
      {
        "id": "core:hull/medium_standard",
        "content_type": "hulls",
        "file": "content/hulls.json",
        "name_key": "module.core.medium_standard_hull.name",
        "name_zh": "标准中型船体",
        "name_en": "Medium Standard Hull",
        "tags": [
          "module.hull",
          "module.medium",
          "module.standard",
          "ship.medium"
        ],
        "definition": {
          "id": "core:hull/medium_standard",
          "name_key": "module.core.medium_standard_hull.name",
          "description_key": "module.core.medium_standard_hull.description",
          "tags": [
            "module.hull",
            "module.medium",
            "module.standard",
            "ship.medium"
          ],
          "enabled": true,
          "data": {
            "tier": 2,
            "weight": 38,
            "purchase_price": 1100,
            "craft_time_hours": 8,
            "craft_cost": 220,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 8
              },
              {
                "id": "core:material/boiler_plate",
                "amount": 3
              }
            ],
            "base_speed": 15,
            "max_weight": 165,
            "max_durability": 140,
            "cargo_slots": 2,
            "cabin_slots": 1,
            "base_risk": 0.02,
            "size_tag": "medium"
          }
        }
      },
      {
        "id": "core:hull/large_efficient",
        "content_type": "hulls",
        "file": "content/hulls.json",
        "name_key": "module.core.large_efficient_hull.name",
        "name_zh": "效率型大型船体",
        "name_en": "Large Efficient Hull",
        "tags": [
          "module.hull",
          "module.large",
          "module.efficient",
          "ship.large"
        ],
        "definition": {
          "id": "core:hull/large_efficient",
          "name_key": "module.core.large_efficient_hull.name",
          "description_key": "module.core.large_efficient_hull.description",
          "tags": [
            "module.hull",
            "module.large",
            "module.efficient",
            "ship.large"
          ],
          "enabled": true,
          "data": {
            "tier": 3,
            "weight": 60,
            "purchase_price": 2600,
            "craft_time_hours": 12,
            "craft_cost": 520,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 14
              },
              {
                "id": "core:material/boiler_plate",
                "amount": 6
              },
              {
                "id": "core:material/precision_gear",
                "amount": 2
              }
            ],
            "base_speed": 14,
            "max_weight": 260,
            "max_durability": 200,
            "cargo_slots": 3,
            "cabin_slots": 1,
            "base_risk": 0.02,
            "size_tag": "large"
          }
        }
      },
      {
        "id": "core:hull/large_performance",
        "content_type": "hulls",
        "file": "content/hulls.json",
        "name_key": "module.core.large_performance_hull.name",
        "name_zh": "性能型大型船体",
        "name_en": "Large Performance Hull",
        "tags": [
          "module.hull",
          "module.large",
          "module.performance",
          "ship.large"
        ],
        "definition": {
          "id": "core:hull/large_performance",
          "name_key": "module.core.large_performance_hull.name",
          "description_key": "module.core.large_performance_hull.description",
          "tags": [
            "module.hull",
            "module.large",
            "module.performance",
            "ship.large"
          ],
          "enabled": true,
          "data": {
            "tier": 3,
            "weight": 66,
            "purchase_price": 3400,
            "craft_time_hours": 14,
            "craft_cost": 680,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 12
              },
              {
                "id": "core:material/boiler_plate",
                "amount": 8
              },
              {
                "id": "core:material/precision_gear",
                "amount": 4
              }
            ],
            "base_speed": 17,
            "max_weight": 240,
            "max_durability": 180,
            "cargo_slots": 3,
            "cabin_slots": 1,
            "base_risk": 0.025,
            "size_tag": "large"
          }
        }
      },
      {
        "id": "core:boiler/small_efficient",
        "content_type": "boilers",
        "file": "content/boilers.json",
        "name_key": "module.core.small_efficient_boiler.name",
        "name_zh": "效率型小型锅炉",
        "name_en": "Small Efficient Boiler",
        "tags": [
          "module.boiler",
          "module.small",
          "module.efficient"
        ],
        "definition": {
          "id": "core:boiler/small_efficient",
          "name_key": "module.core.small_efficient_boiler.name",
          "description_key": "module.core.small_efficient_boiler.description",
          "tags": [
            "module.boiler",
            "module.small",
            "module.efficient"
          ],
          "enabled": true,
          "data": {
            "tier": 1,
            "weight": 8,
            "purchase_price": 420,
            "craft_time_hours": 4,
            "materials": [
              {
                "id": "core:good/brass",
                "amount": 4
              },
              {
                "id": "core:material/sealing_compound",
                "amount": 2
              }
            ],
            "speed_mul": 0.94,
            "coal_rate": 0.3,
            "water_rate": 0.22
          }
        }
      },
      {
        "id": "core:boiler/standard",
        "content_type": "boilers",
        "file": "content/boilers.json",
        "name_key": "module.core.standard_boiler.name",
        "name_zh": "标准锅炉",
        "name_en": "Standard Boiler",
        "tags": [
          "module.boiler",
          "module.standard"
        ],
        "definition": {
          "id": "core:boiler/standard",
          "name_key": "module.core.standard_boiler.name",
          "description_key": "module.core.standard_boiler.description",
          "tags": [
            "module.boiler",
            "module.standard"
          ],
          "enabled": true,
          "data": {
            "tier": 1,
            "weight": 10,
            "purchase_price": 650,
            "craft_time_hours": 5,
            "materials": [
              {
                "id": "core:good/brass",
                "amount": 6
              },
              {
                "id": "core:material/boiler_plate",
                "amount": 2
              }
            ],
            "speed_mul": 1,
            "coal_rate": 0.4,
            "water_rate": 0.28
          }
        }
      },
      {
        "id": "core:boiler/performance",
        "content_type": "boilers",
        "file": "content/boilers.json",
        "name_key": "module.core.performance_boiler.name",
        "name_zh": "性能型锅炉",
        "name_en": "Performance Boiler",
        "tags": [
          "module.boiler",
          "module.performance"
        ],
        "definition": {
          "id": "core:boiler/performance",
          "name_key": "module.core.performance_boiler.name",
          "description_key": "module.core.performance_boiler.description",
          "tags": [
            "module.boiler",
            "module.performance"
          ],
          "enabled": true,
          "data": {
            "tier": 2,
            "weight": 14,
            "purchase_price": 1200,
            "craft_time_hours": 7,
            "craft_cost": 180,
            "materials": [
              {
                "id": "core:good/brass",
                "amount": 8
              },
              {
                "id": "core:material/boiler_plate",
                "amount": 4
              },
              {
                "id": "core:material/precision_gear",
                "amount": 1
              }
            ],
            "speed_mul": 1.18,
            "coal_rate": 0.58,
            "water_rate": 0.36
          }
        }
      },
      {
        "id": "core:cargo_module/small_hold",
        "content_type": "cargo_modules",
        "file": "content/cargo_modules.json",
        "name_key": "module.core.small_hold.name",
        "name_zh": "小型货舱",
        "name_en": "Small Hold",
        "tags": [
          "module.cargo",
          "module.small",
          "module.efficient"
        ],
        "definition": {
          "id": "core:cargo_module/small_hold",
          "name_key": "module.core.small_hold.name",
          "description_key": "module.core.small_hold.description",
          "tags": [
            "module.cargo",
            "module.small",
            "module.efficient"
          ],
          "enabled": true,
          "data": {
            "tier": 1,
            "weight": 6,
            "purchase_price": 260,
            "craft_time_hours": 3,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 3
              }
            ],
            "capacity": 32
          }
        }
      },
      {
        "id": "core:cargo_module/medium_hold",
        "content_type": "cargo_modules",
        "file": "content/cargo_modules.json",
        "name_key": "module.core.medium_hold.name",
        "name_zh": "中型货舱",
        "name_en": "Medium Hold",
        "tags": [
          "module.cargo",
          "module.medium",
          "module.standard"
        ],
        "definition": {
          "id": "core:cargo_module/medium_hold",
          "name_key": "module.core.medium_hold.name",
          "description_key": "module.core.medium_hold.description",
          "tags": [
            "module.cargo",
            "module.medium",
            "module.standard"
          ],
          "enabled": true,
          "data": {
            "tier": 2,
            "weight": 12,
            "purchase_price": 900,
            "craft_time_hours": 6,
            "craft_cost": 160,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 6
              },
              {
                "id": "core:material/boiler_plate",
                "amount": 2
              }
            ],
            "capacity": 68
          }
        }
      },
      {
        "id": "core:cargo_module/large_hold",
        "content_type": "cargo_modules",
        "file": "content/cargo_modules.json",
        "name_key": "module.core.large_hold.name",
        "name_zh": "大型货舱",
        "name_en": "Large Hold",
        "tags": [
          "module.cargo",
          "module.large",
          "module.performance"
        ],
        "definition": {
          "id": "core:cargo_module/large_hold",
          "name_key": "module.core.large_hold.name",
          "description_key": "module.core.large_hold.description",
          "tags": [
            "module.cargo",
            "module.large",
            "module.performance"
          ],
          "enabled": true,
          "data": {
            "tier": 3,
            "weight": 20,
            "purchase_price": 1800,
            "craft_time_hours": 9,
            "craft_cost": 320,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 10
              },
              {
                "id": "core:material/boiler_plate",
                "amount": 4
              }
            ],
            "capacity": 110
          }
        }
      },
      {
        "id": "core:navigation_module/spyglass",
        "content_type": "navigation_modules",
        "file": "content/navigation_modules.json",
        "name_key": "module.core.spyglass.name",
        "name_zh": "望远镜",
        "name_en": "Spyglass",
        "tags": [
          "module.navigation",
          "module.efficient"
        ],
        "definition": {
          "id": "core:navigation_module/spyglass",
          "name_key": "module.core.spyglass.name",
          "description_key": "module.core.spyglass.description",
          "tags": [
            "module.navigation",
            "module.efficient"
          ],
          "enabled": true,
          "data": {
            "tier": 1,
            "weight": 2,
            "purchase_price": 300,
            "craft_time_hours": 2,
            "materials": [
              {
                "id": "core:good/brass",
                "amount": 2
              }
            ],
            "risk_add": -0.012,
            "speed_mul": 1,
            "reveal_facilities": false
          }
        }
      },
      {
        "id": "core:navigation_module/chart_room",
        "content_type": "navigation_modules",
        "file": "content/navigation_modules.json",
        "name_key": "module.core.chart_room.name",
        "name_zh": "海图室",
        "name_en": "Chart Room",
        "tags": [
          "module.navigation",
          "module.performance"
        ],
        "definition": {
          "id": "core:navigation_module/chart_room",
          "name_key": "module.core.chart_room.name",
          "description_key": "module.core.chart_room.description",
          "tags": [
            "module.navigation",
            "module.performance"
          ],
          "enabled": true,
          "data": {
            "tier": 2,
            "weight": 5,
            "purchase_price": 850,
            "craft_time_hours": 5,
            "craft_cost": 140,
            "materials": [
              {
                "id": "core:good/brass",
                "amount": 3
              },
              {
                "id": "core:material/sealing_compound",
                "amount": 2
              }
            ],
            "risk_add": -0.022,
            "speed_mul": 1.03,
            "reveal_facilities": true
          }
        }
      },
      {
        "id": "core:safety_module/lifeboat",
        "content_type": "safety_modules",
        "file": "content/safety_modules.json",
        "name_key": "module.core.lifeboat.name",
        "name_zh": "救生艇",
        "name_en": "Lifeboat",
        "tags": [
          "module.safety",
          "module.efficient"
        ],
        "definition": {
          "id": "core:safety_module/lifeboat",
          "name_key": "module.core.lifeboat.name",
          "description_key": "module.core.lifeboat.description",
          "tags": [
            "module.safety",
            "module.efficient"
          ],
          "enabled": true,
          "data": {
            "tier": 1,
            "weight": 4,
            "purchase_price": 280,
            "craft_time_hours": 2,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 3
              }
            ],
            "risk_add": -0.015,
            "damage_mul": 0.9,
            "repair_cost_mul": 1
          }
        }
      },
      {
        "id": "core:safety_module/safety_valve",
        "content_type": "safety_modules",
        "file": "content/safety_modules.json",
        "name_key": "module.core.safety_valve.name",
        "name_zh": "安全阀组",
        "name_en": "Safety Valve Set",
        "tags": [
          "module.safety",
          "module.performance"
        ],
        "definition": {
          "id": "core:safety_module/safety_valve",
          "name_key": "module.core.safety_valve.name",
          "description_key": "module.core.safety_valve.description",
          "tags": [
            "module.safety",
            "module.performance"
          ],
          "enabled": true,
          "data": {
            "tier": 2,
            "weight": 6,
            "purchase_price": 760,
            "craft_time_hours": 4,
            "craft_cost": 130,
            "materials": [
              {
                "id": "core:good/brass",
                "amount": 4
              },
              {
                "id": "core:material/sealing_compound",
                "amount": 3
              }
            ],
            "risk_add": -0.03,
            "damage_mul": 0.75,
            "repair_cost_mul": 0.85
          }
        }
      },
      {
        "id": "core:cabin/passenger_cabin",
        "content_type": "cabins",
        "file": "content/cabins.json",
        "name_key": "module.core.passenger_cabin.name",
        "name_zh": "固定客舱",
        "name_en": "Fixed Passenger Cabin",
        "tags": [
          "module.cabin",
          "module.passenger"
        ],
        "definition": {
          "id": "core:cabin/passenger_cabin",
          "name_key": "module.core.passenger_cabin.name",
          "description_key": "module.core.passenger_cabin.description",
          "tags": [
            "module.cabin",
            "module.passenger"
          ],
          "enabled": true,
          "data": {
            "tier": 1,
            "weight": 12,
            "purchase_price": 600,
            "craft_time_hours": 4,
            "materials": [
              {
                "id": "core:good/timber",
                "amount": 4
              },
              {
                "id": "core:good/textiles",
                "amount": 3
              }
            ],
            "passenger_capacity": 4
          }
        }
      },
      {
        "id": "core:role/engineer_basic",
        "content_type": "roles",
        "file": "content/roles.json",
        "name_key": "role.core.engineer_basic.name",
        "name_zh": "工程师",
        "name_en": "Engineer",
        "tags": [
          "role.engineer",
          "role.crew"
        ],
        "definition": {
          "id": "core:role/engineer_basic",
          "name_key": "role.core.engineer_basic.name",
          "description_key": "role.core.engineer_basic.description",
          "tags": [
            "role.engineer",
            "role.crew"
          ],
          "enabled": true,
          "data": {
            "kind": "engineer",
            "wage_per_voyage": 40,
            "hire_cost": 100,
            "modifiers": [
              {
                "stat": "risk",
                "op": "add",
                "value": -0.015
              },
              {
                "stat": "repair_cost",
                "op": "mul",
                "value": 0.85
              },
              {
                "stat": "damage",
                "op": "mul",
                "value": 0.95
              }
            ]
          }
        }
      },
      {
        "id": "core:role/navigator_basic",
        "content_type": "roles",
        "file": "content/roles.json",
        "name_key": "role.core.navigator_basic.name",
        "name_zh": "领航员",
        "name_en": "Navigator",
        "tags": [
          "role.navigator",
          "role.crew"
        ],
        "definition": {
          "id": "core:role/navigator_basic",
          "name_key": "role.core.navigator_basic.name",
          "description_key": "role.core.navigator_basic.description",
          "tags": [
            "role.navigator",
            "role.crew"
          ],
          "enabled": true,
          "data": {
            "kind": "navigator",
            "wage_per_voyage": 35,
            "hire_cost": 100,
            "modifiers": [
              {
                "stat": "risk",
                "op": "add",
                "value": -0.02
              },
              {
                "stat": "speed",
                "op": "mul",
                "value": 1.03
              }
            ]
          }
        }
      },
      {
        "id": "core:strategy/economic",
        "content_type": "strategies",
        "file": "content/strategies.json",
        "name_key": "strategy.core.economic.name",
        "name_zh": "经济",
        "name_en": "Economic",
        "tags": [
          "strategy.economy",
          "strategy.slow"
        ],
        "definition": {
          "id": "core:strategy/economic",
          "name_key": "strategy.core.economic.name",
          "description_key": "strategy.core.economic.description",
          "tags": [
            "strategy.economy",
            "strategy.slow"
          ],
          "enabled": true,
          "data": {
            "speed_mul": 0.8,
            "coal_mul": 0.68,
            "water_mul": 0.78,
            "risk_add": -0.01
          }
        }
      },
      {
        "id": "core:strategy/standard",
        "content_type": "strategies",
        "file": "content/strategies.json",
        "name_key": "strategy.core.standard.name",
        "name_zh": "标准",
        "name_en": "Standard",
        "tags": [
          "strategy.standard",
          "strategy.balanced"
        ],
        "definition": {
          "id": "core:strategy/standard",
          "name_key": "strategy.core.standard.name",
          "description_key": "strategy.core.standard.description",
          "tags": [
            "strategy.standard",
            "strategy.balanced"
          ],
          "enabled": true,
          "data": {
            "speed_mul": 1,
            "coal_mul": 1,
            "water_mul": 1,
            "risk_add": 0
          }
        }
      },
      {
        "id": "core:strategy/fast",
        "content_type": "strategies",
        "file": "content/strategies.json",
        "name_key": "strategy.core.fast.name",
        "name_zh": "极速",
        "name_en": "Full Speed",
        "tags": [
          "strategy.fast",
          "strategy.risky"
        ],
        "definition": {
          "id": "core:strategy/fast",
          "name_key": "strategy.core.fast.name",
          "description_key": "strategy.core.fast.description",
          "tags": [
            "strategy.fast",
            "strategy.risky"
          ],
          "enabled": true,
          "data": {
            "speed_mul": 1.28,
            "coal_mul": 1.8,
            "water_mul": 1.6,
            "risk_add": 0.06
          }
        }
      },
      {
        "id": "core:port_archetype/iron_harbor",
        "content_type": "port_archetypes",
        "file": "content/port_archetypes.json",
        "name_key": "port.core.iron_harbor.name",
        "name_zh": "铁港",
        "name_en": "Iron Harbor",
        "tags": [
          "port.hub",
          "port.industrial",
          "port.shipyard"
        ],
        "definition": {
          "id": "core:port_archetype/iron_harbor",
          "name_key": "port.core.iron_harbor.name",
          "description_key": "port.core.iron_harbor.description",
          "tags": [
            "port.hub",
            "port.industrial",
            "port.shipyard"
          ],
          "enabled": true,
          "data": {
            "size": "medium",
            "banner_asset": "banner.port.iron_harbor",
            "facilities": [
              "exchange",
              "contracts",
              "supply",
              "shipyard"
            ],
            "market": [
              {
                "good": "core:good/iron_ore",
                "stock_range": [
                  70,
                  130
                ]
              },
              {
                "good": "core:good/timber",
                "stock_range": [
                  80,
                  140
                ]
              },
              {
                "good": "core:good/brass",
                "stock_range": [
                  40,
                  90
                ],
                "price_bias": 0.95
              },
              {
                "good": "core:material/boiler_plate",
                "stock_range": [
                  30,
                  70
                ]
              },
              {
                "good": "core:material/sealing_compound",
                "stock_range": [
                  40,
                  80
                ]
              },
              {
                "good": "core:material/precision_gear",
                "stock_range": [
                  10,
                  25
                ]
              }
            ]
          }
        }
      },
      {
        "id": "core:port_archetype/spice_port",
        "content_type": "port_archetypes",
        "file": "content/port_archetypes.json",
        "name_key": "port.core.spice_port.name",
        "name_zh": "香料港",
        "name_en": "Spice Port",
        "tags": [
          "port.trade",
          "port.intel"
        ],
        "definition": {
          "id": "core:port_archetype/spice_port",
          "name_key": "port.core.spice_port.name",
          "description_key": "port.core.spice_port.description",
          "tags": [
            "port.trade",
            "port.intel"
          ],
          "enabled": true,
          "data": {
            "size": "small",
            "facilities": [
              "exchange",
              "contracts",
              "supply",
              "intel"
            ],
            "market": [
              {
                "good": "core:good/spices",
                "stock_range": [
                  30,
                  70
                ],
                "price_bias": 0.9
              },
              {
                "good": "core:good/textiles",
                "stock_range": [
                  50,
                  110
                ]
              },
              {
                "good": "core:good/glassware",
                "stock_range": [
                  30,
                  80
                ]
              },
              {
                "good": "core:material/sealing_compound",
                "stock_range": [
                  30,
                  60
                ]
              }
            ]
          }
        }
      },
      {
        "id": "core:port_archetype/free_town",
        "content_type": "port_archetypes",
        "file": "content/port_archetypes.json",
        "name_key": "port.core.free_town.name",
        "name_zh": "自由镇",
        "name_en": "Free Town",
        "tags": [
          "port.hub",
          "port.trade",
          "port.shipyard",
          "port.intel"
        ],
        "definition": {
          "id": "core:port_archetype/free_town",
          "name_key": "port.core.free_town.name",
          "description_key": "port.core.free_town.description",
          "tags": [
            "port.hub",
            "port.trade",
            "port.shipyard",
            "port.intel"
          ],
          "enabled": true,
          "data": {
            "size": "medium",
            "facilities": [
              "exchange",
              "contracts",
              "supply",
              "shipyard",
              "intel"
            ],
            "market": [
              {
                "good": "core:good/brass",
                "stock_range": [
                  40,
                  90
                ]
              },
              {
                "good": "core:good/timber",
                "stock_range": [
                  60,
                  120
                ]
              },
              {
                "good": "core:good/textiles",
                "stock_range": [
                  50,
                  100
                ]
              },
              {
                "good": "core:good/spices",
                "stock_range": [
                  25,
                  60
                ]
              },
              {
                "good": "core:good/glassware",
                "stock_range": [
                  30,
                  75
                ]
              },
              {
                "good": "core:material/boiler_plate",
                "stock_range": [
                  25,
                  60
                ]
              },
              {
                "good": "core:material/precision_gear",
                "stock_range": [
                  10,
                  25
                ]
              }
            ]
          }
        }
      },
      {
        "id": "core:port_archetype/fishing_village",
        "content_type": "port_archetypes",
        "file": "content/port_archetypes.json",
        "name_key": "port.core.fishing_village.name",
        "name_zh": "渔村",
        "name_en": "Fishing Village",
        "tags": [
          "port.rural",
          "port.supply"
        ],
        "definition": {
          "id": "core:port_archetype/fishing_village",
          "name_key": "port.core.fishing_village.name",
          "description_key": "port.core.fishing_village.description",
          "tags": [
            "port.rural",
            "port.supply"
          ],
          "enabled": true,
          "data": {
            "size": "small",
            "facilities": [
              "exchange",
              "contracts",
              "supply"
            ],
            "market": [
              {
                "good": "core:good/timber",
                "stock_range": [
                  90,
                  150
                ],
                "price_bias": 0.9
              },
              {
                "good": "core:good/iron_ore",
                "stock_range": [
                  60,
                  110
                ]
              },
              {
                "good": "core:good/textiles",
                "stock_range": [
                  40,
                  90
                ]
              },
              {
                "good": "core:material/sealing_compound",
                "stock_range": [
                  30,
                  70
                ]
              }
            ]
          }
        }
      },
      {
        "id": "core:port_archetype/glass_port",
        "content_type": "port_archetypes",
        "file": "content/port_archetypes.json",
        "name_key": "port.core.glass_port.name",
        "name_zh": "玻璃港",
        "name_en": "Glass Port",
        "tags": [
          "port.craft",
          "port.intel"
        ],
        "definition": {
          "id": "core:port_archetype/glass_port",
          "name_key": "port.core.glass_port.name",
          "description_key": "port.core.glass_port.description",
          "tags": [
            "port.craft",
            "port.intel"
          ],
          "enabled": true,
          "data": {
            "size": "small",
            "facilities": [
              "exchange",
              "contracts",
              "supply",
              "intel"
            ],
            "market": [
              {
                "good": "core:good/glassware",
                "stock_range": [
                  40,
                  90
                ],
                "price_bias": 0.9
              },
              {
                "good": "core:good/brass",
                "stock_range": [
                  35,
                  80
                ]
              },
              {
                "good": "core:good/spices",
                "stock_range": [
                  25,
                  55
                ]
              },
              {
                "good": "core:material/precision_gear",
                "stock_range": [
                  15,
                  40
                ]
              }
            ]
          }
        }
      },
      {
        "id": "core:map_profile/standard",
        "content_type": "map_profiles",
        "file": "content/map_profiles.json",
        "name_key": "map_profile.core.standard.name",
        "name_zh": "标准海图",
        "name_en": "Standard Chart",
        "tags": [
          "map.standard",
          "map.mvp"
        ],
        "definition": {
          "id": "core:map_profile/standard",
          "name_key": "map_profile.core.standard.name",
          "description_key": "map_profile.core.standard.description",
          "tags": [
            "map.standard",
            "map.mvp"
          ],
          "enabled": true,
          "data": {
            "port_count_range": [
              4,
              5
            ],
            "edge_count_range": [
              5,
              7
            ],
            "distance_range": [
              90,
              220
            ],
            "route_risk_range": [
              0.01,
              0.055
            ],
            "archetypes": [
              "core:port_archetype/iron_harbor",
              "core:port_archetype/spice_port",
              "core:port_archetype/free_town",
              "core:port_archetype/fishing_village",
              "core:port_archetype/glass_port"
            ],
            "port_name_keys": [
              "port_name.core.iron_harbor",
              "port_name.core.spice_port",
              "port_name.core.free_town",
              "port_name.core.fishing_village",
              "port_name.core.glass_port",
              "port_name.core.mist_cove"
            ],
            "start_archetype_tags": [
              "port.hub"
            ],
            "required_facility_tags": [
              "port.shipyard",
              "port.intel"
            ],
            "required_facility_max_edges": 2,
            "npc_count_range": [
              2,
              3
            ],
            "npc_cargo_range": [
              8,
              24
            ],
            "supply_prices": {
              "coal": 4,
              "water": 2,
              "repair_per_point": 6
            },
            "loan": {
              "limit": 400,
              "interest_rate": 0.1,
              "term_hours": 96
            },
            "intel_cost": 25,
            "trade_margin": 0.95,
            "player_trade_impact": 0.35,
            "default_starting_build": "core:starting_build/steady"
          }
        }
      },
      {
        "id": "core:starting_build/steady",
        "content_type": "starting_builds",
        "file": "content/starting_builds.json",
        "name_key": "starting_build.core.steady.name",
        "name_zh": "低耗稳健型",
        "name_en": "Steady and Thrifty",
        "tags": [
          "starting_build.efficient",
          "starting_build.safe"
        ],
        "definition": {
          "id": "core:starting_build/steady",
          "name_key": "starting_build.core.steady.name",
          "description_key": "starting_build.core.steady.description",
          "tags": [
            "starting_build.efficient",
            "starting_build.safe"
          ],
          "enabled": true,
          "data": {
            "money": 900,
            "reputation": 0,
            "hull": "core:hull/small_efficient",
            "boiler": "core:boiler/small_efficient",
            "cargo_modules": [
              "core:cargo_module/small_hold"
            ],
            "navigation_module": "core:navigation_module/spyglass",
            "safety_module": "core:safety_module/lifeboat",
            "engineer": "core:role/engineer_basic",
            "navigator": "core:role/navigator_basic",
            "coal": 26,
            "water": 18,
            "durability_ratio": 1
          }
        }
      },
      {
        "id": "core:starting_build/swift",
        "content_type": "starting_builds",
        "file": "content/starting_builds.json",
        "name_key": "starting_build.core.swift.name",
        "name_zh": "高速冒险型",
        "name_en": "Swift and Bold",
        "tags": [
          "starting_build.performance",
          "starting_build.risky"
        ],
        "definition": {
          "id": "core:starting_build/swift",
          "name_key": "starting_build.core.swift.name",
          "description_key": "starting_build.core.swift.description",
          "tags": [
            "starting_build.performance",
            "starting_build.risky"
          ],
          "enabled": true,
          "data": {
            "money": 700,
            "reputation": 0,
            "hull": "core:hull/small_efficient",
            "boiler": "core:boiler/performance",
            "cargo_modules": [
              "core:cargo_module/small_hold"
            ],
            "navigation_module": "core:navigation_module/spyglass",
            "navigator": "core:role/navigator_basic",
            "coal": 20,
            "water": 14,
            "durability_ratio": 0.9
          }
        }
      },
      {
        "id": "core:contract/main_01",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.main_01.name",
        "name_zh": "主线一：初次出航",
        "name_en": "Main 1: First Departure",
        "tags": [
          "contract.main",
          "contract.cargo",
          "contract.tutorial"
        ],
        "definition": {
          "id": "core:contract/main_01",
          "name_key": "contract.core.main_01.name",
          "description_key": "contract.core.main_01.description",
          "tags": [
            "contract.main",
            "contract.cargo",
            "contract.tutorial"
          ],
          "enabled": true,
          "data": {
            "kind": "main",
            "sequence": 1,
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "cargo",
                "name_key": "contract.core.main_01.payload",
                "cargo_item_id": "core:good/contract_freight",
                "weight_range": [
                  8,
                  12
                ]
              }
            ],
            "deadline_formula": "tutorial_first",
            "rewards": {
              "base_money": [
                220,
                260
              ],
              "on_time_bonus": [
                80,
                100
              ],
              "reputation": 1,
              "unlock_ids": []
            },
            "requires_completed": []
          }
        }
      },
      {
        "id": "core:contract/main_02",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.main_02.name",
        "name_zh": "主线二：自由贸易",
        "name_en": "Main 2: Free Trade",
        "tags": [
          "contract.main",
          "contract.cargo",
          "contract.tutorial"
        ],
        "definition": {
          "id": "core:contract/main_02",
          "name_key": "contract.core.main_02.name",
          "description_key": "contract.core.main_02.description",
          "tags": [
            "contract.main",
            "contract.cargo",
            "contract.tutorial"
          ],
          "enabled": true,
          "data": {
            "kind": "main",
            "sequence": 2,
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "cargo",
                "name_key": "contract.core.main_02.payload",
                "cargo_item_id": "core:good/contract_freight",
                "weight_range": [
                  10,
                  14
                ]
              }
            ],
            "deadline_formula": "tutorial_trade",
            "rewards": {
              "base_money": [
                300,
                340
              ],
              "on_time_bonus": [
                120,
                140
              ],
              "reputation": 1,
              "unlock_ids": []
            },
            "requires_completed": [
              "core:contract/main_01"
            ]
          }
        }
      },
      {
        "id": "core:contract/main_03",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.main_03.name",
        "name_zh": "主线三：模块制造",
        "name_en": "Main 3: Module Crafting",
        "tags": [
          "contract.main",
          "contract.cargo",
          "contract.tutorial"
        ],
        "definition": {
          "id": "core:contract/main_03",
          "name_key": "contract.core.main_03.name",
          "description_key": "contract.core.main_03.description",
          "tags": [
            "contract.main",
            "contract.cargo",
            "contract.tutorial"
          ],
          "enabled": true,
          "data": {
            "kind": "main",
            "sequence": 3,
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "cargo",
                "name_key": "contract.core.main_03.payload",
                "cargo_item_id": "core:good/contract_freight",
                "weight_range": [
                  12,
                  16
                ]
              }
            ],
            "deadline_formula": "tutorial_craft",
            "rewards": {
              "base_money": [
                380,
                420
              ],
              "on_time_bonus": [
                150,
                180
              ],
              "reputation": 1,
              "unlock_ids": [
                "core:hull/medium_standard",
                "core:cargo_module/medium_hold"
              ]
            },
            "requires_completed": [
              "core:contract/main_02"
            ]
          }
        }
      },
      {
        "id": "core:contract/main_04",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.main_04.name",
        "name_zh": "主线四：客运",
        "name_en": "Main 4: Passengers",
        "tags": [
          "contract.main",
          "contract.passenger",
          "contract.tutorial"
        ],
        "definition": {
          "id": "core:contract/main_04",
          "name_key": "contract.core.main_04.name",
          "description_key": "contract.core.main_04.description",
          "tags": [
            "contract.main",
            "contract.passenger",
            "contract.tutorial"
          ],
          "enabled": true,
          "data": {
            "kind": "main",
            "sequence": 4,
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "passenger",
                "name_key": "contract.core.main_04.payload",
                "count_range": [
                  2,
                  3
                ]
              }
            ],
            "deadline_formula": "passenger_run",
            "rewards": {
              "base_money": [
                420,
                460
              ],
              "on_time_bonus": [
                180,
                220
              ],
              "reputation": 2,
              "unlock_ids": [
                "core:safety_module/safety_valve"
              ]
            },
            "requires_completed": [
              "core:contract/main_03"
            ]
          }
        }
      },
      {
        "id": "core:contract/main_05",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.main_05.name",
        "name_zh": "主线五：综合挑战",
        "name_en": "Main 5: The Final Run",
        "tags": [
          "contract.main",
          "contract.cargo",
          "contract.passenger",
          "contract.finale"
        ],
        "definition": {
          "id": "core:contract/main_05",
          "name_key": "contract.core.main_05.name",
          "description_key": "contract.core.main_05.description",
          "tags": [
            "contract.main",
            "contract.cargo",
            "contract.passenger",
            "contract.finale"
          ],
          "enabled": true,
          "data": {
            "kind": "main",
            "sequence": 5,
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "cargo",
                "name_key": "contract.core.main_05.cargo",
                "cargo_item_id": "core:good/contract_freight",
                "weight_range": [
                  22,
                  30
                ]
              },
              {
                "kind": "passenger",
                "name_key": "contract.core.main_05.passengers",
                "count_range": [
                  2,
                  4
                ]
              }
            ],
            "deadline_formula": "balanced_finale",
            "rewards": {
              "base_money": [
                900,
                1200
              ],
              "on_time_bonus": [
                500,
                700
              ],
              "reputation": 2,
              "unlock_ids": [
                "core:hull/large_efficient",
                "core:hull/large_performance"
              ]
            },
            "requires_completed": [
              "core:contract/main_04"
            ]
          }
        }
      },
      {
        "id": "core:contract/normal_cargo_short",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.normal_cargo_short.name",
        "name_zh": "短途货运",
        "name_en": "Short Cargo Run",
        "tags": [
          "contract.normal",
          "contract.cargo"
        ],
        "definition": {
          "id": "core:contract/normal_cargo_short",
          "name_key": "contract.core.normal_cargo_short.name",
          "description_key": "contract.core.normal_cargo_short.description",
          "tags": [
            "contract.normal",
            "contract.cargo"
          ],
          "enabled": true,
          "data": {
            "kind": "normal",
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "cargo",
                "cargo_item_id": "core:good/contract_freight",
                "weight_range": [
                  6,
                  10
                ]
              }
            ],
            "deadline_formula": "normal_standard",
            "rewards": {
              "base_money": [
                140,
                180
              ],
              "on_time_bonus": [
                40,
                60
              ],
              "reputation": 1,
              "unlock_ids": []
            },
            "requires_completed": []
          }
        }
      },
      {
        "id": "core:contract/normal_cargo_long",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.normal_cargo_long.name",
        "name_zh": "大宗货运",
        "name_en": "Bulk Cargo Run",
        "tags": [
          "contract.normal",
          "contract.cargo"
        ],
        "definition": {
          "id": "core:contract/normal_cargo_long",
          "name_key": "contract.core.normal_cargo_long.name",
          "description_key": "contract.core.normal_cargo_long.description",
          "tags": [
            "contract.normal",
            "contract.cargo"
          ],
          "enabled": true,
          "data": {
            "kind": "normal",
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "cargo",
                "cargo_item_id": "core:good/contract_freight",
                "weight_range": [
                  14,
                  20
                ]
              }
            ],
            "deadline_formula": "normal_standard",
            "rewards": {
              "base_money": [
                240,
                300
              ],
              "on_time_bonus": [
                60,
                90
              ],
              "reputation": 1,
              "unlock_ids": []
            },
            "requires_completed": []
          }
        }
      },
      {
        "id": "core:contract/normal_passenger",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.normal_passenger.name",
        "name_zh": "短途客运",
        "name_en": "Short Passenger Run",
        "tags": [
          "contract.normal",
          "contract.passenger"
        ],
        "definition": {
          "id": "core:contract/normal_passenger",
          "name_key": "contract.core.normal_passenger.name",
          "description_key": "contract.core.normal_passenger.description",
          "tags": [
            "contract.normal",
            "contract.passenger"
          ],
          "enabled": true,
          "data": {
            "kind": "normal",
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "passenger",
                "count_range": [
                  1,
                  2
                ]
              }
            ],
            "deadline_formula": "normal_standard",
            "rewards": {
              "base_money": [
                180,
                220
              ],
              "on_time_bonus": [
                50,
                70
              ],
              "reputation": 1,
              "unlock_ids": []
            },
            "requires_completed": []
          }
        }
      },
      {
        "id": "core:contract/normal_urgent",
        "content_type": "contracts",
        "file": "content/contracts.json",
        "name_key": "contract.core.normal_urgent.name",
        "name_zh": "紧急货运",
        "name_en": "Urgent Cargo",
        "tags": [
          "contract.normal",
          "contract.cargo",
          "contract.urgent"
        ],
        "definition": {
          "id": "core:contract/normal_urgent",
          "name_key": "contract.core.normal_urgent.name",
          "description_key": "contract.core.normal_urgent.description",
          "tags": [
            "contract.normal",
            "contract.cargo",
            "contract.urgent"
          ],
          "enabled": true,
          "data": {
            "kind": "normal",
            "generator": "route_pair",
            "constraints": {
              "requires_discovered_origin": true,
              "min_route_edges": 1,
              "max_route_edges": 1,
              "required_port_tags": []
            },
            "payloads": [
              {
                "kind": "cargo",
                "cargo_item_id": "core:good/contract_freight",
                "weight_range": [
                  8,
                  12
                ]
              }
            ],
            "deadline_formula": "normal_urgent",
            "rewards": {
              "base_money": [
                220,
                260
              ],
              "on_time_bonus": [
                100,
                140
              ],
              "reputation": 1,
              "unlock_ids": []
            },
            "requires_completed": []
          }
        }
      },
      {
        "id": "core:event/boiler_overheat",
        "content_type": "events",
        "file": "content/events.json",
        "name_key": "event.core.boiler_overheat.name",
        "name_zh": "锅炉过热",
        "name_en": "Boiler Overheat",
        "tags": [
          "event.risk",
          "event.mechanical"
        ],
        "definition": {
          "id": "core:event/boiler_overheat",
          "name_key": "event.core.boiler_overheat.name",
          "description_key": "event.core.boiler_overheat.description",
          "tags": [
            "event.risk",
            "event.mechanical"
          ],
          "enabled": true,
          "data": {
            "trigger": "voyage_risk",
            "category": "mechanical",
            "weight": 1,
            "base_delay_hours": 0,
            "options": [
              {
                "id": "water_cooling",
                "name_key": "event.core.boiler_overheat.water_cooling",
                "weight": 1,
                "effects": [
                  {
                    "op": "remove_water",
                    "amount": 6
                  },
                  {
                    "op": "damage_ship",
                    "amount": 2
                  },
                  {
                    "op": "emit_notice",
                    "text_key": "notice.core.overheat.cooled"
                  }
                ]
              },
              {
                "id": "stop_repair",
                "name_key": "event.core.boiler_overheat.stop_repair",
                "weight": 1,
                "effects": [
                  {
                    "op": "add_delay_hours",
                    "amount": 5
                  },
                  {
                    "op": "repair_ship",
                    "amount": 4
                  },
                  {
                    "op": "emit_notice",
                    "text_key": "notice.core.overheat.repaired"
                  }
                ]
              },
              {
                "id": "paid_repair",
                "name_key": "event.core.boiler_overheat.paid_repair",
                "weight": 1,
                "condition": {
                  "op": "money_gte",
                  "value": 90
                },
                "effects": [
                  {
                    "op": "remove_money",
                    "amount": 90
                  },
                  {
                    "op": "repair_ship",
                    "amount": 6
                  },
                  {
                    "op": "add_delay_hours",
                    "amount": 1
                  },
                  {
                    "op": "emit_notice",
                    "text_key": "notice.core.overheat.paid"
                  }
                ]
              },
              {
                "id": "force_continue",
                "name_key": "event.core.boiler_overheat.force_continue",
                "weight": 1,
                "effects": [
                  {
                    "op": "damage_ship",
                    "amount": 9
                  },
                  {
                    "op": "add_delay_hours",
                    "amount": 1
                  },
                  {
                    "op": "emit_notice",
                    "text_key": "notice.core.overheat.forced"
                  }
                ]
              },
              {
                "id": "jettison_cargo",
                "name_key": "event.core.boiler_overheat.jettison_cargo",
                "weight": 1,
                "effects": [
                  {
                    "op": "damage_cargo",
                    "amount": 8
                  },
                  {
                    "op": "emit_notice",
                    "text_key": "notice.core.overheat.jettisoned"
                  }
                ]
              }
            ]
          }
        }
      },
      {
        "id": "core:event/merchant_intel",
        "content_type": "events",
        "file": "content/events.json",
        "name_key": "event.core.merchant_intel.name",
        "name_zh": "偶遇商船",
        "name_en": "Merchant Encounter",
        "tags": [
          "event.opportunity",
          "event.merchant"
        ],
        "definition": {
          "id": "core:event/merchant_intel",
          "name_key": "event.core.merchant_intel.name",
          "description_key": "event.core.merchant_intel.description",
          "tags": [
            "event.opportunity",
            "event.merchant"
          ],
          "enabled": true,
          "data": {
            "trigger": "voyage_opportunity",
            "category": "merchant",
            "weight": 1,
            "base_delay_hours": 0,
            "options": [
              {
                "id": "buy_intel",
                "name_key": "event.core.merchant_intel.buy_intel",
                "weight": 1,
                "condition": {
                  "op": "money_gte",
                  "value": 60
                },
                "effects": [
                  {
                    "op": "remove_money",
                    "amount": 60
                  },
                  {
                    "op": "update_intelligence"
                  },
                  {
                    "op": "emit_notice",
                    "text_key": "notice.core.merchant.bought"
                  }
                ]
              },
              {
                "id": "decline",
                "name_key": "event.core.merchant_intel.decline",
                "weight": 1,
                "effects": [
                  {
                    "op": "emit_notice",
                    "text_key": "notice.core.merchant.declined"
                  }
                ]
              }
            ]
          }
        }
      }
    ]
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
