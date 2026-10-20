class_name PortStage
extends LocationStage
## Fixed-camera 2.5D port stage: quay, facilities, shore skyline, water and the
## player's moored ship in one 3/4 long-lens frame.
##
## Lifecycle: `_ready()` builds the static stage once (environment, lights,
## water, quay, camera, fallback painted backdrop). `bind()` only rebuilds the
## data-driven layers under `_content`:
##   L1  backdrop      banner texture; otherwise a painted dusk backdrop with
##                     three batched silhouette depth layers (ridge/city/roofline)
##   L2  shoreline     deterministic BoxMesh silhouettes seeded by `port.id`
##   L2b harbour town  density-scaled street kit (`port.size` -> sparse/normal/
##                     busy, or `port.density` / `port.diorama.density`)
##   L3  facilities    anchors from `port.facilities`; missing ones get fillers
##   L5  player ship   `ship.hull_model_path`, tier fallback, bobbing in `_process`
## After the dynamic layers are built they are folded into static draw batches
## (MultiMesh for shared-mesh boxes, material-signature merges for GLB props);
## see `batch_stats()`. Repeated binds with the same ViewModel are no-ops, so
## the host can forward every application update without leaking nodes.
##
## `bind()` ViewModel (every field optional):
##   port.id               String  deterministic shoreline/street variation
##   port.size             String  "small" | "medium" | "large" -> 0.9/1.0/1.15
##   port.facilities       Array[String], subset of FACILITY_ORDER
##   port.banner_path      String  resolved L1 backdrop texture path
##   port.density          String  "sparse" | "normal" | "busy" street density
##   port.diorama          Dictionary  optional; `density` is read from here too
##   port.town_visuals     Dictionary  town slot -> resolved GLB path
##   port.palette          Dictionary  stone/deck/wood/wood_dark/metal/iron/canvas/
##                                   brass plus per-facility sign colours
##   port.facility_visuals Dictionary  facility -> resolved GLB path (String or
##                                   Array[String]); may live at the root instead
##   port.landmark_path    String  optional single custom landmark model
##   ship.hull_model_path  String  resolved player hull GLB
##   ship.hull_tier        int     dev fallback when hull_model_path is empty
##
## Presentation only: no GameState, QueryBus or CommandBus; every path arrives
## pre-resolved in the ViewModel.

const FACILITY_ORDER := ["exchange", "contracts", "supply", "intel", "shipyard"]

## `port.size` -> uniform scale applied to the facility group parent.
const SIZE_SCALE := {"small": 0.9, "medium": 1.0, "large": 1.15}

const DOCK_TOP := 2.2
## Thin deck slab on piles: the quay reads as a trestle pier instead of a solid
## box floating on the water. The quay is one continuous 160 m waterfront so the
## market / harbour / supply stations are adjacent along the same deck instead of
## being separate scenes.
const DOCK_SIZE := Vector3(160.0, 0.6, 12.0)
const DOCK_CENTER := Vector3(0.0, 1.9, -6.0)
const DECK_SIZE := Vector3(160.0, 0.1, 12.0)
## Shore shelf behind the quay: the L2 silhouette row stands on it, so the
## skyline never floats directly on the water plane.
## Shore shelf behind the quay, wider/deeper than the frame so no cut edge or
## painted banner water is ever exposed beside it; the silhouette row stands on
## it and the quay reads as one shore instead of a floating box.
const SHORE_SIZE := Vector3(500.0, 1.3, 110.0)
const SHORE_CENTER := Vector3(0.0, -0.55, -65.0)
const SHORE_TOP := 0.1

const CAMERA_POS := Vector3(46.0, 28.0, 64.0)
const CAMERA_TARGET := Vector3(0.0, 12.0, -8.0)
const CAMERA_FOV := 30.0

## The hull is drawn at true scale: the camera backs off far enough that even a
## 60 m ironclad stays in the lower-left foreground without covering facility
## signs, while a 24 m paddle steamer reads as a complete moored ship.
const SHIP_SPAWN := Vector3(-13.5, 0.0, 9.0)
const SHIP_YAW_DEG := 20.0
const SHIP_SCALE := 1.0
const BOB_AMPLITUDE := 0.12
const BOB_SPEED := 0.9

# --- Adjacent stations (one continuous harbour district) --------------------
#
# Bounty Train style: the harbour is a single contiguous 3D district. The market,
# the harbour authority frontage and the supply yard are three stations standing
# side by side along the same quay, and switching pages only pans the camera and
# sails the player's hull to that station's mooring — the world is never rebuilt
# or reloaded, so the new page arrives before the camera has finished moving.
#
# Every station keeps the same lens (`CAMERA_FOV`) and the same relative framing,
# so the district reads as one place; only the camera position and the ship
# mooring change. `center` is the station anchor in world X (also the facility
# anchor that station owns), `camera`/`target` are its department shot and
# `ship` is the berth the player's vessel takes.
const STATION_ORDER := ["market", "harbor", "supply"]
const DEFAULT_STATION := "harbor"
const STATION_FRAMINGS := ["stage", "panel"]
const STATIONS := {
	"market": {
		"center": -30.0,
		"camera": Vector3(16.0, 28.0, 64.0),
		"target": Vector3(-30.0, 12.0, -8.0),
		"ship": Vector3(-43.5, 0.0, 9.0),
		"ship_yaw": SHIP_YAW_DEG,
	},
	"harbor": {
		"center": 0.0,
		"camera": CAMERA_POS,
		"target": CAMERA_TARGET,
		"ship": SHIP_SPAWN,
		"ship_yaw": SHIP_YAW_DEG,
	},
	"supply": {
		"center": 30.0,
		"camera": Vector3(76.0, 28.0, 64.0),
		"target": Vector3(30.0, 12.0, -8.0),
		"ship": Vector3(16.5, 0.0, 9.0),
		"ship_yaw": SHIP_YAW_DEG,
	},
}
## Panel framing: the market/supply pages keep a 620 px information panel on the
## right side of the window, so their shot is shifted a few metres to place the
## station landmark inside the visible left part of the frame instead of behind
## the panel. It is still the same pan — no rebuild, no second stage.
const PANEL_FRAMING_SHIFT_X := 3.0
## Station switch timing: the camera pans in 0.6 s while the hull sails along the
## quay (~24 m/s) and turns back to its mooring yaw on arrival.
const CAMERA_PAN_SECONDS := 0.6
const SHIP_TRANSIT_SPEED := 24.0
const SHIP_TURN_SPEED := 2.6

const MODEL_BY_TIER := {
	1: "res://assets/models/ships/SN_Paddle_Steamer.glb",
	2: "res://assets/models/ships/SN_Paddle_Freighter.glb",
	3: "res://assets/models/ships/SN_Ironclad.glb",
}
const FALLBACK_MODEL := "res://assets/models/ships/SN_Ship_Prototype.glb"

## Local positions inside the scaled facility group; y is the quay top because
## the group itself sits on `DOCK_TOP`. Exchange and supply sit at their own
## stations (`STATIONS.market` / `STATIONS.supply`), so walking the quay changes
## the scene instead of swapping a page background.
const SLOT_POSITIONS := {
	"exchange": Vector3(-30.0, 0.0, -3.0),
	"contracts": Vector3(-8.0, 0.0, -4.0),
	"supply": Vector3(30.0, 0.0, -3.0),
	"intel": Vector3(7.0, 0.0, -4.0),
	"shipyard": Vector3(14.5, 0.0, -4.5),
}
## Shipyard may carry two pieces (dry dock + gantry); the second rides behind
## and on top of the dry dock so the pivot stays on the quay top.
const SHIPYARD_PIECE_OFFSETS := [Vector3.ZERO, Vector3(0.0, 2.6, -2.0)]

const SIGN_YAW_DEG := 30.0
const SIGN_COLORS := {
	"exchange": Color(0.95, 0.63, 0.25),
	"contracts": Color(0.84, 0.72, 0.42),
	"supply": Color(0.34, 0.72, 0.66),
	"intel": Color(0.38, 0.62, 0.90),
	"shipyard": Color(0.88, 0.38, 0.24),
}

const SKY_TOP := Color(0.06, 0.11, 0.16)
const SKY_HORIZON := Color(0.68, 0.43, 0.26)
## Below-horizon sky hemisphere mirrors the warm fog band: if a few pixels of it
## ever show past the water/backdrop edge they read as haze, not a black band.
const SKY_GROUND_HORIZON := Color(0.77, 0.54, 0.35)
const SKY_GROUND_BOTTOM := Color(0.42, 0.28, 0.19)
const FOG_COLOR := Color(0.60, 0.40, 0.27)
const AMBIENT_COLOR := Color(0.56, 0.66, 0.72)
## L1 backdrop: oversized and pushed far back so its quad always covers the
## whole 1440x900 frame (the 120 m version used to leave sky visible on the
## left). `BACKDROP_POSITION.y` keeps the painted waterline below the quay.
const BACKDROP_SIZE := Vector2(260.0, 76.0)
const BACKDROP_POSITION := Vector3(-70.0, 12.0, -70.0)
const NEAR_WATER_SIZE := 600.0
const FAR_WATER_SIZE := 2400.0
## Fallback "sky wall": a camera-facing dusk gradient card far behind the town.
## A fixed depth + screen-fraction size replaces the old oblique quad, whose
## near right edge used to slice the painted backdrops on the right-hand side.
## The painted depth layers (see `_add_painted_backdrop_layers`) sit in front.
const SKY_CARD_DEPTH := 260.0
const SKY_CARD_SCREEN_CENTER := Vector2(-0.015, 0.185)
const SKY_CARD_SCREEN_SIZE := Vector2(2.04, 0.96)

## L2 skyline instances per `port.size`: building count plus crane count. The
## plan's L2 budget is 8-20 instances, so small/medium/large stay inside it.
const SKYLINE_BUILDINGS_BY_SIZE := {"small": 7, "medium": 10, "large": 13}
const SKYLINE_CRANES_BY_SIZE := {"small": 2, "medium": 2, "large": 3}

## Official harbour-town kit layout (framework-owned). Each slot is filled from
## `port.town_visuals` (slot -> pre-resolved GLB path); a missing visual falls
## back to a procedural blockout so the town silhouette still reads as a dense
## working harbour before/without the content kit.
##
## Density: `port.density` or `port.diorama.density` picks the tier explicitly
## (sparse / normal / busy); otherwise `port.size` derives it (small -> sparse,
## medium -> normal, large -> busy). Every group below is a curated ordered list
## and a tier mounts a prefix of it, so a denser street grows outward from the
## authored core instead of reshuffling. `port.id.hash()` only adds small
## deterministic yaw jitter to free-standing props (never a global RNG).
##
## Normal tier = the official harbour look: 5 buildings + 7 fences + 7 workers +
## 8 plaza props + 3 boats + 17 quay/industry props = 47 props.
const DENSITY_BY_SIZE := {"small": "sparse", "medium": "normal", "large": "busy"}
const DENSITY_ORDER := ["sparse", "normal", "busy"]
const TOWN_COUNTS := {
	"fence": {"sparse": 5, "normal": 7, "busy": 9},
	"worker": {"sparse": 4, "normal": 7, "busy": 9},
	"decor": {"sparse": 5, "normal": 8, "busy": 10},
	"boat": {"sparse": 2, "normal": 3, "busy": 5},
	"market_stall": {"sparse": 1, "normal": 2, "busy": 3},
	"harbor_crane": {"sparse": 0, "normal": 1, "busy": 2},
	"sack_pile": {"sparse": 1, "normal": 2, "busy": 2},
	"plate_stack": {"sparse": 0, "normal": 1, "busy": 2},
	"ore_pile": {"sparse": 1, "normal": 1, "busy": 2},
	"pallet": {"sparse": 1, "normal": 3, "busy": 4},
	"gangway": {"sparse": 0, "normal": 1, "busy": 2},
	"mooring_bollard": {"sparse": 2, "normal": 3, "busy": 4},
	"capstan": {"sparse": 0, "normal": 1, "busy": 1},
	"buoy": {"sparse": 1, "normal": 2, "busy": 3},
}
## Iteration order for the quay/industry prop groups (deterministic mount order).
const TOWN_QUAY_ORDER := [
	"market_stall", "harbor_crane", "sack_pile", "plate_stack", "ore_pile",
	"pallet", "gangway", "mooring_bollard", "capstan", "buoy",
]
## Buildings stand on a raised stone plaza behind the quay, facing the camera
## (+Z). The plaza is what makes them read as ground-level buildings instead of
## floating boxes on the water sheet.
const TOWN_GROUND_Y := 1.9
const TOWN_PLAZA_SIZE := Vector3(250.0, 2.2, 34.0)
const TOWN_PLAZA_CENTER := Vector3(0.0, 0.8, -27.0)
## Buildings are always mounted: they carry the street silhouette and only fall
## back to blockouts when their GLB is missing.
## `warehouse_long` is rotated -106 deg (not -90) and moved 1 m toward the quay so
## its loading-door long facade faces the fixed camera instead of running away from
## it: the facade normal goes from 52 deg to 36 deg off the camera axis (+38% facade
## area, +35% door area on screen, doors unobstructed), the footprint still sits on
## the plaza and keeps 0.9 m clearance to the quay crane block.
const TOWN_SLOTS := [
	{"slot": "warehouse_long", "pos": Vector3(-30.0, TOWN_GROUND_Y, -33.0), "yaw": -106.0, "scale": 1.0},
	{"slot": "warehouse_short", "pos": Vector3(27.0, TOWN_GROUND_Y, -30.0), "yaw": -90.0, "scale": 0.95},
	{"slot": "harbor_office", "pos": Vector3(14.0, TOWN_GROUND_Y, -40.0), "yaw": -80.0, "scale": 1.0},
	{"slot": "tavern", "pos": Vector3(-12.0, TOWN_GROUND_Y, -26.0), "yaw": -100.0, "scale": 1.0},
	{"slot": "cargo_shed", "pos": Vector3(1.0, TOWN_GROUND_Y, -20.0), "yaw": -90.0, "scale": 1.0},
]
## Fence modules line the plaza/quay seam (6 m modules, mounted left to right).
const TOWN_FENCE_X := [-24.0, -18.0, -12.0, -6.0, 0.0, 6.0, 12.0, 18.0, 24.0]
## Worker silhouettes on the quay deck / plaza (human scale, no animation).
## Ordered: quay crew first (sparse still reads as a working pier), then plaza
## pairs, then the busy tier extras.
const TOWN_WORKER_SLOTS := [
	{"slot": "dock_worker_a", "pos": Vector3(-7.0, DOCK_TOP, -2.2), "yaw": 35.0},
	{"slot": "dock_worker_b", "pos": Vector3(6.5, DOCK_TOP, -2.4), "yaw": -40.0},
	{"slot": "dock_worker_a", "pos": Vector3(21.0, DOCK_TOP, -2.6), "yaw": 150.0},
	{"slot": "dock_worker_b", "pos": Vector3(0.0, DOCK_TOP, -5.8), "yaw": 10.0},
	{"slot": "dock_worker_a", "pos": Vector3(-14.0, TOWN_GROUND_Y, -13.6), "yaw": 60.0},
	{"slot": "dock_worker_b", "pos": Vector3(16.0, TOWN_GROUND_Y, -14.2), "yaw": -120.0},
	{"slot": "dock_worker_a", "pos": Vector3(21.5, DOCK_TOP, -10.6), "yaw": 75.0},
	{"slot": "dock_worker_b", "pos": Vector3(-19.6, DOCK_TOP, -11.0), "yaw": 20.0},
	{"slot": "dock_worker_a", "pos": Vector3(8.0, TOWN_GROUND_Y, -16.5), "yaw": -95.0},
]
## Reused core props keep the plaza from reading as an empty slab. Ordered:
## the authored eight first, then the busy-tier extras.
const TOWN_DECOR_SLOTS := [
	{"slot": "crate", "pos": Vector3(-21.0, TOWN_GROUND_Y, -16.0), "yaw": 20.0},
	{"slot": "crate", "pos": Vector3(-19.4, TOWN_GROUND_Y, -15.1), "yaw": -15.0},
	{"slot": "barrel", "pos": Vector3(-23.0, TOWN_GROUND_Y, -18.0), "yaw": 0.0},
	{"slot": "coal_pile", "pos": Vector3(22.0, TOWN_GROUND_Y, -18.0), "yaw": 0.0},
	{"slot": "timber_stack", "pos": Vector3(-5.0, TOWN_GROUND_Y, -15.5), "yaw": 90.0},
	{"slot": "handcart", "pos": Vector3(-16.0, TOWN_GROUND_Y, -14.0), "yaw": 60.0},
	{"slot": "gas_lamp", "pos": Vector3(-9.0, TOWN_GROUND_Y, -11.6), "yaw": 0.0},
	{"slot": "gas_lamp", "pos": Vector3(9.0, TOWN_GROUND_Y, -11.6), "yaw": 0.0},
	{"slot": "crate", "pos": Vector3(-26.5, TOWN_GROUND_Y, -19.5), "yaw": 45.0},
	{"slot": "barrel", "pos": Vector3(25.5, TOWN_GROUND_Y, -19.0), "yaw": -30.0},
]
## Small craft in the water around the player ship (authored three, then the
## busy-tier extras).
const TOWN_BOAT_SLOTS := [
	{"slot": "rowboat", "pos": Vector3(-28.0, 0.02, 2.0), "yaw": -25.0},
	{"slot": "rowboat", "pos": Vector3(26.0, 0.02, 1.0), "yaw": 20.0},
	{"slot": "cargo_lighter", "pos": Vector3(20.0, 0.02, 3.0), "yaw": -75.0},
	{"slot": "rowboat", "pos": Vector3(-34.0, 0.02, 4.0), "yaw": 15.0},
	{"slot": "rowboat", "pos": Vector3(33.0, 0.02, -2.0), "yaw": -10.0},
]
## New dock-side industry/market props (official kit keys only). Each list is
## cut to the density count above; positions avoid the facility slots on the
## quay and the authored town row on the plaza.
const TOWN_QUAY_SLOTS := {
	"market_stall": [
		{"pos": Vector3(-24.5, TOWN_GROUND_Y, -14.6), "yaw": 8.0},
		{"pos": Vector3(4.0, TOWN_GROUND_Y, -14.8), "yaw": -6.0},
		{"pos": Vector3(23.0, TOWN_GROUND_Y, -16.0), "yaw": 175.0},
	],
	"harbor_crane": [
		{"pos": Vector3(-42.0, TOWN_GROUND_Y, -41.0), "yaw": -90.0},
		{"pos": Vector3(33.0, TOWN_GROUND_Y, -40.0), "yaw": -90.0},
	],
	"sack_pile": [
		{"pos": Vector3(-21.2, DOCK_TOP, -9.8), "yaw": 12.0},
		{"pos": Vector3(23.5, DOCK_TOP, -9.4), "yaw": -8.0},
	],
	"plate_stack": [
		{"pos": Vector3(-25.2, DOCK_TOP, -10.8), "yaw": 0.0},
		{"pos": Vector3(24.8, DOCK_TOP, -10.8), "yaw": 90.0},
	],
	"ore_pile": [
		{"pos": Vector3(-23.0, DOCK_TOP, -4.8), "yaw": 18.0},
		{"pos": Vector3(24.0, DOCK_TOP, -4.5), "yaw": -24.0},
	],
	"pallet": [
		{"pos": Vector3(-25.2, DOCK_TOP, -8.0), "yaw": 6.0},
		{"pos": Vector3(-23.8, DOCK_TOP, -8.8), "yaw": -12.0},
		{"pos": Vector3(23.0, DOCK_TOP, -6.6), "yaw": 30.0},
		{"pos": Vector3(25.0, DOCK_TOP, -7.8), "yaw": -22.0},
	],
	"gangway": [
		{"pos": Vector3(-20.5, DOCK_TOP, -0.1), "yaw": 0.0},
		{"pos": Vector3(18.5, DOCK_TOP, -0.1), "yaw": 0.0},
	],
	"mooring_bollard": [
		{"pos": Vector3(-22.0, DOCK_TOP, -0.5), "yaw": 0.0},
		{"pos": Vector3(-12.0, DOCK_TOP, -0.5), "yaw": 0.0},
		{"pos": Vector3(3.0, DOCK_TOP, -0.5), "yaw": 0.0},
		{"pos": Vector3(22.0, DOCK_TOP, -0.5), "yaw": 0.0},
	],
	"capstan": [
		{"pos": Vector3(-26.0, DOCK_TOP, -2.6), "yaw": 0.0},
	],
	"buoy": [
		{"pos": Vector3(-30.0, 0.02, 7.0), "yaw": 0.0},
		{"pos": Vector3(30.0, 0.02, 6.0), "yaw": 0.0},
		{"pos": Vector3(-36.0, 0.02, 3.0), "yaw": 0.0},
	],
}
## Per-station dressing: the moment the camera lands on a station the ground in
## front of it must read as that station's place, not as generic quay. Each list
## is an ordered prefix (core props first) cut by the street density tier, and
## every slot reuses an official town-kit key already resolved into
## `port.town_visuals` — no new content keys and no new models are required.
const STATION_PROP_COUNTS := {"sparse": 5, "normal": 8, "busy": 11}
const STATION_PROPS := {
	"market": [
		{"slot": "market_stall", "pos": Vector3(-30.0, TOWN_GROUND_Y, -15.4), "yaw": 2.0},
		{"slot": "market_stall", "pos": Vector3(-37.8, TOWN_GROUND_Y, -16.2), "yaw": 9.0},
		{"slot": "market_stall", "pos": Vector3(-43.0, TOWN_GROUND_Y, -15.0), "yaw": -5.0},
		{"slot": "crate", "pos": Vector3(-21.6, TOWN_GROUND_Y, -13.6), "yaw": 26.0},
		{"slot": "barrel", "pos": Vector3(-33.6, TOWN_GROUND_Y, -13.2), "yaw": -12.0},
		{"slot": "handcart", "pos": Vector3(-27.4, TOWN_GROUND_Y, -20.4), "yaw": 96.0},
		{"slot": "crate", "pos": Vector3(-40.6, TOWN_GROUND_Y, -19.6), "yaw": 44.0},
		{"slot": "barrel", "pos": Vector3(-20.8, TOWN_GROUND_Y, -20.2), "yaw": 18.0},
		{"slot": "sack_pile", "pos": Vector3(-35.8, DOCK_TOP, -9.6), "yaw": 8.0},
		{"slot": "gas_lamp", "pos": Vector3(-31.2, TOWN_GROUND_Y, -12.3), "yaw": 0.0},
		{"slot": "crate", "pos": Vector3(-45.2, TOWN_GROUND_Y, -19.0), "yaw": -30.0},
	],
	"harbor": [
		{"slot": "gas_lamp", "pos": Vector3(-2.6, TOWN_GROUND_Y, -11.6), "yaw": 0.0},
		{"slot": "handcart", "pos": Vector3(3.6, TOWN_GROUND_Y, -20.4), "yaw": -72.0},
		{"slot": "crate", "pos": Vector3(9.2, TOWN_GROUND_Y, -18.6), "yaw": 32.0},
		{"slot": "barrel", "pos": Vector3(-6.4, TOWN_GROUND_Y, -19.8), "yaw": 0.0},
		{"slot": "mooring_bollard", "pos": Vector3(-4.0, DOCK_TOP, -0.5), "yaw": 0.0},
		{"slot": "pallet", "pos": Vector3(12.2, DOCK_TOP, -7.2), "yaw": 8.0},
		{"slot": "crate", "pos": Vector3(-11.2, TOWN_GROUND_Y, -14.8), "yaw": 40.0},
		{"slot": "cargo_lighter", "pos": Vector3(13.2, 0.02, 4.0), "yaw": -70.0},
		{"slot": "plate_stack", "pos": Vector3(15.6, DOCK_TOP, -10.4), "yaw": 90.0},
		{"slot": "barrel", "pos": Vector3(7.6, TOWN_GROUND_Y, -16.2), "yaw": -20.0},
		{"slot": "sack_pile", "pos": Vector3(-13.2, DOCK_TOP, -9.4), "yaw": 10.0},
	],
	"supply": [
		{"slot": "coal_pile", "pos": Vector3(30.0, TOWN_GROUND_Y, -15.6), "yaw": 0.0},
		{"slot": "ore_pile", "pos": Vector3(24.2, DOCK_TOP, -9.4), "yaw": 16.0},
		{"slot": "sack_pile", "pos": Vector3(28.0, DOCK_TOP, -9.8), "yaw": -6.0},
		{"slot": "plate_stack", "pos": Vector3(36.6, DOCK_TOP, -10.8), "yaw": 90.0},
		{"slot": "timber_stack", "pos": Vector3(38.4, TOWN_GROUND_Y, -18.6), "yaw": 88.0},
		{"slot": "coal_pile", "pos": Vector3(40.8, TOWN_GROUND_Y, -13.4), "yaw": 24.0},
		{"slot": "handcart", "pos": Vector3(25.4, TOWN_GROUND_Y, -13.2), "yaw": 58.0},
		{"slot": "pallet", "pos": Vector3(33.4, DOCK_TOP, -7.4), "yaw": 0.0},
		{"slot": "barrel", "pos": Vector3(42.2, TOWN_GROUND_Y, -20.2), "yaw": 0.0},
		{"slot": "crate", "pos": Vector3(35.0, TOWN_GROUND_Y, -12.8), "yaw": 22.0},
		{"slot": "sack_pile", "pos": Vector3(31.2, DOCK_TOP, -9.2), "yaw": 4.0},
	],
}
## Procedural blockout sizes for the town buildings when the GLB kit is missing
## (X = frontage, Y = height, Z = depth, matching the kit's footprint).
const TOWN_BLOCKOUT_SIZES := {
	"warehouse_long": Vector3(20.0, 11.0, 9.0),
	"warehouse_short": Vector3(11.0, 9.5, 9.0),
	"harbor_office": Vector3(9.0, 14.0, 8.0),
	"tavern": Vector3(10.0, 8.0, 8.0),
	"cargo_shed": Vector3(8.0, 4.5, 6.0),
}


## Procedural L6 foreground frame + L7 atmosphere (no external textures).
const FOREGROUND_COLOR := Color(0.105, 0.082, 0.066)
const FOG_BAND_COLOR := Color(0.68, 0.57, 0.45)
const FOG_BAND_ALPHA := 0.15
const ATMOSPHERE_PARTICLE_AMOUNT := 20
const SKY_GLOW_COLOR := Color(1.0, 0.80, 0.50)

const MATERIAL_DEFAULTS := {
	"stone": [Color(0.15, 0.14, 0.12), 0.92, 0.0],
	"deck": [Color(0.23, 0.16, 0.10), 0.88, 0.0],
	"wood": [Color(0.31, 0.22, 0.13), 0.86, 0.0],
	"wood_dark": [Color(0.16, 0.11, 0.07), 0.9, 0.0],
	"metal": [Color(0.20, 0.22, 0.24), 0.55, 0.45],
	"iron": [Color(0.11, 0.12, 0.13), 0.6, 0.5],
	"canvas": [Color(0.55, 0.46, 0.33), 0.95, 0.0],
	"brass": [Color(0.52, 0.38, 0.16), 0.42, 0.65],
	"plaza": [Color(0.24, 0.22, 0.19), 0.9, 0.0],
}

const LANDMARK_POS := Vector3(-25.0, DOCK_TOP, -15.5)

var _static_built := false
var _content: Node3D
var _facilities_root: Node3D
var _camera: Camera3D
var _water_material: ShaderMaterial
var _materials: Dictionary = {}

var _port: Dictionary = {}
var _visuals: Dictionary = {}
var _palette: Dictionary = {}
var _facilities: Array[String] = []
var _facilities_present: Dictionary = {}
var _anchors: Dictionary = {}
var _kinds: Dictionary = {}
var _filler_count := 0
var _scale := 1.0
var _size := "medium"
var _backdrop: MeshInstance3D
var _has_backdrop := false
var _banner_path := ""
var _loaded_banner_path := ""
var _landmark: Node3D
var _shore_shelf: MeshInstance3D
var _sky_card: MeshInstance3D
var _fallback_sky_root: Node3D
var _foreground_frame: Node3D
var _atmosphere_root: Node3D
var _shore_steam: GPUParticles3D
var _particle_count := 0
var _fog_layer_count := 0
var _fog_nodes: Array[MeshInstance3D] = []
var _fog_bases: Array[Vector3] = []
var _fog_phases: Array[float] = []
var _skyline_building_count := 0
var _skyline_crane_count := 0
var _town_root: Node3D
var _town_visuals: Dictionary = {}
var _town_prop_count := 0
var _town_blockout_count := 0
var _station_prop_count := 0
var _town_density := "normal"
var _painted_layer_count := 0
## Station state: which adjacent station the camera and the hull currently serve.
## `focus_station()` only retargets the shot and the berth; the district itself
## (facilities, town, water, backdrop) stays built exactly once per bind.
var _station := DEFAULT_STATION
var _station_framing := "stage"
var _camera_target := CAMERA_TARGET
var _camera_from := CAMERA_POS
var _camera_from_target := CAMERA_TARGET
var _camera_to := CAMERA_POS
var _camera_to_target := CAMERA_TARGET
var _camera_from_fov := CAMERA_FOV
var _camera_to_fov := CAMERA_FOV
var _camera_t := 1.0
## Horizontal offset of the current shot against the harbour reference shot.
## Camera-facing layers (sky card, painted backdrop, foreground frame, banner)
## are translated by it so the pan keeps their screen composition, while world
## geometry (quay, town, ships, water) really moves through the frame.
var _camera_shift_x := 0.0
var _ship_x := SHIP_SPAWN.x
var _ship_moor_x := SHIP_SPAWN.x
var _ship_moor_z := SHIP_SPAWN.z
var _ship_moor_yaw := deg_to_rad(SHIP_YAW_DEG)
var _ship_sailing := false
var _skyline_root: Node3D
var _ship_steam: GPUParticles3D
var _batch_batches := 0
var _batch_multimesh_batches := 0
var _batch_material_batches := 0
var _batch_meshes_before := 0
var _batch_meshes_after := 0
var _batch_surfaces_before := 0
var _batch_surfaces_after := 0
var _unshaded_materials: Dictionary = {}
var _ship_root: Node3D
var _ship_yaw := deg_to_rad(SHIP_YAW_DEG)
var _ship_bounds := AABB()
var _ship_bounds_offset := Vector3.ZERO
var _ship_batches := 0
var _ship_multimesh_batches := 0
var _ship_material_batches := 0
var _ship_meshes_before := 0
var _ship_meshes_after := 0
var _ship_surfaces_before := 0
var _ship_surfaces_after := 0
var _ship_fallback := false
var _signature := ""
var _enter_payload: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	if stage_id.is_empty():
		stage_id = "port"
	_ensure_static()
	set_process(true)


func enter(payload: Dictionary = {}) -> void:
	if payload.has("port") or payload.has("ship") or payload.has("facility_visuals") or payload.has("town_visuals"):
		_enter_payload = payload.duplicate(true)
	# Optional initial station: the shell mounts the stage straight onto the page
	# it is showing, so the first frame is already the right station shot instead
	# of the harbour reference shot panning to it.
	var station := String(payload.get("station", ""))
	if STATIONS.has(station):
		focus_station(station, String(payload.get("station_framing", "stage")), true)
	set_process(true)


func exit() -> void:
	set_process(false)


func bind(view_model: Dictionary = {}) -> void:
	_ensure_static()
	var data := view_model
	if not _has_stage_data(data) and not _enter_payload.is_empty():
		data = _enter_payload
	var port_value: Variant = data.get("port", {})
	var port: Dictionary = port_value if port_value is Dictionary else {}
	var ship_value: Variant = data.get("ship", {})
	var ship: Dictionary = ship_value if ship_value is Dictionary else {}
	var root_visuals: Variant = data.get("facility_visuals", {})
	var root_town: Variant = data.get("town_visuals", {})
	var signature := str(port) + "|" + str(ship) + "|" + str(root_visuals) + "|" + str(root_town)
	if signature == _signature:
		return
	_signature = signature
	_apply_view_model(port, ship, data)


## --- Contract queries -------------------------------------------------------

## Procedural stage: always drawable, even when every content asset is missing.
func has_visual() -> bool:
	return true


func has_backdrop() -> bool:
	return _has_backdrop


## Path of the L1 backdrop texture that actually loaded (`""` when absent).
func loaded_banner_path() -> String:
	return _loaded_banner_path


func facility_count() -> int:
	return _facilities.size()


## Number of empty facility slots that received cargo filler instead of an
## anchor (one per missing facility in FACILITY_ORDER).
func filler_count() -> int:
	return _filler_count


## "model" (facility_visuals GLB mounted), "billboard" (procedural anchor) or
## "missing" (facility absent — only cargo filler exists, never a hotspot).
func facility_visual_kind(facility: String) -> String:
	return String(_kinds.get(facility, "missing"))


## World-space anchor per present facility (facility id -> Vector3).
func facility_anchors() -> Dictionary:
	var result := {}
	if _facilities_root == null:
		return result
	for facility in _facilities:
		if not _anchors.has(facility):
			continue
		var anchor: Node3D = _anchors[facility]
		result[facility] = _facilities_root.to_global(anchor.position)
	return result


## Same anchors projected through the stage camera and normalised to 0..1, so
## 2D hotspots can be laid out without touching 3D internals. ZERO when absent.
func facility_screen_anchor(facility: String) -> Vector2:
	if not _anchors.has(facility) or _camera == null:
		return Vector2.ZERO
	if _facilities_root == null or not is_inside_tree():
		return Vector2.ZERO
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var anchor: Node3D = _anchors[facility]
	var screen_pos := _camera.unproject_position(_facilities_root.to_global(anchor.position))
	return Vector2(screen_pos.x / viewport_size.x, screen_pos.y / viewport_size.y)


func has_ship() -> bool:
	return _ship_root != null and is_instance_valid(_ship_root) and _ship_root.get_child_count() > 0


## Emits the player intent; the host / page decides where it leads.
func request_portal(facility: String) -> void:
	portal_requested.emit(facility)


func hotspot_anchors() -> Dictionary:
	return facility_anchors()


## --- Scene-fill (L0/L1/L2/L6/L7) read-only accessors -----------------------

## L6 foreground frame root (2-4 dark unshaded props entering the frame edge).
func foreground_frame() -> Node3D:
	return _foreground_frame


## Number of L7 smoke/steam particle systems mounted by the stage (<= 3).
func atmosphere_particle_systems() -> int:
	return _particle_count


## Number of L7 low fog billboard layers mounted by the stage (<= 3).
func atmosphere_layers() -> int:
	return _fog_layer_count


## L2 skyline buildings currently drawn (0 when an L1 banner is mounted).
func skyline_building_count() -> int:
	return _skyline_building_count


## L2 skyline cranes currently drawn (0 when an L1 banner is mounted).
func skyline_crane_count() -> int:
	return _skyline_crane_count


## Number of harbour-town props mounted in the background (buildings, fence
## modules, workers, moored boats). 0 only when the town layer is disabled.
func town_prop_count() -> int:
	return _town_prop_count


## How many of those town props used the procedural blockout because the GLB
## was missing/invalid; the stage still stays dense and drawable.
func town_blockout_count() -> int:
	return _town_blockout_count


## Resolved street density tier for the current bind: "sparse" | "normal" |
## "busy". It is `port.density` / `port.diorama.density` when valid, otherwise
## derived from `port.size` (small -> sparse, medium -> normal, large -> busy).
func town_density() -> String:
	return _town_density


## Painted far-backdrop depth layers (ridge / distant city / harbour roofline)
## drawn behind the town when no L1 banner is mounted; 0 with a painted banner,
## which already supplies sky and skyline.
func painted_backdrop_layer_count() -> int:
	if _has_backdrop:
		return 0
	return _painted_layer_count


## Read-only static-batching report for tests and the preview/measure tools:
##   batches              MultiMesh + material-merged draw batches built
##                        for the facilities/town static layers
##   multimesh_batches    batched via MultiMeshInstance3D (shared mesh)
##   material_batches     merged by material signature into one static mesh
##   meshes_before/after  draw-mesh node count under the batched roots
##   surfaces_before/after surface count (the renderer's per-surface draws)
##   ship_*               the same report for the rigidly batched player hull
##                        (ship-local batches under `_ship_root`, so the bob and
##                        turn animation keeps moving the whole ship)
##   ship_fallback        true when the hull kept its original GLB hierarchy
##                        (animation/skeleton/particles/transparent material)
func batch_stats() -> Dictionary:
	return {
		"batches": _batch_batches,
		"multimesh_batches": _batch_multimesh_batches,
		"material_batches": _batch_material_batches,
		"meshes_before": _batch_meshes_before,
		"meshes_after": _batch_meshes_after,
		"surfaces_before": _batch_surfaces_before,
		"surfaces_after": _batch_surfaces_after,
		"ship_batches": _ship_batches,
		"ship_multimesh_batches": _ship_multimesh_batches,
		"ship_material_batches": _ship_material_batches,
		"ship_meshes_before": _ship_meshes_before,
		"ship_meshes_after": _ship_meshes_after,
		"ship_surfaces_before": _ship_surfaces_before,
		"ship_surfaces_after": _ship_surfaces_after,
		"ship_fallback": _ship_fallback,
	}


## World-space hull bounds used to configure the water foam ring. Captured from
## the un-batched hull before rigid batching, so batching can never move or
## resize the foam.
func ship_foam_bounds() -> AABB:
	return _ship_bounds


## True when `visual` is a purely rigid hull that can be baked into ship-local
## draw batches: no AnimationPlayer/AnimationTree, no skeleton/bones, no
## particles, no MultiMesh, no skinned/blend-shape meshes, and every
## MeshInstance3D is an opaque batchable box or mergeable triangle mesh.
## A false result makes the hull batching pass keep the original GLB untouched.
func ship_visual_is_rigid(visual: Node) -> bool:
	if visual == null or not is_instance_valid(visual):
		return false
	var stack: Array[Node] = [visual]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is AnimationPlayer or node is AnimationTree:
			return false
		if node is GPUParticles3D or node is CPUParticles3D:
			return false
		if node is Skeleton3D or node is BoneAttachment3D:
			return false
		if node is MultiMeshInstance3D:
			return false
		if node is MeshInstance3D:
			var instance := node as MeshInstance3D
			if instance.mesh != null:
				# A skinned mesh is deformed by its skeleton; the default
				# `skeleton` NodePath("..") alone is harmless without a skin.
				if instance.skin != null:
					return false
				if instance.mesh is ArrayMesh and (instance.mesh as ArrayMesh).get_blend_shape_count() > 0:
					return false
				if instance.mesh is BoxMesh:
					if not _can_batch_box(instance):
						return false
				elif not _can_merge_instance(instance):
					return false
				if not _mesh_bakeable(instance.mesh):
					return false
		for child in node.get_children():
			stack.append(child)
	return true


## True when every surface of `mesh` is a triangle surface with readable arrays
## (the hull batching pass requires a clean all-triangles mesh).
func _mesh_bakeable(mesh: Mesh) -> bool:
	if mesh.get_surface_count() <= 0:
		return false
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var arrays := mesh.surface_get_arrays(surface)
		if not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
			return false
	return true


# --- Adjacent stations ------------------------------------------------------

## Stations in world order (left -> right along the quay). Pages map to them, so
## switching a page is a camera pan plus a short sail, never a scene swap.
func station_ids() -> Array[String]:
	var result: Array[String] = []
	for station_id in STATION_ORDER:
		result.append(station_id)
	return result


func current_station() -> String:
	return _station


func current_station_framing() -> String:
	return _station_framing


## Per-station shot in world space. `panel` framing shifts the same shot a few
## metres so the station landmark stays visible beside the 620 px info panel.
func station_camera_pose(station_id: String, framing: String = "stage") -> Dictionary:
	var shot: Dictionary = STATIONS.get(station_id, STATIONS[DEFAULT_STATION])
	var shot_position: Vector3 = shot["camera"]
	var shot_target: Vector3 = shot["target"]
	var shift := PANEL_FRAMING_SHIFT_X if framing == "panel" else 0.0
	return {
		"position": shot_position + Vector3(shift, 0.0, 0.0),
		"target": shot_target + Vector3(shift, 0.0, 0.0),
		"fov": CAMERA_FOV,
	}


## The berth (world position) the player's hull takes at a station.
func station_ship_position(station_id: String) -> Vector3:
	var shot: Dictionary = STATIONS.get(station_id, STATIONS[DEFAULT_STATION])
	return shot["ship"]


func station_ship_yaw(station_id: String) -> float:
	var shot: Dictionary = STATIONS.get(station_id, STATIONS[DEFAULT_STATION])
	return deg_to_rad(float(shot.get("ship_yaw", SHIP_YAW_DEG)))


## Switches the camera and the hull to a station. Safe to call on every refresh:
## re-focusing the current station/framing is a no-op, so page rebuilds never
## restart the pan. `immediate` snaps (used when the stage is first mounted);
## otherwise the camera pans and the ship sails over the next 0.6-4 s.
func focus_station(station_id: String, framing: String = "stage", immediate: bool = false) -> bool:
	if not STATIONS.has(station_id):
		return false
	if not STATION_FRAMINGS.has(framing):
		framing = "stage"
	var changed := station_id != _station or framing != _station_framing
	_station = station_id
	_station_framing = framing
	_ship_moor_x = station_ship_position(station_id).x
	_ship_moor_z = station_ship_position(station_id).z
	_ship_moor_yaw = station_ship_yaw(station_id)
	if _camera == null:
		return true
	var pose := station_camera_pose(station_id, framing)
	if immediate:
		_camera_from = pose["position"]
		_camera_from_target = pose["target"]
		_camera_from_fov = float(pose["fov"])
		_camera_to = _camera_from
		_camera_to_target = _camera_from_target
		_camera_to_fov = _camera_from_fov
		_camera_t = 1.0
		_camera.position = _camera_from
		_camera_target = _camera_from_target
		_camera.fov = _camera_from_fov
		_ship_x = _ship_moor_x
		_ship_yaw = _ship_moor_yaw
		_ship_sailing = false
		_apply_camera_shift()
		_camera.look_at(_camera_target, Vector3.UP)
		_apply_ship_pose()
		return true
	if not changed:
		return true
	if _camera_t >= 1.0:
		_camera_from = _camera.position
		_camera_from_target = _camera_target
		_camera_from_fov = _camera.fov
	_camera_to = pose["position"]
	_camera_to_target = pose["target"]
	_camera_to_fov = float(pose["fov"])
	_camera_t = 0.0
	return true


## True while the camera is still panning or the hull is still manoeuvring.
func is_station_transitioning() -> bool:
	if _camera_t < 1.0:
		return true
	return absf(_ship_x - _ship_moor_x) > 0.25 or absf(angle_difference(_ship_yaw, _ship_moor_yaw)) > 0.02


func camera_position() -> Vector3:
	return _camera.position if _camera != null else Vector3.ZERO


func camera_target() -> Vector3:
	return _camera_target


## World X of the player's hull (it moves between the station berths).
func ship_x() -> float:
	return _ship_x


func station_ship_mooring_x() -> float:
	return _ship_moor_x


## Props mounted by the station dressing layer (market square / supply yard /
## harbour-authority frontage). Town-kit props are counted separately.
func station_prop_count() -> int:
	return _station_prop_count


## Current shot offset against the harbour reference shot (tests / preview).
func camera_shift_x() -> float:
	return _camera_shift_x


## Advances the station transition by `delta` seconds. `_process` drives it in
## the game; tests and capture tools step it directly so headless runs do not
## depend on real frames. A large delta is sliced into 50 ms steps so a single
## call settles the whole pan/sail instead of leaving the hull mid-manoeuvre.
func advance_station(delta: float) -> void:
	var remaining := maxf(0.0, delta)
	while remaining > 0.0001:
		var step := minf(remaining, 0.05)
		_advance_camera(step)
		_advance_ship(step)
		remaining -= step


func _advance_camera(delta: float) -> void:
	if _camera == null:
		return
	if _camera_t < 1.0:
		_camera_t = minf(1.0, _camera_t + delta / maxf(0.01, CAMERA_PAN_SECONDS))
		var eased := smoothstep(0.0, 1.0, _camera_t)
		_camera.position = _camera_from.lerp(_camera_to, eased)
		_camera_target = _camera_from_target.lerp(_camera_to_target, eased)
		_camera.fov = lerpf(_camera_from_fov, _camera_to_fov, eased)
		_apply_camera_shift()
	_camera.look_at(_camera_target, Vector3.UP)


func _advance_ship(delta: float) -> void:
	if _ship_root == null or not is_instance_valid(_ship_root):
		return
	var dx := _ship_moor_x - _ship_x
	if absf(dx) > 0.25:
		# Sailing: turn the bow into the travel direction first, then run along
		# the quay so the hull visibly relocates instead of sliding sideways.
		var travel_yaw := 0.0 if dx > 0.0 else PI
		_ship_yaw = rotate_toward(_ship_yaw, travel_yaw, SHIP_TURN_SPEED * delta)
		var alignment := maxf(0.25, cos(angle_difference(_ship_yaw, travel_yaw)))
		_ship_x = move_toward(_ship_x, _ship_moor_x, SHIP_TRANSIT_SPEED * delta * alignment)
		if absf(_ship_moor_x - _ship_x) <= 0.25:
			_ship_x = _ship_moor_x
		_ship_sailing = true
	else:
		_ship_x = _ship_moor_x
		if _ship_sailing:
			_ship_yaw = rotate_toward(_ship_yaw, _ship_moor_yaw, SHIP_TURN_SPEED * delta)
			if absf(angle_difference(_ship_yaw, _ship_moor_yaw)) < 0.01:
				_ship_yaw = _ship_moor_yaw
				_ship_sailing = false
		else:
			_ship_yaw = _ship_moor_yaw
	_apply_ship_pose()


func _apply_ship_pose() -> void:
	if _ship_root == null or not is_instance_valid(_ship_root):
		return
	_ship_root.position = Vector3(
		_ship_x,
		sin(_time * BOB_SPEED) * BOB_AMPLITUDE,
		_ship_moor_z
	)
	_ship_root.rotation = Vector3(0.0, _ship_yaw, sin(_time * BOB_SPEED * 0.75) * 0.004)
	_sync_boat_foam()
	if _ship_steam != null and is_instance_valid(_ship_steam):
		_ship_steam.position.x = _ship_x - 2.5


## The foam ring belongs to the hull, not to the stage: while the ship sails
## between berths the shader centre follows it, so the water never keeps a foam
## ring at the previous station.
func _sync_boat_foam() -> void:
	if _water_material == null:
		return
	_water_material.set_shader_parameter(
		"boat_center",
		Vector2(
			_ship_x + _ship_bounds_offset.x,
			_ship_moor_z + _ship_bounds_offset.z
		)
	)
	_water_material.set_shader_parameter("boat_yaw", _ship_yaw)


## Keeps camera-facing layers glued to the frame while the shot pans. World
## layers (quay, town, water, hull) pan naturally; the far silhouette row gets
## half the shift so it keeps a little parallax instead of sliding like a sticker.
func _apply_camera_shift() -> void:
	_camera_shift_x = _camera_target.x - CAMERA_TARGET.x
	if _fallback_sky_root != null and is_instance_valid(_fallback_sky_root):
		_fallback_sky_root.position.x = _camera_shift_x
	if _foreground_frame != null and is_instance_valid(_foreground_frame):
		_foreground_frame.position.x = _camera_shift_x
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.position.x = BACKDROP_POSITION.x + _camera_shift_x
	if _skyline_root != null and is_instance_valid(_skyline_root):
		_skyline_root.position.x = _camera_shift_x * 0.5


# --- Frame loop -------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if not is_visible_in_tree():
		return
	advance_station(delta)
	# Fog bands drift slowly; the hash-seeded phase keeps each stage unique while
	# the motion stays fully deterministic. The camera shift keeps them glued to
	# the frame like the rest of the painted far layers.
	for index in _fog_nodes.size():
		var fog := _fog_nodes[index]
		if fog == null or not is_instance_valid(fog):
			continue
		if index >= _fog_bases.size() or index >= _fog_phases.size():
			continue
		var base := _fog_bases[index]
		fog.position = base + Vector3(
			_camera_shift_x + sin(_time * 0.055 + _fog_phases[index]) * 5.0, 0.0, 0.0
		)


# --- Static construction ----------------------------------------------------

func _ensure_static() -> void:
	if _static_built:
		return
	_static_built = true
	_build_materials()
	_build_environment()
	_add_fallback_backdrop()
	_add_water()
	_add_quay()
	_add_camera()
	_add_foreground_frame()
	_add_atmosphere()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)
	# The initial shot may already be a station other than the reference harbour
	# one (the shell mounts the stage straight onto the page being shown), so the
	# camera-facing layers are aligned before the first frame.
	_apply_camera_shift()


func _build_materials() -> void:
	_materials.clear()
	_unshaded_materials.clear()
	for key in MATERIAL_DEFAULTS.keys():
		var spec: Array = MATERIAL_DEFAULTS[key]
		var material := StandardMaterial3D.new()
		material.resource_name = "Port_" + String(key)
		material.albedo_color = spec[0]
		material.roughness = float(spec[1])
		material.metallic = float(spec[2])
		_materials[String(key)] = material


func _material(key: String) -> StandardMaterial3D:
	return _materials.get(key, null) as StandardMaterial3D


func _build_environment() -> void:
	var world_environment := StageKit.add_environment(self, {
		"mode": "sky",
		"sky_top": SKY_TOP,
		"sky_horizon": SKY_HORIZON,
		"ground_horizon": SKY_GROUND_HORIZON,
		"ground_bottom": SKY_GROUND_BOTTOM,
		"sky_curve": 0.10,
		"sun_angle_max": 10.0,
		"ambient_color": AMBIENT_COLOR,
		"ambient_energy": 0.55,
		"fog": true,
		"fog_color": FOG_COLOR,
		"fog_density": 0.0035,
		"fog_sky_affect": 0.08,
		"node_name": "StageEnvironment",
	})
	var environment := world_environment.environment
	if environment != null:
		# Depth (linear) fog instead of the default exponential curve: the quay
		# stays readable while the shore silhouettes and backdrop melt together.
		environment.fog_mode = Environment.FOG_MODE_DEPTH
		environment.fog_depth_begin = 70.0
		environment.fog_depth_end = 450.0
		environment.fog_depth_curve = 1.0
		environment.ambient_light_energy = 0.6
		# L0: warm the procedural sky and soften the sun so the fallback painted
		# sky and the 3D lighting read as one dusk grade.
		var sky := environment.sky
		if sky != null and sky.sky_material is ProceduralSkyMaterial:
			var sky_material := sky.sky_material as ProceduralSkyMaterial
			sky_material.sky_energy_multiplier = 1.12
			sky_material.sun_angle_max = 18.0
			sky_material.sun_curve = 0.22
	# One warm key + one cool fill; fixed stages never pay for real-time shadows.
	StageKit.add_directional_light(self, "KeyLight", Color(1.0, 0.79, 0.55), 1.7, Vector3(-52.0, 38.0, 0.0))
	StageKit.add_directional_light(self, "FillLight", Color(0.48, 0.63, 0.82), 0.5, Vector3(-26.0, -142.0, 0.0))


func _add_water() -> void:
	var near_overrides := {
		"shore_z": 0.0,
		"shore_span": 120.0,
		"shore_foam_width": 2.8,
		"foam_strength": 0.55,
		"boat_center": Vector2(0.0, 10000.0),
		"boat_half_size": Vector2(1.0, 1.0),
		"boat_yaw": 0.0,
		"boat_foam_width": 0.7,
		"horizon_fade_start": 130.0,
		"horizon_fade_end": 420.0,
		"horizon_color": FOG_COLOR,
	}
	var near_water := StageKit.add_water(self, StageKit.WATER_MATERIAL, NEAR_WATER_SIZE, 0.0, near_overrides)
	near_water.name = "NearWater"
	_water_material = near_water.material_override as ShaderMaterial
	# The far sheet only outputs the horizon/fog colour; at 2400 m it reaches the
	# horizon line, so no sky-ground band is left visible behind the backdrop.
	var far_water := StageKit.add_water(self, StageKit.WATER_FAR_MATERIAL, FAR_WATER_SIZE, -0.2)
	far_water.name = "FarWater"
	var far_material := far_water.material_override as ShaderMaterial
	if far_material != null:
		far_material.set_shader_parameter("horizon_color", FOG_COLOR)


## L1 fallback painted backdrop (no banner): a camera-facing dusk sky card with
## a warm gradient + additive sun halo/core, plus three batched silhouette depth
## layers (mountain ridge / distant city towers / harbour roofline + chimneys).
## Every texture is procedural, so the stage needs no new assets. The whole
## group is hidden whenever a real banner backdrop is mounted.
func _add_fallback_backdrop() -> void:
	_fallback_sky_root = Node3D.new()
	_fallback_sky_root.name = "FallbackBackdrop"
	add_child(_fallback_sky_root)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.55, 0.72, 1.0])
	gradient.colors = PackedColorArray([SKY_TOP, SKY_TOP, SKY_HORIZON, FOG_COLOR, FOG_COLOR])
	var texture := _gradient_texture_2d(gradient, 8, 256, GradientTexture2D.FILL_LINEAR, Vector2(0.0, 0.0), Vector2(0.0, 1.0))
	var material := StandardMaterial3D.new()
	material.resource_name = "Port_SkyCard"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var card := MeshInstance3D.new()
	card.name = "SkyCard"
	card.mesh = quad
	card.material_override = material
	card.transform = _screen_frame_xform(
		SKY_CARD_SCREEN_CENTER.x, SKY_CARD_SCREEN_CENTER.y, SKY_CARD_DEPTH,
		SKY_CARD_SCREEN_SIZE.x, SKY_CARD_SCREEN_SIZE.y
	)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fallback_sky_root.add_child(card)
	_sky_card = card
	# Sun halo + hot core, placed between the shoreline silhouettes and the
	# gradient card so the skyline stays in front of the glow. Both quads are
	# true soft gradients: radial alpha falls to zero on every edge.
	var sun_pos := _screen_point(0.70, 0.10, 118.0)
	_add_sky_glow(_fallback_sky_root, sun_pos, 90.0, Color(0.95, 0.66, 0.38), 0.12, "SunHalo")
	_add_sky_glow(_fallback_sky_root, sun_pos, 18.0, SKY_GLOW_COLOR, 0.62, "SunCore")
	# Painted depth: three batched silhouette bands between the L2 shoreline and
	# the sky card, so the no-banner stage gets a layered horizon instead of a
	# flat warm gradient even when the town kit is mounted (the L2 row is skipped
	# there). All of it lives under `_fallback_sky_root`, so a painted banner
	# hides the whole fallback backdrop in one toggle.
	_add_painted_backdrop_layers()


## Adds the painted far-backdrop layers: a low harbour roofline with chimneys,
## a distant city tower cluster and a mountain ridge. Each layer is a run of
## screen-aligned boxes placed by `_screen_point()` at a depth behind the
## town/L2 rows but well in front of the sky card, so they read as one painted
## backdrop with real depth. Every piece is folded into a single MultiMesh
## (1 draw call), unshaded, no shadows, low contrast against the dusk haze.
func _add_painted_backdrop_layers() -> void:
	# Bases sit below the water/shore horizon so the far water clips them: the
	# silhouettes rise out of the haze instead of showing a floating bottom edge.
	# Depths are 40-80 m behind the L2 row and far in front of the sky card.
	var bottom := 0.460
	var layer_specs := [
		{
			"depth": 200.0,
			"color": Color(0.115, 0.082, 0.058),
			"pieces": [
				# [u, width_fraction, height_fraction] — harbour roofline blocks…
				Vector3(-0.02, 0.230, 0.062), Vector3(0.170, 0.200, 0.055),
				Vector3(0.360, 0.220, 0.070), Vector3(0.560, 0.240, 0.052),
				Vector3(0.760, 0.230, 0.064), Vector3(0.940, 0.200, 0.056),
				# …plus the chimney silhouettes on top of that skyline.
				Vector3(0.095, 0.012, 0.150), Vector3(0.260, 0.010, 0.170),
				Vector3(0.620, 0.012, 0.142), Vector3(0.845, 0.010, 0.160),
			],
		},
		{
			"depth": 220.0,
			"color": Color(0.190, 0.138, 0.098),
			"pieces": [
				# Distant city: a quay band with a cluster of tower footprints.
				Vector3(0.50, 0.98, 0.018),
				Vector3(0.070, 0.030, 0.140), Vector3(0.115, 0.024, 0.180),
				Vector3(0.160, 0.032, 0.125), Vector3(0.235, 0.026, 0.155),
				Vector3(0.310, 0.036, 0.135), Vector3(0.395, 0.028, 0.190),
				Vector3(0.470, 0.022, 0.148), Vector3(0.535, 0.020, 0.205),
				Vector3(0.600, 0.034, 0.140), Vector3(0.675, 0.026, 0.170),
				Vector3(0.745, 0.032, 0.132), Vector3(0.820, 0.024, 0.182),
				Vector3(0.895, 0.030, 0.144), Vector3(0.965, 0.026, 0.160),
			],
		},
		{
			"depth": 240.0,
			"color": Color(0.300, 0.230, 0.170),
			"pieces": [
				# Mountain ridge: narrow overlapping peaks give a jagged profile.
				Vector3(0.010, 0.095, 0.170), Vector3(0.060, 0.080, 0.245),
				Vector3(0.105, 0.100, 0.140), Vector3(0.155, 0.075, 0.225),
				Vector3(0.200, 0.090, 0.165), Vector3(0.245, 0.080, 0.260),
				Vector3(0.290, 0.100, 0.150), Vector3(0.340, 0.075, 0.230),
				Vector3(0.385, 0.095, 0.200), Vector3(0.435, 0.080, 0.285),
				Vector3(0.480, 0.100, 0.165), Vector3(0.530, 0.075, 0.240),
				Vector3(0.575, 0.095, 0.185), Vector3(0.625, 0.080, 0.265),
				Vector3(0.670, 0.100, 0.155), Vector3(0.720, 0.075, 0.225),
				Vector3(0.765, 0.095, 0.200), Vector3(0.815, 0.080, 0.270),
				Vector3(0.860, 0.100, 0.165), Vector3(0.910, 0.075, 0.235),
				Vector3(0.955, 0.095, 0.180), Vector3(1.000, 0.080, 0.215),
			],
		},
	]
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var material := _make_vertex_color_unshaded()
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for layer_index in layer_specs.size():
		var layer: Dictionary = layer_specs[layer_index]
		var depth := float(layer["depth"])
		var layer_color: Color = layer["color"]
		var pieces: Array = layer["pieces"]
		for piece_index in pieces.size():
			var piece: Vector3 = pieces[piece_index]
			# Slightly staggered depths keep overlapping silhouettes from
			# z-fighting without changing the painted layer reading.
			var piece_depth := depth + float(piece_index) * 0.3
			transforms.append(_screen_frame_xform(
				piece.x, bottom - piece.z * 0.5, piece_depth, piece.y, piece.z
			))
			colors.append(layer_color)
	var bounds := AABB()
	var has_bounds := false
	for xform in transforms:
		var box := StageKit.transform_aabb(xform, unit_box.get_aabb())
		bounds = box if not has_bounds else bounds.merge(box)
		has_bounds = true
	_add_multimesh(
		_fallback_sky_root, unit_box, transforms, material, "PaintedBackdrop",
		bounds, colors
	)
	_painted_layer_count = layer_specs.size()


## Screen-fraction transform for a camera-facing quad/box: `u`/`v` are the
## frame centre (0..1) and `width`/`height` are fractions of the 16:9 frame at
## `depth` metres along the camera forward axis. Built from the fixed camera
## axes, so a stage camera never sees it from the side.
func _screen_frame_xform(u: float, v: float, depth: float, width: float, height: float) -> Transform3D:
	var tan_v := tan(deg_to_rad(CAMERA_FOV * 0.5))
	var tan_h := tan_v * (1440.0 / 900.0)
	var world_size := Vector3(
		width * 2.0 * depth * tan_h,
		height * 2.0 * depth * tan_v,
		1.2
	)
	var forward := (CAMERA_TARGET - CAMERA_POS).normalized()
	var zaxis := -forward
	var xaxis := Vector3.UP.cross(zaxis).normalized()
	var yaxis := zaxis.cross(xaxis)
	# Columns are the scaled screen axes, so the quad/box is exactly
	# camera-facing and its projected corners stay axis-aligned in the frame.
	var basis := Basis()
	basis.x = xaxis * world_size.x
	basis.y = yaxis * world_size.y
	basis.z = zaxis * world_size.z
	return Transform3D(basis, _screen_point(u, v, depth))


## Adds one procedural, camera-facing additive glow sprite (used for the sun).
func _add_sky_glow(parent: Node3D, position3d: Vector3, size: float, color: Color, alpha: float, node_name: String) -> MeshInstance3D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.60, 1.0])
	gradient.colors = PackedColorArray([
		Color(color.r, color.g, color.b, alpha),
		Color(color.r, color.g, color.b, alpha * 0.62),
		Color(color.r, color.g, color.b, alpha * 0.16),
		Color(color.r, color.g, color.b, 0.0),
	])
	# Fade the glow to zero well inside the quad: the texture only uses 72% of the
	# UV radius, so the quad's straight edges are always fully transparent.
	var texture := _gradient_texture_2d(gradient, 64, 64, GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.5), Vector2(0.86, 0.5))
	return _add_billboard_quad(parent, Vector2(size, size), position3d, texture, Color.WHITE, BaseMaterial3D.BLEND_MODE_ADD, node_name)


## L6 foreground frame: dark unshaded crane arm / cables entering from the
## top-left corner. Kept above u=0.24 and v=0.45 so it never covers facility
## signs, hotspot labels or the HUD-safe middle of the screen.
func _add_foreground_frame() -> void:
	_foreground_frame = Node3D.new()
	_foreground_frame.name = "ForegroundFrame"
	add_child(_foreground_frame)
	var material := _make_unshaded_fresh(Color(0.095, 0.078, 0.062))
	# Rim-light the silhouette a touch so it reads as warm iron, not black.
	material.emission_enabled = true
	material.emission = Color(0.17, 0.11, 0.06)
	material.emission_energy_multiplier = 0.45
	var arm_from := _screen_point(-0.10, -0.10, 18.0)
	var arm_to := _screen_point(0.115, 0.170, 15.0)
	_add_beam(_foreground_frame, arm_from, arm_to, 0.30, material, "CraneArm")
	# A thin steel cable hangs from the arm tip; no hook block (it would read as
	# a floating black square at this distance).
	_add_beam(
		_foreground_frame, arm_to, arm_to + Vector3(0.0, -1.0, 0.0), 0.12, material, "HookCable"
	)
	# Thin mast entering from the left edge only; keeps the frame read as a
	# corner silhouette instead of an X across the sky.
	var mast_from := _screen_point(-0.045, -0.05, 20.0)
	var mast_to := _screen_point(-0.015, 0.40, 18.0)
	_add_beam(_foreground_frame, mast_from, mast_to, 0.18, material, "Mast")


## L7 atmosphere: two small smoke/steam particle systems (ship funnel + quay
## vent). Both stop updating with the stage when the host disables processing.
func _add_atmosphere() -> void:
	_atmosphere_root = Node3D.new()
	_atmosphere_root.name = "Atmosphere"
	add_child(_atmosphere_root)
	_add_particle_system(
		_atmosphere_root, Vector3(-16.0, 12.0, 4.0), 22, 4.2, 2.2,
		Color(0.82, 0.78, 0.70, 0.40), 1.1, 2.0, "ShipSteam"
	)
	_add_particle_system(
		_atmosphere_root, Vector3(22.0, 4.2, -2.0), 16, 3.4, 1.3,
		Color(0.80, 0.76, 0.68, 0.34), 0.7, 1.4, "QuaySteam"
	)
	_add_particle_system(
		_atmosphere_root, Vector3(-24.0, 9.0, -34.0), 18, 4.6, 2.5,
		Color(0.82, 0.78, 0.70, 0.36), 0.9, 1.7, "ShoreSteam"
	)
	_shore_steam = _atmosphere_root.get_node_or_null("ShoreSteam") as GPUParticles3D
	_ship_steam = _atmosphere_root.get_node_or_null("ShipSteam") as GPUParticles3D
	_particle_count = 3


func _add_particle_system(
	parent: Node3D,
	position3d: Vector3,
	amount: int,
	lifetime: float,
	size: float,
	color: Color,
	velocity_min: float,
	velocity_max: float,
	node_name: String
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.position = position3d
	particles.visibility_aabb = AABB(Vector3(-20.0, -6.0, -20.0), Vector3(40.0, 40.0, 40.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 10.0
	process.initial_velocity_min = velocity_min
	process.initial_velocity_max = velocity_max
	process.gravity = Vector3(0.18, 0.35, 0.0)
	process.scale_min = 0.9
	process.scale_max = 1.7
	process.color = Color(color.r, color.g, color.b, 1.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.86, 0.82, 0.74, 0.0),
		Color(0.84, 0.80, 0.72, color.a),
		Color(0.72, 0.68, 0.60, 0.0),
	])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	particles.process_material = process
	var puff_gradient := Gradient.new()
	puff_gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	puff_gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.55), Color(1.0, 1.0, 1.0, 0.0),
	])
	var puff_texture := _gradient_texture_2d(puff_gradient, 64, 64, GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
	var draw_mesh := QuadMesh.new()
	draw_mesh.size = Vector2(size, size)
	var draw_material := StandardMaterial3D.new()
	draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_material.vertex_color_use_as_albedo = true
	draw_material.albedo_texture = puff_texture
	draw_material.albedo_color = Color.WHITE
	draw_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw_material.disable_receive_shadows = true
	draw_mesh.material = draw_material
	particles.draw_pass_1 = draw_mesh
	parent.add_child(particles)
	return particles


## Converts a normalised screen position (0..1) at `depth` metres along the
## camera forward axis into a world point. Used to pin the fallback sky glow and
## the foreground frame to the fixed 16:9 framing without hardcoding numbers.
func _screen_point(u: float, v: float, depth: float) -> Vector3:
	var forward := (CAMERA_TARGET - CAMERA_POS).normalized()
	var zaxis := -forward
	var xaxis := Vector3.UP.cross(zaxis).normalized()
	var yaxis := zaxis.cross(xaxis)
	var tan_v := tan(deg_to_rad(CAMERA_FOV * 0.5))
	var tan_h := tan_v * (1440.0 / 900.0)
	var offset_x := (u - 0.5) * 2.0 * depth * tan_h
	var offset_y := (0.5 - v) * 2.0 * depth * tan_v
	return CAMERA_POS + forward * depth + xaxis * offset_x + yaxis * offset_y


## World-space size that occupies `screen_fraction` of the frame width at
## `depth` metres — keeps foreground frame pieces visually consistent.
func _screen_units(screen_fraction: float, depth: float) -> float:
	var tan_v := tan(deg_to_rad(CAMERA_FOV * 0.5))
	var tan_h := tan_v * (1440.0 / 900.0)
	return screen_fraction * 2.0 * depth * tan_h


func _add_quay() -> void:
	# Dark shore shelf behind the quay: the silhouette row stands on solid
	# ground and the quay reads as one shore instead of a floating box.
	var shore_material := StandardMaterial3D.new()
	shore_material.resource_name = "Port_Shore"
	shore_material.albedo_color = Color(0.125, 0.117, 0.105)
	shore_material.roughness = 0.95
	shore_material.metallic = 0.0
	_shore_shelf = _add_box(self, SHORE_SIZE, SHORE_CENTER, shore_material, Vector3.ZERO, "ShoreShelf")
	# Repeated small props are batched through MultiMesh: one draw call per
	# material/mesh pair instead of dozens of individual MeshInstance3D nodes.
	var box_unit := BoxMesh.new()
	box_unit.size = Vector3.ONE
	var stone_xforms: Array[Transform3D] = [_scaled_xform(DOCK_CENTER, DOCK_SIZE)]
	_add_multimesh(self, box_unit, stone_xforms, _material("stone"), "DockPlatform", AABB(Vector3(-30.0, -2.0, -16.0), Vector3(60.0, 6.0, 18.0)))
	var deck_xforms: Array[Transform3D] = [_scaled_xform(Vector3(0.0, 2.15, -6.0), DECK_SIZE)]
	_add_multimesh(self, box_unit, deck_xforms, _material("deck"), "DockDeck", AABB(Vector3(-30.0, 1.0, -14.0), Vector3(60.0, 3.0, 16.0)))
	var wood_xforms: Array[Transform3D] = []
	wood_xforms.append(_scaled_xform(Vector3(0.0, 1.66, -0.2), Vector3(160.0, 0.3, 0.34)))
	wood_xforms.append(_scaled_xform(Vector3(0.0, 1.32, 0.5), Vector3(160.0, 0.35, 0.35)))
	for x in [-72.0, -48.0, -24.0, 0.0, 24.0, 48.0, 72.0]:
		wood_xforms.append(_scaled_xform(Vector3(x, 1.9, -0.15), Vector3(0.6, 0.6, 0.35)))
	for x in [-78.0, -66.0, -54.0, -42.0, -30.0, -18.0, -6.0, 6.0, 18.0, 30.0, 42.0, 54.0, 66.0, 78.0]:
		wood_xforms.append(_scaled_xform(Vector3(x, 1.5, 0.55), Vector3(0.8, 0.5, 0.8)))
	_add_multimesh(self, box_unit, wood_xforms, _material("wood_dark"), "DockWood", AABB(Vector3(-80.0, -1.0, -2.0), Vector3(160.0, 5.0, 6.0)))
	var pile_mesh := CylinderMesh.new()
	pile_mesh.top_radius = 0.88
	pile_mesh.bottom_radius = 1.0
	pile_mesh.height = 1.0
	pile_mesh.radial_segments = 10
	var pile_xforms: Array[Transform3D] = []
	for index in range(-9, 10):
		pile_xforms.append(_scaled_xform(Vector3(float(index) * 8.0, 0.4, 0.55), Vector3(0.34, 3.6, 0.34)))
	_add_multimesh(self, pile_mesh, pile_xforms, _material("wood_dark"), "DockPiles", AABB(Vector3(-80.0, -2.0, -2.0), Vector3(160.0, 6.0, 6.0)))
	var bollard_mesh := CylinderMesh.new()
	bollard_mesh.top_radius = 0.26
	bollard_mesh.bottom_radius = 0.30
	bollard_mesh.height = 0.7
	bollard_mesh.radial_segments = 12
	var bollard_cap_mesh := CylinderMesh.new()
	bollard_cap_mesh.top_radius = 0.34
	bollard_cap_mesh.bottom_radius = 0.34
	bollard_cap_mesh.height = 0.14
	bollard_cap_mesh.radial_segments = 12
	var bollard_bodies: Array[Transform3D] = []
	var bollard_caps: Array[Transform3D] = []
	for index in range(-6, 7):
		var x := float(index) * 12.0
		bollard_bodies.append(_xform(Vector3(x, DOCK_TOP + 0.35, -1.1)))
		bollard_caps.append(_xform(Vector3(x, DOCK_TOP + 0.77, -1.1)))
	_add_multimesh(self, bollard_mesh, bollard_bodies, _material("metal"), "Bollards", AABB(Vector3(-76.0, 1.5, -2.0), Vector3(152.0, 2.0, 2.0)))
	_add_multimesh(self, bollard_cap_mesh, bollard_caps, _material("iron"), "BollardCaps", AABB(Vector3(-76.0, 2.0, -2.0), Vector3(152.0, 2.0, 2.0)))
	# Gas lamps along the quay front.
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 4.2
	pole_mesh.radial_segments = 8
	var pole_xforms: Array[Transform3D] = []
	var glow_xforms: Array[Transform3D] = []
	var lamp_cap_xforms: Array[Transform3D] = []
	for x in [-66.0, -42.0, -18.0, 6.0, 30.0, 54.0, 78.0]:
		pole_xforms.append(_xform(Vector3(x, DOCK_TOP + 2.1, -1.7)))
		glow_xforms.append(_scaled_xform(Vector3(x, DOCK_TOP + 4.55, -1.7), Vector3(0.42, 0.46, 0.42)))
		lamp_cap_xforms.append(_scaled_xform(Vector3(x, DOCK_TOP + 4.83, -1.7), Vector3(0.56, 0.1, 0.56)))
	_add_multimesh(self, pole_mesh, pole_xforms, _material("iron"), "LampPoles", AABB(Vector3(-76.0, 1.0, -2.0), Vector3(152.0, 6.0, 2.0)))
	_add_multimesh(self, box_unit, glow_xforms, _make_unshaded(Color(1.0, 0.68, 0.36), 1.6), "LampGlow", AABB(Vector3(-76.0, 4.0, -2.0), Vector3(152.0, 4.0, 2.0)))
	_add_multimesh(self, box_unit, lamp_cap_xforms, _material("iron"), "LampCaps", AABB(Vector3(-76.0, 4.0, -2.0), Vector3(152.0, 4.0, 2.0)))


func _add_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "StageCamera"
	_camera.fov = CAMERA_FOV
	_camera.near = 0.5
	_camera.far = 1200.0
	add_child(_camera)
	# The first shot is the station requested before the stage was built (the
	# shell points the stage at the page it is showing); the harbour reference
	# shot is the fallback.
	var pose := station_camera_pose(_station, _station_framing)
	_camera.position = pose["position"]
	_camera_target = pose["target"]
	_camera_from = _camera.position
	_camera_from_target = _camera_target
	_camera_from_fov = float(pose["fov"])
	_camera_to = _camera.position
	_camera_to_target = _camera_target
	_camera_to_fov = CAMERA_FOV
	_camera_t = 1.0
	_camera.current = true
	_camera.look_at(_camera_target, Vector3.UP)
	_apply_camera_shift()


# --- Dynamic rebuild (bind) -------------------------------------------------

func _has_stage_data(data: Dictionary) -> bool:
	return data.has("port") or data.has("ship") or data.has("facility_visuals") or data.has("town_visuals")


func _apply_view_model(port: Dictionary, ship: Dictionary, root_data: Dictionary) -> void:
	_port = port.duplicate(true)
	_size = String(_port.get("size", "medium")).to_lower()
	if not SIZE_SCALE.has(_size):
		_size = "medium"
	_scale = float(SIZE_SCALE.get(_size, 1.0))
	var palette_value: Variant = _port.get("palette", {})
	_palette = palette_value if palette_value is Dictionary else {}
	var visuals_value: Variant = _port.get("facility_visuals", null)
	if not (visuals_value is Dictionary):
		visuals_value = root_data.get("facility_visuals", {})
	_visuals = visuals_value if visuals_value is Dictionary else {}
	var town_value: Variant = _port.get("town_visuals", null)
	if not (town_value is Dictionary):
		town_value = root_data.get("town_visuals", {})
	_banner_path = String(_port.get("banner_path", ""))
	_apply_palette()
	_clear_dynamic()
	_town_visuals = town_value if town_value is Dictionary else {}
	_facilities_root = Node3D.new()
	_facilities_root.name = "Facilities"
	_facilities_root.position = Vector3(0.0, DOCK_TOP, 0.0)
	_facilities_root.scale = Vector3.ONE * _scale
	_content.add_child(_facilities_root)
	_rebuild_backdrop()
	# L2 silhouettes are the no-backdrop fallback only: a painted skyline plus
	# black boxes on top of it reads as floating rectangles. A mounted town kit
	# already provides the near skyline, so the procedural row is skipped there
	# as well (otherwise its bases get buried by the raised plaza).
	if _town_visuals.is_empty():
		_rebuild_shoreline()
	_apply_fallback_visibility()
	_rebuild_fog_layers()
	_rebuild_town()
	_rebuild_facilities()
	_rebuild_landmark()
	# Fold the freshly built static layers into draw batches before the player
	# ship is mounted (the ship bobs and is deliberately not batched).
	_batch_static_meshes()
	_rebuild_ship(ship)
	# The rebuilt camera-facing layers (banner / sky card / painted layers) start
	# at the reference framing; reapply the current station shift so a bind never
	# lands the backdrop back on the harbour shot.
	_apply_camera_shift()


func _clear_dynamic() -> void:
	_facilities.clear()
	_facilities_present.clear()
	_anchors.clear()
	_kinds.clear()
	_filler_count = 0
	_backdrop = null
	_skyline_root = null
	_ship_steam = null
	_has_backdrop = false
	_loaded_banner_path = ""
	_landmark = null
	_ship_root = null
	_facilities_root = null
	_town_root = null
	_town_prop_count = 0
	_town_blockout_count = 0
	_station_prop_count = 0
	_town_density = _resolve_town_density()
	_batch_batches = 0
	_batch_multimesh_batches = 0
	_batch_material_batches = 0
	_batch_meshes_before = 0
	_batch_meshes_after = 0
	_batch_surfaces_before = 0
	_batch_surfaces_after = 0
	_ship_batches = 0
	_ship_multimesh_batches = 0
	_ship_material_batches = 0
	_ship_meshes_before = 0
	_ship_meshes_after = 0
	_ship_surfaces_before = 0
	_ship_surfaces_after = 0
	_ship_fallback = false
	_ship_bounds = AABB()
	_fog_nodes.clear()
	_fog_bases.clear()
	_fog_phases.clear()
	_fog_layer_count = 0
	_skyline_building_count = 0
	_skyline_crane_count = 0
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.free()


func _apply_palette() -> void:
	for key in MATERIAL_DEFAULTS.keys():
		var material := _material(String(key))
		if material != null:
			material.albedo_color = _palette_color(String(key), material.albedo_color)


func _palette_color(key: String, fallback: Color) -> Color:
	var value: Variant = _palette.get(key, null)
	if value is Color:
		return value
	if value is String:
		return Color(String(value))
	return fallback


func _sign_color(facility: String) -> Color:
	var fallback: Color = SIGN_COLORS.get(facility, Color(0.9, 0.7, 0.35))
	var value: Variant = _palette.get(facility, null)
	if value is Color:
		return value
	if value is String:
		return Color(String(value))
	return fallback


## Deterministic 0..1 value from the port id hash (no RandomNumberGenerator, so
## the same port always gets the same shoreline).
func _hash01(seed_value: int, index: int, salt: int) -> float:
	var value := seed_value ^ (index * 374761393) ^ (salt * 668265263)
	value = (value ^ (value >> 13)) * 1274126177
	value = value ^ (value >> 16)
	return float(value & 0xFFFFFF) / 16777215.0


func _make_unshaded(color: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	# Cached by exact colour+emission: lamp glows, sign faces and notice papers
	# are re-created per facility, and sharing the material is what lets the
	# static batcher fold them into one draw.
	var key := "%s|%.3f" % [color.to_html(), emission_energy]
	if _unshaded_materials.has(key):
		return _unshaded_materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_unshaded_materials[key] = material
	return material


## Fresh unshaded material that multiplies per-instance / per-vertex colour.
## Deliberately uncached: callers mutate `vertex_color_use_as_albedo` and the
## shared cache above must stay untouched.
func _make_vertex_color_unshaded() -> StandardMaterial3D:
	var material := _make_unshaded_fresh(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.disable_receive_shadows = true
	return material


## Fresh (uncached) unshaded material for callers that customise it afterwards
## (e.g. the rim-lit L6 foreground frame) without leaking into the shared cache.
func _make_unshaded_fresh(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# --- L2 shoreline silhouettes ----------------------------------------------

## Fallback layers only exist when there is no painted L1 backdrop: the shore
## shelf and silhouette row would cover the banner's lower half, and the fallback
## sky would sit in front of it. With a banner the pier stands directly against
## the painted city/water, which is the intended "L1 backdrop first" reading.
func _apply_fallback_visibility() -> void:
	var use_fallback := not _has_backdrop
	if _fallback_sky_root != null:
		_fallback_sky_root.visible = use_fallback
	if _shore_shelf != null:
		_shore_shelf.visible = use_fallback
	# The shore chimney only exists without a painted banner, so its steam plume
	# is hidden together with the L2 silhouette row.
	if _shore_steam != null:
		_shore_steam.visible = use_fallback
		_shore_steam.emitting = use_fallback


## Deterministic two-depth silhouette bands (only when no banner is mounted).
## Counts follow `port.size`; the near band is dark blue-grey and the far band is
## warmer/mistier, so the skyline reads in layers instead of a black wall. Both
## bands are batched into three MultiMeshes (box silhouettes, lighthouse towers,
## lighthouse caps), so the whole L2 skyline costs 3 draw calls.
func _rebuild_shoreline() -> void:
	_skyline_building_count = 0
	_skyline_crane_count = 0
	if _has_backdrop:
		return
	var total_buildings := int(SKYLINE_BUILDINGS_BY_SIZE.get(_size, 10))
	var total_cranes := int(SKYLINE_CRANES_BY_SIZE.get(_size, 2))
	var near_count := int(round(float(total_buildings) * 0.55))
	var far_count := total_buildings - near_count
	var shoreline := Node3D.new()
	shoreline.name = "Shoreline"
	_content.add_child(shoreline)
	_skyline_root = shoreline
	var seed_value := String(_port.get("id", "port")).hash()
	var box_xforms: Array[Transform3D] = []
	var box_colors: Array[Color] = []
	var tower_xforms: Array[Transform3D] = []
	var tower_colors: Array[Color] = []
	var cap_xforms: Array[Transform3D] = []
	var cap_colors: Array[Color] = []
	# Near band: deep blue-grey, small warehouses close to the quay.
	var near_tone := Color(0.068, 0.082, 0.100)
	var near_roof := Color(0.052, 0.064, 0.080)
	# Far band: warm mist colour, low contrast against the dusk sky and haze.
	var far_tone := Color(0.235, 0.210, 0.185)
	var far_roof := Color(0.195, 0.174, 0.153)
	var lighthouse_tone := Color(0.160, 0.148, 0.134)
	# Two small clusters per band plus a low warehouse row, so the building budget
	# reads as a working shore instead of isolated boxes spread over empty ground.
	var near_centers := [-16.0, 13.0]
	for index in near_count:
		var r1 := _hash01(seed_value, index, 101)
		var r2 := _hash01(seed_value, index, 103)
		var r3 := _hash01(seed_value, index, 107)
		var r4 := _hash01(seed_value, index, 109)
		var width := 2.4 + r1 * 2.0
		var height := 3.0 + r2 * 4.0
		var depth := 2.2 + r3 * 1.6
		var cluster := index % 2
		var slot := int(index / 2)
		var x := float(near_centers[cluster]) + (float(slot) - 0.5) * 3.4 + (r2 - 0.5) * 1.2
		var z := -24.0 - float(slot) * 2.6 - r3 * 2.4
		if index == 2:
			_add_lighthouse_silhouette(
				Vector3(x, SHORE_TOP, z), 0.8, lighthouse_tone,
				box_xforms, box_colors, tower_xforms, tower_colors, cap_xforms, cap_colors
			)
		else:
			_append_skyline_box(box_xforms, box_colors, Vector3(x, SHORE_TOP + height * 0.5, z), Vector3(width, height, depth), near_tone)
			_append_skyline_roof(box_xforms, box_colors, Vector3(x, SHORE_TOP + height, z), width, depth, near_roof, r4)
			if r4 > 0.62:
				_append_skyline_box(
					box_xforms, box_colors,
					Vector3(x + width * 0.24, SHORE_TOP + height + 0.7, z - 0.3),
					Vector3(0.55, 1.2 + r1 * 1.6, 0.55), near_roof
				)
		_skyline_building_count += 1
	# Low continuous warehouse row linking the near clusters along the shore.
	_append_skyline_box(box_xforms, box_colors, Vector3(-2.0, SHORE_TOP + 0.8, -29.0), Vector3(21.0, 1.6, 3.0), Color(0.085, 0.098, 0.115))
	_append_skyline_box(box_xforms, box_colors, Vector3(-38.0, SHORE_TOP + 0.8, -31.0), Vector3(18.0, 1.6, 3.0), Color(0.085, 0.098, 0.115))
	# Far band: warmer, mistier, two clusters further back.
	var far_centers := [-20.0, 17.0]
	for index in far_count:
		var r1 := _hash01(seed_value, index, 211)
		var r2 := _hash01(seed_value, index, 223)
		var r3 := _hash01(seed_value, index, 227)
		var r4 := _hash01(seed_value, index, 229)
		var width := 2.6 + r1 * 2.4
		var height := 3.5 + r2 * 5.5
		var depth := 2.4 + r3 * 1.8
		var cluster := index % 2
		var slot := int(index / 2)
		var x := float(far_centers[cluster]) + (float(slot) - 0.5) * 3.8 + (r2 - 0.5) * 1.4
		var z := -38.0 - float(slot) * 3.0 - r3 * 4.0
		if far_count > 1 and index == 1:
			_add_lighthouse_silhouette(
				Vector3(x, SHORE_TOP, z), 0.7, far_roof,
				box_xforms, box_colors, tower_xforms, tower_colors, cap_xforms, cap_colors
			)
		else:
			_append_skyline_box(box_xforms, box_colors, Vector3(x, SHORE_TOP + height * 0.5, z), Vector3(width, height, depth), far_tone)
			_append_skyline_roof(box_xforms, box_colors, Vector3(x, SHORE_TOP + height, z), width, depth, far_roof, r4)
			if r4 > 0.74:
				_append_skyline_box(
					box_xforms, box_colors,
					Vector3(x - width * 0.22, SHORE_TOP + height + 0.9, z),
					Vector3(0.6, 1.8 + r1 * 2.0, 0.6), far_roof
				)
		_skyline_building_count += 1
	# Far low mist bank (long, hazy boxes) right before the fallback sky card:
	# breaks the shelf edge into a soft "shore -> bank -> sky" transition. Large
	# ports carry one fewer bank box so the L2 instance total stays <= 20.
	var bank_tone := Color(0.320, 0.294, 0.260)
	var bank_centers := [-48.0, -6.0, 42.0]
	var bank_count := 2 if _size == "large" else 3
	for index in bank_count:
		var r1 := _hash01(seed_value, index, 311)
		var r2 := _hash01(seed_value, index, 313)
		var bank_width := 30.0 + r1 * 14.0
		var bank_height := 1.2 + r2 * 1.4
		_append_skyline_box(
			box_xforms, box_colors,
			Vector3(float(bank_centers[index]) + (r2 - 0.5) * 5.0, SHORE_TOP + bank_height * 0.5, -51.0 - r1 * 3.0),
			Vector3(bank_width, bank_height, 7.0), bank_tone
		)
	# Cranes sit at the cluster edges; silhouettes only, no lights.
	for index in total_cranes:
		var cx := -8.0 + float(index) * 22.0 + _hash01(seed_value, index, 251) * 4.0
		var cz := -30.0 - _hash01(seed_value, index, 257) * 6.0
		var base := Vector3(cx, SHORE_TOP, cz)
		var tone := near_roof if index % 2 else far_roof
		_append_skyline_box(box_xforms, box_colors, base + Vector3(0.0, 3.7, 0.0), Vector3(0.55, 7.4, 0.55), tone)
		_append_skyline_box(box_xforms, box_colors, base + Vector3(2.5, 7.1, 0.0), Vector3(6.4, 0.5, 0.5), tone)
		_append_skyline_box(box_xforms, box_colors, base + Vector3(4.6, 5.5, 0.0), Vector3(0.14, 2.7, 0.14), tone)
		_skyline_crane_count += 1
	var silhouette_material := _make_vertex_color_unshaded()
	var box_unit := BoxMesh.new()
	box_unit.size = Vector3.ONE
	_add_multimesh(
		shoreline, box_unit, box_xforms, silhouette_material, "SkylineBoxes",
		AABB(Vector3(-42.0, -1.0, -50.0), Vector3(84.0, 20.0, 36.0)), box_colors
	)
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 0.66
	tower_mesh.bottom_radius = 1.0
	tower_mesh.height = 1.0
	tower_mesh.radial_segments = 8
	_add_multimesh(
		shoreline, tower_mesh, tower_xforms, silhouette_material, "SkylineLighthouseBodies",
		AABB(Vector3(-40.0, -1.0, -50.0), Vector3(80.0, 20.0, 30.0)), tower_colors
	)
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.0
	cap_mesh.bottom_radius = 1.0
	cap_mesh.height = 1.0
	cap_mesh.radial_segments = 8
	_add_multimesh(
		shoreline, cap_mesh, cap_xforms, silhouette_material, "SkylineLighthouseCaps",
		AABB(Vector3(-40.0, -1.0, -50.0), Vector3(80.0, 20.0, 30.0)), cap_colors
	)


## Low deterministic fog billboards (L7). Their phase comes from the port id hash
## so every harbour drifts differently, while the motion stays a pure sine wave.
func _rebuild_fog_layers() -> void:
	var fog_root := Node3D.new()
	fog_root.name = "FogBands"
	_content.add_child(fog_root)
	var port_id := String(_port.get("id", "port"))
	var seed_value := port_id.hash()
	var configs := [
		{"u": 0.50, "v": 0.76, "depth": 46.0, "size": Vector2(56.0, 8.0), "color": Color(FOG_BAND_COLOR.r, FOG_BAND_COLOR.g, FOG_BAND_COLOR.b, FOG_BAND_ALPHA)},
		{"u": 0.72, "v": 0.86, "depth": 36.0, "size": Vector2(44.0, 7.0), "color": Color(FOG_BAND_COLOR.r, FOG_BAND_COLOR.g, FOG_BAND_COLOR.b, FOG_BAND_ALPHA)},
	]
	if not _has_backdrop:
		# Horizon haze between the far silhouette row and the fallback sky card:
		# a soft radial alpha band so the sky/land boundary never becomes a hard
		# straight line. With a real banner the painted backdrop has its own haze.
		configs.append({
			"u": 0.50, "v": 0.44, "depth": 135.0, "size": Vector2(320.0, 80.0),
			"color": Color(0.92, 0.70, 0.47, 0.17),
		})
	for index in configs.size():
		var config: Dictionary = configs[index]
		# Radial alpha gradient stretched into a band: every edge fades out.
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 0.80, 1.0])
		gradient.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.65),
			Color(1.0, 1.0, 1.0, 0.18), Color(1.0, 1.0, 1.0, 0.0),
		])
		var texture := _gradient_texture_2d(gradient, 64, 64, GradientTexture2D.FILL_RADIAL, Vector2(0.5, 0.5), Vector2(1.0, 0.5))
		var position3d := _screen_point(float(config["u"]), float(config["v"]), float(config["depth"]))
		var band := _add_billboard_quad(fog_root, config["size"], position3d, texture, config["color"], BaseMaterial3D.BLEND_MODE_MIX, "FogBand_%d" % index)
		_fog_nodes.append(band)
		_fog_bases.append(position3d)
		_fog_phases.append(_hash01(seed_value, index, 71) * TAU)
		_fog_layer_count += 1


## Appends one scaled box instance for the batched silhouette MultiMesh.
func _append_skyline_box(
	transforms: Array[Transform3D], colors: Array[Color], center: Vector3, size: Vector3, color: Color,
	rotation_degrees: Vector3 = Vector3.ZERO
) -> void:
	transforms.append(_scaled_xform(center, size, rotation_degrees))
	colors.append(color)


## Pitched roof / flat parapet as silhouette instances: a 45° box reads as a
## gable from the fixed camera without extra geometry.
func _append_skyline_roof(
	transforms: Array[Transform3D], colors: Array[Color], base: Vector3, width: float, depth: float,
	color: Color, roll: float
) -> void:
	if roll < 0.35:
		_append_skyline_box(transforms, colors, base + Vector3(0.0, 0.28, 0.0), Vector3(width * 0.9, 0.55, depth * 0.92), color)
		return
	var roof_size := width * 0.78
	_append_skyline_box(
		transforms, colors, base + Vector3(0.0, roof_size * 0.30, 0.0),
		Vector3(roof_size, roof_size, depth * 0.92), color, Vector3(0.0, 0.0, 45.0)
	)


## Lighthouse silhouette: tapered tower + lantern room box + cone cap, all
## appended to the batched MultiMesh arrays.
func _add_lighthouse_silhouette(
	base: Vector3, scale_factor: float, color: Color,
	box_xforms: Array[Transform3D], box_colors: Array[Color],
	tower_xforms: Array[Transform3D], tower_colors: Array[Color],
	cap_xforms: Array[Transform3D], cap_colors: Array[Color]
) -> void:
	var body_height := 5.4 * scale_factor
	var body_radius := 0.8 * scale_factor
	tower_xforms.append(_scaled_xform(base + Vector3(0.0, body_height * 0.5, 0.0), Vector3(body_radius, body_height, body_radius)))
	tower_colors.append(color)
	_append_skyline_box(
		box_xforms, box_colors, base + Vector3(0.0, body_height + 0.35 * scale_factor, 0.0),
		Vector3(0.9 * scale_factor, 0.7 * scale_factor, 0.9 * scale_factor), color
	)
	cap_xforms.append(_scaled_xform(
		base + Vector3(0.0, body_height + 0.7 * scale_factor + 0.55 * scale_factor, 0.0),
		Vector3(1.05 * scale_factor, 1.1 * scale_factor, 1.05 * scale_factor)
	))
	cap_colors.append(color)


# --- L1 backdrop ------------------------------------------------------------

func _rebuild_backdrop() -> void:
	_banner_path = String(_port.get("banner_path", ""))
	var texture: Texture2D = null
	if not _banner_path.is_empty():
		texture = _load_texture(_banner_path)
	if texture == null:
		# Deliberately no black box: keep sky + fog + L2 silhouettes/shore instead.
		return
	var material := StandardMaterial3D.new()
	material.resource_name = "Port_Backdrop"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = texture
	# Tint the painted skyline into the same dusk grade as the 3D foreground so
	# it does not read as a bright sticker.
	material.albedo_color = Color(0.72, 0.68, 0.64)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = BACKDROP_SIZE
	var backdrop := MeshInstance3D.new()
	backdrop.name = "Backdrop"
	backdrop.mesh = quad
	backdrop.material_override = material
	backdrop.position = BACKDROP_POSITION
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_content.add_child(backdrop)
	_backdrop = backdrop
	_has_backdrop = true
	_loaded_banner_path = _banner_path
	_apply_camera_shift()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		if resource is Texture2D:
			return resource as Texture2D
	return ContentAssetLoader.load_texture(path)


# --- L3 facilities ----------------------------------------------------------

func _rebuild_facilities() -> void:
	var raw: Variant = _port.get("facilities", [])
	var present: Array = []
	if raw is Array:
		for item in raw:
			var facility := String(item)
			if FACILITY_ORDER.has(facility) and not present.has(facility):
				present.append(facility)
	for facility in FACILITY_ORDER:
		var slot: Vector3 = SLOT_POSITIONS[facility]
		if present.has(facility):
			_facilities.append(facility)
			_facilities_present[facility] = true
			var anchor := Node3D.new()
			anchor.name = "Facility_" + String(facility)
			anchor.position = slot
			_facilities_root.add_child(anchor)
			_anchors[facility] = anchor
			_kinds[facility] = _build_facility_visual(String(facility), anchor)
		else:
			var filler := Node3D.new()
			filler.name = "Filler_" + String(facility)
			filler.position = slot
			_facilities_root.add_child(filler)
			_build_filler(String(facility), filler)
			_filler_count += 1


func _build_facility_visual(facility: String, anchor: Node3D) -> String:
	var paths := _facility_visual_paths(facility)
	if not paths.is_empty():
		var built := 0
		for index in paths.size():
			var visual := _instantiate_visual(paths[index])
			if visual == null:
				continue
			if facility == "shipyard" and index < SHIPYARD_PIECE_OFFSETS.size():
				visual.position += SHIPYARD_PIECE_OFFSETS[index]
			anchor.add_child(visual)
			built += 1
		if built > 0:
			return "model"
	_build_facility_billboard(facility, anchor)
	return "billboard"


func _facility_visual_paths(facility: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = _visuals.get(facility, null)
	if raw is String and not String(raw).is_empty():
		result.append(String(raw))
	elif raw is Array:
		for item in raw:
			if item is String and not String(item).is_empty():
				result.append(String(item))
	return result


func _instantiate_visual(path: String) -> Node3D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		if packed != null:
			var instance := packed.instantiate()
			if instance is Node3D:
				return instance as Node3D
			if instance != null:
				instance.free()
			return null
	return ContentAssetLoader.instantiate_model(path)


func _build_facility_billboard(facility: String, anchor: Node3D) -> void:
	match facility:
		"exchange":
			_billboard_exchange(anchor)
		"contracts":
			_billboard_contracts(anchor)
		"supply":
			_billboard_supply(anchor)
		"intel":
			_billboard_intel(anchor)
		"shipyard":
			_billboard_shipyard(anchor)
		_:
			_add_box(anchor, Vector3(2.0, 2.0, 2.0), Vector3(0.0, 1.0, 0.0), _material("wood"), Vector3.ZERO, "Anchor")


## Market stall: counter + canopy + warm amber sign.
func _billboard_exchange(root: Node3D) -> void:
	var wood := _material("wood")
	var dark := _material("wood_dark")
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(0.18, 2.5, 0.18), Vector3(side * 2.05, 1.25, -1.0), wood, Vector3.ZERO, "")
	_add_box(root, Vector3(4.4, 0.9, 1.1), Vector3(0.0, 0.45, 0.4), dark, Vector3.ZERO, "Counter")
	_add_box(root, Vector3(4.5, 0.12, 1.3), Vector3(0.0, 0.96, 0.4), wood, Vector3.ZERO, "CounterTop")
	_add_box(root, Vector3(4.8, 0.16, 2.8), Vector3(0.0, 2.62, -0.1), _material("canvas"), Vector3(-9.0, 0.0, 0.0), "Canopy")
	_add_box(root, Vector3(4.9, 0.1, 0.28), Vector3(0.0, 2.5, 1.24), dark, Vector3(-9.0, 0.0, 0.0), "")
	_add_sign(root, _sign_color("exchange"), Vector2(3.5, 1.0), Vector3(0.0, 3.15, 1.42))
	_add_crate(root, Vector3(-1.7, 0.0, 1.9), 0.9)
	_add_crate(root, Vector3(1.6, 0.0, 2.0), 0.75)
	_add_barrel(root, Vector3(2.2, 0.0, 1.1))


## Notice board: two posts, a paper-covered board and a brass sign.
func _billboard_contracts(root: Node3D) -> void:
	var dark := _material("wood_dark")
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(0.2, 2.65, 0.2), Vector3(side * 1.12, 1.32, 0.0), dark, Vector3.ZERO, "")
	_add_box(root, Vector3(2.7, 1.7, 0.16), Vector3(0.0, 1.8, 0.0), dark, Vector3.ZERO, "NoticeBoard")
	var paper := _make_unshaded(Color(0.80, 0.76, 0.62))
	for index in 3:
		_add_box(root, Vector3(0.48, 0.62, 0.03), Vector3(-0.8 + float(index) * 0.8, 1.85, 0.10), paper, Vector3(0.0, 0.0, 3.0 + float(index) * 4.0), "")
	_add_box(root, Vector3(2.95, 0.16, 0.55), Vector3(0.0, 2.72, 0.0), _material("wood"), Vector3.ZERO, "BoardCap")
	_add_sign(root, _sign_color("contracts"), Vector2(2.7, 0.8), Vector3(0.0, 3.05, 0.2))
	_add_lamp_post(root, Vector3(1.85, 0.0, 0.25))


## Water tank: riveted tank, conical roof, outlet pipe and a teal sign.
func _billboard_supply(root: Node3D) -> void:
	_add_box(root, Vector3(4.5, 0.35, 4.5), Vector3(0.0, 0.18, 0.0), _material("stone"), Vector3.ZERO, "TankBase")
	_add_cylinder(root, 1.95, 1.95, 3.3, Vector3(0.0, 1.95, 0.0), _material("metal"), "Tank")
	_add_cylinder(root, 0.0, 2.15, 1.15, Vector3(0.0, 4.16, 0.0), _material("iron"), "TankRoof")
	for side in [-1.0, 1.0]:
		_add_cylinder(root, 0.09, 0.09, 3.0, Vector3(side * 1.55, 1.6, 1.55), _material("iron"), "Leg")
	_add_cylinder(root, 0.16, 0.16, 1.9, Vector3(-1.55, 1.2, 1.55), _material("brass"), "Pipe")
	_add_sign(root, _sign_color("supply"), Vector2(2.5, 0.9), Vector3(0.0, 2.5, 2.05))
	_add_crate(root, Vector3(-3.2, 0.0, 1.3), 0.8)
	_add_crate(root, Vector3(3.1, 0.0, 1.6), 0.95)


## Signal tower: thin tall tower, crossarm, aerial and a cool blue sign.
func _billboard_intel(root: Node3D) -> void:
	_add_box(root, Vector3(2.9, 0.45, 2.9), Vector3(0.0, 0.22, 0.0), _material("stone"), Vector3.ZERO, "TowerBase")
	_add_box(root, Vector3(1.9, 7.6, 1.9), Vector3(0.0, 4.25, 0.0), _material("metal"), Vector3.ZERO, "Tower")
	_add_box(root, Vector3(3.9, 0.22, 0.22), Vector3(0.0, 7.55, 0.3), _material("iron"), Vector3.ZERO, "CrossArm")
	_add_cylinder(root, 0.06, 0.08, 2.4, Vector3(0.0, 9.15, 0.3), _material("iron"), "Aerial")
	_add_box(root, Vector3(0.34, 0.34, 0.34), Vector3(0.0, 8.0, 0.3), _make_unshaded(Color(1.0, 0.72, 0.38), 1.8), Vector3.ZERO, "SignalLamp")
	_add_sign(root, _sign_color("intel"), Vector2(2.2, 0.75), Vector3(0.0, 5.1, 1.05))
	_add_barrel(root, Vector3(-2.0, 0.0, 1.4))


## Shipyard: dry dock basin + gantry frame + rust red sign.
func _billboard_shipyard(root: Node3D) -> void:
	var stone := _material("stone")
	var iron := _material("iron")
	# Dry dock: low basin with raised side walls and keel blocks.
	_add_box(root, Vector3(15.0, 0.5, 6.4), Vector3(0.0, 0.25, 0.4), stone, Vector3.ZERO, "DryDockFloor")
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(15.0, 1.1, 0.9), Vector3(0.0, 0.55, 0.4 + side * 3.1), _material("wood_dark"), Vector3.ZERO, "DryDockWall")
	for index in 3:
		_add_box(root, Vector3(1.4, 0.7, 0.9), Vector3(-4.2 + float(index) * 4.2, 0.85, 0.4), _material("wood"), Vector3.ZERO, "KeelBlock")
	# Gantry straddling the dock.
	for side in [-1.0, 1.0]:
		_add_box(root, Vector3(0.7, 8.4, 0.7), Vector3(side * 5.2, 4.2, -2.6), iron, Vector3.ZERO, "GantryLeg")
		_add_box(root, Vector3(0.3, 0.3, 3.0), Vector3(side * 5.2, 4.0, -1.2), iron, Vector3.ZERO, "")
	_add_box(root, Vector3(11.6, 0.75, 0.9), Vector3(0.0, 8.4, -2.6), iron, Vector3.ZERO, "GantryBeam")
	_add_box(root, Vector3(0.5, 0.5, 2.4), Vector3(0.0, 7.0, -2.6), iron, Vector3.ZERO, "Hoist")
	_add_box(root, Vector3(0.08, 2.4, 0.08), Vector3(1.3, 5.8, -2.6), iron, Vector3.ZERO, "Cable")
	_add_box(root, Vector3(0.5, 0.4, 0.5), Vector3(1.3, 4.5, -2.6), _material("brass"), Vector3.ZERO, "Hook")
	_add_sign(root, _sign_color("shipyard"), Vector2(4.4, 1.1), Vector3(0.0, 8.35, -2.0))


# --- Empty slots ------------------------------------------------------------

func _build_filler(facility: String, root: Node3D) -> void:
	var seed_value := String(_port.get("id", "port")).hash() ^ ((FACILITY_ORDER.find(facility) + 1) * 7919)
	_add_box(root, Vector3(3.4, 0.08, 2.6), Vector3(0.0, 0.04, 0.0), _material("wood_dark"), Vector3.ZERO, "FillerPallet")
	var wood := _material("wood")
	var count := 2 + int(_hash01(seed_value, 1, 5) * 2.0)
	for index in count:
		var size := 0.7 + _hash01(seed_value, index, 13) * 0.8
		var pos := Vector3(
			(_hash01(seed_value, index, 17) - 0.5) * 2.6,
			size * 0.5,
			(_hash01(seed_value, index, 19) - 0.5) * 1.8
		)
		var rotation := Vector3(0.0, _hash01(seed_value, index, 29) * 40.0, 0.0)
		_add_box(root, Vector3(size, size * 0.85, size), pos, wood, rotation, "FillerCrate")
	_add_barrel(root, Vector3(1.4, 0.0, 1.2))
	if _hash01(seed_value, 2, 31) > 0.45:
		_add_box(root, Vector3(1.9, 0.55, 1.5), Vector3(-1.1, 0.28, 1.3), _material("canvas"), Vector3(0.0, -20.0, 0.0), "FillerSacks")


# --- Landmark ---------------------------------------------------------------

func _rebuild_landmark() -> void:
	var path := String(_port.get("landmark_path", ""))
	if path.is_empty():
		return
	var visual := _instantiate_visual(path)
	if visual == null:
		return
	var landmark := Node3D.new()
	landmark.name = "Landmark"
	landmark.position = LANDMARK_POS
	visual.position = Vector3.ZERO
	landmark.add_child(visual)
	_content.add_child(landmark)
	_landmark = landmark


# --- L2b: harbour town (dense background street behind the quay) ------------

func _rebuild_town() -> void:
	_town_root = Node3D.new()
	_town_root.name = "HarborTown"
	_content.add_child(_town_root)
	_town_prop_count = 0
	_town_blockout_count = 0
	# Raised stone plaza: grounds the town row and turns the empty water sheet
	# behind the quay into a readable harbour square.
	_add_box(
		_town_root,
		TOWN_PLAZA_SIZE,
		TOWN_PLAZA_CENTER,
		_material("plaza"),
		Vector3.ZERO,
		"TownPlaza"
	)
	# Batched paving seams: one draw call instead of a dozen thin boxes.
	var pave_mesh := BoxMesh.new()
	pave_mesh.size = Vector3(0.12, 0.05, TOWN_PLAZA_SIZE.z - 2.0)
	var pave_transforms: Array[Transform3D] = []
	for index in 31:
		var x := -120.0 + float(index) * 8.0
		pave_transforms.append(
			Transform3D(Basis.IDENTITY, Vector3(x, TOWN_GROUND_Y + 0.01, TOWN_PLAZA_CENTER.z))
		)
	_add_multimesh(
		_town_root,
		pave_mesh,
		pave_transforms,
		_material("wood_dark"),
		"PlazaPaving",
		AABB(Vector3(-124.0, TOWN_GROUND_Y - 0.2, -46.0), Vector3(248.0, 0.4, 40.0))
	)
	_add_box(
		_town_root,
		Vector3(TOWN_PLAZA_SIZE.x, 0.35, 0.5),
		Vector3(0.0, TOWN_GROUND_Y - 0.15, -9.9),
		_material("wood_dark"),
		Vector3.ZERO,
		"PlazaEdge"
	)
	for spec in TOWN_SLOTS:
		_add_town_prop(
			String(spec["slot"]),
			spec["pos"],
			float(spec["yaw"]),
			float(spec["scale"]),
			true
		)
	var seed_value := String(_port.get("id", "port")).hash()
	# Fence modules along the plaza/quay seam.
	var fence_count := mini(_town_count("fence"), TOWN_FENCE_X.size())
	for index in fence_count:
		_add_town_prop(
			"fence_row",
			Vector3(TOWN_FENCE_X[index], TOWN_GROUND_Y, -12.6),
			0.0, 1.0, false
		)
	# Workers read as people, not props: a small deterministic yaw offset stops
	# the repeated poses from lining up exactly.
	var worker_count := mini(_town_count("worker"), TOWN_WORKER_SLOTS.size())
	for index in worker_count:
		var worker_spec: Dictionary = TOWN_WORKER_SLOTS[index]
		_add_town_prop(
			String(worker_spec["slot"]),
			worker_spec["pos"],
			_town_jitter_yaw(seed_value, index, float(worker_spec["yaw"]), 61, 14.0),
			1.0, false
		)
	# Plaza props (crates/barrels/lamps/market clutter).
	var decor_count := mini(_town_count("decor"), TOWN_DECOR_SLOTS.size())
	for index in decor_count:
		var decor_spec: Dictionary = TOWN_DECOR_SLOTS[index]
		_add_town_prop(
			String(decor_spec["slot"]),
			decor_spec["pos"],
			_town_jitter_yaw(seed_value, index, float(decor_spec["yaw"]), 67, 12.0),
			1.0, false
		)
	# Moored small craft.
	var boat_count := mini(_town_count("boat"), TOWN_BOAT_SLOTS.size())
	for index in boat_count:
		var boat_spec: Dictionary = TOWN_BOAT_SLOTS[index]
		_add_town_prop(
			String(boat_spec["slot"]),
			boat_spec["pos"],
			float(boat_spec["yaw"]),
			1.0, false
		)
	# Dock-side industry: market stalls, cranes, cargo piles, pallets, gangways,
	# bollards, capstans and buoys. Only official core-kit asset keys are used.
	for group_index in TOWN_QUAY_ORDER.size():
		var group := String(TOWN_QUAY_ORDER[group_index])
		var slots_value: Variant = TOWN_QUAY_SLOTS.get(group, [])
		if not (slots_value is Array):
			continue
		var slots: Array = slots_value
		var group_count := mini(_town_count(group), slots.size())
		for index in group_count:
			var quay_spec: Dictionary = slots[index]
			var yaw := float(quay_spec["yaw"])
			# Loose freight rolls a little differently per harbour; the authored
			# alignments (stalls, cranes, gangways, bollards) stay square.
			if group == "pallet" or group == "buoy":
				yaw = _town_jitter_yaw(seed_value, index + group_index * 13, yaw, 73, 30.0)
			_add_town_prop(group, quay_spec["pos"], yaw, 1.0, false)
	_rebuild_station_dressing()


## Station dressing: each adjacent station owns the props in front of it, so the
## three shots read as a working market square, a coal/water yard and a harbour
## authority frontage inside the same continuous quay. Props reuse the official
## town-kit keys; a missing visual simply disappears (no placeholder boxes).
func _rebuild_station_dressing() -> void:
	_station_prop_count = 0
	var limit := _station_prop_count_for_density()
	for station_id in STATION_ORDER:
		var props_value: Variant = STATION_PROPS.get(station_id, [])
		if not (props_value is Array):
			continue
		var props: Array = props_value
		var count := mini(limit, props.size())
		for index in count:
			var spec: Dictionary = props[index]
			_add_town_prop(
				String(spec["slot"]),
				spec["pos"],
				float(spec["yaw"]),
				1.0, false, true
			)


## Props mounted per station at the current density tier (a prefix per list).
func _station_prop_count_for_density() -> int:
	var value: Variant = STATION_PROP_COUNTS.get(_town_density, 0)
	return maxi(0, int(value))


## Resolves the street density tier: explicit `port.density` (the shell also
## forwards it) or `port.diorama.density` wins; otherwise `port.size` derives it.
## Unknown values fall back to the size default, so old saves keep rendering.
func _resolve_town_density() -> String:
	var raw := String(_port.get("density", "")).to_lower()
	if raw.is_empty():
		var diorama_value: Variant = _port.get("diorama", {})
		if diorama_value is Dictionary:
			raw = String((diorama_value as Dictionary).get("density", "")).to_lower()
	if DENSITY_ORDER.has(raw):
		return raw
	var derived := String(DENSITY_BY_SIZE.get(_size, "normal"))
	return derived if DENSITY_ORDER.has(derived) else "normal"


## Props mounted for one layout group at the current density tier.
func _town_count(group: String) -> int:
	var table_value: Variant = TOWN_COUNTS.get(group, {})
	if not (table_value is Dictionary):
		return 0
	var table: Dictionary = table_value
	if not table.has(_town_density):
		return 0
	return maxi(0, int(table[_town_density]))


## Deterministic yaw jitter from the port id hash (never global RNG).
func _town_jitter_yaw(seed_value: int, index: int, base_yaw: float, salt: int, amplitude: float) -> float:
	return base_yaw + (_hash01(seed_value, index, salt) - 0.5) * amplitude


## Mounts one town-kit GLB (pre-resolved path in `port.town_visuals`) or, for
## the five building slots, a procedural blockout. Workers/boats/fence simply
## disappear when their GLB is missing, so a content-less stage stays clean.
## `station` marks the per-station dressing props, which are counted separately
## from the harbour-town kit (`station_prop_count()` vs `town_prop_count()`).
func _add_town_prop(
	slot: String,
	pos: Vector3,
	yaw: float,
	prop_scale: float,
	blockout_fallback: bool,
	station: bool = false
) -> void:
	var path := String(_town_visuals.get(slot, ""))
	var visual: Node3D = _instantiate_visual(path) if not path.is_empty() else null
	if visual == null:
		if not blockout_fallback:
			return
		visual = _build_town_blockout(slot)
		if visual == null:
			return
		_town_blockout_count += 1
	var holder := Node3D.new()
	var index := _station_prop_count if station else _town_prop_count
	holder.name = ("Station_%s_%d" if station else "Town_%s_%d") % [slot, index]
	holder.position = pos
	holder.rotation_degrees = Vector3(0.0, yaw, 0.0)
	holder.scale = Vector3.ONE * prop_scale
	holder.add_child(visual)
	_town_root.add_child(holder)
	if station:
		_station_prop_count += 1
	else:
		_town_prop_count += 1


## Cheap box/roof stand-in used only when the town kit is unavailable. It keeps
## the skyline dense and lets the layout be judged before content is authored.
func _build_town_blockout(slot: String) -> Node3D:
	var size_value: Variant = TOWN_BLOCKOUT_SIZES.get(slot, null)
	if not (size_value is Vector3):
		return null
	var size: Vector3 = size_value
	var root := Node3D.new()
	root.name = "TownBlockout_" + slot
	var wall := _material("brick")
	if wall == null:
		wall = _material("stone")
	var roof := _material("wood_dark")
	var trim := _material("iron")
	# Body: X frontage, Y depth, Z height (holder yaw rotates local +X to +Z).
	_add_box(root, Vector3(size.x, size.z, size.y), Vector3(0.0, size.y * 0.5, 0.0), wall, Vector3.ZERO, "Body")
	# Gable-ish roof: two sloped slabs rather than a full prism.
	var half_depth := size.z * 0.5 + 0.45
	var slab := Vector3(size.x + 0.8, half_depth, 0.28)
	_add_box(root, slab, Vector3(0.0, size.y + 0.42, 0.0), roof, Vector3(28.0, 0.0, 0.0), "RoofFront")
	_add_box(root, slab, Vector3(0.0, size.y + 0.42, 0.0), roof, Vector3(-28.0, 0.0, 0.0), "RoofBack")
	# Facade rhythm: dark windows + door on the camera-facing local +X wall.
	var facade_x := size.x * 0.5 + 0.04
	var window_rows := 2 if size.y >= 9.0 else 1
	for row in window_rows:
		var z := size.y * 0.42 + float(row) * 2.6
		for column in 3:
			var y := -size.z * 0.28 + float(column) * size.z * 0.28
			_add_box(root, Vector3(0.08, 1.1, 1.3), Vector3(facade_x, y, z), trim, Vector3.ZERO, "")
	_add_box(root, Vector3(0.08, 1.5, 2.2), Vector3(facade_x, -size.z * 0.18, 1.1), roof, Vector3.ZERO, "Door")
	return root


# --- Static batching --------------------------------------------------------
#
# The fixed-camera stage is mostly static boxes and repeated content-kit props,
# and every surface is a draw call. After the dynamic layers are rebuilt:
#
#   1. procedural BoxMesh nodes share one unit cube and one MultiMesh per
#      material (per-instance scale = the authored box size);
#   2. every other bakeable static mesh (GLB props, cylinders, sign quads) is
#      merged by *material signature* into one static ArrayMesh per material.
#      Content-kit GLBs are multi-surface (one surface per palette material), so
#      merging by material is what actually collapses the harbour down to one
#      draw per material instead of ~10 per building + 32 per crane.
#
# Transparency, shader materials, overlays and non-triangle surfaces are left
# untouched (safe fallback): the merge never changes how something is drawn.
# The player hull is folded separately in ship-local space (see
# `_batch_ship_visual`), while water, particles, fog, the L2 MultiMesh and the
# foreground frame stay outside the batched roots on purpose.

func _batch_static_meshes() -> void:
	_batch_batches = 0
	_batch_multimesh_batches = 0
	_batch_material_batches = 0
	_batch_meshes_before = 0
	_batch_meshes_after = 0
	_batch_surfaces_before = 0
	_batch_surfaces_after = 0
	if _content == null or not is_instance_valid(_content):
		return
	var roots: Array[Node] = []
	if _facilities_root != null:
		roots.append(_facilities_root)
	if _town_root != null:
		roots.append(_town_root)
	if roots.is_empty():
		return
	var before := _count_draw_meshes(roots)
	_batch_meshes_before = int(before["meshes"])
	_batch_surfaces_before = int(before["surfaces"])
	var candidates: Array[MeshInstance3D] = []
	for root in roots:
		_collect_static_meshes(root, candidates)
	if candidates.is_empty():
		_batch_meshes_after = _batch_meshes_before
		_batch_surfaces_after = _batch_surfaces_before
		return
	var content_inverse := _content.global_transform.affine_inverse()
	var batch_root := Node3D.new()
	batch_root.name = "StaticBatches"
	_content.add_child(batch_root)
	var result := _batch_into(batch_root, candidates, content_inverse, "")
	_batch_multimesh_batches = int(result["multimesh"])
	_batch_material_batches = int(result["material"])
	_batch_batches = int(result["batches"])
	if _batch_batches == 0:
		_content.remove_child(batch_root)
		batch_root.free()
	# The originals are gone: every one of them is now geometry inside a batch.
	for instance in (result["nodes"] as Array):
		if not is_instance_valid(instance):
			continue
		if instance.get_parent() != null:
			instance.get_parent().remove_child(instance)
		instance.free()
	var after := _count_draw_meshes(roots)
	# The batch nodes live directly under `_content`, beside the batched layers,
	# so they are added to the draw census by hand (one surface each).
	_batch_meshes_after = int(after["meshes"]) + _batch_batches
	_batch_surfaces_after = int(after["surfaces"]) + _batch_batches


## Bakes `candidates` into `container` (in the container's parent space):
## procedural boxes become one MultiMesh per material (shared unit cube +
## per-instance scale); every other bakeable mesh is merged per material
## signature into one ArrayMesh. Returns the batch counts plus the source nodes
## that are now redundant — the caller frees them (static layers) or drops the
## whole original hierarchy (hull). `name_prefix` separates the static batches
## ("") from the ship batches ("Ship").
func _batch_into(
	container: Node3D,
	candidates: Array[MeshInstance3D],
	space_inverse: Transform3D,
	name_prefix: String
) -> Dictionary:
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var box_groups: Dictionary = {}
	var merged_groups: Dictionary = {}
	var merged_order: Array[String] = []
	var to_free: Array[MeshInstance3D] = []
	for instance in candidates:
		if not is_instance_valid(instance) or instance.mesh == null:
			continue
		var local_xform := space_inverse * instance.global_transform
		var mesh := instance.mesh
		if mesh is BoxMesh and _can_batch_box(instance):
			var box := mesh as BoxMesh
			var box_material := _instance_material(instance)
			var key := "box|" + _material_identity(box_material)
			if not box_groups.has(key):
				box_groups[key] = {"material": box_material, "transforms": [] as Array[Transform3D]}
			var box_group: Dictionary = box_groups[key]
			var transforms: Array[Transform3D] = box_group["transforms"]
			transforms.append(local_xform * Transform3D(Basis.IDENTITY.scaled(box.size), Vector3.ZERO))
			box_group["transforms"] = transforms
			to_free.append(instance)
		elif _can_merge_instance(instance):
			_merge_instance(instance, local_xform, merged_groups, merged_order)
			to_free.append(instance)
	# 1) One MultiMesh per box material (shared unit cube, per-instance scale).
	var multimesh_batches := 0
	for key in box_groups.keys():
		var box_group: Dictionary = box_groups[key]
		var box_transforms: Array[Transform3D] = box_group["transforms"]
		if box_transforms.is_empty():
			continue
		var box_bounds := _transforms_aabb(unit_box, box_transforms)
		_add_multimesh(
			container, unit_box, box_transforms, box_group["material"],
			"%sBoxBatch_%d" % [name_prefix, multimesh_batches], box_bounds
		)
		multimesh_batches += 1
	# 2) One merged static mesh per material signature (GLB surfaces + primitives).
	var material_batches := 0
	for material_index in merged_order.size():
		var key := merged_order[material_index]
		var group: Dictionary = merged_groups[key]
		var vertices: PackedVector3Array = group["vertices"]
		if vertices.is_empty():
			continue
		var mesh_arrays: Array = []
		mesh_arrays.resize(Mesh.ARRAY_MAX)
		mesh_arrays[Mesh.ARRAY_VERTEX] = vertices
		if bool(group["has_normal"]):
			mesh_arrays[Mesh.ARRAY_NORMAL] = group["normals"]
		if bool(group["has_uv"]):
			mesh_arrays[Mesh.ARRAY_TEX_UV] = group["uvs"]
		if bool(group["has_color"]):
			mesh_arrays[Mesh.ARRAY_COLOR] = group["colors"]
		mesh_arrays[Mesh.ARRAY_INDEX] = group["indices"]
		var merged_mesh := ArrayMesh.new()
		merged_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_arrays)
		var merged_material: Material = group["material"]
		if merged_material != null:
			merged_mesh.surface_set_material(0, merged_material)
		var merged_instance := MeshInstance3D.new()
		merged_instance.name = "%sMaterialBatch_%d" % [name_prefix, material_batches]
		merged_instance.mesh = merged_mesh
		merged_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(merged_instance)
		material_batches += 1
	return {
		"batches": multimesh_batches + material_batches,
		"multimesh": multimesh_batches,
		"material": material_batches,
		"nodes": to_free,
	}


## Collects the MeshInstance3D nodes under `node` that belong to the static
## batched layers. MultiMesh batches and particles are already draw-optimal.
func _collect_static_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MultiMeshInstance3D or node is GPUParticles3D:
		return
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			out.append(instance)
	for child in node.get_children():
		_collect_static_meshes(child, out)


## Draw-mesh / surface census under the batched roots (before and after).
func _count_draw_meshes(roots: Array[Node]) -> Dictionary:
	var result := {"meshes": 0, "surfaces": 0}
	for root in roots:
		_count_draw_meshes_under(root, result)
	return result


func _count_draw_meshes_under(node: Node, result: Dictionary) -> void:
	if node is MultiMeshInstance3D:
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh != null:
			result["meshes"] = int(result["meshes"]) + 1
			result["surfaces"] = int(result["surfaces"]) + multi.mesh.get_surface_count()
	elif node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			result["meshes"] = int(result["meshes"]) + 1
			result["surfaces"] = int(result["surfaces"]) + instance.mesh.get_surface_count()
	for child in node.get_children():
		_count_draw_meshes_under(child, result)


## Effective material of a MeshInstance3D: `material_override` wins, then the
## primitive's own material, then its single surface material.
func _instance_material(instance: MeshInstance3D) -> Material:
	if instance.material_override != null:
		return instance.material_override
	var mesh := instance.mesh
	if mesh is PrimitiveMesh and (mesh as PrimitiveMesh).material != null:
		return (mesh as PrimitiveMesh).material
	if mesh != null and mesh.get_surface_count() == 1:
		return mesh.surface_get_material(0)
	return null


## Materials the batcher may fold together: opaque StandardMaterial3D only.
## Transparent / shader materials keep their own node (sorting stays correct),
## and normal-mapped materials stay unbatched because the merge drops tangents.
func _is_batchable_material(material: Material) -> bool:
	if material == null:
		return true
	if not (material is StandardMaterial3D):
		return false
	var standard := material as StandardMaterial3D
	if standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	if standard.normal_texture != null:
		return false
	return true


func _material_identity(material: Material) -> String:
	if material == null:
		return "none"
	return str(material.get_instance_id())


## Visual identity of a material, so content-kit GLBs that were authored from
## the same palette collapse into one merged batch even though each GLB import
## creates its own material resources.
func _material_signature(material: Material) -> String:
	if material == null:
		return "none"
	if not (material is StandardMaterial3D):
		return "res|%d" % material.get_instance_id()
	var standard := material as StandardMaterial3D
	var texture_id := 0
	if standard.albedo_texture != null:
		texture_id = standard.albedo_texture.get_instance_id()
	var parts: Array[String] = [
		"std",
		standard.albedo_color.to_html(),
		"%.4f" % standard.metallic,
		"%.4f" % standard.roughness,
		"%.4f" % standard.metallic_specular,
		"%d" % int(standard.shading_mode),
		"%d" % int(standard.transparency),
		"%d" % int(standard.blend_mode),
		"%d" % int(standard.cull_mode),
		"%d" % int(standard.emission_enabled),
		standard.emission.to_html(),
		"%.4f" % standard.emission_energy_multiplier,
		"%d" % (1 if standard.vertex_color_use_as_albedo else 0),
		"%d" % texture_id,
	]
	return "|".join(parts)


func _can_batch_box(instance: MeshInstance3D) -> bool:
	if instance.material_overlay != null:
		return false
	return _is_batchable_material(_instance_material(instance))


## A non-box static mesh can be merged only when every surface is a triangle
## surface with an opaque StandardMaterial3D (or no material at all).
func _can_merge_instance(instance: MeshInstance3D) -> bool:
	if instance.material_overlay != null:
		return false
	var mesh := instance.mesh
	if mesh == null:
		return false
	for surface in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var material: Material = instance.material_override
		if material == null:
			material = mesh.surface_get_material(surface)
		if not _is_batchable_material(material):
			return false
	return true


## Bakes one static MeshInstance3D into its material-signature group: vertices
## are transformed into `_content` space, normals by the inverse transpose.
func _merge_instance(
	instance: MeshInstance3D,
	local_xform: Transform3D,
	groups: Dictionary,
	order: Array[String]
) -> void:
	var mesh := instance.mesh
	if mesh == null:
		return
	var normal_basis := local_xform.basis.inverse().transposed()
	for surface in mesh.get_surface_count():
		var material: Material = instance.material_override
		if material == null:
			material = mesh.surface_get_material(surface)
		var arrays := mesh.surface_get_arrays(surface)
		var vertices_value: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not (vertices_value is PackedVector3Array):
			continue
		var vertices: PackedVector3Array = vertices_value
		if vertices.is_empty():
			continue
		var normals_value: Variant = arrays[Mesh.ARRAY_NORMAL]
		var uvs_value: Variant = arrays[Mesh.ARRAY_TEX_UV]
		var colors_value: Variant = arrays[Mesh.ARRAY_COLOR]
		var normals: PackedVector3Array = normals_value if normals_value is PackedVector3Array else PackedVector3Array()
		var uvs: PackedVector2Array = uvs_value if uvs_value is PackedVector2Array else PackedVector2Array()
		var colors: PackedColorArray = colors_value if colors_value is PackedColorArray else PackedColorArray()
		var has_normal := normals.size() == vertices.size()
		var has_uv := uvs.size() == vertices.size()
		var has_color := colors.size() == vertices.size()
		var key := "%s|%d|%d|%d" % [
			_material_signature(material),
			1 if has_normal else 0,
			1 if has_uv else 0,
			1 if has_color else 0,
		]
		if not groups.has(key):
			groups[key] = {
				"material": material,
				"vertices": PackedVector3Array(),
				"normals": PackedVector3Array(),
				"uvs": PackedVector2Array(),
				"colors": PackedColorArray(),
				"indices": PackedInt32Array(),
				"has_normal": has_normal,
				"has_uv": has_uv,
				"has_color": has_color,
			}
			order.append(key)
		var group: Dictionary = groups[key]
		var group_vertices: PackedVector3Array = group["vertices"]
		var base_index := group_vertices.size()
		var transformed_vertices := PackedVector3Array()
		transformed_vertices.resize(vertices.size())
		for index in vertices.size():
			transformed_vertices[index] = local_xform * vertices[index]
		group_vertices.append_array(transformed_vertices)
		group["vertices"] = group_vertices
		if has_normal:
			var group_normals: PackedVector3Array = group["normals"]
			var transformed_normals := PackedVector3Array()
			transformed_normals.resize(normals.size())
			for index in normals.size():
				transformed_normals[index] = (normal_basis * normals[index]).normalized()
			group_normals.append_array(transformed_normals)
			group["normals"] = group_normals
		if has_uv:
			var group_uvs: PackedVector2Array = group["uvs"]
			group_uvs.append_array(uvs)
			group["uvs"] = group_uvs
		if has_color:
			var group_colors: PackedColorArray = group["colors"]
			group_colors.append_array(colors)
			group["colors"] = group_colors
		var group_indices: PackedInt32Array = group["indices"]
		var index_value: Variant = arrays[Mesh.ARRAY_INDEX]
		if index_value is PackedInt32Array and (index_value as PackedInt32Array).size() > 0:
			var surface_indices: PackedInt32Array = (index_value as PackedInt32Array).duplicate()
			for index in surface_indices.size():
				surface_indices[index] = surface_indices[index] + base_index
			group_indices.append_array(surface_indices)
		else:
			for index in vertices.size():
				group_indices.append(base_index + index)
		group["indices"] = group_indices


func _transforms_aabb(mesh: Mesh, transforms: Array[Transform3D]) -> AABB:
	var bounds := AABB()
	var has_bounds := false
	for xform in transforms:
		var box := StageKit.transform_aabb(xform, mesh.get_aabb())
		bounds = box if not has_bounds else bounds.merge(box)
		has_bounds = true
	return bounds


# --- L5 player ship ---------------------------------------------------------

func _rebuild_ship(ship: Dictionary) -> void:
	var path := String(ship.get("hull_model_path", ""))
	if path.is_empty():
		path = _fallback_path_for_tier(int(ship.get("hull_tier", 1)))
	var visual := _instantiate_visual(path)
	if visual == null:
		_disable_boat_foam()
		return
	var root := Node3D.new()
	root.name = "PlayerShip"
	# A rebuild keeps the current station: the hull is rebuilt at its berth, not
	# teleported back to the harbour reference shot.
	_ship_x = _ship_moor_x
	_ship_yaw = _ship_moor_yaw
	_ship_sailing = false
	root.position = Vector3(_ship_moor_x, 0.0, _ship_moor_z)
	root.scale = Vector3.ONE * SHIP_SCALE
	root.rotation = Vector3(0.0, _ship_yaw, 0.0)
	_content.add_child(root)
	_ship_root = root
	root.add_child(visual)
	var bounds := StageKit.visual_aabb(root)
	# The foam ring is configured from the *un-batched* hull, then the hull is
	# rigidly baked into ship-local draw batches. The batches stay children of
	# `_ship_root`, so the station transit / bob / turn keeps moving the whole
	# ship. The centre offset is stored in ship-local space so the foam can follow
	# the hull between berths.
	_ship_bounds = bounds
	_ship_bounds_offset = bounds.get_center() - root.position
	if _water_material != null:
		StageKit.configure_boat_foam(_water_material, bounds)
		_water_material.set_shader_parameter("boat_yaw", _ship_yaw)
		_water_material.set_shader_parameter("boat_foam_width", 0.8)
	_batch_ship_visual(visual)
	_sync_boat_foam()


## Rigidly bakes the hull visual into ship-local draw batches under `_ship_root`.
## The foam bounds are captured before this runs, so the water foam ring keeps
## matching the authored hull. Non-rigid hulls (animation/skeleton/particles/
## transparent materials) are left untouched and reported via `ship_fallback`.
func _batch_ship_visual(visual: Node3D) -> void:
	_ship_batches = 0
	_ship_multimesh_batches = 0
	_ship_material_batches = 0
	_ship_meshes_before = 0
	_ship_meshes_after = 0
	_ship_surfaces_before = 0
	_ship_surfaces_after = 0
	_ship_fallback = false
	if _ship_root == null or not is_instance_valid(_ship_root) or visual == null or not is_instance_valid(visual):
		_ship_fallback = true
		return
	var before := _count_draw_meshes([visual])
	_ship_meshes_before = int(before["meshes"])
	_ship_surfaces_before = int(before["surfaces"])
	if not ship_visual_is_rigid(visual):
		_ship_fallback = true
		_ship_meshes_after = _ship_meshes_before
		_ship_surfaces_after = _ship_surfaces_before
		return
	var candidates: Array[MeshInstance3D] = []
	_collect_static_meshes(visual, candidates)
	if candidates.is_empty() or candidates.size() != _ship_meshes_before:
		_ship_fallback = true
		_ship_meshes_after = _ship_meshes_before
		_ship_surfaces_after = _ship_surfaces_before
		return
	var ship_space_inverse := _ship_root.global_transform.affine_inverse()
	var batch_root := Node3D.new()
	batch_root.name = "ShipBatches"
	_ship_root.add_child(batch_root)
	var result := _batch_into(batch_root, candidates, ship_space_inverse, "Ship")
	var baked: Array = result["nodes"]
	if int(result["batches"]) == 0 or baked.size() != candidates.size():
		# Nothing safely bakeable: drop the half-built batches and keep the
		# original hull untouched (no visual regression).
		_ship_root.remove_child(batch_root)
		batch_root.free()
		_ship_fallback = true
		_ship_meshes_after = _ship_meshes_before
		_ship_surfaces_after = _ship_surfaces_before
		return
	_ship_multimesh_batches = int(result["multimesh"])
	_ship_material_batches = int(result["material"])
	_ship_batches = int(result["batches"])
	# Every hull mesh is baked into ShipBatches now; the original hierarchy is
	# redundant and would double the draw calls.
	for instance in baked:
		if not is_instance_valid(instance):
			continue
		if instance.get_parent() != null:
			instance.get_parent().remove_child(instance)
		instance.free()
	if visual.get_parent() != null:
		visual.get_parent().remove_child(visual)
	visual.free()
	var after := _count_draw_meshes([_ship_root])
	_ship_meshes_after = int(after["meshes"])
	_ship_surfaces_after = int(after["surfaces"])


func _fallback_path_for_tier(tier: int) -> String:
	var path := String(MODEL_BY_TIER.get(tier, MODEL_BY_TIER[1]))
	if FileAccess.file_exists(path) or ResourceLoader.exists(path):
		return path
	return FALLBACK_MODEL


func _disable_boat_foam() -> void:
	if _water_material == null:
		return
	_water_material.set_shader_parameter("boat_center", Vector2(0.0, 10000.0))
	_water_material.set_shader_parameter("boat_half_size", Vector2(1.0, 1.0))
	_water_material.set_shader_parameter("boat_yaw", 0.0)


# --- Primitive helpers ------------------------------------------------------

## Small wrapper so every procedural texture (sky gradient, sun glow, puff,
## fog band) is built the same way: no external texture asset is involved.
func _gradient_texture_2d(gradient: Gradient, width: int, height: int, fill: int, fill_from: Vector2, fill_to: Vector2) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = maxi(1, width)
	texture.height = maxi(1, height)
	texture.fill = fill
	texture.fill_from = fill_from
	texture.fill_to = fill_to
	return texture


## Camera-facing transparent quad used by the fallback sky glow and fog bands.
## The stage camera is fixed, so the quad basis is built from the camera axes
## explicitly: this is a screen-aligned quad without relying on shader billboard
## behaviour (which is brittle for transparent additive materials on GL
## Compatibility).
func _add_billboard_quad(parent: Node3D, size: Vector2, position3d: Vector3, texture: Texture2D, tint: Color, blend: int, node_name: String) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.resource_name = "Port_Billboard_" + node_name
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = blend
	material.albedo_texture = texture
	material.albedo_color = tint
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	var instance := MeshInstance3D.new()
	if not node_name.is_empty():
		instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	var forward := (CAMERA_TARGET - CAMERA_POS).normalized()
	var zaxis := -forward
	var xaxis := Vector3.UP.cross(zaxis).normalized()
	var yaxis := zaxis.cross(xaxis)
	instance.transform = Transform3D(Basis(xaxis, yaxis, zaxis), position3d)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Oriented box beam between two world points (foreground crane arm / cables).
func _add_beam(parent: Node3D, from: Vector3, to: Vector3, thickness: float, material: Material, node_name: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, maxf(from.distance_to(to), 0.05))
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	var direction := to - from
	var center := (from + to) * 0.5
	if direction.length_squared() > 0.0001:
		instance.transform = Transform3D(Basis.looking_at(direction.normalized(), Vector3.UP), center)
	else:
		instance.position = center
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Builds one MultiMeshInstance3D from a shared mesh + per-instance transforms
## (optionally per-instance colours). Keeps repeated props at one draw call each.
func _add_multimesh(
	parent: Node3D,
	mesh: Mesh,
	transforms: Array[Transform3D],
	material: Material,
	node_name: String,
	custom_aabb: AABB,
	colors: Array[Color] = []
) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for index in transforms.size():
		multi.set_instance_transform(index, transforms[index])
		if multi.use_colors and index < colors.size():
			multi.set_instance_color(index, colors[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.material_override = material
	instance.custom_aabb = custom_aabb
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _xform(origin: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, origin)


func _scaled_xform(origin: Vector3, size: Vector3, rotation_degrees: Vector3 = Vector3.ZERO) -> Transform3D:
	var basis := Basis.IDENTITY
	if rotation_degrees != Vector3.ZERO:
		basis = Basis.from_euler(Vector3(
			deg_to_rad(rotation_degrees.x), deg_to_rad(rotation_degrees.y), deg_to_rad(rotation_degrees.z)
		))
	basis = basis.scaled(size)
	return Transform3D(basis, origin)


func _add_box(parent: Node3D, size: Vector3, position3d: Vector3, material: Material, rotation_degrees: Vector3 = Vector3.ZERO, node_name: String = "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, mesh, position3d, material, rotation_degrees, node_name)


func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, position3d: Vector3, material: Material, node_name: String = "") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 16
	return _add_mesh(parent, mesh, position3d, material, Vector3.ZERO, node_name)


func _add_mesh(parent: Node3D, mesh: Mesh, position3d: Vector3, material: Material, rotation_degrees: Vector3, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if not node_name.is_empty():
		instance.name = node_name
	instance.mesh = mesh
	if material != null:
		instance.material_override = material
	instance.position = position3d
	instance.rotation_degrees = rotation_degrees
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _add_sign(parent: Node3D, color: Color, size: Vector2, position3d: Vector3) -> void:
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(size.x + 0.16, size.y + 0.16, 0.1)
	var frame := _add_mesh(
		parent,
		frame_mesh,
		position3d + Vector3(0.0, 0.0, -0.06),
		_material("iron"),
		Vector3(0.0, SIGN_YAW_DEG, 0.0),
		"SignFrame"
	)
	frame.rotation_degrees = Vector3(0.0, SIGN_YAW_DEG, 0.0)
	var quad := QuadMesh.new()
	quad.size = size
	var material := _make_unshaded(color, 1.15)
	var sign_instance := _add_mesh(parent, quad, position3d, material, Vector3(0.0, SIGN_YAW_DEG, 0.0), "Sign")
	sign_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_crate(parent: Node3D, position3d: Vector3, size: float) -> void:
	_add_box(parent, Vector3(size, size, size), position3d + Vector3(0.0, size * 0.5, 0.0), _material("wood"), Vector3(0.0, 12.0, 0.0), "")


func _add_barrel(parent: Node3D, position3d: Vector3) -> void:
	_add_cylinder(parent, 0.38, 0.42, 0.95, position3d + Vector3(0.0, 0.475, 0.0), _material("metal"), "")
	_add_cylinder(parent, 0.44, 0.44, 0.08, position3d + Vector3(0.0, 0.86, 0.0), _material("iron"), "")


func _add_lamp_post(parent: Node3D, position3d: Vector3) -> void:
	_add_cylinder(parent, 0.06, 0.09, 3.2, position3d + Vector3(0.0, 1.6, 0.0), _material("iron"), "")
	_add_box(parent, Vector3(0.3, 0.34, 0.3), position3d + Vector3(0.0, 3.3, 0.0), _make_unshaded(Color(1.0, 0.68, 0.36), 1.5), Vector3.ZERO, "")
