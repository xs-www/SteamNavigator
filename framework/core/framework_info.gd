class_name FrameworkInfo
extends RefCounted
## Version and capability constants shared by framework systems.
##
## Kept separate from AppContext so low-level services (save, resolver) can
## depend on version data without creating a class reference cycle.

const VERSION := "0.1.0"
const API_MAJOR := 1
const API_MINOR := 0
const API_VERSION := "1.0"
const CONTENT_SCHEMA := "1.0"

const CAPABILITIES := [
	"content.contract.passenger.v1",
	"content.event.choice_pool.v1",
]
