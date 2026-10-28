extends TestCase
## @static-doc
## 作用：船厂改装蓝图（P2b / P2a）回归套件：只画侧视图、槽位圆点/折线/模块方框布局、无锚点回退、武器贴片单视图、模式隔离与高亮联动。
##
## 覆盖 `.design/refit_round2_plan.md` 的 P2b 契约与 Lead 补充的 P2a 蓝图侧隔离：
## - CUTAWAY 有 `blueprint_views` 时只画 side（top 不再占 48% 高度，仅保留可计算坐标）；
## - 每个槽位（普通模块 + 舰载武器）在内容 `slot_anchors` / `weapon_sockets[].blueprint.side`
##   的位置画圆点，圆点用折线连到贴片方框；
## - 普通模块方框贴着锚点摆放（可拖放、高亮联动、互不重叠、不出界），不再固定底部 dock；
## - 无 `slot_anchors` 的内容回退到通用面板锚点且不崩；
## - `set_module_chips_visible(false)` / `set_weapon_patches_visible(false)` 做模式隔离
##   （目标不可见、不接受拖放）。
##
## 真实 shell + 船厂页夹具（与 test_shipyard_refit 同一路径）；4 艘 Core 船的
## 侧视锚点布局用独立 `SNShipView` 覆盖，避免只测到开局小船。
## @end-static-doc

const MAIN_SCENE := "res://framework/ui/shell/main.tscn"
const SHIPYARD_SCREEN_SCRIPT := preload("res://framework/ui/screens/port/shipyard_screen.gd")
const SHIP_VIEW_SCRIPT := preload("res://framework/ui/components/sn_ship_view.gd")
const SLOT_TARGET_SCRIPT := preload("res://framework/ui/components/sn_slot_target.gd")
const STEADY_BUILD := "core:starting_scenario/steady"
## 与真实窗口里改装页左侧蓝图内容区接近的尺寸（1440×900 实测约 610×620）。
const SYNTHETIC_STAGE_SIZE := Vector2(610, 620)
const CORE_HULL_IDS := [
	"core:hull/small_efficient",
	"core:hull/medium_standard",
	"core:hull/large_efficient",
	"core:hull/large_performance",
]
## shipyard.view.ship.slot_anchors 的键与 UI 槽位描述里的 `slot` 值一一对应。
const EXPECTED_ANCHOR_KEYS := [
	"hull", "boiler", "navigation_module", "safety_module", "passenger_cabin",
]


func _mount(seed_value: int) -> Dictionary:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var started := context.commands.execute(&"run.start", {
		"starting_scenario": STEADY_BUILD,
		"seed": seed_value,
	})
	assert_true(bool(started.get("ok", false)), "run.start succeeds in the blueprint fixture: %s" % str(started))
	var scene: PackedScene = load(MAIN_SCENE)
	assert_not_null(scene, "the playable shell scene loads")
	var shell: Control = scene.instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shell)
	return {"context": context, "shell": shell, "tree": tree}


func _unmount(bundle: Dictionary) -> void:
	var shell: Control = bundle["shell"]
	if shell.get_parent() != null:
		shell.get_parent().remove_child(shell)
	shell.free()


func _node_with_script(root: Node, script: Script) -> Control:
	for child in root.get_children():
		if child.get_script() == script:
			return child
		var found := _node_with_script(child, script)
		if found != null:
			return found
	return null


## 切到船厂改装态（hulls 分类）并返回舞台；舞台是 CUTAWAY 的 SNShipView。
func _cutaway_stage(bundle: Dictionary) -> Control:
	var shell: Control = bundle["shell"]
	shell._active_screen = "shipyard"
	shell._refresh()
	var screen := _node_with_script(shell._root_box, SHIPYARD_SCREEN_SCRIPT)
	assert_not_null(screen, "the shell hosts the shipyard screen")
	if screen == null:
		return null
	screen.set_category("hulls")
	var stage: Control = screen.get("_stage")
	assert_not_null(stage, "the refit page mounts the cutaway stage")
	return stage


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _slot_target_ids(stage: Control) -> Array:
	var ids: Array = []
	for target in Array(stage.get("_slot_targets")):
		if target is Node and is_instance_valid(target):
			ids.append(String(target.slot.get("id", "")))
	return ids


func _weapon_socket_ids(stage: Control) -> Array:
	var ids: Array = []
	for row in Array(stage.get("_model").get("weapon_sockets", [])):
		if row is Dictionary:
			var socket_id := String(row.get("socket", row.get("name", "")))
			if not socket_id.is_empty():
				ids.append(socket_id)
	return ids


func _rect_inside(rect: Rect2, frame: Rect2) -> bool:
	return rect.position.x >= frame.position.x - 0.5 \
		and rect.position.y >= frame.position.y - 0.5 \
		and rect.end.x <= frame.end.x + 0.5 \
		and rect.end.y <= frame.end.y + 0.5


func _assert_rects_disjoint(rects: Dictionary, label: String) -> void:
	var keys: Array = rects.keys()
	for index in keys.size():
		var first: Rect2 = rects[keys[index]]
		for other_index in range(index + 1, keys.size()):
			var second: Rect2 = rects[keys[other_index]]
			assert_false(first.intersects(second),
				"%s: '%s' and '%s' overlap (%s vs %s)" % [label, str(keys[index]), str(keys[other_index]), str(first), str(second)])


func _fit_side_rect(stage: Control) -> Rect2:
	## 独立复算 side 充满「舞台减去底部标注带」后的等比矩形（预期值，不是被测实现）。
	var texture_size: Vector2 = stage.call("blueprint_texture_size", "side")
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()
	var band: Rect2 = stage.call("chip_band_rect")
	var available := Rect2(Vector2.ZERO, Vector2((stage as Control).size.x, (stage as Control).size.y - band.size.y))
	var scale: float = minf(available.size.x / texture_size.x, available.size.y / texture_size.y)
	var fitted := texture_size * scale
	return Rect2(available.position + (available.size - fitted) * 0.5, fitted)


# ---------------------------------------------------------------------------
# P2b: 单侧视图
# ---------------------------------------------------------------------------
func test_cutaway_draws_only_the_side_view() -> void:
	var bundle := _mount(5501)
	var stage := _cutaway_stage(bundle)
	if stage != null:
		assert_true(bool(stage.call("has_blueprint_views")), "the fixture hull ships per-view line art")
		assert_true(float(stage.call("blueprint_texture_size", "top").x) > 0.0,
			"the top line art still exists (just not drawn)")
		var side_rect: Rect2 = stage.call("blueprint_view_rect", "side")
		var expected := _fit_side_rect(stage)
		assert_true(side_rect.size.x > 0.0 and side_rect.size.y > 0.0, "the side view has an on-screen rect")
		assert_almost_eq(side_rect.size.x, expected.size.x, 0.5, "the side view fills the available width")
		assert_almost_eq(side_rect.size.y, expected.size.y, 0.5, "the side view fills the available height")
		# P2b second pass: chip boxes no longer share the line-art rect; the band
		# below it is reserved for the call-out list (checked below).
		# P2b second pass: chips moved off the drawing into a call-out band below it.
		var band: Rect2 = stage.call("chip_band_rect")
		assert_true(band.size.y > 0.0, "the call-out band reserves space below the ship drawing")
		assert_almost_eq(float(stage.call("slot_dock_height")), band.size.y, 0.5,
			"slot_dock_height() reports the call-out band height")
		assert_true(side_rect.end.y <= band.position.y + 0.5, "the line art stays above the call-out band")
		assert_eq(Array(stage.call("_weapon_views")), ["side"], "weapon patches only live on the side view")
		var target_views: Array = []
		for target in Array(stage.call("weapon_targets")):
			target_views.append(String(target.view))
		assert_eq(target_views.size(), _weapon_socket_ids(stage).size(),
			"one weapon patch per hull socket (single view)")
		for view in target_views:
			assert_eq(view, "side", "every weapon patch is a side patch")
	_unmount(bundle)


# ---------------------------------------------------------------------------
# P2b: 圆点覆盖
# ---------------------------------------------------------------------------
func test_every_slot_and_weapon_has_an_anchor_dot_inside_the_side_view() -> void:
	var bundle := _mount(5502)
	var stage := _cutaway_stage(bundle)
	if stage != null:
		var side_rect: Rect2 = stage.call("blueprint_view_rect", "side")
		var anchors: Dictionary = stage.call("slot_anchor_rects")
		assert_false(anchors.is_empty(), "the stage exposes slot anchor dots for tests")
		for slot_id in _slot_target_ids(stage):
			assert_true(anchors.has(slot_id), "module slot '%s' has an anchor dot" % slot_id)
		# P2a 蓝图侧隔离：常规改装模式只显示模块圆点，舰载武器圆点由武器模式接管。
		for socket_id in _weapon_socket_ids(stage):
			assert_false(anchors.has(socket_id),
				"regular module mode hides the weapon dot '%s'" % socket_id)
		stage.call("set_module_chips_visible", false)
		stage.call("set_weapon_patches_visible", true)
		var weapon_anchors: Dictionary = stage.call("slot_anchor_rects")
		for socket_id in _weapon_socket_ids(stage):
			assert_true(weapon_anchors.has(socket_id), "weapon socket '%s' has an anchor dot" % socket_id)
		for raw_id in weapon_anchors.keys():
			assert_true(_rect_inside(weapon_anchors[raw_id], side_rect),
				"weapon dot '%s' stays inside the side view" % String(raw_id))
		stage.call("set_module_chips_visible", true)
		stage.call("set_weapon_patches_visible", false)
		for raw_id in anchors.keys():
			assert_true(_rect_inside(anchors[raw_id], side_rect),
				"dot '%s' stays inside the side view" % String(raw_id))
		# 内容锚点被真实读取：boiler = [0.475, 0.7]（hulls.json small_efficient）。
		var view_rect: Rect2 = side_rect
		var expected_boiler := view_rect.position + Vector2(0.475 * view_rect.size.x, 0.7 * view_rect.size.y)
		var boiler_dot: Rect2 = anchors.get("boiler_0", Rect2())
		assert_true(boiler_dot.size.x > 0.0, "the boiler slot has a dot")
		if boiler_dot.size.x > 0.0:
			assert_true(boiler_dot.get_center().distance_to(expected_boiler) < 1.0,
				"the boiler dot is projected from the Core blueprint anchor")
		var slot_anchors: Dictionary = stage.get("_model").get("slot_anchors", {})
		for key in EXPECTED_ANCHOR_KEYS:
			assert_true(slot_anchors.has(key), "shipyard.view ships slot_anchors.%s" % key)
		assert_true(slot_anchors.get("cargo_modules", []) is Array, "cargo anchors are a list")
	_unmount(bundle)


# ---------------------------------------------------------------------------
# P2b second pass: 方框移出侧视图 + 点线引线
# ---------------------------------------------------------------------------
func test_chips_leave_the_side_view_and_keep_dotted_leaders() -> void:
	var bundle := _mount(5503)
	var stage := _cutaway_stage(bundle)
	if stage != null:
		var side_rect: Rect2 = stage.call("blueprint_view_rect", "side")
		var band: Rect2 = stage.call("chip_band_rect")
		var chips: Dictionary = stage.call("slot_chip_rects")
		var anchors: Dictionary = stage.call("slot_anchor_rects")
		var leaders: Dictionary = stage.call("slot_leader_lines")
		assert_eq(chips.size(), _slot_target_ids(stage).size(), "every module slot has a chip")
		var combined: Dictionary = {}
		for raw_id in chips.keys():
			var rect: Rect2 = chips[raw_id]
			assert_true(rect.size.x > 0.0 and rect.size.y > 0.0, "chip '%s' has a size" % String(raw_id))
			assert_true(_rect_inside(rect, band), "chip '%s' sits inside the call-out band" % String(raw_id))
			assert_false(rect.intersects(side_rect), "chip '%s' is off the ship drawing" % String(raw_id))
			combined["slot:" + String(raw_id)] = rect
			assert_true(anchors.has(raw_id), "chip '%s' keeps its hull dot" % String(raw_id))
			assert_true(leaders.has(raw_id), "chip '%s' keeps a dotted leader" % String(raw_id))
			var leader: PackedVector2Array = leaders.get(raw_id, PackedVector2Array())
			assert_eq(leader.size(), 2, "leader '%s' is a dot → box segment" % String(raw_id))
			if leader.size() == 2:
				assert_true(leader[0].distance_to((anchors[raw_id] as Rect2).get_center()) <= 0.6,
					"leader '%s' starts on its hull dot" % String(raw_id))
				assert_true((rect as Rect2).grow(0.6).has_point(leader[1]),
					"leader '%s' ends on its chip" % String(raw_id))
		_assert_rects_disjoint(combined, "blueprint chips")
		# 武器模式：炮位贴片走同一条标注带，也同样离开船体线稿。
		stage.call("set_module_chips_visible", false)
		stage.call("set_weapon_patches_visible", true)
		var weapon_band: Rect2 = stage.call("chip_band_rect")
		var weapon_rects: Dictionary = stage.call("weapon_socket_display_rects", "side")
		assert_eq(weapon_rects.size(), _weapon_socket_ids(stage).size(), "every weapon socket has a patch")
		for raw_id in weapon_rects.keys():
			var rect: Rect2 = weapon_rects[raw_id]
			assert_true(_rect_inside(rect, weapon_band),
				"weapon patch '%s' sits inside the call-out band" % String(raw_id))
			assert_false(rect.intersects(side_rect),
				"weapon patch '%s' is off the ship drawing" % String(raw_id))
		_assert_rects_disjoint(weapon_rects, "weapon patches")
		stage.call("set_module_chips_visible", true)
		stage.call("set_weapon_patches_visible", false)
	_unmount(bundle)


# ---------------------------------------------------------------------------
# P2b: 无 slot_anchors 内容回退
# ---------------------------------------------------------------------------
func test_content_without_slot_anchors_falls_back_without_crashing() -> void:
	assert_eq(ShipyardViewQuery._slot_anchors_from_data({}), {},
		"a hull without module slots / compartments projects an empty anchor dict")
	var bundle := _mount(5504)
	var stage := _cutaway_stage(bundle)
	if stage != null:
		var model: Dictionary = (stage.get("_model") as Dictionary).duplicate(true)
		model.erase("slot_anchors")
		stage.call("set_ship_model", model)
		var chips: Dictionary = stage.call("slot_chip_rects")
		assert_eq(chips.size(), _slot_target_ids(stage).size(),
			"every slot still gets a chip with generic fallback anchors")
		var band: Rect2 = stage.call("chip_band_rect")
		for raw_id in chips.keys():
			assert_true(_rect_inside(chips[raw_id], band),
				"fallback chip '%s' stays inside the call-out band" % String(raw_id))
		_assert_rects_disjoint(chips, "fallback chips")
		var anchors: Dictionary = stage.call("slot_anchor_rects")
		assert_false(anchors.is_empty(), "fallback anchors still produce dots")
		var leaders: Dictionary = stage.call("slot_leader_lines")
		assert_eq(leaders.size(), chips.size(), "every fallback chip keeps its dotted leader")
	_unmount(bundle)


# ---------------------------------------------------------------------------
# P2a: 模式隔离（Lead 补充契约）
# ---------------------------------------------------------------------------
func test_mode_isolation_hides_one_group_and_refuses_its_drops() -> void:
	var bundle := _mount(5505)
	var stage := _cutaway_stage(bundle)
	if stage != null:
		# 常规模块模式：只有普通槽位。
		stage.call("set_weapon_patches_visible", false)
		assert_false(bool(stage.call("weapon_patches_visible")), "weapon patches can be hidden")
		for target in Array(stage.call("weapon_targets")):
			assert_false(bool(target.visible), "hidden weapon patch is not visible")
			assert_false(bool(target.call("accepts_payload", {
				"kind": "ship_weapon", "weapon_id": "core:weapon/test",
				"weapon_class": String(target.row.get("socket_class", "")), "source": "warehouse", "name": "x",
			})), "hidden weapon patch refuses weapon drops")
		assert_false((stage.call("slot_chip_rects") as Dictionary).is_empty(), "module chips stay visible in module mode")
		var weapon_ids_hidden: Dictionary = stage.call("slot_anchor_rects")
		for socket_id in _weapon_socket_ids(stage):
			assert_false(weapon_ids_hidden.has(socket_id), "hidden weapon socket '%s' drops its dot" % socket_id)
		for slot_id in _slot_target_ids(stage):
			assert_true(weapon_ids_hidden.has(slot_id), "module dot '%s' stays visible" % slot_id)
		# 武器装配模式：只有武器贴片。
		stage.call("set_weapon_patches_visible", true)
		stage.call("set_module_chips_visible", false)
		assert_false(bool(stage.call("module_chips_visible")), "module chips can be hidden")
		assert_true((stage.call("slot_chip_rects") as Dictionary).is_empty(), "hidden module chips have no layout")
		for target in Array(stage.get("_slot_targets")):
			assert_false(bool(target.visible), "hidden module chip is not visible")
			assert_false(bool(target.call("is_drop_enabled")), "hidden module chip disables drops")
			assert_false(bool(target.call("_can_drop_data", Vector2.ZERO, {
				"kind": "ship_parts", "part": {"module_id": "core:module/test", "source": "warehouse", "category": String(target.slot.get("category", ""))},
			})), "hidden module chip refuses ship_parts drops")
		var only_weapons: Dictionary = stage.call("slot_anchor_rects")
		var module_ids: Array = _slot_target_ids(stage)
		for slot_id in module_ids:
			assert_false(only_weapons.has(slot_id), "hidden module slot '%s' drops its dot" % slot_id)
		for target in Array(stage.call("weapon_targets")):
			assert_true(bool(target.visible), "weapon patches stay visible in weapon mode")
		# 恢复默认：两组都可见（旧调用 / 其他测试语义不变）。
		stage.call("set_module_chips_visible", true)
		stage.call("set_weapon_patches_visible", true)
		assert_false((stage.call("slot_chip_rects") as Dictionary).is_empty(), "restoring module chips re-lays them out")
	_unmount(bundle)


# ---------------------------------------------------------------------------
# P2b: 高亮联动
# ---------------------------------------------------------------------------
func test_highlight_slots_marks_dots_chips_and_weapon_patches() -> void:
	var bundle := _mount(5506)
	var stage := _cutaway_stage(bundle)
	if stage != null:
		var slot_ids := _slot_target_ids(stage)
		var socket_ids := _weapon_socket_ids(stage)
		var highlighted: Array = []
		if not slot_ids.is_empty():
			highlighted.append(slot_ids[0])
		if not socket_ids.is_empty():
			highlighted.append(socket_ids[0])
		stage.call("highlight_slots", highlighted)
		assert_eq(Array(stage.get("_highlighted_slot_ids")), highlighted, "the stage keeps the highlight ids")
		for target in Array(stage.get("_slot_targets")):
			var expected := highlighted.has(String(target.slot.get("id", "")))
			assert_eq(bool(target.get("_compatible")), expected,
				"module chip '%s' highlight state follows highlight_slots()" % String(target.slot.get("id", "")))
		for target in Array(stage.call("weapon_targets")):
			var expected := highlighted.has(String(target.row.get("socket", "")))
			assert_eq(bool(target.call("is_highlighted")), expected,
				"weapon patch '%s' highlight state follows highlight_slots()" % String(target.row.get("socket", "")))
		stage.call("highlight_slots", [])
		for target in Array(stage.call("weapon_targets")):
			assert_false(bool(target.call("is_highlighted")), "clearing the highlight clears the weapon patch")
	_unmount(bundle)


# ---------------------------------------------------------------------------
# P2b: 4 艘 Core 船的锚点 → 方框布局都成立
# ---------------------------------------------------------------------------
func _synthetic_stage(context: AppContext, hull_id: String, stage_size: Vector2 = SYNTHETIC_STAGE_SIZE) -> Control:
	var hull: ContentDefinition = context.registries.get_by_id(ContentTypes.HULL, hull_id)
	if hull == null:
		return null
	var stage: Control = SHIP_VIEW_SCRIPT.new()
	stage.size = stage_size
	stage.custom_minimum_size = stage_size
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(stage)
	stage.size = stage_size
	var model := {
		"blueprint_views": ShipyardViewQuery._blueprint_views(context, hull),
		"slot_anchors": ShipyardViewQuery._slot_anchors(hull),
		"weapon_sockets": Array(hull.data.get("weapon_sockets", [])).duplicate(true),
	}
	stage.call("set_ship_model", model)
	stage.call("set_slots", _synthetic_slots_for_hull(hull))
	stage.call("set_mode", SHIP_VIEW_SCRIPT.Mode.CUTAWAY)
	return stage


## Builds the same slot descriptors the shipyard page sends for this hull.
func _synthetic_slots_for_hull(hull: ContentDefinition) -> Array:
	var slots: Array = []
	var defs := [
		["hull", "hulls", "hull"],
		["boiler", "boiler", "boiler"],
		["navigation_module", "utility", "navigation"],
		["safety_module", "utility", "safety"],
	]
	for entry in defs:
		slots.append(_synthetic_slot_row(String(entry[0]), String(entry[1]), 0))
	if int(hull.data.get("cabin_slots", 0)) > 0:
		slots.append(_synthetic_slot_row("passenger_cabin", "cabin", 0))
	for index in int(hull.data.get("cargo_slots", 0)):
		slots.append(_synthetic_slot_row("cargo_modules", "cargo", index))
	return slots


func _synthetic_slot_row(slot: String, category: String, index: int) -> Dictionary:
	return {
		"id": "%s_%d" % [slot, index],
		"slot": slot,
		"category": category,
		"index": index,
		"title": slot,
		"module": {"module_id": "", "name": ""},
		"replace_module_id": "",
		"fixed": slot in ["hull", "boiler"],
		"hint": "",
		"condition": 1.0,
		"empty_text": "空槽位",
		"tooltip": "",
	}


func test_all_core_hulls_lay_their_blueprint_chips_out_cleanly() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	for hull_id in CORE_HULL_IDS:
		var stage := _synthetic_stage(context, String(hull_id))
		assert_not_null(stage, "hull '%s' builds a synthetic cutaway stage" % String(hull_id))
		if stage == null:
			continue
		_assert_stage_chips_fit(stage, "hull '%s'" % String(hull_id))
		if stage.get_parent() != null:
			stage.get_parent().remove_child(stage)
		stage.free()


## 960×540 窗口下左侧蓝图内容区只有约 320 px 宽：此时必须退化成不重叠的紧凑网格，
## 而不是让方框叠在一起（契约：可以缩小 / 省略文字，但不能重叠、出界）。
func test_small_panel_falls_back_to_a_non_overlapping_layout() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	var stage := _synthetic_stage(context, "core:hull/small_efficient", Vector2(320, 380))
	assert_not_null(stage, "a 320x380 blueprint stage builds")
	if stage != null:
		var side_rect: Rect2 = stage.call("blueprint_view_rect", "side")
		assert_true(side_rect.size.x > 0.0 and side_rect.size.y > 0.0,
			"the small stage still fits its side line art")
		_assert_stage_chips_fit(stage, "small panel")
		if stage.get_parent() != null:
			stage.get_parent().remove_child(stage)
		stage.free()


## Shared assertions: every chip / patch has a size, sits in the call-out band
## below the drawing (never on the line art), no two overlap, and every call-out
## keeps a dotted leader from the hull dot to its box.
func _assert_stage_chips_fit(stage: Control, label: String) -> void:
	var side_rect: Rect2 = stage.call("blueprint_view_rect", "side")
	var band: Rect2 = stage.call("chip_band_rect")
	var chips: Dictionary = stage.call("slot_chip_rects")
	var weapon_rects: Dictionary = stage.call("weapon_socket_display_rects", "side")
	var anchors: Dictionary = stage.call("slot_anchor_rects")
	var leaders: Dictionary = stage.call("slot_leader_lines")
	assert_eq(chips.size(), Array(stage.get("_slot_targets")).size(),
		"%s places a chip for every slot" % label)
	assert_eq(weapon_rects.size(), _weapon_socket_ids(stage).size(),
		"%s places a patch for every weapon socket" % label)
	var combined: Dictionary = {}
	for raw_id in chips.keys():
		assert_true(_rect_inside(chips[raw_id], band),
			"%s: chip '%s' sits inside the call-out band" % [label, String(raw_id)])
		assert_false((chips[raw_id] as Rect2).intersects(side_rect),
			"%s: chip '%s' is off the ship drawing" % [label, String(raw_id)])
		combined["slot:" + String(raw_id)] = chips[raw_id]
		assert_true(leaders.has(raw_id),
			"%s: chip '%s' keeps a dotted leader" % [label, String(raw_id)])
		var leader: PackedVector2Array = leaders.get(raw_id, PackedVector2Array())
		if leader.size() == 2 and anchors.has(raw_id):
			assert_true(leader[0].distance_to((anchors[raw_id] as Rect2).get_center()) <= 0.6,
				"%s: leader '%s' starts on its hull dot" % [label, String(raw_id)])
			assert_true((chips[raw_id] as Rect2).grow(0.6).has_point(leader[1]),
				"%s: leader '%s' ends on its chip" % [label, String(raw_id)])
	for raw_id in weapon_rects.keys():
		assert_true(_rect_inside(weapon_rects[raw_id], band),
			"%s: weapon patch '%s' sits inside the call-out band" % [label, String(raw_id)])
		assert_false((weapon_rects[raw_id] as Rect2).intersects(side_rect),
			"%s: weapon patch '%s' is off the ship drawing" % [label, String(raw_id)])
		combined["weapon:" + String(raw_id)] = weapon_rects[raw_id]
	_assert_rects_disjoint(combined, "%s blueprint chips" % label)
	for raw_id in anchors.keys():
		assert_true(_rect_inside(anchors[raw_id], side_rect),
			"%s: dot '%s' stays inside the side view" % [label, String(raw_id)])
