class_name MarketViewQuery
extends RefCounted
## @static-doc
## 作用：市场页聚合 ViewModel：复用 `port.view` 的行情行，补充「船舱货物 / 当前港仓库材料」与图标资产键，供「左侧船只背包 + 右侧市场」的图标直接交互页使用。
##
## - 关键依赖：`PortViewQuery`（行情 / 船摘要 / 港信息）、`IntelViewQuery`（价格趋势）、`ShipOps`、`WarehouseOps`、`ContentDefinition.information["texture"]`。
## - 写作用域：只读；不修改 GameState，不解析纹理（纹理由 Shell 用 `AssetService` 解析）。
##
## ## 契约与约束
## - 输出字段以 `docs/design/MARKET_UI_REFACTOR.md` §3 为准；`market` 行继承 `port.view` 的全部字段，只追加 `icon_key`。
## - `ship.hold` 按 `item_id + 是否委托货` 聚合：普通货一行（`sellable_amount` = 该品种非委托数量），委托货一行且 `is_contract=true`、`sellable_amount=0`。
## - `warehouse.materials` 只列当前港仓库材料区；排序按 item_id 保证确定性。
## - `trends` 沿用 Shell 旧 `_market_trends()` 的语义：当前港情报报告里的价格趋势；无报告时为空字典。
## - 未开局（`has_run=false`）时仍返回完整空结构，页面无需做键存在性判断。
## @end-static-doc


static func execute(params: Dictionary, context) -> Dictionary:
	var port_result := PortViewQuery.execute(params, context)
	if not bool(port_result.get("ok", false)):
		return port_result
	var data: Dictionary = port_result["data"]
	if not bool(data.get("has_run", false)):
		data["market"] = []
		data["trends"] = {}
		data["warehouse"] = {"port_id": "", "materials": []}
		return Result.ok(data)
	var state: GameState = context.state
	var hub: RegistryHub = context.registries
	var ship: Dictionary = state.ship()
	var current_port := state.current_port_id()
	for row in data.get("market", []):
		if row is Dictionary:
			(row as Dictionary)["icon_key"] = _item_icon_key(hub, String((row as Dictionary).get("item_id", "")))
	var ship_view: Dictionary = data.get("ship", {})
	ship_view["hold"] = _hold_rows(hub, ship)
	data["ship"] = ship_view
	data["warehouse"] = {
		"port_id": current_port,
		"materials": _warehouse_rows(hub, state, current_port),
	}
	data["trends"] = _trends(context, current_port)
	data["at_port"] = not bool(data.get("at_sea", false))
	return Result.ok(data)


## 船舱货物：同一 item 的普通货合并，委托货单独一行并锁定交易。
static func _hold_rows(hub: RegistryHub, ship: Dictionary) -> Array:
	var aggregated := {}
	for stack in ship.get("cargo", []):
		if not (stack is Dictionary):
			continue
		var item_id := String((stack as Dictionary).get("item_id", ""))
		var amount := int((stack as Dictionary).get("amount", 0))
		if item_id.is_empty() or amount <= 0:
			continue
		var contract_id := String((stack as Dictionary).get("contract_id", ""))
		var is_contract := not contract_id.is_empty()
		var key := "%s|%s" % [item_id, "contract" if is_contract else "free"]
		if not aggregated.has(key):
			aggregated[key] = {
				"item_id": item_id,
				"amount": 0,
				"total_cost": 0.0,
				"is_contract": is_contract,
				"contract_id": contract_id if is_contract else "",
			}
		var entry: Dictionary = aggregated[key]
		entry["amount"] = int(entry["amount"]) + amount
		entry["total_cost"] = float(entry["total_cost"]) + float((stack as Dictionary).get("total_cost", 0.0))
	var rows: Array = []
	var keys: Array = aggregated.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = aggregated[key]
		var item_id := String(entry["item_id"])
		var definition := ShipOps.item_definition(hub, item_id)
		var total_amount := int(entry["amount"])
		var is_contract := bool(entry["is_contract"])
		rows.append({
			"item_id": item_id,
			"name_key": definition.name_key if definition != null else item_id,
			"category": String(definition.data.get("category", "")) if definition != null else "",
			"crafting_material": bool(definition.data.get("crafting_material", false)) if definition != null else false,
			"unit_weight": float(definition.data.get("unit_weight", 0.0)) if definition != null else 0.0,
			"amount": total_amount,
			"sellable_amount": 0 if is_contract else total_amount,
			"is_contract": is_contract,
			"contract_id": String(entry["contract_id"]),
			"avg_cost": (float(entry["total_cost"]) / float(total_amount)) if not is_contract and total_amount > 0 else 0.0,
			"icon_key": _definition_icon_key(definition),
		})
	return rows


## 当前港仓库材料区：{item_id: amount} -> 带名称 / 类别 / 图标键的行。
static func _warehouse_rows(hub: RegistryHub, state: GameState, port_id: String) -> Array:
	var warehouse := WarehouseOps.warehouse(state, port_id)
	var materials: Dictionary = warehouse.get("materials", {})
	var item_ids: Array = materials.keys()
	item_ids.sort()
	var rows: Array = []
	for raw_item_id in item_ids:
		var item_id := String(raw_item_id)
		var amount := int(materials[raw_item_id])
		if amount <= 0:
			continue
		var definition := ShipOps.item_definition(hub, item_id)
		rows.append({
			"item_id": item_id,
			"name_key": definition.name_key if definition != null else item_id,
			"category": String(definition.data.get("category", "")) if definition != null else "",
			"crafting_material": bool(definition.data.get("crafting_material", false)) if definition != null else false,
			"unit_weight": float(definition.data.get("unit_weight", 0.0)) if definition != null else 0.0,
			"amount": amount,
			"icon_key": _definition_icon_key(definition),
		})
	return rows


## 当前港价格趋势（只在有情报报告时出现）。
static func _trends(context, current_port: String) -> Dictionary:
	var result := {}
	var intel := IntelViewQuery.execute({}, context)
	if not bool(intel.get("ok", false)) or not bool(intel["data"].get("has_report", false)):
		return result
	for port_report in intel["data"].get("ports", []):
		if not (port_report is Dictionary) or String((port_report as Dictionary).get("port_id", "")) != current_port:
			continue
		for row in (port_report as Dictionary).get("market", []):
			if row is Dictionary:
				result[String((row as Dictionary).get("item_id", ""))] = String((row as Dictionary).get("trend", ""))
	return result


static func _item_icon_key(hub: RegistryHub, item_id: String) -> String:
	return _definition_icon_key(ShipOps.item_definition(hub, item_id))


## 内容模组用 `information.texture` 声明图标逻辑键（如 `icon.item.iron_ore`）。
static func _definition_icon_key(definition) -> String:
	if definition == null:
		return ""
	return String(definition.information.get("texture", ""))
