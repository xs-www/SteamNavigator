class_name FrameworkApi
extends RefCounted
## Registers the framework's public command and query surface on the context.

static func register(context) -> void:
	CommandRegistry.register_all(context.commands)
	QueryRegistry.register_all(context.queries)
