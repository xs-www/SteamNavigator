/*
 * AUTO-GENERATED FILE - do not edit by hand.
 * Source: /schemas/*.schema.json
 * Regenerate: node SNModMaker/tools/sync-schemas.mjs
 */
(function (root) {
  'use strict';
  root.SN_SCHEMAS = {
    "boiler.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/boiler-1.json",
      "title": "Steam Navigator boiler content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "boilers"
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
                    "$ref": "#/$defs/boiler_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "boiler_data": {
          "allOf": [
            {
              "$ref": "common.schema.json#/$defs/module_common"
            },
            {
              "type": "object",
              "required": [
                "speed_mul",
                "coal_rate",
                "water_rate"
              ],
              "properties": {
                "speed_mul": {
                  "type": "number",
                  "minimum": 0.2,
                  "maximum": 3
                },
                "coal_rate": {
                  "type": "number",
                  "minimum": 0
                },
                "water_rate": {
                  "type": "number",
                  "minimum": 0
                }
              }
            }
          ]
        }
      }
    },
    "cabin.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/cabin-1.json",
      "title": "Steam Navigator passenger cabin content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "cabins"
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
                    "$ref": "#/$defs/cabin_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "cabin_data": {
          "allOf": [
            {
              "$ref": "common.schema.json#/$defs/module_common"
            },
            {
              "type": "object",
              "required": [
                "passenger_capacity"
              ],
              "properties": {
                "passenger_capacity": {
                  "type": "integer",
                  "minimum": 1,
                  "maximum": 12
                }
              }
            }
          ]
        }
      }
    },
    "cargo_module.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/cargo-module-1.json",
      "title": "Steam Navigator cargo module content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "cargo_modules"
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
                    "$ref": "#/$defs/cargo_module_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "cargo_module_data": {
          "allOf": [
            {
              "$ref": "common.schema.json#/$defs/module_common"
            },
            {
              "type": "object",
              "required": [
                "capacity"
              ],
              "properties": {
                "capacity": {
                  "type": "number",
                  "minimum": 1
                }
              }
            }
          ]
        }
      }
    },
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
    "contract.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/contract-1.json",
      "title": "Steam Navigator contract content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
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
    "event.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/event-1.json",
      "title": "Steam Navigator voyage event content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "events"
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
                    "$ref": "#/$defs/event_data"
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
        "event_data": {
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
    "good.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/good-1.json",
      "title": "Steam Navigator goods content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "goods"
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
                    "$ref": "#/$defs/good_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "good_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "unit_weight",
            "base_price",
            "base_stock",
            "price_elasticity"
          ],
          "properties": {
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
              "type": "number",
              "minimum": 0
            },
            "crafting_material": {
              "type": "boolean"
            },
            "category": {
              "type": "string",
              "minLength": 1
            }
          }
        }
      }
    },
    "hull.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/hull-1.json",
      "title": "Steam Navigator hull content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
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
        "hull_data": {
          "allOf": [
            {
              "$ref": "common.schema.json#/$defs/module_common"
            },
            {
              "type": "object",
              "required": [
                "base_speed",
                "max_weight",
                "max_durability",
                "cargo_slots",
                "cabin_slots",
                "base_risk"
              ],
              "properties": {
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
                }
              }
            }
          ]
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
    "map_profile.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/map-profile-1.json",
      "title": "Steam Navigator map generation profile content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "map_profiles"
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
                    "$ref": "#/$defs/map_profile_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "map_profile_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "port_count_range",
            "edge_count_range",
            "distance_range",
            "route_risk_range",
            "archetypes",
            "port_name_keys",
            "required_facility_tags"
          ],
          "properties": {
            "port_count_range": {
              "$ref": "common.schema.json#/$defs/range2"
            },
            "edge_count_range": {
              "$ref": "common.schema.json#/$defs/range2"
            },
            "distance_range": {
              "$ref": "common.schema.json#/$defs/range2"
            },
            "route_risk_range": {
              "$ref": "common.schema.json#/$defs/range2"
            },
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
            "default_starting_build": {
              "$ref": "common.schema.json#/$defs/id_ref"
            }
          }
        }
      }
    },
    "material.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/material-1.json",
      "title": "Steam Navigator shipbuilding materials content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "materials"
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
                    "$ref": "#/$defs/material_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "material_data": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "tier",
            "unit_weight",
            "base_price",
            "base_stock"
          ],
          "properties": {
            "tier": {
              "type": "integer",
              "minimum": 1,
              "maximum": 3
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
            "category": {
              "type": "string",
              "minLength": 1
            }
          }
        }
      }
    },
    "navigation_module.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/navigation-module-1.json",
      "title": "Steam Navigator navigation module content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "navigation_modules"
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
                    "$ref": "#/$defs/navigation_module_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "navigation_module_data": {
          "allOf": [
            {
              "$ref": "common.schema.json#/$defs/module_common"
            },
            {
              "type": "object",
              "required": [
                "risk_add",
                "speed_mul",
                "reveal_facilities"
              ],
              "properties": {
                "risk_add": {
                  "type": "number",
                  "minimum": -0.5,
                  "maximum": 0.5
                },
                "speed_mul": {
                  "type": "number",
                  "minimum": 0.2,
                  "maximum": 3
                },
                "reveal_facilities": {
                  "type": "boolean"
                }
              }
            }
          ]
        }
      }
    },
    "patch.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/patch-1.json",
      "title": "Steam Navigator explicit patch content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
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
    "port_archetype.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/port-archetype-1.json",
      "title": "Steam Navigator port archetype content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "port_archetypes"
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
                    "$ref": "#/$defs/port_archetype_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "port_archetype_data": {
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
                  "intel"
                ]
              }
            },
            "banner_asset": {
              "type": "string",
              "pattern": "^[a-z][a-z0-9_.-]*$"
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
    "role.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/role-1.json",
      "title": "Steam Navigator crew role content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "roles"
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
                    "$ref": "#/$defs/role_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "role_data": {
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
    "safety_module.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/safety-module-1.json",
      "title": "Steam Navigator safety module content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "safety_modules"
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
                    "$ref": "#/$defs/safety_module_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "safety_module_data": {
          "allOf": [
            {
              "$ref": "common.schema.json#/$defs/module_common"
            },
            {
              "type": "object",
              "required": [
                "risk_add",
                "damage_mul",
                "repair_cost_mul"
              ],
              "properties": {
                "risk_add": {
                  "type": "number",
                  "minimum": -0.5,
                  "maximum": 0.5
                },
                "damage_mul": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 1.5
                },
                "repair_cost_mul": {
                  "type": "number",
                  "minimum": 0,
                  "maximum": 2
                }
              }
            }
          ]
        }
      }
    },
    "starting_build.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/starting-build-1.json",
      "title": "Steam Navigator starting build content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "starting_builds"
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
                    "$ref": "#/$defs/starting_build_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "starting_build_data": {
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
    "strategy.schema.json": {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "https://steam-navigator.local/schema/strategy-1.json",
      "title": "Steam Navigator boiler strategy content file",
      "type": "object",
      "additionalProperties": false,
      "required": [
        "schema_version",
        "content_type",
        "definitions"
      ],
      "properties": {
        "schema_version": {
          "enum": [
            "1.0"
          ]
        },
        "content_type": {
          "const": "strategies"
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
                    "$ref": "#/$defs/strategy_data"
                  }
                }
              }
            ]
          }
        }
      },
      "$defs": {
        "strategy_data": {
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
    }
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
