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
