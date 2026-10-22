extends SceneTree
## Scratch integration check for the run pipeline.

func _initialize() -> void:
	var bootstrap := Bootstrap.new()
	var report := bootstrap.run({
		"scan_roots": PackedStringArray(["res://dev_mods"]),
		"log_to_console": false,
		"autosave": false,
		"save_directory": "user://smoke_saves",
	})
	if report.has_fatal():
		print(report.format_text())
		quit(1)
		return
	var context := AppContext.get_active()
	var start := context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 12345})
	print("run.start -> ", start)
	print("commands: ", context.commands.names())
	var view := context.queries.execute(&"port.view")
	print("port.view ok=", view.get("ok"), " money=", view.get("data", {}).get("money"), " market=", view.get("data", {}).get("market", []).size())
	print("main=", view.get("data", {}).get("contracts", {}).get("main"))
	var destinations: Array = view.get("data", {}).get("destinations", [])
	if destinations.is_empty():
		print("no destinations")
		quit(1)
		return
	var destination: String = destinations[0]["port_id"]
	var preview := context.commands.execute(&"voyage.preview", {"destination_id": destination, "strategy_id": "core:boiler_strategy/standard"})
	print("preview ok=", preview.get("ok"), " data=", preview.get("data", {}))
	var voyage := context.commands.execute(&"voyage.start", {"destination_id": destination, "strategy_id": "core:boiler_strategy/standard"})
	print("voyage.start ok=", voyage.get("ok"), " code=", voyage.get("error_code"), " data=", voyage.get("data", {}))
	if not bool(voyage.get("ok", false)):
		quit(1)
		return
	var data: Dictionary = voyage.get("data", {})
	if not bool(data.get("arrived", true)):
		var event: Dictionary = data.get("event", {})
		var option_ids: Array = event.get("option_ids", [])
		print("event=", event.get("event_id"), " options=", option_ids)
		if not option_ids.is_empty():
			var choice := context.commands.execute(&"event.choose_option", {"option_id": String(option_ids[0])})
			print("choose ok=", choice.get("ok"), " data=", choice.get("data", {}))
	print("final time=", context.state.now(), " port=", context.state.current_port_id(), " money=", context.state.money())
	print("events=", context.events.get_history(&"", 20).map(func(e): return e["event_type"]))
	quit(0)
