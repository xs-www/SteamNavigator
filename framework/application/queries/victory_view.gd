class_name VictoryViewQuery
extends RefCounted
## Victory screen ViewModel. Read-only snapshot of `state.data.victory`.

static func execute(_params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.ok({
			"has_run": false,
			"achieved": false,
			"achieved_at": 0.0,
			"achieved_at_label": "",
			"summary": {},
		})
	var victory: Variant = context.state.data.get("victory", null)
	var achieved := victory is Dictionary and bool(victory.get("achieved", false))
	var achieved_at := 0.0
	var summary: Dictionary = {}
	if victory is Dictionary:
		achieved_at = float(victory.get("achieved_at", 0.0))
		var stored_summary: Variant = victory.get("summary", null)
		if stored_summary is Dictionary:
			summary = stored_summary.duplicate(true)
	return Result.ok({
		"has_run": true,
		"achieved": achieved,
		"achieved_at": achieved_at,
		"achieved_at_label": ClockService.format_time(achieved_at) if achieved else "",
		"summary": summary,
	})
