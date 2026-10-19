class_name ContentAssetLoader
extends RefCounted
## Loads raw content assets (`.glb` / `.png`) shipped inside mod packages.
##
## Imported resources under `res://assets/` go through ResourceLoader, but mod
## content is mounted as a plain resource pack containing the source files, so
## `ResourceLoader.load()` cannot be used for them. These helpers read the raw
## bytes through FileAccess (which works for loose mods and mounted zips) and
## build the runtime resource with Godot's own loaders:
##
## - images: `Image.load_from_file()` -> `ImageTexture`
## - models: `GLTFDocument.append_from_file()` -> scene root
##
## Results are cached by path so repeated shipyard rebuilds do not re-parse the
## same GLB. Failed loads return null; callers keep their 2D fallback.

static var _textures: Dictionary = {}
static var _scenes: Dictionary = {}
static var _failures: Dictionary = {}


static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _textures.has(path):
		return _textures[path]
	if _failures.has(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		_failures[path] = true
		return null
	var texture := ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture


static func load_scene(path: String) -> Node3D:
	if path.is_empty():
		return null
	if _scenes.has(path):
		return _scenes[path]
	if _failures.has(path):
		return null
	if not FileAccess.file_exists(path):
		_failures[path] = true
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		_failures[path] = true
		return null
	var scene := document.generate_scene(state)
	if scene == null:
		_failures[path] = true
		return null
	_scenes[path] = scene
	return scene


## Returns a fresh instance of a cached model scene (the cached node itself is
## never parented, so callers can add it without stealing it from the cache).
static func instantiate_model(path: String) -> Node3D:
	var scene := load_scene(path)
	if scene == null:
		return null
	var instance: Node3D = scene.duplicate()
	return instance


## Drops cached resources; called on framework shutdown so tests and reloads do
## not keep textures/scenes alive.
static func clear_cache() -> void:
	_textures.clear()
	_scenes.clear()
	_failures.clear()
