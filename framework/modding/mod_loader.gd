class_name ModLoader
extends RefCounted
## Full mod lifecycle: scan -> resolve -> mount -> compile -> validate -> freeze.

var logger: AppLogger = null
var packages: Dictionary = {}
var order: PackedStringArray = PackedStringArray()
var report: StartupReport = null


func _init(log: AppLogger = null) -> void:
	logger = log


func load_mods(config: Dictionary) -> StartupReport:
	report = StartupReport.new()
	var total_started := Time.get_ticks_msec()
	var validator := SchemaValidator.new()
	var roots: PackedStringArray = config.get("scan_roots", PackedStringArray())
	var allow_loose := bool(config.get("allow_loose", true))
	var mount_packs := bool(config.get("mount_packs", true))

	var scan_started := Time.get_ticks_msec()
	var scanner := ModScanner.new(validator)
	var scan_result := scanner.scan(roots, allow_loose)
	report.timings_ms["scan"] = Time.get_ticks_msec() - scan_started
	report.scanned_roots = scan_result["scanned_roots"]
	for scan_error in scan_result["errors"]:
		report.add_error(String(scan_error.get("code", "scan_error")), String(scan_error.get("message", "")), scan_error)
	for scan_warning in scan_result["warnings"]:
		report.add_warning(String(scan_warning.get("code", "scan_warning")), String(scan_warning.get("message", "")), scan_warning)
	var package_list: Array[ModPackage] = []
	for package in scan_result["packages"]:
		package_list.append(package)

	var resolve_started := Time.get_ticks_msec()
	var resolver := DependencyResolver.new()
	var resolution := resolver.resolve(package_list, FrameworkInfo.CAPABILITIES)
	report.timings_ms["resolve"] = Time.get_ticks_msec() - resolve_started
	for resolver_error in resolution["errors"]:
		report.add_error(
			String(resolver_error.get("code", "resolution_error")),
			String(resolver_error.get("message", "")),
			resolver_error
		)
	for resolver_warning in resolution["warnings"]:
		report.add_warning(
			String(resolver_warning.get("code", "resolution_warning")),
			String(resolver_warning.get("message", "")),
			resolver_warning
		)
	report.disabled_mods = resolution["disabled"].duplicate(true)

	for package in package_list:
		if resolution["disabled"].has(package.id):
			package.enabled = false
			package.disabled_reason = String(resolution["disabled"][package.id])

	if bool(resolution["fatal"]):
		report.finalize()
		report.registry_frozen = true
		return report

	order = PackedStringArray()
	for mod_id in resolution["order"]:
		var package := _find_package(package_list, String(mod_id))
		if package == null:
			continue
		packages[package.id] = package
		order.append(package.id)
		report.mods.append(package.manifest.to_summary())

	var mount_started := Time.get_ticks_msec()
	if mount_packs:
		_mount_packs()
	report.timings_ms["mount"] = Time.get_ticks_msec() - mount_started

	var compile_started := Time.get_ticks_msec()
	var compiler := ContentCompiler.new(registry_hub(), localization_service(), asset_service(), logger, validator)
	var compile_result := compiler.compile(packages, order)
	report.timings_ms["compile"] = Time.get_ticks_msec() - compile_started
	_add_content_errors(compile_result["errors"])
	for warning in compile_result["warnings"]:
		report.add_warning(String(warning.get("code", "content_warning")), String(warning.get("message", "")), warning)
	report.content_counts = compile_result["counts"]

	var validation_started := Time.get_ticks_msec()
	var cross_reference := CrossReferenceValidator.new()
	var cross_result := cross_reference.validate(registry_hub())
	for error in cross_result["errors"]:
		var is_core := String(error.get("definition_id", "")).begins_with("core:")
		report.add_error(String(error.get("code", "cross_reference")), String(error.get("message", "")), {
			"severity": "fatal" if is_core else "error",
			"definition_id": error.get("definition_id", ""),
		})
	for warning in cross_result["warnings"]:
		report.add_warning(String(warning.get("code", "cross_reference")), String(warning.get("message", "")), warning)

	var completeness := CoreCompletenessChecker.check(registry_hub(), packages, order)
	for error in completeness["errors"]:
		report.add_fatal(String(error.get("code", "core_incomplete")), String(error.get("message", "")))
	for warning in completeness["warnings"]:
		report.add_warning(String(warning.get("code", "core_warning")), String(warning.get("message", "")), warning)
	report.timings_ms["validate"] = Time.get_ticks_msec() - validation_started

	registry_hub().freeze_all()
	report.registry_frozen = true
	for package in packages.values():
		package.close()
	report.timings_ms["total"] = Time.get_ticks_msec() - total_started
	report.finalize()
	if logger != null:
		logger.info("mod load complete", {
			"status": report.status_name(),
			"mods": Array(order),
			"content": report.content_total(),
		})
	return report


func registry_hub() -> RegistryHub:
	return _context.registries if _context != null else null


func localization_service() -> LocalizationService:
	return _context.localization if _context != null else null


func asset_service() -> AssetService:
	return _context.assets if _context != null else null


## The loader receives the composition root through `bind_context` before
## `load_mods`; Bootstrap does this immediately after constructing AppContext.
var _context = null


func bind_context(context) -> void:
	_context = context


func _find_package(package_list: Array[ModPackage], mod_id: String) -> ModPackage:
	for package in package_list:
		if package.id == mod_id:
			return package
	return null


func _mount_packs() -> void:
	for mod_id in order:
		var package: ModPackage = packages[mod_id]
		if not package.source.is_pack():
			continue
		var path := package.source.get_pack_path()
		var mounted := ProjectSettings.load_resource_pack(path, false)
		if not mounted:
			report.add_warning(
				"pack_mount_failed",
				"could not mount resource pack (assets may fall back): %s" % path,
				{"mod_id": mod_id, "path": path}
			)
		elif logger != null:
			logger.debug("resource pack mounted", {"mod_id": mod_id, "path": path})


func _add_content_errors(content_errors: Array) -> void:
	for error in content_errors:
		var mod_id := String(error.get("mod_id", ""))
		report.add_error(
			String(error.get("code", "content_error")),
			String(error.get("message", "")),
			{
				"severity": "fatal" if mod_id == "core" else "error",
				"mod_id": mod_id,
				"file": error.get("file", ""),
				"pointer": error.get("pointer", ""),
			}
		)
