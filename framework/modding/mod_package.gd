class_name ModPackage
extends RefCounted
## A scanned mod package plus its manifest and scan-time diagnostics.

var source: ModSource = null
var manifest: ModManifest = null
var manifest_raw: Dictionary = {}
var id: String = ""
var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []
var enabled: bool = true
var disabled_reason: String = ""


func add_error(code: String, message: String, file: String = "", pointer: String = "") -> void:
	errors.append({"code": code, "message": message, "file": file, "pointer": pointer})


func add_warning(code: String, message: String, file: String = "", pointer: String = "") -> void:
	warnings.append({"code": code, "message": message, "file": file, "pointer": pointer})


func is_valid() -> bool:
	return errors.is_empty() and manifest != null and manifest.errors.is_empty()


func root_label() -> String:
	if source != null:
		return source.get_display_name()
	return id


func close() -> void:
	if source != null:
		source.close()
