class_name AppViewQuery
extends RefCounted
## App / menu ViewModel. C4: the starting picker lists `starting_scenarios`
## (the retired `starting_scenarios`).

static func execute(_params: Dictionary, context) -> Dictionary:
	var report: StartupReport = context.report
	var scenarios: Array = RunFactory.starting_scenario_summaries(context.registries)
	var run_summary: Variant = null
	if context.has_run():
		run_summary = {
			"seed": context.state.seed(),
			"starting_scenario_id": String(context.state.run().get("starting_scenario", "")),
			"game_time": context.state.now(),
			"money": context.state.money(),
			"current_port_id": context.state.current_port_id(),
			"voyages": int(context.state.data.get("stats", {}).get("voyages", 0)),
		}
	return Result.ok({
		"status": report.status_name() if report != null else "fatal",
		"status_key": report.status_key() if report != null else "ui.status.fatal",
		"framework_version": FrameworkInfo.VERSION,
		"api_version": FrameworkInfo.API_VERSION,
		"report": report.to_dict() if report != null else {},
		"report_text": report.format_text() if report != null else "",
		"mods": context.mod_summaries(),
		"content_counts": context.registries.counts(),
		"content_total": context.content_total(),
		"registry_frozen": context.registries.is_frozen(),
		"scenarios": scenarios,
		"has_run": context.has_run(),
		"run_summary": run_summary,
		"autosave_available": context.save.has_slot(SaveService.AUTOSAVE_SLOT),
		"commands": context.commands.names(),
		"queries": context.queries.names(),
	})
