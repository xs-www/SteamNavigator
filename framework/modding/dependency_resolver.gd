class_name DependencyResolver
extends RefCounted
## Resolves mod dependencies, conflicts and deterministic load order.
##
## Failure policy follows the architecture document:
##   Fatal            - core missing/invalid, no game can start.
##   Mod Disabled     - missing dependency, version mismatch, conflict, cycle.
##   Warning          - optional dependency missing or disabled.

const CORE_ID := "core"
const MAX_CYCLE_PASSES := 8

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []
var fatal: bool = false

var _packages: Dictionary = {}
var _disabled: Dictionary = {}


func resolve(packages: Array[ModPackage], known_capabilities: PackedStringArray = PackedStringArray()) -> Dictionary:
	errors.clear()
	warnings.clear()
	fatal = false
	_packages.clear()
	_disabled.clear()

	_index_packages(packages)
	_check_core_presence()
	_check_package_health()
	_check_capabilities(known_capabilities)
	_resolve_conflicts()
	_resolve_dependencies()
	var order := _build_order()

	if _disabled.has(CORE_ID):
		_add_error("core_disabled", "core mod is disabled: %s" % String(_disabled[CORE_ID]), CORE_ID, true)

	var fatal_errors: Array[Dictionary] = []
	for entry in errors:
		if entry.get("severity", "error") == "fatal":
			fatal_errors.append(entry)

	return {
		"ok": not fatal,
		"fatal": fatal,
		"order": order,
		"disabled": _disabled.duplicate(),
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
		"fatal_errors": fatal_errors,
	}


func _index_packages(packages: Array[ModPackage]) -> void:
	var seen: Dictionary = {}
	for package in packages:
		var id := package.id
		if id.is_empty():
			var reason := "missing manifest"
			if not package.errors.is_empty():
				reason = String(package.errors[0].get("message", reason))
			_add_error(
				"mod_missing_id",
				"package has no usable id at %s: %s" % [package.root_label(), reason]
			)
			continue
		if seen.has(id):
			_add_error("duplicate_mod_id", "duplicate mod id '%s'; all copies are disabled" % id, id)
			_disabled[id] = "duplicate mod id"
			if id == CORE_ID:
				fatal = true
			continue
		seen[id] = true
		_packages[id] = package


func _check_core_presence() -> void:
	if not _packages.has(CORE_ID):
		_add_error("core_missing", "required core mod is missing", CORE_ID, true)
		return
	var core: ModPackage = _packages[CORE_ID]
	if core.manifest == null:
		_add_error("core_invalid", "core manifest could not be parsed", CORE_ID, true)
		return
	if not core.manifest.required:
		_add_error("core_not_required", "core manifest must declare required=true", CORE_ID, true)


func _check_package_health() -> void:
	for id in _packages.keys():
		var package: ModPackage = _packages[id]
		if not package.errors.is_empty() or package.manifest == null:
			_disabled[id] = "package validation failed"
			var reason: String = "missing manifest"
			if not package.errors.is_empty():
				reason = String(package.errors[0].get("message", "package validation failed"))
			_add_error("package_invalid", "mod '%s' is disabled: %s" % [id, reason], id, id == CORE_ID)
			continue
		if not package.manifest.accepts_api(FrameworkInfo.API_MAJOR, FrameworkInfo.API_MINOR):
			_disabled[id] = "incompatible mod API"
			_add_error(
				"api_incompatible",
				"mod '%s' targets mod API %s, framework provides %d.%d" % [
					id, package.manifest.api_version_text, FrameworkInfo.API_MAJOR, FrameworkInfo.API_MINOR
				],
				id,
				id == CORE_ID
			)


func _check_capabilities(known_capabilities: PackedStringArray) -> void:
	for id in _packages.keys():
		if _disabled.has(id):
			continue
		var manifest: ModManifest = _packages[id].manifest
		for capability in manifest.capabilities:
			if not known_capabilities.has(capability):
				_disabled[id] = "unsupported capability: %s" % capability
				_add_error(
					"unsupported_capability",
					"mod '%s' requires unsupported capability '%s'" % [id, capability],
					id,
					id == CORE_ID
				)
				break


func _resolve_conflicts() -> void:
	var ids := _active_ids()
	for index in ids.size():
		for other_index in range(index + 1, ids.size()):
			var left_id := ids[index]
			var right_id := ids[other_index]
			var left: ModPackage = _packages[left_id]
			var right: ModPackage = _packages[right_id]
			var conflicting := left.manifest.conflicts.has(right_id) or right.manifest.conflicts.has(left_id)
			if not conflicting:
				continue
			var loser := _conflict_loser(left, right)
			var winner := right_id if loser == left_id else left_id
			if loser == CORE_ID:
				loser = winner
				winner = CORE_ID
			_disabled[loser] = "conflict with %s" % winner
			_add_error(
				"mod_conflict",
				"mods '%s' and '%s' declare a conflict; '%s' is disabled" % [left_id, right_id, loser],
				loser
			)


func _conflict_loser(left: ModPackage, right: ModPackage) -> String:
	if left.id == CORE_ID:
		return right.id
	if right.id == CORE_ID:
		return left.id
	if left.manifest.load_priority != right.manifest.load_priority:
		return left.id if left.manifest.load_priority > right.manifest.load_priority else right.id
	return left.id if left.id > right.id else right.id


func _resolve_dependencies() -> void:
	var changed := true
	var passes := 0
	while changed and passes < MAX_CYCLE_PASSES + 4:
		passes += 1
		changed = false
		for id in _active_ids():
			var package: ModPackage = _packages[id]
			for dependency in package.manifest.dependencies:
				var dependency_id: String = dependency["id"]
				if not _packages.has(dependency_id):
					_disable_mod(id, "missing dependency '%s'" % dependency_id)
					changed = true
					break
				if _disabled.has(dependency_id):
					_disable_mod(id, "dependency '%s' is disabled" % dependency_id)
					changed = true
					break
				var dependency_package: ModPackage = _packages[dependency_id]
				var range: VersionRange = dependency["range"]
				if not range.matches(dependency_package.manifest.version):
					_disable_mod(
						id,
						"dependency '%s' version %s does not match '%s'" % [
							dependency_id, dependency_package.manifest.version_text, dependency["range_text"]
						]
					)
					changed = true
					break
			for optional in package.manifest.optional_dependencies:
				var optional_id: String = optional["id"]
				if not _packages.has(optional_id):
					warnings.append({
						"code": "optional_dependency_missing",
						"message": "optional dependency '%s' of '%s' is not installed" % [optional_id, id],
						"mod_id": id,
					})
				elif _disabled.has(optional_id):
					warnings.append({
						"code": "optional_dependency_disabled",
						"message": "optional dependency '%s' of '%s' is disabled" % [optional_id, id],
						"mod_id": id,
					})


func _build_order() -> Array[String]:
	var active := _active_ids()
	for _pass in MAX_CYCLE_PASSES:
		var result := _kahn(active)
		if result["complete"]:
			return result["order"]
		var cycle_nodes: Array[String] = result["remaining"]
		for id in cycle_nodes:
			_disable_mod(id, "dependency cycle or blocked by a cycle")
		active = _active_ids()
	return _active_ids()


func _kahn(active: Array[String]) -> Dictionary:
	var indegree: Dictionary = {}
	var dependents: Dictionary = {}
	for id in active:
		indegree[id] = 0
		dependents[id] = []
	for id in active:
		var package: ModPackage = _packages[id]
		for dependency in package.manifest.dependencies:
			var dependency_id: String = dependency["id"]
			if indegree.has(dependency_id):
				indegree[id] = int(indegree[id]) + 1
				dependents[dependency_id].append(id)

	var ready: Array[String] = []
	for id in active:
		if int(indegree[id]) == 0:
			ready.append(id)
	var order: Array[String] = []
	while not ready.is_empty():
		_sort_ids(ready)
		var next: String = ready.pop_front()
		order.append(next)
		for dependent in dependents[next]:
			indegree[dependent] = int(indegree[dependent]) - 1
			if int(indegree[dependent]) == 0:
				ready.append(dependent)
	var remaining: Array[String] = []
	for id in active:
		if not order.has(id):
			remaining.append(id)
	remaining.sort()
	return {"complete": remaining.is_empty(), "order": order, "remaining": remaining}


func _sort_ids(ids: Array[String]) -> void:
	ids.sort_custom(func(left: String, right: String) -> bool:
		var left_package: ModPackage = _packages[left]
		var right_package: ModPackage = _packages[right]
		if left_package.manifest.load_priority != right_package.manifest.load_priority:
			return left_package.manifest.load_priority < right_package.manifest.load_priority
		return left < right
	)


func _active_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _packages.keys():
		if not _disabled.has(id):
			ids.append(id)
	ids.sort()
	return ids


func _disable_mod(id: String, reason: String) -> void:
	if _disabled.has(id):
		return
	_disabled[id] = reason
	_add_error("mod_disabled", "mod '%s' is disabled: %s" % [id, reason], id, id == CORE_ID)


func _add_error(code: String, message: String, mod_id: String = "", is_fatal: bool = false) -> void:
	if is_fatal:
		fatal = true
	errors.append({
		"code": code,
		"message": message,
		"mod_id": mod_id,
		"severity": "fatal" if is_fatal else "error",
	})
