## @static-doc
## 作用：运行时读取模组内容资产（原始 PNG / 原始 GLB），并把 GLB 内嵌贴图之外的外部共享贴图按 URI 归一到同一个 `Texture2D` 实例，让多栋建筑在 Godot 里真正共享材质资源。
##
## - 关键依赖：`FileAccess`、`Image.load_from_file`、`GLTFDocument` / `GLTFState`、`StandardMaterial3D`
##
## ## 契约与约束
## - 模组是挂载的普通资源包（含原始文件），`ResourceLoader` 无法直接 load 其中的 `.png` / `.glb`，因此内容资产必须走本加载器。
## - `load_texture(path)` 返回按路径缓存的 `ImageTexture`；`load_scene(path)` 返回 GLTF 场景根；`instantiate_model()` 返回可挂到舞台的副本（缓存节点不被父级占用）。
## - 解析失败按路径记入 `failures` 缓存，重复调用不反复尝试；`clear_cache()` 在 `FrameworkRuntime.shutdown` 中调用。
## - 旧格式（贴图内嵌在 GLB bufferView 里）行为不变：没有外部 image URI 时不做任何材质改写。
## - GLB 的外部 image URI 只在 GLB 自行声明时处理；`data:` URI 与内部资源 URI 不接管。缺失的外部贴图不会让整个模型加载失败（保留 GLTF 解析出的占位材质）。
## - 贴图共享是"按 URI 缓存 `Texture2D` 实例"：同一外部 PNG 被多份 GLB 引用时只解一张、只建一个实例，`PortStage` 的材质签名合批才能跨建筑合并。
## - 只负责表现资源，不读写 GameState、注册表或存档。
##
## ## 重点逻辑
## ### `material_image_uris(path)`
## - 直接解析 GLB 的 JSON chunk（12 字节头 + chunk 头），按 `materials[i].pbrMetallicRoughness.baseColorTexture.index -> textures[].source -> images[].uri` 取出每材质的主色图 URI；解析失败返回空数组，调用方退回旧行为。
## - 只读 GLB 头部与 JSON chunk，不读 BIN chunk，工具/测试可用它核对 `image.uri` 是否已外部化。
## ### `load_scene(path)`
## - `append_from_file()` 之后、`generate_scene()` 之前改写 `GLTFState` 里的材质：把 albedo 贴图换成本加载器缓存的外部 `Texture2D`。放在 `append` 与 `generate` 之间，是因为 `generate_scene()` 会用 state 里的材质实例生成 primitive，改写才能落到最终网格。
## ### `_resolve_image_path(base_dir, uri)`
## - 相对 URI 按 GLB 所在目录拼接（松散目录与挂载 ZIP 内的 res:// 路径都成立），不依赖 `..` 解析层。
## @end-static-doc

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
## A GLB whose images are external URIs (the shared-texture iron-harbor
## buildings) also gets its material albedo textures re-bound to this loader's
## path cache before `generate_scene()`, so every building that references the
## same PNG resolves to the same `Texture2D` instance and `PortStage`'s
## material-signature batching can merge them across models.
##
## Results are cached by path so repeated shipyard rebuilds do not re-parse the
## same GLB. Failed loads return null; callers keep their 2D fallback.

const GLB_MAGIC := 0x46546C67
const GLB_CHUNK_JSON := 0x4E4F534A

static var _textures: Dictionary = {}
static var _scenes: Dictionary = {}
static var _failures: Dictionary = {}
static var _material_uris: Dictionary = {}


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


## Per-material external albedo image URIs of a GLB ("" for embedded / missing
## base color textures). Parses only the GLB header + JSON chunk.
static func material_image_uris(path: String) -> PackedStringArray:
	if _material_uris.has(path):
		return _material_uris[path]
	var uris := PackedStringArray()
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20 or _u32_le(bytes, 0) != GLB_MAGIC:
		_material_uris[path] = uris
		return uris
	var chunk_length := _u32_le(bytes, 12)
	var chunk_type := _u32_le(bytes, 16)
	if chunk_type != GLB_CHUNK_JSON or chunk_length <= 0 or 20 + chunk_length > bytes.size():
		_material_uris[path] = uris
		return uris
	var json_text := bytes.slice(20, 20 + chunk_length).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		_material_uris[path] = uris
		return uris
	var document: Dictionary = parsed
	var images: Array = document.get("images", [])
	var textures: Array = document.get("textures", [])
	for material in document.get("materials", []):
		var uri := ""
		if material is Dictionary:
			var pbr: Dictionary = material.get("pbrMetallicRoughness", {})
			var texture_ref: Dictionary = pbr.get("baseColorTexture", {})
			if texture_ref.has("index"):
				var texture_index := int(texture_ref["index"])
				if texture_index >= 0 and texture_index < textures.size():
					var texture: Dictionary = textures[texture_index]
					var source := int(texture.get("source", -1))
					if source >= 0 and source < images.size():
						var image: Dictionary = images[source]
						uri = String(image.get("uri", ""))
		uris.append(uri)
	_material_uris[path] = uris
	return uris


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
	_apply_shared_textures(path, state)
	var scene := document.generate_scene(state)
	if scene == null:
		_failures[path] = true
		return null
	_scenes[path] = scene
	return scene


## Re-binds external image URIs to the loader's `Texture2D` cache. Returns the
## number of re-bound materials (0 keeps the legacy embedded-texture path).
static func _apply_shared_textures(glb_path: String, state: GLTFState) -> int:
	var uris := material_image_uris(glb_path)
	if uris.is_empty():
		return 0
	var base_dir := glb_path.get_base_dir()
	var materials: Array = state.get_materials()
	var rebound := 0
	for index in mini(materials.size(), uris.size()):
		var uri := uris[index]
		if uri.is_empty() or uri.begins_with("data:"):
			continue
		var material: Variant = materials[index]
		if not (material is StandardMaterial3D):
			continue
		var texture := load_texture(_resolve_image_path(base_dir, uri))
		if texture == null:
			continue
		(material as StandardMaterial3D).albedo_texture = texture
		rebound += 1
	return rebound


static func _resolve_image_path(base_dir: String, uri: String) -> String:
	if uri.begins_with("res://") or uri.begins_with("user://"):
		return uri
	return base_dir.path_join(uri)


static func _u32_le(bytes: PackedByteArray, offset: int) -> int:
	return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24)


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
	_material_uris.clear()
