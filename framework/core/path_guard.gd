class_name PathGuard
extends RefCounted
## Validation helpers for untrusted mod paths.
##
## Mod packages are data, but their file names are still untrusted input.
## Every path crossing the package boundary goes through these checks.

const MAX_PATH_LENGTH := 240
const MAX_PATH_DEPTH := 16

const FORBIDDEN_EXTENSIONS := [
	".gd", ".gdshader", ".cs", ".dll", ".so", ".dylib", ".exe", ".bat",
	".cmd", ".ps1", ".sh", ".pck", ".tscn", ".tres", ".import",
]

const CONTENT_EXTENSIONS := [".json"]
const ASSET_EXTENSIONS := [".png", ".webp", ".svg", ".ogg", ".wav", ".glb"]
const LOCALIZATION_EXTENSIONS := [".json", ".csv"]


static func is_safe_relative(path: String) -> bool:
	if path.is_empty() or path.length() > MAX_PATH_LENGTH:
		return false
	if path.contains("\\") or path.contains("\u0000"):
		return false
	if path.begins_with("/") or path.contains("://") or path.contains(":"):
		return false
	var segments := path.split("/")
	if segments.size() > MAX_PATH_DEPTH:
		return false
	for segment in segments:
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	if is_forbidden_file(path):
		return false
	return true


static func is_forbidden_file(path: String) -> bool:
	var extension := "." + path.get_extension().to_lower()
	return FORBIDDEN_EXTENSIONS.has(extension)


static func is_allowed_content(path: String) -> bool:
	return is_safe_relative(path) and CONTENT_EXTENSIONS.has("." + path.get_extension().to_lower())


static func is_allowed_asset(path: String) -> bool:
	return is_safe_relative(path) and ASSET_EXTENSIONS.has("." + path.get_extension().to_lower())


static func is_allowed_localization(path: String) -> bool:
	return is_safe_relative(path) and LOCALIZATION_EXTENSIONS.has("." + path.get_extension().to_lower())


static func join(root: String, relative: String) -> String:
	return root.rstrip("/") + "/" + relative.trim_prefix("/")


static func strip_root(path: String, root: String) -> String:
	var normalized_root := root.rstrip("/") + "/"
	if path.begins_with(normalized_root):
		return path.substr(normalized_root.length())
	return path


static func depth(path: String) -> int:
	return path.split("/", false).size()
