class_name QueryRegistry
extends RefCounted
## Binds query names to read-only ViewModel builders.

static func register_all(bus: QueryBus) -> void:
	bus.register(&"app.view", Callable(AppViewQuery, "execute"))
	bus.register(&"port.view", Callable(PortViewQuery, "execute"))
	bus.register(&"market.view", Callable(MarketViewQuery, "execute"))
	bus.register(&"map.view", Callable(MapViewQuery, "execute"))
	bus.register(&"voyage.preview", Callable(VoyagePreviewQuery, "execute"))
	bus.register(&"intel.view", Callable(IntelViewQuery, "execute"))
	bus.register(&"tavern.view", Callable(TavernViewQuery, "execute"))
	bus.register(&"shipyard.view", Callable(ShipyardViewQuery, "execute"))
	bus.register(&"supply.view", Callable(SupplyViewQuery, "execute"))
	bus.register(&"port.memory", Callable(PortMemoryViewQuery, "execute"))
	bus.register(&"victory.view", Callable(VictoryViewQuery, "execute"))
	bus.register(&"sea_chart.view", Callable(SeaChartViewQuery, "execute"))
	bus.register(&"clue.list", Callable(ClueListViewQuery, "execute"))
	bus.register(&"story.view", Callable(StoryViewQuery, "execute"))
	bus.register(&"task.view", Callable(TaskViewQuery, "execute"))
	bus.register(&"campaign.view", Callable(CampaignViewQuery, "execute"))
	bus.register(&"sim.view", Callable(SimViewQuery, "execute"))
	bus.register(&"combat.view", Callable(CombatViewQuery, "execute"))
	bus.register(&"combat.log", Callable(CombatLogQuery, "execute"))
	bus.register(&"fleet.view", Callable(FleetViewQuery, "execute"))
	bus.register(&"base.view", Callable(BaseViewQuery, "execute"))
	bus.register(&"auto_trade.view", Callable(AutoTradeViewQuery, "execute"))
	bus.register(&"expedition.view", Callable(ExpeditionViewQuery, "execute"))
