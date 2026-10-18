class_name VoyageCommands
extends RefCounted

static func preview(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var destination_id := String(params.get("destination_id", ""))
	var strategy_id := String(params.get("strategy_id", ""))
	if destination_id.is_empty():
		return Result.fail("missing_destination", "ui.error.missing_destination")
	if strategy_id.is_empty():
		return Result.fail("missing_strategy", "ui.error.missing_strategy")
	return VoyageCalculator.preview(context, destination_id, strategy_id)


static func start(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var destination_id := String(params.get("destination_id", ""))
	var strategy_id := String(params.get("strategy_id", ""))
	if destination_id.is_empty():
		return Result.fail("missing_destination", "ui.error.missing_destination")
	if strategy_id.is_empty():
		return Result.fail("missing_strategy", "ui.error.missing_strategy")
	return VoyageService.start(context, destination_id, strategy_id)


static func choose_option(params: Dictionary, context) -> Dictionary:
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var option_id := String(params.get("option_id", ""))
	if option_id.is_empty():
		return Result.fail("missing_option", "ui.error.missing_option")
	return VoyageService.choose_option(context, option_id)
