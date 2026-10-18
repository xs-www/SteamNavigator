class_name Result
extends RefCounted
## Uniform command/query result envelope.

static func ok(data: Dictionary = {}, events: Array = []) -> Dictionary:
	return {
		"ok": true,
		"error_code": "",
		"message_key": "",
		"data": data,
		"events": events,
	}


static func fail(error_code: String, message_key: String = "", details: Dictionary = {}, events: Array = []) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"message_key": message_key if not message_key.is_empty() else "ui.error.%s" % error_code,
		"data": details,
		"events": events,
	}


static func is_ok(result: Dictionary) -> bool:
	return bool(result.get("ok", false))
