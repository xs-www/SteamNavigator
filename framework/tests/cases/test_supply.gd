extends TestCase


func test_supply_view_and_purchases() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 9191})
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 0.0
	var view := context.queries.execute(&"supply.view")
	assert_true(bool(view["ok"]), "supply view succeeds")
	var data: Dictionary = view["data"]
	assert_true(bool(data["has_supply"]), "starting port has a supply dock")
	assert_true(float(data["coal_price"]) > 0.0, "coal has a price")
	assert_true(float(data["water_price"]) > 0.0, "water has a price")
	assert_true(int(data["max_coal"]) >= 10, "weight and money allow coal")
	assert_true(int(data["max_water"]) >= 10, "weight and money allow water")
	var coal_view: Dictionary = data["coal_view"]
	assert_eq(int(coal_view["max_buy"]), int(data["max_coal"]), "coal card uses the same max-buy rule")
	assert_true(coal_view.has("fill_to"), "coal card exposes fill-to value")
	assert_true(coal_view.has("estimated_days"), "coal card exposes estimated endurance")
	assert_true(int(coal_view["fill_cost"]) >= 0, "coal card exposes fill cost")
	assert_true(Array(coal_view["blockers"]).is_empty(), "coal card has no blockers at start")
	var coal_stock_before := int(data["coal_stock"])
	var coal_price_before := float(data["coal_price"])
	assert_true(coal_stock_before >= 10, "port has coal stock")
	var coal := context.commands.execute(&"supply.buy_coal", {"amount": 10})
	assert_true(bool(coal["ok"]), "buying coal succeeds: %s" % str(coal))
	assert_eq(String(coal["data"].get("item_id", "")), "core:item/coal",
		"the supply payload exposes the resolved item id for quest/event match")
	assert_almost_eq(float(context.state.ship()["coal"]), 10.0, 0.001, "coal is added")
	var after_coal_result := context.queries.execute(&"supply.view")
	var after_coal: Dictionary = after_coal_result["data"]
	assert_eq(int(after_coal["coal_stock"]), coal_stock_before - 10, "coal purchase consumes port stock")
	assert_true(float(after_coal["coal_price"]) >= coal_price_before, "coal price rises as port stock falls")
	var water := context.commands.execute(&"supply.buy_water", {"amount": 10})
	assert_true(bool(water["ok"]), "buying water succeeds: %s" % str(water))
	assert_eq(String(water["data"].get("item_id", "")), "core:item/water",
		"the water payload exposes the resolved item id for quest/event match")
	assert_almost_eq(float(context.state.ship()["water"]), 10.0, 0.001, "water is added")


func test_supply_capacity_loss_tracks_the_other_tank() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 9191})
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 0.0
	var before: Dictionary = context.queries.execute(&"supply.view")["data"]
	var coal_before: Dictionary = before["coal_view"]
	var water_before: Dictionary = before["water_view"]
	for key in ["price", "port_stock", "max_buy", "fill_to", "fill_cost", "can_buy", "blockers", "estimated_days", "daily_rate", "safe_level", "unit_weight"]:
		assert_true(coal_before.has(key), "coal view keeps legacy field %s" % key)
		assert_true(water_before.has(key), "water view keeps legacy field %s" % key)
	assert_eq(int(coal_before["cap_loss"]), 0, "empty other tank costs no coal capacity")
	assert_eq(int(water_before["cap_loss"]), 0, "empty other tank costs no water capacity")
	assert_eq(int(coal_before["baseline_capacity"]), int(coal_before["capacity"]), "coal baseline equals capacity when the other tank is empty")
	assert_eq(int(water_before["baseline_capacity"]), int(water_before["capacity"]), "water baseline equals capacity when the other tank is empty")
	assert_eq(int(coal_before["maximum"]), int(coal_before["capacity"]), "coal maximum is the physical capacity")
	assert_eq(int(coal_before["maximum_baseline"]), int(coal_before["baseline_capacity"]), "coal maximum_baseline is the baseline capacity")
	assert_almost_eq(float(coal_before["headroom"]), float(coal_before["capacity"]) - float(coal_before["current"]), 0.001, "coal headroom is the room inside capacity")
	assert_almost_eq(float(water_before["headroom"]), float(water_before["capacity"]) - float(water_before["current"]), 0.001, "water headroom is the room inside capacity")
	assert_true(float(coal_before["current"]) <= float(coal_before["capacity"]), "coal current stays inside its capacity")

	var coal_before_max_buy := int(coal_before["max_buy"])
	var water_before_max_buy := int(water_before["max_buy"])
	var coal_capacity := int(coal_before["capacity"])
	var water_capacity := int(water_before["capacity"])
	var water_baseline := int(water_before["baseline_capacity"])

	var bought := context.commands.execute(&"supply.buy_coal", {"amount": 10})
	assert_true(bool(bought["ok"]), "buying coal succeeds: %s" % str(bought))
	var after: Dictionary = context.queries.execute(&"supply.view")["data"]
	var coal_after: Dictionary = after["coal_view"]
	var water_after: Dictionary = after["water_view"]

	assert_almost_eq(float(coal_after["current"]), 10.0, 0.001, "coal is loaded")
	assert_eq(int(after["max_coal"]), int(coal_after["max_buy"]), "top-level max_coal still mirrors the coal card")
	assert_eq(int(coal_after["capacity"]), coal_capacity, "buying coal does not move coal's own capacity")
	assert_almost_eq(float(coal_after["headroom"]), float(coal_capacity) - 10.0, 0.001, "coal headroom shrinks by what was bought")
	assert_true(int(coal_after["max_buy"]) <= coal_before_max_buy, "coal max_buy never rises after buying")
	assert_true(float(coal_after["current"]) <= float(coal_after["capacity"]), "coal current stays inside its capacity")

	assert_true(int(water_after["capacity"]) < water_capacity, "water capacity drops when coal is loaded")
	assert_eq(int(water_after["capacity"]), water_capacity - 10, "water loses exactly the coal weight from its capacity")
	assert_eq(int(water_after["baseline_capacity"]), water_baseline, "water baseline does not move when coal is bought")
	assert_true(int(water_after["cap_loss"]) > 0, "water reports a cap loss after buying coal")
	assert_eq(int(water_after["cap_loss"]), water_baseline - int(water_after["capacity"]), "water cap loss is baseline minus capacity")
	assert_eq(int(water_after["cap_loss"]), 10, "water cap loss equals the loaded coal weight")
	assert_true(int(water_after["maximum"]) <= int(water_before["maximum"]), "water maximum never rises when coal is bought")
	assert_true(int(water_after["max_buy"]) <= water_before_max_buy, "water max_buy never rises when coal is bought")
	assert_almost_eq(float(water_after["current"]), float(water_before["current"]), 0.001, "buying coal leaves water untouched")
	var ratio_before := float(water_before["current"]) / maxf(1.0, float(water_before["maximum"]))
	var ratio_after := float(water_after["current"]) / maxf(1.0, float(water_after["maximum"]))
	assert_true(ratio_after <= ratio_before + 0.0001, "water current/maximum ratio does not rise after buying coal")
	var span_before := float(water_before["maximum"]) + float(water_before["cap_loss"])
	var span_after := float(water_after["maximum"]) + float(water_after["cap_loss"])
	assert_true(float(water_after["current"]) / maxf(1.0, span_after) <= float(water_before["current"]) / maxf(1.0, span_before) + 0.0001, "water fill fraction across the loss band does not rise")

	# More water cannot raise coal's buy limit: max_buy is monotonic in current.
	var previous_water_max_buy := int(water_after["max_buy"])
	var previous_coal_max_buy := int(coal_after["max_buy"])
	for amount in [5.0, 10.0, 15.0]:
		context.state.ship()["water"] = amount
		var step: Dictionary = context.queries.execute(&"supply.view")["data"]
		var step_coal: Dictionary = step["coal_view"]
		var step_water: Dictionary = step["water_view"]
		assert_almost_eq(float(step_water["current"]), amount, 0.001, "water current matches the loaded amount")
		assert_true(int(step_water["max_buy"]) <= previous_water_max_buy, "water max_buy never rises while its own current rises")
		assert_true(int(step_coal["max_buy"]) <= previous_coal_max_buy, "coal max_buy never rises when the other tank is filled")
		assert_eq(int(step_water["capacity"]), water_capacity - 10, "water capacity only depends on the other tank")
		previous_water_max_buy = int(step_water["max_buy"])
		previous_coal_max_buy = int(step_coal["max_buy"])


func test_supply_bars_stay_flat_while_the_other_tank_is_loaded() -> void:
	var boot := bootstrap_core()
	var context: AppContext = boot["context"]
	context.commands.execute(&"run.start", {"starting_scenario": "core:starting_scenario/steady", "seed": 9191})
	context.state.ship()["coal"] = 0.0
	context.state.ship()["water"] = 5.0
	var before: Dictionary = context.queries.execute(&"supply.view")["data"]
	var coal_before: Dictionary = before["coal_view"]
	var water_before: Dictionary = before["water_view"]
	assert_eq(int(coal_before["cap_loss"]), 5, "loaded water already costs coal capacity")
	assert_eq(int(water_before["cap_loss"]), 0, "empty coal costs water no capacity")
	assert_eq(int(water_before["baseline_capacity"]), int(water_before["capacity"]), "water starts at its baseline")

	var bought := context.commands.execute(&"supply.buy_coal", {"amount": 10})
	assert_true(bool(bought["ok"]), "buying coal next to a loaded water tank succeeds: %s" % str(bought))
	var after: Dictionary = context.queries.execute(&"supply.view")["data"]
	var coal_after: Dictionary = after["coal_view"]
	var water_after: Dictionary = after["water_view"]

	assert_eq(int(water_after["capacity"]), int(water_before["capacity"]) - 10, "water capacity drops by the coal weight")
	assert_eq(int(water_after["cap_loss"]), 10, "water cap loss grows with the coal weight")
	assert_eq(int(water_after["baseline_capacity"]), int(water_before["baseline_capacity"]), "water baseline is stable")
	assert_almost_eq(float(water_after["current"]), 5.0, 0.001, "water level is untouched by the coal purchase")
	assert_true(int(water_after["max_buy"]) <= int(water_before["max_buy"]), "water max_buy does not rise")
	assert_true(int(coal_after["max_buy"]) <= int(coal_before["max_buy"]), "coal max_buy does not rise")
	assert_almost_eq(float(coal_after["current"]), 10.0, 0.001, "coal is loaded")
	assert_true(float(coal_after["current"]) <= float(coal_after["capacity"]), "coal current stays inside capacity")
	assert_eq(int(coal_after["capacity"]), int(coal_before["capacity"]), "coal capacity ignores its own load")

	# The rendered bar spans capacity + cap_loss, which is exactly the stable baseline.
	var water_span_before := float(water_before["maximum"]) + float(water_before["cap_loss"])
	var water_span_after := float(water_after["maximum"]) + float(water_after["cap_loss"])
	assert_almost_eq(water_span_after, water_span_before, 0.001, "water bar span stays at its baseline")
	assert_true(5.0 / water_span_after <= 5.0 / water_span_before + 0.0001, "water bar fill does not rise when coal is bought")
	assert_almost_eq(float(coal_after["maximum"]) + float(coal_after["cap_loss"]), float(coal_before["baseline_capacity"]), 0.001, "coal bar span reaches its baseline")


func test_supply_meter_switches_to_the_loss_band_only_when_needed() -> void:
	var meter := SNResourceMeter.new()
	meter.label_text = "存量"
	meter.current_value = 5.0
	meter.maximum_value = 40.0
	meter.suffix = ""
	meter.hint = "可补至 40"
	var progress := meter.get_node("Progress") as ProgressBar
	var loss_bar := meter.get_node("LossBar") as Control
	var value_label := meter.get_node("Header/Value") as Label
	var hint_label := meter.get_node("Hint") as Label
	assert_not_null(progress, "legacy ProgressBar node is kept")
	assert_not_null(loss_bar, "loss bar node exists")
	assert_true(progress.visible, "no loss keeps the themed ProgressBar")
	assert_false(loss_bar.visible, "no loss hides the custom band")
	assert_true(value_label.text.begins_with("5 / 40"), "legacy value label format is kept: %s" % value_label.text)
	assert_eq(hint_label.text, "可补至 40", "hint without loss stays untouched")

	meter.loss_value = 10.0
	meter.loss_hint_text = "另一项补给占用的载重让本项上限下降"
	assert_false(progress.visible, "a cap loss hides the themed ProgressBar")
	assert_true(loss_bar.visible, "a cap loss shows the custom band")
	assert_almost_eq(loss_bar.custom_minimum_size.y, 14.0, 0.001, "the custom band keeps the bar height")
	assert_true(value_label.text.begins_with("5 / 40"), "value label still shows current / capacity: %s" % value_label.text)
	assert_eq(hint_label.text, "可补至 40 · 另一项补给占用的载重让本项上限下降", "hint appends the cap-loss note")

	meter.loss_value = 0.0
	assert_true(progress.visible, "clearing the loss restores the themed ProgressBar")
	assert_false(loss_bar.visible, "clearing the loss hides the custom band")
	assert_eq(hint_label.text, "可补至 40", "hint drops the cap-loss note")
	meter.queue_free()


func test_supply_meter_loss_api_stays_backward_compatible() -> void:
	var meter := SNResourceMeter.new()
	assert_eq(meter.label_text, "煤炭", "legacy label default is kept")
	assert_almost_eq(meter.current_value, 31.0, 0.001, "legacy current default is kept")
	assert_almost_eq(meter.maximum_value, 50.0, 0.001, "legacy maximum default is kept")
	assert_almost_eq(meter.loss_value, 0.0, 0.001, "loss defaults to zero for existing callers")
	meter.loss_value = -5.0
	assert_almost_eq(meter.loss_value, 0.0, 0.001, "negative loss is clamped to zero")

	var plain := SNResourceMeter.loss_bar_segments(200.0, 31.0, 50.0, 0.0)
	var with_loss := SNResourceMeter.loss_bar_segments(200.0, 31.0, 40.0, 10.0)
	assert_almost_eq(float(with_loss["span"]), float(plain["span"]), 0.001, "bar span is the stable baseline")
	assert_almost_eq(float(with_loss["fill_end"]), float(plain["fill_end"]), 0.001, "fill width does not grow when the limit shrinks")
	assert_almost_eq(float(with_loss["loss_end"]), 200.0, 0.001, "loss band ends at the right edge")
	assert_almost_eq(float(with_loss["loss_start"]), 160.0, 0.001, "loss band spans [capacity, baseline]")
	assert_true(float(with_loss["empty_end"]) <= float(with_loss["loss_start"]) + 0.001, "free segment stops before the loss band")
	meter.free()

	var legacy := SNSupplyCard.new()
	legacy.bind({"kind": "coal", "current": 31.0, "fill_to": 40.0, "maximum": 50.0, "max_buy": 9}, "煤炭", [])
	var legacy_content := legacy.get_child(0) as VBoxContainer
	var legacy_meter := legacy_content.get_child(1) as SNResourceMeter
	assert_not_null(legacy_meter, "legacy bind still creates the meter")
	assert_almost_eq(legacy_meter.maximum_value, 40.0, 0.001, "ViewModel without capacity keeps the old meter scale")
	assert_almost_eq(legacy_meter.loss_value, 0.0, 0.001, "ViewModel without capacity shows no loss band")
	legacy.free()

	var card := SNSupplyCard.new()
	card.bind({
		"kind": "water",
		"current": 5.0,
		"fill_to": 40.0,
		"maximum": 40.0,
		"capacity": 40,
		"baseline_capacity": 50,
		"cap_loss": 10,
		"headroom": 35,
		"max_buy": 35,
	}, "淡水", [], func(key: String) -> String: return key)
	var content := card.get_child(0) as VBoxContainer
	var card_meter := content.get_child(1) as SNResourceMeter
	assert_not_null(card_meter, "bind creates the meter")
	assert_almost_eq(card_meter.current_value, 5.0, 0.001, "card forwards the current level")
	assert_almost_eq(card_meter.maximum_value, 40.0, 0.001, "card forwards the reachable capacity")
	assert_almost_eq(card_meter.loss_value, 10.0, 0.001, "card forwards the cap loss as the reverse band")
	var texts: Array[String] = []
	for row in content.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is Label:
					texts.append((child as Label).text)
	var joined := " | ".join(texts)
	assert_true(joined.contains("上限损失 10"), "card shows the cap loss: %s" % joined)
	assert_true(joined.contains("剩余可装 35"), "card shows the remaining headroom: %s" % joined)
	card.free()
