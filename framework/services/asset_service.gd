class_name AssetService
extends RefCounted
## Resolves logical asset keys (`asset://core/icon.coal`) to mounted paths.
##
## Missing assets degrade to a framework placeholder instead of breaking saves
## or scenes.

const FALLBACK_PATH := "res://framework/assets/missing.png"

var _assets: Dictionary = {}  # "asset://mod/key" -> physical path
var _logger: AppLogger = null


func _init(logger: AppLogger = null) -> void:
	_logger = logger


func register(mod_id: String, key: String, relative_path: String, asset_prefix: String) -> void:
	var logical_key := "asset://%s/%s" % [mod_id, key]
	var physical_path := PathGuard.join(asset_prefix, relative_path)
	_assets[logical_key] = physical_path


func resolve(logical_key: String) -> String:
	if logical_key.begins_with("res://"):
		return logical_key if FileAccess.file_exists(logical_key) else FALLBACK_PATH
	if not _assets.has(logical_key):
		if _logger != null:
			_logger.warn("asset key is not registered", {"asset": logical_key})
		return FALLBACK_PATH
	var path: String = _assets[logical_key]
	if not FileAccess.file_exists(path):
		if _logger != null:
			_logger.warn("asset file is missing after mount", {"asset": logical_key, "path": path})
		return FALLBACK_PATH
	return path


## Loads a content texture from a mod (raw PNG in a mounted pack) or from an
## imported framework texture. Returns null when the asset is missing.
func load_texture(logical_key: String) -> Texture2D:
	var path := resolve(logical_key)
	if path == FALLBACK_PATH:
		return load(FALLBACK_PATH) as Texture2D
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return ContentAssetLoader.load_texture(path)


## Loads an instanced content model from a mod (raw GLB) or an imported scene.
## Returns null when the asset is missing; callers keep their 2D fallback.
func load_model(logical_key: String) -> Node3D:
	var path := resolve(logical_key)
	if path == FALLBACK_PATH:
		return null
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		return packed.instantiate() as Node3D if packed != null else null
	return ContentAssetLoader.instantiate_model(path)


func has(logical_key: String) -> bool:
	return _assets.has(logical_key) and FileAccess.file_exists(String(_assets[logical_key]))


func count() -> int:
	return _assets.size()


func keys() -> PackedStringArray:
	var result := PackedStringArray()
	for key in _assets.keys():
		result.append(String(key))
	result.sort()
	return result


func fallback_path() -> String:
	return FALLBACK_PATH
