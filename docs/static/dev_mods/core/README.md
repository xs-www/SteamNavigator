# `dev_mods/core`

> 官方 MVP 内容包：港口、商品、船只、模块、策略、岗位、委托、事件、地图与本地化；模块含打造配方/工时/费用，tier1 为仅金币配方（materials 为空）。

## 文件索引

| 文件 | 职责 | 文档 |
| --- | --- | --- |
| `assets/icons/coal.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/icons/money.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/icons/water.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/goods/SN_Coal_Pile.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/goods/SN_Ore_Pile.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/goods/SN_Timber_Stack.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/materials/SN_Barrel.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/materials/SN_Gear_Crate.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/materials/SN_Plate_Stack.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Boiler_Efficient.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Boiler_Performance.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Boiler_Standard.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Boiler_Unit.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Cabin_Passenger.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Cargo_Large_Hold.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Cargo_Medium_Hold.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Cargo_Small_Hold.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Nav_Chart_Room.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Nav_Spyglass.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Safety_Lifeboat.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/modules/SN_Safety_Valve.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/port/SN_Dry_Dock.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/port/SN_Market_Stall.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/port/SN_Notice_Board.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/port/SN_Shipyard_Gantry.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/port/SN_Signal_Tower.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/port/SN_Water_Tank.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Barrel.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Bell.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Boiler_Unit.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Buoy.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Capstan.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Cargo_Net.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Chain_Coil.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Coal_Chute.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Coal_Pile.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Crate.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Dock_Fender.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Dock_Ladder.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Dock_Stairs.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Dock_Wall.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Fender_Ball.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Flag_Pole.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Gangway.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Gas_Lamp.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Gear_Crate.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Grab_Bucket.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Boiler_House.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Boiler_House_LOD1.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Brick_Tenement.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Brick_Tenement_LOD1.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Cargo_Lighter.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Cargo_Shed.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Cargo_Shed_LOD1.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Dock_Worker_A.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Dock_Worker_B.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Fence_Row.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Harbor_Office.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Harbor_Office_LOD1.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Rowboat.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Tavern.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Tavern_LOD1.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Warehouse_Long.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Warehouse_Long_LOD1.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Warehouse_Short.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Warehouse_Short_LOD1.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Workshop_Row.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_HT_Workshop_Row_LOD1.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Handcart.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Harbor_Crane.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Keel_Block.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Mooring_Bollard.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Mooring_Rope.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Ore_Pile.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Pallet.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Plate_Stack.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Port_Sign.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Sack_Pile.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Steam_Pipe.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/SN_Timber_Stack.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/brick_wall.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/brick_wall_soot.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/glass_dark.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/glass_reflect.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/iron_dark.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/iron_rust.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/plaster_grime.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/plaster_light.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/stone_base.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/stone_base_dirty.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/wood_plank.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/props/iron_harbor_shared/wood_plank_weathered.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/ships/SN_Ironclad.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/ships/SN_Paddle_Freighter.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/ships/SN_Paddle_Steamer.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/ships/SN_Schooner_Fame.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/models/ships/SN_Ship_Prototype.glb` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `assets/ports/iron_harbor_banner.png` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/boilers.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/cabins.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/cargo_modules.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/contracts.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/events.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/goods.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/hulls.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/map_profiles.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/materials.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/navigation_modules.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/port_archetypes.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/roles.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/safety_modules.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/starting_builds.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `content/strategies.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `localization/en.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `localization/zh_CN.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |
| `manifest.json` | 官方 Core 内容文件（manifest/content/localization/assets）。 | 本页 |

## 模块契约

- `manifest.json` 声明 required=true，内容文件 15 个，本地化 zh_CN/en。
- tier≥2 模块带 `craft_cost`；所有模块可带 `materials`/`craft_time_hours` 供 CraftOps 读取。
- 两个造船厂港口（iron_harbor/free_town）市场限量出售精密齿轮，保证大型船材料在当局地图可获得。
- 框架不得引用这里的具体 ID；所有引用由 Schema/交叉校验保证。
- 修改数值只改 JSON，不改框架。
