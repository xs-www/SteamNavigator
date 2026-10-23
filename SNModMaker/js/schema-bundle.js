/*
 * AUTO-GENERATED FILE - do not edit by hand.
 * Source: /schemas (Content Schema 1.0 top-level + 2.0 runtime/draft under v2/)
 * Regenerate: node SNModMaker/tools/sync-schemas.mjs
 */
(function (root) {
  'use strict';
  root.SN_SCHEMAS = {
    "common.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/common-1.json",
      "title": "Steam Navigator common content schema",
      "$defs": {
        "id_ref": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9_]{2,31}:[a-z_]+/[a-z0-9_]+$"
        },
        "definition": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "name_key",
            "enabled",
            "data"
          ],
          "properties": {
            "id": {
              "$ref": "#/$defs/id_ref"
            },
            "name_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "description_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "tags": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string",
                "pattern": "^[a-z][a-z0-9_.-]*$"
              }
            },
            "enabled": {
              "type": "boolean"
            },
            "information": {
              "$ref": "#/$defs/entity_information"
            },
            "data": {
              "type": "object"
            }
          }
        },
        "entity_information": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "texture": {
              "type": "string",
              "minLength": 1,
              "maxLength": 120
            },
            "model": {
              "type": "string",
              "minLength": 1,
              "maxLength": 120
            }
          }
        },
        "range2": {
          "type": "array",
          "minItems": 2,
          "maxItems": 2,
          "items": {
            "type": "number"
          }
        },
        "modifier": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "stat",
            "op",
            "value"
          ],
          "properties": {
            "stat": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "op": {
              "enum": [
                "add",
                "mul",
                "set"
              ]
            },
            "value": {
              "type": "number"
            }
          }
        },
        "craft_material": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "amount"
          ],
          "properties": {
            "id": {
              "$ref": "#/$defs/id_ref"
            },
            "amount": {
              "type": "number",
              "minimum": 0.1
            }
          }
        },
        "module_common": {
          "type": "object",
          "additionalProperties": true,
          "required": [
            "tier",
            "weight",
            "purchase_price"
          ],
          "properties": {
            "tier": {
              "type": "integer",
              "minimum": 1,
              "maximum": 3
            },
            "weight": {
              "type": "number",
              "minimum": 0
            },
            "purchase_price": {
              "type": "number",
              "minimum": 0
            },
            "craft_time_hours": {
              "type": "number",
              "minimum": 0
            },
            "craft_cost": {
              "type": "number",
              "minimum": 0
            },
            "materials": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/craft_material"
              }
            },
            "modifiers": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/modifier"
              }
            },
            "unlock_reputation": {
              "type": "integer",
              "minimum": 0
            },
            "icon": {
              "type": "string",
              "minLength": 1
            }
          }
        },
        "payload": {
          "type": "object",
          "additionalProperties": true,
          "required": [
            "kind"
          ],
          "properties": {
            "kind": {
              "enum": [
                "cargo",
                "passenger"
              ]
            },
            "name_key": {
              "type": "string"
            },
            "weight_range": {
              "$ref": "#/$defs/range2"
            },
            "count_range": {
              "$ref": "#/$defs/range2"
            },
            "provider": {
              "enum": [
                "player",
                "fuel"
              ]
            }
          }
        },
        "rewards": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "base_money",
            "on_time_bonus",
            "reputation"
          ],
          "properties": {
            "base_money": {
              "$ref": "#/$defs/range2"
            },
            "on_time_bonus": {
              "$ref": "#/$defs/range2"
            },
            "reputation": {
              "type": "integer",
              "minimum": 0
            },
            "unlock_ids": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/id_ref"
              }
            }
          }
        },
        "condition_node": {
          "type": "object",
          "additionalProperties": true,
          "properties": {
            "all": {
              "type": "array",
              "maxItems": 16,
              "items": {
                "$ref": "#/$defs/condition_node"
              }
            },
            "any": {
              "type": "array",
              "maxItems": 16,
              "items": {
                "$ref": "#/$defs/condition_node"
              }
            },
            "not": {
              "$ref": "#/$defs/condition_node"
            },
            "op": {
              "enum": [
                "money_gte",
                "reputation_gte",
                "debt_lte",
                "at_port",
                "port_has_tag",
                "has_item",
                "has_module",
                "has_module_tag",
                "has_role",
                "contract_completed",
                "port_discovered",
                "ship_tier_gte",
                "durability_gte"
              ]
            },
            "value": {},
            "tag": {
              "type": "string"
            },
            "id": {
              "type": "string"
            },
            "item_id": {
              "type": "string"
            },
            "port_id": {
              "type": "string"
            },
            "role_kind": {
              "type": "string"
            }
          }
        },
        "effect": {
          "type": "object",
          "additionalProperties": true,
          "required": [
            "op"
          ],
          "properties": {
            "op": {
              "enum": [
                "add_money",
                "remove_money",
                "add_reputation",
                "remove_reputation",
                "add_item",
                "remove_item",
                "add_coal",
                "remove_coal",
                "add_water",
                "remove_water",
                "damage_ship",
                "repair_ship",
                "damage_module",
                "add_delay_hours",
                "damage_cargo",
                "injure_passenger",
                "unlock_definition",
                "complete_contract",
                "fail_voyage",
                "reveal_port_facilities",
                "update_intelligence",
                "emit_notice"
              ]
            },
            "amount": {
              "type": "number"
            },
            "id": {
              "type": "string"
            },
            "item_id": {
              "type": "string"
            },
            "contract_id": {
              "type": "string"
            },
            "port_id": {
              "type": "string"
            },
            "text_key": {
              "type": "string"
            },
            "slot": {
              "type": "string",
              "pattern": "^(boiler|navigation|safety|cabin|cargo)$"
            },
            "index": {
              "type": "integer",
              "minimum": 0
            }
          }
        }
      }
    },
    "manifest.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/mod-manifest-1.json",
      "title": "Steam Navigator mod manifest",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "id",
        "name",
        "version",
        "api_version",
        "type",
        "content"
      ],
      "properties": {
        "$schema": {
          "type": "string"
        },
        "id": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9_]{2,31}$"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 120
        },
        "version": {
          "type": "string",
          "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\\+[0-9A-Za-z.-]+)?$"
        },
        "api_version": {
          "type": "string",
          "pattern": "^[0-9]+\\.[0-9]+$"
        },
        "type": {
          "const": "content"
        },
        "load_priority": {
          "type": "integer",
          "minimum": -100,
          "maximum": 100
        },
        "required": {
          "type": "boolean"
        },
        "dependencies": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/dependency"
          }
        },
        "optional_dependencies": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/dependency"
          }
        },
        "conflicts": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "type": "string",
            "pattern": "^[a-z][a-z0-9_]{2,31}$"
          }
        },
        "content": {
          "type": "array",
          "minItems": 1,
          "uniqueItems": true,
          "items": {
            "type": "string",
            "minLength": 1
          }
        },
        "localization": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "type": "string",
            "minLength": 1
          }
        },
        "assets": {
          "type": "object",
          "additionalProperties": {
            "type": "string",
            "minLength": 1
          }
        },
        "authors": {
          "type": "array",
          "items": {
            "type": "string"
          }
        },
        "license": {
          "type": "string"
        },
        "description": {
          "type": "string"
        },
        "checksum": {
          "type": "string",
          "pattern": "^sha256:[a-f0-9]{64}$"
        },
        "capabilities": {
          "type": "array",
          "uniqueItems": true,
          "items": {
            "type": "string",
            "pattern": "^[a-z][a-z0-9_.-]*$"
          }
        }
      },
      "$defs": {
        "dependency": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id"
          ],
          "properties": {
            "id": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]{2,31}$"
            },
            "version": {
              "type": "string",
              "minLength": 1,
              "maxLength": 80
            }
          }
        }
      }
    },
    "v2/automation_rule.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/automation-rule-2.json",
      "title": "Steam Navigator automation rule content file (Content Schema 2.0)",
      "description": "Auto-trade automation rules (D4): ordered condition -> action overrides for a trade policy. IDs use core:automation_rule/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "automation_rules"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/automation_rule_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "automation_rule_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "policy_ref",
            "when",
            "condition",
            "action",
            "priority"
          ],
          "properties": {
            "policy_ref": {
              "description": "Trade policy this rule belongs to.",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "when": {
              "enum": [
                "tick",
                "arrival",
                "departure"
              ]
            },
            "condition": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "op"
              ],
              "properties": {
                "op": {
                  "enum": [
                    "always",
                    "money_gte",
                    "money_lte",
                    "cargo_gte",
                    "cargo_lte",
                    "margin_gte",
                    "risk_gte"
                  ]
                },
                "value": {
                  "type": "number"
                }
              }
            },
            "action": {
              "enum": [
                "pause",
                "resume",
                "sell_now",
                "buy_now"
              ]
            },
            "priority": {
              "type": "integer",
              "minimum": 0,
              "maximum": 100
            }
          }
        }
      }
    },
    "v2/base_site.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/base-site-2.json",
      "title": "Steam Navigator base site content file (Content Schema 2.0)",
      "description": "Player base archetypes (D3): building slots, storage, upkeep, defense and claim cost. A base instance binds one archetype to a world port; IDs use core:base_site/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "base_sites"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/base_site_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "worker_seed": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "role",
            "amount"
          ],
          "properties": {
            "role": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "amount": {
              "type": "integer",
              "minimum": 0,
              "maximum": 20
            }
          }
        },
        "base_site_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "slot_count",
            "storage_capacity",
            "maintenance_per_tick",
            "claim_cost_money"
          ],
          "properties": {
            "slot_count": {
              "description": "Building slots available on this site.",
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            "storage_capacity": {
              "description": "Base storage capacity in weight units.",
              "type": "number",
              "minimum": 50,
              "maximum": 20000
            },
            "maintenance_per_tick": {
              "description": "Money paid every simulation tick while the base exists.",
              "type": "number",
              "minimum": 0,
              "maximum": 1000
            },
            "defense": {
              "description": "Base defense contribution before buildings.",
              "type": "integer",
              "minimum": 0,
              "maximum": 500
            },
            "claim_cost_money": {
              "description": "One-off money cost to claim the site.",
              "type": "number",
              "minimum": 0,
              "maximum": 100000
            },
            "starting_workers": {
              "description": "Optional worker pool granted on claim (content-driven bootstrap).",
              "type": "array",
              "maxItems": 4,
              "items": {
                "$ref": "#/$defs/worker_seed"
              }
            },
            "starting_storage": {
              "description": "Optional items granted to base storage on claim.",
              "type": "array",
              "maxItems": 6,
              "items": {
                "$ref": "common.schema.json#/$defs/cargo_stack"
              }
            }
          }
        }
      }
    },
    "v2/boiler_strategy.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/boiler-strategy-2.json",
      "title": "Steam Navigator boiler strategy content file (Content Schema 2.0)",
      "description": "Boiler propulsion strategy definitions (C4): speed / coal / water multipliers and risk adjustment. Successor of the 1.0 `strategies` content type; the data block is unchanged, the type, id segment and default file are renamed to boiler_strategies / core:boiler_strategy/* / content/boiler_strategies.json.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "boiler_strategies"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/boiler_strategy_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "boiler_strategy_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "speed_mul",
            "coal_mul",
            "water_mul",
            "risk_add"
          ],
          "properties": {
            "speed_mul": {
              "type": "number",
              "minimum": 0.2,
              "maximum": 2
            },
            "coal_mul": {
              "type": "number",
              "minimum": 0,
              "maximum": 4
            },
            "water_mul": {
              "type": "number",
              "minimum": 0,
              "maximum": 4
            },
            "risk_add": {
              "type": "number",
              "minimum": -0.2,
              "maximum": 0.3
            }
          }
        }
      }
    },
    "v2/building.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/building-2.json",
      "title": "Steam Navigator base building content file (Content Schema 2.0)",
      "description": "Base buildings (D3): construction cost and time, worker slots, upkeep, storage/defense contributions and the production recipes the building can run. IDs use core:building/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "buildings"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/building_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "building_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "category",
            "build_cost_money",
            "build_time_hours",
            "worker_slots",
            "upkeep_per_tick",
            "max_level"
          ],
          "properties": {
            "category": {
              "enum": [
                "production",
                "storage",
                "defense",
                "utility"
              ]
            },
            "build_cost_money": {
              "description": "Money paid when the building is placed.",
              "type": "number",
              "minimum": 0,
              "maximum": 50000
            },
            "build_cost_items": {
              "description": "Items consumed from base storage when the building is placed.",
              "type": "array",
              "maxItems": 6,
              "items": {
                "$ref": "common.schema.json#/$defs/cargo_stack"
              }
            },
            "build_time_hours": {
              "description": "Construction time in simulation hours.",
              "type": "number",
              "minimum": 0,
              "maximum": 720
            },
            "worker_slots": {
              "description": "Maximum workers assignable to this building.",
              "type": "integer",
              "minimum": 0,
              "maximum": 8
            },
            "worker_role": {
              "description": "Worker role required to staff this building.",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "upkeep_per_tick": {
              "description": "Money paid every simulation tick while built.",
              "type": "number",
              "minimum": 0,
              "maximum": 1000
            },
            "storage_capacity": {
              "description": "Storage added to the base when the building is ready.",
              "type": "number",
              "minimum": 0,
              "maximum": 20000
            },
            "defense": {
              "description": "Defense added to the base when the building is ready.",
              "type": "integer",
              "minimum": 0,
              "maximum": 500
            },
            "max_level": {
              "description": "Highest level this building can reach (1-3).",
              "type": "integer",
              "minimum": 1,
              "maximum": 3
            },
            "recipes": {
              "description": "Production recipes this building can run.",
              "type": "array",
              "maxItems": 8,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            }
          }
        }
      }
    },
    "v2/building_upgrade.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/building-upgrade-2.json",
      "title": "Steam Navigator building upgrade content file (Content Schema 2.0)",
      "description": "Base building upgrades (D3): one step from a building level to the next, with cost, time and stat modifiers. IDs use core:building_upgrade/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "building_upgrades"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/building_upgrade_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "building_upgrade_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "building_ref",
            "from_level",
            "to_level",
            "cost_money",
            "time_hours"
          ],
          "properties": {
            "building_ref": {
              "description": "Building definition this upgrade belongs to.",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "from_level": {
              "type": "integer",
              "minimum": 1,
              "maximum": 2
            },
            "to_level": {
              "type": "integer",
              "minimum": 2,
              "maximum": 3
            },
            "cost_money": {
              "type": "number",
              "minimum": 0,
              "maximum": 50000
            },
            "cost_items": {
              "description": "Items consumed from base storage when the upgrade starts.",
              "type": "array",
              "maxItems": 6,
              "items": {
                "$ref": "common.schema.json#/$defs/cargo_stack"
              }
            },
            "time_hours": {
              "type": "number",
              "minimum": 0,
              "maximum": 720
            },
            "modifiers": {
              "description": "Stat modifiers applied while the building is at least to_level (production_speed / storage_capacity / defense).",
              "type": "array",
              "maxItems": 8,
              "items": {
                "$ref": "common.schema.json#/$defs/modifier"
              }
            }
          }
        }
      }
    },
    "v2/captain.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/captain-2.json",
      "title": "Steam Navigator captain content file (Content Schema 2.0)",
      "description": "Fleet captains (D2): skills, traits, wage and starting loyalty, plus the hull classes they may command. IDs use core:captain/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "captains"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/captain_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "captain_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "skills",
            "wage_per_voyage",
            "loyalty",
            "commandable_archetypes"
          ],
          "properties": {
            "skills": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "navigation",
                "gunnery",
                "engineering",
                "leadership"
              ],
              "properties": {
                "navigation": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 100
                },
                "gunnery": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 100
                },
                "engineering": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 100
                },
                "leadership": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 100
                }
              }
            },
            "traits": {
              "description": "Free-form trait tags (e.g. captain.drillmaster); runtime may map known tags to modifiers.",
              "type": "array",
              "maxItems": 8,
              "items": {
                "type": "string",
                "minLength": 1,
                "maxLength": 64
              }
            },
            "wage_per_voyage": {
              "type": "number",
              "minimum": 0,
              "maximum": 5000
            },
            "loyalty": {
              "description": "Initial loyalty 0–100.",
              "type": "integer",
              "minimum": 0,
              "maximum": 100
            },
            "commandable_archetypes": {
              "description": "Ship archetypes this captain may command (ship_archetypes).",
              "type": "array",
              "minItems": 1,
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            }
          }
        }
      }
    },
    "v2/combat_ability.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/combat-ability-2.json",
      "title": "Steam Navigator combat ability content file (Content Schema 2.0)",
      "description": "Combat ability / AI behavior parameters (D1). Abilities are data, not scripts: they pick one S-N Battle Simulator FSM action and tune the tactic thresholds the runtime AI consumes. IDs use core:combat_ability/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "combat_abilities"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/combat_ability_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "combat_ability_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "action"
          ],
          "properties": {
            "action": {
              "description": "Primary FSM action (SNBattleSim FSM_ACTIONS): recon / cruise / approach / flank / evade / maneuver / withdraw / flee / engage / focus.",
              "enum": [
                "recon",
                "cruise",
                "approach",
                "flank",
                "evade",
                "maneuver",
                "withdraw",
                "flee",
                "engage",
                "focus"
              ]
            },
            "target_priority": {
              "description": "Which enemy the AI prefers (SNBattleSim tactic.targetPriority).",
              "enum": [
                "nearest",
                "cargo",
                "weakest"
              ]
            },
            "preferred_range": {
              "description": "Preferred engagement range as a 0–1 fraction of weapon range (tactic.preferredRange).",
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "approach_threshold": {
              "description": "Approach when the target is farther than this multiple of preferred range (tactic.approachThreshold).",
              "type": "number",
              "minimum": 0.1,
              "maximum": 3
            },
            "withdraw_threshold": {
              "description": "Withdraw when the target is closer than this multiple (tactic.withdrawThreshold).",
              "type": "number",
              "minimum": 0.1,
              "maximum": 3
            },
            "retreat_hull": {
              "description": "Hull ratio below which the ability retreats (tactic.retreatHull).",
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "engage_speed": {
              "description": "Throttle fraction used while engaging (tactic.engageSpeed).",
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "cargo_behavior": {
              "description": "How a convoy escort reacts when its cargo is threatened.",
              "enum": [
                "flee",
                "ignore",
                "defend"
              ]
            }
          }
        }
      }
    },
    "v2/combat_ai_profile.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/combat-ai-profile-2.json",
      "title": "Steam Navigator combat AI profile content file (Content Schema 2.0 draft)",
      "description": "Combat AI profiles (D-AI, schema-first draft): an FSM decision graph plus its targeting/rang control parameters, aligned with SNBattleSim/docs/FSM_MOD_CONTRACT.md and SNBattleSim/js/tactics.mjs normalisation limits. The Godot runtime does not load this type yet; it is editable and draft-validated only. IDs use core:combat_ai_profile/* once promoted.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "combat_ai_profiles"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/combat_ai_profile_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "fsm_node_id": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9_]{0,23}$"
        },
        "fsm_node": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "runtime_action"
          ],
          "properties": {
            "id": {
              "$ref": "#/$defs/fsm_node_id"
            },
            "runtime_action": {
              "description": "Safe FSM action shared with the battle simulator (SNBattleSim FSM_ACTIONS).",
              "enum": [
                "recon",
                "cruise",
                "approach",
                "flank",
                "evade",
                "maneuver",
                "withdraw",
                "flee",
                "engage",
                "focus"
              ]
            },
            "name_key": {
              "description": "Optional localization key for the editor graph label; defaults to the node id.",
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "x": {
              "description": "Optional graph position 0.08–0.92 (simulator FSM import/export).",
              "type": "number",
              "minimum": 0.08,
              "maximum": 0.92
            },
            "y": {
              "description": "Optional graph position 0.08–0.92.",
              "type": "number",
              "minimum": 0.08,
              "maximum": 0.92
            }
          }
        },
        "fsm_transition": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "from",
            "to",
            "logic",
            "conditions"
          ],
          "properties": {
            "from": {
              "$ref": "#/$defs/fsm_node_id"
            },
            "to": {
              "$ref": "#/$defs/fsm_node_id"
            },
            "logic": {
              "description": "all = every condition must hold, any = one is enough.",
              "enum": [
                "all",
                "any"
              ]
            },
            "conditions": {
              "description": "Condition enum shared with the battle simulator (SNBattleSim FSM_CONDITIONS); at most 8 per transition.",
              "type": "array",
              "minItems": 1,
              "maxItems": 8,
              "items": {
                "enum": [
                  "cargo_threatened",
                  "no_target",
                  "visible_target",
                  "last_known_target",
                  "withdraw_trigger",
                  "withdraw_recovered",
                  "enemy_in_range",
                  "enemy_out_of_range",
                  "weapon_ready",
                  "broadside_ready",
                  "commander_present",
                  "hull_below",
                  "has_target",
                  "target_far",
                  "target_band",
                  "always"
                ]
              }
            }
          }
        },
        "combat_ai_profile_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "target_priority",
            "preferred_range",
            "initial",
            "nodes",
            "transitions"
          ],
          "properties": {
            "target_priority": {
              "enum": [
                "nearest",
                "cargo",
                "weakest"
              ]
            },
            "preferred_range": {
              "description": "Preferred engagement range as a 0–1 fraction of weapon range (simulator tactic.preferredRange).",
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "initial": {
              "description": "Initial node id; must appear in nodes (semantic check).",
              "$ref": "#/$defs/fsm_node_id"
            },
            "nodes": {
              "description": "FSM states (simulator limit: at most 20).",
              "type": "array",
              "minItems": 1,
              "maxItems": 20,
              "items": {
                "$ref": "#/$defs/fsm_node"
              }
            },
            "transitions": {
              "description": "Ordered transitions per from-node (simulator limit: at most 80). The first satisfied transition wins.",
              "type": "array",
              "maxItems": 80,
              "items": {
                "$ref": "#/$defs/fsm_transition"
              }
            }
          }
        }
      }
    },
    "v2/common.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/common-2.json",
      "title": "Steam Navigator common content schema 2.0",
      "description": "Shared definitions for Content Schema 2.0 files. Uses only the subset supported by the project SchemaValidator.",
      "$defs": {
        "id_ref": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9_]{2,31}:[a-z_]+/[a-z0-9_]+$"
        },
        "tag": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9_.-]*$"
        },
        "definition": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "name_key",
            "enabled",
            "data"
          ],
          "properties": {
            "id": {
              "$ref": "#/$defs/id_ref"
            },
            "name_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "description_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "tags": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "#/$defs/tag"
              }
            },
            "enabled": {
              "type": "boolean"
            },
            "information": {
              "$ref": "#/$defs/entity_information"
            },
            "data": {
              "type": "object"
            }
          }
        },
        "entity_information": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "texture": {
              "type": "string",
              "minLength": 1,
              "maxLength": 120
            },
            "model": {
              "type": "string",
              "minLength": 1,
              "maxLength": 120
            }
          }
        },
        "range2": {
          "type": "array",
          "minItems": 2,
          "maxItems": 2,
          "items": {
            "type": "number"
          }
        },
        "integer_range2": {
          "type": "array",
          "minItems": 2,
          "maxItems": 2,
          "items": {
            "type": "integer",
            "minimum": 0
          }
        },
        "cargo_stack": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "item",
            "amount"
          ],
          "properties": {
            "item": {
              "$ref": "#/$defs/id_ref"
            },
            "amount": {
              "type": "integer",
              "minimum": 1
            }
          }
        },
        "tag_list": {
          "type": "array",
          "minItems": 1,
          "uniqueItems": true,
          "items": {
            "$ref": "#/$defs/tag"
          }
        },
        "story_presentation": {
          "enum": [
            "card",
            "briefing",
            "debrief",
            "toast",
            "choice",
            "radio",
            "camera_hint"
          ]
        },
        "story_stage": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "advance"
          ],
          "properties": {
            "id": {
              "type": "string",
              "minLength": 1
            },
            "checkpoint": {
              "type": "boolean"
            },
            "presentation": {
              "$ref": "#/$defs/story_presentation"
            },
            "dialogue": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "title_key",
                "body_keys"
              ],
              "properties": {
                "title_key": {
                  "type": "string",
                  "minLength": 1
                },
                "body_keys": {
                  "type": "array",
                  "minItems": 1,
                  "items": {
                    "type": "string",
                    "minLength": 1
                  }
                }
              }
            },
            "unlock_features": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string"
              }
            },
            "unlock_items": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "#/$defs/id_ref"
              }
            },
            "unlock_modules": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "#/$defs/id_ref"
              }
            },
            "objective": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "text_key",
                "target"
              ],
              "properties": {
                "text_key": {
                  "type": "string",
                  "minLength": 1
                },
                "target": {
                  "type": "integer",
                  "minimum": 1
                }
              }
            },
            "advance": {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "mode": {
                  "enum": [
                    "confirm"
                  ]
                },
                "event": {
                  "type": "string",
                  "minLength": 1
                },
                "counter": {
                  "type": "string",
                  "minLength": 1
                },
                "counter_from": {
                  "type": "string",
                  "minLength": 1
                },
                "at_least": {
                  "type": "integer",
                  "minimum": 1
                },
                "flag": {
                  "type": "string",
                  "minLength": 1
                },
                "not_flag": {
                  "type": "string",
                  "minLength": 1
                },
                "all": {
                  "type": "array",
                  "minItems": 1,
                  "items": {
                    "$ref": "#/$defs/story_condition"
                  }
                },
                "match": {
                  "$ref": "#/$defs/story_match"
                }
              }
            },
            "lock_actions": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string"
              }
            },
            "preferred_strategy": {
              "type": "string",
              "minLength": 1
            },
            "effects": {
              "type": "array",
              "items": {
                "type": "object",
                "required": [
                  "type"
                ],
                "properties": {
                  "type": {
                    "type": "string",
                    "minLength": 1
                  }
                }
              }
            }
          }
        },
        "story_condition": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "event": {
              "type": "string",
              "minLength": 1
            },
            "counter": {
              "type": "string",
              "minLength": 1
            },
            "counter_from": {
              "type": "string",
              "minLength": 1
            },
            "at_least": {
              "type": "integer",
              "minimum": 1
            },
            "flag": {
              "type": "string",
              "minLength": 1
            },
            "not_flag": {
              "type": "string",
              "minLength": 1
            },
            "match": {
              "$ref": "#/$defs/story_match"
            }
          }
        },
        "story_match": {
          "type": "object",
          "additionalProperties": {
            "type": "string"
          }
        },
        "modifier": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "stat",
            "op",
            "value"
          ],
          "properties": {
            "stat": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "op": {
              "enum": [
                "add",
                "mul",
                "set"
              ]
            },
            "value": {
              "type": "number"
            }
          }
        },
        "condition_node": {
          "type": "object",
          "additionalProperties": true,
          "properties": {
            "all": {
              "type": "array",
              "maxItems": 16,
              "items": {
                "$ref": "#/$defs/condition_node"
              }
            },
            "any": {
              "type": "array",
              "maxItems": 16,
              "items": {
                "$ref": "#/$defs/condition_node"
              }
            },
            "not": {
              "$ref": "#/$defs/condition_node"
            },
            "op": {
              "enum": [
                "money_gte",
                "reputation_gte",
                "debt_lte",
                "at_port",
                "port_has_tag",
                "has_item",
                "has_module",
                "has_module_tag",
                "has_role",
                "contract_completed",
                "port_discovered",
                "ship_tier_gte",
                "durability_gte"
              ]
            },
            "value": {},
            "tag": {
              "type": "string"
            },
            "id": {
              "type": "string"
            },
            "item_id": {
              "type": "string"
            },
            "port_id": {
              "type": "string"
            },
            "role_kind": {
              "type": "string"
            }
          }
        },
        "effect": {
          "type": "object",
          "additionalProperties": true,
          "required": [
            "op"
          ],
          "properties": {
            "op": {
              "enum": [
                "add_money",
                "remove_money",
                "add_reputation",
                "remove_reputation",
                "add_item",
                "remove_item",
                "add_coal",
                "remove_coal",
                "add_water",
                "remove_water",
                "damage_ship",
                "repair_ship",
                "damage_module",
                "add_delay_hours",
                "damage_cargo",
                "injure_passenger",
                "unlock_definition",
                "complete_contract",
                "fail_voyage",
                "reveal_port_facilities",
                "update_intelligence",
                "emit_notice"
              ]
            },
            "amount": {
              "type": "number"
            },
            "id": {
              "type": "string"
            },
            "item_id": {
              "type": "string"
            },
            "contract_id": {
              "type": "string"
            },
            "port_id": {
              "type": "string"
            },
            "text_key": {
              "type": "string"
            },
            "slot": {
              "type": "string",
              "pattern": "^(boiler|navigation|safety|cabin|cargo)$"
            },
            "index": {
              "type": "integer",
              "minimum": 0
            }
          }
        },
        "payload": {
          "type": "object",
          "additionalProperties": true,
          "required": [
            "kind"
          ],
          "properties": {
            "kind": {
              "enum": [
                "cargo",
                "passenger"
              ]
            },
            "name_key": {
              "type": "string"
            },
            "weight_range": {
              "$ref": "#/$defs/range2"
            },
            "count_range": {
              "$ref": "#/$defs/range2"
            },
            "provider": {
              "enum": [
                "player",
                "fuel"
              ]
            }
          }
        },
        "rewards": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "base_money",
            "on_time_bonus",
            "reputation"
          ],
          "properties": {
            "base_money": {
              "$ref": "#/$defs/range2"
            },
            "on_time_bonus": {
              "$ref": "#/$defs/range2"
            },
            "reputation": {
              "type": "integer",
              "minimum": 0
            },
            "unlock_ids": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/id_ref"
              }
            }
          }
        }
      }
    },
    "v2/contract.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/contract-2.json",
      "title": "Steam Navigator contract content file (Content Schema 2.0)",
      "description": "Transport contracts (C4): generation constraints, cargo/passenger payloads, deadline formula and rewards. Successor of the 1.0 `contracts` content type; the data block and IDs (core:contract/*) are unchanged, only the envelope moves to Content Schema 2.0 and the schema file moves to schemas/v2/contract.schema.json.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "contracts"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/contract_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "contract_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "generator",
            "payloads",
            "deadline_formula",
            "rewards"
          ],
          "properties": {
            "kind": {
              "enum": [
                "main",
                "normal"
              ]
            },
            "sequence": {
              "type": "integer",
              "minimum": 0,
              "maximum": 99
            },
            "generator": {
              "enum": [
                "route_pair",
                "random_pair"
              ]
            },
            "constraints": {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "requires_discovered_origin": {
                  "type": "boolean"
                },
                "min_route_edges": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 8
                },
                "max_route_edges": {
                  "type": "integer",
                  "minimum": 0,
                  "maximum": 8
                },
                "required_port_tags": {
                  "type": "array",
                  "items": {
                    "type": "string"
                  }
                }
              }
            },
            "payloads": {
              "type": "array",
              "minItems": 1,
              "maxItems": 4,
              "items": {
                "$ref": "common.schema.json#/$defs/payload"
              }
            },
            "deadline_formula": {
              "type": "string",
              "minLength": 1
            },
            "rewards": {
              "$ref": "common.schema.json#/$defs/rewards"
            },
            "requires_completed": {
              "type": "array",
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            }
          }
        }
      }
    },
    "v2/crew_role.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/crew-role-2.json",
      "title": "Steam Navigator crew role content file (Content Schema 2.0)",
      "description": "Crew role definitions (C4): kind, per-voyage wage, hire cost and stat modifiers. Successor of the 1.0 `roles` content type; the data block is unchanged, the type, id segment and default file are renamed to crew_roles / core:crew_role/* / content/crew_roles.json.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "crew_roles"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/crew_role_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "crew_role_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "wage_per_voyage"
          ],
          "properties": {
            "kind": {
              "enum": [
                "engineer",
                "navigator"
              ]
            },
            "wage_per_voyage": {
              "type": "number",
              "minimum": 0
            },
            "hire_cost": {
              "type": "number",
              "minimum": 0
            },
            "modifiers": {
              "type": "array",
              "items": {
                "$ref": "common.schema.json#/$defs/modifier"
              }
            }
          }
        }
      }
    },
    "v2/damage_type.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/damage-type-2.json",
      "title": "Steam Navigator damage type content file (Content Schema 2.0)",
      "description": "Combat damage types (D1): small registry entries referenced by weapons and defences. The registry deliberately has no damage-type interaction matrix; runtime consumers apply armor_pierce and status metadata. IDs use core:damage_type/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "damage_types"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/damage_type_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "damage_type_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "color"
          ],
          "properties": {
            "color": {
              "description": "Hit / effect tint (#RRGGBB), shared by weapons that reference this damage type.",
              "type": "string",
              "pattern": "^#[0-9a-fA-F]{6}$"
            },
            "armor_pierce": {
              "description": "0–1 share of the damage that ignores target armor; the registry keeps this scalar instead of a damage x armor matrix.",
              "type": "number",
              "minimum": 0,
              "maximum": 1,
              "default": 0
            },
            "status_effect": {
              "description": "Optional status applied by hits of this type; empty means no status.",
              "enum": [
                "none",
                "burn",
                "shock",
                "flood"
              ]
            }
          }
        }
      }
    },
    "v2/discovery.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/discovery-2.json",
      "title": "Steam Navigator discovery content file (Content Schema 2.0)",
      "description": "Codex entry prototype: what a site/ruin reveals, its rarity, spawn weight and the ids it unlocks.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "discoveries"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/discovery_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "discovery_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "rarity",
            "weight",
            "repeatable"
          ],
          "properties": {
            "kind": {
              "enum": [
                "site",
                "ruin_room",
                "relic",
                "species",
                "blueprint",
                "lore"
              ]
            },
            "rarity": {
              "enum": [
                "common",
                "uncommon",
                "rare",
                "unique"
              ]
            },
            "weight": {
              "type": "integer",
              "minimum": 1
            },
            "repeatable": {
              "type": "boolean"
            },
            "source_site_kinds": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "enum": [
                  "ruin",
                  "base_site",
                  "resource",
                  "wreck",
                  "landmark",
                  "encounter"
                ]
              }
            },
            "region_kinds": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "enum": [
                  "coastal",
                  "archipelago",
                  "open_sea",
                  "industrial",
                  "frontier"
                ]
              }
            },
            "requires_tags": {
              "$ref": "common.schema.json#/$defs/tag_list"
            },
            "unlock_ids": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            }
          }
        }
      }
    },
    "v2/encounter_table.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/encounter-table-2.json",
      "title": "Steam Navigator encounter table content file (Content Schema 2.0)",
      "description": "Weighted encounter tables (D1): which enemy archetypes appear, in what counts and relative weights. Tables are content, the weighted roll belongs to the runtime. IDs use core:encounter_table/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "encounter_tables"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/encounter_table_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "encounter_table_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "entries"
          ],
          "properties": {
            "kind": {
              "description": "Encounter context: patrol / ambush / convoy / blockade / ruin.",
              "enum": [
                "patrol",
                "ambush",
                "convoy",
                "blockade",
                "ruin"
              ]
            },
            "danger": {
              "description": "0–10 designer-facing danger score (UI / encounter selection).",
              "type": "number",
              "minimum": 0,
              "maximum": 10
            },
            "entries": {
              "type": "array",
              "minItems": 1,
              "maxItems": 16,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "enemy_archetype",
                  "weight"
                ],
                "properties": {
                  "enemy_archetype": {
                    "$ref": "common.schema.json#/$defs/id_ref"
                  },
                  "weight": {
                    "type": "number",
                    "exclusiveMinimum": 0
                  },
                  "count_range": {
                    "$ref": "common.schema.json#/$defs/range2"
                  }
                }
              }
            }
          }
        }
      }
    },
    "v2/enemy_archetype.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/enemy-archetype-2.json",
      "title": "Steam Navigator enemy archetype content file (Content Schema 2.0)",
      "description": "Enemy ship archetypes (D1). Stats mirror the tooling/combat_kit catalogue (enemy_class / weapon_sockets from the shipped SN_Enemy_* GLBs), the AI profile references a combat_ability, and loot references a loot_table. The definition's information.model points at the combat_kit GLB asset key. IDs use core:enemy_archetype/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "enemy_archetypes"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/enemy_archetype_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "enemy_archetype_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "enemy_class",
            "hull_points",
            "armor",
            "max_speed",
            "turn_rate_deg",
            "weapon_sockets",
            "combat_ability"
          ],
          "properties": {
            "enemy_class": {
              "description": "Combat kit class (tools/modeling/combat_kit_catalog.json enemy_classes).",
              "enum": [
                "Light",
                "Medium",
                "Heavy"
              ]
            },
            "hull_points": {
              "description": "Enemy hull hit points before armor mitigation.",
              "type": "number",
              "minimum": 20,
              "maximum": 2000
            },
            "armor": {
              "description": "0–0.8 flat damage reduction fraction.",
              "type": "number",
              "minimum": 0,
              "maximum": 0.8
            },
            "max_speed": {
              "description": "Top speed in combat simulation units (SNBattleSim ship tuning).",
              "type": "number",
              "minimum": 1,
              "maximum": 30
            },
            "turn_rate_deg": {
              "description": "Hull turn rate in degrees per second.",
              "type": "number",
              "minimum": 5,
              "maximum": 180
            },
            "weapon_sockets": {
              "description": "Ordered socket classes copied from the combat_kit GLB weapon_sockets (SN_Socket_Weapon_*); the runtime mounts weapons whose weapon_class fits.",
              "type": "array",
              "minItems": 1,
              "maxItems": 8,
              "items": {
                "enum": [
                  "Light",
                  "Medium",
                  "Heavy",
                  "Tower",
                  "Side"
                ]
              }
            },
            "combat_ability": {
              "description": "AI profile reference (combat_abilities).",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "loot_table": {
              "description": "Optional loot table reference (loot_tables).",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "encounter_tags": {
              "description": "Optional tags that encounter tables use to bias this archetype.",
              "type": "array",
              "items": {
                "type": "string"
              }
            }
          }
        }
      }
    },
    "v2/expedition_event.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/expedition-event-2.json",
      "title": "Steam Navigator expedition event content file (Content Schema 2.0)",
      "description": "Ruin expedition events (D5): prompt, 1-3 options and their effect ops. IDs use core:expedition_event/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "expedition_events"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/expedition_event_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "expedition_event_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "text_key",
            "options"
          ],
          "properties": {
            "text_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "options": {
              "type": "array",
              "minItems": 1,
              "maxItems": 3,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "text_key",
                  "effect"
                ],
                "properties": {
                  "text_key": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 160
                  },
                  "name_key": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 160
                  },
                  "effect": {
                    "$ref": "common.schema.json#/$defs/effect"
                  }
                }
              }
            }
          }
        }
      }
    },
    "v2/faction.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/faction-2.json",
      "title": "Steam Navigator faction content file (Content Schema 2.0)",
      "description": "Persistent faction prototype: attitude thresholds, trade affinity, patrol presence and rivalries.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "factions"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/faction_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "attitude_thresholds": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "hostile_below",
            "friendly_at"
          ],
          "properties": {
            "hostile_below": {
              "type": "integer",
              "minimum": -100,
              "maximum": 100
            },
            "friendly_at": {
              "type": "integer",
              "minimum": -100,
              "maximum": 100
            }
          }
        },
        "faction_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "starting_reputation",
            "attitude_thresholds",
            "patrol_strength"
          ],
          "properties": {
            "kind": {
              "enum": [
                "merchant_guild",
                "naval",
                "scientific",
                "pirates",
                "civic",
                "industrial"
              ]
            },
            "starting_reputation": {
              "type": "integer",
              "minimum": -100,
              "maximum": 100
            },
            "attitude_thresholds": {
              "$ref": "#/$defs/attitude_thresholds"
            },
            "patrol_strength": {
              "type": "integer",
              "minimum": 0,
              "maximum": 10
            },
            "trade_goods": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "home_region_tags": {
              "$ref": "common.schema.json#/$defs/tag_list"
            },
            "contract_family": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "rival_factions": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            }
          }
        }
      }
    },
    "v2/fleet_doctrine.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/fleet-doctrine-2.json",
      "title": "Steam Navigator fleet doctrine content file (Content Schema 2.0)",
      "description": "Fleet doctrines (D2): engagement / retreat behaviour, escort role, target priority and resupply policy, with an optional default formation. IDs use core:fleet_doctrine/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "fleet_doctrines"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/fleet_doctrine_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "fleet_doctrine_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "engagement",
            "retreat",
            "target_priority",
            "supply_policy"
          ],
          "properties": {
            "engagement": {
              "enum": [
                "aggressive",
                "balanced",
                "defensive",
                "evasive"
              ]
            },
            "retreat": {
              "enum": [
                "never",
                "when_damaged",
                "when_outnumbered",
                "when_cargo_threatened"
              ]
            },
            "escort": {
              "description": "Convoy role: none / convoy escort / patrol / screen.",
              "enum": [
                "none",
                "convoy",
                "patrol",
                "screen"
              ]
            },
            "target_priority": {
              "enum": [
                "nearest",
                "cargo",
                "weakest"
              ]
            },
            "supply_policy": {
              "enum": [
                "conservative",
                "standard",
                "aggressive"
              ]
            },
            "formation": {
              "description": "Optional default formation reference.",
              "$ref": "common.schema.json#/$defs/id_ref"
            }
          }
        }
      }
    },
    "v2/formation.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/formation-2.json",
      "title": "Steam Navigator formation content file (Content Schema 2.0)",
      "description": "Fleet formations (D2): named slots with chart offsets and roles, an optional per-slot target preference, and formation-wide stat bonuses. IDs use core:formation/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "formations"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/formation_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "formation_offset": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "x",
            "y"
          ],
          "properties": {
            "x": {
              "description": "Relative chart offset along the fleet heading.",
              "type": "number",
              "minimum": -100,
              "maximum": 100
            },
            "y": {
              "description": "Relative lateral chart offset.",
              "type": "number",
              "minimum": -100,
              "maximum": 100
            }
          }
        },
        "formation_slot": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "role",
            "offset"
          ],
          "properties": {
            "id": {
              "description": "Stable slot id referenced by data.fleet ships (e.g. flagship / left / right).",
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]{0,31}$"
            },
            "role": {
              "enum": [
                "flagship",
                "line",
                "screen",
                "flank",
                "reserve"
              ]
            },
            "offset": {
              "$ref": "#/$defs/formation_offset"
            },
            "target_priority": {
              "description": "Optional per-slot target preference (overrides the doctrine).",
              "enum": [
                "nearest",
                "cargo",
                "weakest"
              ]
            }
          }
        },
        "formation_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "slots"
          ],
          "properties": {
            "max_ships": {
              "description": "Optional ship count cap; defaults to slots length. The framework also clamps it to MAX_SHIPS (5).",
              "type": "integer",
              "minimum": 1,
              "maximum": 5
            },
            "slots": {
              "type": "array",
              "minItems": 1,
              "maxItems": 5,
              "items": {
                "$ref": "#/$defs/formation_slot"
              }
            },
            "bonuses": {
              "description": "Formation-wide modifiers (stat / op / value, same DSL as modules).",
              "type": "array",
              "items": {
                "$ref": "common.schema.json#/$defs/modifier"
              }
            }
          }
        }
      }
    },
    "v2/hazard_table.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/hazard-table-2.json",
      "title": "Steam Navigator hazard table content file (Content Schema 2.0)",
      "description": "Ruin hazard tables (D5): weighted hazards with type, amount range and text. IDs use core:hazard_table/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "hazard_tables"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/hazard_table_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "hazard_table_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "entries"
          ],
          "properties": {
            "entries": {
              "type": "array",
              "minItems": 1,
              "maxItems": 8,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "type",
                  "weight",
                  "amount_range"
                ],
                "properties": {
                  "type": {
                    "enum": [
                      "durability",
                      "money",
                      "cargo"
                    ]
                  },
                  "weight": {
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 100
                  },
                  "amount_range": {
                    "$ref": "common.schema.json#/$defs/integer_range2"
                  },
                  "text_key": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 160
                  }
                }
              }
            }
          }
        }
      }
    },
    "v2/hull.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/hull-2.json",
      "title": "Steam Navigator hull content file (Content Schema 2.0)",
      "description": "Ship hull definitions promoted to Content Schema 2.0 (C1). Fields are unchanged from the 1.0 hull schema: economy block, sailing stats and the weapon/rig socket mirrors used by the shipyard editor. The content type and core hull ids are kept.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "hulls"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/hull_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "craft_material": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "amount"
          ],
          "properties": {
            "id": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "amount": {
              "type": "number",
              "minimum": 0.1
            }
          }
        },
        "modifier": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "stat",
            "op",
            "value"
          ],
          "properties": {
            "stat": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "op": {
              "enum": [
                "add",
                "mul",
                "set"
              ]
            },
            "value": {
              "type": "number"
            }
          }
        },
        "blueprint_position": {
          "description": "船厂蓝图中的归一化槽位坐标。side / top 分别对应侧视图和俯视图，原点在图像左上角，坐标范围为 0..1；至少提供一个视图。",
          "type": "object",
          "additionalProperties": false,
          "minProperties": 1,
          "default": {
            "side": [
              0.5,
              0.5
            ]
          },
          "properties": {
            "side": {
              "$ref": "#/$defs/normalized_vector2"
            },
            "top": {
              "$ref": "#/$defs/normalized_vector2"
            }
          }
        },
        "normalized_vector2": {
          "description": "JSON 表示的 Vector2：[x, y]，两个分量均为 0..1。",
          "type": "array",
          "minItems": 2,
          "maxItems": 2,
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          }
        },
        "blueprint_view": {
          "description": "船体蓝图某一视图的线稿绑定。image 是 mod 资源键；坐标即相对该线稿（space=trimmed，默认）或未裁切画布（space=canvas）的归一化值。",
          "type": "object",
          "additionalProperties": false,
          "required": [
            "image"
          ],
          "properties": {
            "image": {
              "description": "线稿图片的资源键（manifest.assets 中的键，例如 blueprint.ship.side）。",
              "type": "string",
              "minLength": 1,
              "maxLength": 120,
              "pattern": "^[a-z][a-z0-9_.-]*$"
            },
            "width": {
              "description": "线稿像素宽（仅元数据；编辑器可回填）。",
              "type": "integer",
              "minimum": 1
            },
            "height": {
              "description": "线稿像素高（仅元数据；编辑器可回填）。",
              "type": "integer",
              "minimum": 1
            },
            "space": {
              "description": "坐标基准：trimmed = 裁切后线稿纹理（默认），canvas = 未裁切渲染画布。",
              "enum": [
                "trimmed",
                "canvas"
              ]
            }
          }
        },
        "blueprint_views": {
          "description": "船体蓝图的每视图线稿绑定。至少绑定一个视图；槽位坐标的 side/top 与这里的键一一对应。",
          "type": "object",
          "additionalProperties": false,
          "minProperties": 1,
          "properties": {
            "side": {
              "$ref": "#/$defs/blueprint_view"
            },
            "top": {
              "$ref": "#/$defs/blueprint_view"
            }
          }
        },
        "compartment_mount": {
          "description": "船体提供的舱位安装位：可独立选中、装载货舱/客舱模块并配置蓝图坐标。",
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id"
          ],
          "properties": {
            "id": {
              "description": "船体内唯一的稳定标识，运行时存档与 UI 选中使用。",
              "type": "string",
              "minLength": 1,
              "maxLength": 32,
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "blueprint_position": {
              "$ref": "#/$defs/blueprint_position"
            },
            "max_tier": {
              "description": "可装载舱位模块的最高等级；缺省表示不额外限制。",
              "type": "integer",
              "minimum": 1,
              "maximum": 3
            },
            "allowed_types": {
              "description": "允许装载的舱位模块类型；省略或空数组表示全部类型。",
              "type": "array",
              "uniqueItems": true,
              "maxItems": 2,
              "items": {
                "enum": [
                  "cargo",
                  "cabin"
                ]
              }
            },
            "note": {
              "type": "string",
              "maxLength": 200
            }
          }
        },
        "module_slot": {
          "description": "船体提供的模块安装位；内部模块只需蓝图坐标，外部模块可附 GLB socket 引用。",
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id"
          ],
          "properties": {
            "id": {
              "type": "string",
              "minLength": 1,
              "maxLength": 32,
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "blueprint_position": {
              "$ref": "#/$defs/blueprint_position"
            },
            "allowed_categories": {
              "description": "允许安装的模块 v2_category；省略或空数组表示不额外限制。",
              "type": "array",
              "uniqueItems": true,
              "maxItems": 5,
              "items": {
                "enum": [
                  "boiler",
                  "cargo",
                  "utility",
                  "cabin",
                  "crew"
                ]
              }
            },
            "socket": {
              "description": "可选 GLB 节点名（外部模块装配点，例如 SN_Socket_Module_Crane_1）。",
              "type": "string",
              "maxLength": 64,
              "pattern": "^SN_Socket_"
            },
            "note": {
              "type": "string",
              "maxLength": 200
            }
          }
        },
        "weapon_socket": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "name",
            "socket_class",
            "socket_index"
          ],
          "properties": {
            "name": {
              "description": "GLB 节点名（标准名，例如 SN_Socket_Weapon_Port_1）。",
              "type": "string",
              "pattern": "^SN_Socket_Weapon"
            },
            "socket_class": {
              "description": "可安装武器的 weapon_class；装配时是硬门禁。",
              "enum": [
                "Light",
                "Medium",
                "Heavy",
                "Tower",
                "Side"
              ]
            },
            "socket_index": {
              "description": "安装点序号，用于稳定排序与 UI 编号。",
              "type": "integer",
              "minimum": 0,
              "maximum": 64
            },
            "blueprint": {
              "$ref": "#/$defs/blueprint_position"
            },
            "pair": {
              "description": "左右舷同型约束的对端 socket 名（例如 SN_Socket_Weapon_Starboard_1）；省略表示独立安装位。",
              "type": "string",
              "maxLength": 64,
              "pattern": "^SN_Socket_Weapon"
            },
            "position": {
              "description": "船体局部坐标 [x, y, z]（米）；z 为该点甲板实测高度。",
              "type": "array",
              "minItems": 3,
              "maxItems": 3,
              "items": {
                "type": "number"
              }
            },
            "clearance_r": {
              "description": "16 向水平射线最小自由距离（米）。",
              "type": "number",
              "minimum": 0,
              "maximum": 30
            },
            "clearance_x": {
              "description": "socket 局部 ±X 较小自由距离（米）；侧舷点 +X 为舷外（炮口方向）。",
              "type": "number",
              "minimum": 0,
              "maximum": 30
            },
            "clearance_y": {
              "description": "socket 局部 ±Y 较小自由距离（米）；侧舷点沿船体纵轴（炮列方向）。",
              "type": "number",
              "minimum": 0,
              "maximum": 30
            },
            "clearance_h": {
              "description": "安装面向上首个遮挡高度（米）；露天按 20 m 封顶。",
              "type": "number",
              "minimum": 0,
              "maximum": 40
            },
            "mount_scale": {
              "description": "装配时武器本体的统一缩放。",
              "type": "number",
              "minimum": 0.1,
              "maximum": 10
            },
            "note": {
              "description": "人类可读备注；装配忽略。",
              "type": "string",
              "maxLength": 200
            }
          }
        },
        "rig_socket": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "name",
            "socket_kind",
            "socket_index"
          ],
          "properties": {
            "name": {
              "description": "GLB 节点名（标准名，例如 SN_Socket_Mast_Fore）。",
              "type": "string",
              "pattern": "^SN_Socket_"
            },
            "socket_kind": {
              "enum": [
                "mast",
                "yard",
                "sail"
              ]
            },
            "mast_id": {
              "description": "所属桅杆标识（fore / main / mizzen 等）。",
              "type": "string",
              "maxLength": 32
            },
            "socket_index": {
              "type": "integer",
              "minimum": 0,
              "maximum": 64
            },
            "position": {
              "description": "船体局部坐标 [x, y, z]（米）；z 为该点甲板实测高度。",
              "type": "array",
              "minItems": 3,
              "maxItems": 3,
              "items": {
                "type": "number"
              }
            },
            "rig_height": {
              "type": "number",
              "minimum": 0,
              "maximum": 80
            },
            "rig_deck_z": {
              "type": "number",
              "minimum": 0,
              "maximum": 80
            },
            "rig_yard_z": {
              "type": "number",
              "minimum": 0,
              "maximum": 80
            },
            "rig_yard_length": {
              "type": "number",
              "minimum": 0,
              "maximum": 80
            },
            "rig_stowed": {
              "type": "boolean"
            },
            "rig_sail_area_m2": {
              "type": "number",
              "minimum": 0,
              "maximum": 2000
            },
            "note": {
              "type": "string",
              "maxLength": 200
            }
          }
        },
        "rig_plan": {
          "description": "运行时帆索装配计划（ShipVisualAssembler）：声明该船体用哪套 rig_kit 部件替换烘焙帆索。GLB 里的 SN_Socket_Mast/Yard/Sail_* 空节点仍是安装点唯一真源；本字段只决定装哪些资产、隐藏哪些烘焙节点。缺省 = 保留 GLB 内烘焙帆索（rig_mode=baked）。",
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind"
          ],
          "properties": {
            "kind": {
              "description": "帆型 / 蒸汽船配置，用于报告与套件族选择（sail = 帆船桅，steam = 蒸汽船桅）。",
              "enum": [
                "sail",
                "steam"
              ]
            },
            "mount_kinds": {
              "description": "要填充的船体 socket 类型；缺省 [mast]。yard/sail 只在套件尺寸与烘焙件吻合时才声明。",
              "type": "array",
              "items": {
                "enum": [
                  "mast",
                  "yard",
                  "sail"
                ]
              },
              "uniqueItems": true,
              "maxItems": 3
            },
            "hide_nodes": {
              "description": "装配前隐藏（并从渲染中移除）的烘焙节点名，覆盖被 kit 替换的桅 / 桁；不写则保留原船，避免双层帆索。",
              "type": "array",
              "items": {
                "type": "string",
                "pattern": "^[A-Za-z0-9_]+$"
              },
              "maxItems": 64
            },
            "mast_asset": {
              "description": "桅杆套件资源键（如 model.rig.mast_sail / model.rig.mast_steam）。",
              "type": "string",
              "pattern": "^[a-z0-9_.]+$"
            },
            "yard_asset": {
              "description": "横桁 / 斜桁套件资源键。",
              "type": "string",
              "pattern": "^[a-z0-9_.]+$"
            },
            "sail_asset": {
              "description": "帆面套件资源键。",
              "type": "string",
              "pattern": "^[a-z0-9_.]+$"
            },
            "per_mast_assets": {
              "description": "每个桅点额外挂的索具套件资源键（侧支索 / 前后支索 / 动索）。",
              "type": "array",
              "items": {
                "type": "string",
                "pattern": "^[a-z0-9_.]+$"
              },
              "maxItems": 8
            },
            "yaw_deg": {
              "description": "挂件整体绕 socket 局部 +Y 的附加旋转（度），用于让套件轴向与烘焙布局对齐。",
              "type": "number",
              "minimum": -180,
              "maximum": 180
            }
          }
        },
        "hull_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "tier",
            "weight",
            "purchase_price",
            "base_speed",
            "max_weight",
            "max_durability",
            "cargo_slots",
            "cabin_slots",
            "base_risk"
          ],
          "properties": {
            "tier": {
              "type": "integer",
              "minimum": 1,
              "maximum": 3
            },
            "weight": {
              "type": "number",
              "minimum": 0
            },
            "purchase_price": {
              "type": "number",
              "minimum": 0
            },
            "craft_time_hours": {
              "type": "number",
              "minimum": 0
            },
            "craft_cost": {
              "type": "number",
              "minimum": 0
            },
            "materials": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/craft_material"
              }
            },
            "modifiers": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/modifier"
              }
            },
            "unlock_reputation": {
              "type": "integer",
              "minimum": 0
            },
            "icon": {
              "type": "string",
              "minLength": 1
            },
            "base_speed": {
              "type": "number",
              "minimum": 1
            },
            "max_weight": {
              "type": "number",
              "minimum": 1
            },
            "max_durability": {
              "type": "number",
              "minimum": 1
            },
            "cargo_slots": {
              "type": "integer",
              "minimum": 0,
              "maximum": 8
            },
            "cabin_slots": {
              "type": "integer",
              "minimum": 0,
              "maximum": 4
            },
            "base_cargo_capacity": {
              "description": "船体自带的初始货舱空间；总货舱容量 = 本值 + Σ(货舱模块 capacity × condition)。",
              "type": "number",
              "minimum": 0
            },
            "blueprint_views": {
              "$ref": "#/$defs/blueprint_views"
            },
            "compartments": {
              "description": "船体提供的舱位安装位；数组长度即数量上限，每个安装位可独立配置蓝图坐标、等级与类型限制。",
              "type": "array",
              "maxItems": 32,
              "items": {
                "$ref": "#/$defs/compartment_mount"
              }
            },
            "module_slots": {
              "description": "船体提供的模块安装位；内部模块只需蓝图坐标，外部模块可附 socket 引用。",
              "type": "array",
              "maxItems": 32,
              "items": {
                "$ref": "#/$defs/module_slot"
              }
            },
            "base_risk": {
              "type": "number",
              "minimum": 0,
              "maximum": 0.5
            },
            "size_tag": {
              "enum": [
                "small",
                "medium",
                "large"
              ]
            },
            "weapon_sockets": {
              "description": "内容侧的船体武器安装点镜像（与 GLB 里 SN_Socket_Weapon_* 节点 extras 同口径）。运行时装配仍读 GLB extras；这里供编辑器查看、编辑与校验，并作为后续数据驱动装配的前向声明。",
              "type": "array",
              "items": {
                "$ref": "#/$defs/weapon_socket"
              }
            },
            "rig_sockets": {
              "description": "内容侧的船体帆索安装点镜像（与 GLB 里 SN_Socket_Mast/Yard/Sail_* 节点 extras 同口径，见 RIG_KIT_CONTRACT.md）。运行时装配仍读 GLB extras。",
              "type": "array",
              "items": {
                "$ref": "#/$defs/rig_socket"
              }
            },
            "rig_plan": {
              "$ref": "#/$defs/rig_plan"
            }
          }
        }
      }
    },
    "v2/item.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/item-2.json",
      "title": "Steam Navigator item content file (Content Schema 2.0)",
      "description": "Merged trade item family (C2): the former `goods` and `materials` content types now share one active type. `data.crafting_material` marks items that can be consumed by crafting/refit recipes; every other market field (weight, price, stock, elasticity, spawn weight, category, tier) is the union of the two legacy schemas. Content Schema 2.0 drops the 1.0 goods/material types and their ids.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "items"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/item_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "item_data": {
          "description": "Union of the legacy good_data and material_data blocks. `crafting_material` replaces the old content-type split: true = consumable by recipes (old materials plus craftable goods such as timber/brass/iron ore), false = pure trade/supply item.",
          "type": "object",
          "additionalProperties": false,
          "required": [
            "crafting_material",
            "unit_weight",
            "base_price",
            "base_stock",
            "price_elasticity"
          ],
          "properties": {
            "crafting_material": {
              "description": "是否可作为打造 / 改装材料消耗。old materials 恒为 true；old goods 中原本可打造者保留 true。",
              "type": "boolean"
            },
            "unit_weight": {
              "type": "number",
              "minimum": 0.1
            },
            "base_price": {
              "type": "number",
              "minimum": 1
            },
            "base_stock": {
              "type": "number",
              "minimum": 1
            },
            "price_elasticity": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "spawn_weight": {
              "description": "市场随机进货权重；0 = 只按供需/补给规则出现。",
              "type": "number",
              "minimum": 0
            },
            "category": {
              "description": "自由分类标签（ore/metal/plate/supply 等），市场与 UI 分组用。",
              "type": "string",
              "minLength": 1,
              "maxLength": 40
            },
            "tier": {
              "description": "材料品质等级；普通商品可省略。",
              "type": "integer",
              "minimum": 1,
              "maximum": 3
            }
          }
        }
      }
    },
    "v2/loot_table.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/loot-table-2.json",
      "title": "Steam Navigator loot table content file (Content Schema 2.0)",
      "description": "Weighted loot tables (D1): item / weapon / module drops plus an optional money range, rolled by the runtime after a victory. IDs use core:loot_table/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "loot_tables"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/loot_table_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "loot_table_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "entries"
          ],
          "properties": {
            "money_range": {
              "description": "Optional money reward range (same units as other content money fields).",
              "$ref": "common.schema.json#/$defs/range2"
            },
            "entries": {
              "type": "array",
              "minItems": 1,
              "maxItems": 32,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "kind",
                  "id",
                  "weight"
                ],
                "properties": {
                  "kind": {
                    "description": "Which content family the drop references; id is resolved in that registry.",
                    "enum": [
                      "item",
                      "weapon",
                      "module"
                    ]
                  },
                  "id": {
                    "$ref": "common.schema.json#/$defs/id_ref"
                  },
                  "weight": {
                    "type": "number",
                    "exclusiveMinimum": 0
                  },
                  "amount_range": {
                    "$ref": "common.schema.json#/$defs/range2"
                  }
                }
              }
            }
          }
        }
      }
    },
    "v2/map_config.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/map-config-2.json",
      "title": "Steam Navigator map config content file (Schema 2.0)",
      "description": "Scene tuning for a generated campaign: port archetypes/names, facilities, NPC and economy parameters, twin chart world size, exploration rules and the tutorial story flow. Successor of the 1.0 map_profile scenario block.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "map_configs"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/map_config_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "map_config_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "archetypes",
            "port_name_keys",
            "required_facility_tags"
          ],
          "properties": {
            "archetypes": {
              "type": "array",
              "minItems": 4,
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "port_name_keys": {
              "type": "array",
              "minItems": 4,
              "items": {
                "type": "string",
                "minLength": 1
              }
            },
            "start_archetype_tags": {
              "type": "array",
              "items": {
                "type": "string"
              }
            },
            "required_facility_tags": {
              "type": "array",
              "minItems": 1,
              "items": {
                "type": "string",
                "pattern": "^port\\.[a-z_]+$"
              }
            },
            "required_facility_max_edges": {
              "type": "integer",
              "minimum": 1,
              "maximum": 4
            },
            "npc_count_range": {
              "$ref": "common.schema.json#/$defs/range2"
            },
            "npc_cargo_range": {
              "$ref": "common.schema.json#/$defs/range2"
            },
            "supply_prices": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "coal",
                "water",
                "repair_per_point"
              ],
              "properties": {
                "coal": {
                  "type": "number",
                  "minimum": 0
                },
                "water": {
                  "type": "number",
                  "minimum": 0
                },
                "repair_per_point": {
                  "type": "number",
                  "minimum": 0
                }
              }
            },
            "loan": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "limit",
                "interest_rate",
                "term_hours"
              ],
              "properties": {
                "limit": {
                  "type": "number",
                  "minimum": 1
                },
                "interest_rate": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 0.5
                },
                "term_hours": {
                  "type": "number",
                  "minimum": 1
                }
              }
            },
            "intel_cost": {
              "type": "number",
              "minimum": 0
            },
            "trade_margin": {
              "type": "number",
              "minimum": 0.5,
              "maximum": 1
            },
            "player_trade_impact": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "default_starting_scenario": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "twin_world_size": {
              "type": "number",
              "minimum": 64,
              "maximum": 1024
            },
            "exploration": {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "rumor_clue_chance": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "fog_port_reveal_ratio": {
                  "type": "number",
                  "minimum": 0.01,
                  "maximum": 0.5
                },
                "fog_vision_ratio": {
                  "type": "number",
                  "minimum": 0.01,
                  "maximum": 0.5
                },
                "intel_clue_cost": {
                  "type": "number",
                  "minimum": 0
                },
                "max_active_clues": {
                  "type": "integer",
                  "minimum": 1,
                  "maximum": 12
                },
                "level_weights": {
                  "type": "object",
                  "additionalProperties": false,
                  "required": [
                    "rumor",
                    "intel"
                  ],
                  "properties": {
                    "rumor": {
                      "$ref": "#/$defs/level_weight_vector"
                    },
                    "intel": {
                      "$ref": "#/$defs/level_weight_vector"
                    }
                  }
                },
                "credibility_range": {
                  "type": "object",
                  "additionalProperties": false,
                  "required": [
                    "rumor",
                    "intel"
                  ],
                  "properties": {
                    "rumor": {
                      "$ref": "common.schema.json#/$defs/range2"
                    },
                    "intel": {
                      "$ref": "common.schema.json#/$defs/range2"
                    },
                    "wait": {
                      "$ref": "common.schema.json#/$defs/range2"
                    },
                    "contract": {
                      "$ref": "common.schema.json#/$defs/range2"
                    }
                  }
                },
                "distance_error_ratio": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "search_zone_radius": {
                  "type": "number",
                  "minimum": 0
                },
                "search_zone_noise": {
                  "type": "number",
                  "minimum": 0
                },
                "discovery_chance_base": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "discovery_chance_per_credibility": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "risk_base": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "risk_per_unreliability": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "drift_durability_loss": {
                  "type": "number",
                  "minimum": 0
                },
                "drift_extra_coal": {
                  "type": "number",
                  "minimum": 0
                },
                "drift_extra_water": {
                  "type": "number",
                  "minimum": 0
                },
                "drift_hours": {
                  "type": "number",
                  "minimum": 0
                },
                "alert_threshold": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "alert_progress": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "turnback_extra_ratio": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "investigation_cost": {
                  "type": "number",
                  "minimum": 0
                },
                "investigation_hours": {
                  "type": "number",
                  "minimum": 0
                },
                "investigation_success_chance": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "goods_clue_expiry_hours": {
                  "type": "object",
                  "additionalProperties": false,
                  "required": [
                    "rumor",
                    "intel",
                    "wait",
                    "contract"
                  ],
                  "properties": {
                    "rumor": {
                      "type": "number",
                      "minimum": 0
                    },
                    "intel": {
                      "type": "number",
                      "minimum": 0
                    },
                    "wait": {
                      "type": "number",
                      "minimum": 0
                    },
                    "contract": {
                      "type": "number",
                      "minimum": 0
                    }
                  }
                },
                "goods_clue_price_error_ratio": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "goods_clue_source_weights": {
                  "type": "object",
                  "additionalProperties": false,
                  "required": [
                    "rumor",
                    "intel",
                    "wait",
                    "contract"
                  ],
                  "properties": {
                    "rumor": {
                      "type": "number",
                      "minimum": 0,
                      "maximum": 1
                    },
                    "intel": {
                      "type": "number",
                      "minimum": 0,
                      "maximum": 1
                    },
                    "wait": {
                      "type": "number",
                      "minimum": 0,
                      "maximum": 1
                    },
                    "contract": {
                      "type": "number",
                      "minimum": 0,
                      "maximum": 1
                    }
                  }
                },
                "wait_clue_hours_block": {
                  "type": "number",
                  "minimum": 1
                },
                "wait_clue_chance_per_block": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "wait_clue_max_chance": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                },
                "contract_clue_chance": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1
                }
              }
            },
            "story": {
              "$ref": "#/$defs/story_flow"
            }
          }
        },
        "level_weight_vector": {
          "type": "array",
          "minItems": 4,
          "maxItems": 4,
          "items": {
            "type": "number",
            "minimum": 0,
            "maximum": 1
          }
        },
        "story_flow": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "flow_id",
            "stages"
          ],
          "properties": {
            "flow_id": {
              "type": "string",
              "minLength": 1
            },
            "enabled": {
              "type": "boolean"
            },
            "skip_unlocks": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string"
              }
            },
            "start_unlocks": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string"
              }
            },
            "start_items": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "start_modules": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "stages": {
              "type": "array",
              "minItems": 1,
              "items": {
                "$ref": "common.schema.json#/$defs/story_stage"
              }
            }
          }
        }
      }
    },
    "v2/module.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/module-2.json",
      "title": "Steam Navigator module content file (Content Schema 2.0)",
      "description": "Merged ship module family (C1): boilers, cargo holds, utility modules (navigation/safety) and passenger cabins share one active type. `data.v2_category` selects the category; the remaining fields are the union of the five legacy per-category schemas, so a single definition still carries exactly the numbers its category needs. Content Schema 2.0 drops the 1.0 slot-specific content types and their ids.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "modules"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/module_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "craft_material": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "amount"
          ],
          "properties": {
            "id": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "amount": {
              "type": "number",
              "minimum": 0.1
            }
          }
        },
        "modifier": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "stat",
            "op",
            "value"
          ],
          "properties": {
            "stat": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "op": {
              "enum": [
                "add",
                "mul",
                "set"
              ]
            },
            "value": {
              "type": "number"
            }
          }
        },
        "module_data": {
          "description": "Union of the five legacy module schemas. Required per category: boiler -> speed_mul/coal_rate/water_rate; cargo -> capacity; utility -> risk_add; cabin -> passenger_capacity. The schema cannot express those conditionals, so the runtime validates the category-specific block.",
          "type": "object",
          "additionalProperties": false,
          "required": [
            "v2_category",
            "tier",
            "weight",
            "purchase_price"
          ],
          "properties": {
            "v2_category": {
              "description": "模块分类。boiler=锅炉，cargo=货舱，utility=导航/安全等杂项功能，cabin=客舱；crew 为船员居住预留，Phase C 暂无内容。",
              "enum": [
                "boiler",
                "cargo",
                "utility",
                "cabin",
                "crew"
              ]
            },
            "tier": {
              "type": "integer",
              "minimum": 1,
              "maximum": 3
            },
            "weight": {
              "type": "number",
              "minimum": 0
            },
            "purchase_price": {
              "type": "number",
              "minimum": 0
            },
            "craft_time_hours": {
              "type": "number",
              "minimum": 0
            },
            "craft_cost": {
              "type": "number",
              "minimum": 0
            },
            "materials": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/craft_material"
              }
            },
            "modifiers": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/modifier"
              }
            },
            "unlock_reputation": {
              "type": "integer",
              "minimum": 0
            },
            "icon": {
              "type": "string",
              "minLength": 1
            },
            "speed_mul": {
              "description": "boiler / utility: 航速乘数。",
              "type": "number",
              "minimum": 0.2,
              "maximum": 3
            },
            "coal_rate": {
              "description": "boiler: 每小时煤耗。",
              "type": "number",
              "minimum": 0
            },
            "water_rate": {
              "description": "boiler: 每小时水耗。",
              "type": "number",
              "minimum": 0
            },
            "capacity": {
              "description": "cargo: 货舱容量。",
              "type": "number",
              "minimum": 1
            },
            "risk_add": {
              "description": "utility: 风险修正（负值为降低）。navigation / safety 共用。",
              "type": "number",
              "minimum": -0.5,
              "maximum": 0.5
            },
            "damage_mul": {
              "description": "utility / safety: 事故损伤乘数。",
              "type": "number",
              "minimum": 0,
              "maximum": 1.5
            },
            "repair_cost_mul": {
              "description": "utility / safety: 维修费用乘数。",
              "type": "number",
              "minimum": 0,
              "maximum": 2
            },
            "reveal_facilities": {
              "description": "utility / navigation: 出航前是否揭示目的港设施。",
              "type": "boolean"
            },
            "passenger_capacity": {
              "description": "cabin: 可搭载旅客数。",
              "type": "integer",
              "minimum": 1,
              "maximum": 12
            }
          }
        }
      }
    },
    "v2/patch.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/patch-2.json",
      "title": "Steam Navigator explicit patch content file (Content Schema 2.0)",
      "description": "Explicit patches that modify definitions of other mods (C4). Each definition declares the full target id (mod/type/definition), an optional source-mod version requirement, and JSON Patch-style operations against that definition. The envelope is Content Schema 2.0; patched definitions are re-validated against the current schema of the target content type, so the patch envelope version no longer selects a 1.0 fallback.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "patches"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "$ref": "#/$defs/patch_data"
          }
        }
      },
      "$defs": {
        "patch_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "target",
            "operations"
          ],
          "properties": {
            "target": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "requires": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "mod",
                "version"
              ],
              "properties": {
                "mod": {
                  "type": "string",
                  "pattern": "^[a-z][a-z0-9_]{2,31}$"
                },
                "version": {
                  "type": "string",
                  "minLength": 1
                }
              }
            },
            "operations": {
              "type": "array",
              "minItems": 1,
              "maxItems": 32,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "op",
                  "path"
                ],
                "properties": {
                  "op": {
                    "enum": [
                      "add",
                      "replace",
                      "remove"
                    ]
                  },
                  "path": {
                    "type": "string",
                    "pattern": "^/"
                  },
                  "value": {}
                }
              }
            }
          }
        }
      }
    },
    "v2/port_template.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/port-template-2.json",
      "title": "Steam Navigator port template content file (Content Schema 2.0)",
      "description": "Generated-port template (C4): size, facilities and market stock table. Successor of the 1.0 port_archetype content type; the data block is unchanged, the type, id segment and default file are renamed to port_templates / core:port_template/* / content/port_templates.json.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "port_templates"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/port_template_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "port_template_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "size",
            "facilities",
            "market"
          ],
          "properties": {
            "size": {
              "enum": [
                "small",
                "medium",
                "large"
              ]
            },
            "facilities": {
              "type": "array",
              "minItems": 2,
              "uniqueItems": true,
              "items": {
                "enum": [
                  "exchange",
                  "contracts",
                  "supply",
                  "shipyard",
                  "tavern",
                  "intel"
                ]
              }
            },
            "banner_asset": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_.-]*$"
            },
            "diorama": {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "kit": {
                  "type": "string",
                  "pattern": "^[a-z][a-z0-9_.-]*$"
                },
                "density": {
                  "enum": [
                    "sparse",
                    "normal",
                    "busy"
                  ]
                },
                "town": {
                  "type": "object",
                  "minProperties": 1,
                  "additionalProperties": {
                    "type": "string",
                    "pattern": "^[a-z][a-z0-9_.-]*$"
                  }
                },
                "facility_visuals": {
                  "type": "object",
                  "additionalProperties": {
                    "type": "string",
                    "pattern": "^[a-z][a-z0-9_.-]*$"
                  }
                },
                "palette": {
                  "type": "object",
                  "additionalProperties": {
                    "type": "string"
                  }
                },
                "landmark": {
                  "type": "string",
                  "pattern": "^[a-z][a-z0-9_.-]*$"
                }
              }
            },
            "market": {
              "type": "array",
              "minItems": 1,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "good",
                  "stock_range"
                ],
                "properties": {
                  "good": {
                    "$ref": "common.schema.json#/$defs/id_ref"
                  },
                  "stock_range": {
                    "$ref": "common.schema.json#/$defs/range2"
                  },
                  "price_bias": {
                    "type": "number",
                    "minimum": 0.5,
                    "maximum": 2
                  }
                }
              }
            }
          }
        }
      }
    },
    "v2/production_recipe.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/production-recipe-2.json",
      "title": "Steam Navigator production recipe content file (Content Schema 2.0)",
      "description": "Base production recipes (D3): item inputs and outputs, duration, required workers and money per batch. IDs use core:production_recipe/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "production_recipes"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/production_recipe_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "production_recipe_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "building_ref",
            "inputs",
            "outputs",
            "duration_hours"
          ],
          "properties": {
            "building_ref": {
              "description": "Building definition that can run this recipe.",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "inputs": {
              "description": "Items consumed from base storage when the batch starts.",
              "type": "array",
              "maxItems": 6,
              "items": {
                "$ref": "common.schema.json#/$defs/cargo_stack"
              }
            },
            "outputs": {
              "description": "Items added to base storage when the batch completes.",
              "type": "array",
              "minItems": 1,
              "maxItems": 4,
              "items": {
                "$ref": "common.schema.json#/$defs/cargo_stack"
              }
            },
            "duration_hours": {
              "description": "Base batch duration in simulation hours.",
              "type": "number",
              "minimum": 0.5,
              "maximum": 240
            },
            "workers_required": {
              "description": "Workers that must be assigned to the building while the batch runs.",
              "type": "integer",
              "minimum": 0,
              "maximum": 8
            },
            "money_cost": {
              "description": "Money paid when the batch starts.",
              "type": "number",
              "minimum": 0,
              "maximum": 50000
            }
          }
        }
      }
    },
    "v2/quest.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/quest-2.json",
      "title": "Steam Navigator quest content file (Content Schema 2.0)",
      "description": "Abstract guidance quest (C3): story performance, player guidance and non-transport system goals. A quest is a sequence of stages whose objectives reuse the story condition DSL (event / counter / at_least / match). Transport payload, deadlines and economy rewards stay on contracts; a quest may reference a spawned contract by id but never carries its payload or settlement.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "quests"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/quest_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "quest_objective": {
          "description": "A single countable objective, reusing the story/quest DSL. Completion is derived from persisted counters; the quest definition never stores progress.",
          "type": "object",
          "additionalProperties": false,
          "required": [
            "event"
          ],
          "properties": {
            "event": {
              "description": "触发事件名（与剧情 DSL 同一命名空间，例如 cmd:trade.buy / ui:arrival_settled）。",
              "type": "string",
              "minLength": 1,
              "maxLength": 120
            },
            "counter": {
              "description": "计数键；同 event 的多次触发累加到该 counter。",
              "type": "string",
              "minLength": 1,
              "maxLength": 120
            },
            "at_least": {
              "description": "目标进度阈值；省略时默认 1。",
              "type": "integer",
              "minimum": 1
            },
            "match": {
              "description": "事件 payload 的匹配条件（字符串键值），例如 {item_id: core:item/coal}。",
              "type": "object",
              "additionalProperties": {
                "type": "string"
              }
            },
            "text_key": {
              "description": "目标在任务追踪/任务日志中的展示文本键；省略时回退到 stage.title_key。",
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            }
          }
        },
        "quest_stage": {
          "description": "One ordered stage of a quest. Stages advance in array order; objectives inside a stage are all required.",
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "title_key",
            "objectives"
          ],
          "properties": {
            "id": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$",
              "maxLength": 64
            },
            "title_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "description_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "objectives": {
              "type": "array",
              "minItems": 1,
              "items": {
                "$ref": "#/$defs/quest_objective"
              }
            }
          }
        },
        "prerequisites": {
          "description": "开始该任务前必须满足的条件；由 QuestService 在接取/自动开始时检查。",
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "quests_completed": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "flags": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string",
                "pattern": "^[a-z][a-z0-9_.-]*$"
              }
            }
          }
        },
        "tracking": {
          "description": "任务日志 / HUD 追踪的展示与排序设置；不含进度状态。",
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "label_key": {
              "description": "任务日志分组标签键（如「指引」「系统」）。",
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "priority": {
              "description": "HUD/任务列表排序优先级，数值越大越靠前。",
              "type": "integer",
              "minimum": 0,
              "maximum": 1000
            },
            "hidden": {
              "description": "为 true 时不在任务日志列出（仍可被系统追踪）。",
              "type": "boolean"
            }
          }
        },
        "quest_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "stages"
          ],
          "properties": {
            "kind": {
              "description": "story=剧情演出；guide=游戏指引；system=非运输类系统需求。",
              "enum": [
                "story",
                "guide",
                "system"
              ]
            },
            "auto_start": {
              "description": "满足 prerequisites 时自动接取；默认 false。",
              "type": "boolean"
            },
            "repeatable": {
              "description": "完成后可再次接取；默认 false（同一任务不重复发奖）。",
              "type": "boolean"
            },
            "prerequisites": {
              "$ref": "#/$defs/prerequisites"
            },
            "tracking": {
              "$ref": "#/$defs/tracking"
            },
            "stages": {
              "type": "array",
              "minItems": 1,
              "items": {
                "$ref": "#/$defs/quest_stage"
              }
            }
          }
        }
      }
    },
    "v2/region.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/region-2.json",
      "title": "Steam Navigator region content file (Content Schema 2.0)",
      "description": "World region prototype: kind, size, density budgets, weather and faction presence.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "regions"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/region_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "region_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "size",
            "port_density",
            "site_density",
            "weather_profile",
            "region_tags"
          ],
          "properties": {
            "kind": {
              "enum": [
                "coastal",
                "archipelago",
                "open_sea",
                "industrial",
                "frontier"
              ]
            },
            "size": {
              "enum": [
                "small",
                "medium",
                "large"
              ]
            },
            "port_density": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "site_density": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "hostile_density": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "weather_profile": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "factions": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "region_tags": {
              "$ref": "common.schema.json#/$defs/tag_list"
            }
          }
        }
      }
    },
    "v2/relic.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/relic-2.json",
      "title": "Steam Navigator relic content file (Content Schema 2.0)",
      "description": "Ruin relics (D5): rarity, passive modifiers and optional value. IDs use core:relic/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "relics"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/relic_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "relic_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rarity",
            "value"
          ],
          "properties": {
            "rarity": {
              "enum": [
                "common",
                "rare",
                "legendary"
              ]
            },
            "value": {
              "type": "number",
              "minimum": 0,
              "maximum": 100000
            },
            "modifiers": {
              "type": "array",
              "maxItems": 6,
              "items": {
                "$ref": "common.schema.json#/$defs/modifier"
              }
            }
          }
        }
      }
    },
    "v2/room_template.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/room-template-2.json",
      "title": "Steam Navigator ruin room template content file (Content Schema 2.0)",
      "description": "Ruin room templates (D5): tags, size, exits, optional event/hazard/loot references. IDs use core:room_template/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "room_templates"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/room_template_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "room_template_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "size",
            "exits"
          ],
          "properties": {
            "size": {
              "enum": [
                "small",
                "medium",
                "large"
              ]
            },
            "exits": {
              "type": "integer",
              "minimum": 1,
              "maximum": 4
            },
            "event_ref": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "hazard_table": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "loot_table": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "weight": {
              "type": "integer",
              "minimum": 1,
              "maximum": 100
            }
          }
        }
      }
    },
    "v2/route_template.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/route-template-2.json",
      "title": "Steam Navigator route template content file (Content Schema 2.0)",
      "description": "Generated sea route prototype: distance, risk, travel time, region affinity and optional encounters.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "route_templates"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/route_template_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "route_template_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "distance_range",
            "risk_range",
            "travel_time_range"
          ],
          "properties": {
            "kind": {
              "enum": [
                "sea_lane",
                "trade_route",
                "hazardous_shortcut"
              ]
            },
            "distance_range": {
              "$ref": "common.schema.json#/$defs/integer_range2"
            },
            "risk_range": {
              "$ref": "common.schema.json#/$defs/range2"
            },
            "travel_time_range": {
              "$ref": "common.schema.json#/$defs/range2"
            },
            "bidirectional": {
              "type": "boolean"
            },
            "region_kinds": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "enum": [
                  "coastal",
                  "archipelago",
                  "open_sea",
                  "industrial",
                  "frontier"
                ]
              }
            },
            "encounter_table": {
              "$ref": "common.schema.json#/$defs/id_ref"
            }
          }
        }
      }
    },
    "v2/ruin_archetype.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/ruin-archetype-2.json",
      "title": "Steam Navigator ruin archetype content file (Content Schema 2.0)",
      "description": "Procedural ruin archetypes (D5): room count, difficulty, room tag pool, hazard/relic/loot references. IDs use core:ruin_archetype/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "ruin_archetypes"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/ruin_archetype_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "ruin_archetype_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "room_count",
            "difficulty",
            "room_tags",
            "hazard_table",
            "loot_table"
          ],
          "properties": {
            "room_count": {
              "type": "integer",
              "minimum": 2,
              "maximum": 12
            },
            "difficulty": {
              "type": "integer",
              "minimum": 1,
              "maximum": 5
            },
            "room_tags": {
              "type": "array",
              "minItems": 1,
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/tag"
              }
            },
            "hazard_table": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "loot_table": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "relic_pool": {
              "type": "array",
              "minItems": 1,
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "entry_event": {
              "$ref": "common.schema.json#/$defs/id_ref"
            }
          }
        }
      }
    },
    "v2/ship_archetype.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/ship-archetype-2.json",
      "title": "Steam Navigator ship archetype content file (Content Schema 2.0)",
      "description": "Fleet ship archetypes (D2): a hull plus its crew/cargo budget, base speed and upkeep, with default modules and weapon sockets mapped onto the existing hull/module/weapon content. IDs use core:ship_archetype/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "ship_archetypes"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/ship_archetype_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "ship_archetype_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "hull_ref",
            "crew_capacity",
            "cargo_capacity",
            "base_speed",
            "upkeep"
          ],
          "properties": {
            "hull_ref": {
              "description": "Hull definition reference (hulls).",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "crew_capacity": {
              "description": "Maximum crew slots, captains included.",
              "type": "integer",
              "minimum": 1,
              "maximum": 200
            },
            "cargo_capacity": {
              "description": "Cargo capacity in weight units; must fit the hull's cargo slots.",
              "type": "number",
              "minimum": 0,
              "maximum": 5000
            },
            "base_speed": {
              "description": "Fleet-map base speed (matches the hull/simulator speed scale).",
              "type": "number",
              "minimum": 1,
              "maximum": 30
            },
            "upkeep": {
              "description": "Per-voyage upkeep in money.",
              "type": "number",
              "minimum": 0,
              "maximum": 5000
            },
            "default_modules": {
              "description": "Optional default loadout; each entry maps one hull slot to a module.",
              "type": "array",
              "maxItems": 8,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "slot",
                  "module"
                ],
                "properties": {
                  "slot": {
                    "enum": [
                      "boiler",
                      "cargo",
                      "navigation",
                      "safety",
                      "cabin"
                    ]
                  },
                  "module": {
                    "$ref": "common.schema.json#/$defs/id_ref"
                  }
                }
              }
            },
            "weapon_sockets": {
              "description": "Optional mapping of hull weapon sockets to their class and default weapon.",
              "type": "array",
              "maxItems": 8,
              "items": {
                "type": "object",
                "additionalProperties": false,
                "required": [
                  "socket",
                  "class"
                ],
                "properties": {
                  "socket": {
                    "type": "string",
                    "minLength": 1,
                    "maxLength": 64
                  },
                  "class": {
                    "enum": [
                      "Light",
                      "Medium",
                      "Heavy",
                      "Tower",
                      "Side"
                    ]
                  },
                  "weapon": {
                    "$ref": "common.schema.json#/$defs/id_ref"
                  }
                }
              }
            }
          }
        }
      }
    },
    "v2/site.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/site-2.json",
      "title": "Steam Navigator site content file (Content Schema 2.0)",
      "description": "Discoverable world site prototype (ruins, base sites, resources, wrecks, landmarks, encounters).",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "sites"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/site_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "site_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "site_kind",
            "weight"
          ],
          "properties": {
            "site_kind": {
              "enum": [
                "ruin",
                "base_site",
                "resource",
                "wreck",
                "landmark",
                "encounter"
              ]
            },
            "weight": {
              "type": "integer",
              "minimum": 1
            },
            "region_kinds": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "enum": [
                  "coastal",
                  "archipelago",
                  "open_sea",
                  "industrial",
                  "frontier"
                ]
              }
            },
            "ruin_archetype": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "base_site_archetype": {
              "description": "Base archetype used when a player claims this base site.",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "encounter_table": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "loot_table": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "repeatable": {
              "type": "boolean"
            }
          }
        }
      }
    },
    "v2/start_profile.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/start-profile-2.json",
      "title": "Steam Navigator start profile content file (Content Schema 2.0)",
      "description": "Persistent campaign start profile: world profile, starting scenario, difficulty, port tags and optional cargo/contract. C4 replaced the retired 1.0 start-build reference with a `starting_scenario` reference.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "start_profiles"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/start_profile_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "start_profile_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "world_profile",
            "starting_scenario",
            "difficulty",
            "starting_port_tags"
          ],
          "properties": {
            "world_profile": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "map_config": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "starting_scenario": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "difficulty": {
              "enum": [
                "easy",
                "standard",
                "hard"
              ]
            },
            "starting_port_tags": {
              "$ref": "common.schema.json#/$defs/tag_list"
            },
            "starting_money": {
              "type": "number",
              "minimum": 0
            },
            "starting_reputation": {
              "type": "integer",
              "minimum": 0
            },
            "starting_cargo": {
              "type": "array",
              "items": {
                "$ref": "common.schema.json#/$defs/cargo_stack"
              }
            },
            "starting_contract": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "notes_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            }
          }
        }
      }
    },
    "v2/starting_scenario.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/starting-scenario-2.json",
      "title": "Steam Navigator starting scenario content file (Content Schema 2.0)",
      "description": "Campaign start scenario (C4): opening money, hull/module build, supplies and loan. Successor of the retired 1.0 start-build content type; the data block is unchanged, the type, id segment and default file are renamed to starting_scenarios / core:starting_scenario/* / content/starting_scenarios.json. Ship slots stay flat (boiler / cargo_modules / navigation_module / safety_module / passenger_cabin).",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "starting_scenarios"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/starting_scenario_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "starting_scenario_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "money",
            "reputation",
            "hull",
            "boiler",
            "cargo_modules",
            "coal",
            "water"
          ],
          "properties": {
            "money": {
              "type": "number",
              "minimum": 0
            },
            "reputation": {
              "type": "integer",
              "minimum": 0
            },
            "hull": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "boiler": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "cargo_modules": {
              "type": "array",
              "minItems": 1,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "navigation_module": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "safety_module": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "passenger_cabin": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "engineer": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "navigator": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "coal": {
              "type": "number",
              "minimum": 0
            },
            "water": {
              "type": "number",
              "minimum": 0
            },
            "durability_ratio": {
              "type": "number",
              "minimum": 0.1,
              "maximum": 1
            },
            "loan": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "principal",
                "interest_rate",
                "term_hours"
              ],
              "properties": {
                "principal": {
                  "type": "number",
                  "minimum": 1
                },
                "interest_rate": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 0.5
                },
                "term_hours": {
                  "type": "number",
                  "minimum": 1
                }
              }
            }
          }
        }
      }
    },
    "v2/story_arc.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/story-arc-2.json",
      "title": "Steam Navigator story arc content file (Schema 2.0 draft)",
      "description": "Story Mode campaign arcs (Content Schema 2.0 draft). One arc is one playable story campaign inside a story-only content mod: a fixed protagonist, the cast and glossary authored from the World Forge world bible, and the ordered level list. See docs/design/STORY_MODE.md for the full contract. The Godot runtime does not load Schema 2.0 draft content yet.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "story_arcs"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/story_arc_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "local_id": {
          "type": "string",
          "pattern": "^[a-z][a-z0-9_]{0,31}$"
        },
        "story_character": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "name_key"
          ],
          "properties": {
            "id": {
              "$ref": "#/$defs/local_id"
            },
            "name_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "description_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "role": {
              "enum": [
                "protagonist",
                "supporting",
                "antagonist",
                "other"
              ]
            }
          }
        },
        "story_term": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "term_key",
            "definition_key"
          ],
          "properties": {
            "id": {
              "$ref": "#/$defs/local_id"
            },
            "term_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "definition_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            }
          }
        },
        "story_arc_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "protagonist_id",
            "characters",
            "levels"
          ],
          "properties": {
            "protagonist_id": {
              "$ref": "#/$defs/local_id"
            },
            "characters": {
              "type": "array",
              "minItems": 1,
              "items": {
                "$ref": "#/$defs/story_character"
              }
            },
            "terms": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/story_term"
              }
            },
            "levels": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "canon": {
              "type": "boolean"
            },
            "completion_achievement": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_.]{1,63}$"
            },
            "source": {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "world_bible": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 120
                },
                "author": {
                  "type": "string",
                  "minLength": 1,
                  "maxLength": 120
                }
              }
            }
          }
        }
      }
    },
    "v2/story_level.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/story-level-2.json",
      "title": "Steam Navigator story level content file (Schema 2.0 draft)",
      "description": "Story Mode levels (Content Schema 2.0 draft). One level is one hand-authored mission on a fixed map: the embedded fixed_layout ports/edges, the initial run state, the staged mission line (shared story_stage DSL from v2/common.schema.json), narrative briefing/beats/debrief, difficulty knobs, checkpoint-driven retry policy and non-gameplay rewards. See docs/design/STORY_MODE.md for the full contract. The Godot runtime does not load Schema 2.0 draft content yet.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "story_levels"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/story_level_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "port_id": {
          "type": "string",
          "pattern": "^port_[0-9]{1,2}$"
        },
        "fixed_port": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "name_key",
            "position"
          ],
          "properties": {
            "id": {
              "$ref": "#/$defs/port_id"
            },
            "name_key": {
              "type": "string",
              "minLength": 1,
              "maxLength": 160
            },
            "archetype": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "position": {
              "$ref": "common.schema.json#/$defs/range2"
            },
            "facilities": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string",
                "pattern": "^[a-z_]+$"
              }
            },
            "market": {
              "type": "object",
              "additionalProperties": {
                "type": "object",
                "additionalProperties": false,
                "properties": {
                  "stock": {
                    "type": "number",
                    "minimum": 0
                  },
                  "price": {
                    "type": "number",
                    "minimum": 0
                  }
                }
              }
            }
          }
        },
        "fixed_edge": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "from",
            "to",
            "distance",
            "risk"
          ],
          "properties": {
            "from": {
              "$ref": "#/$defs/port_id"
            },
            "to": {
              "$ref": "#/$defs/port_id"
            },
            "distance": {
              "type": "number",
              "minimum": 1
            },
            "risk": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "bidirectional": {
              "type": "boolean"
            }
          }
        },
        "fixed_map": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "ports",
            "edges"
          ],
          "properties": {
            "ports": {
              "type": "array",
              "minItems": 2,
              "items": {
                "$ref": "#/$defs/fixed_port"
              }
            },
            "edges": {
              "type": "array",
              "minItems": 1,
              "items": {
                "$ref": "#/$defs/fixed_edge"
              }
            },
            "start_port": {
              "$ref": "#/$defs/port_id"
            }
          }
        },
        "level_map": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "fixed"
          ],
          "properties": {
            "map_config": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "fog": {
              "enum": [
                "revealed",
                "explored",
                "unknown"
              ]
            },
            "fixed": {
              "$ref": "#/$defs/fixed_map"
            }
          }
        },
        "level_start": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "starting_scenario": {
              "$ref": "common.schema.json#/$defs/id_ref",
              "description": "C4: references a core:starting_scenario/* definition (the retired 1.0 start-build field was renamed)."
            },
            "port_id": {
              "$ref": "#/$defs/port_id"
            },
            "money": {
              "type": "number",
              "minimum": 0
            },
            "ship_fuel": {
              "type": "number",
              "minimum": 0
            },
            "ship_water": {
              "type": "number",
              "minimum": 0
            },
            "cargo": {
              "type": "array",
              "items": {
                "$ref": "common.schema.json#/$defs/cargo_stack"
              }
            },
            "equipped_modules": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "world_time": {
              "type": "string",
              "minLength": 1,
              "maxLength": 64
            }
          }
        },
        "level_systems": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "unlock_features": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string"
              }
            },
            "unlock_items": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "unlock_modules": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "lock_actions": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string"
              }
            }
          }
        },
        "narrative_dialogue": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "title_key",
            "body_keys"
          ],
          "properties": {
            "title_key": {
              "type": "string",
              "minLength": 1
            },
            "body_keys": {
              "type": "array",
              "minItems": 1,
              "items": {
                "type": "string",
                "minLength": 1
              }
            }
          }
        },
        "narrative_brief": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "title_key",
            "body_keys"
          ],
          "properties": {
            "presentation": {
              "$ref": "common.schema.json#/$defs/story_presentation"
            },
            "speaker_key": {
              "type": "string",
              "minLength": 1
            },
            "title_key": {
              "type": "string",
              "minLength": 1
            },
            "body_keys": {
              "type": "array",
              "minItems": 1,
              "items": {
                "type": "string",
                "minLength": 1
              }
            }
          }
        },
        "narrative_beat": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "dialogue"
          ],
          "properties": {
            "id": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "stage_id": {
              "type": "string",
              "minLength": 1
            },
            "presentation": {
              "$ref": "common.schema.json#/$defs/story_presentation"
            },
            "dialogue": {
              "$ref": "#/$defs/narrative_dialogue"
            }
          }
        },
        "narrative_debrief": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "success_keys"
          ],
          "properties": {
            "presentation": {
              "$ref": "common.schema.json#/$defs/story_presentation"
            },
            "success_keys": {
              "type": "array",
              "minItems": 1,
              "items": {
                "type": "string",
                "minLength": 1
              }
            },
            "failure_keys": {
              "type": "array",
              "items": {
                "type": "string",
                "minLength": 1
              }
            },
            "hook_key": {
              "type": "string",
              "minLength": 1
            }
          }
        },
        "level_narrative": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "brief",
            "debrief"
          ],
          "properties": {
            "brief": {
              "$ref": "#/$defs/narrative_brief"
            },
            "beats": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/narrative_beat"
              }
            },
            "debrief": {
              "$ref": "#/$defs/narrative_debrief"
            }
          }
        },
        "level_difficulty": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "profile": {
              "enum": [
                "story.intro",
                "story.standard",
                "story.hard"
              ]
            },
            "knobs": {
              "type": "object",
              "additionalProperties": false,
              "properties": {
                "starting_money_scale": {
                  "type": "number",
                  "minimum": 0
                },
                "deadline_scale": {
                  "type": "number",
                  "minimum": 0
                },
                "risk_scale": {
                  "type": "number",
                  "minimum": 0
                },
                "coal_water_scale": {
                  "type": "number",
                  "minimum": 0
                },
                "hint_level": {
                  "enum": [
                    "full",
                    "light",
                    "none"
                  ]
                }
              }
            }
          }
        },
        "level_rewards": {
          "type": "object",
          "additionalProperties": false,
          "properties": {
            "achievements": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string",
                "pattern": "^[a-z][a-z0-9_.]{1,63}$"
              }
            },
            "codex_entries": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string",
                "pattern": "^[a-z][a-z0-9_.]{1,63}$"
              }
            },
            "cosmetics": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "type": "string",
                "pattern": "^[a-z][a-z0-9_.]{1,63}$"
              }
            }
          }
        },
        "level_fail": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "default_mode",
            "allow"
          ],
          "properties": {
            "default_mode": {
              "enum": [
                "checkpoint",
                "level_start"
              ]
            },
            "allow": {
              "type": "array",
              "minItems": 1,
              "uniqueItems": true,
              "items": {
                "enum": [
                  "checkpoint",
                  "level_start"
                ]
              }
            }
          }
        },
        "story_level_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "map",
            "stages",
            "narrative"
          ],
          "properties": {
            "map": {
              "$ref": "#/$defs/level_map"
            },
            "start": {
              "$ref": "#/$defs/level_start"
            },
            "systems": {
              "$ref": "#/$defs/level_systems"
            },
            "narrative": {
              "$ref": "#/$defs/level_narrative"
            },
            "stages": {
              "type": "array",
              "minItems": 1,
              "items": {
                "$ref": "common.schema.json#/$defs/story_stage"
              }
            },
            "difficulty": {
              "$ref": "#/$defs/level_difficulty"
            },
            "rewards": {
              "$ref": "#/$defs/level_rewards"
            },
            "fail": {
              "$ref": "#/$defs/level_fail"
            }
          }
        }
      }
    },
    "v2/trade_policy.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/trade-policy-2.json",
      "title": "Steam Navigator auto-trade policy content file (Content Schema 2.0)",
      "description": "Automated trade policies (D4): allowed goods, port tag filters, budget/reserve, cargo capacity, travel time, risk and rule links. IDs use core:trade_policy/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "trade_policies"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/trade_policy_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "trade_policy_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "goods",
            "budget",
            "reserve_money",
            "max_cargo",
            "travel_hours",
            "risk",
            "min_margin"
          ],
          "properties": {
            "goods": {
              "description": "Ordinary items the route may trade.",
              "type": "array",
              "minItems": 1,
              "maxItems": 4,
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            },
            "buy_port_tags": {
              "description": "Optional port tags required at the buying end.",
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/tag"
              }
            },
            "sell_port_tags": {
              "description": "Optional port tags required at the selling end.",
              "type": "array",
              "uniqueItems": true,
              "items": {
                "$ref": "common.schema.json#/$defs/tag"
              }
            },
            "budget": {
              "description": "Maximum money spent on one buy.",
              "type": "number",
              "minimum": 1,
              "maximum": 1000000
            },
            "reserve_money": {
              "description": "Money the automation never spends.",
              "type": "number",
              "minimum": 0,
              "maximum": 1000000
            },
            "max_cargo": {
              "description": "Cargo units the automated trader can carry.",
              "type": "integer",
              "minimum": 1,
              "maximum": 500
            },
            "travel_hours": {
              "description": "Simulation hours per leg.",
              "type": "number",
              "minimum": 1,
              "maximum": 240
            },
            "risk": {
              "description": "Per-leg loss probability (0-1).",
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "min_margin": {
              "description": "Minimum expected profit ratio required before buying.",
              "type": "number",
              "minimum": 0,
              "maximum": 5
            },
            "rules": {
              "description": "Automation rules attached to this policy.",
              "type": "array",
              "maxItems": 8,
              "items": {
                "$ref": "common.schema.json#/$defs/id_ref"
              }
            }
          }
        }
      }
    },
    "v2/voyage_event.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/voyage-event-2.json",
      "title": "Steam Navigator voyage event content file (Content Schema 2.0)",
      "description": "Voyage events that fire during travel (C4): trigger, category, weight, optional condition and player options with effects. Successor of the 1.0 `events` content type; the data block is unchanged, the type, id segment and default file are renamed to voyage_events / core:voyage_event/* / content/voyage_events.json.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "voyage_events"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/voyage_event_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "option_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "name_key",
            "effects"
          ],
          "properties": {
            "id": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_]*$"
            },
            "name_key": {
              "type": "string",
              "minLength": 1
            },
            "weight": {
              "type": "number",
              "minimum": 0
            },
            "condition": {
              "$ref": "common.schema.json#/$defs/condition_node"
            },
            "effects": {
              "type": "array",
              "minItems": 1,
              "maxItems": 16,
              "items": {
                "$ref": "common.schema.json#/$defs/effect"
              }
            }
          }
        },
        "voyage_event_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "trigger",
            "category",
            "options"
          ],
          "properties": {
            "trigger": {
              "enum": [
                "voyage_risk",
                "voyage_opportunity"
              ]
            },
            "category": {
              "enum": [
                "mechanical",
                "merchant"
              ]
            },
            "weight": {
              "type": "number",
              "minimum": 0,
              "exclusiveMinimum": 0
            },
            "base_delay_hours": {
              "type": "number",
              "minimum": 0
            },
            "condition": {
              "$ref": "common.schema.json#/$defs/condition_node"
            },
            "options": {
              "type": "array",
              "minItems": 2,
              "maxItems": 8,
              "items": {
                "$ref": "#/$defs/option_data"
              }
            }
          }
        }
      }
    },
    "v2/weapon.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/weapon-2.json",
      "title": "Steam Navigator weapon content file (Content Schema 2.0)",
      "description": "Ship-mounted weapon definitions (Content Schema 2.0 runtime type since D1). The combat block mirrors the S-N Battle Simulator weapon catalogue, the assembly block mirrors docs/design/WEAPON_SOCKET_CONTRACT.md (weapon-assembly@2), and the economy block follows the runtime module shape.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "weapons"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/weapon_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "craft_material": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "id",
            "amount"
          ],
          "properties": {
            "id": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "amount": {
              "type": "number",
              "minimum": 0.1
            }
          }
        },
        "weapon_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "kind",
            "damage",
            "range",
            "min_range",
            "cooldown",
            "accuracy",
            "projectile_speed",
            "splash",
            "arc_deg",
            "salvo",
            "weapon_class",
            "assembly_profile",
            "tier",
            "weight",
            "purchase_price"
          ],
          "properties": {
            "kind": {
              "description": "开火行为：direct 直射 / artillery 曲射 / broadside 舷侧齐射（与战斗模拟器 weapon.kind 一致）。",
              "enum": [
                "direct",
                "artillery",
                "broadside"
              ]
            },
            "damage": {
              "type": "number",
              "minimum": 1,
              "maximum": 120
            },
            "range": {
              "description": "最大射程（模拟器单位，米）。",
              "type": "number",
              "minimum": 60,
              "maximum": 700
            },
            "min_range": {
              "description": "最小射程；必须小于 range。",
              "type": "number",
              "minimum": 0,
              "maximum": 400
            },
            "cooldown": {
              "description": "两轮齐射间隔（秒）。",
              "type": "number",
              "minimum": 0.25,
              "maximum": 20
            },
            "damage_type": {
              "description": "Optional damage_types reference (D1); the runtime falls back to a plain kinetic hit when omitted.",
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "accuracy": {
              "type": "number",
              "minimum": 0.05,
              "maximum": 0.98
            },
            "projectile_speed": {
              "type": "number",
              "minimum": 60,
              "maximum": 900
            },
            "splash": {
              "description": "溅射半径（米），0 表示单体命中。",
              "type": "number",
              "minimum": 0,
              "maximum": 100
            },
            "arc_deg": {
              "description": "射界/炮口可覆盖角度（度）。",
              "type": "number",
              "minimum": 30,
              "maximum": 360
            },
            "salvo": {
              "description": "单次开火的弹药数（多联装）。",
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            "color": {
              "description": "弹道/炮口特效基色（#RRGGBB）。",
              "type": "string",
              "pattern": "^#[0-9a-fA-F]{6}$"
            },
            "weapon_class": {
              "description": "与船体 SN_Socket_Weapon_* 的 socket_class 做硬门禁；Modular 是 kit 部件，不是完整武器。",
              "enum": [
                "Light",
                "Medium",
                "Heavy",
                "Tower",
                "Side",
                "Modular"
              ]
            },
            "mount_class": {
              "description": "可选：安装帧类别，缺省与 weapon_class 相同。",
              "enum": [
                "Light",
                "Medium",
                "Heavy",
                "Tower",
                "Side"
              ]
            },
            "assembly_profile": {
              "description": "机构层组合：yaw_pitch / yaw_pitch_multi / pitch_only / fixed / base_only / yaw_only（WEAPON_SOCKET_CONTRACT §4）。",
              "enum": [
                "yaw_pitch",
                "yaw_pitch_multi",
                "pitch_only",
                "fixed",
                "base_only",
                "yaw_only"
              ]
            },
            "has_yaw": {
              "type": "boolean"
            },
            "has_pitch": {
              "type": "boolean"
            },
            "has_recoil": {
              "type": "boolean"
            },
            "has_muzzle": {
              "type": "boolean"
            },
            "muzzle_count": {
              "type": "integer",
              "minimum": 1,
              "maximum": 8
            },
            "envelope_x": {
              "description": "GLB Root extras envelope_x（米），含炮管的整机长度。",
              "type": "number",
              "minimum": 0,
              "maximum": 20
            },
            "envelope_y": {
              "type": "number",
              "minimum": 0,
              "maximum": 20
            },
            "height": {
              "description": "GLB Root extras height（米），甲板面以上总高。",
              "type": "number",
              "minimum": 0,
              "maximum": 20
            },
            "mount_scale": {
              "description": "装配时的统一缩放（socket extras mount_scale 的同名口径）。",
              "type": "number",
              "minimum": 0.1,
              "maximum": 10
            },
            "tier": {
              "type": "integer",
              "minimum": 1,
              "maximum": 3
            },
            "weight": {
              "description": "重量（对应模拟器 weapon.mass），影响船体载重。",
              "type": "number",
              "minimum": 0,
              "maximum": 200
            },
            "purchase_price": {
              "type": "number",
              "minimum": 0
            },
            "craft_cost": {
              "type": "number",
              "minimum": 0
            },
            "craft_time_hours": {
              "type": "number",
              "minimum": 0
            },
            "materials": {
              "type": "array",
              "items": {
                "$ref": "#/$defs/craft_material"
              }
            }
          }
        }
      }
    },
    "v2/weather_profile.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/weather-profile-2.json",
      "title": "Steam Navigator weather profile content file (Content Schema 2.0)",
      "description": "Climate band prototype: fog/storm/ice chances and voyage modifiers applied while a ship travels through a region.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "weather_profiles"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/weather_profile_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "weather_profile_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "climate",
            "fog_chance",
            "storm_chance",
            "risk_modifier"
          ],
          "properties": {
            "climate": {
              "enum": [
                "temperate",
                "cold",
                "tropical",
                "volcanic",
                "storm_belt"
              ]
            },
            "fog_chance": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "storm_chance": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "ice_chance": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "base_visibility": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "risk_modifier": {
              "type": "number",
              "minimum": -0.5,
              "maximum": 0.5
            },
            "speed_modifier": {
              "type": "number",
              "minimum": -0.5,
              "maximum": 0.5
            },
            "coal_drain_modifier": {
              "type": "number",
              "minimum": 0,
              "maximum": 2
            },
            "seasons": {
              "type": "array",
              "uniqueItems": true,
              "items": {
                "enum": [
                  "spring",
                  "summer",
                  "autumn",
                  "winter"
                ]
              }
            }
          }
        }
      }
    },
    "v2/worker_role.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/worker-role-2.json",
      "title": "Steam Navigator worker role content file (Content Schema 2.0)",
      "description": "Base worker roles (D3): hire cost, per-tick wage and the production speed bonus one worker contributes. IDs use core:worker_role/*.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "worker_roles"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/worker_role_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "worker_role_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "wage_per_tick",
            "hire_cost_money",
            "speed_bonus"
          ],
          "properties": {
            "wage_per_tick": {
              "description": "Money paid per simulation tick for each hired worker of this role.",
              "type": "number",
              "minimum": 0,
              "maximum": 200
            },
            "hire_cost_money": {
              "description": "One-off money cost to hire one worker.",
              "type": "number",
              "minimum": 0,
              "maximum": 5000
            },
            "speed_bonus": {
              "description": "Production speed multiplier added per worker (0.1 = +10%).",
              "type": "number",
              "minimum": 0,
              "maximum": 2
            },
            "skill": {
              "enum": [
                "labor",
                "smithing",
                "engineering"
              ]
            }
          }
        }
      }
    },
    "v2/world_profile.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/world-profile-2.json",
      "title": "Steam Navigator world profile content file (Content Schema 2.0)",
      "description": "Persistent world generation profile for regions, sites, ports, ruins, bases and factions.",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "const": "2.0"
        },
        "content_type": {
          "const": "world_profiles"
        },
        "definitions": {
          "type": "array",
          "minItems": 1,
          "items": {
            "allOf": [
              {
                "$ref": "common.schema.json#/$defs/definition"
              },
              {
                "type": "object",
                "properties": {
                  "data": {
                    "$ref": "#/$defs/world_profile_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "world_profile_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "region_count",
            "sites_per_region",
            "port_count",
            "start_region_tags"
          ],
          "properties": {
            "region_count": {
              "type": "integer",
              "minimum": 1,
              "maximum": 64
            },
            "sites_per_region": {
              "type": "integer",
              "minimum": 0,
              "maximum": 32
            },
            "port_count": {
              "type": "integer",
              "minimum": 1,
              "maximum": 64
            },
            "ruin_density": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "base_site_count": {
              "type": "integer",
              "minimum": 0,
              "maximum": 16
            },
            "faction_count": {
              "type": "integer",
              "minimum": 0,
              "maximum": 16
            },
            "weather_profile": {
              "$ref": "common.schema.json#/$defs/id_ref"
            },
            "edge_density": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "start_region_tags": {
              "$ref": "common.schema.json#/$defs/tag_list"
            }
          }
        }
      }
    }
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
