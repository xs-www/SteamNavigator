class_name QueryRegistry
extends RefCounted
## Binds query names to read-only ViewModel builders.

static func register_all(bus: QueryBus) -> void:
	bus.register(&"app.view", Callable(AppViewQuery, "execute"))
	bus.register(&"port.view", Callable(PortViewQuery, "execute"))
	bus.register(&"map.view", Callable(MapViewQuery, "execute"))
	bus.register(&"voyage.preview", Callable(VoyagePreviewQuery, "execute"))
	bus.register(&"intel.view", Callable(IntelViewQuery, "execute"))
	bus.register(&"shipyard.view", Callable(ShipyardViewQuery, "execute"))
	bus.register(&"supply.view", Callable(SupplyViewQuery, "execute"))
	bus.register(&"port.memory", Callable(PortMemoryViewQuery, "execute"))
	bus.register(&"victory.view", Callable(VictoryViewQuery, "execute"))
	bus.register(&"sea_chart.view", Callable(SeaChartViewQuery, "execute"))
	bus.register(&"clue.list", Callable(ClueListViewQuery, "execute"))
	bus.register(&"story.view", Callable(StoryViewQuery, "execute"))
