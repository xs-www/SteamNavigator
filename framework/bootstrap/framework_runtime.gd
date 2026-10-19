class_name FrameworkRuntime
extends RefCounted
## Process-level cleanup for headless tools and tests.
##
## Static opcode/formula registries intentionally live for the whole process.
## Clearing them before quit keeps CI exits clean.

static func shutdown() -> void:
	FormulaRegistry.clear_runtime()
	ConditionOpRegistry.clear_runtime()
	EffectOpRegistry.clear_runtime()
	ContentAssetLoader.clear_cache()
	AppContext.set_active(null)
