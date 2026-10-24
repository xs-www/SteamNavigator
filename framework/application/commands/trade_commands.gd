class_name TradeCommands
extends RefCounted
## @static-doc
## 作用：`trade.buy` / `trade.sell` 命令包装：读取场景贸易参数、透传落点（船货舱 / 当前港仓库）并发出 `market.changed` 事件。
##
## ## 契约与约束
## - `params.destination`（buy，默认 `"cargo"`）与 `params.source`（sell，默认 `"cargo"`）原样交给 `MarketOps`；
##   非法值由领域层返回 `invalid_destination` / `invalid_trade_source`，命令总线不提交事务。
## - 成功时 `MarketOps` 结果 data 携带实际 `destination` / `source`；`market.changed` 载荷保留
##   `"source":"player"` 表示行为者，并新增 `"storage"` 表示实际落点，供状态栏 / 表现层使用。
## - 成功交易后调用 `MarketMemoryService.remember` 记录价格记忆，与既往路径一致。
## @end-static-doc

static func buy(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var port_id := String(params.get("port_id", state.current_port_id()))
	var item_id := String(params.get("item_id", ""))
	var amount := int(params.get("amount", 1))
	var destination := String(params.get("destination", "cargo"))
	var profile := _profile(context)
	var margin := float(profile.get("trade_margin", MarketOps.DEFAULT_TRADE_MARGIN))
	var impact := float(profile.get("player_trade_impact", MarketOps.DEFAULT_PLAYER_PRICE_IMPACT))
	var result := MarketOps.buy(state, context.registries, port_id, item_id, amount, margin, impact, destination)
	if bool(result["ok"]):
		MarketMemoryService.remember(state, port_id)
		var entry := MarketOps.entry_for(state, port_id, item_id)
		var payload := {
			"port_id": port_id,
			"item_id": item_id,
			"source": "player",
			"storage": String(result["data"].get("destination", destination)),
			"stock": int(entry.get("stock", 0)),
			"price_after": float(entry.get("price", 0.0)),
		}
		if result["data"].has("warehouse_amount"):
			payload["warehouse_amount"] = int(result["data"]["warehouse_amount"])
		result["events"] = [{
			"type": "market.changed",
			"payload": payload,
		}]
	return result


static func sell(params: Dictionary, context) -> Dictionary:
	var state: GameState = context.state
	if not context.has_run():
		return Result.fail("no_run", "ui.error.no_run")
	var port_id := String(params.get("port_id", state.current_port_id()))
	var item_id := String(params.get("item_id", ""))
	var amount := int(params.get("amount", 1))
	var source := String(params.get("source", "cargo"))
	var profile := _profile(context)
	var margin := float(profile.get("trade_margin", MarketOps.DEFAULT_TRADE_MARGIN))
	var impact := float(profile.get("player_trade_impact", MarketOps.DEFAULT_PLAYER_PRICE_IMPACT))
	var result := MarketOps.sell(state, context.registries, port_id, item_id, amount, margin, impact, source)
	if bool(result["ok"]):
		MarketMemoryService.remember(state, port_id)
		var entry := MarketOps.entry_for(state, port_id, item_id)
		var payload := {
			"port_id": port_id,
			"item_id": item_id,
			"source": "player",
			"storage": String(result["data"].get("source", source)),
			"stock": int(entry.get("stock", 0)),
			"price_after": float(entry.get("price", 0.0)),
		}
		if result["data"].has("warehouse_amount"):
			payload["warehouse_amount"] = int(result["data"]["warehouse_amount"])
		result["events"] = [{
			"type": "market.changed",
			"payload": payload,
		}]
	return result


static func _profile(context) -> Dictionary:
	return ContentRefs.map_config_data(context.state, context.registries)
