class_name DebtService
extends RefCounted
## Fixed-rate loans that prevent soft locks without becoming optimal finance.

static func borrow(state: GameState, requested: float, limit: float, interest_rate: float, term_hours: float) -> Dictionary:
	if requested <= 0.0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount")
	if not (state.player().get("debt", null) == null):
		return Result.fail("debt_exists", "ui.error.debt_exists")
	var principal := minf(requested, limit)
	if principal <= 0.0:
		return Result.fail("invalid_amount", "ui.error.invalid_amount")
	var total_due := principal * (1.0 + interest_rate)
	var debt := {
		"principal": principal,
		"interest_rate": interest_rate,
		"remaining": total_due,
		"borrowed_at": state.now(),
		"due_time": state.now() + term_hours,
		"overdue": false,
	}
	state.player()["debt"] = debt
	state.add_money(int(round(principal)))
	return Result.ok({
		"principal": principal,
		"total_due": total_due,
		"due_time": debt["due_time"],
		"money": state.money(),
	})


static func receive_income(state: GameState, amount: int) -> Dictionary:
	if amount <= 0:
		return {"gross": amount, "to_debt": 0, "to_player": 0, "debt_cleared": false}
	var debt: Variant = state.player().get("debt", null)
	if not (debt is Dictionary):
		state.add_money(amount)
		return {"gross": amount, "to_debt": 0, "to_player": amount, "debt_cleared": false}
	var remaining := float(debt.get("remaining", 0.0))
	var payment := minf(float(amount), remaining)
	debt["remaining"] = maxf(0.0, remaining - payment)
	var to_player := amount - int(round(payment))
	if to_player > 0:
		state.add_money(to_player)
	var cleared := float(debt["remaining"]) <= 0.01
	if cleared:
		state.player()["debt"] = null
	return {
		"gross": amount,
		"to_debt": int(round(payment)),
		"to_player": to_player,
		"debt_cleared": cleared,
	}


static func check_overdue(state: GameState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var debt: Variant = state.player().get("debt", null)
	if not (debt is Dictionary):
		return events
	if bool(debt.get("overdue", false)):
		return events
	if state.now() <= float(debt.get("due_time", 0.0)):
		return events
	debt["overdue"] = true
	var player := state.player()
	player["reputation"] = maxi(0, int(player.get("reputation", 0)) - 1)
	events.append({
		"type": "debt.overdue",
		"payload": {
			"remaining": float(debt.get("remaining", 0.0)),
			"due_time": float(debt.get("due_time", 0.0)),
			"reputation": int(player.get("reputation", 0)),
		},
	})
	return events


static func remaining(state: GameState) -> float:
	var debt: Variant = state.player().get("debt", null)
	return 0.0 if not (debt is Dictionary) else float(debt.get("remaining", 0.0))
