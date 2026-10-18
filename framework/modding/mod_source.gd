class_name ModSource
extends RefCounted
## Abstraction over a loose mod directory or a ZIP resource pack.
##
## All paths passed to these methods are relative to the mod root and have
## already been validated by PathGuard. Implementations must not escape it.

var mod_id: String = ""
var origin: String = ""
var error: String = ""


func exists(_relative_path: String) -> bool:
	return false


func read_text(_relative_path: String) -> String:
	return ""


func read_bytes(_relative_path: String) -> PackedByteArray:
	return PackedByteArray()


func list_files() -> PackedStringArray:
	return PackedStringArray()


func get_asset_prefix() -> String:
	return ""


func get_pack_path() -> String:
	return ""


func is_pack() -> bool:
	return false


func get_display_name() -> String:
	return origin


func close() -> void:
	pass
