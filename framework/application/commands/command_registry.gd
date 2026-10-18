class_name CommandRegistry
extends RefCounted
## Binds MVP command names to application use cases.

static func register_all(bus: CommandBus) -> void:
	bus.register(&"run.start", Callable(RunStartCommand, "execute"))
	bus.register(&"trade.buy", Callable(TradeCommands, "buy"))
	bus.register(&"trade.sell", Callable(TradeCommands, "sell"))
	bus.register(&"supply.buy_coal", Callable(SupplyCommands, "buy_coal"))
	bus.register(&"supply.buy_water", Callable(SupplyCommands, "buy_water"))
	bus.register(&"supply.repair", Callable(SupplyCommands, "repair"))
	bus.register(&"intel.refresh", Callable(IntelCommands, "refresh"))
	bus.register(&"debt.borrow", Callable(DebtCommands, "borrow"))
	bus.register(&"contract.accept", Callable(ContractCommands, "accept"))
	bus.register(&"voyage.preview", Callable(VoyageCommands, "preview"))
	bus.register(&"voyage.start", Callable(VoyageCommands, "start"))
	bus.register(&"event.choose_option", Callable(VoyageCommands, "choose_option"))
	bus.register(&"ship.install_module", Callable(ShipCommands, "install_module"))
